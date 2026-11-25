# frozen_string_literal: true

module Gitlab
  module CollaborativeEditing
    class DocumentStore
      TTL = 1.hour

      COMPACTION_THRESHOLD = 500
      SEED_CLAIM_TTL = 30.seconds
      COMPACTION_CLAIM_TTL = 30.seconds
      MAX_LOG_LENGTH = COMPACTION_THRESHOLD * 4
      MAX_LOG_BYTES = 16.megabytes
      COMPACTION_BYTES = MAX_LOG_BYTES / 2
      SAVE_TTL = 15.seconds
      SAVE_WRITE_TTL = 1.minute

      FULL = 'full'

      Result = Struct.new(:full, :compaction_token, :invalid_session, keyword_init: true) do
        alias_method :full?, :full
        alias_method :invalid_session?, :invalid_session

        def compact?
          compaction_token.present?
        end
      end

      Session = Struct.new(:session_id, :busy, keyword_init: true)

      SESSION_VALIDATION_SCRIPT = <<~LUA
        local session_key = KEYS[5]
        local session_id = redis.call('hget', session_key, 'id')
        local length = tonumber(redis.call('hget', session_key, 'length'))
        local valid_session = session_id and length == redis.call('llen', KEYS[1])
          and redis.call('exists', KEYS[3], KEYS[4]) == 2 and redis.call('hget', session_key, 'version')
      LUA

      CONFIRMED_SAVE_SCRIPT = "string.find(redis.call('get', KEYS[6]) or '', 'confirmed:', 1, true) == 1"

      OPEN_SCRIPT = <<~LUA.freeze
        #{SESSION_VALIDATION_SCRIPT}
        if valid_session and redis.call('hget', session_key, 'version') ~= ARGV[3]
          and #{CONFIRMED_SAVE_SCRIPT} then return { '', 1 } end
        if not valid_session or redis.call('hget', session_key, 'version') ~= ARGV[3] then
          redis.call('del', unpack(KEYS))
          session_id = ARGV[1]
          redis.call('hset', session_key, 'id', session_id, 'length', 0, 'version', ARGV[3])
          redis.call('expire', session_key, ARGV[2])
          local expires_at = redis.call('pexpiretime', session_key)
          redis.call('set', KEYS[3], 0, 'PXAT', expires_at)
          redis.call('set', KEYS[4], 0, 'PXAT', expires_at)
        end
        return { session_id, 0 }
      LUA

      TOUCH_SCRIPT = <<~LUA.freeze
        #{SESSION_VALIDATION_SCRIPT}
        if not valid_session or session_id ~= ARGV[1] then return 0 end
        if ARGV[3] ~= '' and redis.call('hget', session_key, 'version') ~= ARGV[3] then
          if #{CONFIRMED_SAVE_SCRIPT} then return 2 end
          return -1
        end
        redis.call('expire', session_key, ARGV[2])
        local expires_at = redis.call('pexpiretime', session_key)
        for _, key in ipairs({ KEYS[1], KEYS[3], KEYS[4] }) do
          redis.call('pexpireat', key, expires_at)
        end
        return 1
      LUA

      READ_SESSION_SCRIPT = <<~LUA.freeze
        #{SESSION_VALIDATION_SCRIPT}
        if not valid_session or session_id ~= ARGV[1] then return false end
        local version = redis.call('hget', session_key, 'version')
        local updates = redis.call('lrange', KEYS[1], 0, -1)
        local seed = 0
        if ARGV[5] == 'admit' then
          if ARGV[2] ~= version and ARGV[3] ~= session_id then return { 'refused' } end
          if ARGV[3] ~= session_id and #updates == 0
            and redis.call('set', KEYS[7], '1', 'EX', ARGV[4], 'NX') then seed = 1 end
        end
        return { updates, version, seed }
      LUA

      SAVE_SCRIPT = <<~LUA.freeze
        local marker = ARGV[1] .. ':' .. ARGV[2] .. ':' .. ARGV[3]
        local confirmed = 'confirmed:' .. marker
        local current = redis.call('get', KEYS[6])
        local owned = current == marker or current == confirmed
        if ARGV[4] == 'release' then return owned and redis.call('del', KEYS[6]) or 0 end
        #{SESSION_VALIDATION_SCRIPT}
        if not valid_session or session_id ~= ARGV[1] then return 0 end
        if ARGV[4] == 'claim' then
          return redis.call('set', KEYS[6], marker, 'NX', 'EX', ARGV[5]) and 1 or 0
        end
        if not owned then return 0 end
        if redis.call('hget', session_key, 'version') ~= ARGV[6] then return 0 end
        if ARGV[4] == 'confirm' then
          redis.call('set', KEYS[6], confirmed, 'EX', ARGV[5])
          return 1
        end
        redis.call('hset', session_key, 'version', ARGV[7])
        redis.call('del', KEYS[6])
        return 1
      LUA

      APPEND_SCRIPT = <<~LUA.freeze
        #{SESSION_VALIDATION_SCRIPT}
        if not valid_session or session_id ~= ARGV[9] then return { 'invalid_session' } end
        local updates_key, claim_key, bytes_key, snapshot_bytes_key = KEYS[1], KEYS[2], KEYS[3], KEYS[4]
        local update, token = ARGV[1], ARGV[2]
        local ttl, threshold, claim_ttl = tonumber(ARGV[3]), tonumber(ARGV[4]), tonumber(ARGV[5])
        local max_length, max_bytes, compact_bytes = tonumber(ARGV[6]), tonumber(ARGV[7]), tonumber(ARGV[8])

        local length = redis.call('llen', updates_key)
        local bytes = tonumber(redis.call('get', bytes_key)) or 0
        local full = length >= max_length or bytes + string.len(update) > max_bytes

        if not full then
          length = redis.call('rpush', updates_key, update)
          bytes = bytes + string.len(update)
          redis.call('expire', updates_key, ttl)
          local expires_at = redis.call('pexpiretime', updates_key)
          redis.call('set', bytes_key, bytes, 'PXAT', expires_at)
          redis.call('pexpireat', snapshot_bytes_key, expires_at)
          redis.call('hset', session_key, 'length', length)
          redis.call('pexpireat', session_key, expires_at)
        end

        local snapshot_bytes = tonumber(redis.call('get', snapshot_bytes_key)) or 0
        local compact_at = math.max(compact_bytes, math.min(snapshot_bytes * 2, (snapshot_bytes + max_bytes) / 2))
        if not full and length < threshold and bytes < compact_at then
          return {}
        end

        if redis.call('set', claim_key, token .. ':' .. length, 'EX', claim_ttl, 'NX') then
          return { full and 'full' or '', token }
        end

        return { full and 'full' or '' }
      LUA

      REPLACE_SCRIPT = <<~LUA.freeze
        #{SESSION_VALIDATION_SCRIPT}
        if not valid_session or session_id ~= ARGV[5] then return -2 end
        local updates_key, claim_key, bytes_key, snapshot_bytes_key = KEYS[1], KEYS[2], KEYS[3], KEYS[4]
        local snapshot, token, ttl, max_bytes = ARGV[1], ARGV[2], tonumber(ARGV[3]), tonumber(ARGV[4])

        local claim = redis.call('get', claim_key)
        if not claim then
          return 0
        end

        local claimed_token, claimed_length = string.match(claim, '^(.+):(%d+)$')
        if claimed_token ~= token then
          return 0
        end

        local suffix = redis.call('lrange', updates_key, tonumber(claimed_length), -1)
        local bytes = string.len(snapshot)
        for _, update in ipairs(suffix) do
          bytes = bytes + string.len(update)
        end
        if bytes > max_bytes then
          return -1
        end

        redis.call('ltrim', updates_key, tonumber(claimed_length), -1)
        redis.call('lpush', updates_key, snapshot)
        redis.call('expire', updates_key, ttl)
        local expires_at = redis.call('pexpiretime', updates_key)
        redis.call('set', bytes_key, bytes, 'PXAT', expires_at)
        redis.call('set', snapshot_bytes_key, string.len(snapshot), 'PXAT', expires_at)
        redis.call('hset', session_key, 'length', redis.call('llen', updates_key))
        redis.call('pexpireat', session_key, expires_at)
        redis.call('del', claim_key)

        return 1
      LUA

      def self.document_key(container, slug)
        "wiki:#{container.class.name}:#{container.id}:#{CGI.escape(slug)}"
      end

      def initialize(document_key)
        @document_key = document_key
      end

      def stream_name(session_id)
        "collaborative_editing:#{document_key}:#{session_id}"
      end

      def updates
        with_redis { |redis| redis.lrange(updates_key, 0, -1) }
      end

      def open(version:)
        raise ArgumentError, 'version must be present' unless version.is_a?(String) && version.present?

        session_id, busy = with_redis do |redis|
          redis.eval(OPEN_SCRIPT, keys: session_keys + [seed_key],
            argv: [SecureRandom.hex(16), TTL.to_i, version])
        end

        @session_id = session_id
        Session.new(session_id: session_id, busy: busy == 1)
      end

      def read_session(session_id:, client_version: nil, remembered_session_id: nil)
        return unless session_id.is_a?(String) && session_id.present?

        with_redis do |redis|
          result = redis.eval(READ_SESSION_SCRIPT, keys: session_keys + [seed_key],
            argv: [session_id, client_version.to_s, remembered_session_id.to_s, SEED_CLAIM_TTL.to_i,
              client_version.nil? ? '' : 'admit'])
          next :refused if result == ['refused']

          result && (client_version.nil? ? result.first(2) : [result[0], result[1], result[2] == 1])
        end
      end

      def touch(session_id:, version: nil)
        return false unless session_id.is_a?(String) && session_id.present?

        with_redis do |redis|
          result = redis.eval(TOUCH_SCRIPT, keys: session_keys, argv: [session_id, TTL.to_i, version.to_s])
          { -1 => :page_changed, 0 => false, 1 => true, 2 => :busy }.fetch(result)
        end
      end

      def claim_save(session_id:, save_id:, user_id:)
        save_operation(:claim, session_id, save_id, user_id)
      end

      def confirm_save(session_id:, save_id:, user_id:, version:)
        save_operation(:confirm, session_id, save_id, user_id, version)
      end

      def advance_version(session_id:, save_id:, user_id:, previous_version:, version:)
        save_operation(:advance, session_id, save_id, user_id, previous_version, version)
      end

      def release_save(session_id:, save_id:, user_id:)
        save_operation(:release, session_id, save_id, user_id)
      end

      def append(update, session_id: @session_id)
        raise ArgumentError, 'update must be a String' unless update.is_a?(String)
        return Result.new(invalid_session: true) unless session_id.is_a?(String) && session_id.present?

        token = SecureRandom.hex(16)

        full, claimed = with_redis do |redis|
          redis.eval(
            APPEND_SCRIPT,
            keys: session_keys,
            argv: [
              update, token, TTL.to_i, COMPACTION_THRESHOLD, COMPACTION_CLAIM_TTL.to_i,
              MAX_LOG_LENGTH, MAX_LOG_BYTES, COMPACTION_BYTES, session_id
            ]
          )
        end

        Result.new(full: full == FULL, compaction_token: claimed.presence, invalid_session: full == 'invalid_session')
      end

      def replace(snapshot, token, session_id: @session_id)
        raise ArgumentError, 'snapshot must be a String' unless snapshot.is_a?(String)
        raise ArgumentError, 'token must be a String' unless token.is_a?(String)
        return :invalid_session unless session_id.is_a?(String) && session_id.present?

        return :invalid_claim if token.empty?

        result = with_redis do |redis|
          redis.eval(
            REPLACE_SCRIPT,
            keys: session_keys,
            argv: [snapshot, token, TTL.to_i, MAX_LOG_BYTES, session_id]
          )
        end

        { -2 => :invalid_session, -1 => :full, 0 => :invalid_claim, 1 => :replaced }.fetch(result)
      end

      private

      attr_reader :document_key

      def save_operation(operation, session_id, save_id, user_id, previous_version = '', version = '')
        return false unless [session_id, save_id].all? { |value| value.is_a?(String) && value.present? }

        with_redis do |redis|
          redis.eval(SAVE_SCRIPT, keys: session_keys,
            argv: [session_id, save_id, user_id.to_s, operation.to_s,
              operation == :claim ? SAVE_TTL.to_i : SAVE_WRITE_TTL.to_i, previous_version, version]) == 1
        end
      end

      def session_keys
        [updates_key, compaction_key, bytes_key, snapshot_bytes_key, session_key, save_key]
      end

      def save_key
        "collaborative_editing:{#{document_key}}:save"
      end

      def session_key
        "collaborative_editing:{#{document_key}}:session"
      end

      def updates_key
        "collaborative_editing:{#{document_key}}:updates"
      end

      def seed_key
        "collaborative_editing:{#{document_key}}:seed"
      end

      def compaction_key
        "collaborative_editing:{#{document_key}}:compaction"
      end

      def bytes_key
        "collaborative_editing:{#{document_key}}:bytes"
      end

      def snapshot_bytes_key
        "collaborative_editing:{#{document_key}}:snapshot_bytes"
      end

      def with_redis(&block)
        Gitlab::Redis::SharedState.with(&block) # rubocop:disable CodeReuse/ActiveRecord -- Redis client, not ActiveRecord
      end
    end
  end
end
