---
stage: Analytics
group: Platform Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Les merge requests
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.

{{< /history >}}

## Modes autorisés {#allowed-modes}

- Mode standard (par défaut) : interroger les enregistrements de merge requests.
- Mode Analytics : interroger les métriques agrégées des merge requests. Pour plus d'informations, voir [Analytique des merge requests](merge_request_analytics.md).

## Portées autorisées {#allowed-scopes}

| Portée     | Description                                           |
| --------- | ----------------------------------------------------- |
| `project` | Interroger les merge requests dans un projet spécifique.           |
| `group`   | Interroger les merge requests dans tous les projets d'un groupe, y compris les sous-groupes. |

Pour plus d'informations, voir [les portées](_index.md#scopes).

## Filtres de requête {#query-filters}

Utilisez ces champs dans le paramètre `query` pour filtrer vos résultats.

| Champ                                                    | Nom (et alias)                             | Opérateurs                  |
| -------------------------------------------------------- | -------------------------------------------- | -------------------------- |
| [Approuvé par l'utilisateur](#mr-approved-by-user)                 | `approver`, `approvedBy`, `approvers`        | `=`, `!=`                  |
| [Assignés](#mr-assignees)                               | `assignee`, `assignees`                      | `=`, `!=`                  |
| [Auteur](#mr-author)                                     | `author`                                     | `=`, `!=`                  |
| [Fermé le](#mr-closed-at)                               | `closed`, `closedAt`                         | `=`, `>`, `<`, `>=`, `<=`  |
| [Créé le](#mr-created-at)                             | `created`, `createdAt`, `opened`, `openedAt` | `=`, `>`, `<`, `>=`, `<=`  |
| [Brouillon](#mr-draft)                                       | `draft`                                      | `=`, `!=`                  |
| [Environnement](#mr-environment)                           | `environment`                                | `=`                        |
| [ID](#mr-identifier)                                     | `id`                                         | `=`, `in`                  |
| [Inclure les sous-groupes](#mr-include-subgroups)               | `includeSubgroups`                            | `=`, `!=`                  |
| [Labels](#mr-labels)                                     | `label`, `labels`                            | `=`, `!=`                  |
| [Fusionné le](#mr-merged-at)                               | `merged`, `mergedAt`                         | `=`, `>`, `<`, `>=`, `<=`  |
| [Fusionné par l'utilisateur](#mr-merged-by-user)                     | `merger`, `mergedBy`                         | `=`                        |
| [Jalon](#mr-milestone)                               | `milestone`                                  | `=`, `!=`                  |
| [Mon emoji de réaction](#mr-my-reaction-emoji)               | `myReaction`, `myReactionEmoji`              | `=`, `!=`                  |
| [État de relecture](#mr-review-state)                         | `reviewState`, `reviewStates`                | `=`, `!=`, `in`            |
| [Relecteurs](#mr-reviewers)                               | `reviewer`, `reviewers`, `reviewedBy`        | `=`, `!=`                  |
| [Branche source](#mr-source-branch)                       | `sourceBranch`                               | `=`, `in`, `!=`            |
| [État](#mr-state)                                       | `state`                                      | `=`                        |
| [Abonné](#mr-subscribed)                             | `subscribed`                                 | `=`, `!=`                  |
| [Branche cible](#mr-target-branch)                       | `targetBranch`                               | `=`, `in`, `!=`            |
| [Déployé le](#mr-deployed-at)                           | `deployed`, `deployedAt`                     | `=`, `>`, `<`, `>=`, `<=`  |
| [Mis à jour le](#mr-updated-at)                             | `updated`, `updatedAt`                       | `=`, `>`, `<`, `>=`, `<=`  |

### Approuvé par l'utilisateur {#mr-approved-by-user}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.
- Les alias `approvedBy` et `approvers` [introduits](https://gitlab.com/gitlab-org/glql/-/merge_requests/137) dans GitLab 18.0.
- La prise en charge des valeurs `Nullable` [introduite](https://gitlab.com/gitlab-org/glql/-/merge_requests/221) dans GitLab 18.3.

{{< /history >}}

**Description** : interroger les merge requests par un ou plusieurs utilisateurs ayant approuvé la merge request.

**Types de valeurs autorisés** :

- `String`
- `User` (par exemple, `@username`)
- `List` (contenant des valeurs `String` ou `User`)
- `Nullable` (l'une des valeurs suivantes : `null`, `none` ou `any`)

### Assignés {#mr-assignees}

**Description** : interroger les merge requests par un ou plusieurs utilisateurs qui leur sont assignés.

**Types de valeurs autorisés** :

- `String`
- `User` (par exemple, `@username`)
- `Nullable` (l'une des valeurs suivantes : `null`, `none` ou `any`)

**Notes** :

- Les valeurs `List` et l'opérateur `in` ne sont pas pris en charge pour les merge requests.

### Auteur {#mr-author}

**Description** : interroger les merge requests par leur auteur.

**Types de valeurs autorisés** :

- `String`
- `User` (par exemple, `@username`)

**Notes** :

- L'opérateur `in` n'est pas pris en charge pour les merge requests.

### Fermé le {#mr-closed-at}

**Description** : interroger les merge requests par la date à laquelle elles ont été fermées.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs suivantes : `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

### Créé le {#mr-created-at}

**Description** : interroger les merge requests par la date à laquelle elles ont été créées.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs suivantes : `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

### Brouillon {#mr-draft}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.

{{< /history >}}

**Description** : interroger les merge requests par leur statut de brouillon.

**Types de valeurs autorisés** :

- `Boolean` (l'une des valeurs suivantes : `true` ou `false`)

### Déployé le {#mr-deployed-at}

**Description** : interroger les merge requests par la date à laquelle elles ont été déployées.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs suivantes : `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

### Environnement {#mr-environment}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.

{{< /history >}}

**Description** : interroger les merge requests par l'environnement dans lequel elles ont été déployées.

**Types de valeurs autorisés** : `String`

### ID {#mr-identifier}

**Description** : interroger les merge requests par leurs identifiants.

**Types de valeurs autorisés** :

- `Number` (entiers positifs uniquement)
- `List` (contenant des valeurs `Number`)

### Inclure les sous-groupes {#mr-include-subgroups}

**Description** : interroger les merge requests dans l'ensemble de la hiérarchie d'un groupe.

**Types de valeurs autorisés** :

- `Boolean` (l'une des valeurs suivantes : `true` ou `false`)

**Notes** :

- Ce champ ne peut être utilisé qu'avec une portée `group`.
- La valeur par défaut de ce champ est `false`.

### Labels {#mr-labels}

**Description** : interroger les merge requests par leurs labels associés.

**Types de valeurs autorisés** :

- `String`
- `Label` (par exemple, `~bug`, `~"team::planning"`)
- `Nullable` (l'une des valeurs suivantes : `none` ou `any`)

**Notes** :

- L'opérateur `in` n'est pas pris en charge pour les merge requests.
- Les labels à portée limitée ou les labels contenant des espaces doivent être encadrés par des guillemets.

### Fusionné le {#mr-merged-at}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.
- L'alias `mergedAt` [introduit](https://gitlab.com/gitlab-org/glql/-/merge_requests/137) dans GitLab 18.0.
- Les opérateurs `>=` et `<=` [introduits](https://gitlab.com/gitlab-org/gitlab-query-language/glql-rust/-/work_items/58) dans GitLab 18.0.

{{< /history >}}

**Description** : interroger les merge requests par la date à laquelle elles ont été fusionnées.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs suivantes : `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

### Fusionné par l'utilisateur {#mr-merged-by-user}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.
- L'alias `mergedBy` [introduit](https://gitlab.com/gitlab-org/glql/-/merge_requests/137) dans GitLab 18.0.

{{< /history >}}

**Description** : interroger les merge requests par l'utilisateur qui a fusionné la merge request.

**Types de valeurs autorisés** :

- `String`
- `User` (par exemple, `@username`)

### Jalon {#mr-milestone}

**Description** : interroger les merge requests par leur jalon associé.

**Types de valeurs autorisés** :

- `String`
- `Milestone` (par exemple, `%Backlog`, `%"Awaiting Further Demand"`)
- `Nullable` (l'une des valeurs suivantes : `none` ou `any`)

**Notes** :

- L'opérateur `in` n'est pas pris en charge pour les merge requests.
- Les jalons contenant des espaces doivent être encadrés par des guillemets (`"`).

### Mon emoji de réaction {#mr-my-reaction-emoji}

**Description** : interroger les merge requests par la [réaction emoji](../../emoji_reactions.md) de l'utilisateur actuel sur celle-ci.

**Types de valeurs autorisés** : `String`

### État de relecture {#mr-review-state}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/glql/-/merge_requests/508) dans GitLab 19.5.

{{< /history >}}

**Description** : interroger les merge requests par l'état de relecture de leurs relecteurs. Pour plus d'informations sur les états de relecture, voir [Relectures des merge requests](../../project/merge_requests/reviews/_index.md).

**Types de valeurs autorisés** :

- `Enum`, l'une des valeurs suivantes : `unreviewed`, `review_started`, `reviewed`, `requested_changes`, `approved` ou `unapproved`
- `List` (contenant des valeurs `Enum`)

**Notes** :

- Les valeurs `List` ne sont prises en charge qu'avec les opérateurs `in` et `!=`.
- Une merge request correspond lorsqu'au moins un de ses relecteurs est dans l'état donné, et non lorsque tous les relecteurs le sont.
- En combinaison avec `reviewer = @username`, `=` et `in` s'appliquent uniquement à ce relecteur. `!=` s'applique à tous les relecteurs : `reviewer = @username and reviewState != approved` retourne les merge requests où l'utilisateur est relecteur et aucun relecteur n'a approuvé.
- Les merge requests sans relecteurs ne correspondent jamais, donc `reviewState` ne peut pas être combiné avec `reviewer = any` ou `reviewer = none`.
- Pour exclure plusieurs états, utilisez un `List` : `reviewState != (approved, unapproved)`.

### Relecteurs {#mr-reviewers}

{{< history >}}

- Les alias `reviewers` et `reviewedBy` [introduits](https://gitlab.com/gitlab-org/glql/-/merge_requests/137) dans GitLab 18.0.

{{< /history >}}

**Description** : interroger les merge requests qui ont été relues par un ou plusieurs utilisateurs.

**Types de valeurs autorisés** :

- `String`
- `User` (par exemple, `@username`)
- `Nullable` (l'une des valeurs suivantes : `null`, `none` ou `any`)

### Branche source {#mr-source-branch}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197407) dans GitLab 18.2.

{{< /history >}}

**Description :** Interroger les merge requests par leur branche source.

**Types de valeurs autorisés :** `String`, `List`

**Notes** :

- Les valeurs `List` ne sont prises en charge qu'avec les opérateurs `in` et `!=`.

### État {#mr-state}

**Description** : interroger les merge requests par statut.

**Types de valeurs autorisés** :

- `Enum`, l'une des valeurs suivantes : `opened`, `closed`, `merged` ou `all`

**Notes** :

- Le champ `state` ne prend pas en charge l'opérateur `!=`.

### Abonné {#mr-subscribed}

**Description** : interroger les merge requests selon que l'utilisateur actuel a [activé ou désactivé les notifications](../../profile/notifications.md).

**Types de valeurs autorisés** : `Boolean`

### Branche cible {#mr-target-branch}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197407) dans GitLab 18.2.

{{< /history >}}

**Description :** Interroger les merge requests par leur branche cible.

**Types de valeurs autorisés :** `String`, `List`

**Notes** :

- Les valeurs `List` ne sont prises en charge qu'avec les opérateurs `in` et `!=`.

### Mis à jour le {#mr-updated-at}

**Description** : interroger les merge requests par leur date de dernière mise à jour.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs suivantes : `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

## Champs d'affichage {#display-fields}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/491246) dans GitLab 17.8.
- Les champs `sourceBranch`, `targetBranch`, `sourceProject` et `targetProject` [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197407) dans GitLab 18.2.

{{< /history >}}

| Champ            | Nom ou alias                         | Description |
| ---------------- | ------------------------------------- | ----------- |
| Approuvé         | `approved`                            | Affiche `Yes` ou `No` indiquant si la merge request a été approuvée |
| Approuvé par l'utilisateur | `approver`, `approvers`, `approvedBy` | Affiche les utilisateurs qui ont approuvé la merge request |
| Assignés        | `assignee`, `assignees`               | Affiche les utilisateurs assignés à la merge request |
| Auteur           | `author`                              | Affiche l'auteur de la merge request |
| Fermé le        | `closed`, `closedAt`                  | Affiche le temps écoulé depuis la fermeture de la merge request |
| Créé le       | `created`, `createdAt`                | Affiche le temps écoulé depuis la création de la merge request |
| Description      | `description`                         | Affiche la description de la merge request |
| Brouillon            | `draft`                               | Affiche `Yes` ou `No` indiquant si la merge request est en état de brouillon |
| ID               | `id`                                  | Affiche l'identifiant de la merge request |
| Labels           | `label`, `labels`                     | Affiche les labels associés à la merge request |
| Dernier commentaire     | `lastComment`                         | Affiche le dernier commentaire effectué sur la merge request |
| Fusionné le        | `merged`, `mergedAt`                  | Affiche le temps écoulé depuis la fusion de la merge request |
| Fusionné par l'utilisateur   | `merger`, `mergedBy`                  | Affiche l'utilisateur qui a fusionné la merge request |
| Jalon        | `milestone`                           | Affiche le jalon associé à la merge request |
| Projet          | `project`                             | Affiche le projet auquel appartient la merge request |
| Relecteurs        | `reviewer`, `reviewers`               | Affiche les utilisateurs assignés à la relecture de la merge request |
| Branche source    | `sourceBranch`                        | Affiche la branche source de la merge request |
| Projet source   | `sourceProject`                       | Affiche le projet source de la merge request |
| État            | `state`                               | Affiche un badge indiquant le statut. Les valeurs sont `Open`, `Closed` ou `Merged` |
| Abonné       | `subscribed`                          | Affiche `Yes` ou `No` indiquant si l'utilisateur actuel est abonné |
| Branche cible    | `targetBranch`                        | Affiche la branche cible de la merge request |
| Projet cible   | `targetProject`                       | Affiche le projet cible de la merge request |
| Estimation de temps    | `timeEstimate`                        | Affiche le temps estimé pour la merge request |
| Titre            | `title`                               | Affiche le titre de la merge request |
| Temps total passé | `totalTimeSpent`                      | Affiche le temps total passé sur la merge request |
| Mis à jour le       | `updated`, `updatedAt`                | Affiche le temps écoulé depuis la dernière mise à jour de la merge request |

## Champs de tri {#sort-fields}

| Champ         | Nom (et alias)       | Description                                     |
|---------------|------------------------|-------------------------------------------------|
| Fermé le     | `closed`, `closedAt`   | Trier par date de fermeture                             |
| Créé       | `created`, `createdAt` | Trier par date de création                            |
| Fusionné le     | `merged`, `mergedAt`   | Trier par date de fusion                              |
| Jalon     | `milestone`            | Trier par date d'échéance du jalon                      |
| Popularité    | `popularity`           | Trier par nombre de réactions emoji « pouce levé » |
| Titre         | `title`                | Trier par titre                                   |
| Mis à jour le    | `updated`, `updatedAt` | Trier par date de dernière mise à jour                       |

## Exemples {#examples}

- Lister les merge requests ouvertes dans le projet `gitlab-org/gitlab` qui attendent une première relecture :

  ````yaml
  ```glql
  display: table
  fields: title, author, reviewer, updated
  sort: updated asc
  query: project = "gitlab-org/gitlab" and type = MergeRequest and state = opened and draft = false and reviewState = unreviewed
  limit: 10
  ```
  ````

- Lister toutes les merge requests dans le groupe `gitlab-org` créées par moi, triées par date de fusion (les plus récentes en premier) :

  ````yaml
  ```glql
  display: table
  fields: title, reviewer, merged
  sort: merged desc
  query: group = "gitlab-org" and type = MergeRequest and state = merged and author = currentUser()
  limit: 10
  ```
  ````
