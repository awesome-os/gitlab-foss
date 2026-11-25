# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineTriggers::DestroyService, feature_category: :continuous_integration do
  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project) }

    let(:pipeline_trigger) { create(:ci_trigger, project: project, owner: user) }

    subject(:service) { described_class.new(user: user, trigger: pipeline_trigger) }

    before_all do
      project.add_maintainer(user)
      project.add_developer(developer)
    end

    context 'when user does not have permission' do
      subject(:service) { described_class.new(user: developer, trigger: pipeline_trigger) }

      it 'returns an error' do
        response = service.execute

        expect(response).to be_a(ServiceResponse)
        expect(response.error?).to be(true)

        error_message = _('The current user is not authorized to manage the pipeline trigger token')
        expect(response.message).to eq(error_message)
        expect(response.errors).to match_array([error_message])
      end
    end

    context 'when user has permission' do
      context 'when only delete_trigger is denied' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :delete_trigger, pipeline_trigger).and_return(false)
        end

        it 'returns an error' do
          expect(service.execute).to be_error
        end
      end

      it 'deletes the pipeline trigger token' do
        response = service.execute

        expect(response).to be_a(ServiceResponse)
        expect(response.success?).to be(true)
        expect(Ci::Trigger.find_by(id: pipeline_trigger.id)).to be_nil
      end

      context 'when destroy fails' do
        before do
          allow(pipeline_trigger).to receive(:destroy).and_return(false)
        end

        it 'returns ServiceResponse.error' do
          result = service.execute

          expect(result).to be_a(ServiceResponse)
          expect(result.error?).to be(true)
          expect(result.message).to eq('Attempted to destroy the pipeline trigger token but failed')
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

        described_class.new(user: actor, trigger: trigger).execute
      end

      it_behaves_like 'a rate limited pipeline trigger management action'

      context 'when the rate limit is reached' do
        before do
          stub_application_setting(pipeline_trigger_management_limit_per_user: 1)
        end

        it 'keeps the trigger token once the allowance is spent' do
          execute_service

          described_class.new(user: user, trigger: pipeline_trigger).execute

          expect(Ci::Trigger.exists?(pipeline_trigger.id)).to be(true)
        end

        it 'shares the allowance with creating a trigger token', :aggregate_failures do
          create_response = Ci::PipelineTriggers::CreateService
            .new(project: project, user: user, description: 'desc')
            .execute
          expect(create_response).to be_success

          expect(execute_service.reason).to eq(:rate_limited)
        end
      end
    end
  end
end
