# frozen_string_literal: true

require 'fast_spec_helper'
require 'httparty'

RSpec.describe Atlassian::Jira::DevInfoClient, feature_category: :integrations do
  subject(:client) { described_class.new('https://gitlab-test.atlassian.net') }

  describe '#headers' do
    it 'must be implemented by a subclass' do
      expect { client.send(:headers, 'https://example.test') }
        .to raise_error(Gitlab::AbstractMethodError, /#{described_class} must implement #headers/)
    end
  end

  describe '#auth_error_message' do
    it 'does not name a credential the subclass may not use' do
      expect(client.send(:auth_error_message)).to eq('Authentication failed')
    end
  end

  describe '#dev_info_errors' do
    let(:response) { instance_double(HTTParty::Response, code: 202) }

    subject(:result) { client.send(:dev_info_errors, data, response) }

    context 'when Jira reports unknown issue keys and accepted entities' do
      let(:data) do
        {
          'unknownIssueKeys' => %w[ABC-1 ABC-2],
          'acceptedDevinfoEntities' => {
            '1' => { 'commits' => [{ 'id' => 'sha1' }], 'branches' => [{ 'id' => 'b1' }], 'pullRequests' => [] },
            '2' => { 'commits' => [{ 'id' => 'sha2' }], 'branches' => 'unexpected' },
            '3' => 'unexpected'
          }
        }
      end

      it 'logs the keys and per-type counts without treating them as errors' do
        expect(result).to eq(
          'errorMessages' => [],
          'responseCode' => 202,
          'unknownIssueKeys' => %w[ABC-1 ABC-2],
          'unknownIssueKeysCount' => 2,
          'acceptedEntities' => { 'commits' => 2, 'branches' => 1, 'pullRequests' => 0 }
        )
      end
    end

    context 'when Jira reports more unknown issue keys than the log limit' do
      let(:data) { { 'unknownIssueKeys' => Array.new(101) { |i| "ABC-#{i}" } } }

      it 'logs the total and only the first keys' do
        expect(result).to include(
          'unknownIssueKeysCount' => 101,
          'unknownIssueKeys' => data['unknownIssueKeys'].first(100)
        )
      end
    end

    where(:data) do
      [
        [{ 'unknownIssueKeys' => [], 'acceptedDevinfoEntities' => [] }],
        [{ 'unknownIssueKeys' => 'ABC-1', 'acceptedDevinfoEntities' => 'unexpected' }],
        ['unexpected']
      ]
    end

    with_them do
      it 'omits the keys for empty or unexpected shapes' do
        expect(result).to eq('errorMessages' => [], 'responseCode' => 202)
      end
    end
  end
end
