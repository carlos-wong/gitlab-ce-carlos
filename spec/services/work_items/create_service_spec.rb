# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::CreateService do
  include AfterNextHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:parent) { create(:work_item, project: project) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:user_with_no_access) { create(:user) }

  let(:widget_params) { {} }
  let(:spam_params) { double }
  let(:current_user) { guest }
  let(:opts) do
    {
      title: 'Awesome work_item',
      description: 'please fix'
    }
  end

  before_all do
    project.add_guest(guest)
    project.add_reporter(reporter)
  end

  describe '#execute' do
    let(:service) do
      described_class.new(
        project: project,
        current_user: current_user,
        params: opts,
        spam_params: spam_params,
        widget_params: widget_params
      )
    end

    subject(:service_result) { service.execute }

    before do
      stub_spam_services
    end

    context 'when user is not allowed to create a work item in the project' do
      let(:current_user) { user_with_no_access }

      it { is_expected.to be_error }

      it 'returns an access error' do
        expect(service_result.errors).to contain_exactly('Operation not allowed')
      end
    end

    context 'when params are valid' do
      it 'created instance is a WorkItem' do
        expect(Issuable::CommonSystemNotesService).to receive_message_chain(:new, :execute)

        work_item = service_result[:work_item]

        expect(work_item).to be_persisted
        expect(work_item).to be_a(::WorkItem)
        expect(work_item.title).to eq('Awesome work_item')
        expect(work_item.description).to eq('please fix')
        expect(work_item.work_item_type.base_type).to eq('issue')
      end
    end

    context 'when params are invalid' do
      let(:opts) { { title: '' } }

      it { is_expected.to be_error }

      it 'returns validation errors' do
        expect(service_result.errors).to contain_exactly("Title can't be blank")
      end

      it 'does not execute after-create transaction widgets' do
        expect(service).to receive(:create).and_call_original
        expect(service).not_to receive(:execute_widgets)
          .with(callback: :after_create_in_transaction, widget_params: widget_params)

        service_result
      end
    end

    context 'checking spam' do
      it 'executes SpamActionService' do
        expect_next_instance_of(
          Spam::SpamActionService,
          {
            spammable: kind_of(WorkItem),
            spam_params: spam_params,
            user: an_instance_of(User),
            action: :create
          }
        ) do |instance|
          expect(instance).to receive(:execute)
        end

        service_result
      end
    end

    it_behaves_like 'work item widgetable service' do
      let(:widget_params) do
        {
          hierarchy_widget: { parent: parent }
        }
      end

      let(:service) do
        described_class.new(
          project: project,
          current_user: current_user,
          params: opts,
          spam_params: spam_params,
          widget_params: widget_params
        )
      end

      let(:service_execute) { service.execute }

      let(:supported_widgets) do
        [
          {
            klass: WorkItems::Widgets::HierarchyService::CreateService,
            callback: :after_create_in_transaction,
            params: { parent: parent }
          }
        ]
      end
    end

    describe 'hierarchy widget' do
      let(:widget_params) { { hierarchy_widget: { parent: parent } } }

      shared_examples 'fails creating work item and returns errors' do
        it 'does not create new work item if parent can not be set' do
          expect { service_result }.not_to change(WorkItem, :count)

          expect(service_result[:status]).to be(:error)
          expect(service_result[:message]).to match(error_message)
        end
      end

      context 'when user can admin parent link' do
        let(:current_user) { reporter }

        context 'when parent is valid work item' do
          let(:opts) do
            {
              title: 'Awesome work_item',
              description: 'please fix',
              work_item_type: create(:work_item_type, :task)
            }
          end

          it 'creates new work item and sets parent reference' do
            expect { service_result }.to change(
              WorkItem, :count).by(1).and(change(
                WorkItems::ParentLink, :count).by(1))

            expect(service_result[:status]).to be(:success)
          end
        end

        context 'when parent type is invalid' do
          let_it_be(:parent) { create(:work_item, :task, project: project) }

          it_behaves_like 'fails creating work item and returns errors' do
            let(:error_message) { 'only Issue and Incident can be parent of Task.'}
          end
        end

        context 'when hierarchy feature flag is disabled' do
          before do
            stub_feature_flags(work_items_hierarchy: false)
          end

          it_behaves_like 'fails creating work item and returns errors' do
            let(:error_message) { '`work_items_hierarchy` feature flag disabled for this project' }
          end
        end
      end

      context 'when user cannot admin parent link' do
        let(:current_user) { guest }

        let(:opts) do
          {
            title: 'Awesome work_item',
            description: 'please fix',
            work_item_type: create(:work_item_type, :task)
          }
        end

        it_behaves_like 'fails creating work item and returns errors' do
          let(:error_message) { 'No matching task found. Make sure that you are adding a valid task ID.'}
        end
      end
    end
  end
end
