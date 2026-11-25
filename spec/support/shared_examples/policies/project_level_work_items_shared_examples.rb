# frozen_string_literal: true

RSpec.shared_examples 'checks abilities for project level work items' do
  context 'when checking guest abilities' do
    context 'with guest on not_persisted_project_work_item' do
      subject { permissions(guest, not_persisted_project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_parent_link, :set_work_item_metadata,
          :admin_work_item_link, :create_note
        )
      end
    end

    context 'with guest on project_work_item' do
      subject { permissions(guest, project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_parent_link, :admin_work_item_link, :create_note
        )
      end

      it 'denies the permissions' do
        expect_disallowed(
          :admin_work_item, :update_work_item, :delete_work_item, :set_work_item_metadata, :move_work_item,
          :clone_work_item
        )
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with guest on project_confidential_work_item' do
      subject { permissions(guest, project_confidential_work_item) }

      it 'denies the permissions' do
        expect_disallowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
          :set_work_item_metadata, :create_note, :move_work_item, :clone_work_item
        )
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with guest_author on authored_project_work_item' do
      subject { permissions(guest_author, authored_project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :update_work_item, :delete_work_item, :admin_parent_link,
          :admin_work_item_link, :create_note
        )
      end

      it 'denies the permissions' do
        expect_disallowed(:admin_work_item, :set_work_item_metadata, :move_work_item, :clone_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with guest_author on authored_project_confidential_work_item' do
      subject { permissions(guest_author, authored_project_confidential_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :update_work_item, :delete_work_item, :admin_parent_link,
          :admin_work_item_link, :create_note
        )
      end

      it 'denies the permissions' do
        expect_disallowed(:admin_work_item, :set_work_item_metadata, :move_work_item, :clone_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with guest on incident_work_item' do
      subject { permissions(guest, incident_work_item) }

      it 'denies the permissions' do
        expect_disallowed(:admin_work_item, :update_work_item, :set_work_item_metadata, :delete_work_item)
      end
    end
  end

  context 'when checking planner abilities' do
    context 'with planner on project_work_item' do
      subject { permissions(planner, project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
          :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item,
          :clone_work_item
        )
      end
    end

    context 'with planner on project_confidential_work_item' do
      subject { permissions(planner, project_confidential_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
          :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item,
          :clone_work_item
        )
      end
    end

    context 'with planner on incident_work_item' do
      subject { permissions(planner, incident_work_item) }

      it 'denies the permissions' do
        expect_disallowed(:admin_work_item, :update_work_item, :set_work_item_metadata, :delete_work_item)
      end
    end
  end

  context 'when checking group planner abilities' do
    context 'with group_planner on project_work_item' do
      subject { permissions(group_planner, project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
          :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item,
          :clone_work_item
        )
      end
    end

    context 'with group_planner on project_confidential_work_item' do
      subject { permissions(group_planner, project_confidential_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
          :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item,
          :clone_work_item
        )
      end
    end
  end

  context 'when checking reporter abilities' do
    context 'with reporter on project_work_item' do
      subject { permissions(reporter, project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
          :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item, :clone_work_item
        )
      end

      it 'denies the permissions' do
        expect_disallowed(:delete_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with reporter on project_confidential_work_item' do
      subject { permissions(reporter, project_confidential_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
          :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item, :clone_work_item
        )
      end

      it 'denies the permissions' do
        expect_disallowed(:delete_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with reporter on incident_work_item' do
      subject { permissions(reporter, incident_work_item) }

      it 'allows the permissions' do
        expect_allowed(:admin_work_item, :update_work_item, :set_work_item_metadata)
      end

      it 'denies the permissions' do
        expect_disallowed(:delete_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end
  end

  context 'when checking group reporter abilities' do
    context 'with group_reporter on project_work_item' do
      subject { permissions(group_reporter, project_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
          :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item, :clone_work_item
        )
      end

      it 'denies the permissions' do
        expect_disallowed(:delete_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end

    context 'with group_reporter on project_confidential_work_item' do
      subject { permissions(group_reporter, project_confidential_work_item) }

      it 'allows the permissions' do
        expect_allowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
          :set_work_item_metadata, :admin_work_item_link, :create_note, :move_work_item, :clone_work_item
        )
      end

      it 'denies the permissions' do
        expect_disallowed(:delete_work_item)
      end

      it 'denies summarize_comments', if: Gitlab.ee? do
        expect_disallowed(:summarize_comments)
      end
    end
  end
end

RSpec.shared_examples 'prevents access to project-level {issues|work_items} with type Epic' do |record_type|
  context 'with Epic work item type' do
    let_it_be(:with_epic_type, freeze: false) do
      create(
        record_type,
        :epic,
        project: project,
        assignees: [assignee],
        author: author
      )
    end

    let(:work_item_permissions) do
      %i[delete_work_item set_work_item_metadata admin_work_item_link admin_parent_link move_work_item clone_work_item]
    end

    let(:issue_permissions) do
      %i[
        read_cross_project admin_all_resources read_all_resources change_repository_storage resolve_note read_issue
        update_issue reopen_issue update_merge_request reopen_merge_request create_note admin_note award_emoji
        read_timeline_event create_timeline_event update_timeline_event
        delete_timeline_event create_timelog read_issuable
        read_issuable_participables read_note read_internal_note set_note_created_at mark_note_as_internal
        reposition_note create_issue admin_issue destroy_issue read_issue_iid read_design create_design update_design
        destroy_design move_design create_todo update_subscription set_issue_metadata admin_issue_link
        set_confidentiality admin_issue_relation read_crm_contacts set_issue_crm_contacts move_issue clone_issue
        read_work_item create_work_item update_work_item admin_work_item
      ]
    end

    let(:permissions) { record_type == :work_item ? issue_permissions + work_item_permissions : issue_permissions }

    context 'when the user is anonymous' do
      subject { described_class.new(nil, with_epic_type) }

      it "does not allow any access to the #{record_type}" do
        expect_disallowed(*permissions)
      end
    end

    where(role: %w[guest planner reporter owner admin assignee author support_bot])

    with_them do
      subject { described_class.new(current_user, with_epic_type) }

      let(:current_user) { public_send(role) }

      it "does not allow user any access to the #{record_type}" do
        expect_disallowed(*permissions)
      end
    end
  end
end
