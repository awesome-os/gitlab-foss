---
title: GitLab Self-ManagedおよびGitLab DedicatedにおけるBusiness Logic Security Analyzer
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: application_security_testing
documentation_link: "../../../user/application_security/business_logic_scanning/"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23435
categories: [ SAST ]
level: secondary
---

Business Logic Security AnalyzerはGitLab Duo Agent Platformのフローで、コードが何を強制するよう設計されているかを推論します。パターンベースのスキャナーが見逃す脆弱性を検出します。

- オブジェクトレベルの認可の不備。
- 認可チェックの欠如。
- マスアサインメント。

検出結果は脆弱性レポートとマージリクエストのセキュリティウィジェットに表示されます。

これまで、Business Logic Security AnalyzerはGitLab.comでのみ利用可能でした。コードの解析場所に最も厳格な要件を持つことが多いGitLab Self-ManagedおよびGitLab Dedicatedを利用する組織は、使用できませんでした。

現在は両方で動作します。

- GitLab Dedicatedでは、スキャンはGitLabがホストするRunnerで実行されます。
- GitLab Self-Managedでは、スキャンはお客様のRunnerで実行されます。

利用を開始するには、担当のアカウントチームにお問い合わせください。

各スキャンはGitLabクレジットを消費します。セットアップについては、[ビジネスロジックスキャン](../../../user/application_security/business_logic_scanning/_index.md)を参照してください。
