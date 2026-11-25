# frozen_string_literal: true

RSpec.shared_examples 'abilities without group level work items license' do
  context 'without group level work items license' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_licensed_features(epics: false)
    end

    where(:user_name, :work_item_name) do
      :non_member_user    | :work_item
      :non_member_user    | :confidential_work_item
      :guest              | :not_persisted_work_item
      :guest              | :work_item
      :guest              | :confidential_work_item
      :planner            | :work_item
      :planner            | :confidential_work_item
      :reporter           | :work_item
      :reporter           | :confidential_work_item
      :group_guest        | :work_item
      :group_guest        | :confidential_work_item
      :group_guest_author | :authored_work_item
      :group_guest_author | :authored_confidential_work_item
      :group_planner      | :work_item
      :group_planner      | :confidential_work_item
      :group_reporter     | :work_item
      :group_reporter     | :confidential_work_item
    end

    with_them do
      subject { permissions(public_send(user_name), public_send(work_item_name)) }

      it 'denies the permissions' do
        expect_disallowed(
          :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
          :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji,
          :move_work_item, :clone_work_item
        )
      end
    end
  end
end

RSpec.shared_examples 'abilities with group level work items license' do
  context 'with group level work items license', if: Gitlab.ee? do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when checking project guest abilities' do
      context 'with guest on not_persisted_work_item' do
        subject { permissions(guest, not_persisted_work_item) }

        it 'allows the permissions' do
          expect_allowed(:read_work_item, :read_issue, :read_note, :create_note, :award_emoji)
        end

        it 'denies the permissions' do
          expect_disallowed(
            :admin_work_item, :update_work_item, :delete_work_item, :admin_parent_link, :set_work_item_metadata,
            :admin_work_item_link, :move_work_item, :clone_work_item
          )
        end
      end

      context 'with guest on work_item' do
        subject { permissions(guest, work_item) }

        it 'allows the permissions' do
          expect_allowed(:read_work_item, :read_issue, :read_note, :create_note, :award_emoji)
        end

        it 'denies the permissions' do
          expect_disallowed(
            :admin_work_item, :update_work_item, :delete_work_item, :admin_parent_link, :set_work_item_metadata,
            :admin_work_item_link, :move_work_item, :clone_work_item
          )
        end
      end

      context 'with guest on confidential_work_item' do
        subject { permissions(guest, confidential_work_item) }

        it 'denies the permissions' do
          expect_disallowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
            :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji, :move_work_item,
            :clone_work_item
          )
        end
      end
    end

    context 'when checking project planner abilities' do
      context 'with planner on work_item' do
        subject { permissions(planner, work_item) }

        it 'allows the permissions' do
          expect_allowed(:read_work_item, :read_issue, :read_note, :create_note, :award_emoji)
        end

        it 'denies the permissions' do
          expect_disallowed(
            :admin_work_item, :update_work_item, :delete_work_item, :admin_parent_link, :set_work_item_metadata,
            :admin_work_item_link, :move_work_item, :clone_work_item
          )
        end
      end

      context 'with planner on confidential_work_item' do
        subject { permissions(planner, confidential_work_item) }

        it 'denies the permissions' do
          expect_disallowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
            :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji, :move_work_item,
            :clone_work_item
          )
        end
      end
    end

    context 'when checking project reporter abilities' do
      context 'with reporter on work_item' do
        subject { permissions(reporter, work_item) }

        it 'allows the permissions' do
          expect_allowed(:read_work_item, :read_issue, :read_note, :create_note, :award_emoji)
        end

        it 'denies the permissions' do
          expect_disallowed(
            :admin_work_item, :update_work_item, :delete_work_item, :admin_parent_link, :set_work_item_metadata,
            :admin_work_item_link, :move_work_item, :clone_work_item
          )
        end
      end

      context 'with reporter on confidential_work_item' do
        subject { permissions(reporter, confidential_work_item) }

        it 'denies the permissions' do
          expect_disallowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
            :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji, :move_work_item,
            :clone_work_item
          )
        end
      end
    end

    context 'when checking group guest abilities' do
      context 'with group_guest on not_persisted_work_item' do
        subject { permissions(group_guest, not_persisted_work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :admin_parent_link, :set_work_item_metadata,
            :admin_work_item_link, :create_note, :award_emoji
          )
        end
      end

      context 'with group_guest on work_item' do
        subject { permissions(group_guest, work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :admin_parent_link, :admin_work_item_link, :create_note,
            :award_emoji
          )
        end

        it 'denies the permissions' do
          expect_disallowed(
            :admin_work_item, :update_work_item, :delete_work_item, :set_work_item_metadata, :move_work_item,
            :clone_work_item
          )
        end
      end

      context 'with group_guest on confidential_work_item' do
        subject { permissions(group_guest, confidential_work_item) }

        it 'denies the permissions' do
          expect_disallowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
            :set_work_item_metadata, :create_note, :award_emoji, :move_work_item, :clone_work_item
          )
        end
      end

      context 'with group_guest_author on authored_work_item' do
        subject { permissions(group_guest_author, authored_work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :update_work_item, :delete_work_item, :admin_parent_link,
            :admin_work_item_link, :create_note, :award_emoji
          )
        end

        it 'denies the permissions' do
          expect_disallowed(:admin_work_item, :set_work_item_metadata, :move_work_item, :clone_work_item)
        end
      end

      context 'with group_guest_author on authored_confidential_work_item' do
        subject { permissions(group_guest_author, authored_confidential_work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :update_work_item, :delete_work_item, :admin_parent_link,
            :admin_work_item_link, :create_note, :award_emoji
          )
        end

        it 'denies the permissions' do
          expect_disallowed(:admin_work_item, :set_work_item_metadata, :move_work_item, :clone_work_item)
        end
      end
    end

    context 'when checking group planner abilities' do
      context 'with group_planner on work_item' do
        subject { permissions(group_planner, work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
            :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji,
            :move_work_item, :clone_work_item
          )
        end
      end

      context 'with group_planner on confidential_work_item' do
        subject { permissions(group_planner, confidential_work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :delete_work_item,
            :admin_parent_link, :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji,
            :move_work_item, :clone_work_item
          )
        end
      end
    end

    context 'when checking group reporter abilities' do
      context 'with group_reporter on work_item' do
        subject { permissions(group_reporter, work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
            :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji, :move_work_item,
            :clone_work_item
          )
        end

        it 'denies the permissions' do
          expect_disallowed(:delete_work_item)
        end
      end

      context 'with group_reporter on confidential_work_item' do
        subject { permissions(group_reporter, confidential_work_item) }

        it 'allows the permissions' do
          expect_allowed(
            :read_work_item, :read_issue, :read_note, :admin_work_item, :update_work_item, :admin_parent_link,
            :set_work_item_metadata, :admin_work_item_link, :create_note, :award_emoji, :move_work_item,
            :clone_work_item
          )
        end

        it 'denies the permissions' do
          expect_disallowed(:delete_work_item)
        end
      end
    end
  end
end
