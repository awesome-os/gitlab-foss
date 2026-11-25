# frozen_string_literal: true

module CollaborativeEditing
  class WikiPageChannel < BaseChannel
    private

    def find_container
      container = Routable.find_by_full_path(params[:container_full_path].to_s)

      container if container.respond_to?(:wiki)
    end

    def feature_enabled?(container)
      Feature.enabled?(:wiki_collaborative_editing, container.root_ancestor)
    end

    def authorized?(container)
      return false unless Ability.allowed?(current_user, :create_wiki, container)

      !granular_authorization_denied?(
        boundaries: ::Authz::Boundary.for(container),
        permissions: :create_wiki
      )
    end

    def find_document(container)
      wiki = Wiki.for_container(container, current_user)
      page = wiki.find_page(params[:slug].to_s, load_content: false)
      raise LookupError if wiki.error_message.present?

      page
    end

    def document_key(container, page)
      Gitlab::CollaborativeEditing::DocumentStore.document_key(container, page.slug)
    end

    def document_version(page)
      page.last_commit_sha
    rescue Gitlab::Git::BaseError
      raise LookupError
    end
  end
end
