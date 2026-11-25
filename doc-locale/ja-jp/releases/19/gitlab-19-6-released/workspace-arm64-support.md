---
title: WorkspacesがARM64 Kubernetesクラスターをサポート
tier: [ Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: create
documentation_link: "../../../user/workspace/configuration/#platform-compatibility"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/264361
categories: [ Workspaces ]
co_create: true
level: secondary
weight: 60
---

GitLab Workspacesが`linux/arm64` Kubernetesノードでネイティブイメージをサポートするようになりました。Apple Mシリーズハードウェアも対象です。これまで、arm64ノードではエミュレーション下でamd64イメージが実行されていました。GitLabは各ノードに適したイメージバリアントを自動的に取得します。
カスタムdevfileイメージは、ワークスペースが実行されるノードのアーキテクチャをサポートしている必要があります。

このコントリビューションを提供してくださった[Miguel Sacristan](https://gitlab.com/miguel.sacristan1)さんに感謝します
（[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/264361)）！
