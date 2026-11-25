# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceLabelEventPolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:private_project) { create(:project, :private) }
  let_it_be(:label) { create(:label, project: project) }
  let_it_be(:private_label) { create(:label, project: private_project) }

  let(:permissions) { %i[read_label read_resource_label_event read_note] }
  let(:event) { build(:resource_label_event, issue: issue, label: label) }

  subject { described_class.new(user, event) }

  context 'with non-member user' do
    it { expect_disallowed(*permissions) }

    context 'with a deleted label' do
      let(:event) { build(:resource_label_event, issue: issue, label: nil) }

      it { expect_allowed(:read_label) }
      it { expect_disallowed(:read_resource_label_event, :read_note) }
    end
  end

  context 'with member user' do
    before_all do
      project.add_guest(user)
    end

    it { expect_allowed(*permissions) }

    context 'with a deleted label' do
      let(:event) { build(:resource_label_event, issue: issue, label: nil) }

      it { expect_allowed(*permissions) }
    end

    context 'with a not accessible label' do
      let(:event) { build(:resource_label_event, issue: issue, label: private_label) }

      it { expect_disallowed(*permissions) }
    end
  end

  context 'when the user can read the label but not the issue' do
    let(:event) { build(:resource_label_event, issue: issue, label: private_label) }

    before_all do
      private_project.add_guest(user)
    end

    it { expect_allowed(:read_label) }
    it { expect_disallowed(:read_resource_label_event, :read_note) }
  end
end
