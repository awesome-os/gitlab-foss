# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::NpmPackage, feature_category: :package_registry do
  let(:metadata) do
    {
      name: '@scope/package',
      versions: { '1.0.0' => { name: '@scope/package', version: '1.0.0' } },
      time: { 'created' => '2026-01-12T08:41:01.956Z', 'modified' => '2026-01-12T08:41:01.956Z',
              '1.0.0' => '2026-01-12T08:41:01.956Z' },
      dist_tags: { 'latest' => '1.0.0' }
    }
  end

  subject(:representation) { described_class.new(metadata).as_json }

  it 'exposes time' do
    expect(representation[:time]).to eq(metadata[:time])
  end

  context 'without time' do
    let(:metadata) { super().except(:time) }

    it 'does not expose time' do
      expect(representation).not_to have_key(:time)
    end
  end
end
