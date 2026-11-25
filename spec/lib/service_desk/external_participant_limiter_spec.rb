# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceDesk::ExternalParticipantLimiter, :clean_gitlab_redis_rate_limiting,
  feature_category: :service_desk do
  let_it_be(:project) { create(:project, service_desk_enabled: true) }

  let(:limiter) { described_class.new(project) }

  describe '#allow?' do
    # Without plans, every namespace resolves the default plan, which has no cap.
    it 'allows every email without counting it' do
      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)

      expect(limiter.allow?('user@example.com')).to be(true)
    end
  end

  describe '#post_limit_notice' do
    let_it_be(:work_item) { create(:work_item, :ticket, project: project) }

    it 'posts a notice throttled per work item' do
      expect_next_instance_of(
        ServiceDesk::PostNoticeService,
        work_item,
        note: a_string_including('daily limit for new email participants'),
        throttle_key: :service_desk_external_participant_limit_notice
      ) do |service|
        expect(service).to receive(:execute)
      end

      limiter.post_limit_notice(work_item)
    end
  end
end
