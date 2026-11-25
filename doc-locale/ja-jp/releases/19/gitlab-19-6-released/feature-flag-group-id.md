---
title: 機能フラグのロールアウト戦略におけるグループID
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: deploy
documentation_link: "../../../operations/feature_flags/#percent-rollout"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/263973
categories: [ Feature Flags ]
co_create: true
level: secondary
weight: 50
---

パーセントロールアウトおよびパーセント・オブ・ユーザー機能フラグ戦略で、カスタムグループIDを指定できるようになりました。
同じグループIDとスティッキネス値を共有する複数のフラグにまたがる戦略は、同じ割合で同じユーザーセットを選択するため、複数のフラグにわたるロールアウトを連携させることができます。
グループIDを変更することで、独立したユーザーセットを対象にすることも可能です。

このコントリビューションを提供してくださった[Mehdi Youb](https://gitlab.com/myoub)さんに感謝します
([MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/263973))！
