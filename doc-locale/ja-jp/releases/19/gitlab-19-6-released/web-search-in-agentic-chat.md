---
title: GitLab Duo Agentic ChatのWebサーチ
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: ai_clients
documentation_link: "../../../user/gitlab_duo_chat/agentic_chat/#web-search"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/20480
categories: [ Web Chat ]
level: secondary
weight: 50
---

以前は、GitLab Duo Agentic Chatで最新情報を検索することができませんでした。
回答はモデルのトレーニングデータとGitLabのコンテキストのみに基づいており、
最新のパッケージバージョンやセキュリティアドバイザリに関する回答が古くなっている場合がありました。

今回のリリースで、会話内でWebサーチを有効にできるようになりました。
Chatがウェブを検索してページを読み込み、最新の回答を見つけるため、GitLabを離れる必要がありません。
会話内の各検索を展開すると、見つかったページを確認できます。
また、各検索では監査イベントも作成されます。

Webサーチはデフォルトで無効になっています。
GitLab.comでは、グループのオーナーがトップレベルグループに対して許可する必要があります。
GitLab Self-ManagedおよびGitLab Dedicatedでは、管理者がインスタンスに対して許可する必要があります。
