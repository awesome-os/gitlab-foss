---
title: "セルフホストモデルでコンテキストとして画像を提供する"
tier: [ Premium, Ultimate ]
offering: [ self_managed, gitlab_dedicated_for_government ]
stage: agent_foundations
documentation_link: "../../../administration/gitlab_duo_self_hosted/configure_duo_features/#declare-image-support-for-a-self-hosted-model"
work_item: https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/work_items/3335
categories: [ Duo Developer ]
level: secondary
weight: 50
---

以前のバージョンのGitLabでは、Developer FlowとAgentic Chatはセルフホストモデルでのコンテキストとして画像をサポートしていませんでした。

今回のリリースで、リポジトリ内のスクリーンショットや図、および添付ファイルを、画像入力をサポートする任意のセルフホストモデルで読み取れるようになりました。

モデルが画像を読み取れない場合、管理者はAIゲートウェイのモデルメタデータファイルでその旨を宣言できます。AIゲートウェイはリクエストを送信する前に、各画像をテキスト通知に置き換えます。
