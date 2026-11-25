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
  let(:pull_access_check) { access.check('git-upload-pack', changes) }

  describe '#check_authentication_abilities!' do
    context 'with a granular personal access token' do
      let(:personal_access_token) { build(:granular_pat) }

      it 'delegates to check_granular_token_permissions!' do
        instance = access
        expect(instance).to receive(:check_granular_token_permissions!)

        instance.send(:check_authentication_abilities!)
      end
    end

    context 'without a personal access token' do
      it 'delegates to check_legacy_authentication_abilities!' do
        instance = access
        expect(instance).not_to receive(:check_granular_token_permissions!)
        expect(instance).to receive(:check_legacy_authentication_abilities!)

        instance.send(:check_authentication_abilities!)
      end
    end

    context 'with a non-granular personal access token' do
      let(:personal_access_token) { build(:personal_access_token) }

      it 'delegates to both check_granular_token_permissions! and check_legacy_authentication_abilities!' do
        instance = access
        expect(instance).to receive(:check_granular_token_permissions!)
        expect(instance).to receive(:check_legacy_authentication_abilities!)

        instance.send(:check_authentication_abilities!)
      end
    end

    context 'with a granular OAuth access token' do
      let(:oauth_access_token) { build(:oauth_access_token, :granular) }

      it 'delegates to check_granular_token_permissions! only' do
        instance = access
        expect(instance).to receive(:check_granular_token_permissions!)
        expect(instance).not_to receive(:check_legacy_authentication_abilities!)

        instance.send(:check_authentication_abilities!)
      end
    end

    context 'with a non-granular OAuth access token' do
      let(:oauth_access_token) { build(:oauth_access_token, scopes: ['api']) }

      it 'delegates to both check_granular_token_permissions! and check_legacy_authentication_abilities!' do
        instance = access
        expect(instance).to receive(:check_granular_token_permissions!)
        expect(instance).to receive(:check_legacy_authentication_abilities!)

        instance.send(:check_authentication_abilities!)
      end
    end

    context 'with an IAM OAuth token' do
      let(:oauth_access_token) { instance_double(Authn::Tokens::IamOauthToken) }

      it 'grants access based on authentication abilities' do
        project.add_developer(user)

        expect { pull_access_check }.not_to raise_error
      end
    end
  end

  describe '#check_legacy_authentication_abilities!' do
    before do
      project.add_maintainer(user)
    end

    context 'when download' do
      let(:authentication_abilities) { [] }

      it 'raises unauthorized with download error' do
        expect { pull_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_download])
      end

      context 'when authentication abilities include download code' do
        let(:authentication_abilities) { [:download_code] }

        it 'does not raise any errors' do
          expect { pull_access_check }.not_to raise_error
        end
      end

      context 'when authentication abilities include build download code' do
        let(:authentication_abilities) { [:build_download_code] }

        it 'does not raise any errors' do
          expect { pull_access_check }.not_to raise_error
        end
      end
    end

    context 'when upload' do
      let(:authentication_abilities) { [] }

      it 'raises unauthorized with push error' do
        expect { push_access_check }.to raise_forbidden(described_class::ERROR_MESSAGES[:auth_upload])
      end

      context 'when authentication abilities include push code' do
        let(:authentication_abilities) { [:push_code] }

        it 'does not raise any errors' do
          expect { push_access_check }.not_to raise_error
        end
      end
    end
  end

  describe '#check_granular_token_permissions!' do
    before do
      project.add_developer(user)
    end

    context 'without a personal access token' do
      it 'does not check granular permissions' do
        expect(::Authz::Tokens::AuthorizeGranularScopesService).not_to receive(:new)

        expect { pull_access_check }.not_to raise_error
      end
    end

    context 'with a non-granular personal access token' do
      let(:personal_access_token) { create(:personal_access_token, user: user) }

      it 'authorizes via the granular scopes service without denying access' do
        expect(::Authz::Tokens::AuthorizeGranularScopesService).to receive(:new).and_call_original

        expect { pull_access_check }.not_to raise_error
      end

      context 'when granular tokens are enforced for the namespace' do
        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, :repository, group: group) }

        before do
          group.namespace_settings.update!(
            enforce_granular_tokens: true,
            granular_tokens_enforced_after: Date.current
          )
        end

        it 'denies git pull' do
          expect { pull_access_check }.to raise_error(described_class::ForbiddenError,
            'Access denied: This operation requires a fine-grained personal access token ' \
            "with the following project permissions: [Code: Download].")
        end

        it 'denies git push' do
          expect { push_access_check }.to raise_error(described_class::ForbiddenError,
            'Access denied: This operation requires a fine-grained personal access token ' \
            "with the following project permissions: [Code: Push].")
        end
      end
    end

    shared_examples 'granular token git access checks' do |token_type|
      context 'when token has no code permissions' do
        let(:permissions) { [] }

        it 'denies git pull' do
          expect { pull_access_check }.to raise_error(described_class::ForbiddenError,
            "Access denied: This operation requires a fine-grained #{token_type} " \
            "with the following project permissions: [Code: Download].")
        end

        it 'denies git push' do
          expect { push_access_check }.to raise_error(described_class::ForbiddenError,
            "Access denied: This operation requires a fine-grained #{token_type} " \
            "with the following project permissions: [Code: Push].")
        end
      end

      context 'when token has download_code permission' do
        let(:permissions) { :download_code }

        it 'allows git pull' do
          expect { pull_access_check }.not_to raise_error
        end

        it 'denies git push' do
          expect { push_access_check }.to raise_error(described_class::ForbiddenError,
            "Access denied: This operation requires a fine-grained #{token_type} " \
            "with the following project permissions: [Code: Push].")
        end
      end

      context 'when token has push_code permission' do
        let(:permissions) { :push_code }

        it 'allows git push' do
          expect { push_access_check }.not_to raise_error
        end

        it 'denies git pull' do
          expect { pull_access_check }.to raise_error(described_class::ForbiddenError,
            "Access denied: This operation requires a fine-grained #{token_type} " \
            "with the following project permissions: [Code: Download].")
        end
      end

      context 'when token has both download_code and push_code permissions' do
        let(:permissions) { [:push_code, :download_code] }

        it 'allows git pull' do
          expect { pull_access_check }.not_to raise_error
        end

        it 'allows git push' do
          expect { push_access_check }.not_to raise_error
        end
      end

      context 'when the project is private and the token user is not a member' do
        let_it_be(:project) { create(:project, :private, :repository) }
        let(:permissions) { [] }

        before do
          project.members.find_by(user_id: user.id)&.destroy!
        end

        it 'raises NotFoundError on git pull' do
          expect { pull_access_check }.to raise_error(described_class::NotFoundError,
            described_class.error_message(:project_not_found))
        end

        it 'raises NotFoundError on git push' do
          expect { push_access_check }.to raise_error(described_class::NotFoundError,
            described_class.error_message(:project_not_found))
        end
      end

      context 'when the project is internal and the token user is not a member' do
        let_it_be(:project) { create(:project, :internal, :repository) }
        let(:permissions) { [] }

        before do
          project.members.find_by(user_id: user.id)&.destroy!
        end

        it 'raises ForbiddenError on git pull' do
          expect { pull_access_check }.to raise_error(described_class::ForbiddenError)
        end

        it 'raises ForbiddenError on git push' do
          expect { push_access_check }.to raise_error(described_class::ForbiddenError)
        end
      end
    end

    context 'with a granular personal access token' do
      let(:boundary) { Authz::Boundary.for(project) }
      let(:personal_access_token) { create(:granular_pat, user: user, boundary: boundary, permissions: permissions) }

      it_behaves_like 'granular token git access checks', 'personal access token'

      context 'when the project is public and the token has no code permissions' do
        let_it_be(:project) { create(:project, :public, :repository) }
        let(:permissions) { [] }

        it 'allows git pull, as anonymous users can' do
          expect { pull_access_check }.not_to raise_error
        end

        it 'denies git push' do
          expect { push_access_check }.to raise_error(described_class::ForbiddenError,
            'Access denied: This operation requires a fine-grained personal access token ' \
            "with the following project permissions: [Code: Push].")
        end
      end
    end

    context 'with a granular OAuth access token' do
      let_it_be(:application) { create(:oauth_application) }

      let(:authentication_abilities) { [] }
      let(:oauth_access_token) do
        create(:oauth_access_token, :granular, resource_owner: user, application: application)
      end

      let!(:consent_grant) do
        create(:oauth_consent_grant, user: user, application: application,
          boundary: Authz::Boundary.for(project), permissions: permissions)
      end

      it_behaves_like 'granular token git access checks', 'oauth access token'

      context 'when the consent grant is revoked' do
        let(:permissions) { :download_code }

        before do
          consent_grant.revoked!
        end

        it 'denies git pull' do
          expect { pull_access_check }.to raise_error(described_class::ForbiddenError,
            'Access denied: This operation requires a fine-grained oauth access token ' \
            "with the following project permissions: [Code: Download].")
        end
      end
    end

    context 'with a non-granular OAuth access token' do
      let(:oauth_access_token) { create(:oauth_access_token, resource_owner: user, scopes: ['api']) }

      it 'grants access based on authentication abilities' do
        expect { pull_access_check }.not_to raise_error
      end

      context 'when granular tokens are enforced for the namespace' do
        let(:group) { create(:group) }
        let(:project) { create(:project, :repository, group: group) }

        before do
          group.namespace_settings.update!(
            enforce_granular_tokens: true,
            granular_tokens_enforced_after: Date.current
          )
        end

        it 'grants access based on authentication abilities' do
          expect { pull_access_check }.not_to raise_error
        end
      end
    end
  end

  describe '#permission_for_command' do
    before do
      project.add_developer(user)
    end

    context 'with a download command' do
      it 'returns :download_code' do
        git_access = access
        git_access.check('git-upload-pack', changes)
        expect(git_access.send(:permission_for_command)).to eq(:download_code)
      end
    end

    context 'with a push command' do
      it 'returns :push_code' do
        git_access = access
        git_access.check('git-receive-pack', changes)
        expect(git_access.send(:permission_for_command)).to eq(:push_code)
      end
    end

    context 'with an unknown command' do
      it 'returns nil' do
        expect(access.send(:permission_for_command)).to be_nil
      end
    end
  end

  describe '#has_authentication_ability?' do
    context 'with a granular personal access token' do
      let(:personal_access_token) { build(:granular_pat) }
      let(:authentication_abilities) { [] }

      it 'returns true regardless of authentication_abilities' do
        expect(access.send(:has_authentication_ability?, :download_code)).to be(true)
      end
    end

    context 'with a granular OAuth access token' do
      let(:oauth_access_token) { build(:oauth_access_token, :granular) }
      let(:authentication_abilities) { [] }

      it 'returns true regardless of authentication_abilities' do
        expect(access.send(:has_authentication_ability?, :download_code)).to be(true)
      end
    end

    context 'without a granular personal access token' do
      context 'when authentication_abilities includes the ability' do
        let(:authentication_abilities) { [:download_code] }

        it 'returns true' do
          expect(access.send(:has_authentication_ability?, :download_code)).to be(true)
        end
      end

      context 'when authentication_abilities does not include the ability' do
        let(:authentication_abilities) { [] }

        it 'returns false' do
          expect(access.send(:has_authentication_ability?, :download_code)).to be(false)
        end
      end
    end
  end

  describe '#user_can_download?' do
    before do
      project.add_developer(user)
    end

    context 'without a granular personal access token' do
      context 'when authentication_abilities includes :download_code' do
        let(:authentication_abilities) { [:download_code] }

        it 'returns true' do
          expect(access.send(:user_can_download?)).to be(true)
        end
      end

      context 'when authentication_abilities does not include :download_code' do
        let(:authentication_abilities) { [] }

        it 'returns falsey' do
          expect(access.send(:user_can_download?)).to be_falsey
        end
      end
    end

    context 'with a granular personal access token and empty authentication_abilities' do
      let(:personal_access_token) { create(:granular_pat) }
      let(:authentication_abilities) { [] }

      it 'returns true' do
        expect(access.send(:user_can_download?)).to be(true)
      end
    end
  end

  describe '#user_can_push?' do
    before do
      project.add_developer(user)
    end

    context 'without a granular personal access token' do
      context 'when authentication_abilities includes :push_code' do
        let(:authentication_abilities) { [:push_code] }

        it 'returns true' do
          expect(access.send(:user_can_push?)).to be(true)
        end
      end

      context 'when authentication_abilities does not include :push_code' do
        let(:authentication_abilities) { [] }

        it 'returns falsey' do
          expect(access.send(:user_can_push?)).to be_falsey
        end
      end
    end

    context 'with a granular personal access token and empty authentication_abilities' do
      let(:personal_access_token) { create(:granular_pat) }
      let(:authentication_abilities) { [] }

      it 'returns true' do
        expect(access.send(:user_can_push?)).to be(true)
      end
    end
  end
end
