---
title: Rapid Diffsで高速にマージリクエストをレビューする
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: ai_coding
documentation_link: "../../../user/project/merge_requests/changes/#rapid-diffs"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/19380
categories: [ Code Review Workflow ]
level: primary
---

以前のバージョンのGitLabでは、小さなマージリクエストでも最初の差分が読み込まれるまで待つ必要がありました。
大きなマージリクエストの場合は、ページの動作が遅くなったりフリーズしたりすることもありました。

Rapid Diffsは、GitLabが差分をレンダリングする仕組みをゼロから書き直したもので、一般提供が開始され、
従来の差分ビューに置き換わりました。
GitLabはサーバー上で差分をレンダリングしてブラウザにストリーミングするため、レビューを数秒で開始できます。

- 最初のファイルは約1.5秒で表示されます（従来の約4.5秒から短縮）。
- Webブラウザの検索（<kbd>Control</kbd>+<kbd>F</kbd>または<kbd>Command</kbd>+<kbd>F</kbd>）がページをフリーズさせることなく即座に機能します。

Rapid Diffsは、既存のレビューツールもサポートしています。

- ファイルごとのモード
- 確認済みとしてマーク
- ファイル全体の表示
- コミットごとのナビゲーション
- キーボードショートカット
- 画像コメント
