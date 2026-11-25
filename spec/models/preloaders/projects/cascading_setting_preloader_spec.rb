# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::Projects::CascadingSettingPreloader, feature_category: :groups_and_projects do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:locked_root) { create(:group) }
  let_it_be(:project_in_subgroup) { create(:project, group: create(:group, parent: locked_root)) }
  let_it_be(:unlocked_project) { create(:project, group: root_group) }
  let_it_be(:personal_project) { create(:project) }

  let(:attribute) { :web_based_commit_signing_enabled }
  let(:project_ids) { [project_in_subgroup, unlocked_project, personal_project].map(&:id) }
  let(:projects) { Project.id_in(project_ids).order(:id).to_a }

  before_all do
    NamespaceSetting.where(namespace_id: locked_root.id)
      .update_all(web_based_commit_signing_enabled: true, lock_web_based_commit_signing_enabled: true)
    project_in_subgroup.project_setting.update!(web_based_commit_signing_enabled: false)
    unlocked_project.project_setting.update!(web_based_commit_signing_enabled: true)
  end

  it 'resolves the cascaded values with one NamespaceSetting query', :aggregate_failures do
    expected = projects.map { |project| Project.find(project.id).project_setting.public_send(attribute) }

    preload = ActiveRecord::QueryRecorder.new { described_class.new(projects, attribute).execute }
    values = nil
    read = ActiveRecord::QueryRecorder.new { values = projects.map { |p| p.project_setting.public_send(attribute) } }

    expect(values).to eq(expected)
    expect(expected).to eq([true, true, false])
    expect(preload.log.count { |query| query.include?('"namespace_settings"') }).to eq(1)
    expect(read.count).to eq(0)
  end

  it 'does not query NamespaceSetting when no project belongs to a group' do
    recorder = ActiveRecord::QueryRecorder.new do
      described_class.new([Project.find(personal_project.id)], attribute).execute
    end

    expect(recorder.log).not_to include(a_string_including('"namespace_settings"'))
  end
end
