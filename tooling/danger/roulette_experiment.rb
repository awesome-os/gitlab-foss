# frozen_string_literal: true

require 'digest'
require 'json'
require 'net/http'

module Tooling
  module Danger
    module RouletteExperiment
      SALT = 'reviewer-column-2026-08'
      PERCENT_ENV_VAR = 'ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT'
      DEFAULT_HIDDEN_PERCENT = 50
      RISK_TIER_TIMEOUT_SECONDS = 5
      RISK_TIER_QUERY = <<~GRAPHQL
        query($id: MergeRequestID!) {
          mergeRequest(id: $id) { riskAssessment { riskTier } }
        }
      GRAPHQL

      def self.hide_reviewer_column?(mr_iid)
        Digest::SHA256.hexdigest("#{SALT}-#{mr_iid}").to_i(16) % 100 < hidden_percent
      end

      # Read on every call rather than memoized, so a CI variable change takes
      # effect on the next pipeline without a code change.
      def self.hidden_percent
        Integer(ENV.fetch(PERCENT_ENV_VAR, DEFAULT_HIDDEN_PERCENT)).clamp(0, 100)
      end

      # Keyword arguments for `roulette.spin`. Low-risk MRs teach a trainee maintainer little, so they
      # go to a maintainer. Without a score, maintainers and trainee maintainers get the same weight.
      # Higher tiers use the gem's default boost for trainee maintainers.
      def self.maintainer_pool_options(risk_tier)
        case risk_tier
        when nil then { maintainer_pool: :maintainers_and_traintainers, traintainer_boost: 0 }
        when 'LOW' then { maintainer_pool: :maintainers }
        else { maintainer_pool: :maintainers_and_traintainers }
        end
      end

      # Returns nil when the MR has no risk score or the request fails, so the roulette still runs.
      def self.risk_tier(api_endpoint:, token:, merge_request_id:)
        uri = URI(api_endpoint.sub(%r{/v4/?\z}, '/graphql'))
        body = { query: RISK_TIER_QUERY, variables: { id: "gid://gitlab/MergeRequest/#{merge_request_id}" } }.to_json
        headers = { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }

        response = Net::HTTP.start(
          uri.host, uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: RISK_TIER_TIMEOUT_SECONDS,
          read_timeout: RISK_TIER_TIMEOUT_SECONDS
        ) { |http| http.post(uri.path, body, headers) }

        unless response.is_a?(Net::HTTPSuccess)
          puts "roulette_experiment: risk tier request returned #{response.code} #{response.message}. Ignoring."
          return
        end

        json = JSON.parse(response.body)
        errors = Array(json['errors']).map { |error| error['message'] }
        puts "roulette_experiment: risk tier query returned errors: #{errors.join('; ')}. Ignoring." if errors.any?

        tier = json.dig('data', 'mergeRequest', 'riskAssessment', 'riskTier')
        puts 'roulette_experiment: no risk tier in the response.' if tier.nil?
        tier
      rescue StandardError => e
        puts "roulette_experiment: #{e.class}: #{e.message}. Ignoring."
        nil
      end
    end
  end
end
