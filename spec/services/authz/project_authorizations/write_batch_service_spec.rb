# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ProjectAuthorizations::WriteBatchService, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:projects) { create_list(:project, 4) }

  let(:project_ids) { projects.map(&:id) }

  def rows_for(user)
    ProjectAuthorization.where(user: user).pluck(:project_id, :access_level)
  end

  before do
    ProjectAuthorization.delete_all
  end

  describe '.unchanged?' do
    using RSpec::Parameterized::TableSyntax

    where(:levels, :level, :unchanged) do
      [30]     | 30                         | true
      []       | nil                        | true
      []       | Gitlab::Access::NO_ACCESS  | true
      [30]     | 40                         | false
      [30, 30] | 30                         | false
      [30]     | nil                        | false
    end

    with_them do
      it { expect(described_class.unchanged?(levels, level)).to be(unchanged) }
    end
  end

  describe '.lock_sql' do
    it 'locks on the IDs, sorted, in the namespace' do
      sql = described_class.lock_sql(described_class::PROJECT_LOCK_NAMESPACE, [3, 1, 3])

      expect(sql).to include('ARRAY[1,3]')
      expect(sql).to include("pg_advisory_xact_lock(#{described_class::PROJECT_LOCK_NAMESPACE}, id)")
    end

    it 'takes shared locks when asked' do
      expect(described_class.lock_sql(described_class::USER_LOCK_NAMESPACE, [1], shared: true))
        .to include("pg_advisory_xact_lock_shared(#{described_class::USER_LOCK_NAMESPACE}, id)")
    end

    it 'raises for an ID too large for an int4 key' do
      expect { described_class.lock_sql(described_class::USER_LOCK_NAMESPACE, [1, described_class::MAX_LOCK_KEY + 1]) }
        .to raise_error(ArgumentError, /too large/)
    end
  end

  # Records each advisory lock statement with its transaction.
  def record_locks
    locks = []
    allow(ProjectAuthorization.connection).to receive(:execute).and_call_original
    allow(ProjectAuthorization.connection).to receive(:execute).with(/pg_advisory_xact_lock/) do |sql|
      locks << {
        function: sql[/pg_advisory_xact_lock(_shared)?/],
        namespace: sql[/pg_advisory_xact_lock(?:_shared)?\((\d+),/, 1].to_i,
        ids: sql[/ARRAY\[([\d,]+)\]/, 1].split(',').map(&:to_i),
        transaction: ProjectAuthorization.connection.current_transaction
      }
      ProjectAuthorization.connection.exec_query(sql)
    end
    locks
  end

  describe '.wait_for_user_writers' do
    it "takes the user's lock exclusively, so it waits for project writers holding it shared" do
      locks = record_locks

      described_class.wait_for_user_writers(user.id)

      expect(locks.map { |lock| lock.slice(:function, :namespace, :ids) }).to eq([
        { function: 'pg_advisory_xact_lock', namespace: described_class::USER_LOCK_NAMESPACE, ids: [user.id] }
      ])
    end

    it 'refuses to run inside a transaction' do
      ProjectAuthorization.transaction do
        expect { described_class.wait_for_user_writers(user.id) }
          .to raise_error(RuntimeError, /outside a transaction/)
      end
    end
  end

  describe '.wait_for_project_writers' do
    let(:project_id) { projects[0].id }

    it "takes the project's lock shared, then the users' locks shared, in one transaction" do
      locks = record_locks

      described_class.wait_for_project_writers(project_id, [other_user.id, user.id])

      expect(locks.map { |lock| lock.slice(:function, :namespace, :ids) }).to eq([
        { function: 'pg_advisory_xact_lock_shared', namespace: described_class::PROJECT_LOCK_NAMESPACE,
          ids: [project_id] },
        { function: 'pg_advisory_xact_lock_shared', namespace: described_class::USER_LOCK_NAMESPACE,
          ids: [user.id, other_user.id].sort }
      ])
      expect(locks.pluck(:transaction).uniq.size).to eq(1)
    end

    it "takes only the project's lock for no users" do
      locks = record_locks

      described_class.wait_for_project_writers(project_id, [])

      expect(locks.pluck(:namespace)).to eq([described_class::PROJECT_LOCK_NAMESPACE])
    end

    it 'takes at most BATCH_SIZE users per transaction, the project with the first' do
      stub_const("#{described_class}::BATCH_SIZE", 1)
      locks = record_locks

      described_class.wait_for_project_writers(project_id, [user.id, other_user.id, user.id])

      expect(locks.map { |lock| [lock[:namespace], lock[:ids]] }).to eq([
        [described_class::PROJECT_LOCK_NAMESPACE, [project_id]],
        [described_class::USER_LOCK_NAMESPACE, [user.id]],
        [described_class::USER_LOCK_NAMESPACE, [other_user.id]]
      ])
      expect(locks.map { |lock| lock[:transaction] }.chunk_while { |a, b| a.equal?(b) }.map(&:size)).to eq([2, 1])
    end

    it 'yields in the last transaction, once every lock is taken, and returns the value' do
      stub_const("#{described_class}::BATCH_SIZE", 1)
      locks = record_locks
      yielded_in = nil

      result = described_class.wait_for_project_writers(project_id, [user.id, other_user.id]) do
        yielded_in = [locks.size, ProjectAuthorization.connection.current_transaction]
        :read
      end

      expect(result).to eq(:read)
      expect(yielded_in.first).to eq(3)
      expect(yielded_in.last).to equal(locks.last[:transaction])
    end

    it 'refuses to run inside a transaction' do
      ProjectAuthorization.transaction do
        expect { described_class.wait_for_project_writers(project_id, [user.id]) }
          .to raise_error(RuntimeError, /outside a transaction/)
      end
    end
  end

  describe '.read_together' do
    let(:session) { ::Gitlab::Database::LoadBalancing::SessionMap.current(ProjectAuthorization.load_balancer) }

    it 'returns the block value' do
      expect(described_class.read_together { :value }).to eq(:value)
    end

    context 'when reads would go to a replica' do
      before do
        allow(session).to receive(:use_primary?).and_return(false)
        allow(ProjectAuthorization.load_balancer).to receive(:primary_only?).and_return(false)
      end

      it 'opens no transaction' do
        expect(ProjectAuthorization).not_to receive(:transaction)

        described_class.read_together { :value }
      end
    end

    context 'when only the primary is configured' do
      before do
        allow(session).to receive(:use_primary?).and_return(false)
        allow(ProjectAuthorization.load_balancer).to receive(:primary_only?).and_return(true)
      end

      it 'reads in one transaction' do
        expect(ProjectAuthorization).to receive(:transaction).and_call_original

        described_class.read_together { :value }
      end
    end

    context 'when the session sticks to the primary' do
      before do
        allow(session).to receive(:use_primary?).and_return(true)
        allow(ProjectAuthorization.load_balancer).to receive(:primary_only?).and_return(false)
      end

      it 'reads in one transaction' do
        expect(ProjectAuthorization).to receive(:transaction).and_call_original

        described_class.read_together { :value }
      end
    end
  end

  describe '#initialize' do
    it 'needs exactly one of user_id and project_id' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(user_id: 1, project_id: 1) }.to raise_error(ArgumentError)
    end
  end

  describe '#execute' do
    context 'for one user' do
      subject(:service) { described_class.new(user_id: user.id) }

      before do
        ProjectAuthorization.insert_all([
          { user_id: user.id, project_id: projects[0].id, access_level: 30, is_unique: true },
          { user_id: user.id, project_id: projects[1].id, access_level: 30, is_unique: true },
          { user_id: user.id, project_id: projects[2].id, access_level: 20, is_unique: true }
        ])
        ProjectAuthorization.insert_all([
          { user_id: user.id, project_id: projects[2].id, access_level: 10, is_unique: false }
        ])
      end

      it 'adds, changes, removes and rewrites duplicates to match the calculation, and leaves others alone' do
        levels = { projects[0].id => 30, projects[1].id => 40, projects[2].id => 20, projects[3].id => 10 }

        result = service.execute(project_ids) { |ids| levels.slice(*ids) }

        expect(rows_for(user)).to contain_exactly(
          [projects[0].id, 30], [projects[1].id, 40], [projects[2].id, 20], [projects[3].id, 10]
        )
        expect(result).to have_attributes(rows_added: 3, rows_deleted: 3)
      end

      it 'removes rows the calculation no longer grants' do
        service.execute(project_ids.first(2)) { |_| { projects[0].id => Gitlab::Access::NO_ACCESS } }

        expect(rows_for(user).map(&:first)).to contain_exactly(projects[2].id, projects[2].id)
      end

      it "doesn't touch rows outside the given IDs" do
        service.execute([projects[3].id]) { |_| {} }

        expect(rows_for(user).size).to eq(4)
      end

      it 'takes the lock before calculating, and calculates inside the transaction' do
        queries = []
        callback = ->(*, payload) { queries << payload[:sql] }

        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          service.execute([projects[0].id]) do |ids|
            queries << :calculate
            expect(ProjectAuthorization.inside_transaction?).to be(true)

            { ids.first => 40 }
          end
        end

        lock = queries.index { |sql| sql.is_a?(String) && sql.include?('pg_advisory_xact_lock') }
        expect(lock).to be < queries.index(:calculate)
      end

      it 'retries a chunk whose lock times out, then gives up' do
        calls = 0
        allow(ProjectAuthorization.connection).to receive(:execute).and_call_original
        allow(ProjectAuthorization.connection).to receive(:execute).with(/pg_advisory_xact_lock/) do
          calls += 1
          raise ActiveRecord::LockWaitTimeout
        end

        expect { service.execute([projects[0].id]) { |_| {} } }.to raise_error(ActiveRecord::LockWaitTimeout)
        expect(calls).to eq(described_class::LOCK_ATTEMPTS)
      end

      it 'publishes added and removed notifications for the changed pairs, after the commit' do
        events = []
        allow(Gitlab::EventStore).to receive(:publish_group) do |group|
          expect(ProjectAuthorization.inside_transaction?).to be(false)
          events.concat(group)
        end

        service.execute(project_ids) { |_| { projects[3].id => 30 } }

        removed = events.grep(ProjectAuthorizations::AuthorizationsRemovedEvent).map(&:data)
        added = events.grep(ProjectAuthorizations::AuthorizationsAddedEvent).map(&:data)
        expect(removed).to match_array(
          projects.first(3).map { |project| { project_id: project.id, user_ids: [user.id] } }
        )
        expect(added).to contain_exactly(
          { project_ids: match_array(project_ids), user_ids: [user.id] }
        )
      end

      it 'publishes nothing for duplicates rewritten at the level they already granted' do
        expect(Gitlab::EventStore).not_to receive(:publish_group)

        service.execute([projects[2].id]) { |_| { projects[2].id => 20 } }

        expect(rows_for(user).count { |id, _| id == projects[2].id }).to eq(1)
      end

      it 'keeps the written rows when publishing fails' do
        allow(Gitlab::EventStore).to receive(:publish_group).and_raise(StandardError)

        expect(Gitlab::ErrorTracking).to receive(:track_exception)
        expect(service.execute([projects[3].id]) { |_| { projects[3].id => 30 } })
          .to have_attributes(rows_added: 1)
        expect(rows_for(user)).to include([projects[3].id, 30])
      end

      it 'writes in chunks of at most BATCH_SIZE project IDs, each in its own transaction' do
        stub_const("#{described_class}::BATCH_SIZE", 3)
        chunks = []
        transactions = []

        service.execute(project_ids) do |ids|
          chunks << ids
          transactions << ProjectAuthorization.connection.current_transaction
          {}
        end

        expect(chunks).to eq([project_ids.first(3), project_ids.drop(3)])
        expect(transactions.uniq.size).to eq(2)
      end

      it 'writes nothing for a user that no longer exists' do
        expect(described_class.new(user_id: non_existing_record_id).execute([projects[0].id]) { |_| raise })
          .to have_attributes(rows_added: 0, rows_deleted: 0)
      end

      context 'when the user is being deleted' do
        before do
          UserCustomAttribute.set_deletion_started_at(user)
          User.find(user.id).block!
        end

        it 'deletes their rows on the given projects without calculating or publishing' do
          expect(Gitlab::EventStore).not_to receive(:publish_group)

          result = service.execute(project_ids.first(2)) { |_| raise 'calculated' }

          expect(rows_for(user).map(&:first)).to contain_exactly(projects[2].id, projects[2].id)
          expect(result).to have_attributes(rows_added: 0, rows_deleted: 2)
        end

        it 'checks under the lock' do
          queries = []
          callback = ->(*, payload) { queries << payload[:sql] }

          ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
            service.execute([projects[0].id]) { |_| {} }
          end

          lock = queries.index { |sql| sql.include?('pg_advisory_xact_lock') }
          check = queries.index { |sql| sql.include?('user_custom_attributes') }
          expect(lock).to be < check
        end

        it 'calculates as usual once the user is unblocked after a failed deletion' do
          User.find(user.id).activate!

          service.execute([projects[0].id]) { |_| { projects[0].id => 40 } }

          expect(rows_for(user)).to include([projects[0].id, 40])
        end
      end

      it 'calculates and publishes as usual for a blocked user not being deleted' do
        User.find(user.id).block!
        expect(Gitlab::EventStore).to receive(:publish_group).at_least(:once)

        service.execute([projects[0].id]) { |_| {} }

        expect(rows_for(user).map(&:first)).not_to include(projects[0].id)
      end
    end

    context 'for one project' do
      subject(:service) { described_class.new(project_id: projects[0].id) }

      it "locks the project exclusively, then every user shared in one statement, in user ID order" do
        locks = record_locks

        service.execute([other_user.id, user.id]) { |ids| ids.index_with(30) }

        expect(locks.map { |lock| lock.slice(:function, :namespace, :ids) }).to eq([
          { function: 'pg_advisory_xact_lock', namespace: described_class::PROJECT_LOCK_NAMESPACE,
            ids: [projects[0].id] },
          { function: 'pg_advisory_xact_lock_shared', namespace: described_class::USER_LOCK_NAMESPACE,
            ids: [user.id, other_user.id].sort }
        ])
        expect(locks.pluck(:transaction).uniq.size).to eq(1)
        expect(ProjectAuthorization.where(project: projects[0]).pluck(:user_id))
          .to contain_exactly(user.id, other_user.id)
      end

      it 'changes and removes rows to match the calculation' do
        ProjectAuthorization.insert_all([
          { user_id: user.id, project_id: projects[0].id, access_level: 30, is_unique: true },
          { user_id: other_user.id, project_id: projects[0].id, access_level: 30, is_unique: true }
        ])

        result = service.execute([user.id, other_user.id]) { |_| { user.id => 40 } }

        expect(ProjectAuthorization.where(project: projects[0]).pluck(:user_id, :access_level))
          .to contain_exactly([user.id, 40])
        expect(result).to have_attributes(rows_added: 1, rows_deleted: 2)
      end

      it "doesn't write rows for a user deleted meanwhile" do
        service.execute([non_existing_record_id]) { |ids| ids.index_with(30) }

        expect(ProjectAuthorization.where(project: projects[0])).to be_empty
      end

      it 'writes in chunks of at most BATCH_SIZE IDs, each in its own transaction' do
        stub_const("#{described_class}::BATCH_SIZE", 1)
        chunks = []
        transactions = []
        locked_in = []
        allow(ProjectAuthorization.connection).to receive(:execute).and_call_original
        allow(ProjectAuthorization.connection).to receive(:execute).with(/pg_advisory_xact_lock\(/) do |sql|
          locked_in << ProjectAuthorization.connection.current_transaction
          ProjectAuthorization.connection.exec_query(sql)
        end

        result = service.execute([user.id, other_user.id, user.id]) do |ids|
          chunks << ids
          transactions << ProjectAuthorization.connection.current_transaction
          ids.index_with(30)
        end

        expect(chunks).to eq([[user.id], [other_user.id]])
        expect(transactions.uniq.size).to eq(2)
        expect(locked_in).to eq(transactions)
        expect(result).to have_attributes(rows_added: 2, rows_deleted: 0)
      end
    end

    it 'returns no changes for no IDs' do
      expect(described_class.new(user_id: user.id).execute([]) { |_| raise })
        .to have_attributes(rows_added: 0, rows_deleted: 0)
    end

    it 'needs a block' do
      expect { described_class.new(user_id: user.id).execute([projects[0].id]) }.to raise_error(ArgumentError)
    end

    it 'refuses to run inside a transaction' do
      ProjectAuthorization.transaction do
        expect { described_class.new(user_id: user.id).execute([projects[0].id]) { |_| {} } }
          .to raise_error(RuntimeError, /outside a transaction/)
      end
    end

    it 'runs inside a transaction when the exclusive lease transaction check is skipped' do
      ProjectAuthorization.transaction do
        Gitlab::ExclusiveLease.skipping_transaction_check do
          expect { described_class.new(user_id: user.id).execute([projects[0].id]) { |_| {} } }.not_to raise_error
        end
      end
    end

    it 'ignores the skip outside tests, where after-commit callbacks set it' do
      stub_rails_env('production')

      ProjectAuthorization.transaction do
        Gitlab::ExclusiveLease.skipping_transaction_check do
          expect { described_class.new(user_id: user.id).execute([projects[0].id]) { |_| {} } }
            .to raise_error(RuntimeError, /outside a transaction/)
        end
      end
    end
  end
end
