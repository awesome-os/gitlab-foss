# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitAccess, :aggregate_failures, feature_category: :system_access do
  include TermsHelper
  include Ci::JobTokenScopeHelpers
  include_context 'with git access spec helpers'

  let_it_be_with_reload(:user) { create(:user) }
  let(:actor) { user }
  let(:project) { create(:project, :repository) }
  let(:repository_path) { "#{project.full_path}.git" }
  let(:protocol) { 'ssh' }
  let(:authentication_abilities) { %i[read_project download_code push_code] }
  let(:redirected_path) { nil }
  let(:auth_result_type) { nil }
  let(:gitaly_context) { { 'key' => 'value' } }
  let(:personal_access_token) { nil }
  let(:oauth_access_token) { nil }
  let(:changes) { Gitlab::GitAccess::ANY }
  let(:push_access_check) { access.check('git-receive-pack', changes) }
  let(:pull_access_check) { access.check('git-upload-pack', changes) }

  context 'terms are enforced' do
    before do
      enforce_terms
    end

    shared_examples 'access after accepting terms' do
      let(:actions) do
        [-> { pull_access_check },
          -> { push_access_check }]
      end

      it 'blocks access when the user did not accept terms' do
        actions.each do |action|
          expect { action.call }.to raise_forbidden(/must accept the Terms of Service in order to perform this action/)
        end
      end

      it 'allows access when the user accepted the terms' do
        accept_terms(user)

        actions.each do |action|
          expect { action.call }.not_to raise_error
        end
      end
    end

    describe 'as an anonymous user to a public project' do
      let(:actor) { nil }
      let(:project) { create(:project, :public, :repository) }

      it { expect { pull_access_check }.not_to raise_error }
    end

    describe 'as a guest to a public project' do
      let_it_be(:project) { create(:project, :public, :repository) }

      it_behaves_like 'access after accepting terms' do
        let(:actions) { [-> { pull_access_check }] }
      end
    end

    describe 'as a reporter to the project' do
      before do
        project.add_reporter(user)
      end

      it_behaves_like 'access after accepting terms' do
        let(:actions) { [-> { pull_access_check }] }
      end
    end

    describe 'as a developer of the project' do
      before do
        project.add_developer(user)
      end

      it_behaves_like 'access after accepting terms'
    end

    describe 'as a maintainer of the project' do
      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'access after accepting terms'
    end

    describe 'as an owner of the project' do
      let_it_be_with_reload(:project) { create(:project, :repository, namespace: user.namespace) }

      it_behaves_like 'access after accepting terms'
    end

    describe 'when a ci build clones the project' do
      let(:protocol) { 'http' }
      let(:authentication_abilities) { [:build_download_code] }
      let(:auth_result_type) { :build }

      before do
        project.add_developer(user)
      end

      it "doesn't block http pull" do
        aggregate_failures do
          expect { pull_access_check }.not_to raise_error
        end
      end
    end

    describe 'when request is authorized with job token' do
      let(:source_project) { create(:project) }
      let(:auth_result_type) { :build }
      let(:job) { build_stubbed(:ci_build, project: source_project, user: user) }
      let(:scope) { user.set_ci_job_token_scope!(job) }

      before do
        accept_terms(user)

        source_project.add_maintainer(user)
        source_project.save!

        allow(user).to receive(:ci_job_token_scope).and_return(scope)
      end

      context 'and target project in the allow list' do
        let(:access) { access_class.new(user, project, 'web', authentication_abilities: [:download_code], repository_path: repository_path) }

        before do
          project.add_maintainer(user)
          project.save!

          allow(scope).to receive(:accessible?).with(project).and_return(true)
        end

        it 'does not block http pull' do
          expect { pull_access_check }.not_to raise_error
        end
      end

      context 'and target_project in the allow list, but user does not have permissions' do
        let(:access) { access_class.new(user, project, 'web', authentication_abilities: [:download_code], repository_path: repository_path) }

        before do
          allow(scope).to receive(:accessible?).with(project).and_return(true)
        end

        it 'blocks http pull' do
          expect { pull_access_check }.to raise_forbidden_by_job_token(project)
        end
      end

      context 'and target project is not in the allow list' do
        let(:access) { access_class.new(user, project, 'web', authentication_abilities: [:download_code], repository_path: repository_path) }

        before do
          project.add_maintainer(user)
          project.save!

          allow(scope).to receive(:accessible?).with(project).and_return(false)
        end

        it 'blocks http pull' do
          expect { pull_access_check }.to raise_forbidden_by_job_token_allowlist(source_project, project)
        end
      end
    end

    describe 'when request is made from CI' do
      let(:auth_result_type) { :build }
      let(:job) { build_stubbed(:ci_build, project: project, user: user) }

      before do
        accept_terms(user)
        project.add_maintainer(user)
        project.ci_push_repository_for_job_token_allowed = ci_push_repository_for_job_token_allowed
        project.save!

        allow(user).to receive(:ci_job_token_scope).and_return(user.set_ci_job_token_scope!(job))
      end

      context 'when push to repository is allowed by project settings' do
        let(:ci_push_repository_for_job_token_allowed) { true }

        it "doesn't block push" do
          expect { push_access_check_build(project, changes) }.not_to raise_error
        end

        context 'when push is requested to a different project' do
          let(:another_project) do
            create(:project, :repository, :public).tap do |accessible_project|
              add_inbound_accessible_linkage(project, accessible_project)
            end
          end

          before do
            another_project.add_maintainer(user)
            another_project.ci_push_repository_for_job_token_allowed = ci_push_repository_for_job_token_allowed
            another_project.save!
          end

          it 'raises forbidden exception on push' do
            expect { push_access_check_build(another_project, changes) }.to raise_error(Gitlab::GitAccess::ForbiddenError)
          end
        end
      end

      context 'when push to repository is not allowed by project settings' do
        let(:ci_push_repository_for_job_token_allowed) { false }

        it 'raises forbidden exception on push' do
          expect { push_access_check_build(project, changes) }.to raise_error(Gitlab::GitAccess::ForbiddenError)
        end
      end
    end
  end

  private

  def push_access_check_build(access_project, changes)
    access_class.new(actor, access_project, protocol,
      authentication_abilities: build_authentication_abilities_allowed_push,
      repository_path: "#{access_project.full_path}.git",
      redirected_path: redirected_path, auth_result_type: auth_result_type, gitaly_context: gitaly_context)
    .check('git-receive-pack', changes)
  end

  def raise_forbidden_by_job_token(target_project)
    raise_error(described_class::ForbiddenError, format(described_class::ERROR_MESSAGES[:auth_by_job_token_forbidden],
      target_project_id: target_project.id))
  end

  def raise_forbidden_by_job_token_allowlist(source_project, target_project)
    raise_error(described_class::ForbiddenError, format(described_class::ERROR_MESSAGES[:auth_by_job_token_project_not_in_allowlist],
      source_project_path: source_project.path, target_project_id: target_project.id))
  end

  def build_authentication_abilities_allowed_push
    [
      :read_project,
      :build_download_code,
      :build_push_code
    ]
  end
end
