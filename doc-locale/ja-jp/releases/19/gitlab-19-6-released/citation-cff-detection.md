---
title: CITATION.cffファイルの検出
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: create
documentation_link: "../../../user/project/repository/"
work_item: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/254371
categories: [ Source Code Management ]
co_create: true
level: secondary
weight: 100
---

GitLabはリポジトリ内の`CITATION.cff`ファイルを検出するようになりました。
`CITATION.cff`ファイルが存在するプロジェクトでは、プロジェクトの概要にそのファイルへのリンクが表示されます。
ファイルが存在しないプロジェクトでは、`CITATION.cff`ファイルを追加するオプションが表示されます。
`CITATION.cff`はソフトウェアの引用方法を記述するオープンなファイル形式です。

この貢献をしてくださった[rajasekhar](https://gitlab.com/rajasekharponakala)さんに感謝します
（[MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/254371)）！
