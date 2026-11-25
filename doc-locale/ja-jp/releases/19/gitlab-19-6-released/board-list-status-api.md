---
title: REST APIにおけるステータスベースのボードリスト
tier: [ Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: plan
documentation_link: "../../../api/boards/#create-a-board-list"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/260752
categories: [ Planning Views ]
co_create: true
level: secondary
weight: 80
---

ボードリストのREST APIエンドポイントで`status_id`パラメーターが使用できるようになりました。これにより、カスタムステータスでイシューをフィルタリングするボード列を作成できます。APIレスポンスにはステータスオブジェクト全体が含まれるため、自動化処理で設定したステータスを読み取ることができます。
以前のバージョンのGitLabでは、ステータスベースのリストをREST APIで作成することはできませんでした。

このコントリビューションを提供してくださった[Daniel Ziegenberg](https://gitlab.com/ziegenberg)さんに感謝します
（[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/260752)）。
