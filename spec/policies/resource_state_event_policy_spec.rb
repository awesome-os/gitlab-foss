# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceStateEventPolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:event) { build(:resource_state_event, issue: issue, state: 2) }

  subject { described_class.new(user, event) }

  describe '#read_resource_state_event' do
    context 'with non-member user' do
      it 'does not allow to read event' do
        expect_disallowed(:read_resource_state_event, :read_note)
      end
    end

    context 'with member user' do
      before_all do
        project.add_guest(user)
      end

      it 'allows to read event for a state change' do
        expect_allowed(:read_resource_state_event, :read_note)
      end
    end
  end
end
