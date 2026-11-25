---
title: サンドボックスが利用できない場合にフローを失敗させる
tier: [ Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: agent_foundations
documentation_link: "../../../user/duo_agent_platform/environment_sandbox/#require-flows-to-run-in-the-sandbox"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/607753
categories: [ AI Agents ]
level: secondary
weight: 50
---

以前のバージョンのGitLabでは、Runner環境のGitLab Duo Agent Platformフローは、サンドボックスが利用できない場合でも分離なしで実行され、警告のみが表示されていました。
今回のリリースで、[サンドボックスなしでフローを実行する代わりにジョブを失敗させる](../../../user/duo_agent_platform/environment_sandbox.md#require-flows-to-run-in-the-sandbox)よう設定できるようになりました。
