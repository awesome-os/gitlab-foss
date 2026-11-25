---
title: その他の改善
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: create
documentation_link: "../../../user/project/merge_requests/"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/262477
categories: [ Source Code Management ]
co_create: true
level: secondary
weight: 110
---

コミュニティコントリビューターによる主な改善点は以下のとおりです。

- マージウィジェットで、マージ処理中に失敗したチェックが一瞬表示される問題が修正されました。（[Aleksandr Kotlyar](https://gitlab.com/aleksandr-kotlyar)、[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/266893)）
- 複数回引用された脚注のリンクがすべて正しく機能するようになりました。（[José M. Requena Plens](https://gitlab.com/jmrp)、[MR 1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/265760) [MR 2](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/265411)）
- ユーザープロフィールの「スター付き」タブにページネーションが追加されました。（[Radek Antoniuk](https://gitlab.com/rantoniuk)、[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/261375)）
- `needs:` 依存関係を持つジョブが、パイプライン依存関係ビューの正しい列に表示されるようになりました。（[iDang3r](https://gitlab.com/iDang3r)、[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/262477)）
- グループのサブプロジェクトおよびメンバーリストに、有効なロールが表示されるようになりました。（[Gerardo Navarro](https://gitlab.com/gerardo-navarro)、[MR 1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/256522) [MR 2](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/256559)）
- 依存プロキシが、Docker Hubの障害発生時にキャッシュ済みイメージへのフォールバックを行うようになりました。（[Tri Lam](https://gitlab.com/trilamsr)、[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/254559)）
- キャッシュ済みの依存プロキシのblobが、アップストリームトークンを要求せずに提供されるようになりました。（[Thota Shashank](https://gitlab.com/thotashashank302)、[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/264118)）
- Telegram通知で、プロジェクトタイトルとブランチ名がHTMLエスケープされるようになりました。（[kuttLoggin](https://gitlab.com/kuttLoggin)、[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/261103)）
