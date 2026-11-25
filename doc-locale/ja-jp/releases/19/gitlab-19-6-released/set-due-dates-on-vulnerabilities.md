---
title: 脆弱性の詳細ページで期日を設定する
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: security_risk_management
documentation_link: "../../../user/application_security/vulnerabilities/#set-a-due-date-for-a-vulnerability"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/638884
categories: [ Vulnerability Management ]
level: secondary
---

以前のバージョンのGitLabでは、脆弱性の期日はGraphQL APIを通じてのみ設定・確認できました。

今回のリリースで、脆弱性の詳細ページから期日を確認・設定できるようになりました。
脆弱性のステータスが**トリアージが必要**または**確認済み**の場合、GitLabは日付に次のラベルを表示します。

- **期限超過**: 期日が過ぎた場合。
- **期限間近**: 期日が7日以内の場合。
