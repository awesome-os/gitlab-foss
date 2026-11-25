# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitAccess, :aggregate_failures, feature_category: :system_access do
  include_context 'with git access spec helpers'

  let_it_be_with_reload(:user) { create(:user) }
  let(:actor) { user }
  let_it_be(:project) { create(:project, :repository) }
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

  describe '#check with single protocols allowed' do
    def disable_protocol(protocol)
      allow(Gitlab::ProtocolAccess).to receive(:allowed?).with(protocol, project: project).and_return(false)
    end

    context 'ssh disabled' do
      before do
        disable_protocol('ssh')
      end

      it 'blocks ssh git push and pull' do
        aggregate_failures do
          expect { push_access_check }.to raise_forbidden('Git access over SSH is not allowed')
          expect { pull_access_check }.to raise_forbidden('Git access over SSH is not allowed')
        end
      end
    end

    context 'http disabled' do
      let(:protocol) { 'http' }

      before_all do
        project.add_maintainer(user)
      end

      before do
        disable_protocol('http')
      end

      it 'blocks http push and pull' do
        aggregate_failures do
          expect { push_access_check }.to raise_forbidden('Git access over HTTP is not allowed')
          expect { pull_access_check }.to raise_forbidden('Git access over HTTP is not allowed')
        end
      end

      context 'when request is made from CI' do
        let(:auth_result_type) { :build }

        it "doesn't block http pull" do
          aggregate_failures do
            expect { pull_access_check }.not_to raise_error
          end
        end

        context 'when legacy CI credentials are used' do
          let(:auth_result_type) { :ci }

          it "doesn't block http pull" do
            expect { pull_access_check }.not_to raise_error
          end
        end
      end
    end
  end

  describe '#check_project_accessibility!' do
    context 'when the project exists' do
      context 'when actor exists' do
        context 'when actor is a DeployKey' do
          let_it_be_with_reload(:deploy_key) { create(:deploy_key, user: user) }
          let(:actor) { deploy_key }

          context 'when the DeployKey has access to the project' do
            before do
              deploy_key.deploy_keys_projects.create!(project: project, can_push: true)
            end

            it 'allows push and pull access' do
              aggregate_failures do
                expect { push_access_check }.not_to raise_error
                expect { pull_access_check }.not_to raise_error
              end
            end
          end

          context 'when the Deploykey does not have access to the project' do
            it 'blocks push and pull with "not found"' do
              aggregate_failures do
                expect { push_access_check }.to raise_not_found
                expect { pull_access_check }.to raise_not_found
              end
            end
          end

          context 'when the deploy key is restricted with external_authorization' do
            before do
              allow(Gitlab::ExternalAuthorization).to receive(:allow_deploy_tokens_and_deploy_keys?).and_return(false)
            end

            it 'blocks push and pull with "not found"' do
              aggregate_failures do
                expect { push_access_check }.to raise_not_found
                expect { pull_access_check }.to raise_not_found
              end
            end
          end
        end

        context 'when actor is a User' do
          context 'when the User can read the project' do
            before_all do
              project.add_maintainer(user)
            end

            it 'allows push and pull access' do
              aggregate_failures do
                expect { pull_access_check }.not_to raise_error
                expect { push_access_check }.not_to raise_error
              end
            end
          end

          context 'when the User cannot read the project' do
            it 'blocks push and pull with "not found"' do
              aggregate_failures do
                expect { push_access_check }.to raise_not_found
                expect { pull_access_check }.to raise_not_found
              end
            end
          end
        end

        # legacy behavior that is blocked/deprecated
        context 'when actor is :ci' do
          let(:actor) { :ci }
          let(:authentication_abilities) { build_authentication_abilities }

          it 'disallows pull access' do
            expect { pull_access_check }.to raise_error(Gitlab::GitAccess::NotFoundError)
          end

          it 'does not block pushes with "not found"' do
            expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_upload])
          end
        end

        context 'when actor is DeployToken' do
          let(:actor) { create(:deploy_token, projects: [project]) }

          context 'when DeployToken is active and belongs to project' do
            it 'allows pull access' do
              expect { pull_access_check }.not_to raise_error
            end

            it 'blocks the push' do
              expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:upload])
            end
          end

          context 'when DeployToken does not belong to project' do
            let_it_be(:another_project) { create(:project) }
            let(:actor) { create(:deploy_token, projects: [another_project]) }

            it 'blocks pull access' do
              expect { pull_access_check }.to raise_not_found
            end

            it 'blocks the push' do
              expect { push_access_check }.to raise_not_found
            end
          end

          context 'when the deploy token is restricted with external_authorization' do
            before do
              allow(Gitlab::ExternalAuthorization).to receive(:allow_deploy_tokens_and_deploy_keys?).and_return(false)
            end

            it 'blocks pull access' do
              expect { pull_access_check }.to raise_not_found
            end

            it 'blocks the push' do
              expect { push_access_check }.to raise_not_found
            end
          end
        end
      end

      context 'when actor is nil' do
        let(:actor) { nil }

        context 'when guests can read the project' do
          let_it_be(:project) { create(:project, :repository, :public) }

          it 'allows pull access' do
            expect { pull_access_check }.not_to raise_error
          end

          it 'does not block pushes with "not found"' do
            expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:upload])
          end
        end

        context 'when guests cannot read the project' do
          it 'blocks pulls with "not found"' do
            expect { pull_access_check }.to raise_not_found
          end

          it 'blocks pushes with "not found"' do
            expect { push_access_check }.to raise_not_found
          end
        end
      end
    end

    context 'when the project does not exist' do
      let(:project) { nil }
      let(:repository_path) { "#{user.namespace.path}/new-project.git" }

      it 'blocks push and pull with "not found"' do
        aggregate_failures do
          expect { pull_access_check }.to raise_not_found
          expect { push_access_check }.to raise_not_found
        end
      end
    end
  end

  shared_examples '#check with a key that is not valid' do
    before_all do
      project.add_maintainer(user)
    end

    context 'key is expired' do
      before do
        actor.expires_at = 2.days.ago
      end

      it 'does not allow expired keys' do
        expect { pull_access_check }.to raise_forbidden('Your SSH key has expired.')
        expect { push_access_check }.to raise_forbidden('Your SSH key has expired.')
      end
    end

    context 'key is too small' do
      before do
        stub_application_setting(rsa_key_restriction: 4096)
      end

      it 'does not allow keys which are too small' do
        expect(actor).not_to be_valid
        expect { pull_access_check }.to raise_forbidden('Your SSH key must be at least 4096 bits.')
        expect { push_access_check }.to raise_forbidden('Your SSH key must be at least 4096 bits.')
      end
    end

    context 'key type is not allowed' do
      before do
        stub_application_setting(rsa_key_restriction: ApplicationSetting::FORBIDDEN_KEY_VALUE)
      end

      it 'does not allow keys which are forbidden' do
        expect(actor).not_to be_valid
        expect { pull_access_check }.to raise_forbidden(/Your SSH key type is forbidden/)
        expect { push_access_check }.to raise_forbidden(/Your SSH key type is forbidden/)
      end
    end
  end

  it_behaves_like '#check with a key that is not valid' do
    let(:actor) { build(:rsa_key_2048, user: user) }
  end

  it_behaves_like '#check with a key that is not valid' do
    let(:actor) { build(:rsa_deploy_key_2048, user: user) }
  end

  shared_examples 'check_project_moved' do
    it 'enqueues a redirected message for pushing' do
      push_access_check

      expect(Gitlab::Checks::ContainerMoved.fetch_message(user, project.repository)).not_to be_nil
    end

    it 'allows push and pull access' do
      aggregate_failures do
        expect { push_access_check }.not_to raise_error
        expect { pull_access_check }.not_to raise_error
      end
    end
  end

  describe '#add_project_moved_message!', :clean_gitlab_redis_shared_state do
    before_all do
      project.add_maintainer(user)
    end

    context 'when a redirect was not followed to find the project' do
      it 'allows push and pull access' do
        aggregate_failures do
          expect { push_access_check }.not_to raise_error
          expect { pull_access_check }.not_to raise_error
        end
      end
    end

    context 'with a redirect and ssh protocol' do
      let(:redirected_path) { 'some/other-path' }

      it_behaves_like 'check_project_moved'
    end

    context 'with a redirect and http protocol' do
      let(:redirected_path) { 'some/other-path' }
      let(:protocol) { 'http' }

      it_behaves_like 'check_project_moved'
    end
  end

  describe '#check_command_disabled!' do
    before_all do
      project.add_maintainer(user)
    end

    context 'over http' do
      let(:protocol) { 'http' }

      context 'when the git-upload-pack command is disabled in config' do
        before do
          allow(Gitlab.config.gitlab_shell).to receive(:upload_pack).and_return(false)
        end

        context 'when calling git-upload-pack' do
          it { expect { pull_access_check }.to raise_forbidden('Pulling over HTTP is not allowed.') }
        end

        context 'when calling git-receive-pack' do
          it { expect { push_access_check }.not_to raise_error }
        end
      end

      context 'when the git-receive-pack command is disabled in config' do
        before do
          allow(Gitlab.config.gitlab_shell).to receive(:receive_pack).and_return(false)
        end

        context 'when calling git-receive-pack' do
          it { expect { push_access_check }.to raise_forbidden('Pushing over HTTP is not allowed.') }
        end

        context 'when calling git-upload-pack' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end
    end
  end
end
