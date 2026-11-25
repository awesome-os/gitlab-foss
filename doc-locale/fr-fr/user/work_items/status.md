---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Une étape spécifique dans le workflow d'un élément de travail (« En cours », « Terminé », « Ne sera pas fait ») qui appartient à une catégorie et correspond à un état binaire (ouvert/fermé)."
title: Statut
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/543862) dans GitLab 18.2 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `work_item_status_feature_flag`. Activés par défaut.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/521286) dans GitLab 18.4. Le feature flag `work_item_status_feature_flag` a été supprimé.

{{< /history >}}

<!-- Turn off the future tense test because of "won't do". -->
<!-- vale gitlab_base.FutureTense = NO -->

Le statut d'un élément de travail représente une étape spécifique dans son workflow, telle que **En cours**, **Terminé** ou **Ne sera pas fait**. Le statut offre un suivi plus granulaire que le système d'état binaire ouvert/fermé traditionnel utilisé dans GitLab Gratuite.

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une présentation vidéo, consultez [Configurable Status for Issues and Tasks - Complete Walkthrough (GitLab 18.2)](https://www.youtube.com/watch?v=oxN95MSo6UU).
<!-- Video published on 2025-07-11 -->

Utilisez le statut pour :

- Suivre les éléments de travail à travers différentes étapes de réalisation.
- Offrir une meilleure visibilité sur la progression des éléments de travail.
- Remplacer l'utilisation des labels pour gérer les cycles de vie des éléments de travail.
- Standardiser les workflows entre les équipes et les projets.

Le statut est disponible pour les tâches et les tickets. Pour plus d'informations sur les plans d'ajout du statut aux epics et autres types d'éléments de travail, consultez [l'epic 5099](https://gitlab.com/groups/gitlab-org/-/epics/5099).

## Statuts par défaut {#default-statuses}

GitLab fournit des statuts par défaut pour vous aider à démarrer avec le suivi des éléments de travail. Ces statuts ne peuvent pas être modifiés.

Les statuts par défaut sont :

- **À faire** : l'élément de travail est prêt à être démarré.
- **En cours** : l'élément de travail est activement en cours de traitement.
- **Terminé** : l'élément de travail a été complété.
- **Ne sera pas fait** : l'élément de travail ne sera pas complété.
- **Dupliquer** : l'élément de travail est un doublon d'un autre élément.

## Catégories de statut {#status-categories}

Les catégories de statut sont des regroupements logiques qui déterminent comment un statut affecte l'état et l'icône d'un élément de travail. Chaque statut appartient à l'une des cinq catégories suivantes :

- **Priorisation** : pour les éléments de travail nouveaux ou non traités.
- **À faire** : pour les éléments de travail prêts à être démarrés.
- **En cours** : pour les éléments de travail activement en cours de traitement.
- **Terminé** : pour les éléments de travail terminés.
- **Annulée** : pour les éléments de travail qui ne seront pas complétés.

Les statuts des catégories **Terminé** et **Annulée** définissent automatiquement les éléments de travail à l'état fermé. Toutes les autres catégories maintiennent les éléments de travail à l'état ouvert.

<!-- vale gitlab_base.FutureTense = YES -->

## Cycles de vie {#lifecycles}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/556113) dans GitLab 18.5 [avec le feature flag](../../administration/feature_flags/_index.md) `work_item_status_mvc2`. Activés par défaut.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/576610) dans GitLab 18.6. Le feature flag `work_item_status_mvc2` a été supprimé.

{{< /history >}}

Un cycle de vie est un ensemble de statuts qui peut être appliqué à un type d'élément de travail. Les cycles de vie regroupent les statuts en workflows pertinents pouvant être réutilisés de manière cohérente entre les types d'éléments de travail et les espaces de nommage.

Chaque cycle de vie définit des statuts de transition par défaut :

- **Statut ouvert par défaut** : appliqué lors de la création et de la réouverture des éléments de travail.
- **Statut fermé par défaut** : appliqué lors de la fermeture des éléments de travail.
- **Statut dupliqué par défaut** : appliqué lorsque des éléments de travail sont marqués comme doublons, déplacés ou promus.

### Créer un cycle de vie {#create-a-lifecycle}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire pour le groupe.
- Ce groupe doit être au niveau principal.

Pour créer un cycle de vie :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Éléments de travail**.
1. Dans la section **États**, sélectionnez **Créer un cycle de vie**.
1. Ajoutez le nom du cycle de vie et choisissez soit la configuration de cycle de vie par défaut, soit l'un des cycles de vie existants comme point de départ. Cela prérenseigne le nouveau cycle de vie avec des statuts que vous pouvez personnaliser par la suite.
1. Sélectionnez **Créer**.

### Renommer un cycle de vie {#rename-a-lifecycle}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire pour le groupe.
- Ce groupe doit être au niveau principal.

Pour renommer un cycle de vie :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Éléments de travail**.
1. Dans la section **États**, survolez la vue détaillée du cycle de vie.
1. Sélectionnez **Renommer**.
1. Renommez le cycle de vie et sélectionnez **Sauvegarder**.

### Supprimer un cycle de vie {#remove-a-lifecycle}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire pour le groupe.
- Ce groupe doit être au niveau principal.
- Le cycle de vie ne doit pas être utilisé. Il ne doit être associé à aucun type d'élément de travail.

Pour supprimer un cycle de vie :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Éléments de travail**.
1. Dans la section **États**, sélectionnez **Supprimer le cycle de vie** pour le cycle de vie que vous souhaitez supprimer.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer**.

### Modifier le cycle de vie pour un type d'élément de travail {#change-lifecycle-for-a-work-item-type}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire pour le groupe.
- Ce groupe doit être au niveau principal.

Pour modifier le cycle de vie d'un type d'élément de travail :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Éléments de travail**.
1. Dans la section **États**, effectuez l'une des actions suivantes :
   - Sélectionnez **Modifier le cycle de vie**.
   - Si le cycle de vie est utilisé avec plus d'un type d'élément de travail, sélectionnez-le dans la liste déroulante.
1. Sélectionnez un nouveau cycle de vie pour le type d'élément de travail. Vous pouvez choisir un cycle de vie existant ou en créer un nouveau.
1. Sélectionnez **Suivant**.

   Tous les statuts actuels indiquent le nouveau statut du nouveau cycle de vie auquel ils correspondent.

1. Facultatif. Pour choisir un statut de remplacement différent, sélectionnez-le dans la liste déroulante.
1. Sélectionnez **Enregistrer**.

## Statuts personnalisés {#custom-statuses}

Les statuts personnalisés sont des statuts définis au niveau de l'espace de nommage qui remplacent les statuts par défaut pour tous les groupes et projets de cet espace de nommage. Lorsque vous modifiez un cycle de vie, les statuts personnalisés remplacent les statuts par défaut pour cet espace de nommage.

Les statuts personnalisés sont soumis aux limites suivantes :

- 70 statuts maximum par espace de nommage
- 30 statuts maximum par cycle de vie

### Modifications de catégorie de statut {#status-category-changes}

Un statut possède une seule catégorie, et cette catégorie s'applique à chaque cycle de vie qui utilise ce statut. Vous ne pouvez pas modifier la catégorie d'un statut lorsque :

- Le statut est utilisé dans un autre cycle de vie.
- Le statut est en cours d'utilisation et la nouvelle catégorie déplacerait le statut entre les états ouvert et fermé. Un statut est en cours d'utilisation lorsque des éléments de travail lui sont assignés, ou lorsqu'il est le statut de remplacement d'un statut qui a été supprimé.

Pour utiliser une catégorie différente, créez un statut avec un nom différent et la catégorie souhaitée.

### Configurer des statuts personnalisés pour un espace de nommage {#configure-custom-statuses-for-a-namespace}

Configurez des statuts personnalisés pour les groupes principaux afin de les rendre disponibles pour les éléments de travail de ce groupe, ses sous-groupes et ses projets.

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire pour le groupe.
- Ce groupe doit être au niveau principal.

Pour configurer des statuts personnalisés :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Éléments de travail**.
1. Dans la section **États**, sélectionnez **Modifier les états** pour le cycle de vie utilisé par le type d'élément de travail.
1. Ajoutez, modifiez ou réorganisez les statuts pour l'espace de nommage.
1. Sélectionnez **Fermer**.

### Définir le statut d'un élément de travail {#set-status-for-a-work-item}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Chargé de maintenance ou Propriétaire pour le projet ou le groupe de l'élément de travail, en être l'auteur ou y être assigné.

Pour définir un statut pour un élément de travail :

1. Accédez à un ticket ou une tâche.
1. Dans la barre latérale droite, dans la section **Statut**, sélectionnez **Modifier**.
1. Sélectionnez le statut souhaité.
1. Sélectionnez n'importe quelle zone en dehors de la liste déroulante.

Le statut de l'élément de travail est mis à jour immédiatement.
