# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe ClearStaleLastRolloutFailedAtOnZoektEnabledNamespaces,
  migration: :gitlab_main_org,
  feature_category: :global_search do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:enabled_namespaces) { table(:zoekt_enabled_namespaces) }
  let(:replicas) { table(:zoekt_replicas) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }
  let(:failed_at) { Time.zone.parse('2026-10-02 01:39:02 UTC') }

  def create_enabled_namespace(replica_count:, override: nil, last_rollout_failed_at: failed_at)
    namespace = namespaces.create!(
      name: "group-#{SecureRandom.hex(4)}", path: "group-#{SecureRandom.hex(4)}",
      type: 'Group', organization_id: organization.id
    )
    enabled_namespace = enabled_namespaces.create!(
      root_namespace_id: namespace.id,
      number_of_replicas_override: override,
      last_rollout_failed_at: last_rollout_failed_at
    )

    replica_count.times do
      replicas.create!(zoekt_enabled_namespace_id: enabled_namespace.id, namespace_id: namespace.id, state: 10)
    end

    enabled_namespace
  end

  describe '#up' do
    it 'clears the failure only for namespaces that have all their replicas', :aggregate_failures do
      provisioned = create_enabled_namespace(replica_count: 1)
      without_replicas = create_enabled_namespace(replica_count: 0)
      short_of_override = create_enabled_namespace(replica_count: 1, override: 2)
      meets_override = create_enabled_namespace(replica_count: 2, override: 2)
      above_override = create_enabled_namespace(replica_count: 2, override: 1)
      never_failed = create_enabled_namespace(replica_count: 1, last_rollout_failed_at: nil)

      migrate!

      expect(provisioned.reload.last_rollout_failed_at).to be_nil
      expect(meets_override.reload.last_rollout_failed_at).to be_nil
      expect(above_override.reload.last_rollout_failed_at).to be_nil
      expect(never_failed.reload.last_rollout_failed_at).to be_nil
      expect(without_replicas.reload.last_rollout_failed_at).to eq(failed_at)
      expect(short_of_override.reload.last_rollout_failed_at).to eq(failed_at)
    end

    context 'when the default number of replicas is set' do
      before do
        table(:application_settings).create!(zoekt_settings: { zoekt_default_number_of_replicas: 2 })
      end

      it 'keeps the failure for namespaces below the default', :aggregate_failures do
        below_default = create_enabled_namespace(replica_count: 1)
        meets_default = create_enabled_namespace(replica_count: 2)

        migrate!

        expect(below_default.reload.last_rollout_failed_at).to eq(failed_at)
        expect(meets_default.reload.last_rollout_failed_at).to be_nil
      end
    end

    context 'when the application settings do not set the default number of replicas' do
      before do
        table(:application_settings).create!(zoekt_settings: {})
      end

      it 'uses one replica as the default' do
        provisioned = create_enabled_namespace(replica_count: 1)

        migrate!

        expect(provisioned.reload.last_rollout_failed_at).to be_nil
      end
    end

    context 'when namespaces span multiple batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'clears the failure in every batch', :aggregate_failures do
        first = create_enabled_namespace(replica_count: 1)
        without_replicas = create_enabled_namespace(replica_count: 0)
        last = create_enabled_namespace(replica_count: 1)

        migrate!

        expect(first.reload.last_rollout_failed_at).to be_nil
        expect(last.reload.last_rollout_failed_at).to be_nil
        expect(without_replicas.reload.last_rollout_failed_at).to eq(failed_at)
      end
    end
  end
end
