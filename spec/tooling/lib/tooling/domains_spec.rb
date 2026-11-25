# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../tooling/lib/tooling/domains'

RSpec.describe Tooling::Domains, feature_category: :tooling do
  describe 'PATH_PREFIX' do
    let(:pattern) { %r{\A#{described_class::PATH_PREFIX}app/}o }

    it 'matches a path in a domain and a top-level path' do
      expect(pattern.match?('domains/foo/app/models/x.rb')).to be(true)
      expect(pattern.match?('app/models/x.rb')).to be(true)
    end

    it 'does not treat a domain without a name as a domain path' do
      expect(pattern.match?('domains/app/x.rb')).to be(false)
    end
  end

  describe 'ROOT' do
    let(:pattern) { %r{\A#{described_class::ROOT}}o }

    it 'matches only a named domain root' do
      expect(pattern.match?('domains/foo/app/x.rb')).to be(true)
      expect(pattern.match?('app/models/x.rb')).to be(false)
    end
  end
end
