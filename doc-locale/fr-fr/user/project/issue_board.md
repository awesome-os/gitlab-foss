---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Tableaux des tickets
description: "Visualisation, workflow, Kanban et priorisation."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Suppression du dernier tableau d'un groupe ou d'un projet [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/499579) dans GitLab 17.6.
- Rôle minimum pour gérer les tableaux des tickets [modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Les tableaux des tickets offrent une façon visuelle de gérer et de suivre le travail dans GitLab. Les tableaux des tickets :

- Affichent les tickets sous forme de cartes dans des listes personnalisables basées sur des labels, des jalons ou des personnes assignées.
- Suivent les tickets à travers différentes étapes de votre workflow.
- Prennent en charge les méthodologies agiles comme Kanban et Scrum.
- Organisent plusieurs tableaux pour différentes équipes et projets.
- Visualisent la charge de travail et la progression tout au long de votre processus.

Vos tickets apparaissent sous forme de cartes dans des listes verticales, organisées par [labels](labels.md), [jalons](#milestone-lists), [itérations](#iteration-lists), [personnes assignées](#assignee-lists) ou [statut](#status-lists) assignés.

Ajoutez des métadonnées à vos tickets, puis créez la liste correspondante pour vos tickets existants. Quand vous êtes prêt, vous pouvez faire glisser vos cartes de ticket d'une liste à une autre.

Les tableaux des tickets peuvent alimenter des frameworks courants comme [Kanban](https://en.wikipedia.org/wiki/Kanban_(development)) et [Scrum](https://en.wikipedia.org/wiki/Scrum_(software_development)).

Pour permettre aux membres de votre équipe d'organiser leurs propres workflows, utilisez les [tableaux des tickets multiples](#multiple-issue-boards). Cela permet de créer plusieurs tableaux des tickets dans le même projet.

![Tableau des tickets GitLab - Core](img/issue_boards_core_v17_1.png)

Différentes fonctionnalités des tableaux des tickets sont disponibles dans différentes [éditions GitLab](https://about.gitlab.com/pricing/) :

| Édition     | Nombre de tableaux des tickets de projet | Nombre de [tableaux des tickets de groupe](#group-issue-boards) | [Tableaux des tickets configurables](#configurable-issue-boards) | [Listes de personnes assignées](#assignee-lists) |
| -------- | ------------------------------ | --------------------------------------------------- | ------------------------------------------------------- | --------------------------------- |
| Gratuite     | Multiple                       | 1                                                   | {{< no >}}                                  | {{< no >}}            |
| GitLab Premium  | Multiple                       | Multiple                                            | {{< yes >}}                                  | {{< yes >}}            |
| GitLab Ultimate | Multiple                       | Multiple                                            | {{< yes >}}                                  | {{< yes >}}            |

En savoir plus sur les [fonctionnalités GitLab Enterprise pour les tableaux des tickets](#gitlab-enterprise-features-for-issue-boards).

![Tableau des tickets GitLab - Premium](img/issue_boards_premium_v17_1.png)

<i class="fa-youtube-play" aria-hidden="true"></i> Regardez une [présentation vidéo](https://youtu.be/vjccjHI7aGI) de la fonctionnalité de tableau des tickets.
<!-- Video published on 2020-04-02 -->

## Tableaux des tickets multiples {#multiple-issue-boards}

Les tableaux des tickets multiples permettent d'avoir plus d'un tableau des tickets pour :

- Un projet dans toutes les éditions
- Un groupe dans les éditions Premium et Ultimate

Les tableaux des tickets multiples sont idéaux pour les grands projets avec plus d'une équipe, dans lesquels un dépôt héberge le code de plusieurs produits et lorsque vous souhaitez créer des tableaux pour alimenter différents workflows tout au long du cycle de vie du développement logiciel.

En utilisant la zone de recherche en haut du menu, vous pouvez filtrer les tableaux listés.

Lorsque vous avez dix tableaux ou plus disponibles, une section **Récent** est également affichée dans le menu, avec des raccourcis vers vos quatre derniers tableaux visités.

![Tableaux des tickets multiples.](img/issue_boards_multiple_v17_1.png)

Lorsque vous revenez sur un tableau des tickets dans un projet ou un groupe avec plusieurs tableaux, GitLab charge automatiquement le dernier tableau visité.

### Créer un tableau des tickets {#create-an-issue-board}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour créer un nouveau tableau des tickets :

1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez la liste déroulante avec le nom du tableau actuel.
1. Sélectionnez **Créer un nouveau tableau**.
1. Saisissez le nom du nouveau tableau et sélectionnez sa portée : jalon, itération, labels, personne assignée ou poids.
1. Sélectionnez **Créer un tableau**

### Supprimer un tableau des tickets {#delete-an-issue-board}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet ou le groupe où le tableau est enregistré.

Pour supprimer le tableau des tickets ouvert :

1. Dans le coin supérieur droit de la page du tableau des tickets, sélectionnez **Configurer le tableau** ({{< icon name="settings" >}}).
1. Sélectionnez **Supprimer le tableau**.
1. Sélectionnez **Supprimer** pour confirmer.

Si le tableau que vous avez supprimé était le dernier, un nouveau tableau `Development` est créé.

## Cas d'utilisation des tableaux des tickets {#issue-boards-use-cases}

Vous pouvez adapter les tableaux des tickets GitLab à votre propre workflow préféré. Pour une documentation basée sur les workflows, consultez le [tutoriel planifier et suivre votre travail](../../tutorials/plan_and_track.md).

### Cas d'utilisation pour un seul tableau des tickets {#use-cases-for-a-single-issue-board}

Avec le [GitLab Flow](https://about.gitlab.com/topics/version-control/what-is-gitlab-flow/), vous pouvez discuter de propositions dans des tickets, les étiqueter et les organiser et les prioriser avec des tableaux des tickets.

Par exemple, considérons ce workflow de développement simplifié :

1. Vous disposez d'un dépôt qui héberge la base de code de votre application, et votre équipe y contribue activement du code.
1. Votre équipe **backend** commence à travailler sur une nouvelle implémentation, recueille des retours et des approbations, puis la transmet à l'équipe **frontend**.
1. Une fois le frontend terminé, la nouvelle fonctionnalité est déployée dans un environnement de **préproduction** pour être testée.
1. En cas de succès, elle est déployée en **production**.

Si vous avez les labels **Backend**, **Frontend**, **Préproduction** et **Production**, et un tableau des tickets avec une liste pour chacun, vous pouvez :

- Visualiser l'ensemble du flux d'implémentations depuis le début du cycle de vie du développement jusqu'au déploiement en production.
- Prioriser les tickets dans une liste en les déplaçant verticalement.
- Déplacer les tickets entre les listes pour les organiser selon les labels que vous avez définis.
- Ajouter plusieurs tickets aux listes du tableau en sélectionnant un ou plusieurs tickets existants.

![Déplacement de cartes de tickets.](img/issue_board_move_issue_card_list_v17_1.png)

### Équipe Scrum {#scrum-team}

Dans une équipe Scrum, utilisez les [tableaux des tickets multiples](#multiple-issue-boards) afin que chaque équipe Scrum dispose de son propre tableau. Sur le tableau Scrum, vous pouvez déplacer les tickets à travers chaque partie du processus. Par exemple : **À faire**, **En cours** et **Terminé**.

### Assignations rapides {#quick-assignments}

Pour assigner rapidement des tickets aux membres de votre équipe :

1. Créez des [listes de personnes assignées](#assignee-lists) pour chaque membre de l'équipe.
1. Faites glisser un ticket vers la liste du membre de l'équipe.

## Terminologie des tableaux des tickets {#issue-board-terminology}

Un **tableau des tickets** représente une vue unique de vos tickets. Il peut avoir plusieurs listes, chaque liste étant composée de tickets représentés par des cartes.

Une **liste** est une colonne sur le tableau des tickets qui affiche les tickets correspondant à certains attributs. En plus des listes « Ouvert » et « Fermé » par défaut, chaque liste supplémentaire affiche les tickets correspondant au label, à la personne assignée ou au jalon que vous avez choisi. En haut de chaque liste, vous pouvez voir le nombre de tickets qui lui appartiennent. Les types de listes comprennent :

- **Ouvrir** (par défaut) : tous les tickets ouverts qui n'appartiennent pas à l'une des autres listes. Apparaît toujours comme la liste la plus à gauche.
- **Fermé** (par défaut) : tous les tickets fermés. Apparaît toujours comme la liste la plus à droite.
- **Liste de labels** : tous les tickets ouverts pour un label.
- [**Liste de personnes assignées**](#assignee-lists) : tous les tickets ouverts assignés à un utilisateur.
- [**Liste de jalons**](#milestone-lists) : tous les tickets ouverts pour un jalon.
- [**Liste d'itérations**](#iteration-lists) : tous les tickets ouverts pour une itération.
- [**Liste de statuts**](#status-lists) : tous les tickets ayant un statut.

Une **carte** est une boîte dans une liste qui représente un ticket. Vous pouvez faire glisser des cartes d'une liste à une autre pour modifier leur label, leur personne assignée ou leur jalon. Les informations visibles sur une carte comprennent :

- Titre du ticket
- Labels associés
- Numéro du ticket
- Personne assignée
- Poids
- Jalon
- Itération (dans les éditions Premium et Ultimate)
- Date d'échéance
- Estimation du suivi du temps
- Statut de santé

Un **swimlane** est un regroupement horizontal de tickets sur le tableau des tickets, par exemple par epic parent.

## Ordonner les tickets dans une liste {#ordering-issues-in-a-list}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Lorsqu'un ticket est créé, le système lui attribue une valeur d'ordre relative supérieure à la valeur maximale du projet ou du groupe principal de ce ticket. Cela signifie que le ticket se trouve en bas de toute liste de tickets dans laquelle il apparaît.

Lorsque vous visitez un tableau, les tickets apparaissent ordonnés dans toute liste. Vous pouvez modifier cet ordre en faisant glisser les tickets. L'ordre modifié est enregistré, de sorte que toute personne qui visite le même tableau ultérieurement voit le réordonnancement, avec quelques exceptions.

Chaque fois que vous faites glisser et réordonnez le ticket, sa valeur d'ordre relative change en conséquence. Ensuite, chaque fois que ce ticket apparaît dans un tableau, l'ordonnancement est effectué selon la valeur d'ordre relative mise à jour. Si un utilisateur dans votre instance GitLab fait glisser le ticket `A` au-dessus du ticket `B`, l'ordonnancement est maintenu lorsque ces deux tickets sont chargés ultérieurement dans n'importe quel tableau de la même instance. Il peut s'agir, par exemple, d'un tableau de projet différent ou d'un tableau de groupe différent.

Cet ordonnancement affecte également les [listes de tickets](issues/sorting_issue_lists.md). Modifier l'ordre dans un tableau des tickets modifie l'ordonnancement dans une liste de tickets, et vice versa.

## Mode focus {#focus-mode}

En mode focus, l'interface de navigation est masquée, vous permettant de vous concentrer sur les tickets du tableau. Pour activer ou désactiver le mode focus, dans le coin supérieur droit, sélectionnez **Activer/désactiver le mode focus** ({{< icon name="maximize" >}}).

## Tableaux des tickets de groupe {#group-issue-boards}

Accessible au niveau de navigation du groupe, un tableau des tickets de groupe offre les mêmes fonctionnalités qu'un tableau des tickets de projet. Il peut afficher les tickets de tous les projets relevant du groupe et de ses sous-groupes descendants.

Les utilisateurs de GitLab Gratuite peuvent utiliser un seul tableau des tickets de groupe.

## Fonctionnalités GitLab Enterprise pour les tableaux des tickets {#gitlab-enterprise-features-for-issue-boards}

Les tableaux des tickets GitLab sont disponibles dans l'édition GitLab Gratuite, mais certaines fonctionnalités avancées sont présentes [dans les éditions supérieures uniquement](https://about.gitlab.com/pricing/).

### Tableaux des tickets configurables {#configurable-issue-boards}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Un tableau des tickets peut être associé à un [jalon](milestones/_index.md), des [labels](labels.md), une personne assignée, un poids et l'[itération](../group/iterations/_index.md) en cours, ce qui filtre automatiquement les tickets du tableau en conséquence. Grâce à ces filtres, vous pouvez créer des tableaux uniques adaptés aux besoins de votre équipe.

![Créer un tableau avec une portée définie.](img/issue_board_creation_v17_1.png)

Vous pouvez définir la portée de votre tableau lors de sa création ou en sélectionnant le bouton **Configurer le tableau** ({{< icon name="settings" >}}). Une fois qu'un jalon, une itération, une personne assignée ou un poids est attribué à un tableau des tickets, vous ne pouvez plus filtrer par ces éléments dans la barre de recherche. Pour ce faire, vous devez supprimer la portée souhaitée (par exemple, le jalon, la personne assignée ou le poids) du tableau des tickets.

Si vous ne disposez pas des droits de modification dans un tableau, vous pouvez tout de même consulter la configuration en sélectionnant **Configuration du tableau** ({{< icon name="settings" >}}).

### Listes de personnes assignées {#assignee-lists}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Comme dans une liste classique affichant tous les tickets avec un label choisi, vous pouvez ajouter une liste de personnes assignées qui affiche tous les tickets assignés à un utilisateur. Vous pouvez avoir un tableau avec à la fois des listes de labels et des listes de personnes assignées.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour ajouter une liste de personnes assignées :

1. Sélectionnez **Nouvelle liste**.
1. Sélectionnez **Personne assignée**.
1. Dans la liste déroulante, sélectionnez un utilisateur.
1. Sélectionnez **Ajouter au tableau**.

Maintenant que la liste de personnes assignées est ajoutée, vous pouvez assigner ou désassigner des tickets à cet utilisateur en [déplaçant les tickets](#move-issues-and-lists) vers et depuis une liste de personnes assignées. Pour supprimer une liste de personnes assignées, comme pour une liste de labels, sélectionnez l'icône de corbeille.

![Définir la portée de la liste sur Personne assignée.](img/issue_board_assignee_lists_v17_1.png)

### Listes de jalons {#milestone-lists}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez créer des listes de jalons qui filtrent les tickets par le jalon assigné, vous offrant plus de liberté et de visibilité sur le tableau des tickets.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour ajouter une liste de jalons :

1. Sélectionnez **Nouvelle liste**.
1. Sélectionnez **Jalon**.
1. Dans la liste déroulante, sélectionnez un jalon.
1. Sélectionnez **Ajouter au tableau**.

Pour modifier le jalon des tickets, [faites glisser les cartes de tickets](#move-issues-and-lists) vers et depuis une liste de jalons.

![Définir la portée de la liste sur Jalon.](img/issue_board_milestone_lists_v17_1.png)

### Listes d'itérations {#iteration-lists}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez créer des listes de tickets dans une itération.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour ajouter une liste d'itérations :

1. Sélectionnez **Nouvelle liste**.
1. Sélectionnez **Itération**.
1. Dans la liste déroulante, sélectionnez une itération.
1. Sélectionnez **Ajouter au tableau**.

Pour modifier l'itération des tickets, [faites glisser les cartes de tickets](#move-issues-and-lists) vers et depuis une liste d'itérations.

![Définir la portée de la liste sur Itération.](img/issue_board_iteration_lists_v17_1.png)

### Listes de statuts {#status-lists}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/543862) dans GitLab 18.2 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `work_item_status_feature_flag`. Activés par défaut.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/521286) dans GitLab 18.4. Le feature flag `work_item_status_feature_flag` a été supprimé.

{{< /history >}}

Créez des listes de tickets ayant un statut spécifique. Les listes de statuts vous aident à organiser les tickets par étape de workflow, par exemple **En cours** ou **Terminé**.

Pour plus d'informations, consultez la [section statut](../work_items/status.md).

Les listes de statuts se comportent différemment des autres types de listes :

- **Listes de statuts** : peuvent inclure à la fois des tickets ouverts et fermés, selon que le statut correspond à un état ouvert ou fermé.
- **Autres listes** (comme les listes de personnes assignées ou de jalons) : affichent toujours uniquement les tickets ouverts.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour ajouter une liste de statuts :

1. Sélectionnez **Nouvelle liste**.
1. Sélectionnez **Statut**.
1. Dans la liste déroulante, sélectionnez le statut.
1. Sélectionnez **Ajouter au tableau**.

La liste de statuts est ajoutée au tableau et affiche les tickets ayant ce statut.

Pour modifier le statut des tickets, [faites glisser les cartes de tickets](#move-issues-and-lists) vers et depuis une liste de statuts.

![Définir la portée de la liste sur Statut.](img/issue_board_status_lists_v18_2.png)

### Regrouper les tickets dans des swimlanes {#group-issues-in-swimlanes}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Avec les swimlanes, vous pouvez visualiser les tickets regroupés par epic. Votre tableau des tickets conserve toutes les autres fonctionnalités, mais avec une organisation visuelle différente des tickets. Cette fonctionnalité est disponible pour les projets et les groupes.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour regrouper les tickets par epic dans un tableau des tickets :

1. Sélectionnez **Voir les options** ({{< icon name="preferences" >}}).
1. Sélectionnez **Swimlanes d'epics**.

![Swimlanes d'epics](img/epics_swimlanes_v17_1.png)

Vous pouvez ensuite [modifier](#edit-an-issue) les tickets sans quitter cette vue et les [faire glisser](#move-issues-and-lists) pour modifier leur position et leur assignation à un epic :

- Pour réordonner un ticket, faites-le glisser vers la nouvelle position dans une liste.
- Pour assigner un ticket à un autre epic, faites-le glisser vers la couloir horizontal de l'epic.
- Pour retirer un ticket d'un epic, faites-le glisser vers le couloir **Tickets sans épopée assignée**.
- Pour déplacer un ticket vers un autre epic et une autre liste en même temps, faites glisser le ticket en diagonale.

![Faire glisser des tickets entre les swimlanes.](img/epics_swimlanes_drag_and_drop_v13_6.png)

### Somme des poids des tickets {#sum-of-issue-weights}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Le haut de chaque liste indique la somme des poids des tickets appartenant à cette liste. La somme est utile lorsque vous utilisez des tableaux pour l'allocation de capacité, notamment en combinaison avec les [listes de personnes assignées](#assignee-lists).

![La somme des poids d'un tableau des tickets.](img/issue_board_summed_weights_v17_1.png)

### Limites du travail en cours {#work-in-progress-limits}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Définition de limites par poids [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/119208/) dans GitLab 17.11.

{{< /history >}}

Vous pouvez définir une limite de travail en cours (WIP) pour chaque liste de tickets sur un tableau des tickets. Lorsqu'une limite est définie, l'état actuel et la limite configurée sont affichés dans l'en-tête de la liste du tableau.

Une ligne dans la liste sépare les éléments qui se trouvent dans la limite de ceux qui la dépassent. Vous ne pouvez pas définir de limite WIP sur les listes par défaut (**Ouvrir** et **Fermé**).

#### Types de limites {#types-of-limits}

GitLab prend en charge deux types de limites WIP :

- **Éléments** : limite le nombre de tickets dans une liste indépendamment de leur poids. L'en-tête du tableau affiche le nombre de tickets dans la liste et la limite d'éléments.

  Par exemple, s'il y a 4 tickets et une limite d'éléments de 3, l'en-tête affiche **4/3**.

  ![Limite d'éléments en cours sur un tableau des tickets](img/issue_board_wip_items_limit_v17_11.png)

- **Poids** : limite le poids total des tickets dans une liste. L'en-tête du tableau affiche le poids total des tickets dans la liste et la limite de poids.

  Par exemple, s'il y a des tickets avec des poids dont la somme est de 8 et une limite de poids de 5, l'en-tête affiche **8/5**.

  ![Limite de poids en cours sur un tableau des tickets](img/issue_board_wip_weight_limit_v17_11.png)

Exemples :

- Lorsque vous avez une liste avec quatre tickets et une limite d'éléments de cinq, l'en-tête affiche **4/5**. Si vous dépassez la limite, le nombre actuel de tickets est affiché en rouge.
- Vous avez une liste avec cinq tickets et une limite d'éléments de cinq. Lorsque vous déplacez un autre ticket vers cette liste, l'en-tête de la liste affiche **6/5**, avec le six affiché en rouge. La ligne de limite du travail en cours est affichée avant le sixième ticket.
- Lors de l'utilisation des limites de poids, si vous avez trois tickets avec des poids de 1, 2 et 5 (poids total de 8) et une limite de poids de 5, l'en-tête affiche **8/5** avec le 8 en rouge. La ligne de limite du travail en cours apparaît après les tickets dont le poids combiné ne dépasse pas la limite, les séparant de ceux qui la dépassent.

#### Définir la limite du travail en cours {#set-work-in-progress-limit}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour définir une limite WIP pour une liste, dans un tableau des tickets :

1. En haut de la liste que vous souhaitez modifier, sélectionnez **Modifier les paramètres de la liste** ({{< icon name="settings" >}}). Le panneau latéral des paramètres de la liste s'ouvre à droite.
1. En regard de **Limite du travail en cours**, sélectionnez **Modifier**.
1. Choisissez le type de limite dans la liste déroulante :
   - **Éléments** : pour limiter par le nombre de tickets.
   - **Poids** : pour limiter par le poids total des tickets.
1. Saisissez le nombre maximum d'éléments ou le poids maximum.
1. Appuyez sur <kbd>Entrée</kbd> pour enregistrer.

Pour supprimer une limite WIP, sélectionnez **Supprimer la limite**.

### Tickets bloqués {#blocked-issues}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Si un ticket est [bloqué par un autre ticket](issues/related_issues.md#blocking-issues), une icône apparaît à côté de son titre pour indiquer son statut de blocage.

Lorsque vous survolez l'icône de blocage ({{< icon name="entity-blocked" >}}), une fenêtre contextuelle d'informations détaillées s'affiche.

![Tickets bloqués avec détails.](img/issue_boards_blocked_icon_v17_9.png)

## Actions possibles sur un tableau des tickets {#actions-you-can-take-on-an-issue-board}

- [Modifier un ticket](#edit-an-issue).
- [Créer une nouvelle liste](#create-a-new-list).
- [Supprimer une liste existante](#remove-a-list).
- [Retirer un ticket d'une liste](#remove-an-issue-from-a-list).
- [Filtrer les tickets](#filter-issues) qui apparaissent sur votre tableau des tickets.
- [Déplacer les tickets et les listes](#move-issues-and-lists).
- Faire glisser et réordonner les listes.
- Modifier les labels des tickets (en faisant glisser un ticket entre des listes).
- Fermer un ticket (en le faisant glisser vers la liste **Fermé**).

### Modifier un ticket {#edit-an-issue}

Vous pouvez modifier un ticket sans quitter la vue du tableau. Pour ouvrir le panneau latéral droit, sélectionnez une carte de ticket (pas son titre).

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Vous pouvez modifier les attributs de ticket suivants dans le panneau latéral droit :

- Personnes assignées
- Confidentialité
- Date d'échéance
- [Epic](../group/epics/_index.md)
- [Statut de santé](issues/managing_issues.md#health-status)
- [Itération](../group/iterations/_index.md)
- Labels
- Jalon
- Paramètre de notifications
- Titre
- [Poids](../work_items/weight.md)
- Suivi du temps

Lorsque vous sélectionnez une carte de ticket dans le tableau des tickets, le ticket s'ouvre dans un panneau de détails. Vous pouvez y modifier tous les champs, y compris la description, les commentaires ou les éléments associés.

### Créer une nouvelle liste {#create-a-new-list}

{{< history >}}

- Création d'une liste entre des listes existantes [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/462515) dans GitLab 17.5.

{{< /history >}}

Vous pouvez créer une nouvelle liste entre deux listes existantes ou à droite d'un tableau des tickets.

Pour créer une nouvelle liste entre deux listes :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Tableaux des tickets**.
1. Survolez ou déplacez le focus du clavier entre deux listes.
1. Sélectionnez **Nouvelle liste**. Le panneau de nouvelle liste s'ouvre.

   ![création d'une nouvelle liste entre deux listes dans un tableau des tickets](img/issue_board_add_list_between_lists_v17_6.png)

1. Choisissez le label, l'utilisateur, le jalon, l'itération ou le statut sur lequel baser la nouvelle liste.
1. Sélectionnez **Ajouter au tableau**.

La nouvelle liste est insérée à la même position sur le tableau que le panneau de nouvelle liste.

Pour déplacer et réordonner les listes, faites-les glisser.

Vous pouvez également sélectionner **Nouvelle liste** à l'extrémité droite du tableau. La nouvelle liste est insérée à l'extrémité droite des listes, avant **Fermé**.

### Supprimer une liste {#remove-a-list}

La suppression d'une liste n'a aucun effet sur les tickets et les labels, car c'est uniquement la vue de la liste qui est supprimée. Vous pouvez toujours la recréer plus tard si nécessaire.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour supprimer une liste d'un tableau des tickets :

1. En haut de la liste que vous souhaitez supprimer, sélectionnez **Modifier les paramètres de la liste** ({{< icon name="settings" >}}). Le panneau latéral des paramètres de la liste s'ouvre à droite.
1. Sélectionnez **Supprimer la liste**.
1. Dans la boîte de dialogue de confirmation, sélectionnez à nouveau **Supprimer la liste**.

### Ajouter des tickets à une liste {#add-issues-to-a-list}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Si votre tableau est limité à un ou plusieurs attributs, accédez aux tickets que vous souhaitez ajouter et appliquez les mêmes attributs que la portée de votre tableau.

Par exemple, pour ajouter un ticket à une liste limitée au label `Doing`, dans un tableau des tickets de groupe :

1. Accédez à un ticket dans le groupe ou l'un des sous-groupes ou projets.
1. Ajoutez le label `Doing`.

Le ticket devrait maintenant apparaître dans la liste `Doing` de votre tableau des tickets.

### Retirer un ticket d'une liste {#remove-an-issue-from-a-list}

Lorsqu'un ticket ne doit plus appartenir à une liste, vous pouvez le retirer.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Les étapes dépendent de la portée de la liste :

1. Pour ouvrir le panneau latéral droit, sélectionnez la carte de ticket.
1. Supprimez ce qui maintient le ticket dans la liste. S'il s'agit d'une liste de labels, supprimez le label. S'il s'agit d'une [liste de personnes assignées](#assignee-lists), désassignez l'utilisateur.

### Filtrer les tickets {#filter-issues}

Vous pouvez utiliser les filtres en haut de votre tableau des tickets pour afficher uniquement les résultats souhaités. C'est similaire au filtrage utilisé dans le [gestionnaire de tickets](issues/_index.md).

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Vous pouvez filtrer par les éléments suivants :

- Personne assignée
- Auteur
- [Epic](../group/epics/_index.md)
- [Itération](../group/iterations/_index.md)
- Label
- Jalon
- Ma réaction
- Release
- Type (ticket/incident)
- [Poids](../work_items/weight.md)
- [Statut](../work_items/status.md)

#### Filtrer les tickets dans un tableau de groupe {#filtering-issues-in-a-group-board}

Lorsque vous [filtrez des tickets](#filter-issues) dans un tableau de groupe, gardez ce comportement à l'esprit :

- Jalons : vous pouvez filtrer par les jalons appartenant au groupe et à ses groupes descendants.
- Labels : vous pouvez uniquement filtrer par les labels appartenant au groupe, mais pas à ses groupes descendants.

Lorsque vous modifiez des tickets individuellement à l'aide du panneau latéral droit, vous pouvez également sélectionner les jalons et les labels du projet dont provient le ticket.

### Déplacer les tickets et les listes {#move-issues-and-lists}

Vous pouvez déplacer les tickets et les listes en les faisant glisser.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour un projet dans GitLab.

Pour déplacer un ticket, sélectionnez la carte de ticket et faites-la glisser vers une autre position dans sa liste actuelle ou dans une liste différente. Découvrez les effets possibles dans [faire glisser des tickets entre les listes](#dragging-issues-between-lists).

Pour déplacer une liste, sélectionnez sa barre supérieure et faites-la glisser horizontalement. Vous ne pouvez pas déplacer les listes **Ouvrir** et **Fermé**, mais vous pouvez les masquer lors de la modification d'un tableau des tickets.

#### Déplacer un ticket au début de la liste {#move-an-issue-to-the-start-of-the-list}

Vous pouvez déplacer des tickets en haut de la liste à l'aide d'un raccourci de menu.

Votre ticket est déplacé en haut de la liste même si d'autres tickets sont masqués par un filtre.

Prérequis :

- Vous devez avoir au moins le rôle Planificateur pour le projet.

Pour déplacer un ticket au début de la liste :

1. Dans un tableau des tickets, survolez la carte du ticket que vous souhaitez déplacer.
1. Sélectionnez **Options de la carte** ({{< icon name="ellipsis_v" >}}), puis **Déplacer en début de liste**.

#### Déplacer un ticket à la fin de la liste {#move-an-issue-to-the-end-of-the-list}

Vous pouvez déplacer des tickets en bas de la liste à l'aide d'un raccourci de menu.

Votre ticket est déplacé en bas de la liste même si d'autres tickets sont masqués par un filtre.

Prérequis :

- Vous devez avoir au moins le rôle Planificateur pour le projet.

Pour déplacer un ticket à la fin de la liste :

1. Dans un tableau des tickets, survolez la carte du ticket que vous souhaitez déplacer.
1. Sélectionnez **Options de la carte** ({{< icon name="ellipsis_v" >}}), puis **Déplacer en fin de liste**.

#### Faire glisser des tickets entre les listes {#dragging-issues-between-lists}

Pour déplacer un ticket vers une autre liste, sélectionnez la carte de ticket et faites-la glisser sur cette liste.

Lorsque vous faites glisser des tickets entre des listes, le résultat est différent selon la liste source et la liste cible.

|                              | Vers Ouvert        | Vers Fermé   | Vers la liste du label B                | Vers la liste de la personne assignée Bob          |
| ---------------------------- | -------------- | ----------- | ------------------------------ | ----------------------------- |
| **Depuis Ouvert**                | -              | Fermer le ticket | Ajouter le label B                    | Assigner Bob                    |
| **Depuis Fermé**              | Rouvrir le ticket   | -           | Rouvrir le ticket et ajouter le label B   | Rouvrir le ticket et assigner Bob   |
| **Depuis la liste du label A**        | Supprimer le label A | Fermer le ticket | Supprimer le label A et ajouter le label B | Assigner Bob                    |
| **Depuis la liste de la personne assignée Alice** | Désassigner Alice | Fermer le ticket | Ajouter le label B                    | Désassigner Alice et assigner Bob |

## Conseils {#tips}

Quelques points à retenir :

- Déplacer un ticket entre des listes supprime le label de la liste de provenance et ajoute le label de la liste de destination.
- Un ticket peut exister dans plusieurs listes s'il possède plusieurs labels.
- Les listes sont alimentées automatiquement en tickets si les tickets sont étiquetés.
- Sélectionner le titre du ticket dans une carte vous amène à ce ticket.
- Sélectionner un label dans une carte filtre rapidement l'ensemble du tableau des tickets et affiche uniquement les tickets de toutes les listes qui ont ce label.
- Lorsqu'un ticket est déplacé d'une liste de statuts vers une liste ouverte, le statut ouvert par défaut est appliqué. De même, lorsqu'il est déplacé vers une liste fermée, le statut fermé par défaut est appliqué.
- Pour des raisons de performances et de visibilité, chaque liste affiche par défaut les 20 premiers tickets. Si vous avez plus de 20 tickets, commencez à faire défiler vers le bas et les 20 suivants apparaissent.

## Résolution des problèmes liés aux tableaux des tickets {#troubleshooting-issue-boards}

### `There was a problem fetching users` sur le tableau des tickets de groupe lors du filtrage par Auteur ou Personne assignée {#there-was-a-problem-fetching-users-on-group-issue-board-when-filtering-by-author-or-assignee}

Si vous obtenez une bannière avec l'erreur `There was a problem fetching users` lors du filtrage par auteur ou personne assignée sur un tableau des tickets de groupe, assurez-vous d'être ajouté en tant que membre du groupe actuel. Les non-membres n'ont pas l'autorisation de lister les membres du groupe lors du filtrage par auteur ou personne assignée sur les tableaux des tickets.

Pour corriger cette erreur, vous devez ajouter tous vos utilisateurs au groupe principal avec le rôle Invité, Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire.

### Utiliser la console Rails pour résoudre les problèmes de chargement et d'expiration des tableaux des tickets {#use-rails-console-to-fix-issue-boards-not-loading-and-timing-out}

Si vous constatez qu'un tableau des tickets ne se charge pas et expire dans l'interface utilisateur, utilisez la console Rails pour appeler le service Issue Rebalancing afin de le corriger :

1. [Démarrer une session de console Rails](../../administration/operations/rails_console.md#starting-a-rails-console-session).
1. Exécutez ces commandes :

   ```ruby
   p = Project.find_by_full_path('<username-or-group>/<project-name>')

   Issues::RelativePositionRebalancingService.new(p.root_namespace.all_projects).execute
   ```

1. Pour quitter la console Rails, saisissez `quit`.
