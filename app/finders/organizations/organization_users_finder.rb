# frozen_string_literal: true

# Organizations::OrganizationUsersFinder
#
# Used to find Users of an Organization
module Organizations
  class OrganizationUsersFinder
    # @param organization [Organizations::Organization]
    # @param current_user [User]
    # @param search [String, nil] filters by user name, username, or public email
    # @param exclude_user_ids [Array<Integer>]
    def initialize(organization:, current_user:, search: nil, exclude_user_ids: [])
      @organization = organization
      @current_user = current_user
      @search = search
      @exclude_user_ids = exclude_user_ids
    end

    def execute
      return User.none if organization.nil? || !authorized?

      without_excluded_users(by_search)
    end

    private

    attr_reader :organization, :current_user, :search, :exclude_user_ids

    def all_organization_users
      organization.organization_users
    end

    def by_search
      return all_organization_users if search.blank?

      all_organization_users.by_user(User.search(search, use_minimum_char_limit: true).without_order.select(:id))
    end

    def without_excluded_users(organization_users)
      return organization_users if exclude_user_ids.blank?

      organization_users.without_user_ids(exclude_user_ids)
    end

    def authorized?
      Ability.allowed?(current_user, :read_organization_user, organization)
    end
  end
end
