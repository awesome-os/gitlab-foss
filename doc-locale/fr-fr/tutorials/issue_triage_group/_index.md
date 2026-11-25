---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Configurez des labels à portée limitée et un tableau des tickets de groupe partagé entre plusieurs projets pour trier les tickets par type, gravité et priorité."
title: 'Tutoriel : configurer un groupe avec plusieurs projets pour le triage des tickets'
---

<!-- vale gitlab_base.FutureTense = NO -->

Le triage des tickets est le processus de catégorisation selon le type et la gravité. À mesure que votre projet grandit et que les personnes créent davantage de tickets, il est utile de mettre en place un workflow pour le triage des tickets entrants.

Dans ce tutoriel, vous allez apprendre à configurer un groupe GitLab avec plusieurs projets pour ce scénario.

Pour configurer GitLab pour le triage des tickets dans un projet :

1. [Créer un groupe](#create-a-group)
1. [Créer des projets dans un groupe](#create-projects-inside-a-group)
1. [Définir les critères pour les types, la gravité et la priorité](#decide-on-the-criteria-for-types-severity-and-priority)
1. [Documenter vos critères](#document-your-criteria)
1. [Créer des labels à portée limitée](#create-scoped-labels)
1. [Prioriser les nouveaux labels](#prioritize-the-new-labels)
1. [Créer un tableau de triage des tickets de groupe](#create-a-group-issue-triage-board)
1. [Créer des tickets pour les fonctionnalités](#create-issues-for-features)

## Avant de commencer {#before-you-begin}

- Si vous utilisez un projet existant pour ce tutoriel, assurez-vous de disposer du rôle Reporter, Developer, Maintainer ou Owner pour le projet.
  - Si votre projet existant ne possède pas de groupe parent, créez un groupe et [promouvez les labels du projet en labels de groupe](../../user/project/labels.md#promote-a-project-label-to-a-group-label).

## Créer un groupe {#create-a-group}

Un [groupe](../../user/group/_index.md) est, en substance, un conteneur pour plusieurs projets. Avec un groupe, vous pouvez gérer plusieurs projets et communiquer avec les membres du groupe en une seule fois.

Pour créer un nouveau groupe :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et sélectionnez **Nouveau groupe**.
1. Sélectionnez **Créer un groupe**.
1. Saisissez les informations du groupe.
   - Pour **Nom du groupe**, saisissez `triage-tutorial`.
1. Sélectionnez **Créer un groupe** en bas de la page.

## Créer des projets dans un groupe {#create-projects-inside-a-group}

Pour gérer le suivi des tickets dans plusieurs projets, vous devez créer au moins deux projets dans votre groupe.

Pour créer un nouveau projet :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Créer un projet vide**.
1. Saisissez les informations du projet :
   - Pour **Nom du projet**, saisissez `test-project-1`. Pour plus d'informations, consultez les [règles de nommage](../../user/reserved_names.md#rules-for-usernames-project-and-group-names-and-slugs) des projets.
1. Sélectionnez **Créer le projet** en bas de la page.
1. Répétez ce processus pour créer un second projet nommé `test-project-2`.

## Définir les critères pour les types, la gravité et la priorité {#decide-on-the-criteria-for-types-severity-and-priority}

Ensuite, vous devez déterminer :

- Les **types** de tickets que vous souhaitez reconnaître. Si vous avez besoin d'une approche plus granulaire, vous pouvez également créer des sous-types pour chaque type. Les types permettent de catégoriser le travail afin de comprendre la nature des demandes adressées à votre équipe.
- Les niveaux de **priorités** et de **gravités** pour définir l'impact du travail entrant sur les utilisateurs finaux et pour aider à la priorisation.

Pour ce tutoriel, supposons que vous ayez décidé ce qui suit :

- Type : `Bug`, `Feature` et `Maintenance`
- Priorité : `1`, `2`, `3` et `4`
- Gravité : `1`, `2`, `3` et `4`

Pour vous inspirer, consultez la façon dont GitLab les définit :

- [Types et sous-types](https://handbook.gitlab.com/handbook/engineering/metrics/#work-type-classification)
- [Priorité](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#priority)
- [Gravité](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/#severity)

## Documenter vos critères {#document-your-criteria}

Une fois que vous vous êtes mis d'accord sur tous les critères, consignez-les dans un endroit toujours accessible à vos coéquipiers.

Par exemple, ajoutez-les à un [wiki](../../user/project/wiki/_index.md) dans votre projet, ou dans le handbook de votre entreprise publié avec [GitLab Pages](../../user/project/pages/_index.md).

<!-- Idea for expanding this tutorial:
     Add steps for [creating a wiki page](../../user/project/wiki/_index.md#create-a-new-wiki-page). -->

## Créer des labels à portée limitée {#create-scoped-labels}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Ensuite, vous allez créer des labels à ajouter aux tickets pour les catégoriser.

Le meilleur outil pour cela est les [labels à portée limitée](../../user/project/labels.md#scoped-labels), que vous pouvez utiliser pour définir des attributs mutuellement exclusifs.

En vous référant à la liste des types, gravités et priorités que vous avez définis [précédemment](#decide-on-the-criteria-for-types-severity-and-priority), vous allez créer des labels à portée limitée correspondants.

Le double deux-points (`::`) dans le nom d'un label à portée limitée empêche l'utilisation simultanée de deux labels de même portée. Par exemple, si vous ajoutez le label `type::feature` à un ticket qui possède déjà `type::bug`, le précédent est supprimé.

> [!note]
> Les labels à portée limitée sont disponibles dans les éditions GitLab Premium et GitLab Ultimate. Si vous utilisez l'édition Gratuite, vous pouvez utiliser des labels ordinaires à la place. Cependant, ils ne sont pas mutuellement exclusifs.

Pour créer chaque label :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Nouveau label**.
1. Dans la zone de texte **Intitulé**, saisissez le nom du label. Commencez par `type::bug`.
1. Facultatif. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale pour une couleur spécifique dans la zone de texte **Couleur d'arrière‐plan**.
1. Sélectionnez **Créer un label**.

Répétez les étapes 3 à 6 pour créer tous les labels dont vous avez besoin. Voici quelques exemples :

- `type::bug`
- `type::feature`
- `type::maintenance`
- `priority::1`
- `priority::2`
- `priority::3`
- `priority::4`
- `severity::1`
- `severity::2`
- `severity::3`
- `severity::4`

## Prioriser les nouveaux labels {#prioritize-the-new-labels}

Définissez maintenant les nouveaux labels comme labels prioritaires. Cela garantit que les tickets les plus importants s'affichent en tête de la liste des tickets si vous triez par priorité ou par priorité du label.

Pour savoir ce qui se passe lorsque vous triez par priorité ou par priorité du label, consultez [le tri et l'ordonnancement des listes de tickets](../../user/project/issues/sorting_issue_lists.md).

Pour prioriser les labels :

1. Sur la page Labels, à côté d'un label que vous souhaitez prioriser, sélectionnez **Prioriser** ({{< icon name="star-o" >}}). Ce label apparaît désormais en haut de la liste des labels, sous **Étiquettes prioritaires**.
1. Pour modifier la priorité relative de ces labels, faites-les glisser vers le haut ou vers le bas dans la liste. Les labels situés plus haut dans la liste ont une priorité plus élevée.
1. Priorisez tous les labels que vous avez créés précédemment. Assurez-vous que les labels de priorité et de gravité plus élevées sont placés plus haut dans la liste que ceux de valeurs inférieures.

![Liste de onze labels à portée limitée priorisés.](img/priority_labels_v16_3.png)

## Créer un tableau de triage des tickets de groupe {#create-a-group-issue-triage-board}

Pour vous préparer au backlog de tickets entrants, créez un [tableau des tickets](../../user/project/issue_board.md) qui organise les tickets par label. Vous l'utiliserez pour créer rapidement des tickets et leur ajouter des labels en faisant glisser des cartes vers différentes listes.

Pour configurer votre tableau des tickets :

1. Définissez la portée du tableau. Par exemple, [créez un tableau des tickets de groupe](../../user/project/issue_board.md#group-issue-boards) que vous utiliserez pour attribuer une gravité aux tickets.
1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe **triage-tutorial**.
1. Sélectionnez **Forfait** > **Tableaux des tickets**.
1. Dans le coin supérieur gauche de la page du tableau des tickets, sélectionnez la liste déroulante avec le nom du tableau actuel.
1. Sélectionnez **Créer un nouveau tableau**.
1. Dans la zone de texte **Intitulé**, saisissez `Issue triage (by severity)`.
1. Gardez la case **Afficher la liste des tickets ouverts** cochée et décochez la case **Afficher la liste des tickets fermés**.
1. Sélectionnez **Créer un tableau**. Vous devriez voir un tableau vide.
1. Créez une liste pour le label `severity::1` :
   1. Dans le coin supérieur droit de la page du tableau des tickets, sélectionnez **Créer une liste**.
   1. Dans la colonne qui apparaît, dans la liste déroulante **Valeur**, sélectionnez le label `severity::1`.
   1. En bas de la liste, sélectionnez **Ajouter au tableau**.
1. Répétez l'étape précédente pour les labels `severity::2`, `severity::3` et `severity::4`.

Pour l'instant, les listes de votre tableau devraient être vides. Ensuite, vous les remplirez avec quelques tickets.

## Créer des tickets pour les fonctionnalités {#create-issues-for-features}

Pour suivre les fonctionnalités et les bugs à venir, vous devez créer quelques tickets. Les tickets appartiennent à des projets, mais vous pouvez également les créer directement depuis votre tableau des tickets de groupe.

Commencez par créer quelques tickets pour les fonctionnalités planifiées. Vous pouvez créer des tickets pour les bugs au fur et à mesure que vous les découvrez (espérons qu'ils ne soient pas trop nombreux !).

Pour créer un ticket depuis votre tableau **Triage des tickets (par gravité)** :

1. Accédez à la liste **Ouvrir**. Cette liste affiche les tickets qui ne correspondent à aucune autre liste du tableau. Si vous savez déjà quel label de gravité votre ticket doit avoir, vous pouvez le créer directement depuis la liste de ce label. Gardez à l'esprit que chaque ticket créé depuis une liste de labels reçoit ce label.

   Pour l'instant, continuez avec la liste **Ouvrir**.
1. Dans la liste **Ouvrir**, sélectionnez l'icône **Créer un nouveau ticket** ({{< icon name="plus" >}}).
1. Remplissez les champs :
   - Sous **Intitulé**, saisissez `User registration`.
   - Sélectionnez le projet auquel ce ticket s'applique. Cet exemple utilise `test-project-1`.
1. Sélectionnez **Créer un ticket**.
1. Répétez ces étapes pour créer quelques tickets supplémentaires.

   Par exemple, si vous développez une application, imaginez que `test-project-1` et `test-project-2` correspondent au backend et au frontend de l'application. Créez les tickets suivants, en les attribuant aux projets selon ce qui vous convient :

   - `User registration`
   - `Profile creation`
   - `Search functionality`
   - `Add to favorites`
   - `Push notifications`
   - `Social sharing`
   - `In-app messaging`
   - `Track progress`
   - `Feedback and ratings`
   - `Settings and preferences`

Votre premier tableau de triage des tickets est prêt ! Testez-le en faisant glisser quelques tickets depuis la liste **Ouvrir** vers l'une des listes de labels pour ajouter l'un des labels de gravité.

![Tableau des tickets avec des tickets sans label et des labels « severity » priorisés pour l'étiquetage des tickets.](img/triage_board_v16_3.png)

## Étapes suivantes {#next-steps}

Ensuite, vous pouvez :

- Ajuster la façon dont vous utilisez les tableaux des tickets. Certaines options incluent :
  - Modifier votre tableau des tickets actuel pour y ajouter également des listes pour les labels de priorité et de type. De cette façon, vous élargirez le tableau et un défilement horizontal pourrait être nécessaire.
  - Créer des tableaux des tickets distincts nommés `Issue triage (by priority)` et `Issue triage (by type)`. De cette façon, vous séparerez les différents types de travail de triage, mais vous devrez basculer entre les tableaux.
  - [Configurer des tableaux des tickets pour la passation entre équipes](../boards_for_teams/_index.md).
- Parcourez les tickets par priorité ou gravité dans les listes de tickets, [filtrées par chaque label](../../user/project/issues/managing_issues.md#filter-the-list-of-issues). Si cette option est disponible, utilisez [l'opérateur de filtre « est l'un de »](../../user/project/issues/managing_issues.md#filter-the-list-of-issues).
- Décomposez les tickets en [tâches](../../user/tasks.md).
- Créez des politiques pour automatiser le triage des tickets dans un projet avec le [gem `gitlab-triage`](https://gitlab.com/gitlab-org/ruby/gems/gitlab-triage). Générez des rapports de synthèse avec des heatmaps comme celui-ci :

  ![Heatmap diagonale pour les tickets avec les labels « priority » et « severity ».](img/triage_report_v16_3.png)

Pour en savoir plus sur le triage des tickets chez GitLab, consultez [le triage des tickets](https://handbook.gitlab.com/handbook/product-development/how-we-work/issue-triage/) et [les opérations de triage](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/developer-experience/triage-operations/).
