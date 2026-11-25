# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::TransferService, :sidekiq_inline, feature_category: :groups_and_projects do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:new_parent_group) { create(:group, :public, owners: user) }

  let(:transfer_service) { described_class.new(group, user) }

  context 'when handling packages' do
    let_it_be_with_reload(:group) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: group) }

    let!(:new_group) { create(:group, owners: user) }

    context 'with an npm package' do
      let_it_be(:npm_package) { create(:npm_package, project: project, name: "@testscope/test") }

      shared_examples 'transfer allowed' do
        it 'allows transfer' do
          transfer_service.execute(new_group)

          expect(transfer_service.error).to be_nil
          expect(group.parent).to eq(new_group)
        end
      end

      it_behaves_like 'transfer allowed'

      context 'with a project within subgroup' do
        let_it_be(:root_group) { create(:group, owners: user) }
        let_it_be_with_reload(:group) { create(:group, parent: root_group) }
        let_it_be(:project) { create(:project, namespace: group) }

        it_behaves_like 'transfer allowed'

        context 'without a root namespace change' do
          let_it_be(:new_group) { create(:group, parent: root_group, owners: user) }

          it_behaves_like 'transfer allowed'
        end

        context 'with namespaced packages present' do
          let_it_be_with_reload(:package) do
            create(:npm_package, project: project, name: "@#{project.root_namespace.path}/test")
          end

          it 'does not allow transfer' do
            transfer_service.execute(new_group)

            expect(transfer_service.error).to eq(
              'Group contains projects with NPM packages scoped to the current root level group.'
            )
            expect(group.parent).not_to eq(new_group)
          end

          context 'when the namespaced package is pending destruction' do
            let_it_be_with_reload(:group) { create(:group, owners: user) }

            before do
              package.pending_destruction!
            end

            it_behaves_like 'transfer allowed'
          end
        end

        context 'when transferring a group into a root group' do
          let_it_be(:root_group) { create(:group, owners: user) }
          let_it_be_with_reload(:group) { create(:group, parent: root_group) }
          let_it_be(:new_group) { nil }

          it_behaves_like 'transfer allowed'
        end
      end
    end

    context 'without an npm package' do
      context 'when transferring a group into a root group' do
        let(:parent_group) { create(:group) }
        let(:group) { create(:group, parent: parent_group, owners: user) }

        it 'allows transfer' do
          transfer_service.execute(nil)

          expect(transfer_service.error).to be_nil
          expect(group.parent).to be_nil
        end
      end
    end
  end

  describe '#execute' do
    context 'when a project has container images' do
      let(:group) { create(:group, :public, :nested, owners: user) }
      let!(:container_repository) { create(:container_repository, project: project) }

      subject(:transfer_result) { transfer_service.execute(new_parent_group) }

      context 'when within group' do
        let(:project) { create(:project, :public, namespace: group) }

        it 'does not transfer' do
          expect(transfer_result).to be false
          expect(transfer_service.error).to match(/Docker images in their container registry/)
        end
      end

      context 'when within subgroup' do
        let(:subgroup) { create(:group, parent: group) }
        let(:project) { create(:project, :public, namespace: subgroup) }

        it 'does not transfer' do
          expect(transfer_result).to be false
          expect(transfer_service.error).to match(/Docker images in their container registry/)
        end
      end
    end
  end
end
