---
title: MCPサーバーツール呼び出しの監査イベント
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated, gitlab_dedicated_for_government ]
stage: software_supply_chain_security
documentation_link: "../../../user/ai-governance/ai-audit-events/#audit-events-for-the-gitlab-mcp-server"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/22496
categories: [ AI Governance ]
level: primary
weight: 50
---

エージェントがGitLab MCPサーバーを通じて実行するすべてのアクションに対して、監査イベントが作成されるようになりました。クライアント側のトラッキングを追加することなく、エージェントのアクティビティの記録を取得できます。

各イベントには、アクションを実行したユーザー、実行した内容、影響を受けたリソース、および実行日時が記録されます。また、イベントにはMCPサーバーからのアクションであることが示されるため、エージェントのアクションと人が直接実行したアクションを区別できます。

これらのイベントを確認するには、トップレベルグループで **AI** > **Governance** に移動し、**Audit events** タブを選択します。セキュリティおよびコンプライアンスチームは、外部エージェントがGitLabで行う操作の完全なビューを取得できます。
