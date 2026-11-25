---
title: Swift対応と実行環境タグを備えた依存関係スキャンの自動修正
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: software_supply_chain_security
documentation_link: "../../../user/application_security/remediate/dependency_scanning_auto_remediation/"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/19244
categories: [ Software Composition Analysis ]
level: secondary
---

依存関係スキャンの自動修正は、脆弱な依存関係のバージョンを更新するマージリクエストを自動で作成します。これまでは、Swiftプロジェクトがサポートされておらず、ジョブはタグなしのRunnerでのみ実行されていました。また、マージリクエストはランダムなメンテナーに割り当てられ、各プロジェクトで同時にオープンできるマージリクエストは最大10件に制限されていました。

GitLab 19.6では以下の改善が行われました。

- コミット済みの`Package.resolved`ファイルを持つSwift Package Managerプロジェクトで、自動修正マージリクエストが作成されるようになりました。
- 自動修正プロファイルにRunnerタグを設定でき、ジョブは一致するRunnerで実行されます。
- 自動レビュアー割り当てが有効な場合、更新されたファイルのコードオーナーがレビュアーとしてリクエストされます。無効な場合、GitLabはレビュアーを割り当てません。
- 各プロジェクトで最大30件の自動修正マージリクエストを同時にオープンできるようになりました。
- リポジトリがConventional Commitsに従っている場合、タイトルとコミットメッセージもそれに準拠します。

詳細については、[依存関係スキャンの自動修正](../../../user/application_security/remediate/dependency_scanning_auto_remediation.md)を参照してください。
