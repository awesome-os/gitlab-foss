# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Audit::NullAuthorPolicy, feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  let(:author) { Gitlab::Audit::NullAuthor.new(id: 123, name: 'Audit Author') }
  let(:current_user) { signed_in ? build(:user) : nil }

  subject { described_class.new(current_user, author) }

  where(:signed_in, :public_restricted, :allowed) do
    true  | false | true
    true  | true  | true
    false | false | true
    false | true  | false
  end

  with_them do
    before do
      restricted = public_restricted ? [Gitlab::VisibilityLevel::PUBLIC] : []
      stub_application_setting(restricted_visibility_levels: restricted)
    end

    it { allowed ? expect_allowed(:read_user) : expect_disallowed(:read_user) }
  end
end
