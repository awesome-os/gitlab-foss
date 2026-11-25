---
title: GitLab Duoが承認または変更リクエストを行う（ベータ版）
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: ai_coding
documentation_link: "../../../user/duo_agent_platform/flows/foundational_flows/code_review/#approvals-and-change-requests"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23854
categories: [ DAP Code Review ]
level: secondary
---

以前のバージョンのGitLabでは、コードレビューフローはコメントを残すことしかできませんでした。
マージの承認やブロックは行えませんでした。

今回のリリースで、GitLab Duoはレビュー結果に基づいて承認または変更リクエストを行えるようになりました。

- コメントすべき内容がない場合、GitLab Duoはマージリクエストを承認します。
  この承認は、必須承認数にはカウントされません。
- コメントすべき内容がある場合、GitLab Duoは変更をリクエストします。
  プロジェクトで変更リクエスト時のマージブロックが有効になっている場合、GitLab Duoからのリクエストもマージをブロックします。
  リクエストは、GitLab Duoがフォローアップレビューで承認するか、ユーザーがバイパスするまで有効のままとなります。

この機能を使用するには、[実験的機能とベータ版機能を有効にし](../../../user/duo_agent_platform/turn_on_off.md#turn-on-beta-and-experimental-features)、
プロジェクト、グループ、またはインスタンスで**GitLab Duoが承認および変更リクエストを行える**設定をオンにしてください。
