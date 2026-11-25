# frozen_string_literal: true

module Gitlab
  module MobilePush
    # Builds the APNs notification content for a todo. The copy mirrors the
    # GitLab mobile app's to-do list (`Todo.actionText` / `showAuthor` in the
    # app) so pushes read exactly like the rows they open.
    #
    # The `gitlab` dict also names who acted (`author_*`) and when the todo was
    # raised (`created_at`), what a to-do list row knows and a tap on the push
    # otherwise does not. A `review_submitted` todo's dict also names the
    # review (`review_id`), so the app opens exactly that review instead of
    # picking it out of the merge request's discussions by author and time.
    #
    # In :id_only mode (the subscription's payload_mode) no user content
    # leaves the instance: the alert is a fixed generic sentence, the
    # `gitlab` dict carries identifiers only, and `mutable-content` is set
    # so the app's notification service extension can fetch and render the
    # real content on-device.
    #
    # In :encrypted mode (a subscription with a content key) the alert is the
    # same generic sentence and `mutable-content` is set, but the `gitlab`
    # dict carries the full-mode content sealed for that one device
    # (`gitlab_data_for`, EncryptedContent): Apple relays it, the extension
    # opens it, and neither title nor body is ever in the clear off the
    # instance.
    class Payload
      GENERIC_BODY = 'You have a new to-do'
      # Byte caps that keep an encrypted push under APNs' 4 KB limit: per alert
      # text, and for the sealed `gitlab` dict's JSON (the rest is the fixed `aps`
      # block). Bytes, not characters: CJK and emoji take three to four each.
      ENCRYPTED_TEXT_BYTES = 300
      ENCRYPTED_DATA_BYTES = 3_500
      ACTION_PHRASES = {
        'assigned' => 'assigned you.',
        'review_requested' => 'requested a review.',
        'mentioned' => 'mentioned you.',
        'directly_addressed' => 'mentioned you.',
        'build_failed' => 'The pipeline failed.',
        'marked' => 'added a to-do item.',
        'approval_required' => 'created a merge request you can approve.',
        'added_approver' => 'created a merge request you can approve.',
        'unmergeable' => 'Could not merge.',
        'merge_train_removed' => 'Removed from Merge Train.',
        'review_submitted' => 'reviewed your merge request.',
        'review_approved' => 'approved your merge request.',
        'review_changes_requested' => 'requested changes to your merge request.',
        'member_access_requested' => 'has requested access.',
        'okr_checkin_requested' => 'requested an OKR update.',
        'ssh_key_expired' => 'Your SSH key has expired.',
        'ssh_key_expiring_soon' => 'Your SSH key is expiring soon.'
      }.freeze

      # Actions whose phrase is a standalone sentence. The app hides the
      # author for these (`showAuthor == false`), so the body does too.
      AUTHORLESS_ACTIONS = %w[
        build_failed
        unmergeable
        merge_train_removed
        ssh_key_expired
        ssh_key_expiring_soon
      ].freeze

      def initialize(todo, mode: :full)
        @todo = todo
        @mode = mode.to_sym
      end

      def id_only?
        mode == :id_only
      end

      def encrypted?
        mode == :encrypted
      end

      # @return [String, nil] what the alert shows before the extension runs
      def title
        return if id_only? || encrypted?

        full_title
      end

      def subtitle
        return if id_only? || encrypted?

        full_subtitle
      end

      def body
        return GENERIC_BODY if id_only? || encrypted?

        full_body
      end

      def badge
        todo.user.todos_pending_count
      end

      def thread_id
        return if id_only? || encrypted?

        full_thread_id
      end

      def collapse_id
        "todo-#{todo.id}"
      end

      def mutable_content?
        id_only? || encrypted?
      end

      # @return [Hash] the `gitlab` object for `subscription`: in encrypted mode
      #   the full content sealed under that device's key, otherwise `gitlab_data`
      def gitlab_data_for(subscription)
        return gitlab_data unless encrypted?

        key = subscription.content_key_bytes
        # A subscription whose key no longer decodes is sent as id_only.
        return id_only_gitlab_data unless key

        sealed = {
          version: 1,
          type: 'todo',
          content: EncryptedContent.seal(
            Gitlab::Json.dump(plaintext_for_extension),
            key: key,
            device_token: subscription.device_token
          )
        }

        # The untruncated fields (paths, URLs) can still outgrow the budget;
        # the extension then fetches the content on-device as for id_only.
        return id_only_gitlab_data if Gitlab::Json.dump(sealed).bytesize > ENCRYPTED_DATA_BYTES

        sealed
      end

      def gitlab_data
        return id_only_gitlab_data if id_only? || encrypted?

        full_gitlab_data
      end

      private

      def id_only_gitlab_data
        { version: 1, type: 'todo', todo_id: todo.id, user_id: todo.user_id }
      end

      def full_gitlab_data
        {
          version: 1,
          type: 'todo',
          todo_id: todo.id,
          user_id: todo.user_id,
          action: action,
          target_type: todo.target_type,
          project_path: full_path,
          iid: todo.target.try(:iid),
          target_url: todo.target_url,
          note_id: todo.note_id,
          created_at: todo.created_at.utc.iso8601(3),
          author_id: todo.author_id,
          author_name: todo.author_name,
          author_username: todo.author.username,
          author_avatar_url: todo.author.avatar_url(only_path: false),
          **review_data
        }
      end

      attr_reader :todo, :mode

      # @return [Hash] the extension's plaintext: the full-mode alert fields over
      #   the full-mode `gitlab` dict, the keys `NotificationService.swift` reads
      def plaintext_for_extension
        {
          title: full_title.truncate_bytes(ENCRYPTED_TEXT_BYTES),
          subtitle: full_subtitle.truncate_bytes(ENCRYPTED_TEXT_BYTES),
          body: full_body.truncate_bytes(ENCRYPTED_TEXT_BYTES),
          thread_id: full_thread_id,
          gitlab: full_gitlab_data
        }.compact
      end

      def full_title
        target_title.presence || reference
      end

      def full_subtitle
        [full_path, reference].compact_blank.join(' · ')
      end

      def full_body
        return action_phrase if AUTHORLESS_ACTIONS.include?(action)

        [todo.author_name, action_phrase].compact_blank.join(' ')
      end

      def full_thread_id
        "#{full_path}#{reference}"
      end

      def action
        todo.action_name.to_s
      end

      def action_phrase
        ACTION_PHRASES.fetch(action) { "#{action.tr('_', ' ')}." }
      end

      def target_title
        todo.target.try(:title) || todo.target.try(:name)
      end

      def reference
        todo.target_reference.to_s
      end

      def full_path
        todo.resource_parent&.full_path
      end

      def review_data
        review_id = todo.review_id
        return {} unless review_id

        { review_id: review_id }
      end
    end
  end
end
