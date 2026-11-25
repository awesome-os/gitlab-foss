# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['NamespaceSidebar'], feature_category: :navigation do
  include GraphqlHelpers

  let(:fields) do
    %i[open_issues_count open_merge_requests_count open_work_items_count]
  end

  specify { expect(described_class.graphql_name).to eq('NamespaceSidebar') }

  specify { expect(described_class).to have_graphql_fields(fields).at_least }

  describe '#open_merge_requests_count' do
    let_it_be(:user) { create(:user) }

    context 'when namespace is a Group' do
      let_it_be(:group) { create(:group) }

      it 'delegates to Groups::MergeRequestsCountService with fast_timeout' do
        service = instance_double(Groups::MergeRequestsCountService, count: 5)
        expect(Groups::MergeRequestsCountService)
          .to receive(:new).with(group, user, fast_timeout: true).and_return(service)

        expect(resolve_field(:open_merge_requests_count, group, current_user: user)).to eq(5)
      end

      it 'returns nil when the query times out' do
        service = instance_double(Groups::MergeRequestsCountService)
        allow(Groups::MergeRequestsCountService)
          .to receive(:new).with(group, user, fast_timeout: true).and_return(service)
        allow(service).to receive(:count).and_raise(ActiveRecord::QueryCanceled)

        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          an_instance_of(ActiveRecord::QueryCanceled),
          group_id: group.id,
          query: 'group_sidebar_merge_requests_count'
        )

        expect(resolve_field(:open_merge_requests_count, group, current_user: user)).to be_nil
      end

      context 'when the group is a subgroup' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        before do
          stub_feature_flags(group_sidebar_mr_and_epic_counts_fast_timeout: group)
        end

        it 'checks the feature flag against the root ancestor' do
          service = instance_double(Groups::MergeRequestsCountService, count: 5)
          expect(Groups::MergeRequestsCountService)
            .to receive(:new).with(subgroup, user, fast_timeout: true).and_return(service)

          expect(resolve_field(:open_merge_requests_count, subgroup, current_user: user)).to eq(5)
        end
      end

      context 'when group_sidebar_mr_and_epic_counts_fast_timeout is disabled' do
        before do
          stub_feature_flags(group_sidebar_mr_and_epic_counts_fast_timeout: false)
        end

        it 'delegates to Groups::MergeRequestsCountService without fast_timeout' do
          service = instance_double(Groups::MergeRequestsCountService, count: 5)
          expect(Groups::MergeRequestsCountService)
            .to receive(:new).with(group, user, fast_timeout: false).and_return(service)

          expect(resolve_field(:open_merge_requests_count, group, current_user: user)).to eq(5)
        end

        it 'returns nil when the query times out' do
          service = instance_double(Groups::MergeRequestsCountService)
          allow(Groups::MergeRequestsCountService)
            .to receive(:new).with(group, user, fast_timeout: false).and_return(service)
          allow(service).to receive(:count).and_raise(ActiveRecord::QueryCanceled)

          expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
            an_instance_of(ActiveRecord::QueryCanceled),
            group_id: group.id,
            query: 'group_sidebar_merge_requests_count'
          )

          expect(resolve_field(:open_merge_requests_count, group, current_user: user)).to be_nil
        end
      end
    end

    context 'when namespace is a ProjectNamespace' do
      let_it_be(:project) { create(:project) }

      it 'delegates to Projects::OpenMergeRequestsCountService' do
        service = instance_double(Projects::OpenMergeRequestsCountService, count: 3)
        expect(Projects::OpenMergeRequestsCountService)
          .to receive(:new).with(project).and_return(service)

        expect(resolve_field(:open_merge_requests_count, project.project_namespace, current_user: user)).to eq(3)
      end
    end
  end

  describe '#open_work_items_count' do
    let_it_be(:user) { create(:user) }

    context 'when namespace is a Group' do
      let_it_be(:group) { create(:group) }

      before_all do
        group.add_developer(user)
      end

      it 'delegates to Groups::OpenWorkItemsCountService with fast_timeout' do
        service = instance_double(Groups::OpenWorkItemsCountService, count: 5)
        expect(Groups::OpenWorkItemsCountService)
          .to receive(:new).with(group, user, fast_timeout: true).and_return(service)

        expect(resolve_field(:open_work_items_count, group, current_user: user)).to eq(5)
      end

      it 'returns nil when the query times out' do
        service = instance_double(Groups::OpenWorkItemsCountService)
        allow(Groups::OpenWorkItemsCountService)
          .to receive(:new).with(group, user, fast_timeout: true).and_return(service)
        allow(service).to receive(:count).and_raise(ActiveRecord::QueryCanceled)

        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          an_instance_of(ActiveRecord::QueryCanceled),
          group_id: group.id,
          query: 'group_sidebar_work_items_count'
        )

        expect(resolve_field(:open_work_items_count, group, current_user: user)).to be_nil
      end
    end

    context 'when namespace is a ProjectNamespace' do
      let_it_be(:project) { create(:project) }

      before_all do
        project.add_developer(user)
      end

      it 'delegates to Projects::OpenWorkItemsCountService' do
        service = instance_double(Projects::OpenWorkItemsCountService, count: 3)
        expect(Projects::OpenWorkItemsCountService)
          .to receive(:new).with(project, user).and_return(service)

        expect(resolve_field(:open_work_items_count, project.project_namespace, current_user: user)).to eq(3)
      end
    end

    context 'when namespace is neither a Group nor a ProjectNamespace' do
      let_it_be(:personal_namespace) { create(:namespace) }

      it 'returns nil' do
        expect(resolve_field(:open_work_items_count, personal_namespace, current_user: user)).to be_nil
      end
    end
  end
end
