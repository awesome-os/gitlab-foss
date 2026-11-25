# frozen_string_literal: true

require 'fast_spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'fetch_merge_request_history_to_diff_base shell function', feature_category: :tooling do
  let(:utils_path) { File.expand_path('../../../scripts/utils.sh', __dir__) }
  let(:tmp_dir) { Dir.mktmpdir }
  # Plays origin, the project the pipeline runs in: the canonical project or a community fork.
  let(:origin_dir) { File.join(tmp_dir, 'origin') }
  # Plays the job's shallow clone.
  let(:clone_dir) { File.join(tmp_dir, 'clone') }

  let(:git_env) do
    {
      'GIT_CONFIG_GLOBAL' => '/dev/null', 'GIT_CONFIG_SYSTEM' => '/dev/null',
      'GIT_AUTHOR_NAME' => 'Test', 'GIT_AUTHOR_EMAIL' => 'test@example.com',
      'GIT_COMMITTER_NAME' => 'Test', 'GIT_COMMITTER_EMAIL' => 'test@example.com'
    }
  end

  # master: base, later. The MR source branch: base, two commits, head.
  let!(:base_sha) do
    git_init(origin_dir)
    # The GitLab remote allows fetching a commit by SHA and filtered fetches.
    git(origin_dir, 'config', 'uploadpack.allowAnySHA1InWant', 'true')
    git(origin_dir, 'config', 'uploadpack.allowFilter', 'true')
    git_commit(origin_dir, 'base')
  end

  let!(:later_sha) { git_commit(origin_dir, 'later') }

  let!(:head_sha) do
    git(origin_dir, 'checkout', '-q', '-b', 'mr-source', base_sha)
    git_commit(origin_dir, 'first')
    git_commit(origin_dir, 'second')
    git_commit(origin_dir, 'head').tap { git(origin_dir, 'checkout', '-q', 'master') }
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  def git_init(dir)
    FileUtils.mkdir_p(dir)
    git(dir, 'init', '-q', '-b', 'master')
  end

  def git(dir, *args)
    stdout, stderr, status = Open3.capture3(git_env, 'git', '-C', dir, *args)
    raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

    stdout.strip
  end

  def git_commit(dir, message)
    git(dir, 'commit', '-q', '--allow-empty', '-m', message)
    git(dir, 'rev-parse', 'HEAD')
  end

  def shallow_clone(ref)
    # Checks out `ref` of origin at depth 1, as the job's clone does.
    git_init(clone_dir)
    git(clone_dir, 'remote', 'add', 'origin', "file://#{origin_dir}")
    git(clone_dir, 'fetch', '-q', '--depth=1', 'origin', ref)
    git(clone_dir, 'checkout', '-q', '--detach', 'FETCH_HEAD')
  end

  def base_reachable_from_head?
    # Without the promisor settings of the filtered fetch, Git reads only what the clone holds.
    %w[remote.origin.promisor extensions.partialclone].each do |key|
      Open3.capture3(git_env, 'git', '-C', clone_dir, 'config', '--unset-all', key)
    end

    _, _, status = Open3.capture3(git_env, 'git', '-C', clone_dir, 'merge-base', '--is-ancestor', base_sha, head_sha)
    status.success?
  end

  def run_function(env)
    # Runs the function the way GitLab Runner runs job scripts: in a subshell with `set -eo pipefail`.
    # `sleep` is stubbed so that `retry` does not wait between failed fetches.
    ci_env = {
      'CI_MERGE_REQUEST_IID' => '1',
      'CI_MERGE_REQUEST_DIFF_BASE_SHA' => base_sha,
      'CI_MERGE_REQUEST_SOURCE_BRANCH_SHA' => nil,
      'CI_COMMIT_SHA' => head_sha
    }

    Open3.capture3(
      git_env.merge(ci_env, env), 'bash', '-c',
      "set -eo pipefail\n. '#{utils_path}'\nsleep() { :; }\nfetch_merge_request_history_to_diff_base",
      chdir: clone_dir
    )
  end

  context 'in a community fork pipeline, whose origin does not have the merge request ref' do
    it 'fetches the history of the MR head until the diff base is reachable' do
      shallow_clone('refs/heads/mr-source')

      _, stderr, status = run_function({})

      expect(status).to be_success, stderr
      expect(stderr).not_to include('still not reachable')
      expect(base_reachable_from_head?).to be(true)
    end
  end

  context 'in a merged results pipeline, where only a merge request ref holds the MR head' do
    it 'fetches the history of the MR head until the diff base is reachable' do
      git(origin_dir, 'update-ref', 'refs/merge-requests/1/head', head_sha)
      git(origin_dir, 'branch', '-q', '-D', 'mr-source')
      merge_sha = git(origin_dir, 'commit-tree', "#{later_sha}^{tree}", '-p', later_sha, '-p', head_sha, '-m', 'merge')
      git(origin_dir, 'update-ref', 'refs/merge-requests/1/merge', merge_sha)
      shallow_clone('refs/merge-requests/1/merge')

      _, stderr, status = run_function('CI_COMMIT_SHA' => merge_sha, 'CI_MERGE_REQUEST_SOURCE_BRANCH_SHA' => head_sha)

      expect(status).to be_success, stderr
      expect(stderr).not_to include('still not reachable')
      expect(base_reachable_from_head?).to be(true)
    end
  end
end
