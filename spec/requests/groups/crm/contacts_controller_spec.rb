# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Crm::ContactsController do
  let_it_be(:user) { create(:user) }

  shared_examples 'response with 404 status' do
    it 'returns 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'ok response with index template' do
    it 'renders the index template' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end

  shared_examples 'ok response with index template if authorized' do
    context 'private group' do
      let(:group) { create(:group, :private, :crm_enabled) }

      context 'with authorized user' do
        before do
          group.add_reporter(user)
          sign_in(user)
        end

        context 'when crm_enabled is true' do
          it_behaves_like 'ok response with index template'
        end

        context 'when crm_enabled is false' do
          let(:group) { create(:group, :private) }

          it_behaves_like 'response with 404 status'
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(customer_relations: false)
          end

          it_behaves_like 'response with 404 status'
        end

        context 'when subgroup' do
          let(:group) { create(:group, :private, :crm_enabled, parent: create(:group)) }

          it_behaves_like 'response with 404 status'
        end
      end

      context 'with unauthorized user' do
        before do
          sign_in(user)
        end

        it_behaves_like 'response with 404 status'
      end

      context 'with anonymous user' do
        it 'blah' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end

    context 'public group' do
      let(:group) { create(:group, :public, :crm_enabled) }

      context 'with anonymous user' do
        it_behaves_like 'response with 404 status'
      end
    end
  end

  describe 'GET #index' do
    subject { get group_crm_contacts_path(group) }

    it_behaves_like 'ok response with index template if authorized'
  end

  describe 'GET #new' do
    subject { get new_group_crm_contact_path(group) }

    it_behaves_like 'ok response with index template if authorized'
  end

  describe 'GET #edit' do
    subject { get edit_group_crm_contact_path(group, id: 1) }

    it_behaves_like 'ok response with index template if authorized'
  end
end
