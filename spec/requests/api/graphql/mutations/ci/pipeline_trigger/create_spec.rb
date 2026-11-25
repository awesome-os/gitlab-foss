# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'PipelineTriggerCreate', feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }

  let(:mutation) { graphql_mutation(:pipeline_trigger_create, params) }
  let(:project_path) { project.full_path }
  let(:description) { 'Ye old pipeline trigger token' }

  let(:params) do
    {
      project_path: project_path,
      description: description
    }
  end

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when unauthorized' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when authorized' do
    before_all do
      project.add_owner(current_user)
    end

    context 'when only create_trigger is denied' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(current_user, :create_trigger, anything).and_return(false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_trigger do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:pipeline_trigger_create, { project_path: project.full_path, description: description },
          'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the params are invalid' do
      let(:description) { nil }

      it 'does not create a pipeline trigger token and returns an error' do
        expect { subject }.not_to change { project.triggers.count }
        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors.to_s).to include('provided invalid value for description (Expected value to not be null)')
      end
    end

    context 'when the params are valid' do
      it 'creates a pipeline trigger token' do
        expect { subject }.to change { project.triggers.count }.by(1)
        expect(graphql_errors.to_s).to eql("")
      end

      it 'returns the new pipeline trigger token' do
        subject

        expect(graphql_data_at(:pipeline_trigger_create, :pipeline_trigger)).to match a_hash_including(
          'owner' => a_hash_including(
            'id' => current_user.to_global_id.to_s,
            'username' => current_user.username,
            'name' => current_user.name
          ),
          'description' => description,
          "canAccessProject" => true,
          "hasTokenExposed" => true,
          "lastUsed" => nil
        )
      end
    end
  end

  context 'when the pipeline trigger management rate limit is exceeded', :clean_gitlab_redis_rate_limiting,
    :freeze_time do
    before_all do
      project.add_owner(current_user)
    end

    before do
      stub_application_setting(pipeline_trigger_management_limit_per_user: 1)
    end

    it 'surfaces the throttle in the mutation errors', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: current_user)
      expect(graphql_mutation_response(:pipeline_trigger_create)['errors']).to be_empty

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_mutation_response(:pipeline_trigger_create)['pipelineTrigger']).to be_nil
      expect(graphql_mutation_response(:pipeline_trigger_create)['errors'])
        .to contain_exactly(_('This endpoint has been requested too many times. Try again later.'))
    end
  end
end
