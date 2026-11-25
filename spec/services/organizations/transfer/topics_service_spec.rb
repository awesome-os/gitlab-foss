# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Transfer::TopicsService, :aggregate_failures, feature_category: :organization do
  let_it_be(:old_organization) { create(:organization) }
  let_it_be(:new_organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: old_organization) }

  let_it_be(:topic_project) { create(:project, namespace: group) }
  let_it_be(:topic_subgroup) { create(:group, parent: group) }
  let_it_be(:topic_subgroup_project) do
    create(:project, namespace: topic_subgroup)
  end

  let(:service) do
    described_class.new(
      group: group,
      old_organization: old_organization,
      new_organization: new_organization
    )
  end

  describe '#execute' do
    context 'with a basic topic transfer' do
      let!(:old_topic) do
        create(:topic, name: 'rails', organization: old_organization, slug: 'rails')
      end

      let!(:project_topic) do
        create(:project_topic, project: topic_project, topic: old_topic)
      end

      it 'creates topic in new org and repoints project_topic' do
        service.execute

        new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'rails')
        expect(new_topic).to be_present
        expect(new_topic.slug).to eq('rails')
        expect(project_topic.reload.topic_id).to eq(new_topic.id)
      end
    end

    context 'when topic with same name exists in target org' do
      let!(:old_topic) do
        create(:topic, name: 'ruby', organization: old_organization, slug: 'ruby')
      end

      let!(:existing_topic) do
        create(:topic, name: 'ruby', organization: new_organization, slug: 'ruby')
      end

      let!(:project_topic) do
        create(:project_topic, project: topic_project, topic: old_topic)
      end

      it 'reuses existing topic and does not create a duplicate' do
        expect { service.execute }.not_to change { Projects::Topic.where(name: 'ruby').count }

        expect(project_topic.reload.topic_id).to eq(existing_topic.id)
      end
    end

    context 'when project already has the target topic assigned' do
      let!(:old_topic) do
        create(:topic, name: 'python', organization: old_organization, slug: 'python')
      end

      let!(:target_topic) do
        create(:topic, name: 'python', organization: new_organization, slug: 'python')
      end

      let!(:old_project_topic) do
        create(:project_topic, project: topic_project, topic: old_topic)
      end

      let!(:existing_project_topic) do
        create(:project_topic, project: topic_project, topic: target_topic)
      end

      it 'removes the duplicate project_topic without violating unique constraint' do
        service.execute

        expect(Projects::ProjectTopic.where(project_id: topic_project.id, topic_id: old_topic.id)).not_to exist
        expect(Projects::ProjectTopic.where(project_id: topic_project.id, topic_id: target_topic.id)).to exist
      end
    end

    context 'when counter caches need updating' do
      let_it_be_with_reload(:old_topic) do
        create(:topic, name: 'go', organization: old_organization)
      end

      let_it_be(:public_project) do
        create(:project, :public, namespace: group, organization: old_organization)
      end

      before_all do
        create(:project_topic, project: topic_project, topic: old_topic)
        create(:project_topic, project: public_project, topic: old_topic)
        old_topic.update_columns(total_projects_count: 2, non_private_projects_count: 1)
      end

      it 'adjusts counter caches for old and new topics' do
        service.execute

        new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'go')
        expect(new_topic.total_projects_count).to eq(2)
        expect(new_topic.non_private_projects_count).to eq(1)

        old_topic.reload
        expect(old_topic.total_projects_count).to eq(0)
        expect(old_topic.non_private_projects_count).to eq(0)
      end

      context 'with multiple topics across mixed visibility projects' do
        let!(:internal_project) do
          create(:project, :internal, namespace: group, organization: old_organization)
        end

        let!(:second_topic) do
          create(:topic, name: 'rust', organization: old_organization)
        end

        before do
          create(:project_topic, project: topic_project, topic: second_topic)
          create(:project_topic, project: public_project, topic: second_topic)
          create(:project_topic, project: internal_project, topic: second_topic)
          second_topic.update_columns(total_projects_count: 3, non_private_projects_count: 2)

          create(:project_topic, project: internal_project, topic: old_topic)
          old_topic.update_columns(total_projects_count: 3, non_private_projects_count: 2)
        end

        it 'batches counter updates correctly for all affected topics' do
          service.execute

          new_go = Projects::Topic.find_by(organization_id: new_organization.id, name: 'go')
          new_rust = Projects::Topic.find_by(organization_id: new_organization.id, name: 'rust')

          old_topic.reload
          expect(old_topic.total_projects_count).to eq(0)
          expect(old_topic.non_private_projects_count).to eq(0)
          expect(new_go.total_projects_count).to eq(3)
          expect(new_go.non_private_projects_count).to eq(2)

          second_topic.reload
          expect(second_topic.total_projects_count).to eq(0)
          expect(second_topic.non_private_projects_count).to eq(0)
          expect(new_rust.total_projects_count).to eq(3)
          expect(new_rust.non_private_projects_count).to eq(2)
        end
      end

      context 'when duplicates exist for one topic but not another' do
        let!(:second_topic) do
          create(:topic, name: 'swift', organization: old_organization)
        end

        let!(:existing_swift) do
          create(:topic, name: 'swift', organization: new_organization)
        end

        before do
          create(:project_topic, project: topic_project, topic: second_topic)
          create(:project_topic, project: public_project, topic: second_topic)
          create(:project_topic, project: topic_project, topic: existing_swift)
          second_topic.update_columns(total_projects_count: 2, non_private_projects_count: 1)
          existing_swift.update_columns(total_projects_count: 1, non_private_projects_count: 0)
        end

        it 'accounts for deleted duplicates in old topic counters and moves non-duplicates to new topic' do
          service.execute

          second_topic.reload
          expect(second_topic.total_projects_count).to eq(0)
          expect(second_topic.non_private_projects_count).to eq(0)

          existing_swift.reload
          expect(existing_swift.total_projects_count).to eq(2)
          expect(existing_swift.non_private_projects_count).to eq(1)
        end
      end

      context 'when a topic is only on private projects' do
        let!(:private_topic) do
          create(:topic, name: 'private-only', organization: old_organization)
        end

        before do
          create(:project_topic, project: topic_project, topic: private_topic)
          create(:project_topic, project: topic_subgroup_project, topic: private_topic)
          private_topic.update_columns(total_projects_count: 2, non_private_projects_count: 0)
        end

        it 'sets non_private_projects_count to zero on the new topic' do
          service.execute

          new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'private-only')
          expect(new_topic.total_projects_count).to eq(2)
          expect(new_topic.non_private_projects_count).to eq(0)

          private_topic.reload
          expect(private_topic.total_projects_count).to eq(0)
          expect(private_topic.non_private_projects_count).to eq(0)
        end
      end

      context 'when old topic is partially transferred (shared with outside project)' do
        let_it_be(:outside_group) { create(:group, organization: old_organization) }
        let_it_be(:outside_project) do
          create(:project, :public, namespace: outside_group, organization: old_organization)
        end

        before do
          create(:project_topic, project: outside_project, topic: old_topic)
          old_topic.update_columns(total_projects_count: 3, non_private_projects_count: 2)
        end

        it 'decrements old topic only by the transferred portion' do
          service.execute

          new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'go')
          expect(new_topic.total_projects_count).to eq(2)
          expect(new_topic.non_private_projects_count).to eq(1)

          old_topic.reload
          expect(old_topic.total_projects_count).to eq(1)
          expect(old_topic.non_private_projects_count).to eq(1)
        end
      end
    end

    context 'when multiple projects share a topic' do
      let!(:shared_topic) do
        create(:topic, name: 'docker', organization: old_organization)
      end

      before do
        create(:project_topic, project: topic_project, topic: shared_topic)
        create(:project_topic, project: topic_subgroup_project, topic: shared_topic)
      end

      it 'repoints both project_topics and creates only one new topic' do
        service.execute

        new_topics = Projects::Topic.where(organization_id: new_organization.id, name: 'docker').to_a
        expect(new_topics.count).to eq(1)

        new_topic = new_topics.first
        expect(Projects::ProjectTopic.where(project_id: topic_project.id, topic_id: new_topic.id)).to exist
        expect(Projects::ProjectTopic.where(project_id: topic_subgroup_project.id, topic_id: new_topic.id)).to exist
      end
    end

    context 'when topic belongs to a third organization' do
      let!(:third_organization) { create(:organization) }
      let!(:third_org_topic) do
        create(:topic, name: 'elixir', organization: third_organization)
      end

      let!(:project_topic) do
        create(:project_topic, project: topic_project, topic: third_org_topic)
      end

      it 'does not modify the topic or project_topic' do
        service.execute

        expect(project_topic.reload.topic_id).to eq(third_org_topic.id)
        expect(third_org_topic.reload.organization_id).to eq(third_organization.id)
      end
    end

    context 'when topic is shared with a project outside the transferred group' do
      let_it_be(:outside_group) { create(:group, organization: old_organization) }
      let_it_be(:outside_project) { create(:project, namespace: outside_group, organization: old_organization) }
      let!(:shared_topic) do
        create(:topic, name: 'shared', organization: old_organization)
      end

      let!(:inside_project_topic) do
        create(:project_topic, project: topic_project, topic: shared_topic)
      end

      let!(:outside_project_topic) do
        create(:project_topic, project: outside_project, topic: shared_topic)
      end

      before do
        shared_topic.update_columns(total_projects_count: 2, non_private_projects_count: 0)
      end

      it 'repoints only the inside project and preserves the outside assignment' do
        service.execute

        new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'shared')
        expect(new_topic).to be_present
        expect(inside_project_topic.reload.topic_id).to eq(new_topic.id)
        expect(outside_project_topic.reload.topic_id).to eq(shared_topic.id)
        expect(shared_topic.reload.total_projects_count).to eq(1)
        expect(new_topic.total_projects_count).to eq(1)
      end
    end

    context 'when the old and new organization are the same' do
      let(:service) do
        described_class.new(group: group, old_organization: old_organization, new_organization: old_organization)
      end

      let!(:old_topic) { create(:topic, name: 'same-org', organization: old_organization, slug: 'same-org') }
      let!(:project_topic) { create(:project_topic, project: topic_project, topic: old_topic) }

      it 'leaves the topic and its project assignments unchanged' do
        expect { service.execute }.not_to change { Projects::Topic.count }

        expect(project_topic.reload.topic_id).to eq(old_topic.id)
      end
    end

    context 'when the topic has an avatar' do
      let!(:old_topic) { create(:topic, :with_avatar, name: 'with-avatar', organization: old_organization) }
      let!(:project_topic) { create(:project_topic, project: topic_project, topic: old_topic) }

      it 'schedules the avatar transfer to the copy' do
        expect { service.execute }.to change { Organizations::TransferTopicAvatarWorker.jobs.size }.by(1)

        new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'with-avatar')
        expect(Organizations::TransferTopicAvatarWorker.jobs.last['args']).to eq([old_topic.id, new_topic.id])
      end
    end

    context 'when projects have no topics' do
      it 'completes without error' do
        expect { service.execute }.not_to raise_error
      end
    end

    context 'when the group is deeply nested (multi-element traversal_ids)' do
      # traversal_ids is a bigint[] column. The old_topics query compares it with
      # a literal array via @>; guards against an integer[] vs bigint[] type
      # mismatch (PG::UndefinedFunction) on the traversal_ids containment check.
      let!(:deep_subgroup) { create(:group, parent: topic_subgroup) }
      let!(:deep_project) { create(:project, namespace: deep_subgroup) }
      let!(:deep_topic) { create(:topic, name: 'nested', organization: old_organization) }
      let!(:deep_project_topic) do
        create(:project_topic, project: deep_project, topic: deep_topic)
      end

      it 'executes the traversal_ids query and repoints the topic without a type error' do
        expect { service.execute }.not_to raise_error

        new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'nested')
        expect(new_topic).to be_present
        expect(deep_project_topic.reload.topic_id).to eq(new_topic.id)
      end
    end

    context 'with source topics that fail current validations' do
      def create_unvalidated_topic(name, **attributes)
        build(:topic, name: name, organization: old_organization, **attributes).tap do |topic|
          topic.save!(validate: false)
        end
      end

      context 'when the topic name is not ASCII' do
        let!(:old_topic) { create_unvalidated_topic('⚠️DEPRECATED⚠️', title: nil, slug: 'deprecated') }
        let!(:project_topic) { create(:project_topic, project: topic_project, topic: old_topic) }

        it 'copies the topic as-is and repoints the project_topic' do
          service.execute

          new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: '⚠️DEPRECATED⚠️')
          expect(new_topic).to have_attributes(title: nil, slug: 'deprecated')
          expect(project_topic.reload.topic_id).to eq(new_topic.id)
        end
      end

      context 'when source topic names differ only in case' do
        let!(:upper_topic) { create_unvalidated_topic('Docker') }
        let!(:lower_topic) { create_unvalidated_topic('docker') }
        let!(:upper_project_topic) { create(:project_topic, project: topic_project, topic: upper_topic) }
        let!(:lower_project_topic) { create(:project_topic, project: topic_subgroup_project, topic: lower_topic) }

        it 'copies both topics and repoints each project_topic' do
          service.execute

          new_upper = Projects::Topic.find_by(organization_id: new_organization.id, name: 'Docker')
          new_lower = Projects::Topic.find_by(organization_id: new_organization.id, name: 'docker')
          expect(upper_project_topic.reload.topic_id).to eq(new_upper.id)
          expect(lower_project_topic.reload.topic_id).to eq(new_lower.id)
        end
      end
    end

    context 'with topics that are inserted, reused and slug-conflicting' do
      let!(:inserted_topic) { create(:topic, name: 'alpha', organization: old_organization, slug: 'alpha') }
      let!(:reused_topic) { create(:topic, name: 'beta', organization: old_organization, slug: 'beta') }
      let!(:slug_conflict_topic) { create(:topic, name: 'gamma', organization: old_organization, slug: 'g') }
      let!(:delta_topic) { create(:topic, name: 'delta', organization: old_organization, slug: 'delta') }

      let!(:existing_beta) { create(:topic, name: 'beta', organization: new_organization, slug: 'beta') }
      let!(:slug_owner) { create(:topic, name: 'other', organization: new_organization, slug: 'g') }

      before do
        [inserted_topic, reused_topic, slug_conflict_topic, delta_topic].each do |topic|
          create(:project_topic, project: topic_project, topic: topic)
        end
      end

      it 'maps each source topic to the right copy' do
        service.execute

        copies = Projects::Topic.where(organization_id: new_organization.id).index_by(&:name)
        expect(copies['alpha']).to have_attributes(slug: 'alpha')
        expect(copies['beta']).to eq(existing_beta)
        expect(copies['gamma']).to have_attributes(slug: nil)
        expect(copies['delta']).to have_attributes(slug: 'delta')
        expect(slug_owner.reload.slug).to eq('g')

        expect(topic_project.reload.topics).to contain_exactly(
          copies['alpha'], copies['beta'], copies['gamma'], copies['delta']
        )
      end
    end

    context 'when a previous run copied the topic but did not repoint the project_topic' do
      let!(:old_topic) { create(:topic, name: 'kotlin', organization: old_organization, slug: 'kotlin') }
      let!(:project_topic) { create(:project_topic, project: topic_project, topic: old_topic) }
      let!(:copied_topic) { create(:topic, name: 'kotlin', organization: new_organization, slug: 'kotlin') }

      it 'reuses the copy and does not create another on re-runs' do
        expect { 2.times { service.execute } }.not_to change { Projects::Topic.count }

        expect(project_topic.reload.topic_id).to eq(copied_topic.id)
        expect(copied_topic.reload.total_projects_count).to eq(1)
      end
    end

    context 'when the slug is taken by another topic in the target org' do
      let!(:old_topic) { create(:topic, name: 'rails', organization: old_organization, slug: 'rails') }
      let!(:slug_owner) { create(:topic, name: 'ruby-on-rails', organization: new_organization, slug: 'rails') }
      let!(:project_topic) { create(:project_topic, project: topic_project, topic: old_topic) }

      it 'copies the topic without a slug' do
        service.execute

        new_topic = Projects::Topic.find_by(organization_id: new_organization.id, name: 'rails')
        expect(new_topic.slug).to be_nil
        expect(project_topic.reload.topic_id).to eq(new_topic.id)
        expect(slug_owner.reload.slug).to eq('rails')
      end
    end

    context 'when name matches existing topic in target org with different slug' do
      let!(:old_topic) do
        create(:topic, name: 'rails', organization: old_organization, slug: 'rails-old')
      end

      let!(:existing_topic) do
        create(:topic, name: 'rails', organization: new_organization, slug: 'rails-new')
      end

      let!(:project_topic) do
        create(:project_topic, project: topic_project, topic: old_topic)
      end

      it 'reuses the existing topic matched by name' do
        service.execute

        expect(project_topic.reload.topic_id).to eq(existing_topic.id)
      end
    end
  end
end
