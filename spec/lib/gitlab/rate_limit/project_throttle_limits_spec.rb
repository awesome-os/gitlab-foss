# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::RateLimit::ProjectThrottleLimits, feature_category: :rate_limiting do
  let_it_be(:project, refind: true) { create(:project) }
  let(:path) { "/#{project.full_path}.git/info/refs" }
  let(:default) { 3600 }

  before do
    described_class.expire!
  end

  after do
    described_class.expire!
  end

  def set_override(**attrs)
    project.project_setting.update!(**attrs)
    described_class.expire!
  end

  # Ages the clock past the TTL instead of dropping the entry, so the stale set is
  # still there to be served. expire! would leave nothing behind.
  def expire_the_cache
    now = Gitlab::Metrics::System.monotonic_time

    allow(Gitlab::Metrics::System).to receive(:monotonic_time)
      .and_return(now + described_class::CACHE_TTL.to_i + 1)
  end

  # What the Labkit rules do: match on the override key, then resolve the limit
  # from it. A request with no override never reaches limit_for_key at all.
  def limit_for(throttle, path: self.path, env: nil)
    key = described_class.override_key_for(throttle, path: path, env: env)
    return default unless key

    described_class.limit_for_key(throttle, key, default: default)
  end

  describe 'renamed projects' do
    # Captured eagerly: a lazy let would evaluate after the rename below and hand
    # back the new path, making every assertion here compare a path with itself.
    let!(:old_path) { project.full_path }

    before do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      project.update!(path: "#{project.path}-renamed")
      described_class.expire!
    end

    it 'keeps applying the override to the pre-rename path Git HTTP still serves' do
      expect(limit_for(:authenticated_git_http, path: "/#{old_path}.git/info/refs")).to eq(42)
    end

    it 'applies the override to the new path' do
      expect(limit_for(:authenticated_git_http, path: "/#{project.reload.full_path}.git/info/refs")).to eq(42)
    end

    # One counter per project, not one per path it has ever had: keying each
    # redirect separately would give an actor a fresh budget per rename.
    it 'counts a pre-rename path under the project\'s current path' do
      current = project.reload.full_path.downcase

      expect(described_class.override_key_for(:authenticated_git_http, path: "/#{old_path}.git/info/refs"))
        .to eq(current)
      expect(described_class.override_key_for(:authenticated_git_http, path: "/#{current}.git/info/refs"))
        .to eq(current)
    end
  end

  # The flag gates enforcement at the source: with it off the override set is
  # empty, so every fact resolves to nil and no rule can match. The write side is
  # gated separately, in ProjectPolicy.
  context 'when the feature flag is disabled' do
    before do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      stub_feature_flags(project_git_throttle_overrides: false)
      described_class.expire!
    end

    it 'resolves no override key, so no rule partitions the counter' do
      expect(described_class.override_key_for(:authenticated_git_http, path: path)).to be_nil
    end

    it 'falls back to the instance default' do
      expect(limit_for(:authenticated_git_http)).to eq(default)
    end
  end

  # These run only when some project has an override, so the override set must be
  # non-empty for the early return in matched_path to be reached at all.
  describe 'paths that resolve to no project' do
    before do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
    end

    it 'is nil for a non-git path' do
      expect(described_class.override_key_for(:authenticated_git_http, path: '/api/v4/projects')).to be_nil
    end

    it 'is nil for a path the git route regex does not match' do
      expect(described_class.override_key_for(:authenticated_git_http, path: '/')).to be_nil
    end

    it 'is nil for a git path belonging to another project' do
      expect(described_class.override_key_for(:authenticated_git_http, path: '/other/thing.git/info/refs'))
        .to be_nil
    end

    it 'is nil for a sibling project whose name starts with this one and .git' do
      expect(described_class.override_key_for(:authenticated_git_http, path: "/#{project.full_path}.github/info/refs"))
        .to be_nil
    end
  end

  # Fails open: a throttle that cannot read its overrides falls back to the
  # instance default rather than taking Git over HTTP down with it.
  context 'when loading the overrides raises' do
    before do
      allow(ProjectSetting).to receive(:git_throttle_overrides_by_full_path).and_raise(StandardError, 'boom')
      described_class.expire!
    end

    it 'reports the error and resolves no override' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(an_instance_of(StandardError))

      expect(described_class.override_key_for(:authenticated_git_http, path: path)).to be_nil
    end
  end

  # Git HTTP is served under /o/:organization_path too, and those requests must
  # get the project's limit rather than falling back to the instance-wide one.
  describe 'organization-scoped paths' do
    before do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
    end

    it 'resolves the override through the organization scope' do
      expect(described_class.override_key_for(:authenticated_git_http,
        path: "/o/default/#{project.full_path}.git/info/refs")).to eq(project.full_path.downcase)
    end

    it 'applies the same limit as the unscoped path' do
      expect(limit_for(:authenticated_git_http, path: "/o/default/#{project.full_path}.git/info/refs"))
        .to eq(42)
    end

    it 'ignores a prefix that is not a valid organization route' do
      expect(described_class.override_key_for(:authenticated_git_http,
        path: "/o/groups/#{project.full_path}.git/info/refs")).to be_nil
    end
  end

  describe '.limit_for_key' do
    subject(:limit) { described_class.limit_for_key(:authenticated_git_http, key, default: default) }

    let(:key) { project.full_path.downcase }

    it 'returns the override for a key that has one' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      expect(limit).to eq(42)
    end

    # The clamp is what stops a project Owner widening a limit the instance admin
    # set.
    it 'clamps an override above the instance default' do
      set_override(throttle_authenticated_git_http_requests_per_period: default + 1_000)

      expect(limit).to eq(default)
    end

    it 'returns the default for a throttle the project did not override' do
      set_override(throttle_authenticated_git_lfs_requests_per_period: 42)

      expect(limit).to eq(default)
    end

    it 'returns the default for a key nobody overrode' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      expect(described_class.limit_for_key(:authenticated_git_http, 'no/such-project', default: default))
        .to eq(default)
    end
  end

  describe '.override_key_for' do
    subject(:key) { described_class.override_key_for(:authenticated_git_http, path: path) }

    it { is_expected.to be_nil }

    it 'is the project full path when that throttle is overridden' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      expect(key).to eq(project.full_path.downcase)
    end

    # Otherwise a project that overrides one throttle silently gains a second,
    # full-size counter for every throttle it did not override.
    it 'is nil for a throttle the project did not override' do
      set_override(throttle_authenticated_git_lfs_requests_per_period: 7)

      expect(key).to be_nil
    end

    it 'is nil for a project without an override while another project has one' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      expect(described_class.override_key_for(:authenticated_git_http, path: '/other/x.git/info/refs')).to be_nil
    end

    # The parent has an override, but not for the throttle being asked about, so the wiki
    # request must keep counting on the instance-wide key.
    it 'is nil when the parent project overrides a different throttle' do
      set_override(throttle_authenticated_git_lfs_requests_per_period: 7)
      wiki_path = "/#{project.full_path}.wiki.git/info/refs"

      expect(described_class.override_key_for(:authenticated_git_http, path: wiki_path)).to be_nil
    end

    it 'is the parent project path for a wiki repository' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      wiki_path = "/#{project.full_path}.wiki.git/info/refs"

      expect(described_class.override_key_for(:authenticated_git_http, path: wiki_path))
        .to eq(project.full_path.downcase)
    end
  end

  describe 'caching' do
    it 'does not query the database once the overrides are loaded' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      limit_for(:authenticated_git_http)

      expect { limit_for(:authenticated_git_http) }.not_to exceed_query_limit(0)
    end

    it 'does not copy the overrides hash on read' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      first = described_class.send(:overrides)
      second = described_class.send(:overrides)

      expect(second).to be(first)
      expect(first).to be_frozen
    end

    it 'loads the overrides once when several threads read them concurrently' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      described_class.expire!

      expect(ProjectSetting).to receive(:git_throttle_overrides_by_full_path).once.and_call_original

      Array.new(4) { Thread.new { described_class.send(:overrides) } }.each(&:join)
    end

    # The threads that lose the race must not queue behind the refresh. At the row
    # ceiling the two queries cost ~160ms, and every Git request in the process
    # would otherwise wait on them once a minute.
    it 'serves the expired set while another thread refreshes' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      expect(limit_for(:authenticated_git_http)).to eq(42)

      expire_the_cache

      holding = Queue.new
      release = Queue.new
      refresher = Thread.new do
        described_class::MUTEX.synchronize do
          holding << true
          release.pop
        end
      end
      holding.pop

      begin
        expect(ProjectSetting).not_to receive(:git_throttle_overrides_by_full_path)

        # Read on its own thread so a regression fails here rather than hanging the
        # suite until the job times out: without this the read blocks on the mutex.
        reader = Thread.new { limit_for(:authenticated_git_http) }

        expect(reader.join(10)).to be_present, 'expected the expired set to be served without waiting'
        expect(reader.value).to eq(42)
      ensure
        release << true
        refresher.join
      end
    end

    # Nothing to serve before the first load, so that one wait is unavoidable.
    it 'loads rather than serving nothing when the cache is empty' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      expect(ProjectSetting).to receive(:git_throttle_overrides_by_full_path).once.and_call_original

      expect(limit_for(:authenticated_git_http)).to eq(42)
    end

    it 'picks up a new override after the cache is expired' do
      expect(limit_for(:authenticated_git_http)).to eq(default)

      set_override(throttle_authenticated_git_http_requests_per_period: 42)

      expect(limit_for(:authenticated_git_http)).to eq(42)
    end
  end

  describe 'request memoization' do
    it 'resolves the path once per request env' do
      set_override(throttle_authenticated_git_http_requests_per_period: 42)
      env = {}

      limit_for(:authenticated_git_http, env: env)

      expect(described_class).not_to receive(:extract_full_path)
      expect(limit_for(:authenticated_git_http, env: env)).to eq(42)
      expect(env[described_class::ENV_KEY]).to eq(project.full_path.downcase)
    end
  end
end
