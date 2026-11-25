# frozen_string_literal: true

require "spec_helper"

RSpec.describe Types::Namespaces::AvailableFeaturesType, feature_category: :shared do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  it_behaves_like 'expose all available feature fields for the namespace'

  describe 'has_design_management_feature' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:has_design_management_feature) do
      resolve_field(:has_design_management_feature, namespace, current_user: user)
    end

    context 'when the namespace is a project namespace' do
      let(:namespace) { project.project_namespace }

      where(:enabled, :expectation) do
        true  | true
        false | false
      end

      with_them do
        before do
          allow(DesignManagement).to receive(:enabled_for?).with(project).and_return(enabled)
        end

        it { is_expected.to be(expectation) }
      end
    end

    context 'when the namespace is a group' do
      let(:namespace) { group }

      it { is_expected.to be(false) }
    end
  end
end
