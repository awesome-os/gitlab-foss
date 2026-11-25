---
title: スケジュール型自動化（ベータ版）でルーティンワークを自動化する
tier: [ Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: ai_coding
documentation_link: "../../../user/duo_agent_platform/automations/#scheduled-automations"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/24075
categories: [ DAP Triggers ]
level: secondary
---

以前のバージョンのGitLabでは、フローはユーザーまたはイベントによって開始された場合にのみ実行されていました。そのため、イシューのトリアージなどのルーティンワークは、手動でのきっかけがなければ滞ってしまうことがありました。

スケジュール型自動化を使用すると、こうした作業に一定のリズムをもたせることができます。15分ごとから月次まで、実行間隔を一度設定するだけで、指定した時刻にフローが自動的に実行されます。毎朝新しいイシューをトリアージしたり、1時間ごとにパイプラインの状態を確認したりすることが可能です。

各スケジュール型自動化は、スコープ付きロールを持つ専用のサービスアカウントとして実行されるため、その操作は特定のユーザーではなくそのアカウントに帰属します。

なお、トリガーは「自動化」という名称に変更されました。刷新された**自動化**ページでは、スケジュール型自動化とイベントベースの自動化が一元管理され、実行履歴、成功率、セッションの詳細を確認できます。

試してみるには、[実験的機能およびベータ版機能を有効にする](../../../user/duo_agent_platform/turn_on_off.md#turn-on-beta-and-experimental-features)を参照してください。
