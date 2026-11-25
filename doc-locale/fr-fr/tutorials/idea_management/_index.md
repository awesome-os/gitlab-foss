---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Configurez un projet avec des labels à portée limitée et un tableau des tickets afin que les parties prenantes puissent soumettre des idées, voter pour celles-ci et les trier."
title: 'Tutoriel : configurer un projet pour la gestion des idées'
---

<!-- vale gitlab_base.FutureTense = NO -->

La gestion des idées désigne la collecte, l'organisation, l'évaluation et la mise en œuvre d'idées au sein d'une organisation ou d'une communauté. Les idées peuvent provenir de différentes parties prenantes, telles que des employés, des clients ou des partenaires.

Un backlog d'idées distinct permet à l'équipe de recueillir et de prioriser des concepts et des suggestions potentiels avant qu'ils ne soient pleinement développés. Ce backlog distinct facilite la gestion des idées brutes. Il évite ainsi d'encombrer le backlog principal avec des concepts non affinés ou non validés.

Dans ce tutoriel, vous apprendrez à configurer un projet GitLab pour la gestion des idées.

Pour configurer GitLab pour la gestion des idées dans un projet :

1. [Créer un projet](#create-a-project)
1. [Définir le workflow des idées](#define-the-idea-workflow)
1. [Documenter vos critères](#document-your-criteria)
1. [Créer des labels à portée limitée](#create-scoped-labels)
1. [Créer un tableau de statut des idées](#create-an-idea-status-board)
1. [Les parties prenantes soumettent des idées et votent pour celles-ci](#stakeholders-submit-and-vote-on-ideas)
1. [Trier les nouvelles idées](#triage-new-ideas)

## Avant de commencer {#before-you-begin}

- Si vous utilisez un projet existant pour ce tutoriel, assurez-vous de disposer du rôle Rapporteur, Développeur, Mainteneur ou Propriétaire pour le projet.
- Si vous suivez les étapes ci-dessous et décidez ultérieurement de créer un groupe parent pour votre projet, afin de tirer le meilleur parti des labels, vous devrez promouvoir les labels du projet en labels de groupe.

## Créer un projet {#create-a-project}

Un projet contient les tickets qui seront utilisés pour suivre les idées.

Pour créer un projet vide :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Créer un projet vide**.
1. Saisissez les détails du projet.
   - Pour **Nom du projet**, saisissez `Idea management tutorial`.
1. Sélectionnez **Créer le projet**.

## Définir le workflow des idées {#define-the-idea-workflow}

Vous devez ensuite déterminer le **workflow de statut** que suivront les idées. Communiquer le statut d'une idée permet de définir les bonnes attentes auprès des parties prenantes.

Pour ce tutoriel, supposons que vous ayez défini le workflow de statut suivant :

- `In Review`
- `Backlog`
- `In Progress`
- `Complete`
- `Rejected`

## Documenter vos critères {#document-your-criteria}

Une fois que vous vous êtes mis d'accord sur le workflow de statut, consignez-le dans un endroit toujours accessible à vos coéquipiers.

Par exemple, ajoutez-le à un [wiki](../../user/project/wiki/_index.md) dans votre projet, ou à l'handbook de votre entreprise publié avec [GitLab Pages](../../user/project/pages/_index.md).

<!-- Idea for expanding this tutorial:
     Add steps for [creating a wiki page](../../user/project/wiki/_index.md#create-a-new-wiki-page). -->

## Créer des labels à portée limitée {#create-scoped-labels}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous allez ensuite créer des labels à ajouter aux idées pour représenter le workflow de statut.

Le meilleur outil pour cela est les [labels à portée limitée](../../user/project/labels.md#scoped-labels), que vous pouvez utiliser pour définir des attributs mutuellement exclusifs.

En consultant la liste des statuts que vous avez définie [précédemment](#define-the-idea-workflow), vous devrez créer des labels à portée limitée correspondants.

Le double deux-points (`::`) dans le nom d'un label à portée limitée empêche l'utilisation simultanée de deux labels de même portée. Par exemple, si vous ajoutez le label `status::backlog` à un ticket qui possède déjà `status::in review`, le précédent est supprimé.

> [!note]
> Les labels à portée limitée sont disponibles dans les éditions GitLab Premium et GitLab Ultimate. Si vous utilisez l'édition Gratuite, vous pouvez utiliser des labels ordinaires à la place. Cependant, ils ne sont pas mutuellement exclusifs.

Pour créer chaque label :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Nouveau label**.
1. Dans la zone de texte **Intitulé**, saisissez le nom du label. Commencez par `status::in review`.
1. Facultatif. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale pour une couleur spécifique dans la zone de texte **Couleur d'arrière‐plan**.
1. Sélectionnez **Créer un label**.

Répétez ces étapes pour créer tous les labels dont vous aurez besoin :

- `status::backlog`
- `status::in progress`
- `status::complete`
- `status::rejected`

## Créer un tableau de statut des idées {#create-an-idea-status-board}

Pour vous préparer aux idées entrantes, créez un [tableau des tickets](../../user/project/issue_board.md) qui organise les idées par label. Vous l'utiliserez pour créer rapidement des tickets et leur ajouter des labels en faisant glisser des cartes vers différentes listes.

Pour configurer votre tableau des tickets :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre projet **Idea management tutorial**.
1. Sélectionnez **Forfait** > **Tableaux des tickets**.
1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez la liste déroulante avec le nom du tableau actuel.
1. Sélectionnez **Créer un nouveau tableau**.
1. Dans le champ **Titre**, saisissez `Idea status workflow`.
1. Conservez la case **Afficher la liste des tickets ouverts** cochée et décochez la case **Afficher la liste des tickets fermés**.
1. Sélectionnez **Créer un tableau**. Vous devriez voir un tableau vide.
1. Créez une liste pour le label `status::in review` :
   1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez **Créer une liste**.
   1. Dans la colonne qui apparaît, dans la liste déroulante **Valeur**, sélectionnez le label `status::in review`.
   1. Sélectionnez **Ajouter au tableau**.
1. Répétez l'étape précédente pour les labels `status::backlog`, `status::in progress`, `status::complete` et `status::rejected`.

Pour l'instant, les listes de votre tableau devraient être vides. Vous les remplirez ensuite avec quelques tickets.

![Tableau de statut des idées.](img/blank_idea_board_v16_10.png)

## Les parties prenantes soumettent des idées et votent pour celles-ci {#stakeholders-submit-and-vote-on-ideas}

Partagez votre projet de gestion des idées avec les parties prenantes et invitez-les à documenter leurs idées !

Pour inviter vos parties prenantes :

1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**
1. Sélectionnez **Inviter des membres**
1. Saisissez les adresses e-mail de vos parties prenantes.
1. Sélectionnez le rôle **Rapporteur**.

Vos parties prenantes peuvent désormais accéder à votre projet pour créer de nouvelles idées :

1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**.
1. Dans le coin supérieur droit, sélectionnez **Nouvel élément**.
1. Dans la liste déroulante **Type**, sélectionnez **Ticket** si ce n'est pas déjà le cas.
1. Saisissez un titre et une description.
1. Sélectionnez **Créer un ticket**.

Les parties prenantes peuvent également voter positivement pour une idée existante afin de signaler leur intérêt pour celle-ci :

1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**.
1. Filtrez la liste par **Type** = **Ticket**, puis sélectionnez un ticket.
1. Sélectionnez la [réaction emoji](../../user/emoji_reactions.md) **Pouce vers le haut** sous la description du ticket.

## Trier les nouvelles idées {#triage-new-ideas}

Essayez en faisant glisser des tickets depuis la liste **Ouvrir** vers l'une des listes de labels pour définir le statut du workflow.

![Tableau des tickets d'idées avec des exemples de tickets.](img/populated_idea_board_v16_10.png)

## Étapes suivantes {#next-steps}

Vous pouvez ensuite :

- Créer un [modèle de ticket](../../user/project/description_templates.md) pour recueillir tous les détails importants auprès de vos parties prenantes.
- Utiliser les [commentaires et fils de discussion](../../user/discussions/_index.md) pour recueillir plus d'informations sur une idée.
- [Associer](../../user/project/issues/related_issues.md) des tickets du backlog de votre équipe à des tickets de votre projet d'idées.
