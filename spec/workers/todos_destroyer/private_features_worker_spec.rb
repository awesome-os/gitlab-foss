# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TodosDestroyer::PrivateFeaturesWorker, feature_category: :team_planning do
  it "calls the Todos::Destroy::PrivateFeaturesService with the params it was given" do
    service = double

    expect(::Todos::Destroy::UnauthorizedFeaturesService).to receive(:new).with(100, nil).and_return(service)
    expect(service).to receive(:execute)

    described_class.new.perform(100)
  end

  it 'deduplicates jobs, including scheduled ones, until they start' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
    expect(described_class.get_deduplication_options).to include(including_scheduled: true)
  end

  it_behaves_like 'an idempotent worker' do
    let_it_be(:project) { create(:project, :public, :issues_private) }
    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:todo) { create(:todo, user: create(:user), project: project, target: work_item) }

    let(:job_args) { [project.id] }

    it 'deletes the to-do of the user who lost access' do
      expect { perform_idempotent_work }.to change { Todo.exists?(todo.id) }.from(true).to(false)
    end
  end
end
