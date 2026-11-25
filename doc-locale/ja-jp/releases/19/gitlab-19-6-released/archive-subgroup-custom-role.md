---
title: サブグループのアーカイブカスタムロール権限
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: software_supply_chain_security
documentation_link: "../../../user/custom_roles/abilities/#groups-and-projects"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/257968
categories: [ Permissions ]
co_create: true
level: secondary
weight: 70
---

カスタムロールに`archive_subgroup`権限を追加できるようになりました。この権限を持つユーザーは、グループの削除権限も付与されるより広範なオーナーロールを必要とせずに、サブグループのアーカイブおよびアーカイブ解除を行えます。この権限は、カスタムロールエディタに**サブグループをアーカイブ**として表示されます。

この貢献をしてくださった[Jimmy Spagnola](https://gitlab.com/jspagnola)さんに感謝します
([MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/257968))！
