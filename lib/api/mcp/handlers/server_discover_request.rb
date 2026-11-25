# frozen_string_literal: true

module API
  module Mcp
    module Handlers
      # See: https://modelcontextprotocol.io/specification/2026-07-28/server/discover
      class ServerDiscoverRequest < Base
        # 5 minutes. An Integer literal, as `5.minutes.in_milliseconds` is a Float.
        TTL_MS = 300_000

        # The result depends on a per-user feature flag, so a shared cache must not reuse it.
        CACHE_SCOPE = 'private'

        def invoke
          {
            resultType: 'complete',
            supportedVersions: InitializeRequest::STATELESS_PROTOCOL_VERSIONS,
            capabilities: { tools: { listChanged: false } },
            ttlMs: TTL_MS,
            cacheScope: CACHE_SCOPE,
            instructions: InitializeRequest.server_instructions(current_user),
            _meta: { ::API::Helpers::Mcp::JsonRpc::SERVER_INFO_META_KEY => InitializeRequest.server_info }
          }.compact
        end
      end
    end
  end
end
