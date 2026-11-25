---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Labels
description: "Labels de projet, labels de groupe, portées imbriquées et filtrage."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les labels organisent et suivent le travail dans les fonctionnalités de GitLab. Au fur et à mesure que les projets évoluent de petites équipes vers de grandes organisations, les labels vous aident à suivre et à gérer des volumes de travail croissants. Labels :

- Catégoriser les tickets, les merge requests et les epics avec des attributs personnalisés.
- Filtrer le contenu dans les listes et les tableaux.
- Prioriser les éléments de travail avec des couleurs et des titres descriptifs.
- Suivre la priorité et la gravité avec des labels à portée limitée.
- Structurer les workflows grâce à des regroupements organisés.

## Types de labels {#types-of-labels}

Utilisez trois types de labels dans GitLab :

- **Les labels de projet** peuvent être assignés aux tickets et aux merge requests dans ce projet uniquement.
- **Les labels de groupe** peuvent être assignés aux tickets, aux merge requests et aux [epics](../group/epics/_index.md) dans n'importe quel projet du groupe sélectionné ou de ses sous-groupes.
- **Les labels d'instance** [sont créés](../../administration/labels.md) par les administrateurs d'instance et sont copiés dans tous les nouveaux projets.

## Assigner et désassigner des labels {#assign-and-unassign-labels}

Vous pouvez assigner des labels à n'importe quel ticket, merge request ou epic.

Les labels modifiés sont immédiatement visibles par les autres utilisateurs, sans actualisation de la page, sur les éléments suivants :

- Les epics
- Incidents
- Les tickets
- Les merge requests

Pour assigner ou désassigner un label :

1. Dans la section **Labels** de la barre latérale, sélectionnez **Modifier**.
1. Dans la liste **Assigner des labels**, recherchez des labels en saisissant leurs noms. Vous pouvez effectuer plusieurs recherches pour ajouter d'autres labels. Les labels sélectionnés sont marqués d'une coche.
1. Sélectionnez les labels que vous souhaitez assigner ou désassigner.
1. Pour appliquer vos modifications aux labels, sélectionnez **X** à côté de **Assigner des labels** ou sélectionnez n'importe quelle zone en dehors de la section des labels.

Sinon, pour désassigner un label, sélectionnez le **X** sur le label que vous souhaitez désassigner.

Vous pouvez également assigner et désassigner des labels avec des actions rapides :

- Assigner des labels avec [`/label`](quick_actions.md#label).
- Supprimer des labels avec [`/unlabel`](quick_actions.md#unlabel).
- Supprimer tous les labels et en assigner de nouveaux avec [`/relabel`](quick_actions.md#relabel).

## Afficher les labels disponibles {#view-available-labels}

### Afficher les labels du projet {#view-project-labels}

Pour afficher les **labels du projet** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.

Ou :

1. Affichez un ticket ou une merge request.
1. Dans la barre latérale droite, dans la section **Labels**, sélectionnez **Modifier**.
1. Sélectionnez **Gérer les labels de projet**.

La liste des labels comprend à la fois les labels créés dans le projet et tous les labels créés dans les groupes ancêtres du projet. Pour chaque label, vous pouvez voir le chemin du projet ou du groupe où il a été créé.

### Afficher les labels du groupe {#view-group-labels}

Pour afficher les **labels du groupe** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.

Ou :

1. Affichez un epic.
1. Dans la barre latérale droite, dans la section **Labels**, sélectionnez **Modifier**.
1. Sélectionnez **Gérer les labels de groupe**.

La liste comprend tous les labels créés uniquement dans le groupe. Elle ne répertorie pas les labels créés dans les projets du groupe.

## Créer un label {#create-a-label}

{{< history >}}

- Le rôle minimum pour créer un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet ou le groupe.

### Créer un label de projet {#create-a-project-label}

Pour créer un label de projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Nouveau label**.
1. Dans la zone de texte **Intitulé**, saisissez un nom court et descriptif pour le label. Vous pouvez également utiliser cette zone de texte pour créer des [labels à portée limitée mutuellement exclusifs](#scoped-labels).
1. Facultatif. Dans la zone de texte **Description**, saisissez des informations supplémentaires sur comment et quand utiliser ce label.
1. Facultatif. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale pour une couleur spécifique dans la zone de texte **Couleur d'arrière‐plan**.
1. Sélectionnez **Créer un label**.

### Créer un label de projet à partir d'un ticket ou d'une merge request {#create-a-project-label-from-an-issue-or-merge-request}

{{< history >}}

- Le rôle minimum pour créer un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez également créer un nouveau label de projet à partir d'un ticket ou d'une merge request. Les labels que vous créez de cette façon appartiennent au même projet que le ticket ou la merge request.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour ce faire :

1. Affichez un ticket ou une merge request.
1. Dans la barre latérale droite, dans la section **Labels**, sélectionnez **Modifier**.
1. Sélectionnez **Créer un label de projet**.
1. Renseignez le champ de nom. Vous ne pouvez pas spécifier de description si vous créez un label de cette façon. Vous pouvez ajouter une description ultérieurement en [modifiant le label](#edit-a-label).
1. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale pour une couleur spécifique.
1. Sélectionnez **Créer**. Votre label est créé et sélectionné.

### Créer un label de groupe {#create-a-group-label}

Pour créer un label de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Nouveau label**.
1. Dans la zone de texte **Intitulé**, saisissez un nom court et descriptif pour le label. Vous pouvez également utiliser cette zone de texte pour créer des [labels à portée limitée mutuellement exclusifs](#scoped-labels).
1. Facultatif. Dans la zone de texte **Description**, saisissez des informations supplémentaires sur comment et quand utiliser ce label.
1. Facultatif. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale pour une couleur spécifique dans la zone de texte **Couleur d'arrière‐plan**.
1. Sélectionnez **Créer un label**.

### Créer un label de groupe à partir d'un epic {#create-a-group-label-from-an-epic}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Le rôle minimum pour créer un label de groupe a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez également créer un nouveau label de groupe à partir d'un epic. Les labels que vous créez de cette façon appartiennent au même groupe que l'epic.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe.

Pour ce faire :

1. Affichez un epic.
1. Dans la barre latérale droite, dans la section **Labels**, sélectionnez **Modifier**.
1. Sélectionnez **Créer un label de groupe**.
1. Renseignez le champ de nom. Vous ne pouvez pas spécifier de description si vous créez un label de cette façon. Vous pouvez ajouter une description ultérieurement en [modifiant le label](#edit-a-label).
1. Sélectionnez une couleur parmi les couleurs disponibles, ou saisissez une valeur de couleur hexadécimale pour une couleur spécifique.
1. Sélectionnez **Créer**.

## Modifier un label {#edit-a-label}

{{< history >}}

- Le rôle minimum pour modifier un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet ou le groupe.

### Modifier un label de projet {#edit-a-project-label}

Pour modifier un label de **projet** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. À côté du label que vous souhaitez modifier, sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Modifier**.
1. Sélectionnez **Enregistrer les modifications**.

### Modifier un label de groupe {#edit-a-group-label}

Pour modifier un label de **groupe** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. À côté du label que vous souhaitez modifier, sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Modifier**.
1. Sélectionnez **Enregistrer les modifications**.

## Supprimer un label {#delete-a-label}

{{< history >}}

- Le rôle minimum pour supprimer un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

> [!warning]
> Si vous supprimez un label, il est définitivement supprimé. Toutes les références au label sont supprimées du système et vous ne pouvez pas annuler la suppression.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

### Supprimer un label de projet {#delete-a-project-label}

Pour supprimer un label de **projet** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. À côté de **S'abonner**, sélectionnez ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Supprimer**.

### Supprimer un label de groupe {#delete-a-group-label}

Pour supprimer un label de **groupe** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. L'une ou l'autre des options :

   - À côté de **S'abonner**, sélectionnez ({{< icon name="ellipsis_v" >}}).
   - À côté du label que vous souhaitez modifier, sélectionnez **Modifier** ({{< icon name="pencil" >}}).

1. Sélectionnez **Supprimer**.

## Labels archivés {#archived-labels}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/4233) dans GitLab 18.3 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `labels_archive`. Fonctionnalité désactivée par défaut.
- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/211744) du flag `labels_archive` afin qu'il puisse être activé et désactivé pour un groupe dans GitLab 18.7.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/556700) dans GitLab 18.11. Suppression du feature flag `labels_archive`.

{{< /history >}}

Vous pouvez archiver les labels qui ne sont plus utilisés activement mais qui doivent être conservés pour des raisons historiques et de recherche.

Par exemple, vous pouvez archiver les labels de release tels que `Q4-25` après la fin d'une release, en les maintenant disponibles pour les recherches tout en les supprimant de la liste déroulante de sélection des labels.

Lorsque vous archivez un label :

- Le label est masqué dans la liste déroulante de sélection des labels dans les tickets, les merge requests et les epics.
- Le label reste visible sur les tickets, les merge requests et les epics existants auxquels il était précédemment assigné.
- Vous pouvez toujours rechercher le label et consulter les données historiques.
- Le label apparaît dans un onglet **Archivées** distinct sur la page **Labels**.

### Archiver un label {#archive-a-label}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet ou le groupe.

Pour archiver un label :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. À côté du label que vous souhaitez archiver, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Cochez la case **Archivées**.
1. Sélectionnez **Enregistrer les modifications**.

Le label est archivé et [déprioritisé](#set-label-priority).

### Afficher les labels archivés {#view-archived-labels}

Pour afficher les labels archivés :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Accédez à la page des labels de votre projet ou groupe.
1. Sélectionnez **Archivées**.

### Désarchiver un label {#unarchive-a-label}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet ou le groupe.

Pour désarchiver un label :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Archivées**.
1. À côté du label que vous souhaitez désarchiver, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Décochez la case **Archivées**.
1. Sélectionnez Enregistrer les modifications.

## Promouvoir un label de projet en label de groupe {#promote-a-project-label-to-a-group-label}

{{< history >}}

- Le rôle minimum pour promouvoir un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez vouloir rendre un label de projet disponible pour d'autres projets du même groupe. Vous pouvez alors promouvoir le label en label de groupe.

Si d'autres projets du même groupe ont un label avec le même titre, ils sont tous fusionnés avec le nouveau label de groupe. Si un label de groupe portant le même titre existe, il est également fusionné.

> [!warning]
> La promotion d'un label est une action permanente et ne peut pas être annulée.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe parent du projet.

Pour promouvoir un label de projet en label de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. À côté de **S'abonner**, sélectionnez les trois points ({{< icon name="ellipsis_v" >}}) et sélectionnez **Promouvoir en tant que label de groupe**.

Tous les tickets, les merge requests, les listes du tableau des tickets, les filtres du tableau des tickets et les abonnements aux labels avec les anciens labels sont assignés au nouveau label de groupe.

Le nouveau label de groupe possède le même ID que l'ancien label de projet.

## Promouvoir un label de sous-groupe vers le groupe parent {#promote-a-subgroup-label-to-the-parent-group}

{{< history >}}

- Le rôle minimum pour promouvoir un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Il n'est pas possible de promouvoir directement un label de groupe vers le groupe parent. Pour y parvenir, utilisez la solution de contournement suivante.

Prérequis :

- Il doit exister un groupe contenant des sous-groupes (« groupe parent »).
- Il doit exister un sous-groupe dans le groupe parent qui possède un label que vous souhaitez promouvoir.
- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour les deux groupes.

Pour « promouvoir » le label vers le groupe parent :

1. Dans le groupe parent, [créez un label](#create-a-group-label) avec le même nom que celui d'origine. Nous vous recommandons de lui attribuer une couleur différente pour ne pas confondre les deux lors de cette opération.
1. Dans le sous-groupe, [affichez ses labels](#view-group-labels). Vous devriez voir les deux labels et leur provenance :

   ![labels du groupe parent et du sous-groupe dans la liste des labels du sous-groupe](img/promote_to_parent_group_workaround_v14_10.png)

1. À côté du label du sous-groupe (l'ancien), sélectionnez **Tickets**, **Requêtes de fusion** ou **Épopées**.
1. Ajoutez le nouveau label aux tickets, aux merge requests et aux epics qui ont l'ancien label. Pour aller plus vite, utilisez [la modification en masse](issues/managing_issues.md#bulk-edit-issues).
1. Dans le sous-groupe ou le groupe parent, [supprimez le label](#delete-a-group-label) qui appartient au groupe de niveau inférieur.

Vous devriez maintenant avoir un label dans le groupe parent qui porte le même nom que l'ancien, et qui a été ajouté aux mêmes tickets, merge requests et epics.

## Générer les labels de projet par défaut {#generate-default-project-labels}

{{< history >}}

- Le rôle minimum pour générer les labels par défaut a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Si un projet ou son groupe parent ne possède pas de labels, vous pouvez générer un jeu de labels de projet par défaut à partir de la page de liste des labels.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Le projet ne doit avoir aucun label.

Pour ajouter les labels par défaut au projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. Sélectionnez **Générer un jeu de labels par défaut**.

Les labels suivants sont créés :

- `bug`
- `confirmed`
- `critical`
- `discussion`
- `documentation`
- `enhancement`
- `suggestion`
- `support`

## Labels à portée limitée {#scoped-labels}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les équipes peuvent utiliser des labels à portée limitée pour annoter les tickets, les merge requests et les epics avec des labels mutuellement exclusifs. En empêchant l'utilisation conjointe de certains labels, vous pouvez créer des workflows plus complexes.

![Une liste de labels à portée limitée.](img/labels_key_value_v13_5.png)

Un label à portée limitée utilise la syntaxe avec double deux-points (`::`) dans son titre, par exemple : `workflow::in-review`.

Un ticket, une merge request ou un epic ne peut pas avoir deux labels à portée limitée, de la forme `key::value`, avec le même `key`. Si vous ajoutez un nouveau label avec le même `key` mais une `value` différente, l'ancien label `key` est remplacé par le nouveau label.

<div class="video-fallback">
  Voir la vidéo : <a href="https://www.youtube.com/watch?v=7l7tnEva6I8">Labels à portée limitée - Configurer votre organisation avec GitLab</a>.
</div>
<figure class="video-container">
  <iframe src="https://www.youtube-nocookie.com/embed/7l7tnEva6I8" frameborder="0" allowfullscreen> </iframe>
</figure>

### Filtrer par labels à portée limitée {#filter-by-scoped-labels}

Pour filtrer les listes de tickets, de merge requests ou d'epics selon une portée donnée, saisissez `<scope>::*` dans le nom du label recherché.

Par exemple, le filtrage par le label `platform::*` renvoie les tickets qui ont les labels `platform::iOS`, `platform::Android` ou `platform::Linux`.

> [!note]
> Le filtrage par labels à portée limitée n'est pas disponible sur les pages du tableau de bord des tickets ou des merge requests.

### Exemples de labels à portée limitée {#scoped-labels-examples}

**Exemple 1**. Mise à jour de la priorité d'un ticket :

1. Vous décidez qu'un ticket est de faible priorité et vous lui assignez le label `priority::low`.
1. Après un examen plus approfondi, vous réalisez que la priorité du ticket est plus élevée et vous lui assignez le label `priority::high`.
1. Comme un ticket ne doit pas avoir deux labels de priorité en même temps, GitLab supprime le label `priority::low`.

**Exemple 2**. Vous souhaitez créer un champ personnalisé dans les tickets pour suivre la plateforme de système d'exploitation ciblée par vos fonctionnalités, où chaque ticket ne doit cibler qu'une seule plateforme.

Vous créez trois labels :

- `platform::iOS`
- `platform::Android`
- `platform::Linux`

Si vous assignez l'un de ces labels à un ticket, il supprime automatiquement tout autre label existant qui commence par `platform::`.

**Exemple 3**. Vous pouvez utiliser des labels à portée limitée pour représenter les états de workflow de vos équipes.

Supposons que vous ayez les labels suivants :

- `workflow::development`
- `workflow::review`
- `workflow::deployed`

Si un ticket a déjà le label `workflow::development` et qu'un développeur souhaite indiquer que le ticket est désormais en cours de révision, il assigne le label `workflow::review`, et le label `workflow::development` est supprimé.

La même chose se produit lorsque vous déplacez des tickets entre des listes de labels dans un [tableau des tickets](issue_board.md). Avec les labels à portée limitée, les membres de l'équipe qui ne travaillent pas dans un tableau des tickets peuvent également faire avancer les états de workflow de manière cohérente dans les tickets eux-mêmes.

Pour une explication en vidéo, voir :

<div class="video-fallback">
  Voir la vidéo : <a href="https://www.youtube.com/watch?v=4BCBby6du3c">Utiliser des labels à portée limitée pour des champs personnalisés et des workflows personnalisés</a>.
</div>
<figure class="video-container">
  <iframe src="https://www.youtube-nocookie.com/embed/4BCBby6du3c" frameborder="0" allowfullscreen> </iframe>
</figure>

### Portées imbriquées {#nested-scopes}

Vous pouvez créer un label avec une portée imbriquée en utilisant plusieurs doubles deux-points `::` lors de sa création. Dans ce cas, tout ce qui précède le dernier `::` constitue la portée.

Par exemple, si votre projet possède ces labels :

- `workflow::backend::review`
- `workflow::backend::development`
- `workflow::frontend::review`

Un ticket ne peut pas avoir à la fois les labels `workflow::backend::review` et `workflow::backend::development` en même temps, car ils partagent la même portée : `workflow::backend`.

En revanche, un ticket peut avoir à la fois les labels `workflow::backend::review` et `workflow::frontend::review` en même temps, car ils ont des portées différentes : `workflow::frontend` et `workflow::backend`.

## Recevoir des notifications lorsqu'un label est utilisé {#receive-notifications-when-a-label-is-used}

Vous pouvez vous abonner à un label pour [recevoir des notifications](../profile/notifications.md) chaque fois que le label est assigné à un ticket, une merge request ou un epic.

Pour vous abonner à un label :

1. [Affichez la page de liste des labels.](#view-available-labels)
1. À droite de n'importe quel label, sélectionnez **S'abonner**.
1. Facultatif. Si vous vous abonnez à un label de groupe depuis un projet, sélectionnez l'une des options suivantes :
   - **S'abonner au niveau du projet** pour être notifié des événements dans ce projet.
   - **S'abonner au niveau du groupe** pour être notifié des événements dans l'ensemble du groupe.

## Définir la priorité du label {#set-label-priority}

{{< history >}}

- Le rôle minimum pour définir la priorité d'un label a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Les labels peuvent avoir des priorités relatives, utilisées lorsque vous triez les listes de tickets et de merge requests par [priorité du label](issues/sorting_issue_lists.md#sorting-by-label-priority) et par [priorité](issues/sorting_issue_lists.md#sorting-by-priority).

Lors de la priorisation des labels, vous devez le faire depuis un projet. Il n'est pas possible de le faire depuis la liste des labels du groupe.

> [!note]
> Le tri par priorité est basé uniquement sur le label de priorité la plus élevée. [Le ticket 14523](https://gitlab.com/gitlab-org/gitlab/-/issues/14523) envisage de modifier ce comportement.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour prioriser un label :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Labels**.
1. À côté du label que vous souhaitez prioriser, sélectionnez l'étoile ({{< icon name="star-o" >}}).

![Une liste de labels définis comme prioritaires.](img/labels_prioritized_v13_5.png)

Ce label apparaît désormais en haut de la liste des labels, sous **Labels prioritaires**.

Pour modifier la priorité relative de ces labels, faites-les glisser vers le haut ou vers le bas de la liste. Les labels placés plus haut dans la liste ont une priorité plus élevée.

Pour en savoir plus sur le tri par priorité ou par priorité du label, consultez [le tri et l'ordre des listes de tickets](issues/sorting_issue_lists.md).

## Verrouiller les labels lors de la fusion d'une merge request {#lock-labels-when-a-merge-request-is-merged}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/408676) dans GitLab 16.3 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `enforce_locked_labels_on_merge`. Cette fonctionnalité est en [version bêta](../../policy/development_stages_support.md). Fonctionnalité désactivée par défaut.
- Le rôle minimum pour verrouiller les labels a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Pour se conformer à certaines exigences d'audit, vous pouvez définir un label comme verrouillé. Lorsqu'une merge request avec des labels verrouillés est fusionnée, personne ne peut les supprimer de la merge request.

Lorsque vous ajoutez des labels verrouillés à des tickets ou à des epics, ils se comportent comme des labels ordinaires.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet ou le groupe.

> [!warning]
> Une fois qu'un label est défini comme verrouillé, personne ne peut annuler cette action ni supprimer le label.

Pour définir un label à verrouiller lors de la fusion :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre projet.
1. Sélectionnez **Gérer** > **Labels**.
1. À côté du label que vous souhaitez modifier, sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Modifier**.
1. Cochez la case **Verrouiller la label après la fusion d'une requête de fusion**.
1. Sélectionnez **Enregistrer les modifications**.

## Événements d'audit pour les labels {#audit-events-for-labels}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> - [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/415036) dans GitLab 18.11.

GitLab enregistre des [événements d'audit](../compliance/audit_event_types.md) lorsque vous créez, mettez à jour ou supprimez des labels de projet et de groupe. Utilisez ces événements pour suivre les modifications des labels à des fins de débogage ou de conformité.

Les actions suivantes sur les labels génèrent des événements d'audit :

- `label_created` : un label de projet ou de groupe est créé.
- `label_updated` : un label de projet ou de groupe est mis à jour. Lorsque le titre change, le message d'audit inclut l'ancien et le nouveau titre (par exemple, `Changed label title from Foo to Bar`). Pour les autres modifications de champs, le message est générique (par exemple, `Updated label Foo`).
- `label_deleted` : un label de projet ou de groupe est supprimé.

> [!note]
> Les labels que GitLab crée automatiquement, par exemple lors des imports Jira, ne génèrent pas d'événements d'audit. Seuls les labels créés par une action directe de l'utilisateur font l'objet d'un audit.

## Sujets connexes {#related-topics}

- Tutoriels :
  - [Configurer un projet unique pour le triage des tickets](../../tutorials/issue_triage/_index.md)
  - [Configurer des tableaux des tickets pour la passation entre équipes](../../tutorials/boards_for_teams/_index.md)
- [Administration des labels](../../administration/labels.md)
