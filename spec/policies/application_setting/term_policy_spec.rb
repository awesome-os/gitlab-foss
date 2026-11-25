# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApplicationSetting::TermPolicy, feature_category: :user_management do
  include TermsHelper

  let_it_be(:term) { create(:term) }
  let_it_be_with_reload(:user) { create(:user) }

  let(:current_user) { user }

  subject(:policy) { described_class.new(current_user, term) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  it { expect_allowed(:accept_terms, :decline_terms) }

  context 'when the user is anonymous' do
    let(:current_user) { nil }

    it { expect_disallowed(:accept_terms, :decline_terms) }
  end

  context 'when the terms are not current' do
    before do
      create(:term)
    end

    it { expect_disallowed(:accept_terms, :decline_terms) }
  end

  context 'when the user already accepted the terms' do
    before do
      accept_terms(user)
    end

    it { expect_disallowed(:accept_terms) }
    it { expect_allowed(:decline_terms) }
  end
end
