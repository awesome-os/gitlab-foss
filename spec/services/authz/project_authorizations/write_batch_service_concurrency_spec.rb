# frozen_string_literal: true

require 'spec_helper'

# Needs real concurrent connections, so it uses the :delete strategy and no let_it_be.
RSpec.describe Authz::ProjectAuthorizations::WriteBatchService, :delete, feature_category: :permissions do
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }
  let!(:project) { create(:project) }
  let(:other_project) { create(:project) }

  let(:release) { Queue.new }
  let(:threads) { [] }

  after do
    # Enough releases for every writer still waiting in its calculation.
    threads.size.times { release << true }
    threads.each { |thread| thread.join(10) }
  end

  # Starts a writer that holds its locks, inside its calculation, until released, and returns its backend PID.
  def start_writer(level, user_id: nil, project_id: nil)
    locked = Queue.new
    ids = user_id ? [project.id] : [user.id]

    threads << Thread.new do
      described_class.new(user_id: user_id, project_id: project_id).execute(ids) do |chunk|
        locked << ProjectAuthorization.connection.select_value('SELECT pg_backend_pid()')
        release.pop(timeout: 10)
        chunk.index_with(level)
      end
    end

    locked.pop(timeout: 10) || raise('the writer did not take its locks')
  end

  def in_thread(&block)
    Thread.new(&block).tap { |thread| threads << thread }
  end

  def wait_until_a_session_is_blocked_by(pid)
    Timeout.timeout(10) do
      sleep 0.01 until ApplicationRecord.connection.select_value(<<~SQL).present?
        SELECT 1 FROM pg_stat_activity WHERE pg_blocking_pids(pid) @> ARRAY[#{pid.to_i}] LIMIT 1
      SQL
    end
  end

  def stored_levels(user, project)
    ProjectAuthorization.stored_levels_for_user(user.id, [project.id])
  end

  it "makes wait_for_user_writers wait for a user writer holding the user's lock, then see its rows" do
    writer_pid = start_writer(Gitlab::Access::DEVELOPER, user_id: user.id)

    waiter = in_thread do
      described_class.wait_for_user_writers(user.id)
      stored_levels(user, project)
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(waiter.value).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "makes wait_for_user_writers wait for a project writer holding the user's lock shared, then see its rows" do
    writer_pid = start_writer(Gitlab::Access::DEVELOPER, project_id: project.id)

    waiter = in_thread do
      described_class.wait_for_user_writers(user.id)
      stored_levels(user, project)
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(waiter.value).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "makes wait_for_project_writers wait for a writer of the same project, even for users it doesn't name" do
    writer_pid = start_writer(Gitlab::Access::DEVELOPER, project_id: project.id)

    waiter = in_thread do
      described_class.wait_for_project_writers(project.id, [other_user.id])
      stored_levels(user, project)
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(waiter.value).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "makes wait_for_project_writers wait for a user writer of one of its users" do
    writer_pid = start_writer(Gitlab::Access::DEVELOPER, user_id: user.id)

    waiter = in_thread do
      described_class.wait_for_project_writers(project.id, [user.id])
      stored_levels(user, project)
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(waiter.value).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "makes wait_for_project_writers yield, inside its last lock transaction, after the writers it waited for" do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    writer_pid = start_writer(Gitlab::Access::DEVELOPER, project_id: project.id)

    waiter = in_thread do
      described_class.wait_for_project_writers(project.id, [other_user.id, user.id]) { stored_levels(user, project) }
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(waiter.value).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "lets a project writer queued behind wait_for_project_writers finish once the user writer it waits for does" do
    user_writer_pid = start_writer(Gitlab::Access::DEVELOPER, user_id: user.id)
    waiter = in_thread { described_class.wait_for_project_writers(project.id, [user.id]) }
    wait_until_a_session_is_blocked_by(user_writer_pid)

    project_writer = in_thread do
      described_class.new(project_id: project.id).execute([user.id]) { |ids| ids.index_with(Gitlab::Access::MAINTAINER) }
    end
    Timeout.timeout(10) do
      sleep 0.01 until ApplicationRecord.connection.select_value(<<~SQL) >= 2
        SELECT count(*) FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0
      SQL
    end
    release << true

    expect(waiter.join(10)).to be(waiter)
    expect(project_writer.value).to have_attributes(rows_added: 1, rows_deleted: 1)
    expect(stored_levels(user, project)).to eq(project.id => [Gitlab::Access::MAINTAINER])
  end

  it "doesn't make wait_for_project_writers wait for a writer of another project that shares its user" do
    start_writer(Gitlab::Access::DEVELOPER, project_id: other_project.id)

    waiter = in_thread { described_class.wait_for_project_writers(project.id, [user.id]) }

    expect(waiter.join(10)).to be(waiter)
    expect(threads.first).to be_alive
  end

  it "makes a second writer for the same user wait, then calculate from the first writer's rows" do
    writer_pid = start_writer(Gitlab::Access::MAINTAINER, user_id: user.id)
    seen = Queue.new

    second = in_thread do
      described_class.new(user_id: user.id).execute([project.id]) do |ids|
        seen << stored_levels(user, project)
        ids.index_with(Gitlab::Access::DEVELOPER)
      end
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(second.value).to have_attributes(rows_added: 1, rows_deleted: 1)
    expect(seen.pop(timeout: 10)).to eq(project.id => [Gitlab::Access::MAINTAINER])
    expect(stored_levels(user, project)).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "makes a project writer wait for a user writer of one of its users, then calculate from its rows" do
    writer_pid = start_writer(Gitlab::Access::MAINTAINER, user_id: user.id)
    seen = Queue.new

    second = in_thread do
      described_class.new(project_id: project.id).execute([user.id]) do |ids|
        seen << stored_levels(user, project)
        ids.index_with(Gitlab::Access::DEVELOPER)
      end
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(second.value).to have_attributes(rows_added: 1, rows_deleted: 1)
    expect(seen.pop(timeout: 10)).to eq(project.id => [Gitlab::Access::MAINTAINER])
  end

  it "makes a user writer wait for a project writer holding its user shared" do
    writer_pid = start_writer(Gitlab::Access::MAINTAINER, project_id: project.id)

    second = in_thread do
      described_class.new(user_id: user.id).execute([project.id]) { |ids| ids.index_with(Gitlab::Access::DEVELOPER) }
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(second.value).to have_attributes(rows_added: 1, rows_deleted: 1)
    expect(stored_levels(user, project)).to eq(project.id => [Gitlab::Access::DEVELOPER])
  end

  it "makes a second writer for the same project wait, even for other users" do
    writer_pid = start_writer(Gitlab::Access::MAINTAINER, project_id: project.id)

    second = in_thread do
      described_class.new(project_id: project.id).execute([other_user.id]) do |ids|
        ids.index_with(Gitlab::Access::DEVELOPER)
      end
    end
    wait_until_a_session_is_blocked_by(writer_pid)
    release << true

    expect(second.value).to have_attributes(rows_added: 1)
  end

  it "doesn't make a writer for another user wait" do
    start_writer(Gitlab::Access::DEVELOPER, user_id: user.id)

    other = in_thread do
      described_class.new(user_id: other_user.id).execute([project.id]) do |ids|
        ids.index_with(Gitlab::Access::DEVELOPER)
      end
    end

    expect(other.join(10)).to be(other)
    # The first writer gives up waiting for its release after 10 seconds, so check it still holds its lock.
    expect(threads.first).to be_alive
    expect(other.value).to have_attributes(rows_added: 1)
  end

  it 'lets writers of many projects that share one user hold their locks at the same time' do
    projects = [project, other_project, *create_list(:project, 3)]

    # Each start_writer returns only once its writer holds its locks, so all of them hold theirs together.
    projects.each { |p| start_writer(Gitlab::Access::DEVELOPER, project_id: p.id) }

    projects.size.times { release << true }
    threads.each { |thread| expect(thread.value).to have_attributes(rows_added: 1) }
    expect(ProjectAuthorization.where(user: user).pluck(:project_id)).to match_array(projects.map(&:id))
  end
end
