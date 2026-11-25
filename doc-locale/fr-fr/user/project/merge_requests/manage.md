---
stage: AI Coding
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Utilisez les revues de merge requests pour discuter et améliorer le code avant qu'il ne soit fusionné dans votre projet."
title: Gérer les merge requests
---

GitLab fournit des outils pour gérer les merge requests de votre projet et de votre groupe.

## Supprimer une merge request {#delete-a-merge-request}

Dans la plupart des cas, vous devriez fermer les merge requests plutôt que de les supprimer. Vous ne pouvez pas annuler la suppression d'une merge request.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le projet.

Pour supprimer une merge request :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et trouvez la merge request que vous souhaitez supprimer.
1. Sélectionner **Éditer**.
1. Faites défiler jusqu'en bas de la page et sélectionnez **Supprimer la merge request**.

> [!note]
> La suppression d'une merge request n'efface pas complètement toutes les données. Certaines informations sont conservées pour maintenir l'historique du projet et prendre en charge les processus de récupération. Pour plus d'informations, consultez [gérer les informations sensibles](../../../topics/git/undo.md#handle-sensitive-information).

## Modifier en masse les merge requests dans un projet {#bulk-edit-merge-requests-in-a-project}

Ces attributs sont modifiables lors de la modification en masse des merge requests :

- Statut (ouvert/fermé)
- Responsable
- Jalon
- Labels
- Abonnements

Prérequis :

- Vous devez disposer du rôle Développeur, Chargé de maintenance ou Propriétaire.

Pour cela :

1. Dans un projet, accédez à **Code** > **Requêtes de fusion**.
1. Sélectionnez **Modification en masse**. Une barre latérale apparaît sur le côté droit de votre écran avec des champs modifiables.
1. Cochez les cases situées à côté de chaque merge request que vous souhaitez modifier.
1. Sélectionnez les champs appropriés et leurs valeurs dans la barre latérale.
1. Sélectionnez **Mettre à jour la sélection**.

## Modifier en masse les merge requests dans un groupe {#bulk-edit-merge-requests-in-a-group}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Ces attributs sont modifiables lorsque vous modifiez en masse les merge requests d'un groupe :

- Jalon
- Labels

Prérequis :

- Vous devez disposer du rôle Développeur, Chargé de maintenance ou Propriétaire pour le projet.

Pour mettre à jour plusieurs merge requests d'un groupe simultanément :

1. Dans un groupe, accédez à **Code** > **Requêtes de fusion**.
1. Sélectionnez **Modification en masse**. Une barre latérale apparaît sur le côté droit de votre écran avec des champs modifiables.
1. Cochez les cases situées à côté de chaque merge request que vous souhaitez modifier.
1. Sélectionnez les champs appropriés et leurs valeurs dans la barre latérale.
1. Sélectionnez **Mettre à jour la sélection**.

## Sujets connexes {#related-topics}

- [Modifier en masse les tickets](../issues/managing_issues.md#bulk-edit-issues)
