# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RemoveBitbucketImportIssueWorkerJobInstances, :migration, feature_category: :importers do
  describe '#up' do
    it 'removes the jobs of the deprecated Bitbucket issue import workers' do
      expect_next_instance_of(described_class) do |migration|
        expect(migration).to receive(:sidekiq_remove_jobs).with(
          job_klasses: %w[
            Gitlab::BitbucketImport::ImportIssueWorker
            Gitlab::BitbucketImport::ImportIssueNotesWorker
            Gitlab::BitbucketImport::Stage::ImportIssuesWorker
            Gitlab::BitbucketImport::Stage::ImportIssuesNotesWorker
          ]
        )
      end

      migrate!
    end
  end
end
