---
stage: Tenant Scale
group: Organizations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Gérer les projets
description: "Paramètres, configuration, activité du projet et suppression du projet."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

La plupart des activités dans GitLab s'effectuent dans un [projet](_index.md). Les fichiers et le code sont enregistrés dans des projets, et la plupart des fonctionnalités s'inscrivent dans le cadre des projets.

## Vue d'ensemble du projet {#project-overview}

Lorsque vous sélectionnez un projet, la page **Vue d'ensemble du projet** affiche le contenu du projet :

- Fichiers du dépôt
- Informations sur le projet (description)
- Sujets
- Badges
- Nombre d'étoiles, de duplications, de commits, de branches, de tags, de releases et d'environnements dans le projet
  - Le nombre de commits est calculé à partir de la branche par défaut du projet, et non à partir de toutes les branches
- Taille de stockage du projet
- Fichiers et configurations facultatifs
- Fichier `README` ou index
  - Page wiki
  - Licence
  - Journal des modifications
  - Directives de contribution
  - Cluster Kubernetes
  - Configuration CI/CD
  - Intégrations
  - GitLab Pages
- Date de création

Pour les projets publics, ainsi que pour les membres des projets internes et privés disposant des [autorisations pour afficher le code du projet](../permissions.md#project-permissions), la page de vue d'ensemble du projet affiche :

- Un [fichier `README` ou index](repository/files/_index.md#readme-and-index-files).
- Une liste des répertoires du dépôt du projet.

Pour les utilisateurs ne disposant pas de l'autorisation d'afficher le code du projet, la page de vue d'ensemble affiche :

- La page d'accueil du wiki.
- La liste des tickets du projet.

Vous pouvez accéder à un projet en utilisant son ID à la place de son nom à l'adresse `https://gitlab.example.com/projects/<id>`. Par exemple, si dans votre espace de nommage personnel `alex` vous avez un projet `my-project` avec l'ID `123456`, vous pouvez accéder au projet à l'adresse `https://gitlab.example.com/alex/my-project` ou `https://gitlab.example.com/projects/123456`.

> [!note]
> Dans GitLab 17.5 et les versions ultérieures, vous pouvez également utiliser `https://gitlab.example.com/-/p/<id>` pour cet endpoint.

## Trouver l'ID du projet {#find-the-project-id}

Vous pourriez avoir besoin de l'ID du projet si vous souhaitez interagir avec le projet à l'aide de l'[API GitLab](../../api/_index.md).

Pour trouver l'ID du projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Copier l'ID du projet**.

## Afficher les projets {#view-projects}

Utilisez la liste **Projets** pour afficher :

- Tous les projets d'une instance
- Les projets avec lesquels vous travaillez ou dont vous êtes propriétaire
- Les projets inactifs, y compris les projets archivés et les projets en attente de suppression

### Explorer tous les projets d'une instance {#explore-all-projects-on-an-instance}

{{< history >}}

- L'onglet Projets tendance a été [supprimé](https://gitlab.com/groups/gitlab-org/-/work_items/18493) dans GitLab 19.0. Feature flags `retire_trending_projects` activés par défaut.
- Feature flag `retire_trending_projects` supprimé dans GitLab 19.1.

{{< /history >}}

Affichez tous les projets de votre instance GitLab. Filtrez la liste par projets actifs et inactifs :

- Les projets actifs sont des projets avec une activité récente ou un développement en cours.
- Les projets inactifs sont des projets archivés ou programmés pour suppression.

Si vous n'êtes pas authentifié, la liste affiche uniquement les projets publics.

Pour afficher les projets de votre instance GitLab :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Explorer**.
1. Facultatif. Sélectionnez un onglet pour filtrer les projets affichés.

### Afficher les projets avec lesquels vous travaillez {#view-projects-you-work-with}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/13066) dans GitLab 17.9 [avec le feature flag](../../administration/feature_flags/_index.md) `your_work_projects_vue`. Fonctionnalité désactivée par défaut.
- [Modification](https://gitlab.com/groups/gitlab-org/-/work_items/13066) du libellé de l'onglet de **Yours** à **Membre** dans GitLab 17.9 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `your_work_projects_vue`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/issues/465889) dans GitLab 17.10. Le feature flag `your_work_projects_vue` a été supprimé.

{{< /history >}}

Pour afficher les projets avec lesquels vous avez interagi :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Voir tous mes projets**.
1. Facultatif. Sélectionnez un onglet pour filtrer les projets affichés :
   - **Contribué** : projets dans lesquels vous avez :
     - Créé des tickets, des merge requests ou des epics
     - Commenté sur des tickets, des merge requests ou des epics
     - Fermé des tickets, des merge requests ou des epics
     - Poussé des commits
     - Approuvé des merge requests
     - Fusionné des merge requests
   - **Favori(s)** : projets que vous avez [mis en favori](#star-a-project)
   - **Personnel** : projets créés dans votre espace de nommage personnel
   - **Membre** : projets dont vous êtes membre
   - **Inactif** : projets archivés et projets en attente de suppression

Vous pouvez également consulter vos projets favoris et vos projets personnels depuis votre profil personnel :

1. Dans le coin supérieur droit, sélectionnez votre avatar, puis votre nom d'utilisateur.
1. Dans la barre latérale gauche, sélectionnez **Projets suivis** ou **Projets personnels**.

### Afficher les projets inactifs {#view-inactive-projects}

{{< history >}}

- [Modification](https://gitlab.com/groups/gitlab-org/-/work_items/13066) du libellé de l'onglet de « Suppression en attente » à « Inactif » dans GitLab 17.9 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `your_work_projects_vue`. Fonctionnalité désactivée par défaut.
- [Modification du libellé de l'onglet disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/issues/465889) dans GitLab 17.10. Le feature flag `your_work_projects_vue` a été supprimé.
- [Déplacé](https://gitlab.com/groups/gitlab-org/-/work_items/17208) de GitLab Premium vers GitLab Free dans la version 18.0.
- [Activé pour les projets dans les espaces de nommage personnels](https://gitlab.com/gitlab-org/gitlab/-/issues/536244) dans GitLab 18.0.

{{< /history >}}

Un projet est inactif lorsqu'il est soit en attente de suppression, soit archivé.

Pour afficher tous les projets inactifs :

1. Sélectionnez l'une des options suivantes :
   - **Voir tous mes projets**, pour filtrer vos projets.
   - **Explorer**, pour filtrer tous les projets auxquels vous avez accès.
1. Sélectionnez l'onglet **Inactif**.

Chaque projet inactif dans la liste affiche un badge pour indiquer que le projet est soit archivé, soit en attente de suppression.

Si le projet est en attente de suppression, la liste affiche également :

- La date à laquelle la suppression définitive du projet est planifiée.
- Une action **Restaurer**. Lorsque vous restaurez un projet :
  - Le label **Suppression en attente** est supprimé. Le projet n'est plus programmé pour suppression.
  - Le projet est retiré de l'onglet **Inactif**.

### Afficher uniquement les projets dont vous êtes propriétaire {#view-only-projects-you-own}

Pour afficher uniquement les projets dont vous êtes propriétaire :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez l'une des options suivantes :
   - **Voir tous vos projets**, pour filtrer vos projets.
   - **Explorer**, pour filtrer tous les projets auxquels vous avez accès.
1. Au-dessus de la liste des projets, sélectionnez **Rechercher ou filtrer les résultats**.
1. Dans la liste déroulante **Rôle**, sélectionnez **Propriétaire**.

## Afficher l'activité du projet {#view-project-activity}

Vous pouvez afficher les actions les plus récentes effectuées dans un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Activité**.
1. Facultatif. Pour filtrer l'activité par type de contribution, sélectionnez un onglet :

   - **Tous** : toutes les contributions des membres du projet.
   - **Événements poussés** : événements poussés dans le projet.
   - **Événements de fusion** : merge requests acceptées dans le projet.
   - **Événements liés à un ticket** : tickets ouverts et fermés dans le projet.
   - **Commentaires** : commentaires publiés par les membres du projet.
   - **Designs** : Designs ajoutés, mis à jour et supprimés dans le projet.
   - **Équipe** : membres ayant rejoint et quitté le projet.

1. Facultatif. Pour vous abonner à un flux RSS de cette activité, sélectionnez le symbole de flux ({{< icon name="rss" >}}).

GitLab supprime les événements d'activité de projet de plus de trois ans de la table des événements pour des raisons de performance.

## Filtrer les projets par langage {#filter-projects-by-language}

Vous pouvez filtrer les projets par le langage de programmation qu'ils utilisent. Pour cela :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez l'une des options suivantes :
   - **Voir tous vos projets**, pour filtrer vos projets.
   - **Explorer**, pour filtrer tous les projets auxquels vous avez accès.
1. Au-dessus de la liste des projets, sélectionnez **Rechercher ou filtrer les résultats**.
1. Dans la liste déroulante **Langage**, sélectionnez le langage par lequel vous souhaitez filtrer les projets.

Une liste de projets utilisant le langage sélectionné s'affiche.

## Mettre un projet en favori {#star-a-project}

Vous pouvez mettre en favori les projets que vous utilisez fréquemment pour les retrouver plus facilement.

Pour mettre un projet en favori :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans le coin supérieur droit de la page, sélectionnez **Mettre en favori**.

## Quitter un projet {#leave-a-project}

Lorsque vous quittez un projet :

- Vous n'êtes plus membre du projet et ne pouvez plus contribuer.
- Tous les tickets et merge requests qui vous étaient assignés sont désassignés.

Prérequis :

- Vous ne pouvez quitter un projet de cette manière que lorsqu'un projet fait partie d'un groupe sous un [espace de nommage de groupe](../namespace/_index.md).
- Vous devez être un [membre direct](members/_index.md#membership-types) du projet.

Pour quitter un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Quitter le projet**, puis **Quitter le projet** à nouveau.

Pour quitter un projet directement depuis la vue liste **Votre travail** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Voir tous mes projets**.
1. Dans l'onglet **Membre**, trouvez le projet que vous souhaitez quitter et sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Quitter le projet**.

Cette action est également disponible sur d'autres pages de liste.

## Modifier un projet {#edit-a-project}

Utilisez les paramètres généraux du projet pour modifier les détails de votre projet.

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Dans la zone de texte **Nom du projet**, saisissez le nom de votre projet. Consultez les [limitations sur les noms de projets](../reserved_names.md).
1. Facultatif. Dans la zone de texte **Description du projet**, saisissez la description de votre projet. La description est limitée à 2 000 caractères. Les composants publiés dans le catalogue CI/CD nécessitent une description de projet.
1. Sélectionnez **Enregistrer les modifications**.

### Renommer un dépôt {#rename-a-repository}

Le nom du dépôt d'un projet définit son URL.

Prérequis :

- Vous devez être administrateur ou disposer du rôle Chargé de maintenance ou Propriétaire pour le projet.

> [!note]
> Lorsque vous modifiez le chemin du dépôt, les utilisateurs peuvent rencontrer des problèmes s'ils poussent vers l'ancienne URL ou en tirent des modifications. Pour plus d'informations sur la durée de redirection et ses effets secondaires, consultez [les redirections lors du renommage des dépôts](repository/_index.md#repository-path-changes).

Pour renommer un dépôt :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Paramètres avancés**.
1. Dans la zone de texte **Changer le chemin**, modifiez le chemin.
1. Sélectionnez **Changer le chemin**.

### Ajouter un avatar de projet {#add-a-project-avatar}

Ajoutez un avatar de projet pour identifier visuellement votre projet. Si vous n'ajoutez pas d'avatar, GitLab affiche la première lettre du nom de votre projet comme avatar de projet par défaut.

Pour ajouter un avatar de projet, utilisez l'une des méthodes suivantes :

- Ajouter un logo à votre dépôt.
- Téléverser un avatar dans les paramètres de votre projet.

#### Ajouter un logo à votre dépôt {#add-a-logo-to-your-repository}

Si vous n'avez pas téléversé d'avatar dans les paramètres de votre projet, GitLab recherche un fichier nommé `logo` dans votre dépôt à utiliser comme avatar de projet par défaut.

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.
- Votre fichier doit faire 200 Ko ou moins. La taille d'image idéale est de 192 x 192 pixels.
- Le fichier doit être nommé `logo` avec l'extension `.png`, `.jpg` ou `.gif`. Par exemple, `logo.gif`.

Pour ajouter un fichier logo à utiliser comme avatar de projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. À la racine du dépôt de votre projet, téléversez le fichier logo.

#### Téléverser un avatar dans les paramètres du projet {#upload-an-avatar-in-project-settings}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.
- Votre fichier doit faire 200 Ko ou moins. La taille d'image idéale est de 192 x 192 pixels.
- L'image doit être de l'un des types de fichiers suivants :
  - `.bmp`
  - `.gif`
  - `.ico`
  - `.jpeg`
  - `.png`
  - `.tiff`

Pour téléverser un avatar dans les paramètres de votre projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Dans la section **Avatar du projet**, sélectionnez **Choisir un fichier**.
1. Sélectionnez votre fichier avatar.
1. Sélectionnez **Enregistrer les modifications**.

## Supprimer un projet {#delete-a-project}

{{< history >}}

- Le comportement par défaut a été [modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/389557) pour passer à une suppression différée des projets pour les éditions Premium et Ultimate sur [GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/393622) et [GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/119606) dans la version 16.0.
- Le comportement par défaut a été modifié pour passer à une suppression différée des projets pour [GitLab Free](https://gitlab.com/groups/gitlab-org/-/work_items/17208) et les [projets personnels](https://gitlab.com/gitlab-org/gitlab/-/issues/536244) dans la version 18.0.

{{< /history >}}

Par défaut, lorsque vous supprimez un projet pour la première fois, il entre dans un état de suppression en attente. Supprimez à nouveau le projet pour le supprimer immédiatement.

Prérequis :

- Vous devez disposer du rôle Propriétaire pour un projet.
- Les propriétaires doivent être [autorisés à supprimer des projets](../../administration/settings/visibility_and_access_controls.md#restrict-project-deletion-to-administrators).

Pour supprimer un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Supprimer**.
1. Dans la boîte de dialogue de confirmation, saisissez le nom du projet et sélectionnez **Oui, supprimer le projet**.

Cette action ajoute un job en arrière-plan pour marquer un projet pour suppression. Sur GitLab.com, le projet est supprimé après 30 jours. Sur GitLab Self-Managed, vous pouvez modifier la période de rétention via les [paramètres de l'instance](../../administration/settings/visibility_and_access_controls.md#deletion-protection).

Si l'utilisateur ayant planifié la suppression du projet perd l'accès au projet avant que la suppression ne se produise (par exemple, en quittant le projet, en voyant son rôle rétrogradé ou en étant banni du projet), le job de suppression restaure le projet à la place, et le projet n'est plus programmé pour suppression.

Lorsqu'un projet est marqué pour suppression, les pipelines CI/CD planifiés cessent de s'exécuter.

> [!warning]
> Si l'utilisateur ayant planifié la suppression du projet récupère le rôle Propriétaire ou l'accès administrateur avant l'exécution du job, le job supprime définitivement le projet.

Vous pouvez également [supprimer des projets à l'aide de la console Rails](troubleshooting.md#delete-a-project-using-console).

## Supprimer un projet immédiatement {#delete-a-project-immediately}

{{< history >}}

- [Déplacé](https://gitlab.com/groups/gitlab-org/-/work_items/17208) de GitLab Premium vers GitLab Free dans GitLab 18.0.

{{< /history >}}

Si vous ne souhaitez pas attendre la fin de la période de rétention configurée pour supprimer un projet, vous pouvez le supprimer immédiatement.

Prérequis :

- Vous devez disposer du rôle Propriétaire pour un projet.
- Vous avez [planifié la suppression du projet](#delete-a-project).

Pour supprimer définitivement un projet programmé pour suppression :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Supprimer définitivement**.
1. Dans la boîte de dialogue de confirmation, saisissez le nom du projet et sélectionnez **Oui, supprimer le projet**.

Cette action supprime le projet et toutes les ressources associées, y compris les tickets et les merge requests.

### Restaurer un projet {#restore-a-project}

{{< history >}}

- [Déplacé](https://gitlab.com/groups/gitlab-org/-/work_items/17208) de GitLab Premium vers GitLab Free dans la version 18.0.
- [Activé pour les projets dans les espaces de nommage personnels](https://gitlab.com/gitlab-org/gitlab/-/issues/536244) dans GitLab 18.0.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le projet.

Pour restaurer un projet en attente de suppression :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Restaurer**.

## Archiver un projet {#archive-a-project}

{{< history >}}

- Suppression de Pages [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/343109) dans GitLab 17.5.

{{< /history >}}

Archivez un projet pour le rendre en lecture seule et conserver ses données pour consultation ultérieure.

Lorsque vous archivez un projet :

- Le projet devient inactif et affiche un badge `Archived`
- La plupart des fonctionnalités passent en lecture seule, y compris les dépôts, les tickets, les merge requests et les paquets
- Les relations de duplication sont supprimées et les merge requests ouvertes depuis des duplications sont fermées
- Les Pages déployées sont supprimées ainsi que les domaines personnalisés
- Les pipelines CI/CD planifiés cessent de s'exécuter
- La mise en miroir pull s'arrête

Prérequis :

- Vous devez être administrateur ou disposer du rôle Propriétaire pour le projet.

Pour archiver un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Archiver**.

Pour archiver un projet directement depuis la vue liste **Votre travail** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Dans la liste déroulante, sélectionnez **Voir tous mes projets**.
1. Dans l'onglet **Membre**, trouvez le projet que vous souhaitez archiver et sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Archiver**.

Cette action est également disponible sur d'autres pages de liste.

### Désarchiver un projet {#unarchive-a-project}

Lorsque vous désarchivez un projet :

- Les restrictions en lecture seule sont supprimées
- Le projet n'est plus marqué comme inactif
- Les pipelines CI/CD planifiés reprennent automatiquement
- La mise en miroir pull reprend automatiquement

Les projets qui ont été archivés dans le cadre de l'archivage d'un groupe ne peuvent pas être désarchivés individuellement. Vous devez [désarchiver le groupe parent](../group/manage.md#unarchive-a-group) pour désarchiver tous ses projets et sous-groupes.

> [!note]
> Les Pages déployées ne sont pas restaurées automatiquement. Vous devez réexécuter le pipeline pour restaurer Pages.

Prérequis :

- Vous devez être administrateur ou disposer du rôle Propriétaire pour le projet.

Pour désarchiver un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sur la page de vue d'ensemble du projet, dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Désarchiver**.

Pour désarchiver un projet directement depuis la vue liste **Votre travail** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Dans la liste déroulante, sélectionnez **Voir tous mes projets**.
1. Dans l'onglet **Inactif**, trouvez le projet que vous souhaitez désarchiver et sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Désarchiver**.

Cette action est également disponible sur d'autres pages de liste.

## Transférer un projet {#transfer-a-project}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/499163) dans GitLab 17.7 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `transfer_project_with_tags`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/499163) dans GitLab 17.7. Feature flag supprimé.
- Les transferts asynchrones pour les projets ont été [introduits](https://gitlab.com/gitlab-org/gitlab/-/work_items/594575) dans GitLab 18.11 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `groups_and_projects_async_transfer`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/250913) dans GitLab 19.4. Le feature flag `groups_and_projects_async_transfer` a été supprimé.

{{< /history >}}

Transférez un projet pour le déplacer vers un autre groupe. Les transferts de projets déplacent des projets individuels entre n'importe quel espace de nommage de la même instance GitLab.

Vous pouvez transférer un projet depuis :

- Un espace de nommage personnel vers un groupe
- Un groupe vers un autre groupe
- Un groupe vers un espace de nommage personnel

Prérequis :

- Le rôle Chargé de maintenance ou Propriétaire pour le groupe de destination.
- Le rôle Propriétaire du projet que vous souhaitez transférer.
- Activez la création de projets pour le groupe de destination.

> [!note]
> Vous ne pouvez pas transférer un projet s'il est archivé ou en attente de suppression.

Pour transférer un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Paramètres avancés**.
1. Sous **Transférer le projet**, choisissez l'espace de nommage vers lequel transférer le projet.
1. Sélectionnez **Transférer le projet**.
1. Saisissez le nom du projet et sélectionnez **Confirmer**.

Après avoir confirmé le transfert :

- Le projet est transféré de manière asynchrone.
- Un e-mail de confirmation est envoyé une fois le transfert terminé ou en cas d'échec.
- L'ancienne URL du projet est redirigée vers la nouvelle URL du projet. Actualisez la page pour voir la nouvelle URL du projet. Pour les grands projets, vous devez attendre que le transfert soit terminé avant de pouvoir consulter le projet dans l'espace de nommage de destination.

Après avoir transféré un projet, assurez-vous de :

- Mettre à jour les remotes du dépôt local vers les nouvelles URL.
- Vérifier l'accès et les permissions des membres du projet.
- Mettre à jour les configurations de paquets et republier si nécessaire.
- Tester les pipelines CI/CD et les intégrations.
- Réviser et réassigner les politiques de sécurité si nécessaire.

Les administrateurs peuvent transférer des projets depuis la [zone d'administration](../../administration/admin_area.md#administering-projects).

### Données transférées {#what-data-gets-transferred}

Un transfert de projet inclut :

- Composants du projet :
  - Tickets, merge requests et fils de discussion sur les tickets
  - Pipelines CI/CD et configurations
  - Tableaux de bord et wikis
  - Code du dépôt et historique Git
  - Jetons d'accès au projet
- Membres du projet :
  - Membres directs du projet et leurs rôles
  - Invitations à rejoindre en attente
- Ajustements automatisés :
  - De nouveaux labels de projet sont créés si aucun label de groupe correspondant n'existe
  - Des copies d'epics sont créées dans le groupe de destination si nécessaire, avec des copies séparées par projet
    - Lorsque vous transférez plusieurs projets avec des tickets assignés au même epic, des copies distinctes de cet epic sont créées dans le groupe de destination pour chaque projet.

> [!warning]
> Des erreurs lors du processus de transfert peuvent entraîner une perte de données des composants du projet ou des dépendances des utilisateurs finaux.

### Problèmes connus {#known-issues}

Lors du transfert d'un projet, gardez les restrictions suivantes à l'esprit.

Pour les projets avec des membres hérités :

- Les membres disposant d'une [adhésion héritée](members/_index.md#membership-types) dans le projet perdent l'accès à moins qu'ils ne soient également membres du groupe de destination.
- Le projet hérite des nouvelles permissions des membres du groupe de destination.

Pour les projets où le registre de conteneurs est activé :

- Sur GitLab.com : vous ne pouvez transférer des projets qu'au sein du même groupe principal.
- Sur GitLab Self-Managed : le projet ne doit pas contenir d'[images de conteneurs](../packages/container_registry/_index.md#move-or-rename-container-registry-repositories).
- Les projets contenant plus de 1 000 dépôts de conteneurs ne peuvent pas être transférés. Pour plus d'informations, consultez [Déplacer ou renommer des dépôts du registre de conteneurs](../packages/container_registry/_index.md#move-or-rename-container-registry-repositories).

Pour les projets qui utilisent le registre de paquets :

- Si l'espace de nommage racine change, vous devez supprimer les paquets npm qui suivent la [convention de nommage](../packages/npm_registry/_index.md#naming-convention) du projet. Après avoir transféré le projet, vous pouvez soit :
  - Mettre à jour la portée du paquet avec le nouveau chemin d'espace de nommage racine et le republier dans le projet.
  - Republier le paquet dans le projet sans mettre à jour le chemin d'espace de nommage racine, ce qui fait que le paquet ne suit plus la convention de nommage. Si vous republiez le paquet sans mettre à jour le chemin d'espace de nommage racine, il n'est pas disponible pour le [point de terminaison d'instance](../packages/npm_registry/_index.md#install-from-an-instance).

Pour les projets avec une politique de sécurité :

- Le projet ne doit pas avoir de politique de sécurité. Si une politique de sécurité est assignée au projet, elle est automatiquement désassignée lors du transfert.

Pour les projets qui utilisent GitLab Secrets Manager :

> [!warning]
> Tous les secrets dans GitLab Secrets Manager pour le groupe, ses sous-groupes et ses projets sont [définitivement supprimés lors du transfert](../../ci/secrets/secrets_manager/_index.md#transfer-of-a-project-or-group).

Pour les projets présentant des conflits de noms ou de chemins :

- Un projet ne peut pas être transféré si l'espace de nommage de destination contient déjà un projet ou un sous-groupe portant le même nom ou le même chemin. Cela inclut les projets [en attente de suppression](#delete-a-project). Pour résoudre le conflit, renommez ou supprimez l'élément en conflit dans l'espace de nommage de destination avant de transférer le projet.

Lorsque vous transférez un projet :

- Le [chemin du projet change](repository/_index.md#repository-path-changes). Assurez-vous de modifier les URL des composants du projet là où cela est nécessaire.

### Transférer un projet GitLab.com vers une autre édition d'abonnement {#transfer-a-gitlabcom-project-to-a-different-subscription-tier}

Lorsque vous transférez un projet depuis un espace de nommage sous licence GitLab.com Premium ou Ultimate vers GitLab Free :

- Les [jetons d'accès au projet](settings/project_access_tokens.md) sont révoqués.
- Les [abonnements aux pipelines](../../ci/pipelines/_index.md#trigger-a-pipeline-when-an-upstream-project-is-rebuilt) et les [cas de test](../../ci/test_cases/_index.md) sont supprimés.

## Gérer les projets avec le menu Actions {#manage-projects-with-the-actions-menu}

Vous pouvez afficher la liste de tous vos projets et les gérer avec le menu **Actions**.

Prérequis :

- Vous devez disposer des [permissions de projet](../permissions.md#projects) requises pour effectuer l'action.

Pour gérer les projets avec le menu **Actions** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Dans la liste déroulante, sélectionnez **Voir tous mes projets**.
1. Sur la page **Projets**, trouvez votre projet et sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez une action.

Les actions suivantes sont disponibles selon l'état de votre projet :

| État du projet    | Actions disponibles |
|----------|-------------------------|
| Actif   | **Copier l'ID du projet**, **Modifier**, **Archiver**, **Transférer**, **Quitter le projet**, **Supprimer** |
| Archivé | **Copier l'ID du projet**, **Désarchiver**, **Quitter le projet**, **Supprimer** |
| Suppression en attente | **Copier l'ID du projet**, **Restaurer**, **Quitter le projet**, **Supprimer définitivement** |

## Ajouter un cadre de conformité à un projet {#add-a-compliance-framework-to-a-project}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez ajouter des cadres de conformité aux projets d'un groupe disposant d'un [cadre de conformité](../compliance/compliance_frameworks/_index.md).

## Gérer l'accès au projet via des groupes LDAP {#manage-project-access-through-ldap-groups}

Vous pouvez [utiliser LDAP pour gérer l'appartenance aux groupes](../group/access_and_permissions.md#manage-group-memberships-with-ldap).

Vous ne pouvez pas utiliser les groupes LDAP pour gérer l'accès aux projets, mais vous pouvez utiliser la solution de contournement suivante.

Prérequis :

- Vous devez [intégrer LDAP à GitLab](../../administration/auth/ldap/_index.md).
- Vous devez être administrateur.

1. [Créez un groupe](../group/_index.md#create-a-group) pour suivre l'appartenance à votre projet.
1. [Configurez la synchronisation LDAP](../../administration/auth/ldap/ldap_synchronization.md) pour ce groupe.
1. Pour utiliser des groupes LDAP afin de gérer l'accès à un projet, [ajoutez le groupe synchronisé par LDAP en tant que membre](../group/manage.md) du projet.

## Alias de projet {#project-aliases}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les dépôts GitLab sont généralement accessibles via un espace de nommage et un nom de projet. Lors de la migration de dépôts fréquemment consultés vers GitLab, vous pouvez toutefois utiliser des alias de projet pour accéder à ces dépôts avec le nom d'origine. L'accès aux dépôts via un alias de projet réduit le risque associé à la migration de tels dépôts.

Cette fonctionnalité est uniquement disponible sur Git via SSH. De plus, seuls les administrateurs GitLab peuvent créer des alias de projet, et ils ne peuvent le faire que via l'API. Pour plus d'informations, consultez la [documentation de l'API des alias de projet](../../api/project_aliases.md).

Après qu'un administrateur a créé un alias pour un projet, vous pouvez utiliser l'alias pour cloner le dépôt. Par exemple, si un administrateur crée l'alias `gitlab` pour le projet `https://gitlab.com/gitlab-org/gitlab`, vous pouvez cloner le projet avec `git clone git@gitlab.com:gitlab.git` au lieu de `git clone git@gitlab.com:gitlab-org/gitlab.git`.

## Sujets connexes {#related-topics}

- [Importer et migrer vers GitLab](../import/_index.md).
- [Connecter un dépôt externe à GitLab CI/CD](../../ci/ci_cd_for_external_repos/_index.md).
- [Dupliquer un projet](repository/forking_workflow.md#create-a-fork).
- Ajustez la [visibilité du projet](../public_access.md#change-project-visibility) et les [permissions](settings/_index.md#configure-project-features-and-permissions).
- [Règles pour les noms de projets et de groupes](../reserved_names.md#rules-for-usernames-project-and-group-names-and-slugs)
