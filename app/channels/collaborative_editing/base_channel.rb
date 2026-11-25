# frozen_string_literal: true

module CollaborativeEditing
  class BaseChannel < ApplicationCable::Channel
    LookupError = Class.new(StandardError)
    MESSAGE_TYPE_SYNC = 'sync'
    MESSAGE_TYPE_AWARENESS = 'awareness'
    MESSAGE_TYPE_SNAPSHOT = 'snapshot'

    MAX_PAYLOAD_BYTES = 1.megabyte

    REVALIDATE_ACCESS_EVERY = 1.minute

    periodically :revalidate_access, every: REVALIDATE_ACCESS_EVERY

    def initialize_session(data)
      return unless @stream_key
      return if @initial_state_sent

      @initial_state_sent = true
      data = data.with_indifferent_access
      @client_version = data[:version]
      @client_session_id = data[:sessionId]
      @readiness_token = SecureRandom.hex(16)
      ActionCable.server.broadcast(stream_name, { type: 'session_ready', token: @readiness_token })
    end

    def receive(data)
      return unless @stream_key
      return unless valid_payload?(data)
      return if rate_limited?(data['payload'])

      max_bytes = if data['type'] == MESSAGE_TYPE_AWARENESS
                    MAX_PAYLOAD_BYTES
                  else
                    Gitlab::CollaborativeEditing::DocumentStore::MAX_LOG_BYTES
                  end

      if data['payload'].bytesize > max_bytes
        transmit({ type: 'payload_too_large' }) unless data['type'] == MESSAGE_TYPE_AWARENESS
        return
      end

      case data['type']
      when MESSAGE_TYPE_SYNC
        handle_sync(data)
      when MESSAGE_TYPE_AWARENESS
        broadcast(data, identity: true)
      when MESSAGE_TYPE_SNAPSHOT
        handle_snapshot(data)
      end
    end

    private

    attr_reader :store

    def subscribed
      container = find_container
      return reject unless container && feature_enabled?(container)
      return reject unless authorized?(container)

      document = find_document(container)
      return invalidate_session('page_changed') unless document && document_version(document).present?

      @container = container
      @stream_key = document_key(container, document)
      @store = Gitlab::CollaborativeEditing::DocumentStore.new(@stream_key)

      open_session(document_version(document))
    rescue LookupError
      invalidate_session('lookup_failed')
    end

    def unsubscribed
      @container = nil
      @stream_key = nil
      @store = nil
    end

    def authorization_scopes
      [:api]
    end

    def find_container
      raise NotImplementedError
    end

    def feature_enabled?(_container)
      raise NotImplementedError
    end

    def authorized?(_container)
      raise NotImplementedError
    end

    def find_document(_container)
      raise NotImplementedError
    end

    def document_key(_container, _document)
      raise NotImplementedError
    end

    def document_version(_document)
      raise Gitlab::AbstractMethodError
    end

    def stream_name
      store.stream_name(@session_id)
    end

    def open_session(version)
      session = store.open(version: version)
      return invalidate_session('lookup_failed') if session.busy

      @initial_state_sent = false
      @session_ready = false
      @session_id = session.session_id
      stream_from stream_name, coder: ActiveSupport::JSON do |message|
        receive_stream_message(message)
      end
    end

    def receive_stream_message(message)
      return unless @stream_key

      if message['type'] == 'session_ready'
        return unless @readiness_token && message['token'] == @readiness_token

        @readiness_token = nil
        revalidate_access(retry_on_lookup_failure: false)
        return unless @stream_key

        state = store.read_session(session_id: @session_id, client_version: @client_version.to_s,
          remembered_session_id: @client_session_id)
        return invalidate_session('session_expired') unless state
        return invalidate_session('page_changed') if state == :refused

        updates, version, seed = state

        transmit({ type: 'init', updates: updates, seed: seed,
                   sessionId: @session_id, version: version })
        @session_ready = true
      else
        transmit(message)
      end
    end

    def handle_sync(data)
      return invalidate_session('session_expired') unless data['sessionId'] == @session_id

      result = store.append(data['payload'], session_id: @session_id)
      return invalidate_session('session_expired') if result.invalid_session?

      if result.full?
        transmit_document_full(data)
      else
        save_id = data['saveId']
        save_id = nil unless save_id.is_a?(String) && save_id.match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
        accepted = store.claim_save(session_id: @session_id, save_id: save_id, user_id: current_user.id) if save_id
        broadcast(data, save_id: save_id)
        acknowledge(data, save_accepted: save_id ? accepted : nil)
      end

      return unless result.compact?

      transmit({ type: 'request_snapshot', token: result.compaction_token })
    end

    def handle_snapshot(data)
      token = data['token']
      return unless token.is_a?(String)

      return invalidate_session('session_expired') unless data['sessionId'] == @session_id

      result = store.replace(data['payload'], token, session_id: @session_id)
      return invalidate_session('session_expired') if result == :invalid_session

      return transmit_document_full(data) if result == :full

      return unless result == :replaced

      broadcast(data.slice('payload', 'clientId').merge('type' => MESSAGE_TYPE_SYNC))
      acknowledge(data)
    end

    def acknowledge(data, save_accepted: nil)
      message_id = data['messageId']
      transmit({ type: 'ack', messageId: message_id, saveAccepted: save_accepted }.compact) if message_id.is_a?(Integer)
    end

    def transmit_document_full(data)
      message_id = data['messageId']
      transmit({ type: 'document_full', messageId: message_id.is_a?(Integer) ? message_id : nil }.compact)
    end

    def broadcast(data, identity: false, save_id: nil)
      message = data.slice('type', 'payload', 'clientId')
      message['saveId'] = save_id if save_id
      message['user'] = current_user_identity if identity

      ActionCable.server.broadcast(stream_name, message)
    end

    def current_user_identity
      @current_user_identity ||= {
        id: current_user.id,
        name: current_user.name,
        avatarUrl: current_user.avatar_url(only_path: false)
      }
    end

    def valid_payload?(data)
      payload = data['payload']

      payload.is_a?(String) &&
        data['clientId'].is_a?(Integer) &&
        [MESSAGE_TYPE_SYNC, MESSAGE_TYPE_SNAPSHOT, MESSAGE_TYPE_AWARENESS].include?(data['type'])
    end

    def rate_limited?(payload)
      return true if Gitlab::ApplicationRateLimiter.throttled?(
        :collaborative_editing_update_by_user, scope: { user: current_user }
      )

      return true if Gitlab::ApplicationRateLimiter.throttled?(
        :collaborative_editing_bytes_by_user, scope: { user: current_user }, cost: payload.bytesize
      )

      Gitlab::ApplicationRateLimiter.throttled?(
        :collaborative_editing_update,
        scope: { user: current_user, document_key: @stream_key }
      )
    end

    def revalidate_access(retry_on_lookup_failure: true)
      return unless @container

      unless feature_enabled?(@container) && authorized?(@container)
        unsubscribe_from_channel
        return
      end

      document = find_document(@container)
      return invalidate_session('page_changed') unless document && document_version(document).present?

      result = store.touch(session_id: @session_id, version: document_version(document))
      return if result == true || result == :busy
      return invalidate_session('page_changed') if result == :page_changed

      invalidate_session('session_expired')
    rescue LookupError
      return invalidate_session('lookup_failed') unless retry_on_lookup_failure && @session_ready
      return if store.touch(session_id: @session_id)

      invalidate_session('session_expired')
    end

    def invalidate_session(reason)
      transmit({ type: 'session_invalidated', reason: reason })
      stop_all_streams
      @container = nil
      @stream_key = nil
      @store = nil
      @session_id = nil
      @readiness_token = nil
    end
  end
end
