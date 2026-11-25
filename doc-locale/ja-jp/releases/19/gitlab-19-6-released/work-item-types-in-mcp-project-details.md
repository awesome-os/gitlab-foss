---
title: MCPプロジェクト詳細における作業アイテムタイプ
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: agent_foundations
documentation_link: "../../../user/model_context_protocol/mcp_server_tools/#get_project"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/606643
categories: [ Agent Tools ]
co_create: true
weight: 50
---

以前のバージョンのGitLabでは、AIエージェントがプロジェクトでサポートされている作業アイテムタイプを取得するために、別途リクエストを送信する必要がありました。
今回のリリースで、[プロジェクト詳細](../../../user/model_context_protocol/mcp_server_tools.md#get_project)の取得と同じリクエストで、プロジェクトの作業アイテムタイプおよび各タイプがサポートするフィールドを取得できるようになりました。

このコントリビューションを提供してくださった[Aditya Parida](https://gitlab.com/adityaswarupparida)さんに感謝します！
