---
title: Advanced SASTによるRust言語サポート
tier: [ Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated ]
stage: application_security_testing
documentation_link: "../../../user/application_security/sast/advanced_sast_ext/"
work_item: https://gitlab.com/groups/gitlab-org/-/work_items/23728
categories: [ SAST ]
level: secondary
---

以前は、GitLab SASTにRustのカバレッジがなかったため、Rustコードの脆弱性がパイプラインで検出されませんでした。

GitLab Advanced SASTがRustコードのスキャンに対応しました。GitLab Advanced SASTを有効にすると、リポジトリ内のRustコードが追加設定なしで自動的に解析されます。インクリメンタルスキャンがデフォルトで有効になっているため、パイプライン間で変更されたコードのみが再解析されます。

Advanced SASTは、関数やファイルをまたいで信頼されていない入力を追跡します。SQLインジェクション、コマンドインジェクション、パストラバーサルなどの検出結果には、ソースからシンクまでのコードフローが含まれます。対象となる脆弱性タイプについては、[追加言語のCWEカバレッジ](../../../user/application_security/sast/advanced_sast_coverage.md#additional-languages-cwe-coverage)を参照してください。

Rust解析はGitLab 19.5で追加され、現在ベータ版です。
