# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ImportIssuesCsvWorker, feature_category: :team_planning do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:upload) { create(:upload, :with_file) }

  let(:worker) { described_class.new }

  describe '#perform' do
    it 'destroys the upload without importing anything' do
      expect { worker.perform(user.id, project.id, upload.id) }.not_to change { Issue.count }

      expect { upload.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'does nothing when the upload no longer exists' do
      expect { worker.perform(user.id, project.id, non_existing_record_id) }.not_to raise_error
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [user.id, project.id, upload.id] }
    end
  end
end
