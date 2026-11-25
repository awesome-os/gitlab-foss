# frozen_string_literal: true

module Wikis
  class CollaborativeUpdateService < ::BaseContainerService
    def execute(page, session_id:, save_id:)
      previous_version = page.last_commit_sha
      previous_metadata = [page.slug, page.format, page.front_matter.deep_dup]
      store = Gitlab::CollaborativeEditing::DocumentStore.new(
        Gitlab::CollaborativeEditing::DocumentStore.document_key(container, page.slug))
      marker = { session_id: session_id, save_id: save_id, user_id: current_user.id }
      confirmed = store.confirm_save(**marker, version: previous_version)

      begin
        response = WikiPages::UpdateService.new(container: container, current_user: current_user,
          params: params).execute(page)

        if confirmed && response.success? && compatible?(page, previous_metadata)
          version = saved_version(page)
          if version.present? && version != previous_version &&
              store.advance_version(**marker, previous_version: previous_version, version: version)
            ActionCable.server.broadcast(store.stream_name(session_id),
              { type: 'version', previousVersion: previous_version, version: version, saveId: save_id })
          end
        end

        response
      ensure
        store.release_save(**marker)
      end
    end

    private

    def compatible?(page, previous_metadata)
      [page.slug, page.format, Gitlab::WikiPages::FrontMatterParser.new(page.raw_content).parse.front_matter] ==
        previous_metadata
    end

    def saved_version(page)
      page.wiki.repository.last_commit_for_path(page.saved_commit_sha, page.path)&.sha
    rescue Gitlab::Git::BaseError
      nil
    end
  end
end
