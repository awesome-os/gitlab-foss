# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitAccess, :aggregate_failures, feature_category: :system_access do
  include AdminModeHelper
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
  let(:push_access_check) { access.check('git-receive-pack', changes) }

  describe '#check_push_access!' do
    let(:unprotected_branch) { 'unprotected_branch' }

    let(:changes) do
      { any: Gitlab::GitAccess::ANY,
        push_new_branch: "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2ab refs/heads/wow",
        push_master: '6f6d7e7ed 570e7b2ab refs/heads/master',
        push_protected_branch: '6f6d7e7ed 570e7b2ab refs/heads/feature',
        push_remove_protected_branch: "570e7b2ab #{Gitlab::Git::SHA1_BLANK_SHA} "\
                                      'refs/heads/feature',
        push_tag: '6f6d7e7ed 570e7b2ab refs/tags/v1.0.0',
        push_new_tag: "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2ab refs/tags/v7.8.9",
        push_all: ['6f6d7e7ed 570e7b2ab refs/heads/master', '6f6d7e7ed 570e7b2ab refs/heads/feature'],
        merge_into_protected_branch: "0b4bc9a #{merge_into_protected_branch} refs/heads/feature" }
    end

    before do
      merge_into_protected_branch
    end

    def merge_into_protected_branch
      @protected_branch_merge_commit ||= begin
        project.repository.add_branch(user, unprotected_branch, 'feature')
        target_branch = TestEnv::BRANCH_SHA['feature']
        source_branch = project.repository.create_file(
          user,
          'filename',
          'This is the file content',
          message: 'This is a good commit message',
          branch_name: unprotected_branch)
        merge_id = project.repository.raw.merge_to_ref(
          user,
          branch: target_branch,
          first_parent_ref: target_branch,
          source_sha: source_branch,
          target_ref: 'refs/merge-requests/test',
          message: 'commit message'
        )

        # We are trying to simulate what the repository would look like
        # during the pre-receive hook, before the actual ref is
        # written/created. Repository#new_commits relies on there being no
        # ref pointing to the merge commit.
        project.repository.delete_refs('refs/merge-requests/test')

        merge_id
      end
    end

    def self.run_permission_checks(permissions_matrix)
      permissions_matrix.each_pair do |role, matrix|
        # Run through the entire matrix for this role in one test to avoid
        # repeated setup.
        #
        # Expectations are given a custom failure message proc so that it's
        # easier to identify which check(s) failed.
        it "has the correct permissions for #{role}s" do
          if role == :admin_without_admin_mode
            skip("All admins are allowed to perform actions https://gitlab.com/gitlab-org/gitlab/-/issues/296509")
          end

          if [:admin_with_admin_mode, :admin_without_admin_mode].include?(role)
            user.update_attribute(:admin, true)
            enable_admin_mode!(user) if role == :admin_with_admin_mode
            project.add_guest(user)
          else
            project.add_role(user, role)
          end

          protected_branch.save!

          aggregate_failures do
            matrix.each do |action, allowed|
              check = -> { push_changes(changes[action]) }

              if allowed
                expect(&check).not_to raise_error, -> do
                  "expected #{action} for #{role} to be allowed while #{who_can_action}"
                end
              else
                expect(&check).to raise_error(Gitlab::GitAccess::ForbiddenError), -> do
                  "expected #{action} for #{role} to be disallowed while #{who_can_action}"
                end
              end
            end
          end
        end
      end
    end

    permissions_matrix = {
      admin_with_admin_mode: {
        any: true,
        push_new_branch: true,
        push_master: true,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: false,
        merge_into_protected_branch: false
      },

      admin_without_admin_mode: {
        any: false,
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      },

      maintainer: {
        any: true,
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      developer: {
        any: true,
        push_new_branch: true,
        push_master: true,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: false,
        merge_into_protected_branch: false
      },

      reporter: {
        any: false,
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      },

      guest: {
        any: false,
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      }
    }

    [%w[feature exact], ['feat*', 'wildcard']].each do |protected_branch_name, protected_branch_type|
      context "when only maintainers are allowed to push into the #{protected_branch_type} protected branch" do
        let(:who_can_action) { :maintainers_can_push }
        let(:protected_branch) { create(:protected_branch, who_can_action, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix)
      end

      context "when developers are allowed to push into the #{protected_branch_type} protected branch" do
        let(:who_can_action) { :developers_can_push }
        let(:protected_branch) { create(:protected_branch, who_can_action, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true }))
      end

      context "when developers are allowed to merge into the #{protected_branch_type} protected branch" do
        let(:who_can_action) { :developers_can_merge }
        let(:protected_branch) { create(:protected_branch, who_can_action, name: protected_branch_name, project: project) }

        context "when a merge request exists for the given source/target branch" do
          context "when the merge request is in progress" do
            before do
              create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature',
                state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            end

            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: true }))
          end

          context "when the merge request is not in progress" do
            before do
              create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', in_progress_merge_commit_sha: nil)
            end

            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: false }))
          end

          context "when a merge request does not exist for the given source/target branch" do
            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: false }))
          end
        end
      end

      context "when developers are allowed to push and merge into the #{protected_branch_type} protected branch" do
        let(:who_can_action) { :developers_can_push_and_merge }
        let(:protected_branch) { create(:protected_branch, :developers_can_merge, :developers_can_push, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true }))
      end

      context "when no one is allowed to push to the #{protected_branch_name} protected branch" do
        let(:protected_branch) { build(:protected_branch, :no_one_can_push, name: protected_branch_name, project: project) }

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false },
          maintainer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false },
          admin_with_admin_mode: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false }))
      end
    end

    context 'when pushing to a project' do
      let(:project) { create(:project, :public, :repository) }
      let(:changes) { "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2ab refs/heads/wow" }

      before do
        project.add_developer(user)
      end

      it 'disallows users that are blocked pending approval to push' do
        user.block_pending_approval

        expect { push_access_check }.to raise_forbidden('Your account is pending approval from your administrator and hence blocked.')
      end

      it 'does not allow deactivated users to push' do
        user.deactivate!

        expect { push_access_check }.to raise_forbidden("Your account has been deactivated by your administrator. Please log back in from a web browser to reactivate your account at #{Gitlab.config.gitlab.url}")
      end

      it 'disallows users with expired password to push' do
        user.update!(password_expires_at: 2.minutes.ago)

        expect { push_access_check }.to raise_forbidden("Your password expired. Please access GitLab from a web browser to update your password.")
      end

      context 'with an ldap user' do
        let(:user) { create(:omniauth_user, provider: 'ldap', password_expires_at: 2.minutes.ago) }

        it 'allows ldap users with expired password to push' do
          expect { push_access_check }.not_to raise_error
        end

        it 'disallows blocked ldap users with expired password to push' do
          user.block

          expect { push_access_check }.to raise_forbidden("Your account has been blocked.")
        end
      end

      it 'avoids N+1 queries', :request_store do
        # Run this once to establish a baseline. Cached queries should get
        # cached, so that when we introduce another change we shouldn't see
        # additional queries.
        access.check('git-receive-pack', changes)

        control = ActiveRecord::QueryRecorder.new do
          access.check('git-receive-pack', changes)
        end

        changes = ['6f6d7e7ed 570e7b2ab refs/heads/master', '6f6d7e7ed 570e7b2ab refs/heads/feature']

        # There is still an N+1 query with protected branches
        expect { access.check('git-receive-pack', changes) }.not_to exceed_query_limit(control).with_threshold(2)
      end

      context 'when #check_access! raises a timeout error' do
        let(:expected_message) { "Push operation timed out\n\nTiming information for debugging purposes:\nRunning checks for ref: wow" }

        before do
          allow_next_instance_of(Gitlab::Checks::SingleChangeAccess) do |check|
            allow(check).to receive(:validate!).and_raise(Gitlab::Checks::TimedLogger::TimeoutError)
          end
        end

        it 'logs the timeout details and raises TimeoutError' do
          expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(Gitlab::Checks::TimedLogger::TimeoutError), project_id: project.id, 'gl_user_id' => user.id, deploy_key_id: nil)
          expect { access.check('git-receive-pack', changes) }.to raise_error(described_class::TimeoutError, expected_message)
        end

        context 'when the actor is a deploy key with access to the project' do
          let(:deploy_key) { create(:deploy_key, user: user) }
          let(:actor) { deploy_key }

          before do
            deploy_key.deploy_keys_projects.create!(project: project, can_push: true)
          end

          it 'logs the timeout details and raises TimeoutError' do
            expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(Gitlab::Checks::TimedLogger::TimeoutError), project_id: project.id, 'gl_user_id' => nil, deploy_key_id: deploy_key.id)
            expect { access.check('git-receive-pack', changes) }.to raise_error(described_class::TimeoutError, expected_message)
          end
        end
      end
    end
  end
end
