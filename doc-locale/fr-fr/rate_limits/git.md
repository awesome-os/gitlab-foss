---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
gitlab_dedicated: yes
description: "Configurer les limites de débit pour les opérations Git HTTP, Git LFS et Git SSH."
title: Limites de débit des opérations Git
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les opérations Git courantes, comme les clones, les fetches et les pushes, peuvent générer de nombreuses requêtes en peu de temps. Les limites de débit pour les opérations Git HTTP, Git LFS et Git SSH protègent la sécurité et la durabilité de votre instance GitLab. Chacune de ces limites fonctionne différemment avec les [limites de débit générales par utilisateur et par IP](../administration/settings/user_and_ip_rate_limits.md). Chaque section explique comment.

## Git HTTP {#git-http}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/147112) dans GitLab 17.0.

{{< /history >}}

Si vous utilisez Git HTTP dans votre dépôt, les opérations Git courantes peuvent générer de nombreuses requêtes Git HTTP. GitLab peut appliquer des limites de débit aux requêtes Git HTTP authentifiées et non authentifiées afin d'améliorer la sécurité et la durabilité de votre application web.

> [!note]
> [Les limites de débit générales par utilisateur et par IP](../administration/settings/user_and_ip_rate_limits.md) ne sont pas appliquées aux requêtes Git HTTP.

### Git HTTP sur GitLab.com {#git-http-on-gitlabcom}

Sur GitLab.com, les requêtes Git HTTP sont soumises aux [limites de débit des requêtes Git HTTPS](../user/gitlab_com/rate_limits.md#current-rate-limits).

### Configurer les limites de débit Git HTTP non authentifiées {#configure-unauthenticated-git-http-rate-limits}

GitLab désactive par défaut les limites de débit pour les requêtes Git HTTP non authentifiées.

Prérequis :

- Vous devez disposer d'un accès administrateur.

Pour appliquer des limites de débit aux requêtes Git HTTP qui ne contiennent pas de paramètres d'authentification, activez et configurez ces limites :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Réseau**.
1. Développez **Limites de débit HTTP Git**.
1. Sélectionnez **Activer la limite de débit des requêtes HTTP Git non authentifiées**.
1. Saisissez une valeur pour **Nombre maximal de requêtes HTTP Git non authentifiées par période et par utilisateur**.
1. Saisissez une valeur pour **Limite de débit des requêtes HTTP Git non authentifiées en secondes**.
1. Sélectionnez **Enregistrer les modifications**.

### Configurer les limites de débit Git HTTP authentifiées {#configure-authenticated-git-http-rate-limits}

{{< history >}}

- Les limites de débit Git HTTP authentifiées ont été [introduites](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/191552) dans GitLab 18.1 [avec un feature flag](../administration/feature_flags/_index.md) nommé `git_authenticated_http_limit`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/issues/543768) dans GitLab 18.3.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/561577) dans GitLab 18.4. Le feature flag `git_authenticated_http_limit` a été supprimé.

{{< /history >}}

GitLab désactive par défaut les limites de débit pour les requêtes Git HTTP authentifiées.

Prérequis :

- Vous devez disposer d'un accès administrateur.

Pour appliquer des limites de débit aux requêtes Git HTTP qui contiennent des paramètres d'authentification, activez et configurez ces limites :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Réseau**.
1. Développez **Limites de débit HTTP Git**.
1. Sélectionnez **Activer la limite de débit des requêtes HTTP Git authentifiées**.
1. Saisissez une valeur pour **Nombre maximal de requêtes HTTP Git authentifiées par période et par utilisateur**.
1. Saisissez une valeur pour **Limite de débit des requêtes HTTP Git authentifiées en secondes**.
1. Sélectionnez **Enregistrer les modifications**.

Si nécessaire, vous pouvez [autoriser des utilisateurs spécifiques à contourner la limitation de débit des requêtes authentifiées](../administration/settings/user_and_ip_rate_limits.md#allow-specific-users-to-bypass-authenticated-request-rate-limiting).

## Git LFS {#git-lfs}

[Git Large File Storage (LFS)](../topics/git/lfs/_index.md) est une extension Git pour la gestion des fichiers volumineux. Les dépôts qui utilisent Git LFS peuvent générer un grand nombre de requêtes LFS. Vous pouvez appliquer les [limites de débit générales par utilisateur et par IP](../administration/settings/user_and_ip_rate_limits.md), mais vous pouvez également remplacer le paramètre général pour imposer des limites supplémentaires aux requêtes Git LFS. Ce remplacement peut améliorer la sécurité et la durabilité de votre application web.

### Git LFS sur GitLab.com {#git-lfs-on-gitlabcom}

Sur GitLab.com, les requêtes Git LFS sont soumises aux [limites de débit des requêtes web authentifiées](../user/gitlab_com/rate_limits.md#current-rate-limits). Ces limites sont définies à 1 000 requêtes par minute et par utilisateur.

Chaque objet Git LFS téléversé ou téléchargé génère une requête HTTP qui est comptabilisée dans cette limite.

> [!note]
> Les projets contenant plusieurs fichiers volumineux peuvent rencontrer une erreur de limite de débit HTTP. Cette erreur survient lors d'un clonage ou d'un pull, lorsqu'il est effectué depuis une seule adresse IP dans des environnements automatisés tels que les pipelines CI/CD.

### Configurer les limites de débit Git LFS {#configure-git-lfs-rate-limits}

Les limites de débit Git LFS sont désactivées par défaut sur les instances GitLab Self-Managed. Les administrateurs peuvent configurer des limites de débit dédiées spécifiquement au trafic Git LFS. Lorsqu'elles sont activées, ces limites de débit LFS dédiées remplacent les [limites de débit par utilisateur et par IP](../administration/settings/user_and_ip_rate_limits.md) par défaut.

Prérequis :

- Vous devez être administrateur de l'instance.

Pour configurer les limites de débit Git LFS :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Réseau**.
1. Développez **Limites de débit Git LFS**.
1. Sélectionnez **Activer la limite de fréquence des requêtes Git LFS authentifiées**.
1. Saisissez une valeur pour **Nombre maximal de requêtes Git LFS authentifiées par période et par utilisateur**.
1. Saisissez une valeur pour **Durée de la limitation des requêtes Git LFS authentifiées en secondes**.
1. Sélectionnez **Enregistrer les modifications**.

## Opérations Git SSH {#git-ssh-operations}

GitLab applique des limites de débit aux opérations Git utilisant SSH par compte utilisateur et par projet. Lorsqu'un utilisateur dépasse la limite de débit, GitLab rejette les demandes de connexion ultérieures de cet utilisateur pour le projet.

La limite de débit s'applique au niveau de la commande Git ([plumbing](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)). Par défaut, chaque commande dispose d'une limite de débit de 600 par minute. Par exemple :

- `git push` dispose d'une limite de débit de 600 par minute.
- `git pull` dispose de sa propre limite de débit de 600 par minute.

Les commandes `git-upload-pack`, `git pull` et `git clone` partagent une limite de débit car elles partagent des commandes.

> [!note]
> [Les limites de débit générales par utilisateur et par IP](../administration/settings/user_and_ip_rate_limits.md) ne sont pas appliquées aux opérations Git SSH. Le trafic SSH atteint GitLab via l'API interne et ne compte donc que dans cette limite.

### Opérations Git SSH sur GitLab.com {#git-ssh-operations-on-gitlabcom}

Sur GitLab.com, les opérations Git SSH utilisent la limite de débit par défaut de 600 opérations par minute. Vous ne pouvez pas modifier cette limite.

### Configurer la limite d'opérations GitLab Shell {#configure-the-gitlab-shell-operation-limit}

`Git operations using SSH` est activé par défaut. La valeur par défaut est 600 par utilisateur et par minute.

Prérequis :

- Accès administrateur.

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Réseau**.
1. Développez **Limite de débit des opérations Git SSH**.
1. Saisissez une valeur pour **Nombre maximum d'opérations Git par minute**.
   - Pour désactiver la limite de débit, définissez-la sur `0`.
1. Sélectionnez **Enregistrer les modifications**.

## Sujets connexes {#related-topics}

- [Limites de fréquence](_index.md)
- [Limites de débit par utilisateur et par IP](../administration/settings/user_and_ip_rate_limits.md)
- [Limites de débit non configurables](non_configurable.md)
