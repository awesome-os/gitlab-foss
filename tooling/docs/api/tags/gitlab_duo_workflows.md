---
name: GitLab Duo workflows
external_docs: https://docs.gitlab.com/api/duo_agent_platform_flows/
---
Use this API to create and manage [flows](../../../../doc/user/duo_agent_platform/flows/_index.md) in the
[GitLab Duo Agent Platform](../../../../doc/user/duo_agent_platform/_index.md).
Flows are combinations of AI agents that work together to complete developer tasks,
such as fixing bugs, writing code, or resolving vulnerabilities.

To get an `ai_catalog_item_consumer_id`, use the GraphQL API to retrieve the ID from the AI Catalog.
The item must already be enabled for the project:

```graphql
query {
  aiCatalogConfiguredItems(projectId: "gid://gitlab/Project/<project_id>") {
    nodes {
      id
      item { name }
    }
  }
}
```

The `id` field is a Global ID in the format `gid://gitlab/AiCatalogItemConsumer/<numeric_id>`.
Use the numeric suffix as the `ai_catalog_item_consumer_id` value.

To check the status of a flow after you create it, use the `duoWorkflowWorkflows` GraphQL query,
where `<flow_id>` is the `id` from the create response:

```graphql
query {
  duoWorkflowWorkflows(workflowId: "gid://gitlab/Ai::DuoWorkflows::Workflow/<flow_id>") {
    nodes {
      status
      webUrl
    }
  }
}
```

When the flow ends, `status` is `FINISHED`, `FAILED`, or `STOPPED`. The statuses `PAUSED`,
`INPUT_REQUIRED`, `PLAN_APPROVAL_REQUIRED`, and `TOOL_CALL_APPROVAL_REQUIRED` mean that the flow is
waiting for a user.
