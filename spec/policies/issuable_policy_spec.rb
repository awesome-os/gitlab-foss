# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuablePolicy, :models do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:planner, freeze: false) { create(:user) }
  let_it_be(:reporter, freeze: false) { create(:user) }
  let_it_be(:developer, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :public) }

  let(:issue) { create(:issue, project: project) }
  let(:timeline_event_permissions) do
    %i[create_timeline_event update_timeline_event delete_timeline_event]
  end

  subject(:policies) { described_class.new(user, issue) }

  before_all do
    project.add_developer(developer)
    project.add_guest(guest)
    project.add_planner(planner)
    project.add_reporter(reporter)
  end

  def permissions(user, issuable)
    described_class.new(user, issuable)
  end

  describe '#rules' do
    context 'when user is author of issuable' do
      let(:merge_request) { create(:merge_request, source_project: project, author: user) }

      subject(:policies) { described_class.new(user, merge_request) }

      it 'does not allow reading internal notes' do
        expect_disallowed(:read_internal_note)
      end

      context 'when user is able to read project' do
        it 'enables user to read and update issuables' do
          expect_allowed(:read_issue, :update_issue, :reopen_issue, :read_merge_request, :update_merge_request, :reopen_merge_request)
        end
      end

      context 'Timeline events' do
        context 'with guest' do
          subject { permissions(guest, issue) }

          it 'allows non-members to read time line events' do
            expect_allowed(:read_timeline_event)
          end
        end

        context 'with planner' do
          subject { permissions(planner, issue) }

          it 'disallows planners from managing timeline events' do
            expect_disallowed(*timeline_event_permissions)
          end
        end

        context 'with reporter' do
          subject { permissions(reporter, issue) }

          it 'disallows reporters from managing timeline events' do
            expect_disallowed(*timeline_event_permissions)
          end
        end

        context 'with developer' do
          subject { permissions(developer, issue) }

          it 'allows developers to manage timeline events' do
            expect_allowed(*timeline_event_permissions)
          end
        end
      end

      context 'when project is private' do
        let_it_be(:project, freeze: false) { create(:project, :private) }

        before_all do
          project.add_developer(developer)
          project.add_guest(guest)
          project.add_planner(planner)
          project.add_reporter(reporter)
        end

        context 'when user belongs to the projects team' do
          it 'enables user to read and update issuables' do
            project.add_maintainer(user)

            expect_allowed(:read_issue, :update_issue, :reopen_issue, :read_merge_request, :update_merge_request, :reopen_merge_request)
          end
        end

        it 'disallows user from reading and updating issuables from that project' do
          expect_disallowed(:read_issue, :update_issue, :reopen_issue, :read_merge_request, :update_merge_request, :reopen_merge_request)
        end

        context 'Timeline events' do
          context 'with user' do
            subject { permissions(user, issue) }

            it 'disallows non-members from reading timeline events' do
              expect_disallowed(:read_timeline_event)
            end
          end

          context 'with guest' do
            subject { permissions(guest, issue) }

            it 'allows guests to read time line events' do
              expect_allowed(:read_timeline_event)
            end
          end

          context 'with planner' do
            subject { permissions(planner, issue) }

            it 'disallows planners from managing timeline events' do
              expect_disallowed(*timeline_event_permissions)
            end
          end

          context 'with reporter' do
            subject { permissions(reporter, issue) }

            it 'disallows reporters from managing timeline events' do
              expect_disallowed(*timeline_event_permissions)
            end
          end

          context 'with developer' do
            subject { permissions(developer, issue) }

            it 'allows developers to manage timeline events' do
              expect_allowed(*timeline_event_permissions)
            end
          end
        end
      end
    end

    context 'when user is assignee of issuable' do
      let(:issue) { create(:issue, project: project, assignees: [user]) }

      subject(:policies) { described_class.new(user, issue) }

      it 'does not allow reading internal notes' do
        expect_disallowed(:read_internal_note)
      end
    end

    context 'when discussion is locked for the issuable' do
      let(:issue) { create(:issue, project: project, discussion_locked: true) }

      context 'when the user is not a project member' do
        it 'can not create a note nor award emojis' do
          expect_disallowed(:create_note, :award_emoji)
        end
      end

      context 'when the user is a project member' do
        before_all do
          project.add_developer(user)
        end

        it 'can create a note and award emojis' do
          expect_allowed(:create_note, :award_emoji)
        end
      end
    end

    context 'when user is anonymous' do
      context 'without a user' do
        subject { permissions(nil, issue) }

        it 'does not allow timelogs creation' do
          expect_disallowed(:create_timelog)
        end
      end
    end

    context 'when user is not a member of the project' do
      it 'does not allow timelogs creation' do
        expect_disallowed(:create_timelog)
      end
    end

    context 'when user is not a member of the project but the author of the issuable' do
      let(:issue) { create(:issue, project: project, author: user) }

      it 'does not allow timelogs creation' do
        expect_disallowed(:create_timelog)
      end

      context 'with guest' do
        subject { permissions(guest, issue) }

        it 'does not allow reading internal notes' do
          expect_disallowed(:read_internal_note)
        end
      end
    end

    context 'when user is a guest member of the project' do
      context 'with guest' do
        subject { permissions(guest, issue) }

        it 'does not allow timelogs creation' do
          expect_disallowed(:create_timelog)
        end

        it 'does not allow reading internal notes' do
          expect_disallowed(:read_internal_note)
        end
      end
    end

    context 'when user is a guest member of the project and the author of the issuable' do
      let(:issue) { create(:issue, project: project, author: guest) }

      context 'with guest' do
        subject { permissions(guest, issue) }

        it 'does not allow timelogs creation' do
          expect_disallowed(:create_timelog)
        end
      end
    end

    context 'when user is at planner of the project' do
      context 'with planner' do
        subject { permissions(planner, issue) }

        it 'allows timelogs creation' do
          expect_allowed(:create_timelog)
        end

        it 'allows reading internal notes' do
          expect_allowed(:read_internal_note)
        end
      end
    end

    context 'when user is at least reporter of the project' do
      context 'with reporter' do
        subject { permissions(reporter, issue) }

        it 'allows timelogs creation' do
          expect_allowed(:create_timelog)
        end

        it 'allows reading internal notes' do
          expect_allowed(:read_internal_note)
        end
      end
    end

    context 'when subject is a Merge Request' do
      let_it_be(:issuable, freeze: false) { create(:merge_request) }

      subject(:policy) { permissions(user, issuable) }

      before do
        allow(policy).to receive(:can?).with(:read_merge_request).and_return(can_read_merge_request)
      end

      context 'when can_read_merge_request is false' do
        let(:can_read_merge_request) { false }

        it 'does not allow :read_issuable' do
          expect_disallowed(:read_issuable, :read_issuable_participables)
        end
      end

      context 'when can_read_merge_request is true' do
        let(:can_read_merge_request) { true }

        it 'allows :read_issuable' do
          expect_allowed(:read_issuable, :read_issuable_participables)
        end
      end
    end

    context 'when subject is an Issue' do
      let_it_be(:issuable, freeze: false) { create(:issue) }

      subject(:policy) { permissions(user, issuable) }

      before do
        allow(policy).to receive(:can?).with(:read_issue).and_return(can_read_issue)
      end

      context 'when can_read_issue is false' do
        let(:can_read_issue) { false }

        it 'does not allow :read_issuable' do
          expect_disallowed(:read_issuable, :read_issuable_participables)
        end
      end

      context 'when can_read_issue is true' do
        let(:can_read_issue) { true }

        it 'allows :read_issuable' do
          expect_allowed(:read_issuable, :read_issuable_participables)
        end
      end
    end
  end

  describe 'delegation' do
    it 'delegates a project issue to the project policy' do
      record = build_stubbed(:issue)

      expect(described_class.new(nil, record)).to delegate_to(ProjectPolicy)
    end

    it 'delegates a group-level issue to the group policy' do
      record = build_stubbed(:issue, :group_level)

      expect(described_class.new(nil, record)).to delegate_to(GroupPolicy)
    end
  end
end
