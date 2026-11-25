# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Preloaders::ProjectArchivedAncestorsPreloader, feature_category: :groups_and_projects do
  let_it_be(:archived_group) { create(:group, :archived) }
  let_it_be(:subgroup) { create(:group, parent: archived_group) }
  let_it_be(:project_with_archived_ancestor) { create(:project, group: subgroup) }
  let_it_be(:self_archived_project) { create(:project, :archived) }
  let_it_be(:unarchived_project) { create(:project) }

  let(:all_projects) { [project_with_archived_ancestor, self_archived_project, unarchived_project] }
  let(:projects) { Project.id_in(all_projects) }

  describe '#execute' do
    subject(:execute) { described_class.new(projects).execute }

    it 'returns the projects as a loaded array' do
      result = execute

      expect(result).to be_an(Array)
      expect(result).to match_array(all_projects)
    end

    it 'preloads the ancestor state so self_or_ancestors_archived? fires no per-project query' do
      preloaded = execute

      expect do
        preloaded.each(&:self_or_ancestors_archived?)
      end.not_to exceed_query_limit(0)
    end

    it 'answers self_or_ancestors_archived? correctly from the preloaded data' do
      by_id = execute.index_by(&:id)

      expect(by_id[project_with_archived_ancestor.id].self_or_ancestors_archived?).to be(true)
      expect(by_id[self_archived_project.id].self_or_ancestors_archived?).to be(true)
      expect(by_id[unarchived_project.id].self_or_ancestors_archived?).to be(false)
    end

    context 'when given an array of projects rather than a relation' do
      let(:projects) { all_projects }

      it 'still preloads the ancestor state' do
        preloaded = execute

        expect do
          preloaded.each(&:self_or_ancestors_archived?)
        end.not_to exceed_query_limit(0)
      end
    end
  end
end
