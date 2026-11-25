# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Metrics::Transaction do
  describe '#run' do
    specify { expect { described_class.new.run }.to raise_error(NotImplementedError) }
  end

  describe '#filter_labels' do
    let(:transaction_labels) { { controller: 'TestController', action: 'show' } }
    let(:transaction) do
      labels = transaction_labels

      Class.new(described_class) { define_method(:labels) { labels } }.new
    end

    subject(:filtered) { transaction.filter_labels(labels) }

    context 'with empty labels' do
      let(:labels) { {} }

      it { is_expected.to be(transaction_labels) }
    end

    context 'with labels without sensitive keys' do
      let(:labels) { { db_config_name: 'main', action: 'other' }.freeze }

      it 'merges the transaction labels over them' do
        expect(filtered).to eq(db_config_name: 'main', action: 'show', controller: 'TestController')
        expect(labels).to eq(db_config_name: 'main', action: 'other')
      end

      context 'when the transaction has no labels' do
        let(:transaction_labels) { {} }

        it { is_expected.to be(labels) }
      end
    end

    context 'with labels with sensitive keys' do
      let(:labels) { { path: 'private', branch: 'sensitive', store: 'cache' }.freeze }

      it 'removes them and merges the transaction labels' do
        expect(filtered).to eq(store: 'cache', controller: 'TestController', action: 'show')
        expect(labels).to eq(path: 'private', branch: 'sensitive', store: 'cache')
      end

      context 'when the transaction has no labels' do
        let(:transaction_labels) { {} }

        it { is_expected.to eq(store: 'cache') }
      end

      context 'with only one sensitive key' do
        let(:labels) { { branch: 'sensitive', store: 'cache' } }

        it { is_expected.to eq(store: 'cache', controller: 'TestController', action: 'show') }
      end
    end
  end
end
