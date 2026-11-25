---
title: Jira Cloudドメインアクセスの制限
tier: [ Free, Premium, Ultimate ]
offering: [ self_managed ]
stage: plan
documentation_link: "../../../administration/settings/jira_cloud_app/#restrict-jira-domains-that-can-install-the-app"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/256324
categories: [ Team Planning ]
co_create: true
level: secondary
weight: 30
---

管理者は、GitLab for Jira Cloudアプリに対してドメインの許可リストを設定できるようになりました。
許可リストに登録されていないJiraサイトはアプリをインストールできません。また、該当サイトではアプリのアップグレードや再インストールも失敗するため、許可リストを保存する前に、既に接続済みのすべてのJiraサイトを追加してください。許可リストが空の場合はすべてのドメインが許可され、従来の動作が維持されます。許可リストはアプリのConnect版にのみ適用され、Forge版には適用されません。

この貢献をしてくださった[Roger Meier](https://gitlab.com/bufferoverflow)さんに感謝します
（[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/256324)）！
