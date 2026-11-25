# frozen_string_literal: true

module Issues
  class ReferencedMergeRequestsService < Issues::BaseService
    def execute(issue)
      referenced = referenced_merge_requests(issue)
      closed_by = closed_by_merge_requests(issue)

      ActiveRecord::Associations::Preloader.new(
        records: referenced + closed_by,
        associations: { head_pipeline: { project: [:route, { namespace: :route }] } }
      ).call

      [sort_by_iid(referenced), sort_by_iid(closed_by)]
    end

    def related_merge_requests(issue)
      merge_requests = related_merge_requests_union(issue)

      ActiveRecord::Associations::Preloader.new(
        records: merge_requests,
        associations: { head_pipeline: { project: [:route, { namespace: :route }] } }
      ).call

      sort_by_iid(merge_requests)
    end

    def related_merge_request_ids(issue)
      related_merge_requests_union(issue).map(&:id)
    end

    def referenced_merge_requests(issue)
      return filter_readable_by_user(extract_merge_requests(issue)) unless memoize_referenced_merge_requests?

      # Memoized across service instances: the work item development widget resolves both
      # relatedBranches (own service instance) and relatedMergeRequests, which would otherwise
      # extract twice. Duplicated so a caller mutating its copy cannot poison the others.
      Gitlab::SafeRequestStore.fetch([:issue_referenced_merge_requests, project&.id, current_user&.id, issue.id]) do
        filter_readable_by_user(extract_merge_requests(issue))
      end.dup
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def closed_by_merge_requests(issue)
      return [] unless issue.open?

      merge_requests = extract_merge_requests(issue, filter: :system).select(&:open?)

      return [] if merge_requests.empty?

      ids = MergeRequestIssue.link_type_closes.where(
        merge_request_id: merge_requests.map(&:id),
        issue_id: issue.id
      ).pluck(:merge_request_id)
      merge_requests.select { |mr| mr.id.in?(ids) }
    end
    # rubocop: enable CodeReuse/ActiveRecord

    private

    def memoize_referenced_merge_requests?
      Feature.enabled?(:memoize_issue_referenced_merge_requests, current_user)
    end

    def related_merge_requests_union(issue)
      referenced_merge_requests(issue) | persisted_related_merge_requests(issue)
    end

    def persisted_related_merge_requests(issue)
      merge_request_ids = MergeRequestIssue.link_type_related.with_issues(issue.id).select(:merge_request_id)
      merge_requests = MergeRequest.id_in(merge_request_ids).preload_target_project.preload_author

      filter_readable_by_user(merge_requests)
    end

    def filter_readable_by_user(merge_requests)
      cross_project_filter = ->(merge_requests) do
        merge_requests.select { |mr| mr.target_project == project }
      end

      Ability.merge_requests_readable_by_user(
        merge_requests,
        current_user,
        filters: {
          read_cross_project: cross_project_filter
        }
      )
    end

    def extract_merge_requests(issue, filter: nil)
      ext = issue.all_references(current_user)
      notes = issue_notes(issue)
      notes = notes.select(&filter) if filter

      notes.each do |note|
        note.all_references(current_user, extractor: ext)
      end

      ext.merge_requests
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def issue_notes(issue)
      @issue_notes ||= {}
      @issue_notes[issue] ||= issue.notes.includes(:author)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def sort_by_iid(merge_requests)
      Gitlab::IssuableSorter.sort(project, merge_requests) { |mr| mr.iid.to_s } # rubocop:disable Lint/UnexpectedBlockArity -- false positive (detected as Array.sort)
    end
  end
end
