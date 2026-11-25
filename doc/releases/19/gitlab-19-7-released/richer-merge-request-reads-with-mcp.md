---
title: Richer merge request reads with MCP
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: agent_foundations
documentation_link: "../../../user/model_context_protocol/mcp_server_tools/"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/639870
categories: [ Agent Tools ]
co_create: true
weight: 50
---

In previous versions of GitLab, `list_merge_requests` returned only basic details such as title, state, and branch names, with no reviewers, labels, draft status, or timestamps, and `get_merge_request` didn't return reviewers, labels, or merge status either. A community-contribution tracker listing merge requests with no reviewer had to fall back to extra API calls to get that detail.

Now [`get_merge_request`](../../../user/model_context_protocol/mcp_server_tools.md#get_merge_request) returns reviewers, labels, and detailed merge status, and [`list_merge_requests`](../../../user/model_context_protocol/mcp_server_tools.md#list_merge_requests) returns reviewers, labels, draft status, and timestamps. You can also filter `list_merge_requests` to find merge requests with no reviewer assigned.

Thank you to [Aryan Rajput](https://gitlab.com/aryan105825) for this contribution!
