# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerProjectPolicy, feature_category: :runner_core do
  let_it_be(:project) { create(:project) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:runner) { create(:ci_runner, :project, projects: [project, other_project]) }
  let_it_be(:owner_runner_project) { project.runner_projects.first }
  let_it_be(:member_runner_project) { other_project.runner_projects.first }

  let_it_be(:owner) { create(:user, owner_of: [project, other_project]) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [project, other_project]) }
  let_it_be(:admin) { create(:admin) }

  let_it_be(:locked_runner) { create(:ci_runner, :project, :locked, projects: [project, other_project]) }
  let_it_be(:locked_runner_project) { locked_runner.runner_projects.last }

  let(:runner_project) { member_runner_project }

  subject(:policy) { described_class.new(user, runner_project) }

  describe 'ability :unassign_runner' do
    context 'when the user is a maintainer' do
      let(:user) { maintainer }

      it { expect_allowed(:unassign_runner) }

      context 'with a locked runner' do
        let(:runner_project) { locked_runner_project }

        it { expect_disallowed(:unassign_runner) }
      end

      context 'when the project owns the runner' do
        let(:runner_project) { owner_runner_project }

        it { expect_disallowed(:unassign_runner) }
      end
    end

    context 'when the user is an admin' do
      let(:user) { admin }

      it { expect_disallowed(:unassign_runner) }

      context 'with admin mode enabled', :enable_admin_mode do
        it { expect_allowed(:unassign_runner) }

        context 'with a locked runner' do
          let(:runner_project) { locked_runner_project }

          it { expect_allowed(:unassign_runner) }
        end

        context 'when the project owns the runner' do
          let(:runner_project) { owner_runner_project }

          it { expect_disallowed(:unassign_runner) }
        end
      end
    end
  end

  context 'when the assigned project is archived' do
    let_it_be(:archived_project) { create(:project, :archived, owners: owner) }
    let_it_be(:shared_runner) { create(:ci_runner, :project, projects: [project, archived_project]) }

    let(:user) { owner }
    let(:runner_project) { shared_runner.runner_projects.find_by(project: archived_project) }

    it { expect_allowed(:unassign_runner) }
  end
end
