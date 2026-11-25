# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceDesk::PostNoticeService, :clean_gitlab_redis_rate_limiting, feature_category: :service_desk do
  let_it_be(:project) { create(:project, service_desk_enabled: true) }
  let_it_be(:support_bot) { Users::Internal.in_organization(project.organization_id).support_bot }
  let_it_be_with_reload(:work_item) { create(:work_item, :ticket, project: project, author: support_bot) }

  let(:throttle_key) { :service_desk_suppression_notice }

  def post_notice(target = work_item, key: throttle_key)
    described_class.new(target, note: 'Something was skipped.', throttle_key: key).execute
  end

  before do
    allow(::ServiceDesk).to receive(:enabled?).and_return(true)
  end

  describe '#execute' do
    it 'posts an internal note authored by the support bot', :aggregate_failures do
      expect { post_notice }.to change { work_item.notes.count }.by(1)

      note = work_item.notes.last
      expect(note).to be_internal
      expect(note.author).to eq(support_bot)
      expect(note.note).to eq('Something was skipped.')
    end

    it 'returns nil' do
      expect(post_notice).to be_nil
    end

    it 'does not post a second notice for the same work item within the window' do
      post_notice

      expect { post_notice }.not_to change { work_item.notes.count }
    end

    it 'posts a notice for a different work item' do
      other_work_item = create(:work_item, :ticket, project: project, author: support_bot)
      post_notice

      expect { post_notice(other_work_item) }.to change { other_work_item.notes.count }.by(1)
    end

    it 'throttles each throttle key separately' do
      post_notice

      expect { post_notice(key: :service_desk_external_participant_limit_notice) }
        .to change { work_item.notes.count }.by(1)
    end

    # The support bot loses :mark_note_as_internal when Service Desk is disabled
    # for the project, and Notes::CreateService would then save a public note.
    context 'when the support bot cannot mark the note as internal' do
      before do
        allow(::ServiceDesk).to receive(:enabled?).and_return(false)
      end

      it 'does not post a notice' do
        expect { post_notice }.not_to change { work_item.notes.count }
      end

      it 'does not use the throttle budget' do
        post_notice

        allow(::ServiceDesk).to receive(:enabled?).and_return(true)

        expect { post_notice }.to change { work_item.notes.count }.by(1)
      end
    end
  end
end
