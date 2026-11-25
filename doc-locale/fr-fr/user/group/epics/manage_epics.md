---
stage: Plan
group: Portfolio Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Gérer les epics
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Cette page rassemble les instructions pour toutes les actions que vous pouvez effectuer avec les [epics](_index.md) ou en lien avec ceux-ci.

Pour obtenir des informations sur la gestion des éléments enfants d'un epic, consultez [éléments enfants](../../work_items/child_items.md).

## Créer un epic {#create-an-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.
- L'attribution de jalons aux epics a été [introduite](https://gitlab.com/groups/gitlab-org/-/work_items/329) dans GitLab 18.2.
- L'attribution de poids aux epics a été [introduite](https://gitlab.com/groups/gitlab-org/-/work_items/12273) dans GitLab 18.11.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic.

Pour créer un epic dans le groupe auquel vous appartenez :

1. Accédez au formulaire Nouvel epic :
   - Accédez à votre groupe et, dans la barre latérale gauche, sélectionnez **Éléments de travail**. Puis sélectionnez **Nouvel élément**.
   - Depuis un epic de votre groupe, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}). Puis sélectionnez **Nouvel élément associé**.
   - Depuis n'importe où, dans le menu supérieur, sélectionnez **Nouvelle** ({{< icon name="plus-square" >}}). Puis sélectionnez **Nouvel élément de travail**.
   - Dans un [roadmap](../roadmap/_index.md) vide, sélectionnez **Nouvel élément de travail**.

1. Dans la liste déroulante **Type**, sélectionnez **Épopée** si cette option n'est pas déjà sélectionnée.
1. Remplissez les champs.
   - Saisissez un titre.
   - Saisissez une description.
   - Pour [rendre l'epic confidentiel](#make-an-epic-confidential), cochez la case en regard de **Activer la confidentialité**.
   - Choisissez des labels.
   - Sélectionnez une date de début et une date d'échéance, ou [héritez](#start-and-due-date-inheritance)-les.
   - Sélectionnez une [couleur](#epic-color).
1. Sélectionnez **Créer une épopée**.

L'epic nouvellement créé s'ouvre.

### Héritage des dates de début et d'échéance {#start-and-due-date-inheritance}

Si vous sélectionnez **Hérité** :

- Pour la **date de début** : GitLab analyse tous les epics enfants et les tickets affectés à l'epic, et définit la date de début pour correspondre à la date de début la plus ancienne trouvée dans les epics enfants ou le jalon attribué aux éléments enfants.
- Pour la **date d'échéance** : GitLab analyse tous les epics enfants et les tickets affectés à l'epic, et définit la date d'échéance pour correspondre à la date d'échéance la plus récente trouvée dans les epics enfants ou le jalon attribué aux éléments enfants.

Ces dates sont dynamiques et recalculées si l'un des événements suivants se produit :

- Les dates d'un epic enfant changent.
- Des jalons sont réaffectés à un ticket.
- Les dates d'un jalon changent.
- Des tickets sont ajoutés à l'epic ou en sont supprimés.

Étant donné que les dates de l'epic peuvent hériter des dates de ses enfants, la date de début et la date d'échéance se propagent du bas vers le haut. Si la date de début d'un epic enfant au niveau le plus bas change, celle-ci devient la date de début possible la plus ancienne pour son epic parent. La date de début de l'epic parent reflète alors ce changement et se propage vers le haut jusqu'à l'epic supérieur.

## Modifier un epic {#edit-an-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Après avoir créé un epic, vous pouvez modifier les détails suivants :

- Titre
- Description
- Date de début
- Date d'échéance
- Labels
- Jalon
- [Couleur](#epic-color)

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic.

Pour modifier le titre ou la description d'un epic :

1. Sélectionner **Éditer**.
1. Effectuez vos modifications.
1. Sélectionnez **Enregistrer les modifications**.

Pour modifier la date de début, la date d'échéance, le jalon ou les labels d'un epic :

1. En regard de chaque section de la barre latérale droite, sélectionnez **Modifier**.
1. Sélectionnez les dates, le jalon ou les labels de votre epic.

### Réorganiser les éléments de liste dans la description de l'epic {#reorder-list-items-in-the-epic-description}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Lorsque vous consultez un epic dont la description contient une liste, vous pouvez également réorganiser les éléments de la liste.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur de l'epic, ou être assigné à l'epic.
- La description de l'epic doit comporter une liste [ordonnée ou non ordonnée](../../markdown.md#lists), ou une liste de [tâches](../../markdown.md#task-lists).

Pour réorganiser les éléments de liste lors de la consultation d'un epic :

1. Survolez la ligne de l'élément de liste pour rendre visible l'icône de poignée ({{< icon name="grip" >}}).
1. Sélectionnez l'icône de poignée et maintenez-la enfoncée.
1. Faites glisser la ligne vers sa nouvelle position dans la liste.
1. Relâchez l'icône de poignée.

### Modification en masse des epics {#bulk-edit-epics}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.
- [Ajout](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/200186) d'attributs de modification en masse supplémentaires dans GitLab 18.3.
- [Ajout](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/204037) de la prise en charge de la modification en masse pour l'attribut parent dans GitLab 18.5.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic parent.

Pour mettre à jour plusieurs epics en même temps :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Épopée**.
1. Sélectionnez **Modification en masse**. Sur la droite, une barre latérale avec des champs modifiables apparaît.
1. Cochez les cases en regard de chaque epic que vous souhaitez modifier.
1. Dans la barre latérale, modifiez les champs disponibles.
1. Sélectionnez **Mettre à jour la sélection**.

Lors de la modification en masse d'epics dans un groupe, vous pouvez modifier les attributs suivants :

- État (ouvert ou fermé)
- [Assignés](#assignees)
- [Labels](../../project/labels.md)
- [État de santé](#health-status)
- Abonnement aux [notifications](../../profile/notifications.md)
- [Confidentialité](#make-an-epic-confidential)
- [Jalon](../../project/milestones/_index.md)
- [Parent](../../work_items/child_items.md#add-a-parent-epic-to-an-epic)

## Empêcher la troncature des descriptions avec **En savoir plus** {#prevent-truncating-descriptions-with-read-more}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181184) dans GitLab 17.10.

{{< /history >}}

Si la description d'un epic est longue, GitLab n'en affiche qu'une partie. Pour afficher la description complète, vous devez sélectionner **En savoir plus**. Cette troncature facilite la recherche d'autres éléments sur la page sans avoir à faire défiler un texte long.

Pour modifier le comportement de troncature des descriptions :

1. Sur un epic, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Activez ou désactivez **Tronquer les descriptions** selon votre préférence.

Ce paramètre est mémorisé et affecte tous les tickets, les tâches, les epics, les objectifs et les résultats clés.

## Masquer la barre latérale droite {#hide-the-right-sidebar}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181184) dans GitLab 17.10.

{{< /history >}}

Les attributs de l'epic sont affichés dans une barre latérale à droite de la description lorsque l'espace le permet.

Pour masquer la barre latérale et augmenter l'espace disponible pour la description :

1. Sur un epic, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Masquer la barre latérale**.

Ce paramètre est mémorisé et affecte tous les tickets, les tâches, les epics, les objectifs et les résultats clés.

Pour afficher à nouveau la barre latérale :

- Répétez les étapes précédentes et sélectionnez **Afficher la barre latérale**.

## Assignés {#assignees}

{{< details >}}

- Offre : GitLab.com, GitLab Self-Managed

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/epics/4231) dans GitLab 17.4 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `work_items_beta`. Fonctionnalité désactivée par défaut. Cette fonctionnalité est en [version bêta](../../../policy/development_stages_support.md#beta).
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/551805) dans GitLab 18.2. Déplacé depuis le feature flag `work_items_beta`.

{{< /history >}}

Un epic peut être attribué à un ou plusieurs utilisateurs.

Les assignés peuvent être modifiés aussi souvent que nécessaire. L'idée est que les assignés sont les personnes responsables de l'epic.

Si un utilisateur n'est pas membre d'un groupe, un epic ne peut lui être attribué que si un autre membre du groupe l'assigne.

### Modifier l'assigné d'un epic {#change-assignee-on-an-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe.

Pour modifier l'assigné d'un epic :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Épopée**.
1. Sélectionnez votre epic pour le consulter.
1. Dans la barre latérale droite, dans la section **Personnes assignées**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez les utilisateurs à ajouter en tant qu'assigné.
1. Sélectionnez n'importe quelle zone en dehors de la liste déroulante.

L'assigné est modifié sans qu'il soit nécessaire de rafraîchir la page.

## Couleur de l'epic {#epic-color}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate

{{< /details >}}

{{< history >}}

- La couleur personnalisable a été [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/394864) dans GitLab 17.5.

{{< /history >}}

Vous pouvez définir une couleur pour un epic afin de catégoriser et de prioriser les tâches visuellement. Utilisez les couleurs pour :

- Associer les epics à des équipes ou à des initiatives d'entreprise.
- Indiquer les niveaux dans la hiérarchie des epics.
- Regrouper les epics associés.

Les couleurs des epics sont visibles dans les [roadmaps](../roadmap/_index.md) et les [tableaux d'epics](epic_boards.md).

Dans les roadmaps, les barres de chronologie correspondent à la couleur de l'epic :

![Epics différenciés par couleur dans la v17.0](img/epic_color_roadmap_v17_0.png)

Dans les tableaux d'epics, la couleur apparaît sur l'accent de la carte de l'epic :

![Cartes accentuées avec la couleur de leur epic associé dans la v17.0](img/epic_accent_boards_v17_0.png)

### Modifier la couleur d'un epic {#change-an-epics-color}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic.

Pour modifier la couleur d'un epic :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Épopée**.
1. Sélectionnez un epic.
1. Dans la barre latérale droite, dans la section **Couleur**, sélectionnez **Modifier**.
1. Sélectionnez une couleur existante ou saisissez une valeur RGB ou hexadécimale.
1. Sélectionnez n'importe quelle zone en dehors de la boîte de dialogue.

La couleur de l'epic est mise à jour.

## Supprimer un epic {#delete-an-epic}

{{< history >}}

- Le rôle Planificateur est [autorisé](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) à supprimer un epic dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur ou Owner pour le groupe de l'epic.

Pour supprimer un epic :

1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}), puis **Supprimer l'epic**.
1. Sélectionnez **Supprimer**. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer l'epic**.

La suppression d'un epic libère tous les tickets existants de leur epic associé dans le système.

## Fermer un epic {#close-an-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic.

Pour fermer un epic :

- Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}), puis **Fermer l'epic**.

Vous pouvez également utiliser l'[action rapide `/close`](../../project/quick_actions.md#close).

## Rouvrir un epic fermé {#reopen-a-closed-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez rouvrir un epic qui a été fermé.

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic.

Pour ce faire, vous pouvez :

- Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) puis **Rouvrir l'epic**.
- Utiliser l'[action rapide `/reopen`](../../project/quick_actions.md#reopen).

Vous pouvez également créer un epic en [promouvant un ticket](../../project/issues/managing_issues.md#promote-an-issue-to-an-epic).

## Accéder à un epic depuis un ticket {#go-to-an-epic-from-an-issue}

Si un ticket appartient à un epic, vous pouvez accéder à l'epic parent depuis :

- Le fil d'Ariane en haut du ticket.
- La section **Parent** dans la barre latérale droite.

## Afficher la liste des epics {#view-epics-list}

Prérequis :

- Vous devez être membre de l'un des éléments suivants :
  - Le groupe
  - Un projet dans le groupe
  - Un projet dans l'un des groupes descendants du groupe

Pour afficher les epics dans un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Épopée**.

Pour définir quels attributs sont affichés pour les epics dans la liste des epics, [configurez les préférences d'affichage](../../work_items/_index.md#configure-list-display-preferences).

### Qui peut afficher un epic {#who-can-view-an-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

La possibilité de consulter un epic dépend du [niveau de visibilité du groupe](../../public_access.md) et du [statut de confidentialité](#make-an-epic-confidential) de l'epic :

- Groupe public et epic non confidentiel : tout le monde peut consulter l'epic.
- Groupe privé et epic non confidentiel : vous devez disposer du rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe, ou être membre d'un projet du groupe ou de l'un de ses groupes descendants.
- Epic confidentiel (quelle que soit la visibilité du groupe) : vous devez disposer au minimum du rôle Planificateur pour le groupe.

L'autorisation de consulter un epic n'est pas la même que l'autorisation de consulter ses éléments enfants. Dans la section **Éléments enfants**, vous ne voyez que les éléments que vous êtes autorisé à consulter. Le nombre d'éléments et la progression incluent les éléments que vous ne pouvez pas consulter. Pour plus d'informations, consultez [afficher le nombre et le poids des tickets dans un epic](../../work_items/child_items.md#view-count-and-weight-of-issues-in-an-epic).

### Ouvrir les epics dans un panneau coulissant {#open-epics-in-a-drawer}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/464698) dans GitLab 17.4 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `work_item_view_for_issues`. Activés par défaut.
- Le basculement entre le panneau coulissant et la vue en pleine page a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/536620) dans GitLab 18.2.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/500367) dans GitLab 18.6. Le feature flag `epics_list_drawer` a été supprimé.

{{< /history >}}

Lorsque vous sélectionnez un epic depuis la page des éléments de travail ou un tableau d'epics, il s'ouvre dans un panneau de détails. Vous pouvez alors consulter et modifier ses détails sans perdre le contexte de la liste ou du tableau d'epics.

Lors de l'utilisation du panneau coulissant :

- Sélectionnez un epic dans la liste pour l'ouvrir dans le panneau coulissant.
- Le panneau coulissant apparaît sur le côté droit de l'écran.
- Vous pouvez modifier l'epic directement dans le panneau coulissant.
- Pour fermer le panneau coulissant, sélectionnez l'icône de fermeture ({{< icon name="close" >}}) ou appuyez sur **Échappement**.

#### Ouvrir un epic en vue pleine page {#open-an-epic-in-full-page-view}

Pour ouvrir un epic en vue pleine page :

- Ouvrez l'epic dans un nouvel onglet. Depuis la liste des éléments de travail, vous pouvez :
  - Faire un clic droit sur l'epic et l'ouvrir dans un nouvel onglet du navigateur.
  - Maintenir <kbd>Command</kbd> ou <kbd>Control</kbd> enfoncé et sélectionner l'epic.
- Sélectionnez un epic et, depuis le panneau coulissant, vous pouvez :
  - Dans le coin supérieur gauche, sélectionnez la référence du ticket, par exemple `my_project#123`.
  - Dans le coin supérieur droit, sélectionnez **Ouvrir en plein écran** ({{< icon name="maximize" >}}).

Pour toujours ouvrir les éléments de travail en vue pleine page, consultez [définir la préférence d'ouverture des éléments dans un panneau coulissant](../../work_items/_index.md#configure-list-display-preferences).

## Filtrer une liste d'epics {#filter-a-list-of-epics}

{{< history >}}

- Le filtrage par champs personnalisés a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/525462) dans GitLab 17.11.

{{< /history >}}

Vous pouvez filtrer une liste d'epics par :

- Titre ou description (sélectionnez **Rechercher dans**)
- Nom d'auteur / nom d'utilisateur
- Confidentialité
- Groupes
- Santé
- Labels
- Les jalons
- Emoji de réaction
- Parent
- Abonné
- [Champs personnalisés](../../work_items/custom_fields.md) activés pour les epics

Pour filtrer :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Épopée**.
1. Sélectionnez des filtres, des opérateurs et des valeurs supplémentaires selon vos besoins. Pour rechercher par titre ou description, saisissez du texte dans la barre de filtres.
1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez la loupe ({{< icon name="search" >}}).

### Filtrer avec l'opérateur OR {#filter-with-the-or-operator}

{{< history >}}

- Le filtrage OR pour les labels et les auteurs a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/382969) dans GitLab 15.9 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `or_issuable_queries`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com et GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/104292) dans GitLab 15.9.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/296031) dans GitLab 17.0. Le feature flag `or_issuable_queries` a été supprimé.

{{< /history >}}

Vous pouvez utiliser l'opérateur OR (**est l'un des : `||`**) lorsque vous [filtrez la liste des epics](#filter-a-list-of-epics) par :

- Assigné
- Auteur
- Label

`is one of` représente un OR inclusif. Par exemple, si vous filtrez par `Label is one of Deliverable` et `Label is one of UX`, GitLab affiche les epics avec le label `Deliverable`, `UX`, ou les deux.

## Trier la liste des epics {#sort-the-list-of-epics}

Vous pouvez trier la liste des epics par :

- Date de création
- Date de mise à jour
- Date de fermeture
- Date d'échéance du jalon
- Date d'échéance
- Popularité
- Titre
- Date de début
- Santé
- Bloquant

Chaque option contient un bouton permettant de basculer l'ordre entre **Croissant** et **Décroissant**. L'option et l'ordre de tri sont enregistrés et utilisés partout où vous parcourez les epics, y compris dans le [roadmap](../roadmap/_index.md).

## Modifier l'ordre de tri de l'activité {#change-activity-sort-order}

Vous pouvez inverser l'ordre par défaut et interagir avec le flux d'activité trié par éléments les plus récents en haut. Votre préférence est enregistrée dans le stockage local et appliquée automatiquement à chaque epic et ticket que vous consultez.

Pour modifier l'ordre de tri de l'activité, sélectionnez la liste déroulante **Plus ancien en premier** et choisissez d'afficher en premier les éléments les plus anciens ou les plus récents.

## Rendre un epic confidentiel {#make-an-epic-confidential}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Si vous travaillez sur des éléments contenant des informations privées, vous pouvez rendre un epic confidentiel.

> [!note]
> Un epic confidentiel ne peut contenir que des [tickets confidentiels](../../project/issues/confidential_issues.md) et des epics enfants confidentiels. Cependant, les merge requests sont publiques si elles sont créées dans un projet public. Pour créer une merge request confidentielle, consultez [les merge requests pour les tickets confidentiels](../../project/merge_requests/confidential.md).

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe de l'epic.

Pour rendre un epic confidentiel :

- **Lors de la création d'un epic** : cochez la case en regard de **Activer la confidentialité**.
- **Dans un epic existant** : dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}). Puis sélectionnez **Activer la confidentialité**.

Vous pouvez également utiliser l'[action rapide `/confidential`](../../project/quick_actions.md#confidential).

## Gérer les tickets affectés à un epic {#manage-issues-assigned-to-an-epic}

Cette section rassemble les instructions pour toutes les actions que vous pouvez effectuer avec les [tickets](../../project/issues/_index.md) en lien avec les epics.

### État de santé {#health-status}

{{< details >}}

- Édition : GitLab Ultimate

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/epics/9002) dans GitLab 17.5.

{{< /history >}}

Utilisez l'état de santé sur les epics pour obtenir un aperçu rapide de la progression du projet. L'état de santé vous aide à communiquer et à gérer les problèmes potentiels de manière proactive.

Vous pouvez consulter l'état de santé d'un epic dans la vue de l'epic et dans les sections **Éléments enfants** et **Éléments liés**.

Vous pouvez définir l'état de santé sur :

- Dans les délais (vert)
- Nécessite une attention (orange)
- À risque (rouge)

Pour répondre aux risques liés à la livraison dans les délais de votre travail planifié, intégrez une révision de l'état de santé de l'epic dans vos :

- Réunions quotidiennes de suivi
- Rapports d'avancement du projet
- Réunions hebdomadaires

#### Modifier l'état de santé d'un epic {#change-health-status-of-an-epic}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe.

Pour modifier l'état de santé d'un epic :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Épopée**.
1. Sélectionnez un epic.
1. Dans la barre latérale droite, dans la section **État de santé**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez un statut.

L'état de santé de l'epic est mis à jour.

Vous pouvez également définir et effacer les états de santé à l'aide des actions rapides [`/health_status`](../../project/quick_actions.md#health_status) et [`/clear_health_status`](../../project/quick_actions.md#clear_health_status).

### Participants {#participants}

Les participants sont les utilisateurs qui ont interagi avec un epic. Pour obtenir des informations sur la consultation des participants, consultez [participants](../../participants.md).

## Sujets connexes {#related-topics}

- [Éléments liés](../../work_items/linked_items.md)
- [Éléments enfants](../../work_items/child_items.md)
- [Poids](../../work_items/weight.md)
