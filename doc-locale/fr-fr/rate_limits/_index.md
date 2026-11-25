---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Protégez la stabilité et la sécurité de votre instance grâce aux limites de débit appliquées aux requêtes envoyées à GitLab.
title: Limites de fréquence
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!note]
> Pour GitLab.com, voir [les limites de débit spécifiques à GitLab.com](../user/gitlab_com/rate_limits.md#current-rate-limits).
>
> Pour GitLab Dedicated, voir [les limites de débit pour les utilisateurs authentifiés](../administration/dedicated/user_rate_limits.md).

La limitation de débit est une technique couramment utilisée pour améliorer la sécurité et la durabilité d'une application web.

Par exemple, un simple script peut effectuer des milliers de requêtes web par seconde. Ces requêtes peuvent être :

- Malveillantes.
- Apathiques.
- Simplement dues à un bug.

Votre application et votre infrastructure peuvent ne pas être en mesure de supporter la charge. Pour plus de détails, voir [Attaque par déni de service](https://en.wikipedia.org/wiki/Denial-of-service_attack). La plupart des cas peuvent être atténués en limitant le débit des requêtes provenant d'une seule adresse IP.

La plupart des [attaques par force brute](https://en.wikipedia.org/wiki/Brute-force_attack) sont également atténuées par une limite de débit.

> [!note]
> Les limites de débit pour les requêtes API n'affectent pas les requêtes effectuées par le frontend, car ces requêtes sont toujours comptabilisées comme du trafic web.

## Options de configuration {#configuration-options}

Vous pouvez définir la plupart des limites de débit dans la zone **Admin**. Certaines sont disponibles uniquement via l'API ou la console Rails, et vous définissez les limites de débit de GitLab Pages dans un fichier de configuration.

### Zone Admin {#admin-area}

Vous pouvez définir ces limites de débit dans la zone **Admin** de votre instance :

- [Limites de débit de l'API](api/_index.md)
- [Limites de débit pour la création de contenu](content_creation.md)
- [Limites de débit pour les opérations Git](git.md)
- [Limites de débit pour l'importation et l'exportation](../administration/settings/import_export_rate_limits.md)
- [Limites de débit pour la gestion des incidents](../administration/settings/incident_management_rate_limits.md)
- [Limites de débit pour la création de pipelines](../administration/cicd/limits.md#pipeline-creation-rate-limits)
- [Chemins protégés](../administration/settings/protected_paths.md)
- [Limites de débit pour les endpoints bruts](../administration/settings/rate_limits_on_raw_endpoints.md)
- [Limites de débit pour les utilisateurs et les adresses IP](../administration/settings/user_and_ip_rate_limits.md)
- [Limites de débit pour les opérations de webhook](../administration/settings/rate-limit-on-webhook-operations.md)

### API et console Rails {#api-and-rails-console}

Vous pouvez définir ces limites de débit avec l'[API des paramètres d'application](../api/settings.md) :

- [Limite de débit pour la saisie automatique des utilisateurs](../administration/instance_limits.md#autocomplete-users-rate-limit)
- [Action IA](../api/settings.md#available-settings) (`ai_action_api_rate_limit`) : 160 appels par tranche de 8 heures par utilisateur authentifié. S'applique à la mutation GraphQL `aiAction`.
- [Limite de débit pour la création de tags](../api/settings.md#available-settings) (`tags_create_limit`) : 100 requêtes par 30 minutes par projet. S'applique à l'endpoint de l'API REST pour la création d'un tag, à la mutation GraphQL `tagCreate`, à la création de tags dans l'interface utilisateur, et à l'action rapide `/tag`.
- [Limite de débit pour la récupération de l'historique de fichier](api/repository-files.md#configure-file-blame-rate-limits) (`project_repositories_blame_limit`, `project_repositories_blame_unauthenticated_limit`) : 400 requêtes par minute pour chaque utilisateur et projet. Les requêtes non authentifiées sont limitées à 400 requêtes par minute pour chaque adresse IP. S'applique à l'endpoint de l'API REST pour l'historique de fichier.

Vous pouvez définir cette limite de débit avec l'[API des limites de plan](../api/plan_limits.md) ou la [console Rails](../administration/operations/rails_console.md#starting-a-rails-console-session) :

- [Limite de débit pour les webhooks](../administration/instance_limits.md#webhook-rate-limit)

### Fichier de configuration {#configuration-file}

Vous pouvez définir ces limites de débit uniquement dans le fichier de configuration de votre installation, par exemple `/etc/gitlab/gitlab.rb` dans une installation via le package Linux :

- [Limites de débit de GitLab Pages](../administration/pages/rate-limits.md)

## Limitations non configurables {#non-configurable-limits}

Certaines limites de débit ne peuvent pas être configurées. Pour obtenir la liste de ces limites, voir [les limites de débit non configurables](non_configurable.md).

## Bannissements et blocages {#bans-and-blocks}

Certaines protections bloquent un client pendant une période déterminée au lieu de ralentir les requêtes. Pour plus d'informations, voir [les bannissements pour abus et échecs d'authentification](abuse_bans.md).

## Sujets connexes {#related-topics}

- [Limites de l'application GitLab](../administration/instance_limits.md)
- [Limites CI/CD](../administration/cicd/limits.md)
