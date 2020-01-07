# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Pagination::OffsetPagination do
  let(:resource) { Project.all }
  let(:custom_port) { 8080 }
  let(:incoming_api_projects_url) { "#{Gitlab.config.gitlab.url}:#{custom_port}/api/v4/projects" }

  before do
    stub_config_setting(port: custom_port)
  end

  let(:request_context) { double("request_context") }

  subject do
    described_class.new(request_context)
  end

  describe '#paginate' do
    let(:value) { spy('return value') }
    let(:base_query) { { foo: 'bar', bar: 'baz' } }
    let(:query) { base_query }

    before do
      allow(request_context).to receive(:header).and_return(value)
      allow(request_context).to receive(:params).and_return(query)
      allow(request_context).to receive(:request).and_return(double(url: "#{incoming_api_projects_url}?#{query.to_query}"))
    end

    context 'when resource can be paginated' do
      before do
        create_list(:project, 3)
      end

      describe 'first page' do
        shared_examples 'response with pagination headers' do
          it 'adds appropriate headers' do
            expect_header('X-Total', '3')
            expect_header('X-Total-Pages', '2')
            expect_header('X-Per-Page', '2')
            expect_header('X-Page', '1')
            expect_header('X-Next-Page', '2')
            expect_header('X-Prev-Page', '')

            expect_header('Link', anything) do |_key, val|
              expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 1).to_query}>; rel="first"))
              expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 2).to_query}>; rel="last"))
              expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 2).to_query}>; rel="next"))
              expect(val).not_to include('rel="prev"')
            end

            subject.paginate(resource)
          end
        end

        shared_examples 'paginated response' do
          it 'returns appropriate amount of resources' do
            expect(subject.paginate(resource).count).to eq 2
          end

          it 'executes only one SELECT COUNT query' do
            expect { subject.paginate(resource) }.to make_queries_matching(/SELECT COUNT/, 1)
          end
        end

        let(:query) { base_query.merge(page: 1, per_page: 2) }

        context 'when the api_kaminari_count_with_limit feature flag is unset' do
          it_behaves_like 'paginated response'
          it_behaves_like 'response with pagination headers'
        end

        context 'when the api_kaminari_count_with_limit feature flag is disabled' do
          before do
            stub_feature_flags(api_kaminari_count_with_limit: false)
          end

          it_behaves_like 'paginated response'
          it_behaves_like 'response with pagination headers'
        end

        context 'when the api_kaminari_count_with_limit feature flag is enabled' do
          before do
            stub_feature_flags(api_kaminari_count_with_limit: true)
          end

          context 'when resources count is less than MAX_COUNT_LIMIT' do
            before do
              stub_const("::Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT", 4)
            end

            it_behaves_like 'paginated response'
            it_behaves_like 'response with pagination headers'
          end

          context 'when resources count is more than MAX_COUNT_LIMIT' do
            before do
              stub_const("::Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT", 2)
            end

            it_behaves_like 'paginated response'

            it 'does not return the X-Total and X-Total-Pages headers' do
              expect_no_header('X-Total')
              expect_no_header('X-Total-Pages')
              expect_header('X-Per-Page', '2')
              expect_header('X-Page', '1')
              expect_header('X-Next-Page', '2')
              expect_header('X-Prev-Page', '')

              expect_header('Link', anything) do |_key, val|
                expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 1).to_query}>; rel="first"))
                expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 2).to_query}>; rel="next"))
                expect(val).not_to include('rel="last"')
                expect(val).not_to include('rel="prev"')
              end

              subject.paginate(resource)
            end
          end
        end
      end

      describe 'second page' do
        let(:query) { base_query.merge(page: 2, per_page: 2) }

        it 'returns appropriate amount of resources' do
          expect(subject.paginate(resource).count).to eq 1
        end

        it 'adds appropriate headers' do
          expect_header('X-Total', '3')
          expect_header('X-Total-Pages', '2')
          expect_header('X-Per-Page', '2')
          expect_header('X-Page', '2')
          expect_header('X-Next-Page', '')
          expect_header('X-Prev-Page', '1')

          expect_header('Link', anything) do |_key, val|
            expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 1).to_query}>; rel="first"))
            expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 2).to_query}>; rel="last"))
            expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 1).to_query}>; rel="prev"))
            expect(val).not_to include('rel="next"')
          end

          subject.paginate(resource)
        end
      end

      context 'if order' do
        it 'is not present it adds default order(:id) if no order is present' do
          resource.order_values = []

          paginated_relation = subject.paginate(resource)

          expect(resource.order_values).to be_empty
          expect(paginated_relation.order_values).to be_present
          expect(paginated_relation.order_values.first).to be_ascending
          expect(paginated_relation.order_values.first.expr.name).to eq 'id'
        end

        it 'is present it does not add anything' do
          paginated_relation = subject.paginate(resource.order(created_at: :desc))

          expect(paginated_relation.order_values).to be_present
          expect(paginated_relation.order_values.first).to be_descending
          expect(paginated_relation.order_values.first.expr.name).to eq 'created_at'
        end
      end
    end

    context 'when resource empty' do
      describe 'first page' do
        let(:query) { base_query.merge(page: 1, per_page: 2) }

        it 'returns appropriate amount of resources' do
          expect(subject.paginate(resource).count).to eq 0
        end

        it 'adds appropriate headers' do
          expect_header('X-Total', '0')
          expect_header('X-Total-Pages', '1')
          expect_header('X-Per-Page', '2')
          expect_header('X-Page', '1')
          expect_header('X-Next-Page', '')
          expect_header('X-Prev-Page', '')

          expect_header('Link', anything) do |_key, val|
            expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 1).to_query}>; rel="first"))
            expect(val).to include(%Q(<#{incoming_api_projects_url}?#{query.merge(page: 1).to_query}>; rel="last"))
            expect(val).not_to include('rel="prev"')
            expect(val).not_to include('rel="next"')
            expect(val).not_to include('page=0')
          end

          subject.paginate(resource)
        end
      end
    end
  end

  def expect_header(*args, &block)
    expect(subject).to receive(:header).with(*args, &block)
  end

  def expect_no_header(*args, &block)
    expect(subject).not_to receive(:header).with(*args)
  end

  def expect_message(method)
    expect(subject).to receive(method)
      .at_least(:once).and_return(value)
  end
end
