---
title: リファレンスリポジトリを使用してフローセッションをより速く開始する（ベータ版）
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: agent_foundations
documentation_link: "../../../user/duo_agent_platform/flows/execution/#start-sessions-from-a-reference-repository"
work_item: https://gitlab.com/gitlab-org/gitlab/-/work_items/633571
categories: [ Runner Execution ]
level: secondary
weight: 50
---

以前のバージョンのGitLabでは、フローセッションのたびにリポジトリ全体をクローンする必要があったため、大規模なプロジェクトではエージェントが起動するまでに数分かかることがありました。
GitLab Duo Agent Platformのセッションに使用するイメージにリポジトリのコピーを含めることで、各セッションは最新のコミットのみをフェッチするようになり、大幅に速く開始できます。
