---
title: GitLabクレジットダッシュボードにおける非課金対象の使用量
tier: [ Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: fulfillment
documentation_link: "../../../subscriptions/gitlab_credits_dashboard/#non-billable-usage"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/633154
categories: [ Consumables Cost Management ]
level: secondary
---

GitLabクレジットダッシュボードのサマリーカードとチャートには、プロモーションによってカバーされる使用量など、非課金対象の使用量が含まれるようになりました。
以前は、ユーザー別および製品別の内訳が課金対象の使用量のみを集計していたため、合計値と一致しないことがありました。
また、非課金対象の使用量のみのユーザーはユーザーリストに表示されていませんでした。

GitLabは以下の箇所で非課金対象の使用量を集計するようになりました。

- **ユーザー別使用量**タブおよび**製品別使用量**タブ。
- ユーザードリルダウン（各非課金対象イベントにバッジでその理由が表示されます）。
- GitLab.com上の個人用GitLabクレジット使用量ページ。
