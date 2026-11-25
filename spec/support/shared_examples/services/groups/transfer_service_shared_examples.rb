# frozen_string_literal: true

RSpec.shared_examples 'project namespace path is in sync with project path' do
  it 'keeps project and project namespace attributes in sync' do
    projects_with_project_namespace.each do |project|
      project.reload

      expect(project.full_path).to eq("#{group_full_path}/#{project.path}")
      expect(project.project_namespace.full_path).to eq(project.full_path)
      expect(project.project_namespace.parent).to eq(project.namespace)
      expect(project.project_namespace.visibility_level).to eq(project.visibility_level)
    end
  end
end

RSpec.shared_examples 'publishes a GroupTransferedEvent' do
  it 'publishes a GroupTransferedEvent' do
    expect { transfer_service.execute(target) }
      .to publish_event(Groups::GroupTransferedEvent)
      .with(
        group_id: group.id,
        old_root_namespace_id: group.root_ancestor.id,
        new_root_namespace_id: target.root_ancestor.id
      )
  end
end

RSpec.shared_examples 'ensuring allowed transfer for a group' do
  context "when there's an exception on GitLab shell directories" do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:update_group_attributes).and_raise(Gitlab::UpdatePathError,
          'namespace directory cannot be moved')
      end
    end

    it 'returns false' do
      expect(transfer_service.execute(new_parent_group)).to be_falsy
    end

    it 'adds an error on group' do
      transfer_service.execute(new_parent_group)
      expect(transfer_service.error).to eq('Transfer failed: namespace directory cannot be moved')
    end
  end
end
