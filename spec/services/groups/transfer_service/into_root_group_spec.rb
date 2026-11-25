# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::TransferService, :sidekiq_inline, feature_category: :groups_and_projects do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:new_parent_group) { create(:group, :public, owners: user) }

  let(:transfer_service) { described_class.new(group, user) }

  describe '#execute' do
    context 'when transforming a group into a root group' do
      let_it_be_with_reload(:group) { create(:group, :public, :nested) }
      let_it_be_with_reload(:group_member) { create(:group_member, :owner, group: group, user: user) }

      it_behaves_like 'ensuring allowed transfer for a group'

      context 'when the group is already a root group' do
        let(:group) { create(:group, :public) }

        it 'adds an error on group' do
          transfer_service.execute(nil)
          expect(transfer_service.error).to eq('Group is already a root group.')
        end

        it 'records a failure transfer metric' do
          expect(::Gitlab::Metrics::Transfers).to receive(:count_transfer)
            .with(namespace_type: 'group', result: 'failure')

          transfer_service.execute(nil)
        end
      end

      context 'when the user does not have the right policies' do
        let(:restricted_user) { create(:user) }
        let(:transfer_service) { described_class.new(group, restricted_user) }

        it "returns false" do
          expect(transfer_service.execute(nil)).to be_falsy
        end

        it "adds an error on group" do
          transfer_service.execute(new_parent_group)
          expect(transfer_service.error).to eq("You don't have enough permissions.")
        end
      end

      context 'when there is a group with the same path' do
        let_it_be_with_reload(:group) { create(:group, :public, :nested, path: 'not-unique', owners: user) }

        before_all do
          create(:group, path: 'not-unique')
        end

        it 'returns false' do
          expect(transfer_service.execute(nil)).to be_falsy
        end

        it 'adds an error on group' do
          transfer_service.execute(nil)
          expect(transfer_service.error).to eq(
            'The parent group already has a subgroup or a project with the same path.'
          )
        end
      end

      context 'when the group is a subgroup and the transfer is valid' do
        let_it_be(:subgroup1) { create(:group, :private, parent: group) }
        let_it_be(:subgroup2) { create(:group, :internal, parent: group) }
        let_it_be(:project1) { create(:project, :private, namespace: group) }

        before do
          transfer_service.execute(nil)
          group.reload
        end

        it 'updates group attributes' do
          expect(group.parent).to be_nil
        end

        it 'updates group children path' do
          group.children.each do |subgroup|
            expect(subgroup.full_path).to eq("#{group.path}/#{subgroup.path}")
          end
        end

        it 'updates group projects path' do
          group.projects.each do |project|
            expect(project.full_path).to eq("#{group.path}/#{project.path}")
          end
        end

        context 'when projects have project namespaces' do
          let_it_be(:project1) { create(:project, :private, namespace: group) }
          let_it_be(:project2) { create(:project, :private, namespace: group) }

          it_behaves_like 'project namespace path is in sync with project path' do
            let(:group_full_path) { group.path.to_s }
            let(:projects_with_project_namespace) { [project1, project2] }
          end
        end
      end
    end

    context 'when transferring a subgroup into root group' do
      let(:group) { create(:group, :public, :nested, owners: user) }
      let(:subgroup) { create(:group, :public, parent: group) }
      let(:transfer_service) { described_class.new(subgroup, user) }

      it 'ensures there is still an owner for the transferred group' do
        expect(subgroup.all_owner_members).to be_empty

        transfer_service.execute(nil)
        subgroup.reload

        expect(subgroup.all_owner_members.map(&:user)).to match_array(user)
      end

      context 'when group has explicit owner' do
        let(:another_owner) { create(:user) }
        let(:subgroup) { create(:group, :public, parent: group, owners: another_owner) }

        it 'does not add additional owner' do
          expect(subgroup.all_owner_members.map(&:user)).to match_array(another_owner)

          transfer_service.execute(nil)
          subgroup.reload

          expect(subgroup.all_owner_members.map(&:user)).to match_array(another_owner)
        end
      end
    end
  end
end
