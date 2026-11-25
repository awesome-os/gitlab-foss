# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineTriggers::UpdateService, feature_category: :continuous_integration do
  let_it_be_with_reload(:project) { create(:project, :public) }
  let_it_be_with_reload(:user) { create(:user, maintainer_of: project) }
  let_it_be(:another_maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be_with_reload(:pipeline_trigger) do
    create(:ci_trigger, project: project, owner: user, description: "Old description")
  end

  subject(:service) { described_class.new(user: user, trigger: pipeline_trigger, description: description) }

  before_all do
    pipeline_trigger.reload
  end

  describe "execute" do
    context 'when user does not have permission' do
      subject(:service) { described_class.new(trigger: pipeline_trigger, user: another_maintainer, description: {}) }

      it 'returns ServiceResponse.error' do
        response = service.execute

        expect(response).to be_a(ServiceResponse)
        expect(response.error?).to be(true)

        error_message = _('The current user is not authorized to update the pipeline trigger token')
        expect(response.message).to eq(error_message)
        expect(response.errors).to match_array([error_message])
      end
    end

    context 'when user has permission' do
      let(:description) { 'My updated description' }

      it 'updates database values with passed description param' do
        expect { service.execute }
          .to change { pipeline_trigger.reload.description }.from('Old description').to('My updated description')
      end

      it 'returns ServiceResponse.success' do
        response = service.execute

        expect(response).to be_a(ServiceResponse)
        expect(response.success?).to be(true)
        expect(response.payload[:trigger].description).to eq('My updated description')
      end

      context 'when update fails' do
        before do
          allow(pipeline_trigger).to receive(:update).and_return(false)
        end

        it 'returns ServiceResponse.error' do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response.error?).to be(true)
          expect(response.message).to eq('Attempted to update the pipeline trigger token but failed')
        end
      end
    end
  end

  context 'with rate limiting', :clean_gitlab_redis_rate_limiting, :freeze_time do
    let(:unauthorized_user) { developer }

    def grant_access(member)
      project.add_maintainer(member)
    end

    def execute_service(actor = user, target_project = project)
      trigger = create(:ci_trigger, project: target_project, owner: actor || user)

      described_class.new(user: actor, trigger: trigger, description: 'updated').execute
    end

    it_behaves_like 'a rate limited pipeline trigger management action'

    context 'when the rate limit is reached' do
      before do
        stub_application_setting(pipeline_trigger_management_limit_per_user: 1)
        execute_service
      end

      it 'leaves the trigger token unchanged' do
        described_class.new(user: user, trigger: pipeline_trigger, description: 'updated').execute

        expect(pipeline_trigger.reload.description).to eq('Old description')
      end
    end
  end
end
