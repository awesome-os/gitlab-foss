# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceMilestoneEventPolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:private_project) { create(:project, :private) }

  let(:permissions) { %i[read_milestone read_resource_milestone_event read_note] }
  let(:event) { build_event(project) }

  subject { described_class.new(user, event) }

  context 'with non-member user' do
    it { expect_disallowed(*permissions) }
  end

  context 'with member user' do
    before_all do
      project.add_guest(user)
    end

    it { expect_allowed(*permissions) }

    context 'with a deleted milestone' do
      let(:event) { build(:resource_milestone_event, issue: issue, milestone: nil) }

      it { expect_allowed(*permissions) }
    end

    context 'with a not accessible milestone' do
      let(:event) { build_event(private_project) }

      it { expect_disallowed(*permissions) }
    end
  end

  context 'when the user can read the milestone but not the issue' do
    let(:event) { build_event(private_project) }

    before_all do
      private_project.add_guest(user)
    end

    it { expect_allowed(:read_milestone) }
    it { expect_disallowed(:read_resource_milestone_event, :read_note) }
  end

  def build_event(project)
    milestone = create(:milestone, project: project)

    build(:resource_milestone_event, issue: issue, milestone: milestone)
  end
end
