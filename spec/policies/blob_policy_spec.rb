# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BlobPolicy, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:blob) { project.repository.blob_at(SeedRepo::FirstCommit::ID, 'README.md') }

  subject(:policy) { described_class.new(user, blob) }

  it 'delegates to the project policy' do
    expect(described_class.new(nil, blob)).to delegate_to(ProjectPolicy)
  end

  it { expect_allowed(:read_blob) }

  context 'when the user cannot read code' do
    before do
      stub_permissions(read_code: false)
    end

    it { expect_disallowed(:read_blob) }
  end
end
