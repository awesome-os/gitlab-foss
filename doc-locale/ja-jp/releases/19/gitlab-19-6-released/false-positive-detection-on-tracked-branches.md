---
title: 追跡ブランチでの自動誤検出判定
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: security_risk_management
documentation_link: "../../../user/application_security/vulnerabilities/false_positive_detection/#tracked-branches-and-tags"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23511
categories: [ Vulnerability Management ]
level: secondary
---

以前のバージョンのGitLabでは、誤検出判定はデフォルトブランチの脆弱性に対してのみ自動実行されていました。リリースブランチやタグで検出された結果は、手動でトリアージする必要がありました。

今回のリリースで、SAST誤検出判定フローが追跡ブランチ上の新しいCriticalおよびHighの脆弱性、およびSASTジョブを実行する追跡タグに対して自動実行されるようになりました。これにより、マージやリリース前にノイズを除去できます。この機能は、プロジェクト設定で誤検出判定を有効にするか、自動実行に設定した[自動トリアージおよび修正プロファイル](../../../user/application_security/configuration/security_configuration_profiles.md#automated-triage-and-remediation-profile)を使用することで動作します。

追跡ブランチおよびタグでの[シークレット誤検出判定](../../../user/application_security/vulnerabilities/secret_false_positive_detection.md#tracked-branches-and-tags)は、今回のリリースでGitLab.comにて利用可能になりました。
