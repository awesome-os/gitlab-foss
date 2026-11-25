# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OrganizationAwareStatementCache, feature_category: :organization do
  let_it_be(:organization_a) { create(:organization) }
  let_it_be(:organization_b) { create(:organization) }

  let(:isolated_organization) { true }

  let(:model) do
    Class.new(ApplicationRecord) do
      self.table_name = :users
    end
  end

  let(:connection) { model.connection }
  let(:key) { :test_statement_key }

  # A valid Arel block that StatementCache.create can accept
  let(:block) { proc { |params| model.where(id: params.bind).limit(1) } }

  before do
    allow(::Gitlab::Organizations::Isolation).to receive(:enabled?).and_return(isolated_organization)
  end

  def stored_cache_keys
    model.instance_variable_get(:@find_by_statement_cache)[connection.prepared_statements].keys
  end

  describe '#cached_find_by_statement' do
    context 'when isolation is not enabled' do
      let(:isolated_organization) { false }

      it 'stores the entry under the plain key' do
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys).to contain_exactly(key)
      end

      it 'reuses the same cache entry on repeated calls' do
        model.cached_find_by_statement(connection, key, &block)
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys.count { |k| k == key }).to eq(1)
      end

      it 'does not duplicate entries per organization' do
        stub_current_organization(organization_a)
        model.cached_find_by_statement(connection, key, &block)

        stub_current_organization(organization_b)
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys).to contain_exactly(key)
      end
    end

    context 'when isolation is enabled' do
      before do
        stub_current_organization(organization_a)
      end

      it 'stores the entry under a key scoped to the organization' do
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys).to include([key, organization_a.id])
      end

      it 'reuses the same cache entry within the same organization' do
        model.cached_find_by_statement(connection, key, &block)
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys.count { |k| k == [key, organization_a.id] }).to eq(1)
      end

      it 'uses a separate cache entry for a different organization' do
        model.cached_find_by_statement(connection, key, &block)

        stub_current_organization(organization_b)
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys).to include([key, organization_a.id], [key, organization_b.id])
      end
    end

    # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268682#note_4241115830
    context 'when allow_query_scoping is entered and left', :request_store do
      let_it_be(:isolated_organization) { create(:organization, :isolated) }
      let_it_be(:other_project) { create(:project, organization: organization_b) }

      before do
        allow(::Gitlab::Organizations::Isolation).to receive(:enabled?).and_call_original
        stub_feature_flags(data_isolation: false)
        stub_current_organization(isolated_organization)
        Project.initialize_find_by_cache
      end

      it 'does not reuse the unscoped statement inside the block' do
        expect(Project.find_by(id: other_project.id)).to eq(other_project)

        ::Gitlab::Organizations::Isolation.allow_query_scoping do
          expect(Project.find_by(id: other_project.id)).to be_nil
        end
      end

      it 'does not reuse the scoped statement outside the block' do
        ::Gitlab::Organizations::Isolation.allow_query_scoping do
          expect(Project.find_by(id: other_project.id)).to be_nil
        end

        expect(Project.find_by(id: other_project.id)).to eq(other_project)
      end
    end

    context 'when data isolation is disabled for the block' do
      before do
        # The real predicate: it is what honours the context, and a statement built
        # inside the block carries no organization filter to key on.
        allow(::Gitlab::Organizations::Isolation).to receive(:enabled?).and_call_original
        stub_feature_flags(data_isolation: true)
        stub_current_organization(organization_a)
        allow(organization_a).to receive(:isolated?).and_return(true)
      end

      it 'stores the entry under the plain key' do
        ::Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation do
          model.cached_find_by_statement(connection, key, &block)
        end

        expect(stored_cache_keys).to contain_exactly(key)
      end
    end

    context 'when the isolation state is not already loaded' do
      let(:organization) { Organizations::Organization.find(create(:organization, :isolated).id) }

      before do
        # Not stub_current_organization: that helper preloads the isolation record,
        # which hides the lookup this method has to make while building the key.
        allow(::Gitlab::Organizations::Isolation).to receive(:enabled?).and_call_original
        stub_feature_flags(data_isolation: true)
        allow(::Current).to receive_messages(organization: organization, organization_assigned: true)
      end

      it 'resolves the isolation record without re-entering the statement cache' do
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys).to include([key, organization.id])
      end
    end

    context 'when isolation becomes enabled' do
      let(:isolated_organization) { false }

      before do
        stub_current_organization(organization_a)
      end

      it 'uses a separate cache entry from the one built while isolation was disabled' do
        model.cached_find_by_statement(connection, key, &block)

        allow(::Gitlab::Organizations::Isolation).to receive(:enabled?).and_return(true)
        model.cached_find_by_statement(connection, key, &block)

        expect(stored_cache_keys).to include(key, [key, organization_a.id])
      end
    end
  end
end
