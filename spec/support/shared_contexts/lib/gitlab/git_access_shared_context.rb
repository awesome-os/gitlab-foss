# frozen_string_literal: true

RSpec.shared_context 'with git access spec helpers' do
  let(:access_class) do
    Class.new(described_class) do
      def push_ability
        :push_code
      end

      def download_ability
        :download_code
      end
    end
  end

  private

  def access
    access_class.new(actor, project, protocol,
      authentication_abilities: authentication_abilities,
      repository_path: repository_path,
      redirected_path: redirected_path, auth_result_type: auth_result_type, gitaly_context: gitaly_context,
      personal_access_token: personal_access_token,
      oauth_access_token: oauth_access_token)
  end

  def push_changes(changes)
    access.check('git-receive-pack', changes)
  end

  def raise_forbidden(message)
    raise_error(described_class::ForbiddenError, message)
  end

  def raise_not_found
    raise_error(described_class::NotFoundError, described_class::ERROR_MESSAGES[:project_not_found])
  end

  def build_authentication_abilities
    [
      :read_project,
      :build_download_code
    ]
  end
end
