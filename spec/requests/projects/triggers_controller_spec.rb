# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TriggersController, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:trigger) { create(:ci_trigger, project: project, owner: user) }

  before do
    sign_in(user)
  end

  describe 'GET #index' do
    it 'redirects to the CI/CD settings page' do
      get project_triggers_path(project)

      expect(response).to redirect_to(project_settings_ci_cd_path(project, anchor: 'js-pipeline-triggers'))
    end

    context 'when the user cannot read triggers' do
      before do
        disallow(:read_trigger, project)
      end

      it 'returns not found' do
        get project_triggers_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    subject(:create_trigger) { post project_triggers_path(project), params: { trigger: { description: 'new' } } }

    it 'creates a trigger' do
      expect { create_trigger }.to change { project.triggers.count }.by(1)
    end

    context 'when the user cannot create triggers' do
      before do
        disallow(:create_trigger, project)
      end

      it 'returns not found and does not create a trigger' do
        expect { create_trigger }.not_to change { project.triggers.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT #update' do
    subject(:update_trigger) do
      put project_trigger_path(project, trigger), params: { trigger: { description: 'updated' } }
    end

    it 'updates the trigger' do
      expect { update_trigger }.to change { trigger.reload.description }.to('updated')
    end

    context 'when the user cannot update triggers' do
      before do
        disallow(:update_trigger, an_object_having_attributes(id: trigger.id))
      end

      it 'returns not found and does not update the trigger' do
        expect { update_trigger }.not_to change { trigger.reload.description }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_trigger) { delete project_trigger_path(project, trigger) }

    it 'deletes the trigger' do
      expect { destroy_trigger }.to change { project.triggers.count }.by(-1)
    end

    context 'when the user cannot delete triggers' do
      before do
        disallow(:delete_trigger, an_object_having_attributes(id: trigger.id))
      end

      it 'returns not found and does not delete the trigger' do
        expect { destroy_trigger }.not_to change { project.triggers.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  def disallow(permission, subject)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, permission, subject).and_return(false)
  end
end
