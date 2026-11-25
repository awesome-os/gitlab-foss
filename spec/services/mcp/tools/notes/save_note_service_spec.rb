# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Notes::SaveNoteService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:work_item) { create(:work_item, :issue, project: project, iid: 42) }

  let(:service) { described_class.new(name: 'save_note') }
  let(:request) { Grape::Request.new(Rack::MockRequest.env_for('/api/v4/mcp')) }

  before_all do
    project.add_developer(user)
  end

  before do
    service.set_cred(current_user: user)
  end

  describe 'class configuration' do
    it 'registers version 0.1.0' do
      expect(described_class.available_versions).to include('0.1.0')
    end

    it 'has readOnlyHint: false annotation' do
      expect(service.annotations[:readOnlyHint]).to be(false)
    end

    it 'has destructiveHint: true annotation' do
      expect(service.annotations[:destructiveHint]).to be(true)
    end

    it 'aliases the tools it replaces' do
      expect(described_class.tool_aliases)
        .to contain_exactly('create_merge_request_note', 'create_workitem_note', 'create_work_item_note')
    end
  end

  describe 'input schema' do
    it 'locks the full input schema for version 0.1.0' do
      expect(described_class.version_metadata('0.1.0')[:input_schema]).to eq({
        type: 'object',
        properties: {
          url: {
            type: 'string',
            description: 'GitLab URL of a merge request or work item, including issues and epics ' \
              '(.../-/merge_requests/<iid>, .../-/work_items/<iid>, .../-/issues/<iid>, or ' \
              '.../groups/<full_path>/-/epics/<iid>). Issue URLs are project-scoped; epic URLs are group-scoped ' \
              'and must include the groups/ prefix. ' \
              'The URL determines the target type, so no other identifier is needed'
          },
          project_id: {
            type: 'string',
            description: 'ID or path of the project. Required with merge_request_iid, and with ' \
              'work_item_iid for project-level work items'
          },
          group_id: {
            type: 'string',
            description: 'ID or path of the group. Required with work_item_iid for group-level work items'
          },
          merge_request_iid: {
            type: 'integer',
            description: 'Internal ID of the merge request. Provide with project_id. Mutually exclusive ' \
              'with work_item_iid'
          },
          work_item_iid: {
            type: 'integer',
            description: 'Internal ID of the work item. Provide with project_id or group_id. Mutually ' \
              'exclusive with merge_request_iid'
          },
          method: {
            type: 'string',
            enum: %w[create_note reply_discussion resolve_discussion],
            description: 'The write operation to perform. Omit to create a note, or to reply when ' \
              'discussion_id is given. Fill only the parameters listed for the chosen method; ' \
              'other parameters are rejected.'
          },
          body: {
            type: 'string',
            description: 'Content of the note/comment (create_note, reply_discussion; max 1048576 characters). ' \
              'Lines beginning with "/" are rejected to avoid triggering quick actions such as /merge',
            maxLength: 1_048_576
          },
          internal: {
            type: 'boolean',
            description: 'Mark note as internal (visible only to members with at least the Reporter role)'
          },
          discussion_id: {
            type: 'string',
            description: 'Discussion to reply to (reply_discussion) or to resolve or unresolve ' \
              '(resolve_discussion). Accepts the global ID (gid://gitlab/Discussion/<id>) or the bare <id>. ' \
              'If omitted, creates a new top-level note'
          },
          resolved: {
            type: 'boolean',
            description: 'true resolves the discussion, false unresolves it (resolve_discussion)'
          }
        }
      })
    end
  end

  describe '#execute' do
    context 'with a merge request target' do
      let(:params) do
        { arguments: { project_id: project.id.to_s, merge_request_iid: merge_request.iid, body: 'Test comment' } }
      end

      it 'creates a note on the merge request', :aggregate_failures do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['note']['body']).to eq('Test comment')
      end
    end

    context 'with a work item target' do
      let(:params) do
        { arguments: { project_id: project.id.to_s, work_item_iid: work_item.iid, body: 'Test comment' } }
      end

      it 'creates a note on the work item', :aggregate_failures do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['note']['body']).to eq('Test comment')
      end
    end

    context 'with method resolve_discussion on a work item' do
      let_it_be_with_reload(:discussion_note) do
        create(:discussion_note_on_issue, project: project, noteable: work_item)
      end

      let(:identification) { { project_id: project.id.to_s, work_item_iid: work_item.iid } }

      it 'resolves and unresolves the discussion', :aggregate_failures do
        result = service.execute(
          request: request,
          params: { arguments: identification.merge(method: 'resolve_discussion',
            discussion_id: discussion_note.discussion_id, resolved: true) }
        )

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['method']).to eq('resolve_discussion')
        expect(result[:structuredContent]['resolved']).to be(true)
        expect(discussion_note.reload.resolved?).to be(true)

        result = service.execute(
          request: request,
          params: { arguments: identification.merge(method: 'resolve_discussion',
            discussion_id: discussion_note.discussion_id, resolved: false) }
        )

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['resolved']).to be(false)
        expect(discussion_note.reload.resolved?).to be(false)
      end

      it 'returns a validation error when resolved is missing' do
        result = service.execute(
          request: request,
          params: { arguments: identification.merge(method: 'resolve_discussion',
            discussion_id: discussion_note.discussion_id) }
        )

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text])
          .to include('Missing required parameters for resolve_discussion: resolved')
      end
    end

    context 'when a parameter does not belong to the chosen method' do
      let(:identification) { { project_id: project.id.to_s, work_item_iid: work_item.iid } }

      it 'rejects body with resolve_discussion', :aggregate_failures do
        result = service.execute(
          request: request,
          params: { arguments: identification.merge(method: 'resolve_discussion', discussion_id: 'abc',
            resolved: true, body: 'ignored') }
        )

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text])
          .to include("Parameters not valid for method 'resolve_discussion': body")
      end

      it 'rejects resolved with create_note', :aggregate_failures do
        result = service.execute(
          request: request,
          params: { arguments: identification.merge(method: 'create_note', body: 'Hi', resolved: true) }
        )

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include("Parameters not valid for method 'create_note': resolved")
      end

      context 'when method is omitted and discussion_id is present' do
        let_it_be(:discussion_note) do
          create(:discussion_note_on_issue, project: project, noteable: work_item)
        end

        it 'defaults to reply_discussion and accepts internal: false', :aggregate_failures do
          result = service.execute(
            request: request,
            params: { arguments: identification.merge(discussion_id: discussion_note.discussion_id,
              body: 'A reply', internal: false) }
          )

          expect(result[:isError]).to be(false)
          expect(result[:structuredContent]['note']['body']).to eq('A reply')
          expect(result[:structuredContent]['note']['discussion']['id'])
            .to eq(discussion_note.discussion.to_global_id.to_s)
        end
      end
    end

    context 'when a required parameter is missing' do
      let(:identification) { { project_id: project.id.to_s, work_item_iid: work_item.iid } }

      it 'rejects create_note without body' do
        result = service.execute(request: request, params: { arguments: identification })

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('Missing required parameters for create_note: body')
      end

      it 'rejects reply_discussion without discussion_id' do
        result = service.execute(
          request: request,
          params: { arguments: identification.merge(method: 'reply_discussion', body: 'A reply') }
        )

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text])
          .to include('Missing required parameters for reply_discussion: discussion_id')
      end
    end

    context 'when method is not in the enum' do
      let(:params) do
        { arguments: { project_id: project.id.to_s, work_item_iid: work_item.iid, method: 'approve', body: 'x' } }
      end

      it 'returns a validation error response' do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include("Invalid method: 'approve'")
      end
    end

    context 'when current_user is not set' do
      let(:params) do
        { arguments: { project_id: project.id.to_s, merge_request_iid: merge_request.iid, body: 'Test comment' } }
      end

      before do
        service.set_cred(current_user: nil)
      end

      it 'returns error response' do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('current_user is not set')
      end
    end

    context 'when the merge request does not exist' do
      let(:params) do
        { arguments: { project_id: project.id.to_s, merge_request_iid: non_existing_record_iid, body: 'Test' } }
      end

      it 'returns a not-found error response', :aggregate_failures do
        result = service.execute(request: request, params: params)

        expect(result[:content].first[:text]).to eq('Tool execution failed: Merge request not found or inaccessible')
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:not_found)
      end
    end

    context 'when the merge request is in a project the user cannot see' do
      let_it_be(:hidden_merge_request) do
        create(:merge_request, source_project: create(:project, :repository, :private))
      end

      let(:params) { { arguments: { url: ::Gitlab::UrlBuilder.build(hidden_merge_request), body: 'Test' } } }

      it 'returns the same message, logged as unauthorized', :aggregate_failures do
        result = service.execute(request: request, params: params)

        expect(result[:content].first[:text]).to eq('Tool execution failed: Merge request not found or inaccessible')
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:unauthorized)
      end
    end

    context 'when the project does not exist' do
      let(:params) do
        { arguments: { project_id: 'does/not/exist', merge_request_iid: merge_request.iid, body: 'Test' } }
      end

      it 'returns an error response' do
        result = service.execute(request: request, params: params)

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('Merge request not found')
      end
    end
  end

  describe '#governed_containers' do
    let_it_be(:discussion_note) { create(:discussion_note_on_issue, project: project, noteable: work_item) }

    def governed(discussion_id)
      service.governed_containers(
        { method: 'resolve_discussion', discussion_id: discussion_id, resolved: true }.with_indifferent_access
      )
    end

    it 'governs resolve_discussion by the container holding the discussion' do
      expect(governed(discussion_note.discussion_id).containers).to contain_exactly(project)
    end

    it 'reads a Discussion Global ID' do
      expect(governed("gid://gitlab/Discussion/#{discussion_note.discussion_id}").containers)
        .to contain_exactly(project)
    end

    it 'governs by no container for an unknown discussion' do
      expect(governed(SecureRandom.hex(20)).containers).to be_empty
    end

    it 'governs by no container for a url that is not a string, so schema validation answers' do
      arguments = { method: 'create_note', url: 123, body: 'x' }.with_indifferent_access

      expect(service.governed_containers(arguments).containers).to be_empty
    end

    context 'with a discussion on each kind of noteable' do
      let_it_be(:noteable_group) { create(:group) }
      let_it_be(:noteable_project) { create(:project, :public, :repository, group: noteable_group) }

      def self.noteable_cases
        cases = [
          ['AlertManagement::Alert', -> { create(:note_on_alert, project: noteable_project) }, :noteable_project],
          ['Commit', -> { create(:note_on_commit, project: noteable_project) }, :noteable_project],
          ['DesignManagement::Design', -> { create(:note_on_design, project: noteable_project) }, :noteable_project],
          ['Issue', -> { create(:note_on_issue, project: noteable_project) }, :noteable_project],
          ['WorkItem', -> {
            create(:note, noteable: create(:work_item, :group_level, namespace: noteable_group),
              namespace: noteable_group, project: nil)
          }, :noteable_group],
          ['MergeRequest', -> { create(:note_on_merge_request, project: noteable_project) }, :noteable_project],
          ['ProjectSnippet', -> { create(:note_on_project_snippet, project: noteable_project) }, :noteable_project],
          ['PersonalSnippet', -> { create(:note_on_personal_snippet) }, nil],
          ['WikiPage::Meta', -> { create(:note, :on_project_level_wiki, project: noteable_project) }, :noteable_project]
        ]

        return cases unless Gitlab.ee?

        cases + [
          ['Epic', -> {
            create(:note, noteable: create(:epic, group: noteable_group), namespace: noteable_group, project: nil)
          }, :noteable_group],
          ['Vulnerability', -> { create(:note_on_vulnerability, project: noteable_project) }, :noteable_project],
          ['ComplianceManagement::Projects::ComplianceViolation', -> {
            violation = create(:project_compliance_violation, namespace: noteable_group, project: noteable_project)
            create(:note, noteable: violation, project: noteable_project)
          }, :noteable_project],
          ['WikiPage::Meta', -> { create(:note, :on_group_level_wiki, namespace: noteable_group) }, :noteable_group]
        ]
      end

      noteable_cases.each do |type, build_note, expected|
        it "governs a discussion on #{type} by #{expected || 'no container'}" do
          note = instance_exec(&build_note)
          containers = governed(note.discussion_id).containers

          expect(containers).to eq(expected ? [public_send(expected)] : [])
        end
      end

      it 'has a case for every Noteable', :eager_load do
        noteables = ObjectSpace.each_object(Class).select { |klass| Noteable > klass && klass.name }.map(&:name)

        expect(self.class.noteable_cases.map(&:first).uniq).to match_array(noteables.uniq - ['Snippet'])
      end
    end
  end
end
