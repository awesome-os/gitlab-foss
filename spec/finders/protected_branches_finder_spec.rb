# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranchesFinder, feature_category: :source_code_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }

  let_it_be(:project_protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:another_project_protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:group_protected_branch) { create(:protected_branch, project: nil, group: group) }
  let_it_be(:another_group_protected_branch) { create(:protected_branch, project: nil, group: group) }
  let_it_be(:other_protected_branch) { create(:protected_branch) }

  let(:params) { {} }

  subject(:execute) { described_class.new(entity, params).execute }

  describe '#execute' do
    context 'with a project entity' do
      let(:entity) { project }

      it 'returns only the project protected branches' do
        expect(execute).to match_array([project_protected_branch, another_project_protected_branch])
      end

      context 'when search param is present' do
        let(:params) { { search: project_protected_branch.name } }

        it 'filters by search param' do
          expect(execute).to eq([project_protected_branch])
        end
      end

      context 'when there are more protected branches than the limit' do
        before do
          stub_const("#{described_class}::LIMIT", 1)
        end

        it 'returns limited protected branches' do
          expect(execute.count).to eq(1)
        end
      end
    end

    context 'with a group entity' do
      let(:entity) { group }

      it 'returns the group protected branches' do
        expect(execute).to match_array([group_protected_branch, another_group_protected_branch])
      end
    end
  end
end
