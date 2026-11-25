---
stage: Async
group: Async
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Jobs en arrière-plan Sidekiq
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

Configurez les limites de taille des jobs Sidekiq et le fuseau horaire utilisé pour évaluer les planifications des jobs Cron.

Prérequis :

- Disposer d'un accès administrateur.

Pour accéder à ces paramètres :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Préférences**.
1. Développez **Jobs Sidekiq en arrière-plan**.

## Limites de taille des jobs {#job-size-limits}

[Sidekiq](../sidekiq/_index.md) stocke les jobs dans Redis. Pour éviter une utilisation excessive de la mémoire Redis, GitLab :

- Compresse les arguments des jobs avant de les stocker dans Redis.
- Rejette les jobs qui dépassent le seuil limite spécifié après compression.

Pour ajuster le seuil de compression ou la limite de taille, mettez les valeurs à jour. Pour désactiver la compression, sélectionnez le mode **Track**.

### Paramètres disponibles {#available-settings}

| Paramètre                                   | Valeur par défaut          | Description                                                                                                                                                                   |
|-------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mode de limitation                             | Compress         | Ce mode compresse les jobs au seuil spécifié et les rejette s'ils dépassent la limite spécifiée après compression.                                               |
| Seuil de compression des jobs Sidekiq (octets) | 100 000 (100 Ko) | Lorsque la taille des arguments dépasse ce seuil, ils sont compressés avant d'être stockés dans Redis.                                                                          |
| Limite de taille des jobs Sidekiq (octets)            | 0                | Les jobs dépassant cette taille après compression sont rejetés. Cela permet d'éviter une utilisation excessive de la mémoire dans Redis, source d'instabilité. Définir cette valeur à 0 empêche le rejet des jobs.     |

Après avoir modifié ces valeurs, [redémarrez Sidekiq](../restart_gitlab.md).

## Fuseau horaire des jobs Cron {#cron-jobs-time-zone}

Par défaut, GitLab évalue les planifications des jobs Cron dans le fuseau horaire de l'instance, qui est UTC sauf configuration contraire. Pour exécuter des jobs Cron dans un fuseau horaire différent, définissez un remplacement de fuseau horaire.

Pour définir le fuseau horaire :

1. Dans la liste déroulante **Fuseau horaire des jobs Cron**, sélectionnez un fuseau horaire ou sélectionnez **Valeurs par défaut du système** pour utiliser le fuseau horaire de l'instance.

Après avoir modifié cette valeur, [redémarrez Sidekiq](../restart_gitlab.md).
