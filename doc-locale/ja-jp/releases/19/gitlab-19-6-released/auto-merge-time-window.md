---
title: 自動マージの時間ウィンドウを設定する
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: create
documentation_link: "../../../user/project/merge_requests/auto_merge/#prevent-merge-outside-a-specific-time-period"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/258025
categories: [ Code Review Workflow ]
co_create: true
level: secondary
weight: 10
---

マージスケジュールに時間範囲を設定して、自動的にマージできるようになりました。
以前のバージョンのGitLabでは、マージスケジュールは**After**オプションのみをサポートしており、設定した日時より前のマージを防ぐことができました。
**Between**を選択して時間ウィンドウを定義できるようになりました。現在の時刻が設定した2つの日時の間にある場合にのみ、マージリクエストがマージされます。

これらの貢献をしてくださった[Niklas van Schrick](https://gitlab.com/Taucher2003)さんに感謝します
([MR 1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/258024)
[MR 2](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/258025)
[MR 3](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/262275))!
