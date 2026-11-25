# frozen_string_literal: true

# Before ingested_at, the delta MV skipped credits that arrived after its 30-minute window, and
# finished flows rarely re-emit. Re-emit each enriched row whose credits or model differ from the
# latest enrichment, stamped prev_version + 1us (the mr_outcomes rule) so it supersedes any repair.
class BackfillSessionCreditsOnDuoWorkflowsWorkflowsEnriched < ClickHouse::Migration
  BATCH_SIZE = 100_000
  PRIMARY_KEYS = %i[traversal_path created_at id].freeze

  def up
    # Ranges follow the enriched table's primary key, so each batch reads only its own rows;
    # an id range would scan every granule. All versions of a row share a key and a range.
    iterator = ClickHouse::TableIterator.new(
      'duo_workflows_workflows_enriched', primary_keys: PRIMARY_KEYS, connection: connection
    )

    iterator.each_range(of: BATCH_SIZE) do |scope|
      execute(insert_sql(scope.to_sql))
    end
  end

  def down
    # no-op: the re-emitted rows differ from MV-emitted rows only by _version, so they cannot be
    # selectively removed. Re-running up is idempotent: rows whose credits and model match are skipped.
  end

  private

  def insert_sql(range_sql)
    <<~SQL
      INSERT INTO duo_workflows_workflows_enriched
      (
        id, user_id, project_id, created_at, updated_at, status, goal,
        agent_privileges, workflow_definition, allow_agent_to_request_user,
        pre_approved_agent_privileges, image, environment, namespace_id,
        ai_catalog_item_version_id, issue_id, merge_request_id,
        service_account_id, tool_call_approvals, ai_catalog_item_id,
        traversal_path, messaging_callback_context, summary, title,
        incremental_checkpoints_enabled, agent_type, jsonl_sha256,
        idempotency_key, sync_type, agent_identity_id, web_search_enabled,
        trigger_source, trigger_flow_trigger_id, source_type, source_link,
        execution_mode, drop_reason, credits_used, model_used,
        source_merge_request_ids, created_merge_request_ids,
        later_closed_merge_request_ids, later_merged_merge_request_ids,
        _siphon_deleted, _version, _watermark
      )
      WITH
        latest AS
        (
          SELECT
            workflow_id,
            argMax(credits_used, updated_at) AS credits_used,
            argMax(model_used, updated_at) AS model_used
          FROM duo_workflow_session_enrichments
          WHERE workflow_id IN (SELECT id FROM (#{range_sql}))
          GROUP BY workflow_id
        ),
        current AS
        (
          SELECT
            traversal_path,
            created_at,
            id,
            argMax(user_id, _version) AS user_id,
            argMax(project_id, _version) AS project_id,
            argMax(updated_at, _version) AS updated_at,
            argMax(status, _version) AS status,
            argMax(goal, _version) AS goal,
            argMax(agent_privileges, _version) AS agent_privileges,
            argMax(workflow_definition, _version) AS workflow_definition,
            argMax(allow_agent_to_request_user, _version) AS allow_agent_to_request_user,
            argMax(pre_approved_agent_privileges, _version) AS pre_approved_agent_privileges,
            argMax(image, _version) AS image,
            argMax(environment, _version) AS environment,
            argMax(namespace_id, _version) AS namespace_id,
            argMax(ai_catalog_item_version_id, _version) AS ai_catalog_item_version_id,
            argMax(issue_id, _version) AS issue_id,
            argMax(merge_request_id, _version) AS merge_request_id,
            argMax(service_account_id, _version) AS service_account_id,
            argMax(tool_call_approvals, _version) AS tool_call_approvals,
            argMax(ai_catalog_item_id, _version) AS ai_catalog_item_id,
            argMax(messaging_callback_context, _version) AS messaging_callback_context,
            argMax(summary, _version) AS summary,
            argMax(title, _version) AS title,
            argMax(incremental_checkpoints_enabled, _version) AS incremental_checkpoints_enabled,
            argMax(agent_type, _version) AS agent_type,
            argMax(jsonl_sha256, _version) AS jsonl_sha256,
            argMax(idempotency_key, _version) AS idempotency_key,
            argMax(sync_type, _version) AS sync_type,
            argMax(agent_identity_id, _version) AS agent_identity_id,
            argMax(web_search_enabled, _version) AS web_search_enabled,
            argMax(trigger_source, _version) AS trigger_source,
            argMax(trigger_flow_trigger_id, _version) AS trigger_flow_trigger_id,
            argMax(source_type, _version) AS source_type,
            argMax(source_link, _version) AS source_link,
            argMax(execution_mode, _version) AS execution_mode,
            argMax(tuple(drop_reason), _version).1 AS drop_reason,
            argMax(credits_used, _version) AS credits_used,
            argMax(model_used, _version) AS model_used,
            argMax(source_merge_request_ids, _version) AS source_merge_request_ids,
            argMax(created_merge_request_ids, _version) AS created_merge_request_ids,
            argMax(later_closed_merge_request_ids, _version) AS later_closed_merge_request_ids,
            argMax(later_merged_merge_request_ids, _version) AS later_merged_merge_request_ids,
            argMax(_siphon_deleted, _version) AS _siphon_deleted,
            argMax(_watermark, _version) AS _watermark,
            max(_version) AS prev_version
          FROM (#{range_sql})
          WHERE id IN (SELECT workflow_id FROM latest)
          GROUP BY traversal_path, created_at, id
        )
      SELECT
        current.id, current.user_id, current.project_id, current.created_at, current.updated_at,
        current.status, current.goal, current.agent_privileges, current.workflow_definition,
        current.allow_agent_to_request_user, current.pre_approved_agent_privileges, current.image,
        current.environment, current.namespace_id, current.ai_catalog_item_version_id,
        current.issue_id, current.merge_request_id, current.service_account_id,
        current.tool_call_approvals, current.ai_catalog_item_id, current.traversal_path,
        current.messaging_callback_context, current.summary, current.title,
        current.incremental_checkpoints_enabled, current.agent_type, current.jsonl_sha256,
        current.idempotency_key, current.sync_type, current.agent_identity_id,
        current.web_search_enabled, current.trigger_source, current.trigger_flow_trigger_id,
        current.source_type, current.source_link, current.execution_mode, current.drop_reason,
        latest.credits_used, latest.model_used,
        current.source_merge_request_ids, current.created_merge_request_ids,
        current.later_closed_merge_request_ids, current.later_merged_merge_request_ids,
        current._siphon_deleted,
        current.prev_version + toIntervalMicrosecond(1) AS _version,
        current._watermark
      FROM current
      INNER JOIN latest ON latest.workflow_id = current.id
      -- The MV takes both from one enrichment row, so a missed row can leave either stale.
      WHERE current.credits_used != latest.credits_used OR current.model_used != latest.model_used
    SQL
  end
end
