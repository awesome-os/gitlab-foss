---
title: クイックセットアップがスキャンプロファイルを適用する方法の制御
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: security_risk_management
documentation_link: "../../../user/application_security/configuration/scanner_enablement_wizard/#quick-setup"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23769
categories: [ Security Testing Configuration ]
weight: 50
---

スキャナー有効化ウィザードが[スキャンプロファイル](../../../user/application_security/configuration/security_configuration_profiles.md)をグループに適用する方法を選択できるようになりました。以前のクイックセットアップでは、すべてのプロジェクトにプロファイルが適用されていたため、CI/CD設定またはポリシーを通じてすでにスキャンを実行しているプロジェクトでは、スキャンが2回実行されていました。

クイックセットアップで適用方法を選択できるようになりました:

- **すべてのプロジェクト**: すべてのプロジェクトにプロファイルを適用し、そのスキャナーの既存のプロファイルを置き換えます。別の方法でスキャンしているプロジェクトでは、両方のスキャンが実行されます。
- **まだスキャンしていないプロジェクト**（推奨）: そのスキャナーのスキャンが設定されていないプロジェクトにプロファイルを適用します。すでにスキャンを実行しているプロジェクトは、現在の設定が維持されます。
- **既存のものを置き換える**: そのスキャナーのプロファイルがすでに設定されているプロジェクトに対して、新しいプロファイルに置き換えます。
