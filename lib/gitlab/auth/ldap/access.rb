# frozen_string_literal: true

# LDAP authorization model
#
# * Check if we are allowed access (not blocked)
#
module Gitlab
  module Auth
    module Ldap
      class Access
        attr_reader :provider, :user, :ldap_identity

        def self.open(user, &block)
          Gitlab::Auth::Ldap::Adapter.open(user.ldap_identity.provider) do |adapter|
            yield(self.new(user, adapter))
          end
        end

        def self.allowed?(user, options = {})
          return false unless user.ldap_user?

          self.open(user) do |access|
            # Whether user is allowed, or not, we should update
            # permissions to keep things clean
            if access.allowed?(raise_on_connection_failure: options[:raise_on_connection_failure])
              unless Gitlab::Database.read_only?
                access.update_user
                Users::UpdateService.new(user, user: user, last_credential_check_at: Time.now).execute
              end

              true
            else
              false
            end
          end
        rescue ConnectionFailedError
          # Adapter.open fails before the block runs, so #allowed? never sees this. Bulk callers
          # pass raise_on_connection_failure so an outage is not read as every user leaving LDAP.
          raise if options[:raise_on_connection_failure]

          false
        end

        def initialize(user, adapter = nil)
          @adapter = adapter
          @user = user
          @ldap_identity = user.ldap_identity
          @provider = adapter&.provider || ldap_identity&.provider
        end

        def allowed?(raise_on_connection_failure: false)
          if ldap_user
            unless ldap_config.active_directory
              unblock_user(user, 'is available again') if user.ldap_blocked?
              return true
            end

            # Block user in GitLab if they were blocked in AD
            if Gitlab::Auth::Ldap::Person.disabled_via_active_directory?(ldap_identity.extern_uid, adapter)
              block_user(user, 'is disabled in Active Directory')
              false
            else
              unblock_user(user, 'is not disabled anymore') if user.ldap_blocked?
              true
            end
          else
            # Block the user if they no longer exist in LDAP/AD
            block_user(user, 'does not exist anymore')
            false
          end
        rescue LdapConnectionError
          raise if raise_on_connection_failure

          false
        end

        def update_user
          # no-op in CE
        end

        private

        def adapter
          @adapter ||= Gitlab::Auth::Ldap::Adapter.new(provider)
        end

        def ldap_config
          Gitlab::Auth::Ldap::Config.new(provider)
        end

        def ldap_user
          return unless provider

          @ldap_user ||= find_ldap_user
        end

        def find_ldap_user
          Gitlab::Auth::Ldap::Person.find_by_dn(ldap_identity.extern_uid, adapter) ||
            find_and_recover_ldap_user_with_stale_dn_by_email
        end

        # @note The stored DN goes stale when the LDAP entry moves (e.g. to another OU), so the
        #   corrected DN is persisted for future direct lookups.
        # @return [Gitlab::Auth::Ldap::Person, nil]
        def find_and_recover_ldap_user_with_stale_dn_by_email
          person = find_ldap_user_by_email

          update_stale_dn_for_user(person) if person

          person
        end

        def find_ldap_user_by_email
          Gitlab::Auth::Ldap::Person.find_by_email(user.email, adapter)
        end

        def update_stale_dn_for_user(person)
          stale_dn = ldap_identity.extern_uid

          # Assigned in memory even on a read-only instance,
          # so the `Gitlab::Auth::Ldap::Person.disabled_via_active_directory?` check uses the new DN.
          ldap_identity.extern_uid = person.dn

          return if Gitlab::Database.read_only?

          if ldap_identity.save
            Gitlab::AppLogger.info(
              "LDAP account for GitLab user \"#{user.name}\" (#{user.email}) found at a new DN " \
              "\"#{person.dn}\" (was \"#{stale_dn}\"), updating stored DN"
            )
          else
            Gitlab::AppLogger.error(
              "Could not update stale DN for GitLab user \"#{user.name}\" (#{user.email}) " \
              "to \"#{person.dn}\": #{ldap_identity.errors.full_messages}"
            )
          end
        end

        def block_user(user, reason)
          blocked = user.ldap_block

          if provider
            Gitlab::AppLogger.info(
              "LDAP account \"#{ldap_identity.extern_uid}\" #{reason}, " \
              "blocking GitLab user \"#{user.name}\" (#{user.email})"
            )
          else
            Gitlab::AppLogger.info(
              "Account is not provided by LDAP, " \
              "blocking GitLab user \"#{user.name}\" (#{user.email})"
            )
          end

          log_audit_event_for_block(user, reason) if blocked
        end

        def log_audit_event_for_block(user, reason)
          # no-op in CE
        end

        def unblock_user(user, reason)
          user.activate

          Gitlab::AppLogger.info(
            "LDAP account \"#{ldap_identity.extern_uid}\" #{reason}, " \
            "unblocking GitLab user \"#{user.name}\" (#{user.email})"
          )
        end
      end
    end
  end
end

Gitlab::Auth::Ldap::Access.prepend_mod_with('Gitlab::Auth::Ldap::Access')
