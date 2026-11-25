# frozen_string_literal: true

RSpec.shared_examples_for 'a service that does not update a merge request' do
  it 'does not change the latest updated_at across merge requests' do
    expect { service.execute }.not_to change { MergeRequest.maximum(:updated_at) }
  end
end

RSpec.shared_examples_for 'a service that does nothing' do
  include_examples 'a service that does not create a merge request'
  include_examples 'a service that does not update a merge request'
end

RSpec.shared_examples 'with a deleted branch' do
  let(:changes) { deleted_branch_changes }

  it_behaves_like 'a service that does nothing'
end

RSpec.shared_examples 'with the project default branch' do
  let(:changes) { default_branch_changes }

  it_behaves_like 'a service that does nothing'
end
