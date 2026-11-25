# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Hierarchy, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:task) { create(:work_item, :task, project: project) }
  let_it_be_with_reload(:work_item_parent) { create(:work_item, project: project) }

  describe '.type' do
    subject { described_class.type }

    it { is_expected.to eq(:hierarchy) }
  end

  describe '#type' do
    subject { described_class.new(task).type }

    it { is_expected.to eq(:hierarchy) }
  end

  describe '#parent' do
    let_it_be_with_reload(:parent_link) { create(:parent_link, work_item: task, work_item_parent: work_item_parent) }

    subject { described_class.new(parent_link.work_item).parent }

    it { is_expected.to eq(parent_link.work_item_parent) }
  end

  describe '#has_parent?' do
    subject { described_class.new(task.reload).has_parent? }

    context 'when parent is present' do
      specify do
        create(:parent_link, work_item: task, work_item_parent: work_item_parent)

        is_expected.to be(true)
      end
    end

    context 'when parent is not present' do
      it { is_expected.to be(false) }
    end
  end

  describe '#children' do
    let_it_be_with_reload(:parent_link1) { create(:parent_link, work_item_parent: work_item_parent, work_item: task) }
    let_it_be_with_reload(:parent_link2) { create(:parent_link, work_item_parent: work_item_parent) }

    subject { described_class.new(work_item_parent).children }

    it { is_expected.to contain_exactly(parent_link1.work_item, parent_link2.work_item) }

    context 'when ordered by relative position and work_item_id' do
      let_it_be(:oldest_child) { create(:work_item, :task, project: project) }
      let_it_be(:newest_child) { create(:work_item, :task, project: project) }

      let_it_be_with_reload(:link_to_oldest_child) do
        create(:parent_link, work_item_parent: work_item_parent, work_item: oldest_child)
      end

      let_it_be_with_reload(:link_to_newest_child) do
        create(:parent_link, work_item_parent: work_item_parent, work_item: newest_child)
      end

      let(:parent_links_ordered) { [parent_link1, parent_link2, link_to_oldest_child, link_to_newest_child] }

      context 'when children relative positions are nil' do
        it 'orders by work_item_id' do
          is_expected.to eq(parent_links_ordered.map(&:work_item))
        end
      end

      context 'when children relative positions are present' do
        let(:first_position) { 10 }
        let(:second_position) { 20 }
        let(:parent_links_ordered) { [link_to_oldest_child, link_to_newest_child, parent_link1, parent_link2] }

        before do
          link_to_oldest_child.update!(relative_position: first_position)
          link_to_newest_child.update!(relative_position: second_position)
        end

        it 'orders by relative_position and by created_at' do
          is_expected.to eq(parent_links_ordered.map(&:work_item))
        end
      end

      context 'when filtered by state' do
        let_it_be(:open_child) { create(:work_item, :task, state: :opened, project: project) }
        let_it_be(:closed_child) { create(:work_item, :task, state: :closed, project: project) }

        let_it_be_with_reload(:link_to_open_child) do
          create(:parent_link, work_item_parent: work_item_parent, work_item: open_child)
        end

        let_it_be_with_reload(:link_to_closed_child) do
          create(:parent_link, work_item_parent: work_item_parent, work_item: closed_child)
        end

        it 'returns only opened items' do
          result = described_class.new(work_item_parent).children(state: :opened)

          expect(result).to include(open_child)
          expect(result).not_to include(closed_child)
        end

        it 'returns only closed items' do
          result = described_class.new(work_item_parent).children(state: :closed)

          expect(result).to include(closed_child)
          expect(result).not_to include(open_child)
        end

        it 'returns all items' do
          result = described_class.new(work_item_parent).children

          expect(result).to include(
            open_child,
            closed_child
          )
        end
      end
    end
  end

  describe '#rolled_up_counts_by_type' do
    let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }
    let_it_be(:sub_epic) { create(:work_item, :epic, :closed, namespace: group) }
    let_it_be(:sub_sub_epic) { create(:work_item, :epic, namespace: group) }
    let_it_be(:sub_epic_2) { create(:work_item, :epic, namespace: group) }
    let_it_be(:sub_issue) { create(:work_item, :issue, :closed, project: project) }
    let_it_be(:sub_issue_2) { create(:work_item, :issue, project: project) }
    let_it_be(:sub_task) { create(:work_item, :task, project: project) }

    subject(:rolled_up_counts_by_type) { described_class.new(work_item).rolled_up_counts_by_type }

    before_all do
      skip unless Gitlab.ee?

      create(:parent_link, work_item_parent: work_item, work_item: sub_epic)
      create(:parent_link, work_item_parent: sub_epic, work_item: sub_sub_epic)
      create(:parent_link, work_item_parent: sub_epic, work_item: sub_issue)
      create(:parent_link, work_item_parent: sub_issue, work_item: sub_task)
      create(:parent_link, work_item_parent: work_item, work_item: sub_epic_2)
      create(:parent_link, work_item_parent: sub_epic_2, work_item: sub_issue_2)
    end

    shared_examples 'rolled up counts by work item type and state' do
      it 'returns rolled up counts by work item type and state' do
        is_expected.to contain_exactly(
          {
            work_item_type: build(:work_item_system_defined_type, :epic),
            counts_by_state: { all: 3, opened: 2, closed: 1 }
          },
          {
            work_item_type: build(:work_item_system_defined_type, :issue),
            counts_by_state: { all: 2, opened: 1, closed: 1 }
          },
          {
            work_item_type: build(:work_item_system_defined_type, :task),
            counts_by_state: { all: 1, opened: 1, closed: 0 }
          },
          {
            work_item_type: build(:work_item_system_defined_type, :ticket),
            counts_by_state: { all: 0, opened: 0, closed: 0 }
          }
        )
      end
    end

    shared_examples 'loads the counts only when needed' do
      def counts_queries(recorder)
        recorder.log.grep(/base_and_descendants|descendant_links/)
      end

      it 'loads the counts once per widget' do
        widget = described_class.new(work_item)
        recorder = ActiveRecord::QueryRecorder.new { 2.times { widget.rolled_up_counts_by_type } }

        expect(counts_queries(recorder).size).to eq(1)
      end

      it 'does not load the counts for a type without descendant types' do
        recorder = ActiveRecord::QueryRecorder.new { described_class.new(sub_task).rolled_up_counts_by_type }

        expect(counts_queries(recorder)).to be_empty
      end
    end

    context 'when batch_work_item_rolled_up_counts is enabled' do
      it_behaves_like 'rolled up counts by work item type and state'
      it_behaves_like 'loads the counts only when needed'

      it 'loads the counts with the batched query' do
        expect(::WorkItems::ParentLink).to receive(:descendant_counts_by_type_and_state)
          .with([work_item.id]).once.and_call_original

        rolled_up_counts_by_type
      end
    end

    context 'when batch_work_item_rolled_up_counts is disabled' do
      before do
        stub_feature_flags(batch_work_item_rolled_up_counts: false)
      end

      it_behaves_like 'rolled up counts by work item type and state'
      it_behaves_like 'loads the counts only when needed'

      it 'does not use the batched query' do
        expect(::WorkItems::ParentLink).not_to receive(:descendant_counts_by_type_and_state)

        rolled_up_counts_by_type
      end
    end
  end

  describe '#batch_rolled_up_counts?' do
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:subgroup_work_item) { create(:work_item, project: create(:project, group: subgroup)) }

    where(:work_item_name, :flag_actor, :expected) do
      :work_item_parent   | :group     | true
      :subgroup_work_item | :group     | true
      :subgroup_work_item | :subgroup  | false
      :work_item_parent   | :project   | false
      :work_item_parent   | :disabled  | false
    end

    with_them do
      let(:actor) { flag_actor == :disabled ? false : public_send(flag_actor) }

      before do
        stub_feature_flags(batch_work_item_rolled_up_counts: actor)
      end

      it 'is enabled only for the root namespace of the work item' do
        expect(described_class.new(public_send(work_item_name)).batch_rolled_up_counts?).to eq(expected)
      end
    end

    it 'is disabled when the work item has no namespace traversal ids' do
      stub_feature_flags(batch_work_item_rolled_up_counts: group)
      work_item = build_stubbed(:work_item, project: project, namespace_traversal_ids: nil)

      expect(described_class.new(work_item).batch_rolled_up_counts?).to be(false)
    end
  end

  describe '#depth_limit_reached_by_type' do
    let_it_be(:work_item) { create(:work_item, :issue) }
    let_it_be(:hierarchy) { described_class.new(work_item) }

    it 'returns an array of hashes with work_item_type and depth_limit_reached' do
      descendant_types = work_item.work_item_type.descendant_types(resource_parent: work_item.resource_parent)

      result = hierarchy.depth_limit_reached_by_type

      expect(result.size).to eq(descendant_types.size)
      result.each do |item|
        expect(item).to have_key(:work_item_type)
        expect(item).to have_key(:depth_limit_reached)
        expect(item[:depth_limit_reached]).to be_in([true, false])
      end
    end

    it 'calls max_depth_reached? for each descendant type' do
      descendant_types = work_item.work_item_type.descendant_types(resource_parent: work_item.resource_parent)
      descendant_types.each do |type|
        expect(work_item).to receive(:max_depth_reached?).with(type).once.and_return(false)
      end

      hierarchy.depth_limit_reached_by_type
    end

    context 'when there are no descendant types' do
      let_it_be(:work_item_without_children) { create(:work_item, :task) }
      let_it_be(:hierarchy_without_children) { described_class.new(work_item_without_children) }

      it 'returns an empty array' do
        result = hierarchy_without_children.depth_limit_reached_by_type

        expect(result).to eq([])
      end
    end
  end
end
