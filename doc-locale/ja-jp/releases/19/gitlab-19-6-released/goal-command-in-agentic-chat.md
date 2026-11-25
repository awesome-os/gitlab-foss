---
title: "GitLab Duo Agentic Chatの`/goal`コマンド"
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: ai_clients
documentation_link: "../../../user/gitlab_duo_chat/agentic_chat/#start-a-long-running-task-with-the-goal-command"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23107
categories: [ Web Chat ]
level: secondary
weight: 50
---

以前は、GitLab UIのGitLab Duo Agentic Chatは1回のメッセージに対して1つずつ回答し、次の入力を待つ仕様でした。
失敗しているテストのセットを修正するといった大きな変更を行う場合は、都度プロンプトを入力し続ける必要がありました。

`/goal`を使用することで、長時間実行タスクを開始できるようになりました。
Agentic Chatはタスクが完了するまで継続して動作するDeveloper Flowセッションを開始するため、各ステップ後にプロンプトを入力する必要はありません。

このフローは、各アクションの承認を求めることなく、コミット、プッシュ、マージリクエストの作成を行えます。
各ゴールにはコンピューティング時間も消費されます。

`/goal`を使用するには、プロジェクトでAgentic Chatを開き、トップレベルグループのDeveloper Flowを有効にしてください。
