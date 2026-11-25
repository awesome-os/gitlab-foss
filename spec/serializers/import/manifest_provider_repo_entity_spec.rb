# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::ManifestProviderRepoEntity do
  let(:current_user) { build_stubbed(:user) }
  let(:request) { double(:request, current_user: current_user) }
  let(:repo_data) do
    {
      id: 1,
      url: 'http://demo.repo/url',
      path: '/demo/path'
    }
  end

  subject(:json) { described_class.represent(repo_data, { group_full_path: 'group', request: request }).as_json }

  it_behaves_like 'exposes required fields for import entity' do
    let(:expected_values) do
      {
        id: repo_data[:id],
        full_name: repo_data[:url],
        sanitized_name: nil,
        provider_link: repo_data[:url]
      }
    end
  end

  describe 'target' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(current_user, :create_group).and_return(can_create_group)
      allow(current_user).to receive(:namespace_path).and_return('user-namespace')
    end

    context 'when the user can create groups' do
      let(:can_create_group) { true }

      it 'imports into the group' do
        expect(json[:target]).to eq('group//demo/path')
      end
    end

    context 'when the user cannot create groups' do
      let(:can_create_group) { false }

      it "imports into the user's namespace" do
        expect(json[:target]).to eq('user-namespace//demo/path')
      end
    end
  end
end
