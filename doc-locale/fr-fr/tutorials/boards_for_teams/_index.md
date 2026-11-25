---
stage: Plan
group: Planning Views
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Configurez des tableaux des tickets séparés et des labels de workflow afin que deux équipes puissent se transmettre des tickets en séquence.
title: 'Tutoriel : configurer des tableaux de tickets pour le transfert entre équipes'
---

<!-- vale gitlab_base.FutureTense = NO -->

Ce tutoriel vous explique comment configurer des [tableaux des tickets](../../user/project/issue_board.md) et des [labels à portée limitée](../../user/project/labels.md#scoped-labels) pour deux équipes qui travaillent sur des tickets en séquence.

Dans cet exemple, vous allez créer deux tableaux des tickets pour les équipes UX et Frontend. En suivant les étapes ci-dessous, vous pouvez créer des tableaux des tickets et des workflows pour davantage de sous-équipes, comme Backend ou Quality Assurance.

Pour configurer des tableaux des tickets pour plusieurs équipes :

1. [Créer un groupe](#create-a-group)
1. [Créer un projet](#create-a-project)
1. [Créer des labels](#create-labels)
1. [Créer des tableaux des tickets par équipe](#create-team-issue-boards)
1. [Créer des tickets pour les fonctionnalités](#create-issues-for-features)

## Avant de commencer {#before-you-begin}

- Si vous utilisez un groupe existant pour ce tutoriel, assurez-vous de disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour ce groupe.
- Si vous utilisez un projet existant pour ce tutoriel, assurez-vous de disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour ce projet.

## Le workflow cible {#the-goal-workflow}

Une fois tout configuré, les deux équipes peuvent se transmettre des tickets d'un tableau à l'autre, par exemple de la façon suivante :

1. Le ou la responsable de projet ajoute les labels `Workflow::Ready for design` et `Frontend` à un ticket de fonctionnalité intitulé **Refonte de la page de profil utilisateur**.
1. Un designer produit de l'équipe UX :
   1. Consulte la liste `Workflow::Ready for design` sur le tableau **Workflow UX** et décide de travailler sur la refonte de la page de profil.

      ![Tableau des tickets « Workflow UX » avec trois tickets répartis sur trois colonnes de workflow.](img/ux_board_filled_v16_0.png)

   1. S'assigne le ticket **Refonte de la page de profil utilisateur**.
   1. Fait glisser la carte du ticket vers la liste `Workflow::Design`. Le label de workflow précédent est automatiquement supprimé.
   1. Crée les ✨nouveaux designs✨.
   1. [Ajoute les designs au ticket](../../user/project/issues/design_management.md).
   1. Fait glisser la carte du ticket vers la liste `Workflow::Ready for development`, ce qui ajoute ce label et supprime tout autre label `Workflow::`.
   1. Se désassigne du ticket.
1. Un développeur ou une développeuse de l'équipe Frontend :
   1. Consulte la liste `Workflow::Ready for development` sur le tableau **Workflow frontend** et choisit un ticket sur lequel travailler.

      ![Tableau des tickets « Workflow frontend » avec deux tickets issus du tableau « UX workflow » dans la colonne « Ready for development ».](img/frontend_board_filled_v16_0.png)

   1. S'assigne le ticket **Refonte de la page de profil utilisateur**.
   1. Fait glisser la carte du ticket vers la liste `Workflow::In development`. Le label de workflow précédent est automatiquement supprimé.
   1. Ajoute le code frontend dans une [merge request](../../user/project/merge_requests/_index.md).
   1. Ajoute le label `Workflow::Complete`.

## Créer un groupe {#create-a-group}

Pour anticiper la croissance de votre projet, commencez par créer un groupe. Les groupes vous permettent de gérer un ou plusieurs projets liés simultanément. Vous ajoutez vos utilisateurs en tant que membres du groupe et leur attribuez un rôle.

Pour créer un groupe :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau groupe**.
1. Sélectionnez **Créer un groupe**.
1. Remplissez les champs. Nommez votre groupe `Paperclip Software Factory`.
1. Sélectionnez **Créer un groupe**.

Vous avez créé un groupe vide. Ensuite, vous allez créer un projet qui stockera vos tickets et votre code.

## Créer un projet {#create-a-project}

Le principal travail de développement de code s'effectue dans les projets et leurs dépôts. Un projet contient votre code et vos pipelines, mais aussi les tickets utilisés pour planifier vos prochaines modifications de code.

Pour créer un projet vide :

1. Dans votre groupe, dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) puis sélectionnez **Dans ce groupe** > **Nouveau projet/dépôt**.
1. Sélectionnez **Créer un projet vide**.
1. Saisissez les informations du projet :
   - Dans le champ de texte **Nom du projet**, nommez votre projet `Paperclip Assistant`.
1. Sélectionnez **Créer le projet**.

## Créer des labels {#create-labels}

Vous avez besoin d'un label d'équipe et d'un ensemble de labels de workflow pour indiquer où en est un ticket dans le cycle de développement.

Vous pourriez créer ces labels dans votre projet `Paperclip Assistant`, mais il est préférable de les créer dans le groupe `Paperclip Software Factory`. Ainsi, ces labels seront également disponibles dans tous les autres projets que vous créerez ultérieurement.

Pour créer chaque label :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe **Paperclip Software Factory**.
1. Sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Nouveau label**.
1. Dans le champ de texte **Intitulé**, saisissez le nom du label. Commencez par `Frontend`.
1. Facultatif. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale dans le champ de texte **Couleur d'arrière‐plan**.
1. Sélectionnez **Créer un label**.

Répétez ces étapes pour créer tous les labels dont vous aurez besoin :

- `Frontend`
- `Workflow::Ready for design`
- `Workflow::Design`
- `Workflow::Ready for development`
- `Workflow::In development`
- `Workflow::Complete`

## Créer des tableaux des tickets par équipe {#create-team-issue-boards}

Comme pour les labels, vous pourriez créer vos tableaux des tickets dans le projet **Paperclip Assistant**, mais il peut être préférable de les placer dans le groupe **Paperclip Software Factory**. Ainsi, vous pouvez gérer les tickets de tous les projets que vous pourriez créer ultérieurement dans ce groupe.

Pour créer un nouveau tableau des tickets de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe **Paperclip Software Factory**.
1. Sélectionnez **Forfait** > **Tableaux des tickets**.
1. Créez les tableaux UX workflow et Frontend workflow.

Pour créer le tableau des tickets **Workflow UX** :

1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez la liste déroulante affichant le nom du tableau actuel.
1. Sélectionnez **Créer un nouveau tableau**.
1. Dans le **champ Titre**, saisissez `UX workflow`.
1. Décochez les cases **Afficher la liste des tickets ouverts** et **Afficher la liste des tickets fermés**.
1. Sélectionnez **Créer un tableau**. Vous devriez voir un tableau vide.
1. Créez une liste pour le label `Workflow::Ready for design` :
   1. Dans le coin supérieur droit de la page du tableau des tickets, sélectionnez **Créer une liste**.
   1. Dans la colonne qui apparaît, dans la liste déroulante **Valeur**, sélectionnez le label `Workflow::Ready for design`.
   1. Sélectionnez **Ajouter au tableau**.
1. Répétez l'étape précédente pour les labels `Workflow::Design` et `Workflow::Ready for development`.

![Tableau des tickets « Workflow UX » vide avec trois colonnes de workflow.](img/ux_board_empty_v16_0.png)

Pour créer le tableau **Workflow frontend** :

1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez la liste déroulante affichant le nom du tableau actuel.
1. Sélectionnez **Créer un nouveau tableau**.
1. Dans le **champ Titre**, saisissez `Frontend workflow`.
1. Décochez les cases **Afficher la liste des tickets ouverts** et **Afficher la liste des tickets fermés**.
1. Développez **Portée**.
1. À côté de **Labels**, sélectionnez **Modifier** et sélectionnez le label `Frontend`.
1. Sélectionnez **Créer un tableau**.
1. Créez une liste pour le label `Workflow::Ready for development` :
   1. Dans le coin supérieur droit de la page du tableau des tickets, sélectionnez **Créer une liste**.
   1. Dans la colonne qui est apparue, dans la liste déroulante **Valeur**, sélectionnez le label `Workflow::Ready for development`.
   1. Sélectionnez **Ajouter au tableau**.
1. Répétez l'étape précédente pour les labels `Workflow::In development` et `Workflow::Complete`.

![Tableau des tickets « Workflow frontend » vide avec trois colonnes de workflow.](img/frontend_board_empty_v16_0.png)

Pour l'instant, les listes de vos deux tableaux doivent être vides. Ensuite, vous allez les alimenter avec quelques tickets.

## Créer des tickets pour les fonctionnalités {#create-issues-for-features}

Pour suivre les fonctionnalités, améliorations et bugs à venir, vous devez créer quelques tickets. Les tickets appartiennent à des projets, mais vous pouvez également les créer directement depuis votre tableau des tickets.

Pour créer un ticket depuis votre tableau :

1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez la liste déroulante affichant le nom du tableau actuel.
1. Sélectionnez **Workflow UX**.
1. Dans la liste `Workflow::Ready for development`, sélectionnez **Créer un nouveau ticket** ({{< icon name="plus" >}}).
1. Remplissez les champs :
   1. Sous **Intitulé**, saisissez `Redesign user profile page`.
   1. Sous **Projets**, sélectionnez **Paperclip Software Factory / Paperclip Assistant**.
1. Sélectionnez **Créer un ticket**. Comme vous avez créé le nouveau ticket dans la liste de labels, il est créé avec ce label.
1. Ajoutez le label `Frontend`, car seuls les tickets portant ce label apparaissent dans le tableau de l'équipe Frontend :
   1. Sélectionnez la carte du ticket (pas son titre) ; une barre latérale apparaît sur la droite.
   1. Dans la section **Labels** de la barre latérale, sélectionnez **Modifier**.
   1. Dans la liste déroulante **Attribuer des labels**, sélectionnez les labels `Workflow::Ready for design` et `Frontend`. Les labels sélectionnés sont marqués d'une coche.
   1. Pour appliquer vos modifications aux labels, sélectionnez **X** à côté de **Attribuer des labels** ou cliquez sur n'importe quelle zone en dehors de la section des labels.

Répétez ces étapes pour créer quelques tickets supplémentaires avec les mêmes labels.

Vous devriez maintenant voir au moins un ticket, prêt à être traité par vos designers produit !

Félicitations ! Vos équipes peuvent maintenant commencer à collaborer sur des logiciels remarquables. Pour aller plus loin, vous pouvez tester le [workflow cible](#the-goal-workflow) par vous-même en utilisant ces tableaux, en simulant l'interaction entre les deux équipes.

## En savoir plus sur la gestion de projet dans GitLab {#learn-more-about-project-management-in-gitlab}

Retrouvez d'autres tutoriels sur la gestion de projet sur la [page des tutoriels](../plan_and_track.md).
