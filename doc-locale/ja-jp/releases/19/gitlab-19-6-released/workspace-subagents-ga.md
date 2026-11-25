---
title: ワークスペースサブエージェントが一般提供になりました
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: agent_foundations
documentation_link: "../../../user/duo_agent_platform/customize/workspace_subagents/"
work_item: https://gitlab.com/groups/gitlab-org/modelops/applied-ml/code-suggestions/-/work_items/75
categories: [ Duo Developer, Flow Components ]
level: secondary
weight: 50
---

ワークスペースサブエージェントは、実験的機能としてリリースされていましたが、一般提供になりました。

ワークスペースサブエージェントを使用すると、Linterの出力などのタスクの詳細をDeveloper Flowのコンテキストから切り離すことができます。
また、独自の指示と限定されたツールを持つ別のエージェントとして使用することも可能です。

サブエージェントは、リポジトリのルートにある `.agents/agents/` ディレクトリ内のMarkdownファイルとして定義します。
Developer Flowはいずれかのサブエージェントにタスクを委任するタイミングを判断し、結果のみを受け取ります。

GitLab Duo CLI 10.2.0以降では、`/agents` を使用してサブエージェントを一覧表示し、Developer Flowに特定のサブエージェントを使用するよう指示できます。
イシューやマージリクエストのコメントでDeveloper Flowをメンションし、サブエージェントの一覧表示や特定のサブエージェントへのタスク委任を依頼することもできます。
