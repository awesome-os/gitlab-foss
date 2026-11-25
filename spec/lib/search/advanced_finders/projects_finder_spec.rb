# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::AdvancedFinders::ProjectsFinder, feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  describe '#use_elasticsearch_finder?' do
    # EE prepends an override that never calls super, so walk past it to run the CE
    # definition. The loop stops at once when EE is absent.
    it 'is false without the EE implementation' do
      method = described_class.instance_method(:use_elasticsearch_finder?)
      method = method.super_method until method.owner == described_class

      expect(method.bind_call(described_class.new(user, search: 'foo'))).to be(false)
    end
  end
end
