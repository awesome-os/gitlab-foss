# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'PipelineTriggerUpdate', feature_category: :continuous_integration do
  include GraphqlHelpers

  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:current_user, freeze: false) { build(:user) }
  let_it_be(:project, freeze: false) { build(:project) }
  let_it_be(:old_description) { "Boring old description." }
  let_it_be_with_reload(:trigger) do
    create(:ci_trigger, owner: current_user, project: project, description: old_description)
  end

  let(:mutation) { graphql_mutation(:pipeline_trigger_update, params) }
  let(:new_description) { 'Awesome new description!' }

  let(:params) do
    {
      id: trigger.to_global_id.to_s,
      description: new_description
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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_trigger do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:pipeline_trigger_update, { id: trigger.to_global_id.to_s, description: new_description },
          'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the params are invalid' do
      let(:new_description) { nil }

      it_behaves_like 'an invalid argument to the mutation', argument_name: 'description'

      it 'does not update a pipeline trigger token' do
        expect { subject }.not_to change { trigger }
        expect(response).to have_gitlab_http_status(:success)
      end
    end

    context 'when the params are valid' do
      it_behaves_like 'a working GraphQL mutation'

      it 'updates the pipeline trigger token' do
        expect { subject }.to change { trigger.reload.description }.to(new_description)

        expect(graphql_errors).to be_blank
      end

      it 'returns the updated trigger token' do
        subject

        expect(graphql_data_at(:pipeline_trigger_update, :pipeline_trigger)).to match a_hash_including(
          'owner' => a_hash_including(
            'id' => current_user.to_global_id.to_s,
            'username' => current_user.username,
            'name' => current_user.name
          ),
          'description' => new_description,
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
      expect(graphql_mutation_response(:pipeline_trigger_update)['errors']).to be_empty

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_mutation_response(:pipeline_trigger_update)['errors'])
        .to contain_exactly(_('This endpoint has been requested too many times. Try again later.'))
    end
  end
end
