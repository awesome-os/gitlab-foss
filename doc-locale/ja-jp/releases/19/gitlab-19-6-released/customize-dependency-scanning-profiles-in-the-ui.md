---
title: UIで依存関係スキャンプロファイルをカスタマイズ
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: security_risk_management
documentation_link: "../../../user/application_security/configuration/security_configuration_profiles/"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/20200
categories: [ Security Testing Configuration ]
weight: 50
---

シークレット検出やSASTプロファイルと同様に、UIで依存関係スキャンプロファイルを作成・カスタマイズできるようになりました。グループに対して依存関係スキャンの実行方法を一度設定すれば、各プロジェクトの`.gitlab-ci.yml`を編集することなく、すべてのプロジェクトに適用できます。

以前は、依存関係スキャンプロファイルのカスタマイズにはGraphQL APIを使用する必要がありました。現在は、**セキュア** > **セキュリティ設定**に移動し、**スキャナー**タブを選択して、依存関係スキャンの行にある**プロファイルを管理**を選択するだけで設定できます。スキャンをマージリクエストパイプライン、デフォルトブランチパイプライン、またはその両方で実行するかどうかを選択し、除外するパスなど上書きする設定を追加します。

プロファイルは[セキュリティインベントリから](../../../user/application_security/configuration/security_configuration_profiles.md#apply-profiles-in-the-ui)、または[スキャナー有効化ウィザードの詳細設定](../../../user/application_security/configuration/scanner_enablement_wizard.md#advanced-setup)から適用できます。
