---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Apprenez à gérer les tickets GitLab, notamment la modification, le déplacement, la clôture, les opérations en masse et l'utilisation de diverses fonctionnalités telles que les personnes assignées, l'état de santé et l'automatisation."
title: Gérer les tickets
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les tickets GitLab vous aident à suivre le travail et à collaborer avec votre équipe. Vous pouvez gérer les tickets pour :

- Modifier des détails tels que le titre, la description, les personnes assignées et les métadonnées.
- Déplacer des tickets entre des projets tout en conservant leur contexte et leur historique.
- Clore les tickets terminés et les rouvrir si nécessaire.
- Utiliser la modification en masse pour mettre à jour plusieurs tickets efficacement.
- Suivre l'état de santé des tickets pour surveiller la progression et identifier les risques.

Pour plus d'informations sur la gestion des éléments enfants d'un ticket, voir [éléments enfants](../../work_items/child_items.md).

## Modifier un ticket {#edit-an-issue}

{{< history >}}

- Le rôle minimum pour modifier un ticket a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez modifier le titre et la description d'un ticket.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur du ticket ou être assigné au ticket.

Pour modifier un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. À droite du titre, sélectionnez **Modifier**.
1. Modifiez les champs disponibles.
1. Sélectionnez **Enregistrer les modifications**.

### Remplir un ticket avec la génération de description de ticket {#populate-an-issue-with-issue-description-generation}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Module d'extension : GitLab Duo Enterprise
- Offre : GitLab.com
- Statut : version expérimentale

{{< /details >}}

{{< collapsible title="Informations sur le modèle" >}}

- LLM par défaut : Anthropic [Claude Sonnet 4.6](https://console.cloud.google.com/agent-platform/publishers/anthropic/model-garden/claude-sonnet-4-6)
- Non disponible sur GitLab Duo avec les modèles auto-hébergés

{{< /collapsible >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/epics/10762) dans GitLab 16.3 en tant que [version expérimentale](../../../policy/development_stages_support.md#experiment).
- Obligation de disposer du module d'extension GitLab Duo à partir de GitLab 17.6.
- Disponibilité étendue à GitLab Premium dans GitLab 18.0.

{{< /history >}}

Générez une description détaillée pour un ticket à partir d'un court résumé que vous fournissez.

<i class="fa-youtube-play" aria-hidden="true"></i> [Visionner une présentation](https://www.youtube.com/watch?v=-BWBQat7p5M)
<!-- Video published on 2024-12-18 -->

Prérequis :

- Vous devez appartenir à au moins un groupe pour lequel le [paramètre de fonctionnalités expérimentales et bêta](../../gitlab_duo/turn_on_off.md#turn-on-beta-and-experimental-features) est activé.
- Vous devez avoir l'autorisation de créer un ticket.
- Disponible uniquement pour l'éditeur de texte brut.
- Disponible uniquement lors de la création d'un nouveau ticket. Pour une proposition visant à ajouter la prise en charge de la génération de descriptions lors de la modification de tickets existants, voir le [ticket 474141](https://gitlab.com/gitlab-org/gitlab/-/issues/474141).

Pour générer une description de ticket :

1. Créez un nouveau ticket.
1. Au-dessus de la zone de texte **Description**, sélectionnez **GitLab Duo** ({{< icon name="tanuki-ai" >}}) > **Générer une description du ticket**.
1. Rédigez une courte description et sélectionnez **Envoyer**.

La description du ticket est remplacée par un texte généré par IA.

Donnez votre avis sur cette fonctionnalité expérimentale dans le [ticket 409844](https://gitlab.com/gitlab-org/gitlab/-/issues/409844).

**Utilisation des données** : lorsque vous utilisez cette fonctionnalité, le texte que vous saisissez est envoyé au grand modèle de langage.

## Modification en masse des tickets {#bulk-edit-issues}

{{< history >}}

- Le rôle minimum pour modifier des tickets en masse a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.
- [Ajout](https://gitlab.com/gitlab-org/gitlab/-/issues/520791) d'autres attributs de modification en masse dans GitLab 18.7.

{{< /history >}}

Vous pouvez modifier plusieurs tickets à la fois lorsque vous êtes dans un groupe ou un projet.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe ou le projet.

Pour modifier plusieurs tickets en même temps :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.
1. Sélectionnez **Modification en masse**. Sur la droite, une barre latérale avec des champs modifiables apparaît.
1. Cochez les cases à côté de chaque ticket que vous souhaitez modifier.
1. Dans la barre latérale, modifiez les champs disponibles.
1. Sélectionnez **Mettre à jour la sélection**.

Lors de la modification en masse des tickets, vous pouvez modifier les attributs suivants :

- État (ouvert ou fermé)
- [Statut](../../work_items/status.md)
- [Assignés](#assignees)
- [Labels](../labels.md)
- [État de santé](#health-status)
- Abonnement aux [notifications](../../profile/notifications.md)
- [Confidentialité](confidential_issues.md)
- [Itération](../../group/iterations/_index.md)
- [Jalon](../milestones/_index.md)
- Élément parent
- [Déplacer vers un autre projet](#move-an-issue)

## Déplacer un ticket {#move-an-issue}

{{< history >}}

- Le rôle minimum pour déplacer un ticket a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Lorsque vous déplacez un ticket, il est clôturé et copié dans le projet cible. Le ticket d'origine n'est pas supprimé. Une [note système](../system_notes.md), indiquant d'où il provient et où il est allé, est ajoutée aux deux tickets.

GitLab copie également les fichiers joints à la description ou aux commentaires du ticket dans le projet cible. Étant donné que les [fichiers téléversés sont limités à la portée d'un projet](../../../security/user_file_uploads.md), GitLab crée chaque copie avec une nouvelle URL secrète dans le projet cible :

- Les liens directs vers les URL des pièces jointes d'origine renvoient une erreur `404`.
- Les fichiers copiés sont répertoriés dans les [téléversements Markdown](../../../api/project_markdown_uploads.md) du projet cible, et non dans ceux du projet source.

Soyez prudent lorsque vous déplacez un ticket vers un projet avec des règles d'accès différentes. Avant de déplacer le ticket, assurez-vous qu'il ne contient pas de données sensibles.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour déplacer un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) > **Déplacer**.
1. Recherchez un projet vers lequel déplacer le ticket.
1. Sélectionnez **Déplacer**.

Vous pouvez également utiliser l'[action rapide `/move`](../quick_actions.md#move) dans un commentaire ou une description.

### Déplacer des tickets en masse {#bulk-move-issues}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Le rôle minimum pour déplacer des tickets en masse a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

#### Depuis la liste des éléments de travail {#from-the-work-items-list}

Vous pouvez déplacer plusieurs tickets en même temps lorsque vous êtes dans un projet. Vous ne pouvez pas déplacer des tâches ou des cas de test.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour déplacer plusieurs tickets en même temps :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.
1. Sélectionnez **Modification en masse**. Sur la droite, une barre latérale avec des champs modifiables apparaît.
1. Cochez les cases à côté de chaque ticket que vous souhaitez déplacer.
1. Dans la liste déroulante **Déplacer**, sélectionnez le projet de destination.
1. Sélectionnez **Déplacer les éléments**.

#### Depuis la console Rails {#from-the-rails-console}

Vous pouvez déplacer tous les tickets ouverts d'un projet vers un autre.

Prérequis :

- Vous devez avoir accès à la console Rails de l'instance GitLab.

Pour ce faire :

1. Facultatif (mais recommandé). [Créez une sauvegarde](../../../administration/backup_restore/_index.md) avant d'effectuer toute modification dans la console.
1. Ouvrez la [console Rails](../../../administration/operations/rails_console.md).
1. Exécutez le script suivant. Assurez-vous de remplacer `project`, `admin_user` et `target_project` par vos valeurs.

   ```ruby
   project = Project.find_by_full_path('full path of the project where issues are moved from')
   issues = project.issues
   admin_user = User.find_by_username('username of admin user') # make sure user has permissions to move the issues
   target_project = Project.find_by_full_path('full path of target project where issues moved to')

   issues.each do |issue|
      if issue.state != "closed" && issue.moved_to.nil?
         Issues::MoveService.new(container: project, current_user: admin_user).execute(issue, target_project)
      else
         puts "issue with id: #{issue.id} and title: #{issue.title} was not moved"
      end
   end; nil
   ```

1. Pour quitter la console Rails, entrez `quit`.

## Listes de description et listes de tâches {#description-lists-and-task-lists}

Lorsque vous utilisez des listes ordonnées, des listes non ordonnées ou des listes de tâches dans les descriptions de tickets, vous pouvez :

- Réorganiser tous les éléments de la liste par glisser-déposer.
- Supprimer des éléments de liste de tâches.
- [Convertir des éléments de liste de tâches en éléments de travail de type tâche](../../tasks.md#from-a-task-list-item).

### Supprimer un élément de liste de tâches {#delete-a-task-list-item}

Prérequis :

- Vous devez avoir le rôle Reporter, Developer, Maintainer ou Owner pour le projet, ou être l'auteur ou la personne assignée du ticket.

Dans une description de ticket avec des éléments de liste de tâches :

1. Passez le curseur sur un élément de liste de tâches et sélectionnez le menu d'options ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Supprimer**.

L'élément de liste de tâches est supprimé de la description du ticket. Tout élément de liste de tâches imbriqué est remonté d'un niveau d'imbrication.

### Réorganiser les éléments de liste dans la description du ticket {#reorder-list-items-in-the-issue-description}

{{< history >}}

- Le rôle minimum pour réorganiser les éléments de liste dans la description du ticket a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.
- L'annulation des opérations de glisser des éléments de liste avec <kbd>Esc</kbd> a été [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248854) dans GitLab 19.3.

{{< /history >}}

Lorsque vous consultez un ticket qui contient une liste dans la description, vous pouvez également réorganiser les éléments de la liste.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur du ticket ou être assigné au ticket.
- La description du ticket doit contenir une liste [ordonnée ou non ordonnée](../../markdown.md#lists), ou une liste de [tâches](../../markdown.md#task-lists).

Pour réorganiser les éléments de liste, lors de la consultation d'un ticket :

1. Passez le curseur sur la ligne de l'élément de liste pour rendre visible l'icône de poignée ({{< icon name="grip" >}}).
1. Sélectionnez et maintenez l'icône de poignée.
1. Faites glisser la ligne vers la nouvelle position dans la liste.
1. Relâchez l'icône de poignée.

Pour annuler la réorganisation, appuyez sur <kbd>Esc</kbd> avant de relâcher l'icône de poignée.

## Clore un ticket {#close-an-issue}

{{< history >}}

- Le rôle minimum pour clore un ticket a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Lorsque vous décidez qu'un ticket est résolu ou n'est plus nécessaire, vous pouvez le clore. Le ticket est marqué comme fermé mais n'est pas supprimé.

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur du ticket ou être assigné au ticket.

Pour clore un ticket, vous pouvez :

- Dans un [tableau des tickets](../issue_board.md), faites glisser une carte de ticket de sa liste vers la liste **Fermé**.
- Depuis toute autre page de l'interface GitLab :
  1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
  1. Sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
  1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) puis **Clore le ticket**.

Vous pouvez également utiliser l'[action rapide `/close`](../quick_actions.md#close) dans un commentaire ou une description.

### Rouvrir un ticket fermé {#reopen-a-closed-issue}

{{< history >}}

- Le rôle minimum pour rouvrir un ticket fermé a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur du ticket ou être assigné au ticket.

Pour rouvrir un ticket fermé, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) puis **Rouvrir le ticket**. Un ticket rouvert n'est pas différent d'un autre ticket ouvert.

Vous pouvez également utiliser l'[action rapide `/reopen`](../quick_actions.md#reopen) dans un commentaire ou une description.

### Clôture automatique des tickets {#closing-issues-automatically}

Vous pouvez clore des tickets automatiquement en utilisant certains mots, appelés _modèle de clôture_, dans un message de commit ou dans la description d'une merge request. Les administrateurs de GitLab Self-Managed peuvent [modifier le modèle de clôture par défaut](../../../administration/issue_closing_pattern.md).

Si un message de commit ou une description de merge request contient un texte correspondant au [modèle de clôture](#default-closing-pattern), tous les tickets référencés dans le texte correspondant sont clôturés lorsque :

- Le commit est poussé vers la [branche **par défaut**](../repository/branches/default.md) d'un projet.
- Le commit ou la merge request est fusionné(e) dans la branche par défaut.

Par exemple, si vous incluez `Closes #4, #6, Related to #5` dans une description de merge request :

- Les tickets `#4` et `#6` sont clôturés automatiquement lors de la fusion de la merge request.
- Le ticket `#5` est marqué comme un [ticket lié](related_issues.md), mais il n'est pas clôturé automatiquement.

Sinon, lorsque vous [créez une merge request à partir d'un ticket](../merge_requests/creating_merge_requests.md#from-an-issue), elle hérite du jalon et des labels du ticket.

Pour des raisons de performance, la clôture automatique des tickets est désactivée pour le tout premier push depuis un dépôt existant.

#### Responsabilité de l'utilisateur lors d'une fusion {#user-responsibility-when-merging}

Lorsque vous fusionnez une merge request, il vous incombe de vérifier qu'il est approprié de clore les tickets ciblés. Les utilisateurs peuvent inclure des modèles de clôture de tickets dans la description de la merge request, ainsi que dans le corps d'un message de commit. Les messages de clôture dans les messages de commit sont moins visibles. Dans les deux cas, le widget de la merge request affiche des informations sur le ticket à clore lors de la fusion :

![Cette merge request clôt le ticket n° 2754.](img/closing_pattern_v17_4.png)

Lorsque vous fusionnez une merge request, GitLab vérifie que vous disposez des autorisations nécessaires pour clore les tickets ciblés par un modèle de clôture. Dans les dépôts publics, cette vérification est importante, car les utilisateurs externes peuvent créer des merge requests et des commits contenant des modèles de clôture. Lorsque vous êtes l'utilisateur qui fusionne, il est important que vous soyez conscient des effets de la fusion sur le code et les tickets de votre projet.

Vous pouvez également lier un ticket à une merge request sans modèle de clôture. Utilisez l'API GraphQL ou le widget **Éléments de travail** de la merge request. Pour les liens créés de l'une ou l'autre manière, GitLab vérifie vos autorisations au moment de la création du lien, et non lors de la fusion de la merge request. Le lien persiste, de sorte que le ticket se clôture toujours lors de la fusion, même si vous perdez l'accès au projet du ticket. Pour plus d'informations, voir [lier des éléments de travail manuellement](../../work_items/_index.md#link-work-items-manually).

Lorsque la [fusion automatique](../merge_requests/auto_merge.md) est activée pour une merge request, aucune modification supplémentaire ne peut être apportée à la liste des tickets qui sont automatiquement clôturés.

#### Modèle de clôture par défaut {#default-closing-pattern}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/465391) des références d'éléments de travail (tâche, objectif ou résultat clé) dans GitLab 17.3.

{{< /history >}}

Pour clore automatiquement un ticket, utilisez les mots-clés suivants, suivis de la référence du ticket.

Mots-clés disponibles :

- `Close`, `Closes`, `Closed`, `Closing`, `close`, `closes`, `closed`, `closing`
- `Fix`, `Fixes`, `Fixed`, `Fixing`, `fix`, `fixes`, `fixed`, `fixing`
- `Resolve`, `Resolves`, `Resolved`, `Resolving`, `resolve`, `resolves`, `resolved`, `resolving`
- `Implement`, `Implements`, `Implemented`, `Implementing`, `implement`, `implements`, `implemented`, `implementing`

Formats de référence de ticket disponibles :

- Un ticket local (`#123`).
- Un ticket inter-projets (`group/project#123`).
- L'URL complète d'un ticket (`https://gitlab.example.com/<project_full_path>/-/issues/123`).
- L'URL complète d'un élément de travail (par exemple, tâche, objectif ou résultat clé) :
  - Dans un projet (`https://gitlab.example.com/<project_full_path>/-/work_items/123`).
  - Dans un groupe (`https://gitlab.example.com/groups/<group_full_path>/-/work_items/123`).

Par exemple :

```plaintext
Awesome commit message

Fix #20, Fixes #21 and Closes group/otherproject#22.
This commit is also related to #17 and fixes #18, #19
and https://gitlab.example.com/group/otherproject/-/issues/23.
```

Le message de commit précédent clôt `#18`, `#19`, `#20` et `#21` dans le projet vers lequel ce commit est poussé, et `#22` et `#23` dans `group/otherproject`. `#17` n'est pas clôturé car il ne correspond pas au modèle.

Vous pouvez utiliser les modèles de clôture dans des messages de commit multi-lignes ou en une seule ligne depuis la ligne de commande avec `git commit -m`.

L'expression régulière du modèle de clôture de ticket par défaut :

```shell
\b((?:[Cc]los(?:e[sd]?|ing)|\b[Ff]ix(?:e[sd]|ing)?|\b[Rr]esolv(?:e[sd]?|ing)|\b[Ii]mplement(?:s|ed|ing)?)(:?) +(?:(?:issues? +)?%{issue_ref}(?:(?: *,? +and +| *,? *)?)|([A-Z][A-Z0-9_]+-\d+))+)
```

#### Désactiver la clôture automatique des tickets {#disable-automatic-issue-closing}

Vous pouvez désactiver la fonctionnalité de clôture automatique des tickets pour chaque projet dans les [paramètres du projet](#disable-automatic-issue-closing).

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.

Pour désactiver la clôture automatique des tickets :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Dépôt**.
1. Développez **Paramètres par défaut des branches**.
1. Décochez la case **Fermer automatiquement les tickets référencés sur la branche par défaut**.
1. Sélectionnez **Enregistrer les modifications**.

Les tickets référencés sont toujours affichés, mais ne sont pas clôturés automatiquement.

La modification de ce paramètre s'applique uniquement aux nouvelles merge requests ou aux nouveaux commits. Les tickets déjà fermés restent tels quels. La désactivation de la clôture automatique des tickets s'applique uniquement aux tickets du projet dans lequel le paramètre a été désactivé. Les merge requests et les commits de ce projet peuvent toujours clore les tickets d'un autre projet.

#### Personnaliser le modèle de clôture des tickets {#customize-the-issue-closing-pattern}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Prérequis :

- Vous devez disposer d'un [accès administrateur](../../../administration/_index.md) à votre instance GitLab.

Apprenez à modifier le [modèle de clôture de ticket](../../../administration/issue_closing_pattern.md) par défaut de votre installation.

## Empêcher la troncature des descriptions avec **En savoir plus** {#prevent-truncating-descriptions-with-read-more}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181184) dans GitLab 17.10.

{{< /history >}}

Si la description d'un ticket est longue, GitLab n'en affiche qu'une partie. Pour voir la description complète, vous devez sélectionner **En savoir plus**. Cette troncature facilite la recherche d'autres éléments sur la page sans avoir à faire défiler un texte long.

Pour modifier la troncature des descriptions :

1. Sur un ticket, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Activez ou désactivez **Tronquer les descriptions** selon vos préférences.

Ce paramètre est mémorisé et s'applique à tous les tickets, tâches, epics, objectifs et résultats clés.

## Masquer la barre latérale droite {#hide-the-right-sidebar}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181184) dans GitLab 17.10.

{{< /history >}}

Les attributs du ticket sont affichés dans une barre latérale à droite de la description lorsque l'espace le permet.

Pour masquer la barre latérale et augmenter l'espace disponible pour la description :

1. Sur un ticket, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Masquer la barre latérale**.

Ce paramètre est mémorisé et s'applique à tous les tickets, tâches, epics, objectifs et résultats clés.

Pour afficher à nouveau la barre latérale :

- Répétez les étapes précédentes et sélectionnez **Afficher la barre latérale**.

## Supprimer un ticket {#delete-an-issue}

{{< history >}}

- Le rôle requis pour supprimer un ticket a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Owner à Owner ou Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Planificateur ou Owner pour un projet.

Pour supprimer un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Supprimer le ticket**.

## Modifier le type de ticket {#change-the-issue-type}

{{< history >}}

- Le rôle minimum pour modifier le type de ticket a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.
- La conversion de tickets en résultats clés, objectifs et tâches a été [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/520791) dans GitLab 18.7.

{{< /history >}}

Prérequis :

- Vous devez être l'auteur du ticket ou avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur du ticket ou être assigné au ticket.

Pour modifier le type de ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Changer de type**.
1. Dans la liste déroulante **Type**, sélectionnez le nouveau type :

   - Résultat clé
   - Objectif
   - Tâche
   - Épopée (déplace le ticket vers le groupe parent). Pour plus d'informations, voir [promouvoir un ticket en épopée](#promote-an-issue-to-an-epic).

1. Sélectionnez **Changer de type**.

Pour promouvoir un ticket en incident, voir [promouvoir un ticket en incident](#promote-an-issue-to-an-incident)

### Promouvoir un ticket en épopée {#promote-an-issue-to-an-epic}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Le rôle minimum pour promouvoir un ticket en épopée a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez promouvoir un ticket en [epic](../../group/epics/_index.md) dans le groupe parent immédiat.

La promotion d'un ticket confidentiel en epic crée un [epic confidentiel](../../group/epics/manage_epics.md#make-an-epic-confidential), préservant ainsi la confidentialité.

Lorsqu'un ticket est promu en epic :

- Un epic est créé dans le même groupe que le projet du ticket.
- Les abonnés du ticket sont informés de la création de l'epic.

Les métadonnées suivantes du ticket sont copiées dans l'epic :

- Titre, description, activité et fils de discussion des commentaires.
- Votes positifs et négatifs.
- Participants.
- Labels de groupe associés au ticket.
- Élément parent.

Prérequis :

- Le projet auquel appartient le ticket doit être dans un groupe.
- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le groupe parent immédiat du projet.
- Vous devez soit :
  - Avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
  - Être l'auteur du ticket.
  - Être assigné au ticket.

Pour promouvoir un ticket en épopée :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**, et sélectionnez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Changer de type**
1. Dans la liste déroulante **Type**, sélectionnez **Épopée**.
1. Sélectionnez **Changer de type**.

Vous pouvez également utiliser l'[action rapide `/promote_to Epic`](../quick_actions.md#promote_to).

### Promouvoir un ticket en incident {#promote-an-issue-to-an-incident}

Vous pouvez utiliser l'[action rapide `/promote_to Incident`](../quick_actions.md#promote_to) pour promouvoir le ticket en [incident](../../../operations/incident_management/incidents.md).

## Ajouter un ticket à une itération {#add-an-issue-to-an-iteration}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour ajouter un ticket à une [itération](../../group/iterations/_index.md) :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans la barre latérale droite, dans la section **Itération**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez l'itération à laquelle ajouter ce ticket.
1. Sélectionnez n'importe quelle zone en dehors de la liste déroulante.

Pour ajouter un ticket à une itération, vous pouvez également :

- Utiliser l'[action rapide `/iteration`](../quick_actions.md#iteration).
- Faire glisser un ticket dans une liste d'itération d'un tableau.
- Modifier des tickets en masse depuis la liste **Éléments de travail**.

## Afficher tous les tickets qui vous sont assignés {#view-all-issues-assigned-to-you}

Pour afficher tous les tickets qui vous sont assignés :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Dans la liste déroulante, sélectionnez **Tickets qui me sont assignés**.

Ou :

- Pour utiliser un [raccourci clavier](../../shortcuts.md), appuyez sur <kbd>Shift</kbd>+<kbd>i</kbd>.
- Dans le coin supérieur droit, sélectionnez **Éléments de travail assignés** ({{< icon name="work-items" >}}).

## Liste des tickets {#issue-list}

La liste des tickets affiche tous les tickets de votre projet ou groupe. Vous pouvez l'utiliser pour afficher, trier et gérer les tickets.

Pour afficher la liste des tickets :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.

Pour définir les attributs affichés dans la liste **Éléments de travail**, [configurez les préférences d'affichage](../../work_items/_index.md#configure-list-display-preferences).

Depuis la liste des tickets, vous pouvez :

- Consulter les détails des tickets, tels que le titre, les personnes assignées, les labels et le jalon.
- [Trier les tickets](sorting_issue_lists.md) selon différents critères.
- Filtrer les tickets pour en trouver des spécifiques.
- Modifier les tickets individuellement ou en masse.
- Créer de nouveaux tickets.

Les sections suivantes décrivent comment utiliser la liste des tickets.

### Filtrer la liste des tickets {#filter-the-list-of-issues}

{{< history >}}

- Le filtrage OR est [généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/issues/296031) dans GitLab 17.0. Le feature flag `or_issuable_queries` a été supprimé.
- Le filtrage de la liste des tickets par statut personnalisé ou par élément parent a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/520791) dans GitLab 18.7.
- Le filtrage par date de création, date de clôture, date d'échéance et date de mise à jour est [généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/issues/17758) dans GitLab 19.4. Le feature flag `issue_date_filter` a été supprimé.

{{< /history >}}

Pour filtrer la liste des tickets :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.
1. Sélectionnez des filtres, opérateurs et valeurs supplémentaires selon vos besoins. Les filtres suivants sont disponibles :
   - Personne assignée
   - Auteur
   - Date de clôture
   - Confidentiel
   - [Contact](../../crm/_index.md)
   - Date de création
   - Date d'échéance
   - [État de santé](#health-status)
   - Itération
   - Label
   - Jalon
   - Ma réaction
   - [Organisation](../../crm/_index.md)
   - [Parent](../../group/epics/_index.md)
   - Release
   - Rechercher dans (titres ou descriptions)
   - Statut
   - Abonné
   - Type
   - Date de mise à jour
   - Poids
   - [Champs personnalisés](../../work_items/custom_fields.md)
1. Sélectionnez ou saisissez l'opérateur à utiliser pour filtrer l'attribut. Les opérateurs suivants sont disponibles :
   - `=` : est
   - `!=` : n'est pas l'un de
   - `||` : est l'un de (pour Personne assignée, Auteur, Label, Type). Fonctionne comme un OU inclusif. Par exemple, si vous filtrez par `Assignee is one of Sidney Jones` et `Assignee is one of Zhang Wei`, GitLab affiche les tickets où `Sidney`, `Zhang` ou les deux sont des personnes assignées.
1. Saisissez le texte par lequel filtrer l'attribut. Vous pouvez filtrer certains attributs par **Aucun** ou **Tout**.
1. Répétez ce processus pour filtrer par plusieurs attributs. Les attributs multiples sont joints par un `AND` logique.
1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez l'icône de recherche ({{< icon name="search" >}}).

#### Filtrer par titre ou description {#filter-by-title-or-description}

Pour filtrer la liste des tickets par un texte dans un titre ou une description :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.
1. Dans la barre de filtres, saisissez votre phrase de recherche.
1. Dans la liste déroulante qui apparaît, sélectionnez **Recherchez ce texte**.
1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez l'icône de recherche ({{< icon name="search" >}}).

Le filtrage des tickets utilise la [recherche plein texte PostgreSQL](https://www.postgresql.org/docs/16/textsearch-intro.html) pour faire correspondre des mots significatifs à une requête.

Par exemple, si vous recherchez `I am securing information for M&A`, GitLab peut renvoyer des résultats contenant `securing`, `secured` ou `information` dans le titre ou la description. Cependant, GitLab ne fait pas correspondre exactement la phrase ou les mots `I`, `am` ou `M&A`, car ils ne sont pas considérés comme lexicalement significatifs. C'est une limitation de la recherche plein texte PostgreSQL.

#### Filtrer les tickets par ID {#filter-issues-by-id}

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.
1. Dans la barre de filtres, saisissez `#` suivi de l'ID du ticket. Par exemple, entrez `#362255` pour n'afficher que le ticket 362255.
1. Sélectionnez **Recherchez ce texte**.
1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez l'icône de recherche ({{< icon name="search" >}}).

### Ouvrir des tickets dans un panneau {#open-issues-in-a-panel}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/464063) dans GitLab 17.4 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `issues_list_drawer`. Fonctionnalité désactivée par défaut.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/463829) dans GitLab 18.6. Le feature flag `issues_list_drawer` a été supprimé.

{{< /history >}}

Lorsque vous sélectionnez un ticket dans la liste ou dans un tableau des tickets, il s'ouvre dans un panneau de détails.

Vous pouvez ensuite consulter et modifier ses détails sans perdre le contexte de la liste ou du tableau.

Lors de l'utilisation du panneau :

- Sélectionnez un ticket dans la liste pour l'ouvrir dans le panneau.
- Le panneau apparaît sur le côté droit de l'écran.
- Vous pouvez modifier le ticket directement dans le panneau.
- Pour fermer le panneau, sélectionnez l'icône de fermeture ({{< icon name="close" >}}) ou appuyez sur **Échappement**.

#### Ouvrir un ticket en vue pleine page {#open-an-issue-in-full-page-view}

Pour ouvrir le ticket en vue complète :

- Ouvrez le ticket dans un nouvel onglet. Depuis la liste des tickets, soit :
  - Faites un clic droit sur le ticket et ouvrez-le dans un nouvel onglet du navigateur.
  - Maintenez <kbd>Command</kbd> ou <kbd>Control</kbd> enfoncé et sélectionnez le ticket.
- Sélectionnez un ticket et, depuis le panneau, soit :
  - Dans le coin supérieur gauche, sélectionnez la référence du ticket, par exemple `my_project#123`.
  - Dans le coin supérieur droit, sélectionnez **Ouvrir en plein écran** ({{< icon name="maximize" >}}).

Pour toujours ouvrir les tickets en vue pleine page, [configurez vos préférences d'affichage de liste](../../work_items/_index.md#configure-list-display-preferences).

### S'abonner à un flux RSS de la liste des tickets {#subscribe-to-an-rss-feed-of-the-issue-list}

Vous pouvez vous abonner à un flux RSS de la liste des tickets. Le flux reflète tous les filtres appliqués à la liste.

Pour vous abonner à un flux RSS de la liste des tickets d'un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Planifier** > **Éléments de travail**, puis filtrez par **Type** = **Ticket**.
1. Facultatif. Appliquez les filtres souhaités.
1. Dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **S'abonner au flux RSS**.

Pour vous abonner à un flux RSS de la liste des tickets d'un groupe, suivez les mêmes étapes. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe au lieu d'un projet. Pour votre liste de tickets personnelle, dans la barre latérale gauche, sélectionnez **Votre travail** > **Éléments de travail**, puis utilisez les mêmes **Actions** > **S'abonner au flux RSS**.

L'URL du flux contient un [jeton de flux](../../../security/tokens/_index.md#feed-token) qui vous authentifie en tant que lecteur de flux.

## Copier la référence du ticket {#copy-issue-reference}

Pour référencer un ticket ailleurs dans GitLab, vous pouvez utiliser son URL complète ou une référence courte, qui ressemble à `namespace/project-name#123`, où `namespace` est soit un groupe soit un nom d'utilisateur.

Pour copier la référence du ticket dans votre presse-papiers :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) > **Copier la référence**.

Vous pouvez maintenant coller la référence dans une autre description ou un commentaire.

Pour plus d'informations, voir [les références spécifiques à GitLab](../../markdown.md#gitlab-specific-references).

## Copier l'adresse e-mail du ticket {#copy-issue-email-address}

Vous pouvez créer un commentaire dans un ticket en envoyant un e-mail. L'envoi d'un e-mail à cette adresse crée un commentaire contenant le corps de l'e-mail.

Pour plus d'informations sur la création de commentaires par e-mail et la configuration nécessaire, voir [répondre à un commentaire par e-mail](../../discussions/_index.md#reply-to-a-comment-by-sending-email).

Pour copier l'adresse e-mail du ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) > **Copier l'adresse e-mail du ticket**.

## Personnes assignées {#assignees}

Un ticket peut être assigné à un ou [plusieurs utilisateurs](multiple_assignees_for_issues.md).

Les personnes assignées peuvent être modifiées aussi souvent que nécessaire. L'idée est que les personnes assignées sont responsables du ticket. Lorsqu'un ticket est assigné à quelqu'un, il apparaît sur la page **Éléments de travail assignés** de cette personne.

Si un utilisateur n'est pas membre d'un projet, un ticket ne peut lui être assigné que s'il le crée lui-même ou si un autre membre du projet l'assigne.

### Modifier la personne assignée d'un ticket {#change-assignee-on-an-issue}

{{< history >}}

- Le rôle minimum pour modifier la personne assignée a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour modifier la personne assignée d'un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans la barre latérale droite, dans la section **Personne assignée** ou **Personnes assignées**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez les utilisateurs à assigner.
1. Sélectionnez **Appliquer** ou cliquez n'importe où en dehors de la liste déroulante.

La personne assignée est modifiée sans avoir à actualiser la page.

## Tickets similaires {#similar-issues}

Pour éviter les doublons de tickets sur le même sujet, GitLab recherche des tickets similaires lorsque vous créez un nouveau ticket.

Lorsque vous saisissez du texte dans la zone de titre de la page **Nouveau ticket**, GitLab recherche les titres et les descriptions de tous les tickets du projet actuel. Seuls les tickets auxquels vous avez accès sont renvoyés. Jusqu'à cinq tickets similaires, triés par mise à jour la plus récente, sont affichés sous la zone de texte du titre.

## État de santé {#health-status}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour mieux suivre les risques liés à l'atteinte de vos objectifs, vous pouvez attribuer un état de santé à chaque ticket. Vous pouvez utiliser l'état de santé pour indiquer aux autres membres de votre organisation si les tickets progressent comme prévu ou nécessitent une attention particulière pour rester dans les délais.

Intégrez une revue de l'état de santé des tickets à votre réunion quotidienne, vos rapports d'avancement du projet ou vos réunions hebdomadaires afin de traiter les risques liés à la livraison dans les délais de votre travail planifié.

### Modifier l'état de santé d'un ticket {#change-health-status-of-an-issue}

{{< history >}}

- Le rôle minimum pour modifier l'état de santé a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour modifier l'état de santé d'un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans la barre latérale droite, dans la section **État de santé**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez le statut à ajouter à ce ticket :

   - Dans les temps
   - Attention requise
   - À risque

Vous pouvez consulter l'état de santé du ticket dans :

- La liste **Éléments de travail**
- La section **Éléments enfants** de l'epic
- Les cartes de tickets dans les tableaux des tickets

Une fois qu'un ticket est clôturé, son état de santé ne peut plus être modifié et **Modifier** n'est pas disponible tant que le ticket n'est pas rouvert.

Vous pouvez également définir et effacer les états de santé à l'aide des actions rapides [`/health_status`](../quick_actions.md#health_status) et [`/clear_health_status`](../quick_actions.md#clear_health_status).

## Statut {#status}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/543862) dans GitLab 18.2 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `work_item_status_feature_flag`. Activés par défaut.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/521286) dans GitLab 18.4. Le feature flag `work_item_status_feature_flag` a été supprimé.

{{< /history >}}

<!-- Turn off the future tense test because of "won't do". -->
<!-- vale gitlab_base.FutureTense = NO -->

Vous pouvez attribuer un statut aux tickets pour suivre leur progression dans votre workflow. Le statut offre un suivi plus précis que les états de base ouvert/fermé, vous permettant d'utiliser des étapes spécifiques telles que **En cours**, **Terminé** ou **Ne sera pas fait**.

Pour plus d'informations sur la configuration des statuts personnalisés, voir la [section sur les statuts](../../work_items/status.md).

<!-- vale gitlab_base.FutureTense = YES -->

### Modifier le statut {#change-status}

Prérequis :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet, être l'auteur du ticket ou être assigné au ticket.

Pour modifier le statut d'un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans la barre latérale droite, dans la section **Statut**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez le statut.

Le statut du ticket est mis à jour immédiatement.

Vous pouvez consulter le statut du ticket dans :

- La liste **Éléments de travail**
- La section **Éléments enfants** d'un epic
- Les cartes dans les tableaux des tickets

Vous pouvez également définir le statut à l'aide de l'[action rapide `/status`](../quick_actions.md#status).

## Participants {#participants}

Les participants sont les utilisateurs qui ont interagi avec un ticket. Pour plus d'informations sur la consultation des participants, voir [participants](../../participants.md).

## Publier un ticket {#publish-an-issue}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Si une application de page de statut est associée au projet, vous pouvez utiliser l'[action rapide `/publish`](../quick_actions.md#publish) pour publier le ticket.

Pour plus d'informations, voir [GitLab Status Page](../../../operations/incident_management/status_page.md).

## Actions rapides liées aux tickets {#issue-related-quick-actions}

Vous pouvez également utiliser des actions rapides pour gérer les tickets.

Certaines actions ne disposent pas encore de boutons correspondants dans l'interface. Vous pouvez effectuer les actions suivantes uniquement en utilisant des actions rapides :

- [Ajouter ou supprimer une réunion Zoom](associate_zoom_meeting.md) ([`/zoom` et `/remove_zoom`](../quick_actions.md#zoom)).
- [Publier un ticket](#publish-an-issue) ([`/publish`](../quick_actions.md#publish)).
- Cloner un ticket dans le même projet ou dans un autre projet ([`/clone`](../quick_actions.md#clone)).
- Clore un ticket et le marquer comme doublon d'un autre ticket ([`/duplicate`](../quick_actions.md#duplicate)).
- Copier les labels et le jalon d'une autre merge request ou d'un autre ticket dans le projet ([`/copy_metadata`](../quick_actions.md#copy_metadata)).

## Sujets connexes {#related-topics}

- [Éléments liés](../../work_items/linked_items.md)
- [Éléments enfants](../../work_items/child_items.md)
