# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FeatureLibrary::UpgradeCta, feature_category: :onboarding, unless: Gitlab.ee? do
  subject(:cta) { described_class.new(user: user, resource: nil, plan: :premium).build }

  context 'with an admin', :enable_admin_mode do
    let(:user) { build_stubbed(:admin) }

    it 'offers the CE to EE conversion docs in a new tab' do
      expect(cta).to eq(
        type: 'migrate',
        text: s_('FeatureLibrary|Migrate to Enterprise Edition'),
        url: '/help/update/convert_to_ee/_index.md#convert-to-enterprise-edition',
        new_tab: true
      )
    end
  end

  context 'with an admin outside admin mode' do
    let(:user) { build_stubbed(:admin) }

    it { is_expected.to be_nil }
  end

  context 'with a user who is not an admin' do
    let(:user) { build_stubbed(:user) }

    it { is_expected.to be_nil }
  end

  context 'without a user' do
    let(:user) { nil }

    it { is_expected.to be_nil }
  end
end
