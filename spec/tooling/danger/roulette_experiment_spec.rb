# frozen_string_literal: true

require 'fast_spec_helper'
require 'webmock/rspec'
require_relative '../../../tooling/danger/roulette_experiment'

RSpec.describe Tooling::Danger::RouletteExperiment, feature_category: :tooling do
  describe '.hide_reviewer_column?' do
    # Ignore the project-level CI variable so the default percent applies.
    before do
      stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', nil)
    end

    it 'is deterministic for the same MR iid' do
      result = described_class.hide_reviewer_column?(1234)

      3.times { expect(described_class.hide_reviewer_column?(1234)).to eq(result) }
    end

    it 'splits MRs into both arms across a range of iids' do
      results = (1..2000).map { |iid| described_class.hide_reviewer_column?(iid) }

      expect(results).to include(true).and include(false)
    end

    context 'with a default hidden percent of 50%' do
      it 'hides for roughly half of a large sample of iids' do
        hidden_count = (1..5000).count { |iid| described_class.hide_reviewer_column?(iid) }

        expect(hidden_count / 5000.0).to be_within(0.05).of(0.5)
      end
    end

    context 'when ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT is set' do
      it 'hides for nobody when set to 0' do
        stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '0')

        expect((1..500).map { |iid| described_class.hide_reviewer_column?(iid) }).to all(be false)
      end

      it 'hides for everybody when set to 100' do
        stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '100')

        expect((1..500).map { |iid| described_class.hide_reviewer_column?(iid) }).to all(be true)
      end

      it 'lands in the expected band for an intermediate percentage' do
        stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '25')

        hidden_count = (1..5000).count { |iid| described_class.hide_reviewer_column?(iid) }

        expect(hidden_count / 5000.0).to be_within(0.05).of(0.25)
      end

      it 'raises for a non-numeric value' do
        stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', 'not-a-number')

        expect { described_class.hide_reviewer_column?(1) }.to raise_error(ArgumentError)
      end

      it 'clamps a value above 100 down to 100' do
        stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '150')

        expect((1..500).map { |iid| described_class.hide_reviewer_column?(iid) }).to all(be true)
      end

      it 'clamps a negative value up to 0' do
        stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '-10')

        expect((1..500).map { |iid| described_class.hide_reviewer_column?(iid) }).to all(be false)
      end
    end
  end

  describe '.hidden_percent' do
    it 'clamps values above 100 to 100' do
      stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '150')

      expect(described_class.hidden_percent).to eq(100)
    end

    it 'clamps negative values to 0' do
      stub_env('ROULETTE_HIDE_REVIEWER_COLUMN_PERCENT', '-10')

      expect(described_class.hidden_percent).to eq(0)
    end
  end

  describe '.maintainer_pool_options' do
    using RSpec::Parameterized::TableSyntax

    where(:risk_tier, :options) do
      nil        | { maintainer_pool: :maintainers_and_traintainers, traintainer_boost: 0 }
      'LOW'      | { maintainer_pool: :maintainers }
      'MEDIUM'   | { maintainer_pool: :maintainers_and_traintainers }
      'HIGH'     | { maintainer_pool: :maintainers_and_traintainers }
      'CRITICAL' | { maintainer_pool: :maintainers_and_traintainers }
    end

    with_them do
      it { expect(described_class.maintainer_pool_options(risk_tier)).to eq(options) }
    end
  end

  describe '.risk_tier' do
    let(:graphql_url) { 'https://gitlab.com/api/graphql' }
    let(:risk_assessment) { { riskTier: 'MEDIUM' } }

    subject(:risk_tier) do
      described_class.risk_tier(api_endpoint: 'https://gitlab.com/api/v4', token: 'token', merge_request_id: 42)
    end

    before do
      stub_request(:post, graphql_url)
        .to_return(status: 200, body: { data: { mergeRequest: { riskAssessment: risk_assessment } } }.to_json)
    end

    it 'returns the risk tier of the merge request' do
      expect(risk_tier).to eq('MEDIUM')
      expect(WebMock).to have_requested(:post, graphql_url).with(
        headers: { 'Authorization' => 'Bearer token' },
        body: hash_including('variables' => { 'id' => 'gid://gitlab/MergeRequest/42' })
      )
    end

    context 'when the merge request has no risk assessment' do
      let(:risk_assessment) { nil }

      it 'returns nil and prints a line' do
        expect { expect(risk_tier).to be_nil }.to output(/no risk tier in the response/).to_stdout
      end
    end

    context 'when the query returns errors' do
      before do
        stub_request(:post, graphql_url).to_return(
          status: 200,
          body: { data: { mergeRequest: nil }, errors: [{ message: 'Insufficient scope' }] }.to_json
        )
      end

      it 'returns nil and prints the errors' do
        expect { expect(risk_tier).to be_nil }.to output(/returned errors: Insufficient scope/).to_stdout
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:post, graphql_url).to_return(status: [500, 'Internal Server Error'])
      end

      it 'returns nil and prints the response code' do
        expect { expect(risk_tier).to be_nil }.to output(/returned 500 Internal Server Error/).to_stdout
      end
    end

    context 'when the request times out' do
      before do
        stub_request(:post, graphql_url).to_timeout
      end

      it 'returns nil and prints the error class' do
        expect { expect(risk_tier).to be_nil }.to output(/Net::OpenTimeout/).to_stdout
      end
    end
  end
end
