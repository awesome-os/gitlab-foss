# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Suggestions, feature_category: :code_review_workflow do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }

  let(:merge_request) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let(:position) do
    Gitlab::Diff::Position.new(
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_line: nil,
      new_line: 9,
      diff_refs: merge_request.diff_refs
    )
  end

  let(:position2) do
    Gitlab::Diff::Position.new(
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_line: nil,
      new_line: 15,
      diff_refs: merge_request.diff_refs
    )
  end

  let(:diff_note) do
    create(:diff_note_on_merge_request, noteable: merge_request, position: position, project: project)
  end

  let(:diff_note2) do
    create(:diff_note_on_merge_request, noteable: merge_request, position: position2, project: project)
  end

  let(:suggestion) do
    create(:suggestion,
      note: diff_note,
      from_content: "      raise RuntimeError, \"System commands must be given as an array of strings\"\n",
      to_content: "      raise RuntimeError, 'Explosion'\n      # explosion?")
  end

  let(:unappliable_suggestion) do
    create(:suggestion, :unappliable, note: diff_note2)
  end

  describe "PUT /suggestions/:id/apply" do
    let(:url) { "/suggestions/#{suggestion.id}/apply" }

    it_behaves_like 'authorizing granular token permissions', :apply_suggestion do
      let(:boundary_object) { project }

      before do
        project.add_maintainer(user)
      end

      let(:request) { put api(url, personal_access_token: pat) }
    end

    describe 'mcp route setting' do
      subject { put api(url, user) }

      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'an endpoint with mcp route setting', :apply_suggestion,
        expected_params: [:id, :commit_message]

      describe 'governance container' do
        include ProjectForksHelper

        let_it_be(:other_project) { create(:project) }

        let(:tool) { Mcp::Tools::Manager.new.list_tools['apply_suggestion'] }

        it 'governs the call by the suggestion project' do
          resolved = tool.governed_containers({ id: suggestion.id }.with_indifferent_access)

          expect(resolved.containers).to contain_exactly(project)
        end

        it 'does not govern the call by a project whose id equals the suggestion id' do
          colliding = create(:suggestion, id: other_project.id, note: diff_note)

          resolved = tool.governed_containers({ id: colliding.id }.with_indifferent_access)

          expect(resolved.containers).to contain_exactly(project)
        end

        it 'governs the call by no project when the suggestion does not exist' do
          resolved = tool.governed_containers({ id: non_existing_record_id }.with_indifferent_access)

          expect(resolved.containers).to be_empty
        end

        it 'also governs the call by the fork the merge request comes from' do
          fork = fork_project(project, user, repository: true)
          fork_merge_request = create(:merge_request, source_project: fork, target_project: project)
          fork_note = create(:diff_note_on_merge_request, noteable: fork_merge_request, project: project)
          fork_suggestion = create(:suggestion, note: fork_note)

          resolved = tool.governed_containers({ id: fork_suggestion.id }.with_indifferent_access)

          expect(resolved.containers).to contain_exactly(project, fork)
        end
      end
    end

    context 'when successfully applies patch' do
      it 'renders an ok response and returns json content' do
        project.add_maintainer(user)

        put api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response)
          .to include('id', 'from_line', 'to_line', 'appliable', 'applied', 'from_content', 'to_content')
      end

      it 'returns the suggestion as applied', :aggregate_failures do
        project.add_maintainer(user)

        put api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include('id' => suggestion.id, 'applied' => true, 'appliable' => false)
      end
    end

    context 'when a custom commit message is included' do
      it 'renders an ok response and returns json content' do
        project.add_maintainer(user)

        message = "cool custom commit message!"

        put api(url, user), params: { commit_message: message }

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.repository.commit.message).to eq(message)
      end
    end

    context 'when not able to apply patch' do
      let(:url) { "/suggestions/#{unappliable_suggestion.id}/apply" }

      it 'renders a bad request error and returns json content' do
        project.add_maintainer(user)

        put api(url, user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'message' => "Can't apply as this line was changed in a more recent version." })
      end
    end

    context 'when suggestion is not found' do
      let(:url) { "/suggestions/9999/apply" }

      it 'renders a not found error and returns json content' do
        project.add_maintainer(user)

        put api(url, user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response).to eq({ 'message' => 'Suggestion is not applicable as the suggestion was not found.' })
      end
    end

    context 'when suggestion ID is not valid' do
      let(:url) { "/suggestions/foo-123/apply" }

      it 'renders a not found error and returns json content' do
        project.add_maintainer(user)

        put api(url, user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'error' => 'id is invalid' })
      end
    end

    context 'when unauthorized' do
      it 'renders a forbidden error and returns json content' do
        project.add_reporter(user)

        put api(url, user)

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response).to eq({ 'message' => '403 Forbidden' })
      end
    end
  end

  describe "PUT /suggestions/batch_apply" do
    let(:suggestion2) do
      create(
        :suggestion,
        note: diff_note2,
        from_content: "      \"PWD\" => path\n",
        to_content: "      *** FOO ***\n"
      )
    end

    let(:url) { "/suggestions/batch_apply" }

    it_behaves_like 'authorizing granular token permissions', :apply_suggestion do
      let(:boundary_object) { project }

      before do
        project.add_maintainer(user)
      end

      let(:request) do
        put api(url, personal_access_token: pat), params: { ids: [suggestion.id] }
      end
    end

    context 'when successfully applies multiple patches as a batch' do
      before do
        project.add_maintainer(user)
      end

      it 'renders an ok response and returns json content' do
        put api(url, user), params: { ids: [suggestion.id, suggestion2.id] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to all(
          include('id', 'from_line', 'to_line', 'appliable', 'applied', 'from_content', 'to_content')
        )
      end

      it 'returns the suggestions as applied', :aggregate_failures do
        put api(url, user), params: { ids: [suggestion.id, suggestion2.id] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to contain_exactly(
          include('id' => suggestion.id, 'applied' => true, 'appliable' => false),
          include('id' => suggestion2.id, 'applied' => true, 'appliable' => false)
        )
      end

      it 'provides a custom commit message' do
        message = "cool custom commit message!"

        put api(url, user), params: { ids: [suggestion.id, suggestion2.id],
                                      commit_message: message }

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.repository.commit.message).to eq(message)
      end
    end

    context 'when not able to apply one or more of the patches' do
      it 'renders a bad request error and returns json content' do
        project.add_maintainer(user)

        put api(url, user), params: { ids: [suggestion.id, unappliable_suggestion.id] }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'message' => "Can't apply as this line was changed in a more recent version." })
      end
    end

    context 'with missing suggestions' do
      it 'renders a not found error and returns json content if any suggestion is not found' do
        project.add_maintainer(user)

        put api(url, user), params: { ids: [suggestion.id, 'foo-123'] }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response)
          .to eq({ 'message' => 'Suggestions are not applicable as one or more suggestions were not found.' })
      end

      it 'renders a bad request error and returns json content when no suggestions are provided' do
        project.add_maintainer(user)

        put api(url, user), params: {}

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response)
          .to eq({ 'error' => "ids is missing" })
      end
    end

    context 'when unauthorized' do
      it 'renders a forbidden error and returns json content' do
        project.add_reporter(user)

        put api(url, user), params: { ids: [suggestion.id, suggestion2.id] }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response).to eq({ 'message' => '403 Forbidden' })
      end
    end
  end

  context 'with a merge request from a fork' do
    include ProjectForksHelper

    # Both projects are public so the merge request can allow collaboration.
    let(:project) { create(:project, :public, :repository) }
    let(:target_maintainer) { create(:user, maintainer_of: project) }
    let(:fork_owner) { create(:user) }
    let(:fork) { fork_project(project, fork_owner, repository: true) }
    let(:allow_collaboration) { false }
    let(:pat) { nil }

    let(:merge_request) do
      create(:merge_request, source_project: fork, target_project: project, allow_collaboration: allow_collaboration)
    end

    def fork_head
      fork.commit(merge_request.source_branch).id
    end

    def granular_pat(owner, boundary_resource, permissions: [:apply_suggestion])
      create(:granular_pat, user: owner, boundary: ::Authz::Boundary.for(boundary_resource),
        permissions: permissions)
    end

    def enforce_fine_grained_tokens(group)
      group.namespace_settings.update!(enforce_granular_tokens: true, granular_tokens_enforced_after: Date.current)
    end

    shared_examples 'applying the suggestion to the fork' do
      it 'commits to the fork source branch', :aggregate_failures do
        expect { request }.to change { fork_head }

        expect(response).to have_gitlab_http_status(:ok)
        expect(suggestion.reload).to be_applied
      end
    end

    shared_examples 'refusing to apply the suggestion' do
      it 'leaves the fork source branch untouched', :aggregate_failures do
        expect { request }.not_to change { fork_head }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(suggestion.reload).not_to be_applied
      end
    end

    shared_examples 'refusing to apply the suggestion by the user permission check' do
      it_behaves_like 'refusing to apply the suggestion'

      it 'passes the token check' do
        request

        expect(json_response).to eq({ 'message' => '403 Forbidden' })
      end
    end

    shared_examples 'applying a suggestion on a fork merge request' do
      context 'with a legacy personal access token' do
        context 'when the target maintainer applies it' do
          let(:actor) { target_maintainer }

          it_behaves_like 'refusing to apply the suggestion by the user permission check'

          context 'when the merge request allows collaboration' do
            let(:allow_collaboration) { true }

            it_behaves_like 'applying the suggestion to the fork'
          end
        end

        context 'when the fork owner applies it' do
          let(:actor) { fork_owner }

          it_behaves_like 'applying the suggestion to the fork'

          context 'when the fork group enforces fine-grained tokens' do
            let(:fork_group) { create(:group, :public, owners: fork_owner) }
            let(:fork) { fork_project(project, fork_owner, namespace: fork_group, repository: true) }

            before do
              enforce_fine_grained_tokens(fork_group)
            end

            it_behaves_like 'refusing to apply the suggestion'
          end

          context 'when the target group enforces fine-grained tokens' do
            let(:target_group) { create(:group, :public) }
            let(:project) { create(:project, :public, :repository, group: target_group) }

            before do
              enforce_fine_grained_tokens(target_group)
            end

            it_behaves_like 'refusing to apply the suggestion'
          end
        end
      end

      context 'with a fine-grained token' do
        let(:actor) { nil }

        context 'when the fork owner uses a token scoped to the fork' do
          let(:pat) { granular_pat(fork_owner, fork) }

          it_behaves_like 'applying the suggestion to the fork'
        end

        context 'when a fork member who cannot push uses a token scoped to the fork' do
          let(:fork_reporter) { create(:user, reporter_of: fork) }
          let(:pat) { granular_pat(fork_reporter, fork) }

          it_behaves_like 'refusing to apply the suggestion by the user permission check'
        end

        context 'when the token scoped to the fork lacks the apply permission' do
          let(:pat) { granular_pat(fork_owner, fork, permissions: [:read_merge_request]) }

          it_behaves_like 'refusing to apply the suggestion'
        end

        context 'when the target maintainer uses a token scoped to the target project on a private fork' do
          let(:fork) do
            fork_project(project, fork_owner, repository: true).tap do |fork|
              fork.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end
          end

          let(:pat) { granular_pat(target_maintainer, project) }

          it_behaves_like 'refusing to apply the suggestion by the user permission check'
        end

        context 'when the target maintainer uses a token for all memberships' do
          let(:pat) { granular_pat(target_maintainer, ::Authz::GranularScope::Access::ALL_MEMBERSHIPS) }

          it_behaves_like 'refusing to apply the suggestion by the user permission check'

          context 'when the merge request allows collaboration' do
            let(:allow_collaboration) { true }

            it_behaves_like 'applying the suggestion to the fork'
          end
        end

        context 'when the fork owner uses a token scoped to the target project' do
          let(:pat) { granular_pat(fork_owner, project) }

          before do
            project.add_developer(fork_owner)
          end

          it_behaves_like 'applying the suggestion to the fork'
        end

        context 'when the target maintainer uses a token scoped to the target project' do
          let(:pat) { granular_pat(target_maintainer, project) }

          it_behaves_like 'refusing to apply the suggestion by the user permission check'

          context 'when the merge request allows collaboration' do
            let(:allow_collaboration) { true }

            it_behaves_like 'applying the suggestion to the fork'
          end
        end
      end
    end

    describe 'PUT /suggestions/:id/apply' do
      let(:request) { put api("/suggestions/#{suggestion.id}/apply", actor, personal_access_token: pat) }

      it_behaves_like 'applying a suggestion on a fork merge request'
    end

    describe 'PUT /suggestions/batch_apply' do
      let(:request) do
        put api('/suggestions/batch_apply', actor, personal_access_token: pat), params: { ids: [suggestion.id] }
      end

      it_behaves_like 'applying a suggestion on a fork merge request'
    end
  end
end
