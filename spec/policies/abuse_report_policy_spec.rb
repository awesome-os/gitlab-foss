# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AbuseReportPolicy, feature_category: :insider_threat do
  let(:abuse_report) { build_stubbed(:abuse_report) }
  let(:permissions) { %i[read_abuse_report read_note create_note update_note] }

  subject(:policy) { described_class.new(user, abuse_report) }

  context 'when the user is not an admin' do
    let(:user) { create(:user) }

    it { expect_disallowed(*permissions) }
  end

  context 'when the user is an admin' do
    let(:user) { create(:admin) }

    context 'with admin mode enabled', :enable_admin_mode do
      it { expect_allowed(*permissions) }
    end

    context 'without admin mode enabled' do
      it { expect_disallowed(*permissions) }
    end
  end
end
