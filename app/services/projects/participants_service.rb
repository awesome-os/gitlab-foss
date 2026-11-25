# frozen_string_literal: true

module Projects
  class ParticipantsService < BaseService
    include Gitlab::Utils::StrongMemoize
    include Users::ParticipableService

    def execute(noteable)
      @noteable = noteable

      participants =
        noteable_owner +
        assignees_and_reviewers +
        participants_in_noteable +
        project_members +
        mentioned_users(project_members_relation)

      participants += groups(organization: organization) unless relation_at_search_limit?(project_members)
      participants = organization_user_details_for_participants(participants.uniq)

      render_participants_as_hash(participants)
    end

    def project_members
      filter_and_sort_users(project_members_relation)
    end
    strong_memoize_attr :project_members

    def project_members_relation
      project.authorized_users.with_organization_user_details
    end

    private

    def participation_object
      project
    end

    def organization
      project.organization
    end
    strong_memoize_attr :organization

    # for users that have an OrganizationUserDetail for the current organization, use this instead
    # of the User model for rendering username, display_name, and other details
    def organization_user_details_for_participants(participants)
      preload_organization_user_details(participants)

      participants.map do |participant|
        next participant unless participant.is_a?(User)

        detail = participant.organization_user_details.to_a.find do |det|
          det.organization == organization
        end

        detail.presence || participant
      end
    end

    def preload_organization_user_details(participants)
      users = participants.select do |participant|
        participant.is_a?(User) && !participant.association(:organization_user_details).loaded?
      end

      ActiveRecord::Associations::Preloader.new(
        records: users,
        associations: { organization_user_details: :organization }
      ).call
    end
  end
end

Projects::ParticipantsService.prepend_mod_with('Projects::ParticipantsService')
