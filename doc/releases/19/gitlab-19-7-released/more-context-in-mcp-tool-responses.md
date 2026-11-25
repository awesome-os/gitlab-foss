---
title: More context in MCP tool responses
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: agent_foundations
documentation_link: "../../../user/model_context_protocol/mcp_server_tools/"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/640194
categories: [ Agent Tools ]
weight: 60
---

In previous versions of GitLab, four MCP server tools left out context that an agent needed. Now they return it:

- [`get_vulnerability`](../../../user/model_context_protocol/mcp_server_tools.md#get_vulnerability) (GitLab Ultimate) now returns the dismissal reason, the state comment, and the users who confirmed or dismissed a vulnerability, so an agent can tell a false positive from an accepted risk.
- [`get_duo_session`](../../../user/model_context_protocol/mcp_server_tools.md#get_duo_session) and [`list_duo_sessions`](../../../user/model_context_protocol/mcp_server_tools.md#list_duo_sessions) now return the merge request or work item a session started from, so an agent doesn't have to parse its free-text goal.
- [`list_duo_agents_and_flows`](../../../user/model_context_protocol/mcp_server_tools.md#list_duo_agents_and_flows) can now include each flow's triggers, so an agent can check whether a flow already fires on an event before starting a duplicate session by hand.
