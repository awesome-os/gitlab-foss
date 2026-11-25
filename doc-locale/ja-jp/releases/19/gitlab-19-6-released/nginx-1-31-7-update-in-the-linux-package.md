---
title: LinuxパッケージのNGINXが1.31.7に更新されました
stage: gitlab_delivery
level: secondary
tier: [ Free, Premium, Ultimate ]
offering: [ self_managed ]
documentation_link: "../../../update/versions/gitlab_19_changes/#nginx-update-might-break-custom-nginx-configuration"
work_item: "https://gitlab.com/gitlab-org/omnibus-gitlab/-/work_items/10147"
categories: [ Omnibus Package ]
weight: 10
---

GitLab 19.6では、LinuxパッケージにバンドルされているNGINXのバージョンが1.31.4から1.31.7に更新されます。
この更新により、CVE-2026-15176、CVE-2026-93479、CVE-2026-95101、CVE-2026-97629、CVE-2026-97205の5件のセキュリティ問題が修正されます。

Linuxパッケージが生成する設定への影響はありません。カスタムNGINX設定を追加している場合、アップストリームの2つの変更により動作しなくなる可能性があります。

- ゼロサイズのバッファ設定が拒否されるようになりました。
- IPアドレスの証明書検証が、IPサブジェクト代替名のみに一致するようになりました。

アップグレードの前に、カスタム設定を確認してください。詳細については、[アップグレードノート](../../../update/versions/gitlab_19_changes.md#nginx-update-might-break-custom-nginx-configuration)を参照してください。
