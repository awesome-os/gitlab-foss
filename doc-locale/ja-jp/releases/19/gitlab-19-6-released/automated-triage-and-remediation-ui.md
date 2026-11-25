---
title: 自動トリアージおよび修正プロファイル（UI）
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: security_risk_management
documentation_link: "../../../user/application_security/configuration/security_configuration_profiles/#automated-triage-and-remediation-profile"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23192
categories: [ Vulnerability Management, Security Testing Configuration ]
weight: 50
---

グループ全体でスキャナーを有効にするのと同じ方法で、セキュリティフローを有効にできるようになりました。セキュリティインベントリまたはセキュリティ設定の新しい**自動トリアージおよび修正**タブから、[自動トリアージおよび修正プロファイル](../../../user/application_security/configuration/security_configuration_profiles.md#automated-triage-and-remediation-profile)を適用できます。このプロファイルを適用すると、選択したプロジェクトに対してSAST、シークレット検出、および依存関係スキャンのフローが有効になります。

以前は、このプロファイルはGraphQL APIからのみ利用可能でした。現在は、プリセットを選択して1つの操作で適用できます。ほとんどのフローで以下のプリセットが利用できます。

- 保守的: オンデマンド、高重大度以上。
- 標準（推奨）: 自動、中重大度以上。
- 積極的: 自動、すべての重大度。事前にクレジットの使用状況を確認してください。

セキュリティインベントリの新しい**機能**列には、スキャンが実行される場所の隣に、フローが実行される場所が表示されます。
