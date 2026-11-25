# frozen_string_literal: true

RSpec.shared_examples 'allows protected branch crud' do
  it { expect_allowed(:read_protected_branch) }
  it { expect_allowed(:create_protected_branch) }
  it { expect_allowed(:update_protected_branch) }
  it { expect_allowed(:delete_protected_branch) }
end

RSpec.shared_examples 'disallows protected branch crud' do
  it { expect_disallowed(:read_protected_branch) }
  it { expect_disallowed(:create_protected_branch) }
  it { expect_disallowed(:update_protected_branch) }
  it { expect_disallowed(:delete_protected_branch) }
end

RSpec.shared_examples 'disallows protected branch changes' do
  it { expect_allowed(:read_protected_branch) }
  it { expect_disallowed(:create_protected_branch) }
  it { expect_disallowed(:update_protected_branch) }
  it { expect_disallowed(:delete_protected_branch) }
end
