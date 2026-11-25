# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitAccess, :aggregate_failures, feature_category: :system_access do
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

  describe '#check_db_accessibility!' do
    context 'when in a read-only GitLab instance' do
      before do
        create(:protected_branch, name: 'feature', project: project)
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      end

      it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:cannot_push_to_read_only]) }
    end
  end

  describe 'check LFS integrity' do
    let(:changes) { ['6f6d7e7ed 570e7b2ab refs/heads/master', '6f6d7e7ed 570e7b2ab refs/heads/feature'] }

    before do
      project.add_developer(user)
    end

    context 'when LFS is not enabled' do
      it 'does not run LFSIntegrity check' do
        allow(project).to receive(:lfs_enabled?).and_return(false)

        expect(Gitlab::Checks::LfsIntegrity).not_to receive(:new)

        push_access_check
      end
    end

    context 'when LFS is enabled' do
      it 'checks LFS integrity only for first change' do
        allow(project).to receive(:lfs_enabled?).and_return(true)

        expect_next_instance_of(Gitlab::Checks::LfsIntegrity) do |instance|
          expect(instance).to receive(:objects_missing?).once
        end

        push_access_check
      end
    end
  end

  describe 'build authentication abilities' do
    let(:authentication_abilities) { build_authentication_abilities }

    context 'when project is authorized' do
      before do
        project.add_reporter(user)
      end

      it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_upload]) }
    end

    context 'when unauthorized' do
      context 'to public project' do
        let(:project) { create(:project, :public, :repository) }

        it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_upload]) }
      end

      context 'to internal project' do
        let(:project) { create(:project, :internal, :repository) }

        it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_upload]) }
      end

      context 'to private project' do
        let(:project) { create(:project, :private, :repository) }

        it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_upload]) }
      end
    end
  end

  context 'when the repository is read-only' do
    let(:project) { create(:project, :repository, :read_only) }

    it 'denies push access' do
      project.add_maintainer(user)

      expect { push_access_check }.to raise_forbidden('The repository is temporarily read-only. Please try again later.')
    end
  end

  describe '#check_read_only_push!' do
    # Non-project containers (e.g. group wikis) resolve `project` to nil, so the
    # read-only check must not blow up when there is no project to query.
    it 'does not raise when there is no project' do
      git_access = access
      allow(git_access).to receive(:project).and_return(nil)

      expect { git_access.send(:check_read_only_push!) }.not_to raise_error
    end
  end

  context 'when archived' do
    let_it_be_with_reload(:group) { create(:group, maintainers: user) }
    let_it_be_with_reload(:project) { create(:project, :repository, group: group) }

    context 'when project is archived' do
      before do
        project.update!(archived: true)
      end

      it 'denies push access' do
        expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:archived])
      end
    end

    context 'when group is archived' do
      before do
        group.update!(archived: true)
      end

      it 'denies push access' do
        expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:archived])
      end
    end
  end

  describe 'deploy key permissions' do
    let_it_be_with_reload(:key) { create(:deploy_key, user: user) }
    let(:actor) { key }

    context 'when deploy_key can push' do
      context 'when project is authorized' do
        before do
          key.deploy_keys_projects.create!(project: project, can_push: true)
        end

        it { expect { push_access_check }.not_to raise_error }

        context 'with a wildcard restriction and exact deploy key access' do
          before do
            project.add_developer(user)
            create(:protected_branch, :no_one_can_push, project: project, name: '*')
            exact = create(:protected_branch, project: project, name: 'feature')
            create(:protected_branch_push_access_level, protected_branch: exact, deploy_key: key)
          end

          it 'allows the exact branch and denies wildcard-protected changes', :aggregate_failures do
            expect { push_changes('6f6d7e7ed 570e7b2ab refs/heads/feature') }.not_to raise_error
            expect { push_changes('6f6d7e7ed 570e7b2ab refs/heads/master') }
              .to raise_forbidden(Gitlab::Checks::BranchCheck::ERROR_MESSAGES[:push_protected_branch])
            expect { push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2ab refs/heads/new_branch") }
              .to raise_forbidden(Gitlab::Checks::BranchCheck::ERROR_MESSAGES[:create_protected_branch])
            expect { push_changes("#{TestEnv::BRANCH_SHA['markdown']} #{Gitlab::Git::SHA1_BLANK_SHA} refs/heads/markdown") }
              .to raise_forbidden(Gitlab::Checks::BranchCheck::ERROR_MESSAGES[:non_master_delete_protected_branch])
          end
        end

        context 'when project is archived' do
          before do
            project.update!(archived: true)
          end

          it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:archived]) }
        end
      end

      context 'when unauthorized' do
        context 'to public project' do
          let(:project) { create(:project, :public, :repository) }

          it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:deploy_key_upload]) }
        end

        context 'to internal project' do
          let(:project) { create(:project, :internal, :repository) }

          it { expect { push_access_check }.to raise_not_found }
        end

        context 'to private project' do
          let(:project) { create(:project, :private, :repository) }

          it { expect { push_access_check }.to raise_not_found }
        end
      end
    end

    context 'when deploy_key cannot push' do
      context 'when project is authorized' do
        before do
          key.deploy_keys_projects.create!(project: project, can_push: false)
        end

        it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:deploy_key_upload]) }
      end

      context 'when unauthorized' do
        context 'to public project' do
          let(:project) { create(:project, :public, :repository) }

          it { expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:deploy_key_upload]) }
        end

        context 'to internal project' do
          let(:project) { create(:project, :internal, :repository) }

          it { expect { push_access_check }.to raise_not_found }
        end

        context 'to private project' do
          let(:project) { create(:project, :private, :repository) }

          it { expect { push_access_check }.to raise_not_found }
        end
      end
    end
  end
end
