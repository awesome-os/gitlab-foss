# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::FeatureFlags, feature_category: :markdown do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:personal_project) { create(:project) }

  {
    markdown_placeholders_enabled?: :markdown_placeholders,
    glql_load_on_click_enabled?: :glql_load_on_click
  }.each do |method_name, feature_flag|
    describe ".#{method_name}" do
      subject { described_class.public_send(method_name, *containers) }

      before do
        stub_feature_flags(feature_flag => enabled_for ? public_send(enabled_for) : false)
      end

      context 'with a subgroup' do
        let(:containers) { [group] }

        where(:enabled_for, :expected) do
          nil          | false
          :group       | true
          :root_group  | true
          :other_group | false
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with a root group' do
        let(:containers) { [root_group] }

        where(:enabled_for, :expected) do
          nil         | false
          :root_group | true
          :group      | false
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with a project in a subgroup' do
        let(:containers) { [project] }

        where(:enabled_for, :expected) do
          nil          | false
          :project     | true
          :group       | true
          :root_group  | true
          :other_group | false
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with a project namespace' do
        let(:containers) { [project.project_namespace] }

        where(:enabled_for, :expected) do
          nil         | false
          :project    | true
          :root_group | true
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with a project presenter' do
        let(:containers) { [project.present] }

        where(:enabled_for, :expected) do
          nil         | false
          :project    | true
          :group      | true
          :root_group | true
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with a project in a personal namespace' do
        let(:containers) { [personal_project] }
        let(:personal_namespace) { personal_project.namespace }

        where(:enabled_for, :expected) do
          nil                 | false
          :personal_project   | true
          :personal_namespace | false
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with a project and a group' do
        let(:containers) { [personal_project, group] }

        where(:enabled_for, :expected) do
          nil               | false
          :personal_project | true
          :group            | true
          :root_group       | true
          :other_group      | false
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end

      context 'with nil' do
        let(:containers) { [nil] }

        where(:enabled_for, :expected) do
          nil    | false
          :group | false
        end

        with_them do
          it { is_expected.to be(expected) }
        end
      end
    end
  end
end
