# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RemoveProvisionSecretsManagerWorkerJobInstances, :migration, feature_category: :secrets_management do
  describe '#up' do
    it 'removes the jobs of the deprecated secrets manager provision workers' do
      expect_next_instance_of(described_class) do |migration|
        expect(migration).to receive(:sidekiq_remove_jobs).with(
          job_klasses: %w[
            SecretsManagement::ProvisionProjectSecretsManagerWorker
            SecretsManagement::ProvisionGroupSecretsManagerWorker
          ]
        )
      end

      migrate!
    end
  end
end
