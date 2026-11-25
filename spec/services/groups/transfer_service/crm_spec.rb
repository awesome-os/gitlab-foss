# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::TransferService, :sidekiq_inline, feature_category: :groups_and_projects do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:new_parent_group) { create(:group, :public, owners: user) }

  let(:transfer_service) { described_class.new(group, user) }

  describe '#execute' do
    context 'when handling crm' do
      let(:root_group) { create(:group, :public) }
      let(:subgroup) { create(:group, :public, parent: root_group) }
      let(:another_subgroup) { create(:group, :public, parent: root_group) }
      let(:subsubgroup) { create(:group, :public, parent: subgroup) }

      let(:root_project) { create(:project, group: root_group) }
      let(:sub_project) { create(:project, group: subgroup) }
      let(:another_project) { create(:project, group: another_subgroup) }
      let(:subsub_project) { create(:project, group: subsubgroup) }

      let!(:contacts) { create_list(:contact, 4, group: root_group) }
      let!(:crm_organizations) { create_list(:crm_organization, 2, group: root_group) }

      before do
        create(:issue_customer_relations_contact, contact: contacts[0], issue: create(:issue, project: root_project))
        create(:issue_customer_relations_contact, contact: contacts[1], issue: create(:issue, project: sub_project))
        create(:issue_customer_relations_contact, contact: contacts[2], issue: create(:issue, project: another_project))
        create(:issue_customer_relations_contact, contact: contacts[3], issue: create(:issue, project: subsub_project))
        root_group.add_owner(user)
      end

      context 'when moving up' do
        let(:group) { subsubgroup }

        it 'retains issue contacts' do
          expect { transfer_service.execute(root_group) }
            .not_to change { CustomerRelations::IssueContact.count }
        end

        it_behaves_like 'publishes a GroupTransferedEvent' do
          let(:target) { root_group }
        end
      end

      context 'when moving down' do
        let(:group) { subgroup }

        it 'retains issue contacts' do
          expect { transfer_service.execute(another_subgroup) }
          .not_to change { CustomerRelations::IssueContact.count }
        end

        it_behaves_like 'publishes a GroupTransferedEvent' do
          let(:target) { another_subgroup }
        end
      end

      context 'when moving sideways' do
        let(:group) { subsubgroup }

        it 'retains issue contacts' do
          expect { transfer_service.execute(another_subgroup) }
          .not_to change { CustomerRelations::IssueContact.count }
        end

        it_behaves_like 'publishes a GroupTransferedEvent' do
          let(:target) { another_subgroup }
        end
      end

      context 'when moving to a new root group' do
        let(:group) { root_group }

        it 'moves all crm objects' do
          expect { transfer_service.execute(new_parent_group) }
            .to change { root_group.contacts.count }.by(-4)
            .and change { root_group.crm_organizations.count }.by(-2)
        end

        it 'retains issue contacts' do
          expect { transfer_service.execute(new_parent_group) }
            .not_to change { CustomerRelations::IssueContact.count }
        end

        it_behaves_like 'publishes a GroupTransferedEvent' do
          let(:target) { new_parent_group }
        end
      end

      context 'when moving to a subgroup within a new root group' do
        let(:group) { root_group }
        let(:subgroup_in_new_parent_group) { create(:group, parent: new_parent_group) }

        context 'with permission on the root group' do
          it 'moves all crm objects' do
            expect { transfer_service.execute(subgroup_in_new_parent_group) }
              .to change { root_group.contacts.count }.by(-4)
              .and change { root_group.crm_organizations.count }.by(-2)
          end

          it 'retains issue contacts' do
            expect { transfer_service.execute(subgroup_in_new_parent_group) }
              .not_to change { CustomerRelations::IssueContact.count }
          end

          it_behaves_like 'publishes a GroupTransferedEvent' do
            let(:target) { subgroup_in_new_parent_group }
          end
        end

        context 'with permission on the subgroup' do
          let(:new_parent_group) { create(:group, :public) }

          before do
            subgroup_in_new_parent_group.add_owner(user)
          end

          it 'raises error' do
            transfer_service.execute(subgroup_in_new_parent_group)

            expect(transfer_service.error).to eq(
              "Group contains contacts/organizations and you don't have enough " \
                "permissions to move them to the new root group."
            )
          end

          it 'does not publish a GroupTransferedEvent' do
            expect { transfer_service.execute(subgroup_in_new_parent_group) }
              .not_to publish_event(Groups::GroupTransferedEvent)
          end

          context 'when the group only has organizations' do
            before do
              CustomerRelations::IssueContact.delete_all
              root_group.contacts.delete_all
            end

            it 'raises error' do
              transfer_service.execute(subgroup_in_new_parent_group)

              expect(transfer_service.error).to eq(
                "Group contains contacts/organizations and you don't have enough " \
                  "permissions to move them to the new root group."
              )
            end
          end

          context 'when the group uses the CRM of another group' do
            before do
              create(:crm_settings, group: root_group, source_group: create(:group))
              root_group.reload
            end

            it 'does not check permissions to move crm objects' do
              transfer_service.execute(subgroup_in_new_parent_group)

              expect(transfer_service.error).to be_nil
            end
          end
        end
      end
    end
  end
end
