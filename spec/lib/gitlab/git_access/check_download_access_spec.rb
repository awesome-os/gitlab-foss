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
  let(:pull_access_check) { access.check('git-upload-pack', changes) }

  describe '#check_download_access!' do
    it 'allows maintainers to pull' do
      project.add_maintainer(user)

      expect { pull_access_check }.not_to raise_error
    end

    it 'disallows guests to pull' do
      project.add_guest(user)

      expect { pull_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:download])
    end

    it 'disallows blocked users to pull' do
      project.add_maintainer(user)
      user.block

      expect { pull_access_check }.to raise_forbidden('Your account has been blocked.')
    end

    it 'disallows users that are blocked pending approval to pull' do
      project.add_maintainer(user)
      user.block_pending_approval

      expect { pull_access_check }.to raise_forbidden('Your account is pending approval from your administrator and hence blocked.')
    end

    it 'disallows deactivated users to pull' do
      project.add_maintainer(user)
      user.deactivate!

      expect { pull_access_check }.to raise_forbidden("Your account has been deactivated by your administrator. Please log back in from a web browser to reactivate your account at #{Gitlab.config.gitlab.url}")
    end

    it 'disallows users with expired password to pull' do
      project.add_maintainer(user)
      user.update!(password_expires_at: 2.minutes.ago)

      expect { pull_access_check }.to raise_forbidden("Your password expired. Please access GitLab from a web browser to update your password.")
    end

    context 'with an ldap user' do
      let(:user) { create(:omniauth_user, provider: 'ldap', password_expires_at: 2.minutes.ago) }

      it 'allows ldap users with expired password to pull' do
        project.add_maintainer(user)

        expect { pull_access_check }.not_to raise_error
      end
    end

    context 'when the project repository does not exist' do
      before do
        project.add_guest(user)
        allow(project.repository).to receive(:exists?).and_return(false)
      end

      it 'returns not found' do
        expect { pull_access_check }.to raise_error(Gitlab::GitAccess::NotFoundError, 'A repository for this project does not exist yet.')
      end
    end

    describe 'without access to project' do
      context 'pull code' do
        it { expect { pull_access_check }.to raise_not_found }
      end

      context 'when project is public' do
        let_it_be_with_reload(:public_project) { create(:project, :public, :repository) }
        let(:repository_path) { "#{public_project.full_path}.git" }
        let(:access) { access_class.new(nil, public_project, 'web', authentication_abilities: [:download_code], repository_path: repository_path) }

        context 'when repository is enabled' do
          it 'give access to download code' do
            expect { pull_access_check }.not_to raise_error
          end
        end

        context 'when repository is disabled' do
          it 'does not give access to download code' do
            public_project.project_feature.update_attribute(:repository_access_level, ProjectFeature::DISABLED)

            expect { pull_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:download])
          end
        end
      end
    end

    describe 'deploy key permissions' do
      let_it_be_with_reload(:key) { create(:deploy_key, user: user) }
      let(:actor) { key }

      context 'pull code' do
        context 'when project is public' do
          let(:project) { create(:project, :public, :repository, *options) }

          context 'when deploy key exists in the project' do
            before do
              key.projects << project
            end

            context 'when the repository is public' do
              let(:options) { %i[repository_enabled] }

              it { expect { pull_access_check }.not_to raise_error }
            end

            context 'when the repository is private' do
              let(:options) { %i[repository_private] }

              it { expect { pull_access_check }.not_to raise_error }
            end

            context 'when the repository is disabled' do
              let(:options) { %i[repository_disabled] }

              it { expect { pull_access_check }.to raise_error('You are not allowed to download code from this project.') }
            end
          end

          context 'when deploy key does not exist in the project' do
            context 'when the repository is public' do
              let(:options) { %i[repository_enabled] }

              it { expect { pull_access_check }.not_to raise_error }
            end

            context 'when the repository is private' do
              let(:options) { %i[repository_private] }

              it { expect { pull_access_check }.to raise_error('You are not allowed to download code from this project.') }
            end

            context 'when the repository is disabled' do
              let(:options) { %i[repository_disabled] }

              it { expect { pull_access_check }.to raise_error('You are not allowed to download code from this project.') }
            end
          end
        end

        context 'when project is internal' do
          let(:project) { create(:project, :internal, :repository, *options) }

          context 'when deploy key exists in the project' do
            before do
              key.projects << project
            end

            context 'when the repository is public' do
              let(:options) { %i[repository_enabled] }

              it { expect { pull_access_check }.not_to raise_error }
            end

            context 'when the repository is private' do
              let(:options) { %i[repository_private] }

              it { expect { pull_access_check }.not_to raise_error }
            end

            context 'when the repository is disabled' do
              let(:options) { %i[repository_disabled] }

              it { expect { pull_access_check }.to raise_error('You are not allowed to download code from this project.') }
            end
          end

          context 'when deploy key does not exist in the project' do
            context 'when the repository is public' do
              let(:options) { %i[repository_enabled] }

              it { expect { pull_access_check }.to raise_error("The project you were looking for could not be found or you don't have permission to view it.") }
            end

            context 'when the repository is private' do
              let(:options) { %i[repository_private] }

              it { expect { pull_access_check }.to raise_error("The project you were looking for could not be found or you don't have permission to view it.") }
            end

            context 'when the repository is disabled' do
              let(:options) { %i[repository_disabled] }

              it { expect { pull_access_check }.to raise_error("The project you were looking for could not be found or you don't have permission to view it.") }
            end
          end
        end

        context 'when project is private' do
          let(:project) { create(:project, :private, :repository, *options) }

          context 'when deploy key exists in the project' do
            before do
              key.projects << project
            end

            context 'when the repository is private' do
              let(:options) { %i[repository_private] }

              it { expect { pull_access_check }.not_to raise_error }
            end

            context 'when the repository is disabled' do
              let(:options) { %i[repository_disabled] }

              it { expect { pull_access_check }.to raise_error('You are not allowed to download code from this project.') }
            end
          end

          context 'when deploy key does not exist in the project' do
            context 'when the repository is private' do
              let(:options) { %i[repository_private] }

              it { expect { pull_access_check }.to raise_error("The project you were looking for could not be found or you don't have permission to view it.") }
            end

            context 'when the repository is disabled' do
              let(:options) { %i[repository_disabled] }

              it { expect { pull_access_check }.to raise_error("The project you were looking for could not be found or you don't have permission to view it.") }
            end
          end
        end
      end
    end

    describe 'deploy token permissions' do
      let(:deploy_token) { create(:deploy_token) }
      let(:actor) { deploy_token }

      context 'pull code' do
        context 'when project is authorized' do
          let(:deploy_token) { create(:deploy_token, projects: [project]) }

          it { expect { pull_access_check }.not_to raise_error }
        end

        context 'when unauthorized' do
          context 'from public project' do
            let(:project) { create(:project, :public, :repository) }

            it { expect { pull_access_check }.not_to raise_error }
          end

          context 'from internal project' do
            let(:project) { create(:project, :internal, :repository) }

            it { expect { pull_access_check }.to raise_not_found }
          end

          context 'from private project' do
            let(:project) { create(:project, :private, :repository) }

            it { expect { pull_access_check }.to raise_not_found }
          end
        end
      end
    end

    describe 'build authentication_abilities permissions' do
      let(:authentication_abilities) { build_authentication_abilities }

      describe 'owner' do
        let(:project) { create(:project, :repository, namespace: user.namespace) }

        context 'pull code' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end

      describe 'reporter user' do
        before do
          project.add_reporter(user)
        end

        context 'pull code' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end

      describe 'admin user' do
        let(:user) { create(:admin) }

        context 'when admin mode enabled', :enable_admin_mode do
          context 'when member of the project' do
            before do
              project.add_reporter(user)
            end

            context 'pull code' do
              it { expect { pull_access_check }.not_to raise_error }
            end
          end

          context 'when is not member of the project' do
            context 'pull code' do
              it { expect { pull_access_check }.not_to raise_error }
            end
          end
        end

        context 'when admin mode disabled' do
          context 'when member of the project' do
            before do
              project.add_reporter(user)
            end

            context 'pull code' do
              it { expect { pull_access_check }.not_to raise_error }
            end
          end

          context 'when is not member of the project' do
            context 'pull code' do
              it { expect { pull_access_check }.to raise_not_found }
            end
          end
        end
      end

      describe 'generic CI (build without a user)' do
        let(:actor) { :ci }

        specify { expect { pull_access_check }.to raise_error Gitlab::GitAccess::NotFoundError }
      end
    end
  end
end
