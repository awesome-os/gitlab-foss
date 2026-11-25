# frozen_string_literal: true

module Gitlab
  module DatabaseImporters
    # Creates the GitLab-provided OAuth applications for the GitLab CLI, the VS Code extension and the JetBrains
    # plugin on installations that never ran the SeedFirstPartyOauthApplications migration, such as a new installation.
    #
    # Applications that already exist (matched on client ID) are left untouched, so an administrator's edits survive
    # repeated runs. The definitions are duplicated in that migration on purpose: a migration must not change when this
    # list does.
    module FirstPartyOauthApplicationsImporter
      VSCODE_SCHEMES = %w[vscode vscode-insiders vscodium].freeze

      # Client IDs are the public GitLab.com ones, so clients work against any instance unchanged.
      APPLICATIONS = [
        {
          uid: '36f2a70cddeb5a0889d4fd8295c241b7e9848e89cf9e599d0eed2d8e5350fbf5',
          name: 'GitLab for VS Code',
          redirect_uri: VSCODE_SCHEMES.map { |scheme| "#{scheme}://gitlab.gitlab-workflow/authentication" }.join("\n"),
          scopes: 'api',
          device_code_enabled: false
        },
        {
          uid: '732efe7d78ba62b01d2a95cd3b02f3ca2a00c7cec32c01e060c1b7664a9aa367',
          name: 'GitLab Duo plugin for JetBrains',
          redirect_uri: 'http://127.0.0.1/api/oauth/gitlab/authorization',
          scopes: 'api',
          device_code_enabled: false
        },
        {
          uid: '41d48f9422ebd655dd9cf2947d6979681dfaddc6d0c56f7628f6ada59559af1e',
          name: 'GitLab CLI',
          redirect_uri: 'http://localhost:7171/auth/redirect',
          scopes: 'openid profile read_user write_repository api',
          device_code_enabled: true
        }
      ].freeze

      def self.seed
        # A cell may not own the default organization, and fixtures run before any other organization exists.
        organization = ::Organizations::Organization.default_organization # rubocop:disable Gitlab/AvoidDefaultOrganization -- instance-wide applications live on the default organization
        return unless organization

        APPLICATIONS.each do |attributes|
          next if ::Authn::OauthApplication.exists_for_uid?(attributes[:uid])

          ::Authn::OauthApplication.create!(
            attributes.merge(
              confidential: false,
              trusted: false,
              ropc_enabled: false,
              organization: organization
            )
          )
        end
      end
    end
  end
end
