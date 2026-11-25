# frozen_string_literal: true

module Gitlab
  module Auth
    module Ldap
      # Raised when Net::LDAP.open itself fails, so that callers can tell a dead
      # connection apart from a failure inside their own block.
      ConnectionFailedError = Class.new(LdapConnectionError)
    end
  end
end
