# frozen_string_literal: true

RSpec.shared_examples 'Self-managed Core resource access tokens' do
  let(:permissions) { %i[create_resource_access_tokens read_resource_access_tokens destroy_resource_access_tokens] }

  before do
    allow(::Gitlab).to receive(:com?).and_return(false)
  end

  context 'with owner access' do
    let(:current_user) { owner }

    it { expect_allowed(*permissions) }

    context 'create resource access tokens' do
      context 'when resource access token creation is not allowed' do
        let(:group) { create(:group) }
        let(:project) { create(:project, group: group) }

        before do
          group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
        end

        it { expect_disallowed(:create_resource_access_tokens) }
      end

      context 'when parent group has project access token creation disabled' do
        let(:parent) { create(:group) }
        let(:group) { create(:group, parent: parent) }
        let(:project) { create(:project, group: group) }

        before do
          parent.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
        end

        it { expect_disallowed(:create_resource_access_tokens) }
      end

      context 'with a personal namespace project' do
        let(:namespace) { create(:namespace) }
        let(:project) { create(:project, namespace: namespace) }

        before do
          project.add_maintainer(current_user)
        end

        it { expect_allowed(:create_resource_access_tokens) }
      end
    end
  end

  context 'with developer access' do
    let(:current_user) { developer }

    it { expect_disallowed(*permissions) }
  end
end
