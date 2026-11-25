---
title: セキュリティダッシュボードで平均修正時間を追跡する
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: security_risk_management
documentation_link: "../../../user/application_security/security_dashboard/#mttr-over-time"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/19830
categories: [ Vulnerability Management ]
level: secondary
---

以前のバージョンのGitLabでは、チームが脆弱性をどれだけ迅速に修正しているかを時系列で確認することができませんでした。

プロジェクト、グループ、および組織のセキュリティダッシュボードに、平均修正時間（MTTR）チャートが追加されました。
このチャートでは、過去12週間の週次MTTRと、各週に修正された脆弱性の件数を確認できます。
修正が遅れている箇所を特定するには、重大度またはレポートタイプでチャートをグループ化してください。
修正SLAと照らし合わせてトレンドを比較できます。

MTTRは、最近検出された脆弱性のうち、解決済みまたは検出されなくなったものを対象としています。
却下された脆弱性は除外されます。
