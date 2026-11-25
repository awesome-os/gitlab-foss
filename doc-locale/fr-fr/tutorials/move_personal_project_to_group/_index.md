---
stage: Tenant Scale
group: Organizations
info: For assistance with this tutorial, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments-to-other-projects-and-subjects>.
title: 'Tutoriel : déplacer votre projet personnel vers un groupe'
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

Si vous avez créé un projet dans un [espace de nommage personnel](../../user/namespace/_index.md), vous pouvez effectuer des tâches courantes, comme la gestion des tickets, des merge requests, du contrôle de sources et de la CI/CD.

Cependant, à un moment donné, votre projet personnel pourrait ne plus suffire et vous pourriez vouloir déplacer votre projet vers un espace de nommage de groupe. Avec un espace de nommage de groupe, vous pouvez :

- Accorder à un groupe d'utilisateurs l'accès à votre projet, plutôt que d'ajouter des utilisateurs un par un.
- Afficher tous les tickets et toutes les merge requests pour tous les projets du groupe.
- Afficher tous les utilisateurs uniques dans l'espace de nommage du groupe, pour tous les projets.
- Gérer les quotas d'utilisation.
- Démarrer un essai ou passer à une édition payante. Cette option est importante si vous êtes impacté par les [modifications des limites d'utilisateurs](https://about.gitlab.com/blog/efficient-free-tier/) et avez besoin de plus d'utilisateurs.

Ce tutoriel vous explique comment déplacer votre projet d'un espace de nommage personnel vers un espace de nommage de groupe.

## Étapes {#steps}

Voici une vue d'ensemble des étapes :

1. [Créer un groupe](#create-a-group).
1. [Déplacer votre projet vers un groupe](#move-your-project-to-a-group).
1. [Travailler avec votre groupe](#work-with-your-group).

### Créer un groupe {#create-a-group}

Pour commencer, assurez-vous de disposer d'un groupe approprié vers lequel déplacer votre projet. Le groupe doit autoriser la création de projets, et vous devez disposer au minimum du rôle Maintainer pour le groupe.

Si vous n'avez pas de groupe, créez-en un :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) puis **Nouveau groupe**.
1. Dans **Nom du groupe**, saisissez un nom pour le groupe.
1. Dans **URL du groupe**, saisissez un chemin pour le groupe, qui sera utilisé comme espace de nommage.
1. Choisissez le [niveau de visibilité](../../user/public_access.md).
1. Facultatif. Renseignez des informations pour personnaliser votre expérience.
1. Sélectionnez **Créer un groupe**.

### Déplacer votre projet vers un groupe {#move-your-project-to-a-group}

Avant de déplacer votre projet vers un groupe :

- Vous devez avoir le rôle Propriétaire pour le projet.
- Supprimez toutes les [images de conteneur](../../user/packages/container_registry/_index.md#move-or-rename-container-registry-repositories)
- Supprimez tous les packages npm. Si vous transférez un projet vers un espace de nommage racine différent, le projet ne doit contenir aucun package npm. Lorsque vous mettez à jour le chemin d'un utilisateur ou d'un groupe, ou que vous transférez un sous-groupe ou un projet, vous devez d'abord supprimer tous les packages npm. Vous ne pouvez pas mettre à jour l'espace de nommage racine d'un projet contenant des packages npm. Assurez-vous de mettre à jour vos fichiers .npmrc pour respecter la convention de nommage et exécutez npm publish si nécessaire.

Vous êtes maintenant prêt à déplacer votre projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Paramètres avancés**.
1. Sous **Transférer le projet**, choisissez le groupe vers lequel transférer le projet.
1. Sélectionnez **Transférer le projet**.
1. Saisissez le nom du projet et sélectionnez **Confirmer**.

Vous êtes redirigé vers la nouvelle page du projet. Si vous avez plusieurs projets personnels, vous pouvez répéter ces étapes pour chaque projet.

> [!note]
> Pour plus d'informations sur ces étapes de migration, consultez [Transfert de votre projet vers un autre espace de nommage](../../user/project/working_with_projects.md#transfer-a-project). Une migration peut nécessiter des actions supplémentaires pour mettre à jour le chemin du projet dans vos ressources et outils associés, tels que les sites web et les gestionnaires de packages.

### Travailler avec votre groupe {#work-with-your-group}

Vous pouvez maintenant afficher votre projet dans votre groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Recherchez votre projet sous **Sous‐groupes et projets**.

Profitez des avantages d'un groupe ! Par exemple, en tant que propriétaire du groupe, vous pouvez afficher rapidement tous les utilisateurs uniques dans votre espace de nommage :

1. Dans votre groupe, sélectionnez **Paramètres** > **Quotas d'utilisation**.
1. L'onglet **Sièges** affiche tous les utilisateurs de tous les projets de votre groupe.
