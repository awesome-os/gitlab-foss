---
stage: AI Coding
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Commentaires et fils de discussion
description: Utilisez les commentaires et les fils de discussion pour discuter et gérer les conversations sur les éléments de travail.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Les commentaires et fils de discussion sur les pages Wiki [introduits](https://gitlab.com/groups/gitlab-org/-/epics/14461) dans GitLab 17.7 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `wiki_comments`. Désactivé par défaut.
- Les commentaires et fils de discussion sur les pages Wiki [généralement disponibles](https://gitlab.com/gitlab-org/gitlab/-/issues/502847) dans GitLab 17.9. Le feature flag `wiki_comments` a été supprimé.

{{< /history >}}

GitLab encourage la communication via les commentaires, les fils de discussion et [la suggestion de modifications de code](../project/merge_requests/reviews/suggestions.md). Les commentaires prennent en charge [Markdown](../markdown.md) et les [actions rapides](../project/quick_actions.md).

Deux types de commentaires sont disponibles :

- Un commentaire standard.
- Un commentaire dans un fil de discussion, que vous pouvez [résoudre](../project/merge_requests/_index.md#manage-comment-threads).

Vous pouvez [suggérer des modifications de code](../project/merge_requests/reviews/suggestions.md) dans votre commentaire de diff de commit, que l'utilisateur peut accepter via l'interface utilisateur.

## Emplacements où vous pouvez ajouter des commentaires {#places-you-can-add-comments}

Vous pouvez créer des commentaires dans des emplacements tels que :

- Diffs de commits.
- Commits.
- Designs.
- Epics
- Tickets
- Merge requests
- Extraits de code.
- Tâches.
- OKR.
- Pages wiki

Chaque objet peut contenir jusqu'à 5 000 commentaires.

## Mentions {#mentions}

Vous pouvez mentionner un utilisateur ou un groupe (y compris les [sous-groupes](../group/subgroups/_index.md#mention-subgroups)) dans votre instance GitLab avec `@username` ou `@groupname`. GitLab notifie tous les utilisateurs mentionnés par des éléments de la liste de tâches et des e-mails. Les utilisateurs peuvent modifier ce paramètre dans les [paramètres de notification](../profile/notifications.md).

Vous pouvez rapidement identifier les commentaires qui vous concernent, car GitLab met en évidence les mentions vous ciblant (l'utilisateur actuellement authentifié) dans une couleur différente.

Lorsque vous mentionnez quelqu'un dans un élément de travail ou une merge request, cette personne devient un [participant](../participants.md).

### Mentionner tous les membres {#mentioning-all-members}

{{< history >}}

- [Feature flag](../../administration/feature_flags/_index.md) nommé `disable_all_mention` [introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/110586) dans GitLab 16.1. Activé sur GitLab.com. Désactivé sur GitLab Self-Managed et GitLab Dedicated.
- [Activé sur GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/work_items/415280) dans GitLab 18.8.5.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/work_items/415280) du feature flag `disable_all_mention` dans GitLab 19.0.

{{< /history >}}

Évitez de mentionner `@all` dans les commentaires et les descriptions. `@all` mentionne non seulement les participants du projet, du ticket ou de la merge request, mais tous les membres du groupe parent de ce projet. Tous ces utilisateurs reçoivent une notification par e-mail et un élément de la liste de tâches, et pourraient l'interpréter comme du spam.

La saisie de `@all` dans les commentaires et les descriptions génère du texte brut au lieu de mentionner tous les utilisateurs. Les mentions `@all` existantes dans le texte Markdown antérieures à cette modification restent inchangées et demeurent sous forme de liens.

Vous pouvez désactiver les notifications et les mentions dans les [paramètres du groupe](../group/manage.md#disable-email-notifications).

### Mentionner un groupe dans un ticket ou une merge request {#mention-a-group-in-an-issue-or-merge-request}

Lorsque vous mentionnez un groupe dans un commentaire, chaque membre du groupe reçoit un élément de la liste de tâches ajouté à sa liste de tâches.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Accédez à votre merge request ou votre ticket :
   - Pour les merge requests, sélectionnez **Code** > **Requêtes de fusion**, et trouvez votre merge request.
   - Pour les tickets, sélectionnez **Forfait** > **Éléments de travail**, et trouvez votre ticket.
1. Dans un commentaire, saisissez `@` suivi du nom d'utilisateur, du groupe ou de l'espace de nommage du sous-groupe. Par exemple, `@alex`, `@alex-team`, ou `@alex-team/marketing`.
1. Sélectionnez **Commentaire**.

GitLab crée un élément de la liste de tâches pour tous les membres du groupe et des sous-groupes.

Pour plus d'informations, consultez [mentionner les sous-groupes](../group/subgroups/_index.md#mention-subgroups).

## Ajouter un commentaire à un diff de merge request {#add-a-comment-to-a-merge-request-diff}

Lorsque vous ajoutez des commentaires à un diff de merge request, ces commentaires persistent, même lorsque vous :

- Effectuez un push forcé après un rebasage.
- Modifiez un commit.

Pour ajouter un commentaire de diff de commit :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion**, et trouvez votre merge request.
1. Sélectionnez l'onglet **Validation**, puis sélectionnez le message de commit.
1. Démarrez un commentaire :
   - Pour commenter l'intégralité d'un fichier, trouvez le fichier sur lequel vous souhaitez commenter et, dans l'en-tête du fichier, sélectionnez **Commenter ce fichier** ({{< icon name="comment" >}}).
   - Pour commenter des lignes spécifiques, trouvez le numéro de ligne sur lequel vous souhaitez commenter. Survolez le numéro de ligne, puis sélectionnez **Commentaire** ({{< icon name="comment" >}}). Pour sélectionner davantage de lignes, faites glisser l'icône **Commentaire** ({{< icon name="comment" >}}).
     - Lorsque le formulaire de commentaire s'affiche, vous pouvez [modifier la plage de lignes sélectionnées](#edit-the-comment-line-range).
1. Saisissez votre commentaire.
1. Soumettez votre commentaire :
   - Pour ajouter votre commentaire immédiatement, sélectionnez **Ajouter un commentaire**, ou utilisez le raccourci clavier :
     - macOS : <kbd>Shift</kbd>+<kbd>Command</kbd>+<kbd>Enter</kbd>
     - Tous les autres systèmes d'exploitation : <kbd>Shift</kbd>+<kbd>Control</kbd>+<kbd>Enter</kbd>
   - Pour laisser votre commentaire non publié jusqu'à la fin de votre révision, sélectionnez **Démarrer une révision**, ou utilisez le raccourci clavier :
     - macOS : <kbd>Command</kbd>+<kbd>Enter</kbd>
     - Tous les autres systèmes d'exploitation : <kbd>Control</kbd>+<kbd>Enter</kbd>

Le commentaire s'affiche dans l'onglet **Vue d'ensemble** de la merge request.

Le commentaire ne s'affiche pas sur la page **Code** > **Validation** de votre projet.

> [!note]
> Lorsque votre commentaire contient une référence à un commit inclus dans la merge request, il est converti en lien dans le contexte de la merge request. Par exemple, `28719b171a056960dfdc0012b625d0b47b123196` devient `28719b17` qui renvoie vers `https://gitlab.example.com/example-group/example-project/-/merge_requests/12345/diffs?commit_id=28719b171a056960dfdc0012b625d0b47b123196`.

### Modifier la plage de lignes du commentaire {#edit-the-comment-line-range}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/242736) dans GitLab 19.3 [avec un flag](../../administration/feature_flags/_index.md) nommé `rapid_diffs_on_mr_show`. Activé par défaut.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique.

Sur les merge requests avec les [diffs rapides](../project/merge_requests/changes.md#rapid-diffs) activés, lorsque le formulaire de commentaire est ouvert, vous pouvez modifier les lignes auxquelles le commentaire s'applique.

Vous ne pouvez modifier la plage de lignes que lors de la première création d'un commentaire. L'option n'est plus disponible après l'enregistrement.

Pour ajuster la plage de lignes du commentaire après avoir ouvert le formulaire de commentaire :

1. Sélectionnez **Modifier la plage de lignes** ({{< icon name="pencil" >}}) pour commencer la modification. Une poignée et un bouton d'annulation apparaissent sur la première ligne de la plage, et une autre poignée, qui reçoit le focus, apparaît sur la dernière ligne.
1. Utilisez votre souris ou votre clavier pour ajuster la plage.
   - Avec la souris, faites glisser l'une des poignées vers une nouvelle ligne.
   - Avec le clavier, utilisez les touches suivantes :

     | Touche | Action |
     |-----|--------|
     | <kbd>Gauche</kbd> | Déplace le focus vers la poignée de la première ligne. |
     | <kbd>Droite</kbd> | Déplace le focus vers la poignée de la dernière ligne. |
     | <kbd>Haut</kbd> | Déplace la poignée active vers le haut jusqu'à la ligne précédente pouvant accueillir un commentaire. |
     | <kbd>Bas</kbd> | Déplace la poignée active vers le bas jusqu'à la ligne suivante pouvant accueillir un commentaire. |
     | <kbd>Entrée</kbd> | Confirme la nouvelle plage. |
     | <kbd>Échap</kbd> | Annule la modification et conserve la plage précédente. |

Une poignée ne peut pas dépasser un saut de section dans le diff, indiqué par la syntaxe `@@`. Pour commenter sur plusieurs sections, ajoutez un commentaire distinct dans chacune d'elles.

## Répondre à un commentaire par e-mail {#reply-to-a-comment-by-sending-email}

Si vous avez configuré la [« réponse par e-mail »](../../administration/reply_by_email.md), vous pouvez répondre aux commentaires en envoyant un e-mail.

- Lorsque vous répondez à un commentaire standard, cela crée un autre commentaire standard.
- Lorsque vous répondez à un commentaire dans un fil de discussion, cela crée une réponse dans le fil de discussion.
- Lorsque vous [envoyez un e-mail à l'adresse e-mail d'un ticket](../project/issues/managing_issues.md#copy-issue-email-address), cela crée un commentaire standard.

Vous pouvez utiliser [Markdown](../markdown.md) et les [actions rapides](../project/quick_actions.md) dans vos réponses par e-mail.

### Expiration des réponses aux commentaires {#comment-reply-expiration}

Les réponses par e-mail qui créent des commentaires standard ou dans des fils de discussion sont soumises à une [politique de rétention](../../administration/reply_by_email.md#retention-policy-for-notifications) de deux ans.

## Modifier un commentaire {#edit-a-comment}

Vous pouvez modifier votre propre commentaire à tout moment. Toute personne disposant du rôle Maintainer ou Owner peut également modifier un commentaire rédigé par quelqu'un d'autre.

Pour modifier un commentaire :

1. Sur le commentaire, sélectionnez **Modifier le commentaire** ({{< icon name="pencil" >}}).
1. Effectuez vos modifications.
1. Sélectionnez **Enregistrer les modifications**.

### Modifier un commentaire pour ajouter une mention {#edit-a-comment-to-add-a-mention}

{{< history >}}

- Envoi d'e-mails de notification [introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/224837) dans GitLab 18.10 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `email_on_added_mentions`. Désactivé par défaut.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/591869) dans GitLab 18.11. Le feature flag `email_on_added_mentions` a été supprimé.

{{< /history >}}

Par défaut, lorsque vous mentionnez un utilisateur, GitLab [crée un élément de la liste de tâches](../todos.md#actions-that-create-to-do-items) pour cette personne et lui envoie un [e-mail de notification](../profile/notifications.md).

Si vous modifiez un commentaire existant pour y ajouter une mention d'utilisateur qui n'y figurait pas auparavant, GitLab :

- Crée un élément de la liste de tâches pour l'utilisateur mentionné.
- Envoie un e-mail de notification à l'utilisateur mentionné.

## Empêcher les commentaires en verrouillant la discussion {#prevent-comments-by-locking-the-discussion}

Vous pouvez empêcher les commentaires publics dans un ticket ou une merge request. Dans ce cas, seuls les membres du projet peuvent ajouter et modifier des commentaires.

Prérequis :

- Dans les merge requests, vous devez avoir le rôle Developer, Maintainer ou Owner.
- Dans les tickets, vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner.

Pour verrouiller un ticket ou une merge request :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Accédez à votre merge request ou votre ticket :
   - Pour les merge requests, sélectionnez **Code** > **Requêtes de fusion**, et trouvez votre merge request.
   - Pour les tickets, sélectionnez **Forfait** > **Éléments de travail**, et trouvez votre ticket.
1. Dans le coin supérieur droit, sélectionnez **Actions de requête de fusion** ou **Actions du ticket** ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Verrouiller la discussion**.

GitLab ajoute une note système aux détails de la page.

Vous devez déverrouiller toutes les discussions verrouillées dans les tickets ou les merge requests fermés avant de pouvoir les rouvrir.

## Commentaires sur les éléments confidentiels {#comments-on-confidential-items}

Seuls les utilisateurs autorisés à accéder à un élément confidentiel reçoivent des notifications pour les commentaires sur cet élément. Si l'élément n'était pas précédemment confidentiel, les utilisateurs sans accès peuvent apparaître comme participants. Ces utilisateurs ne reçoivent pas de notifications tant que l'élément est confidentiel.

Qui peut être notifié :

- Les utilisateurs assignés à l'élément, quel que soit leur rôle.
- Les utilisateurs qui ont créé l'élément, s'ils ont le rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner.
- Les utilisateurs ayant le rôle Planificateur, Reporter, Developer, Maintainer ou Owner dans le groupe ou le projet auquel appartient l'élément.

## Ajouter une note interne {#add-an-internal-note}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/538003) pour le Wiki GitLab dans GitLab 18.2.

{{< /history >}}

Utilisez les notes internes pour protéger les informations ajoutées à un ticket public, un epic, une page wiki ou une merge request. Les notes internes diffèrent des commentaires publics :

- Seuls les membres du projet disposant au minimum du rôle Reporter peuvent consulter la note interne.
- Vous ne pouvez pas convertir les notes internes en commentaires ordinaires.
- Toutes les réponses aux notes internes sont également internes.
- Les notes internes affichent un badge **Note interne** et sont présentées dans une couleur différente de celle des commentaires publics :

![Notes internes](img/add_internal_note_v16_9.png)

Prérequis :

- Vous devez avoir le rôle Reporter, Developer, Maintainer ou Owner pour le projet.

Pour ajouter une note interne :

1. Sur le ticket, l'epic, la page wiki ou la merge request, dans la zone de texte **Commentaire**, saisissez un commentaire.
1. Sous le commentaire, sélectionnez **Rendre cette note interne**.
1. Sélectionnez **Ajouter une note interne**.

Vous pouvez également marquer un [ticket entier comme confidentiel](../project/issues/confidential_issues.md), ou créer des [merge requests confidentielles](../project/merge_requests/confidential.md).

## Afficher uniquement les commentaires {#show-only-comments}

Dans les discussions comportant de nombreux commentaires, filtrez la discussion pour n'afficher que les commentaires ou l'historique des modifications ([notes système](../project/system_notes.md)). Les notes système comprennent les modifications apportées à la description, les mentions dans d'autres objets GitLab, ou les modifications des labels, des personnes assignées et du jalon. GitLab enregistre votre préférence et l'applique à chaque ticket, merge request ou epic que vous consultez.

1. Sur une merge request, un ticket ou un epic, sélectionnez l'onglet **Vue d'ensemble**.
1. Sur le côté droit de la page, dans la liste déroulante **Trier ou filtrer**, sélectionnez un filtre :
   - **Afficher toute l'activité** : affiche tous les commentaires des utilisateurs et les notes système.
   - **Afficher uniquement les commentaires** : affiche uniquement les commentaires des utilisateurs.
   - **Afficher uniquement l'historique** : affiche uniquement les notes d'activité.

## Modifier l'ordre de tri de l'activité {#change-activity-sort-order}

Inversez l'ordre par défaut et interagissez avec le flux d'activité trié par éléments les plus récents en haut. GitLab enregistre votre préférence dans le stockage local et l'applique à chaque ticket, merge request ou epic que vous consultez. Les tickets et les epics partagent la même préférence de tri, tandis que les merge requests maintiennent leur propre préférence distincte.

Pour modifier l'ordre de tri de l'activité :

1. Ouvrez un ticket, ou ouvrez l'onglet **Vue d'ensemble** dans une merge request ou un epic.
1. Faites défiler jusqu'au titre **Activité**.
1. Sur le côté droit de la page, modifiez l'ordre de tri :
   - **Tickets et epics** : dans la liste déroulante **Trier ou filtrer**, sélectionnez **Plus récent en premier** ou **Plus ancien en premier** (par défaut).
   - **Requêtes de fusion** : utilisez le bouton fléché de direction de tri pour basculer entre **Sens de tri : croissant** (plus ancien en premier, par défaut) ou **Sens de tri : décroissant** (plus récent en premier).

## Afficher l'historique des modifications de la description {#view-description-change-history}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez consulter les modifications apportées à la description dans l'historique.

Pour comparer les modifications, sélectionnez **Comparer avec la version précédente**.

## Assigner un ticket à l'auteur d'un commentaire {#assign-an-issue-to-the-commenting-user}

Vous pouvez assigner un ticket à un utilisateur qui a rédigé un commentaire.

1. Dans le commentaire, sélectionnez le menu **Plus d'actions** ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Assigner à l'auteur·e du commentaire**.
1. Pour désassigner le commentateur, sélectionnez à nouveau le bouton.

## Créer un fil de discussion en répondant à un commentaire standard {#create-a-thread-by-replying-to-a-standard-comment}

Lorsque vous répondez à un commentaire standard, vous créez un fil de discussion.

Prérequis :

- Vous devez avoir le rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner.
- Vous devez être dans un ticket, une merge request ou un epic. Les fils de discussion dans les commits et les extraits de code ne sont pas pris en charge.

Pour créer un fil de discussion en répondant à un commentaire :

1. Dans le coin supérieur droit du commentaire, sélectionnez **Répondre au commentaire** ({{< icon name="reply" >}}) pour afficher la section de réponse.
1. Saisissez votre réponse.
1. Sélectionnez **Répondre** ou **Ajouter un commentaire** (selon l'endroit de l'interface utilisateur où vous répondez).

GitLab convertit le commentaire du haut en fil de discussion.

## Créer un fil de discussion sans répondre à un commentaire {#create-a-thread-without-replying-to-a-comment}

Vous pouvez créer un fil de discussion sans répondre à un commentaire standard.

Prérequis :

- Vous devez avoir le rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner.
- Vous devez être dans un ticket, une merge request, un commit ou un extrait de code.

Pour créer un fil de discussion :

1. Saisissez un commentaire.
1. Sous le commentaire, à droite de **Commentaire**, sélectionnez la flèche vers le bas ({{< icon name="chevron-down" >}}).
1. Dans la liste, sélectionnez **Démarrer un fil de conversation**.
1. Sélectionnez à nouveau **Démarrer un fil de conversation**.

![Créer un fil de discussion](img/create_thread_v16_6.png)

## Résoudre un fil de discussion {#resolve-a-thread}

{{< history >}}

- Les fils de discussion résolvables pour les tâches, les objectifs et les résultats clés [généralement disponibles](https://gitlab.com/gitlab-org/gitlab/-/issues/458818) dans GitLab 17.3.
- Fils de discussion résolvables pour les epics :
  - [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/458818) dans GitLab 17.5. [Le nouveau look pour les epics](../group/epics/_index.md#epics-as-work-items) doit être activé.
  - [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/468310) dans GitLab 18.1.

{{< /history >}}

Lorsqu'une conversation est terminée, vous pouvez résoudre le fil de discussion. Les fils de discussion résolus sont réduits, mais les utilisateurs peuvent toujours y ajouter des commentaires.

Les fils de discussion résolus peuvent être rouverts ultérieurement par tout utilisateur autorisé à résoudre des fils de discussion. Pour rouvrir un fil de discussion résolu, développez le fil de discussion et sélectionnez **Rouvrir le fil de conversation**.

Prérequis :

- Vous devez être dans un epic, un ticket, une tâche, un objectif, un résultat clé ou une merge request.
- Vous devez avoir le rôle Developer, Maintainer ou Owner, ou être l'auteur du ticket ou de la merge request.

Pour résoudre un fil de discussion :

1. Accédez au fil de discussion.
1. Effectuez l'une des actions suivantes :
   - Dans le coin supérieur droit du commentaire d'origine, sélectionnez **Résoudre le fil de conversation** ({{< icon name="check-circle" >}}).
   - Sous la dernière réponse, dans le champ **Répondre**, sélectionnez **Résoudre le fil de conversation**.
   - Sous la dernière réponse, dans le champ **Répondre**, saisissez du texte, cochez la case **Résoudre le fil de conversation**, puis sélectionnez **Ajouter un commentaire**.

Les mêmes actions peuvent être effectuées pour rouvrir un fil de discussion.

Les merge requests offrent des [options de gestion des fils de discussion](../project/merge_requests/_index.md#manage-comment-threads) plus flexibles, telles que :

- Déplacer les fils de discussion ouverts vers un nouveau ticket.
- Empêcher la fusion tant que tous les fils de discussion ne sont pas résolus.

## Résumer les discussions d'un ticket avec GitLab Duo Chat {#summarize-issue-discussions-with-gitlab-duo-chat}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Module d'extension : GitLab Duo Enterprise, GitLab Duo avec Amazon Q
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< collapsible title="Informations sur le modèle" >}}

- [LLM par défaut](../gitlab_duo/model_selection.md#default-models)
- LLM pour Amazon Q : Amazon Q Developer
- Disponible sur [GitLab Duo avec des modèles auto-hébergés](../../administration/gitlab_duo_self_hosted/_index.md)

{{< /collapsible >}}

{{< history >}}

- [Déplacé](https://gitlab.com/gitlab-org/gitlab/-/issues/454550) vers GitLab Duo et passé en [version bêta](../../policy/development_stages_support.md#beta) dans GitLab 17.3 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `summarize_notes_with_duo`. Désactivé par défaut.
- [Activé par défaut](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/162122) dans GitLab 17.4.
- Obligation de disposer du module d'extension GitLab Duo à partir de GitLab 17.6.
- Disponibilité étendue à GitLab Premium dans GitLab 18.0.

{{< /history >}}

Générez un résumé des discussions sur un ticket.

<i class="fa-youtube-play" aria-hidden="true"></i> [Visionner une présentation](https://www.youtube.com/watch?v=IcdxLfTIUgc)
<!-- Video published on 2024-03-28 -->

Prérequis :

- Vous devez avoir l'autorisation de consulter le ticket.

Pour générer un résumé des discussions d'un ticket :

1. Dans un ticket, faites défiler jusqu'à la section **Activité**.
1. Sélectionnez **Voir le résumé**.

Les commentaires du ticket sont résumés en 10 éléments de liste au maximum. Vous pouvez poser des questions de suivi basées sur la réponse.

Utilisation des données : lorsque vous utilisez cette fonctionnalité, le texte de tous les commentaires du ticket est envoyé au grand modèle de langage.
