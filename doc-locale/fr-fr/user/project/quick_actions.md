---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Actions rapides GitLab
description: "Commandes, raccourcis et actions en ligne."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les actions rapides fournissent des raccourcis textuels pour les actions courantes dans GitLab. Les actions rapides :

- Permettent d'exécuter des actions courantes sans utiliser l'interface utilisateur.
- Prennent en charge les tickets, les merge requests, les epics et les commits.
- S'exécutent automatiquement lorsque vous enregistrez des descriptions ou des commentaires.
- Répondent à des contextes et des conditions spécifiques.
- Traitent plusieurs commandes lorsqu'elles sont saisies sur des lignes séparées.

Par exemple, vous pouvez utiliser des actions rapides pour :

- Attribuer des utilisateurs.
- Ajouter des labels.
- Définir des dates d'échéance.
- Modifier le statut.
- Définir d'autres attributs.

Chaque commande commence par une barre oblique (`/`) et doit être saisie sur une ligne séparée. De nombreuses actions rapides acceptent des paramètres, que vous pouvez saisir avec des guillemets (`"`) ou une mise en forme spécifique.

## Paramètres {#parameters}

De nombreuses actions rapides nécessitent un paramètre. Par exemple, l'action rapide `/assign` nécessite un nom d'utilisateur. GitLab utilise les [caractères d'autocomplétion](autocomplete_characters.md) avec les actions rapides pour aider les utilisateurs à saisir des paramètres, en fournissant une liste de valeurs disponibles.

Si vous saisissez manuellement un paramètre, il doit être entouré de guillemets doubles (`"`), sauf s'il ne contient que les caractères suivants :

- Lettres ASCII
- Chiffres (0-9)
- Trait de soulignement (`_`), tiret (`-`), point d'interrogation (`?`), point (`.`), esperluette (`&`) ou arobase (`@`)

Les paramètres sont sensibles à la casse. L'autocomplétion gère cela, ainsi que l'insertion des guillemets, automatiquement.

## Actions rapides {#quick-actions}

{{< history >}}

- Les epics en tant qu'éléments de travail [introduits](https://gitlab.com/gitlab-org/gitlab/-/issues/468310) dans GitLab 18.1.
- L'action rapide `/cc` [supprimée](https://gitlab.com/gitlab-org/gitlab/-/issues/369571) dans GitLab 18.3.

{{< /history >}}

Les actions rapides suivantes s'appliquent aux descriptions, discussions et fils de discussion. Certaines actions rapides peuvent ne pas être disponibles pour toutes les éditions d'abonnement.

### `add_child` {#add_child}

Ajouter un ou plusieurs éléments en tant qu'éléments enfants.

Disponibilité :

- Epic (ajouter des tickets, des tâches, des objectifs ou des résultats clés)
- Ticket (ajouter des tâches, des objectifs ou des résultats clés)
- Objectif (ajouter des objectifs ou des résultats clés)

Paramètres :

- `<item>` : l'élément à ajouter en tant qu'élément enfant. La valeur doit être au format `#item`, `group/project#item`, ou une URL vers l'élément. Plusieurs éléments de travail peuvent être ajoutés en tant qu'éléments enfants en même temps.

Exemples :

- Ajouter un seul élément enfant :

  ```plaintext
  /add_child #123
  ```

- Ajouter plusieurs éléments enfants :

  ```plaintext
  /add_child #123 #456 group/project#789
  ```

- Ajouter un élément enfant à l'aide d'une URL :

  ```plaintext
  /add_child https://gitlab.com/group/project/-/work_items/123
  ```

### `add_contacts` {#add_contacts}

Ajouter un ou plusieurs contacts CRM actifs.

Disponibilité :

- Ticket

Paramètres :

- `[contact:email1@example.com]` : un ou plusieurs e-mails de contact au format `contact:email@example.com`.

Exemples :

- Ajouter un seul contact :

  ```plaintext
  /add_contacts [contact:alex@example.com]
  ```

- Ajouter plusieurs contacts :

  ```plaintext
  /add_contacts [contact:alex@example.com] [contact:sam@example.com]
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [Contacts CRM](../crm/_index.md).

### `add_email` {#add_email}

{{< history >}}

- [Généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/issues/350460) dans GitLab 18.10. Le feature flag `issue_email_participants` a été supprimé.

{{< /history >}}

Ajouter jusqu'à six participants par e-mail.

Disponibilité :

- Incident
- Ticket

Paramètres :

- `email1 email2` : une ou plusieurs adresses e-mail, séparées par des espaces.

Exemples :

- Ajouter un seul participant par e-mail :

  ```plaintext
  /add_email alex@example.com
  ```

- Ajouter plusieurs participants par e-mail :

  ```plaintext
  /add_email alex@example.com sam@example.com
  ```

Détails supplémentaires :

- Non pris en charge dans les [modèles de tickets](description_templates.md).
- Pour plus d'informations, voir [participants par e-mail](service_desk/external_participants.md).

### `approve` {#approve}

Approuver la merge request.

Disponibilité :

- Demande de fusion

Exemples :

- Approuver une merge request :

  ```plaintext
  /approve
  ```

Détails supplémentaires :

- Pour désapprouver une merge request, utilisez [`/unapprove`](#unapprove).

### `assign` {#assign}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/551805) pour les epics dans GitLab 18.2.

{{< /history >}}

Attribuer un ou plusieurs utilisateurs à l'élément de travail.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `@user1 @user2` : un ou plusieurs noms d'utilisateur à attribuer. Les noms d'utilisateur doivent être précédés de `@`.
- `me` : vous attribuer l'élément de travail.

Exemples :

- Attribuer un seul utilisateur :

  ```plaintext
  /assign @alex
  ```

- Attribuer plusieurs utilisateurs :

  ```plaintext
  /assign @alex @sam
  ```

- Vous attribuer :

  ```plaintext
  /assign me
  ```

Détails supplémentaires :

- Avec GitLab Premium et Ultimate, vous pouvez attribuer plusieurs utilisateurs dans une seule commande en séparant les noms d'utilisateur par des espaces. Avec GitLab Free, seul l'un des utilisateurs spécifiés est attribué. Pour plus d'informations, voir [plusieurs personnes assignées](issues/multiple_assignees_for_issues.md).
- Pour supprimer des personnes assignées, utilisez [`/unassign`](#unassign).
- Pour remplacer les personnes assignées, utilisez [`/reassign`](#reassign).

### `assign_reviewer` {#assign_reviewer}

Attribuer un ou plusieurs utilisateurs comme relecteurs, ou demander une nouvelle relecture aux relecteurs existants.

Alias pour [`/request_review`](#request_review).

Disponibilité :

- Demande de fusion

Paramètres :

- `@user1 @user2` : un ou plusieurs noms d'utilisateur à attribuer comme relecteurs. Les noms d'utilisateur doivent être précédés de `@`.
- `me` : vous attribuer comme relecteur.

Exemples :

- Attribuer un seul relecteur :

  ```plaintext
  /assign_reviewer @alex
  ```

- Attribuer plusieurs relecteurs :

  ```plaintext
  /assign_reviewer @alex @sam
  ```

- Vous attribuer comme relecteur :

  ```plaintext
  /assign_reviewer me
  ```

Détails supplémentaires :

- Si l'utilisateur n'est pas encore relecteur, il est attribué comme relecteur.
- Si l'utilisateur est déjà relecteur, une nouvelle relecture lui est demandée (son état de relecture est réinitialisé et des notifications sont envoyées).
- Vous pouvez attribuer plusieurs utilisateurs dans une seule commande en séparant les noms d'utilisateur par des espaces.
- `/reviewer` est également un alias pour cette commande.
- Pour remplacer les relecteurs, utilisez [`/reassign_reviewer`](#reassign_reviewer).
- Pour supprimer des relecteurs, utilisez [`/unassign_reviewer`](#unassign_reviewer).
- Pour plus d'informations, consultez [`/request_review`](#request_review).

### `award` {#award}

Activer/désactiver une réaction emoji.

Disponibilité :

- Tâche
- Objectif
- Résultat clé

Paramètres :

- `:emoji:` : l'emoji à activer/désactiver. Doit être au format `:emoji_name:`.

Exemples :

- Activer/désactiver une réaction pouce levé :

  ```plaintext
  /award :thumbsup:
  ```

- Activer/désactiver une réaction cœur :

  ```plaintext
  /award :heart:
  ```

Détails supplémentaires :

- `/award` est un alias de `/react`.
- Pour plus d'informations, voir [réactions emoji](../emoji_reactions.md).

### `blocked_by` {#blocked_by}

Marquer l'élément comme bloqué par d'autres éléments.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Paramètres :

- `<item1> <item2>` : un ou plusieurs éléments qui bloquent cet élément. La valeur doit être au format `#item`, `group/project#item`, ou l'URL complète. Pour les merge requests, utilisez `!merge_request`, `group/project!merge_request`, ou l'URL de la merge request.

Exemples :

- Marquer comme bloqué par un seul élément :

  ```plaintext
  /blocked_by #123
  ```

- Marquer comme bloqué par plusieurs éléments :

  ```plaintext
  /blocked_by #123 group/project#456
  ```

- Marquer comme bloqué par un élément à l'aide d'une URL :

  ```plaintext
  /blocked_by https://gitlab.com/group/project/-/work_items/123
  ```

- Marquer une merge request comme bloquée par une autre merge request :

  ```plaintext
  /blocked_by !456
  ```

Détails supplémentaires :

- Pour supprimer la relation de blocage, utilisez [`/unlink`](#unlink).
- Pour marquer les éléments comme liés, sans qu'aucun ne bloque l'autre, utilisez [`/relate`](#relate).

### `blocks` {#blocks}

Marquer l'élément comme bloquant d'autres éléments.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Paramètres :

- `<item1> <item2>` : un ou plusieurs éléments que cet élément bloque. La valeur doit être au format `#item`, `group/project#item`, ou l'URL complète. Pour les merge requests, utilisez `!merge_request`, `group/project!merge_request`, ou l'URL de la merge request.

Exemples :

- Marquer comme bloquant un seul élément :

  ```plaintext
  /blocks #123
  ```

- Marquer comme bloquant plusieurs éléments :

  ```plaintext
  /blocks #123 group/project#456
  ```

- Marquer comme bloquant un élément à l'aide d'une URL :

  ```plaintext
  /blocks https://gitlab.com/group/project/-/work_items/123
  ```

- Marquer une merge request comme bloquant une autre merge request :

  ```plaintext
  /blocks !456
  ```

Détails supplémentaires :

- Pour supprimer la relation de blocage, utilisez [`/unlink`](#unlink).
- Pour marquer les éléments comme liés, sans qu'aucun ne bloque l'autre, utilisez [`/relate`](#relate).

### `board_move` {#board_move}

Déplacer un ticket vers une colonne du tableau.

Disponibilité :

- Ticket

Paramètres :

- `~column` : le nom du label de la colonne du tableau vers laquelle déplacer le ticket. Doit être précédé de `~`.

Exemples :

- Déplacer vers une colonne :

  ```plaintext
  /board_move ~"In Progress"
  ```

Détails supplémentaires :

- Le projet doit n'avoir qu'un seul tableau des tickets.

### `checkin_reminder` {#checkin_reminder}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/422761) dans GitLab 16.4 avec les indicateurs nommés `okrs_mvc` et `okr_checkin_reminders`. Fonctionnalité désactivée par défaut.

{{< /history >}}

Planifier des rappels d'enregistrement pour les objectifs.

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique.

Disponibilité :

- Objectif

Paramètres :

- `<cadence>` : la cadence des rappels. Les options sont :
  - `weekly`
  - `twice-monthly`
  - `monthly`
  - `never` (par défaut)

Exemples :

- Configurer des rappels hebdomadaires :

  ```plaintext
  /checkin_reminder weekly
  ```

- Désactiver les rappels :

  ```plaintext
  /checkin_reminder never
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [planifier des rappels d'enregistrement OKR](../okrs.md#schedule-okr-check-in-reminders).

### `clear_health_status` {#clear_health_status}

Effacer le statut de santé.

Disponibilité :

- Epic
- Ticket
- Tâche
- Objectif
- Résultat clé

Exemples :

- Effacer le statut de santé :

  ```plaintext
  /clear_health_status
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [statut de santé](issues/managing_issues.md#health-status).

### `clear_weight` {#clear_weight}

Effacer le poids.

Disponibilité :

- Ticket
- Tâche

Exemples :

- Effacer le poids :

  ```plaintext
  /clear_weight
  ```

### `clone` {#clone}

Cloner l'élément de travail vers un groupe ou un projet donné.

Disponibilité :

- Epic
- Incident
- Ticket

Paramètres :

- `<path/to/group_or_project>` : le chemin vers le groupe ou le projet cible. Si non fourni, clone vers le projet actuel.
- `--with_notes` : indicateur facultatif pour inclure les commentaires et les notes système dans le clone.
- `[type:<work item type>]` (facultatif) : le type d'élément de travail à utiliser dans l'espace de nommage cible. Lorsqu'il est omis, le type d'élément de travail source est conservé. Les noms de types composés de plusieurs mots (par exemple, `Key Result`) ne nécessitent pas de guillemets car `]` délimite la valeur.

Exemples :

- Cloner vers un autre projet :

  ```plaintext
  /clone group/project
  ```

- Cloner vers le projet actuel :

  ```plaintext
  /clone
  ```

- Cloner avec des notes :

  ```plaintext
  /clone group/project --with_notes
  ```

- Cloner vers un autre projet et convertir vers un type d'élément de travail spécifique :

  ```plaintext
  /clone group/project [type:Issue]
  ```

- Cloner avec un nom de type composé de plusieurs mots :

  ```plaintext
  /clone group/project [type:Key Result]
  ```

Détails supplémentaires :

- Copie autant de données que possible, à condition que la cible contienne des objets équivalents tels que des labels, des jalons ou des epics.
- Ne copie pas les commentaires ni les notes système, sauf si `--with_notes` est fourni comme argument.
- Lorsqu'aucun type n'est fourni, le type d'élément de travail source est conservé. Le clone échoue si ce type n'est pas disponible dans l'espace de nommage cible.
- Lorsqu'un type est fourni, l'élément de travail est converti vers ce type. Le clone échoue si le type n'est pas disponible dans l'espace de nommage cible.
- La valeur `[type:...]` est comparée sans distinction de casse aux noms des types d'éléments de travail disponibles dans l'espace de nommage cible.
- Le clone échoue si le type résolu est désactivé dans l'espace de nommage cible (archivé, désactivé par un administrateur ou non visible dans le contexte de destination).
- Lors du clonage vers le même espace de nommage, l'argument `[type:...]` est validé mais aucune conversion n'est effectuée. Le clone conserve le type d'élément de travail source.
- La conversion de type de base entre les types intégrés (par exemple, `Issue`, `Task`, `Incident`) est disponible sur toutes les éditions.
- Les types d'éléments de travail personnalisés et la visibilité des types par espace de nommage sont des fonctionnalités GitLab Premium et Ultimate sur GitLab.com. Si un type n'est pas disponible dans l'espace de nommage cible dans le cadre de votre abonnement, le clone échoue et le message d'erreur liste les types que vous pouvez utiliser.

### `close` {#close}

Fermer l'élément de travail.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Fermer un élément de travail :

  ```plaintext
  /close
  ```

Détails supplémentaires :

- Pour rouvrir un élément de travail, utilisez [`/reopen`](#reopen).

### `confidential` {#confidential}

Marquer l'élément de travail comme confidentiel.

Disponibilité :

- Epic
- Incident
- Ticket
- Tâche
- Objectif
- Résultat clé

Exemples :

- Marquer comme confidentiel :

  ```plaintext
  /confidential
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [qui peut voir les tickets confidentiels](issues/confidential_issues.md#who-can-see-confidential-issues), [les OKR](../okrs.md#who-can-see-confidential-okrs) ou [les tâches](../tasks.md#who-can-see-confidential-tasks).
- Pour rendre un élément non confidentiel, dans le coin supérieur droit, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) puis **Désactiver la confidentialité**.

### `convert_to_ticket` {#convert_to_ticket}

Convertir un ticket en ticket Service Desk.

Disponibilité :

- Incident
- Ticket

Paramètres :

- `<email address>` : l'adresse e-mail à associer au ticket.

Exemples :

- Convertir en ticket :

  ```plaintext
  /convert_to_ticket user@example.com
  ```

Détails supplémentaires :

- Cette action rapide n'est disponible que lorsque [Service Desk est configuré](service_desk/configure.md) pour le projet. Sur GitLab Self-Managed, l'instance doit également avoir [les e-mails entrants](../../administration/incoming_email.md) configurés avec le sous-adressage d'e-mail ou une boîte de réception fourre-tout.
- Pour plus d'informations, voir [convertir un ticket standard en ticket Service Desk](service_desk/using_service_desk.md#convert-a-regular-issue-to-a-service-desk-ticket).

### `copy_metadata` {#copy_metadata}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/509076) dans GitLab 17.9 pour les tâches, les objectifs et les résultats clés.

{{< /history >}}

Copier les labels et le jalon d'un autre élément.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `<#item>` : l'élément depuis lequel copier les métadonnées. Pour les merge requests, utilisez le format `!MR_IID`. Pour les autres éléments, utilisez `#item` ou une URL.

Exemples :

- Copier les métadonnées depuis un ticket :

  ```plaintext
  /copy_metadata #123
  ```

- Copier les métadonnées depuis une merge request :

  ```plaintext
  /copy_metadata !456
  ```

- Copier les métadonnées depuis un élément de travail à l'aide d'une URL :

  ```plaintext
  /copy_metadata https://gitlab.com/group/project/-/work_items/123
  ```

Détails supplémentaires :

- L'élément depuis lequel vous souhaitez copier les métadonnées doit se trouver dans le même espace de nommage.

### `create_merge_request` {#create_merge_request}

Créer une nouvelle merge request à partir du ticket actuel.

Disponibilité :

- Incident
- Ticket
- Tâche

Paramètres :

- `<branch name>` : le nom de la branche à créer pour la merge request.

Exemples :

- Créer une merge request :

  ```plaintext
  /create_merge_request fix-bug-123
  ```

### `done` {#done}

Marquer un élément de la liste de tâches comme terminé.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Marquer l'élément de la liste de tâches comme terminé :

  ```plaintext
  /done
  ```

### `draft` {#draft}

Définir le statut de brouillon d'une merge request.

Disponibilité :

- Demande de fusion

Exemples :

- Marquer comme brouillon :

  ```plaintext
  /draft
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [statut de brouillon](merge_requests/drafts.md).

### `due` {#due}

Définir la date d'échéance.

Disponibilité :

- Epic
- Incident
- Ticket
- Tâche
- Résultat clé

Paramètres :

- `<date>` : la date d'échéance. Exemples de dates valides : `in 2 days`, `this Friday` et `December 31st`.

Exemples :

- Définir la date d'échéance à une date spécifique :

  ```plaintext
  /due December 31st
  ```

- Définir la date d'échéance par rapport à aujourd'hui :

  ```plaintext
  /due in 2 days
  ```

- Définir la date d'échéance au vendredi prochain :

  ```plaintext
  /due this Friday
  ```

Détails supplémentaires :

- Pour d'autres exemples de formats de date, voir [les exemples Chronic](https://gitlab.com/gitlab-org/ruby/gems/gitlab-chronic#examples).
- Pour supprimer la date d'échéance, utilisez [`/remove_due_date`](#remove_due_date).

### `duplicate` {#duplicate}

Fermer cet élément et le marquer comme lié à, et doublon d'un autre élément.

Disponibilité :

- Epic
- Incident
- Ticket

Paramètres :

- `<item>` : l'élément dont celui-ci est un doublon. La valeur doit être au format `#item`, `group/project#item`, ou une URL.

Exemples :

- Marquer comme doublon :

  ```plaintext
  /duplicate #123
  ```

- Marquer comme doublon à l'aide d'une URL :

  ```plaintext
  /duplicate https://gitlab.com/group/project/-/work_items/123
  ```

### `epic` {#epic}

Ajouter à un epic en tant qu'élément enfant.

Disponibilité :

- Epic
- Ticket

Paramètres :

- `<epic>` : l'epic auquel ajouter cet élément. La valeur doit être au format `&epic`, `#epic`, `group&epic`, `group#epic`, ou une URL vers un epic.

Exemples :

- Ajouter à un epic par référence :

  ```plaintext
  /epic &123
  ```

- Ajouter à un epic par groupe et référence :

  ```plaintext
  /epic group&456
  ```

- Ajouter à un epic à l'aide d'une URL :

  ```plaintext
  /epic https://gitlab.com/groups/group/-/epics/123
  ```

Détails supplémentaires :

- `/set_parent` se comporte de la même manière, mais est disponible pour davantage de types d'éléments de travail.

### `estimate` {#estimate}

Définir l'estimation de temps.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Paramètres :

- `<time>` : l'estimation de temps. Par exemple, `1mo 2w 3d 4h 5m`.

Exemples :

- Définir l'estimation de temps :

  ```plaintext
  /estimate 1mo 2w 3d 4h 5m
  ```

- Définir l'estimation de temps en heures :

  ```plaintext
  /estimate 8h
  ```

Détails supplémentaires :

- `/estimate_time` est un alias pour `/estimate`.
- Pour supprimer une estimation, utilisez [`/remove_estimate`](#remove_estimate).
- Pour plus d'informations, voir [le suivi du temps](time_tracking.md).

### `health_status` {#health_status}

Définir le statut de santé.

Disponibilité :

- Epic
- Ticket
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `<value>` : la valeur du statut de santé. Les options valides sont `on_track`, `needs_attention` et `at_risk`.

Exemples :

- Définir le statut de santé sur « en bonne voie » :

  ```plaintext
  /health_status on_track
  ```

- Définir le statut de santé sur « nécessite une attention » :

  ```plaintext
  /health_status needs_attention
  ```

- Définir le statut de santé sur « à risque » :

  ```plaintext
  /health_status at_risk
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [statut de santé](issues/managing_issues.md#health-status).

### `internal_note` {#internal_note}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/553068) dans GitLab 19.4.

{{< /history >}}

Rendre un commentaire une note interne.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Ticket
- Objectif
- Résultat clé

Exemples :

- Rendre un commentaire une note interne :

  ```plaintext
  This is an internal comment.
  /internal_note
  ```

Détails supplémentaires :

- Vous devez avoir le rôle Planificateur, Reporter, Developer, Maintainer ou Owner.
- Vous ne pouvez pas utiliser `/internal_note` dans une description, comme réponse dans une discussion non interne, ni lors de la modification d'un commentaire existant.
- Vous ne pouvez pas convertir des notes internes en commentaires ordinaires.
- Pour plus d'informations, voir [les notes internes](../discussions/_index.md#add-an-internal-note).

### `iteration` {#iteration}

Définir l'itération.

Disponibilité :

- Incident
- Ticket

Paramètres :

- `*iteration:<iteration ID> or <iteration name>` : définir une itération spécifique par identifiant ou nom.
- `[cadence:<iteration cadence ID> or <iteration cadence name>] <--current or --next>` : définir l'itération en cours ou la prochaine itération d'une cadence spécifique.
- `--current` ou `--next` : définir l'itération en cours ou la prochaine lorsqu'un groupe dispose d'une seule cadence d'itération.

Exemples :

- Définir une itération spécifique par nom :

  ```plaintext
  /iteration *iteration:"Late in July"
  ```

- Définir l'itération en cours d'une cadence :

  ```plaintext
  /iteration [cadence:"Team cadence"] --current
  ```

- Définir la prochaine itération lorsque le groupe dispose d'une seule cadence :

  ```plaintext
  /iteration --next
  ```

Détails supplémentaires :

- Pour supprimer l'itération, utilisez [`/remove_iteration`](#remove_iteration).

### `label` {#label}

Ajouter un ou plusieurs labels.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `~label1 ~label2` : un ou plusieurs noms de labels. Les noms de labels peuvent également commencer sans tilde (`~`), mais la syntaxe mixte n'est pas prise en charge.

Exemples :

- Ajouter un seul label :

  ```plaintext
  /label ~bug
  ```

- Ajouter plusieurs labels :

  ```plaintext
  /label ~bug ~"high priority"
  ```

- Ajouter des labels sans tilde :

  ```plaintext
  /label bug "high priority"
  ```

Détails supplémentaires :

- Les labels dont le nom contient un espace doivent être entourés de guillemets doubles.
- `/labels` est un alias pour `/label`.
- Pour supprimer des labels, utilisez [`/unlabel`](#unlabel).
- Pour remplacer des labels, utilisez [`/relabel`](#relabel).

### `link` {#link}

Ajouter un lien et une description aux ressources liées dans un incident.

Disponibilité :

- Incident

Exemples :

- Ajouter une ressource liée :

  ```plaintext
  /link
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [ressources liées](../../operations/incident_management/linked_resources.md).

### `lock` {#lock}

Verrouiller les discussions.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Exemples :

- Verrouiller les discussions :

  ```plaintext
  /lock
  ```

Détails supplémentaires :

- Pour déverrouiller les discussions, utilisez [`/unlock`](#unlock).

### `merge` {#merge}

Fusionner les modifications.

Disponibilité :

- Demande de fusion

Exemples :

- Fusionner la merge request :

  ```plaintext
  /merge
  ```

Détails supplémentaires :

- Selon le paramètre du projet, cela peut être [lorsque le pipeline réussit](merge_requests/auto_merge.md), ou l'ajout à un [merge train](../../ci/pipelines/merge_trains.md).

### `milestone` {#milestone}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/work_items/329) pour les epics dans GitLab 18.2.

{{< /history >}}

Définir le jalon.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Paramètres :

- `%milestone` : le nom du jalon. Doit être précédé de `%`.

Exemples :

- Définir le jalon :

  ```plaintext
  /milestone %"Sprint 1"
  ```

Détails supplémentaires :

- Pour supprimer le jalon, utilisez [`/remove_milestone`](#remove_milestone).

### `move` {#move}

Déplacer l'élément de travail vers un autre groupe ou projet.

Disponibilité :

- Epic
- Incident
- Ticket

Paramètres :

- `<path/to/group_or_project>` : le chemin vers le groupe ou le projet cible.
- `[type:<work item type>]` (facultatif) : le type d'élément de travail à utiliser dans l'espace de nommage cible. Lorsqu'il est omis, le type d'élément de travail source est conservé. Les noms de types composés de plusieurs mots (par exemple, `Key Result`) ne nécessitent pas de guillemets car `]` délimite la valeur.

Exemples :

- Déplacer vers un autre projet :

  ```plaintext
  /move group/project
  ```

- Déplacer vers un autre projet et convertir vers un type d'élément de travail spécifique :

  ```plaintext
  /move group/project [type:Issue]
  ```

- Déplacer avec un nom de type composé de plusieurs mots :

  ```plaintext
  /move group/project [type:Key Result]
  ```

Détails supplémentaires :

- Faites attention lorsque vous déplacez un élément de travail vers un emplacement soumis à des règles d'accès différentes. Avant de déplacer l'élément de travail, assurez-vous qu'il ne contient pas de données sensibles.
- Lorsqu'aucun type n'est fourni, le type d'élément de travail source est conservé. Le déplacement échoue si ce type n'est pas disponible dans l'espace de nommage cible.
- Lorsqu'un type est fourni, l'élément de travail est converti vers ce type. Le déplacement échoue si le type n'est pas disponible dans l'espace de nommage cible.
- La valeur `[type:...]` est comparée sans distinction de casse aux noms des types d'éléments de travail disponibles dans l'espace de nommage cible.
- Le déplacement échoue si le type résolu est désactivé dans l'espace de nommage cible (archivé, désactivé par un administrateur ou non visible dans le contexte de destination).
- Lors du déplacement vers le même espace de nommage, l'argument `[type:...]` est validé mais aucune conversion n'est effectuée. L'élément de travail conserve son type existant.
- La conversion de type de base entre les types intégrés (par exemple, `Issue`, `Task`, `Incident`) est disponible sur toutes les éditions.
- Les types d'éléments de travail personnalisés et la visibilité des types par espace de nommage sont des fonctionnalités GitLab Premium et Ultimate sur GitLab.com. Si un type n'est pas disponible dans l'espace de nommage cible dans le cadre de votre abonnement, le déplacement échoue et le message d'erreur liste les types que vous pouvez utiliser.

### `page` {#page}

Démarrer les escalades pour l'incident.

Disponibilité :

- Incident

Paramètres :

- `<policy name>` : le nom de la politique d'escalade.

Exemples :

- Démarrer les escalades :

  ```plaintext
  /page "On-call policy"
  ```

### `promote_to` {#promote_to}

Promouvoir un élément de travail vers un type spécifié.

Disponibilité :

- Ticket
- Tâche
- Résultat clé

Paramètres :

- `<type>` : le type vers lequel promouvoir. Options disponibles :
  - `Epic` (pour les tickets)
  - `Incident` (pour les tickets)
  - `issue` (pour les tâches)
  - `objective` (pour les résultats clés)

Exemples :

- Promouvoir un ticket en epic :

  ```plaintext
  /promote_to Epic
  ```

- Promouvoir une tâche en ticket :

  ```plaintext
  /promote_to issue
  ```

- Promouvoir un résultat clé en objectif :

  ```plaintext
  /promote_to objective
  ```

Détails supplémentaires :

- Pour les tickets, `/promote_to_incident` est un raccourci pour `/promote_to Incident`.
- Pour modifier le type des éléments de travail, utilisez également [`/type`](#type).

### `promote_to_incident` {#promote_to_incident}

Promouvoir un ticket en incident.

Disponibilité :

- Ticket

Exemples :

- Promouvoir en incident :

  ```plaintext
  /promote_to_incident
  ```

Détails supplémentaires :

- Vous pouvez également utiliser cette action rapide lors de la création d'un nouveau ticket.

### `publish` {#publish}

Publier un ticket vers une page de statut associée.

Disponibilité :

- Ticket

Exemples :

- Publier sur la page de statut :

  ```plaintext
  /publish
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [la page de statut](../../operations/incident_management/status_page.md).

### `react` {#react}

Activer/désactiver une réaction emoji.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Paramètres :

- `:emoji:` : l'emoji à activer/désactiver. Doit être au format `:emoji_name:`.

Exemples :

- Activer/désactiver une réaction pouce levé :

  ```plaintext
  /react :thumbsup:
  ```

- Activer/désactiver une réaction cœur :

  ```plaintext
  /react :heart:
  ```

Détails supplémentaires :

- `/award` est un alias pour `/react`.

### `ready` {#ready}

Définir le statut « prêt » d'une merge request.

Disponibilité :

- Demande de fusion

Exemples :

- Marquer comme prêt :

  ```plaintext
  /ready
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [marquer les merge requests comme prêtes](merge_requests/drafts.md#mark-merge-requests-as-ready).

### `reassign` {#reassign}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/551805) pour les epics dans GitLab 18.2.

{{< /history >}}

Remplacer les personnes assignées actuelles par celles spécifiées.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `@user1 @user2` : un ou plusieurs noms d'utilisateur à attribuer. Les noms d'utilisateur doivent être précédés de `@`.

Exemples :

- Réattribuer à un seul utilisateur :

  ```plaintext
  /reassign @alex
  ```

- Réattribuer à plusieurs utilisateurs :

  ```plaintext
  /reassign @alex @sam
  ```

Détails supplémentaires :

- Pour ajouter des personnes assignées sans remplacer les précédentes, utilisez [`/assign`](#assign).
- Pour supprimer des personnes assignées, utilisez [`/unassign`](#unassign).
- Pour remplacer les personnes assignées, utilisez [`/reassign`](#reassign).

### `reassign_reviewer` {#reassign_reviewer}

Remplacer les relecteurs actuels par ceux spécifiés.

Disponibilité :

- Demande de fusion

Paramètres :

- `@user1 @user2` : un ou plusieurs noms d'utilisateur à attribuer comme relecteurs. Les noms d'utilisateur doivent être précédés de `@`.

Exemples :

- Réattribuer à un seul relecteur :

  ```plaintext
  /reassign_reviewer @alex
  ```

- Réattribuer à plusieurs relecteurs :

  ```plaintext
  /reassign_reviewer @alex @sam
  ```

Détails supplémentaires :

- Pour attribuer des relecteurs sans remplacer les précédents, utilisez [`/assign_reviewer`](#assign_reviewer).
- Pour supprimer des relecteurs, utilisez [`/unassign_reviewer`](#unassign_reviewer).

### `rebase` {#rebase}

Rebaser la branche source sur le dernier commit de la branche cible. S'il y a des conflits, rien ne se passe.

Disponibilité :

- Demande de fusion

Exemples :

- Rebaser la merge request :

  ```plaintext
  /rebase
  ```

Détails supplémentaires :

- Pour obtenir de l'aide, voir [dépannage de Git](../../topics/git/troubleshooting_git.md).

### `relabel` {#relabel}

Remplacer les labels actuels par ceux spécifiés.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `~label1 ~label2` : un ou plusieurs noms de labels. Les noms de labels peuvent également commencer sans tilde (`~`), mais la syntaxe mixte n'est pas prise en charge.

Exemples :

- Remplacer par un seul label :

  ```plaintext
  /relabel ~bug
  ```

- Remplacer par plusieurs labels :

  ```plaintext
  /relabel ~bug ~"high priority"
  ```

Détails supplémentaires :

- Les labels dont le nom contient un espace doivent être entourés de guillemets doubles.
- Pour ajouter des labels sans remplacer les précédents, utilisez [`/label`](#label).
- Pour supprimer des labels, utilisez [`/unlabel`](#unlabel).

### `relate` {#relate}

Marquer des éléments comme liés.

Disponibilité :

- Epic
- Incident
- Ticket

Paramètres :

- `<item1> <item2>` : un ou plusieurs éléments à lier. La valeur doit être au format `#item`, `group/project#item`, ou l'URL complète.

Exemples :

- Lier à un seul élément :

  ```plaintext
  /relate #123
  ```

- Lier à plusieurs éléments :

  ```plaintext
  /relate #123 group/project#456
  ```

Détails supplémentaires :

- Pour supprimer la relation, utilisez [`/unlink`](#unlink).
- Pour marquer les éléments comme s'en bloquant un autre, utilisez [`/blocked_by`](#blocked_by) ou [`/blocks`](#blocks).

### `remove_child` {#remove_child}

Supprimer un élément en tant qu'élément enfant.

Disponibilité :

- Epic
- Ticket
- Objectif

Paramètres :

- `<item>` : l'élément à supprimer en tant qu'élément enfant. La valeur doit être au format `#item`, `group/project#item`, ou une URL vers l'élément.

Exemples :

- Supprimer un élément enfant :

  ```plaintext
  /remove_child #123
  ```

- Supprimer un élément enfant à l'aide d'une URL :

  ```plaintext
  /remove_child https://gitlab.com/group/project/-/work_items/123
  ```

### `remove_contacts` {#remove_contacts}

Supprimer un ou plusieurs contacts CRM.

Disponibilité :

- Ticket

Paramètres :

- `[contact:email1@example.com]` : un ou plusieurs e-mails de contact au format `contact:email@example.com`.

Exemples :

- Supprimer un seul contact :

  ```plaintext
  /remove_contacts [contact:alex@example.com]
  ```

- Supprimer plusieurs contacts :

  ```plaintext
  /remove_contacts [contact:alex@example.com] [contact:sam@example.com]
  ```

Détails supplémentaires :

- Pour plus d'informations, voir [Contacts CRM](../crm/_index.md).

### `remove_due_date` {#remove_due_date}

Supprimer la date d'échéance.

Disponibilité :

- Epic
- Incident
- Ticket
- Tâche
- Résultat clé

Exemples :

- Supprimer la date d'échéance :

  ```plaintext
  /remove_due_date
  ```

Détails supplémentaires :

- Pour ajouter ou remplacer une date d'échéance, utilisez [`/due`](#due).

### `remove_email` {#remove_email}

{{< history >}}

- [Généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/issues/350460) dans GitLab 18.10. Le feature flag `issue_email_participants` a été supprimé.

{{< /history >}}

Supprimer jusqu'à six participants par e-mail.

Disponibilité :

- Incident
- Ticket

Paramètres :

- `email1 email2` : une ou plusieurs adresses e-mail, séparées par des espaces.

Exemples :

- Supprimer un seul participant par e-mail :

  ```plaintext
  /remove_email alex@example.com
  ```

- Supprimer plusieurs participants par e-mail :

  ```plaintext
  /remove_email alex@example.com sam@example.com
  ```

Détails supplémentaires :

- Non pris en charge dans les modèles de tickets, les merge requests ou les epics.
- Pour plus d'informations, voir [participants par e-mail](service_desk/external_participants.md).

### `remove_estimate` {#remove_estimate}

Supprimer l'estimation de temps.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Exemples :

- Supprimer l'estimation de temps :

  ```plaintext
  /remove_estimate
  ```

Détails supplémentaires :

- `/remove_time_estimate` est un alias pour `/remove_estimate`.
- Pour ajouter ou remplacer une estimation, utilisez [`/estimate`](#estimate).

### `remove_iteration` {#remove_iteration}

Supprimer l'itération.

Disponibilité :

- Incident
- Ticket

Exemples :

- Supprimer l'itération :

  ```plaintext
  /remove_iteration
  ```

Détails supplémentaires :

- Pour définir une itération, utilisez [`/iteration`](#iteration).

### `remove_milestone` {#remove_milestone}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/work_items/329) pour les epics dans GitLab 18.2.

{{< /history >}}

Supprimer le jalon.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Exemples :

- Supprimer le jalon :

  ```plaintext
  /remove_milestone
  ```

Détails supplémentaires :

- Pour définir le jalon, utilisez [`/milestone`](#milestone).

### `remove_parent` {#remove_parent}

Supprimer le parent de l'élément.

Disponibilité :

- Epic
- Ticket
- Tâche
- Résultat clé

Exemples :

- Supprimer le parent :

  ```plaintext
  /remove_parent
  ```

Détails supplémentaires :

- Pour définir l'élément parent, utilisez [`/set_parent`](#set_parent).

### `remove_time_spent` {#remove_time_spent}

Supprimer le temps passé.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Exemples :

- Supprimer le temps passé :

  ```plaintext
  /remove_time_spent
  ```

Détails supplémentaires :

- Pour ajouter du temps passé, utilisez [`/spend`](#spend).

### `remove_zoom` {#remove_zoom}

Supprimer une réunion Zoom d'un ticket.

Disponibilité :

- Ticket

Exemples :

- Supprimer la réunion Zoom :

  ```plaintext
  /remove_zoom
  ```

Détails supplémentaires :

- Pour ajouter une réunion Zoom, utilisez [`/zoom`](#zoom).

### `reopen` {#reopen}

Rouvrir l'élément de travail.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Rouvrir un élément de travail :

  ```plaintext
  /reopen
  ```

Détails supplémentaires :

- Pour fermer un élément de travail, utilisez [`/close`](#close).

### `request_review` {#request_review}

Assigner un relecteur ou demander une nouvelle relecture à un ou plusieurs utilisateurs.

Disponibilité :

- Demande de fusion

Paramètres :

- `@user1 @user2` : un ou plusieurs noms d'utilisateur à qui demander une relecture. Les noms d'utilisateur doivent être précédés de `@`.
- `me` : demander une relecture à vous-même.

Exemples :

- Demander une relecture à un seul utilisateur :

  ```plaintext
  /request_review @alex
  ```

- Demander une relecture à plusieurs utilisateurs :

  ```plaintext
  /request_review @alex @sam
  ```

- Demander une relecture à vous-même :

  ```plaintext
  /request_review me
  ```

Détails supplémentaires :

- Peut également être invoqué avec [`/assign_reviewer`](#assign_reviewer) ou `/reviewer`.
- Si l'utilisateur n'est pas encore relecteur, il est attribué comme relecteur.
- Si l'utilisateur est déjà relecteur, une nouvelle relecture lui est demandée (son état de relecture est réinitialisé et des notifications sont envoyées).
- Pour plus d'informations, consultez [demander une relecture](merge_requests/reviews/_index.md#request-a-review).

### `run_pipeline` {#run_pipeline}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/212811) dans GitLab 18.7.

{{< /history >}}

Exécuter un nouveau pipeline pour la merge request.

Disponibilité :

- Demande de fusion

Exemples :

- Exécuter un nouveau pipeline :

  ```plaintext
    /run_pipeline
  ```

Détails supplémentaires :

- Le pipeline est déclenché de manière asynchrone et apparaît peu après l'exécution de la commande.
- Vous devez disposer des autorisations nécessaires pour créer des pipelines pour la merge request.
- Vous pouvez combiner cette action avec d'autres actions rapides. Par exemple, pour exécuter un pipeline et définir la fusion automatique :

  ```plaintext
    /run_pipeline
    /merge
  ```

### `set_parent` {#set_parent}

{{< history >}}

- L'alias `/epic` pour les tickets a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/514942) dans GitLab 17.10.

{{< /history >}}

Définir l'élément parent.

Disponibilité :

- Epic
- Ticket
- Tâche
- Résultat clé

Paramètres :

- `<item>` : l'élément parent. La valeur doit être au format `#IID`, une référence ou une URL vers un élément.

Exemples :

- Définir le parent par référence :

  ```plaintext
  /set_parent #123
  ```

- Définir le parent à l'aide d'une URL :

  ```plaintext
  /set_parent https://gitlab.com/group/project/-/work_items/123
  ```

Détails supplémentaires :

- Pour les tickets, `/epic` est un alias de `/set_parent`.
- Pour supprimer l'élément parent, utilisez [`/remove_parent`](#remove_parent).

### `severity` {#severity}

Définir la gravité d'un incident.

Disponibilité :

- Incident

Paramètres :

- `<severity>` : le niveau de gravité. Options disponibles :
  - `S1`
  - `S2`
  - `S3`
  - `S4`
  - `critical`
  - `high`
  - `medium`
  - `low`
  - `unknown`

Exemples :

- Définir la gravité sur critique :

  ```plaintext
  /severity critical
  ```

- Définir la gravité avec la notation S :

  ```plaintext
  /severity S1
  ```

### `shrug` {#shrug}

Ajouter `¯\_(ツ)_/¯` au commentaire.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Ajouter le shrug :

  ```plaintext
  /shrug
  ```

### `spend` {#spend}

Ajouter ou soustraire du temps passé.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion

Paramètres :

- `<time>` : le temps à ajouter ou à soustraire. Par exemple, `1mo 2w 3d 4h 5m`. Utilisez une valeur négative pour soustraire du temps.
- `[<date>]` : Facultatif. La date à laquelle le temps a été passé.

Exemples :

- Ajouter du temps passé :

  ```plaintext
  /spend 1mo 2w 3d 4h 5m
  ```

- Soustraire du temps passé :

  ```plaintext
  /spend -1h 30m
  ```

- Ajouter du temps passé à une date spécifique :

  ```plaintext
  /spend 1mo 2w 3d 4h 5m 2018-08-26
  ```

Détails supplémentaires :

- `/spend_time` est un alias pour `/spend`.
- Pour supprimer le temps passé, utilisez [`/remove_time_spent`](#remove_time_spent).
- Pour plus d'informations, voir [le suivi du temps](time_tracking.md).

### `status` {#status}

Définir le statut.

Disponibilité :

- Ticket
- Tâche

Paramètres :

- `<value>` : la valeur du statut. Les options disponibles comprennent les options de statut définies pour l'espace de nommage.

Exemples :

- Définir le statut :

  ```plaintext
  /status "In Progress"
  ```

Détails supplémentaires :

- Pour plus d'informations, consultez [statut](../work_items/status.md).

### `submit_review` {#submit_review}

Soumettre une [relecture](merge_requests/reviews/_index.md#submit-a-review) en attente.

Disponibilité :

- Demande de fusion

Exemples :

- Soumettre la relecture :

  ```plaintext
  /submit_review
  ```

  ```plaintext
  /submit_review reviewed
  ```

- Soumettre la relecture et approuver :

  ```plaintext
  /submit_review approve
  ```

- Soumettre la relecture et [demander des modifications](merge_requests/reviews/_index.md#prevent-merge-when-you-request-changes) :

  ```plaintext
  /submit_review requested_changes
  ```

### `subscribe` {#subscribe}

S'abonner aux notifications pour un élément de travail.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- S'abonner aux notifications :

  ```plaintext
  /subscribe
  ```

Détails supplémentaires :

- Pour se désabonner des notifications, utilisez [`/unsubscribe`](#unsubscribe).

### `tableflip` {#tableflip}

Ajouter `(╯°□°)╯︵ ┻━┻` au commentaire.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Ajouter le tableflip :

  ```plaintext
  /tableflip
  ```

### `target_branch` {#target_branch}

Définir la branche cible d'une merge request.

Disponibilité :

- Demande de fusion

Paramètres :

- `<local branch name>` : Le nom de la branche cible.

Exemples :

- Définir la branche cible :

  ```plaintext
  /target_branch main
  ```

### `timeline` {#timeline}

Ajouter un événement de chronologie à un incident.

Disponibilité :

- Incident

Paramètres :

- `<timeline comment> | <date(YYYY-MM-DD)> <time(HH:MM)>` : le commentaire de chronologie, la date et l'heure, séparés par `|`.

Exemples :

- Ajouter un événement de chronologie :

  ```plaintext
  /timeline DB load spiked | 2022-09-07 09:30
  ```

### `title` {#title}

Modifier le titre.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `<new title>` : le nouveau titre de l'élément de travail.

Exemples :

- Modifier le titre :

  ```plaintext
  /title New title for this item
  ```

### `todo` {#todo}

Ajouter un élément de la liste de tâches pour vous-même.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Ajouter un élément à la liste de tâches :

  ```plaintext
  /todo
  ```

### `type` {#type}

Convertir un élément de travail en un type spécifié.

Disponibilité :

- Ticket
- Résultat clé
- Objectif
- Tâche

Paramètres :

- `<type>` : le type vers lequel convertir. Options disponibles :
  - `issue`
  - `task`
  - `objective`
  - `key result`

Exemples :

- Convertir en ticket :

  ```plaintext
  /type issue
  ```

- Convertir en tâche :

  ```plaintext
  /type task
  ```

Détails supplémentaires :

- Pour convertir un ticket en epic ou en incident, utilisez [`/promote_to`](#promote_to).
- `/type Epic` convertit également un ticket en epic, de la même façon que `/promote_to Epic`.

### `unapprove` {#unapprove}

Annuler l'approbation de la merge request.

Disponibilité :

- Demande de fusion

Exemples :

- Annuler l'approbation d'une merge request :

  ```plaintext
  /unapprove
  ```

Détails supplémentaires :

- Pour approuver une merge request, utilisez [`/approve`](#approve).

### `unassign` {#unassign}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/551805) pour les epics dans GitLab 18.2.

{{< /history >}}

Supprimer les personnes assignées.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `@user1 @user2` : Facultatif. Un ou plusieurs noms d'utilisateur à désassigner. Si non spécifié, supprime toutes les personnes assignées.

Exemples :

- Supprimer des personnes assignées spécifiques :

  ```plaintext
  /unassign @alex @sam
  ```

- Supprimer toutes les personnes assignées :

  ```plaintext
  /unassign
  ```

Détails supplémentaires :

- Pour ajouter des personnes assignées, utilisez [`/assign`](#assign).
- Pour remplacer les personnes assignées, utilisez [`/reassign`](#reassign).

### `unassign_reviewer` {#unassign_reviewer}

Supprimer les relecteurs.

Disponibilité :

- Demande de fusion

Paramètres :

- `@user1 @user2` : Facultatif. Un ou plusieurs noms d'utilisateur à supprimer en tant que relecteurs. Si non spécifié, supprime tous les relecteurs.
- `me` : vous supprimer en tant que relecteur.

Exemples :

- Supprimer des relecteurs spécifiques :

  ```plaintext
  /unassign_reviewer @alex @sam
  ```

- Vous supprimer en tant que relecteur :

  ```plaintext
  /unassign_reviewer me
  ```

- Supprimer tous les relecteurs :

  ```plaintext
  /unassign_reviewer
  ```

Détails supplémentaires :

- `/remove_reviewer` est un alias pour `/unassign_reviewer`.
- Pour assigner des relecteurs, utilisez [`/assign_reviewer`](#assign_reviewer).
- Pour remplacer les relecteurs, utilisez [`/reassign_reviewer`](#reassign_reviewer).

### `unlabel` {#unlabel}

Supprimer des labels.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `~label1 ~label2` : Facultatif. Un ou plusieurs noms de labels à supprimer. Si non spécifié, supprime tous les labels.

Exemples :

- Supprimer des labels spécifiques :

  ```plaintext
  /unlabel ~bug ~"high priority"
  ```

- Supprimer tous les labels :

  ```plaintext
  /unlabel
  ```

Détails supplémentaires :

- Les labels dont le nom contient un espace doivent être entourés de guillemets doubles.
- `/remove_label` est un alias pour `/unlabel`.
- Pour ajouter des labels, utilisez [`/label`](#label).
- Pour remplacer des labels, utilisez [`/relabel`](#relabel).

### `unlink` {#unlink}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/481851) dans GitLab 17.8 pour les tâches, les objectifs et les résultats clés.

{{< /history >}}

Supprimer un lien vers un autre élément.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Paramètres :

- `<item>` : l'élément à dissocier. La valeur doit être au format `#item`, `group/project#item`, ou l'URL complète. Pour les merge requests, utilisez `!merge_request`, `group/project!merge_request`, ou l'URL de la merge request.

Exemples :

- Dissocier un élément :

  ```plaintext
  /unlink #123
  ```

- Dissocier un élément à l'aide d'une URL :

  ```plaintext
  /unlink https://gitlab.com/group/project/-/work_items/123
  ```

- Supprimer une relation de blocage entre des merge requests :

  ```plaintext
  /unlink !456
  ```

Détails supplémentaires :

- Pour définir des relations entre des éléments, utilisez [`/relate`](#relate), [`/blocks`](#blocks) ou [`/blocked_by`](#blocked_by).

### `unlock` {#unlock}

Déverrouiller les discussions.

Disponibilité :

- Epic
- Ticket
- Demande de fusion

Exemples :

- Déverrouiller les discussions :

  ```plaintext
  /unlock
  ```

Détails supplémentaires :

- Pour verrouiller les discussions, utilisez [`/lock`](#lock).

### `unsubscribe` {#unsubscribe}

Se désabonner des notifications pour un élément de travail.

Disponibilité :

- Epic
- Incident
- Ticket
- Demande de fusion
- Tâche
- Objectif
- Résultat clé

Exemples :

- Se désabonner des notifications :

  ```plaintext
  /unsubscribe
  ```

Détails supplémentaires :

- Pour s'abonner aux notifications, utilisez [`/subscribe`](#subscribe).

### `weight` {#weight}

Définir le poids.

Disponibilité :

- Ticket
- Tâche

Paramètres :

- `<value>` : la valeur de poids. Les valeurs valides sont des entiers tels que `0`, `1` ou `2`.

Exemples :

- Définir le poids :

  ```plaintext
  /weight 3
  ```

### `zoom` {#zoom}

Ajouter une réunion Zoom à un ticket ou un incident.

Disponibilité :

- Incident
- Ticket

Paramètres :

- `<Zoom URL>` : L'URL de la réunion Zoom.

Exemples :

- Ajouter une réunion Zoom :

  ```plaintext
  /zoom https://zoom.us/j/123456789
  ```

Détails supplémentaires :

- Les utilisateurs de GitLab Premium peuvent ajouter une courte description lors de [l'ajout d'un lien Zoom à un incident](../../operations/incident_management/linked_resources.md#link-zoom-meetings-from-an-incident).
- Pour supprimer la réunion Zoom, utilisez [`/remove_zoom`](#remove_zoom).

## Commentaires sur les commits {#commit-comments}

Vous pouvez utiliser des actions rapides lorsque vous commentez des commits individuels. Ces actions rapides fonctionnent uniquement dans les fils de discussion des commentaires de commit, et non dans les messages de commit ou autres contextes GitLab.

Pour utiliser des actions rapides dans les commentaires de commit :

1. Accédez à une page de commit en sélectionnant un commit depuis la liste des commits, une merge request ou d'autres liens de commit.
1. Dans le formulaire de commentaire en bas de la page de commit, saisissez votre action rapide.
1. Sélectionnez **Commentaire**.

Les actions rapides suivantes s'appliquent aux commentaires de commit :

### `tag` {#tag}

Créer un tag Git pointant vers le commit commenté.

Paramètres :

- `v1.2.3` : le nom du tag.
- `<message>` : Facultatif. Un message pour le tag.

Exemples :

- Créer un tag avec un message :

  ```plaintext
  Ready for release after security fix.
  /tag v2.1.1 Security patch release
  ```

  Ce commentaire crée un tag Git nommé `v2.1.1` pointant vers le commit, avec le message « Security patch release ».

Détails supplémentaires :

- La création de tags est soumise à une limite de débit pour chaque projet, avec une valeur par défaut de 100 requêtes toutes les 30 minutes. Un administrateur peut modifier la limite avec le paramètre d'[application](../../api/settings.md#available-settings) `tags_create_limit`.
- La limite est partagée entre l'[API REST](../../api/tags.md#create-a-new-tag), la mutation GraphQL `tagCreate`, la création de tags dans l'interface utilisateur et cette action rapide.
- Si vous dépassez la limite, votre commentaire est tout de même ajouté, mais le tag n'est pas créé.

## Dépannage {#troubleshooting}

### L'action rapide ne s'exécute pas {#quick-action-isnt-executed}

Si vous exécutez une action rapide mais que rien ne se passe, vérifiez si l'action rapide apparaît dans la liste d'autocomplétion au fur et à mesure que vous la saisissez. Si ce n'est pas le cas, il est possible que :

- La fonctionnalité liée à l'action rapide n'est pas disponible pour vous en fonction de votre édition d'abonnement ou de votre rôle d'utilisateur pour le groupe ou le projet.
- Une condition requise pour l'action rapide n'est pas satisfaite. Par exemple, vous exécutez `/unlabel` sur un ticket sans aucun label.
