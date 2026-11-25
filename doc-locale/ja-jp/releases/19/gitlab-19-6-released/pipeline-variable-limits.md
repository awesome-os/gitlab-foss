---
title: パイプライン変数の設定可能な制限
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: verify
documentation_link: "../../../administration/cicd/limits/#limit-pipeline-variables"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/253433
categories: [ Pipeline Composition ]
level: secondary
weight: 50
---

管理者は、単一のパイプラインに存在できるパイプライン変数の数とサイズを制限できるようになりました。これにより、ユーザーが大量の大きなパイプライン変数をパイプラインに追加することを防ぎ、CI/CDインフラストラクチャの安定性を維持できます。

GitLab Self-ManagedおよびGitLab Dedicatedでは、制限はデフォルトで無効になっています。
GitLab.comの制限は次のとおりです。

- パイプラインあたり1,200変数
- 値あたり128 KiB
- ファイルタイプの値あたり1 MiB
