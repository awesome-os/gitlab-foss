---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Limites de débit de GitLab Pages
description: Configurez les limites de débit pour les requêtes GitLab Pages et les connexions TLS par adresse IP ou domaine.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

{{< history >}}

- [Modifié](https://gitlab.com/groups/gitlab-org/-/work_items/14653) dans GitLab 17.3 : vous pouvez exclure des sous-réseaux des limites de débit de Pages.

{{< /history >}}

Vous pouvez appliquer des limites de débit pour minimiser le risque d'une attaque par déni de service (DoS). GitLab Pages utilise un algorithme de seau à jetons pour appliquer la limitation de débit. Par défaut, les requêtes ou connexions TLS dépassant les limites spécifiées sont signalées et rejetées.

GitLab Pages prend en charge les types de limitation de débit suivants :

- Pour chaque `source_ip` : limite les requêtes ou les connexions TLS provenant d'une seule adresse IP cliente.
- Pour chaque `domain` : limite les requêtes ou les connexions TLS par domaine hébergé sur GitLab Pages. Il peut s'agir d'un domaine personnalisé comme `example.com`, ou d'un domaine de groupe comme `group.gitlab.io`.

Les limites de débit basées sur les requêtes HTTP sont appliquées à l'aide des paramètres suivants :

- `rate_limit_source_ip` : nombre maximal de requêtes par IP cliente par seconde. Définissez la valeur sur `0` pour désactiver.
- `rate_limit_source_ip_burst` : nombre maximal de requêtes autorisées dans une salve initiale par IP cliente, par exemple lorsqu'une page charge plusieurs ressources simultanément.
- `rate_limit_domain` : nombre maximal de requêtes par domaine Pages hébergé par seconde. Définissez la valeur sur `0` pour désactiver.
- `rate_limit_domain_burst` : nombre maximal de requêtes autorisées dans une salve initiale par domaine Pages hébergé.

Les limites de débit basées sur les connexions TLS sont appliquées à l'aide des paramètres suivants :

- `rate_limit_tls_source_ip` : nombre maximal de connexions TLS par IP cliente par seconde. Définissez la valeur sur `0` pour désactiver.
- `rate_limit_tls_source_ip_burst` : nombre maximal de connexions TLS autorisées dans une salve initiale par IP cliente.
- `rate_limit_tls_domain` : nombre maximal de connexions TLS par domaine Pages hébergé par seconde. Définissez la valeur sur `0` pour désactiver.
- `rate_limit_tls_domain_burst` : nombre maximal de connexions TLS autorisées dans une salve initiale par domaine Pages hébergé.

Pour autoriser certaines plages IP (sous-réseaux) à contourner toutes les limites de débit, utilisez `rate_limit_subnets_allow_list`. Par exemple, `['1.2.3.4/24', '2001:db8::1/32']`. Un [exemple de chart GitLab Pages](https://docs.gitlab.com/charts/charts/gitlab/gitlab-pages/#configure-rate-limits-subnets-allow-list) est disponible.

Si l'adresse IP du client est en IPv6, la limite est appliquée au préfixe IPv6 d'une longueur de 64, plutôt qu'à l'adresse entière.

## Activer les limites de débit des requêtes HTTP par IP source {#enable-http-requests-rate-limits-by-source-ip}

Pour définir des limites de débit dans `/etc/gitlab/gitlab.rb` :

1. Ajoutez ce qui suit :

   ```ruby
   gitlab_pages['rate_limit_source_ip'] = 20.0
   gitlab_pages['rate_limit_source_ip_burst'] = 600
   ```

1. Enregistrez le fichier et [reconfigurez GitLab](../restart_gitlab.md#reconfigure-a-linux-package-installation) pour que les modifications prennent effet.

## Activer les limites de débit des requêtes HTTP par domaine {#enable-http-requests-rate-limits-by-domain}

Pour définir des limites de débit dans `/etc/gitlab/gitlab.rb` :

1. Ajoutez :

   ```ruby
   gitlab_pages['rate_limit_domain'] = 1000
   gitlab_pages['rate_limit_domain_burst'] = 5000
   ```

1. Enregistrez le fichier et [reconfigurez GitLab](../restart_gitlab.md#reconfigure-a-linux-package-installation) pour que les modifications prennent effet.

## Activer les limites de débit des connexions TLS par IP source {#enable-tls-connections-rate-limits-by-source-ip}

Pour définir des limites de débit dans `/etc/gitlab/gitlab.rb` :

1. Ajoutez :

   ```ruby
   gitlab_pages['rate_limit_tls_source_ip'] = 20.0
   gitlab_pages['rate_limit_tls_source_ip_burst'] = 600
   ```

1. Enregistrez le fichier et [reconfigurez GitLab](../restart_gitlab.md#reconfigure-a-linux-package-installation) pour que les modifications prennent effet.

## Activer les limites de débit des connexions TLS par domaine {#enable-tls-connections-rate-limits-by-domain}

Pour définir des limites de débit dans `/etc/gitlab/gitlab.rb` :

1. Ajoutez :

   ```ruby
   gitlab_pages['rate_limit_tls_domain'] = 1000
   gitlab_pages['rate_limit_tls_domain_burst'] = 5000
   ```

1. Enregistrez le fichier et [reconfigurez GitLab](../restart_gitlab.md#reconfigure-a-linux-package-installation) pour que les modifications prennent effet.

## Sujets connexes {#related-topics}

- [Administration de GitLab Pages](_index.md)
- [Limites de fréquence](../../rate_limits/_index.md)
