---
stage: Analytics
group: Platform Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Jobs
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/228521) dans GitLab 18.11.
- Champs `browseArtifactsPath`, `canPlayJob`, `commitPath`, `createdByTag`, `exitCode`, `pipeline`, `playPath`, `queuedDuration`, `refPath`, `retryPath` et `scheduledAt` [ajoutés](https://gitlab.com/gitlab-org/glql/-/merge_requests/361) dans GitLab 18.11.

{{< /history >}}

> [!note]
> Les jobs ne prennent pas en charge le tri.

## Portées autorisées {#allowed-scopes}

| Portée     | Description                           |
| --------- | ------------------------------------- |
| `project` | Interroger les jobs dans un projet spécifique.     |

Pour plus d'informations, voir [portées](_index.md#scopes).

## Filtres de requête {#query-filters}

Utilisez ces champs dans le paramètre `query` pour filtrer vos résultats.

| Champ                                          | Nom                | Opérateurs  |
| ---------------------------------------------- | ------------------- | ---------- |
| [Type](#job-kind)                              | `kind`              | `=`        |
| [Pipeline](#job-pipeline)                      | `pipeline`          | `=`        |
| [Statut](#job-status)                          | `status`            | `=`        |
| [Avec artefacts](#job-with-artifacts)          | `withArtifacts`     | `=`, `!=`  |

### Type {#job-kind}

**Description** : filtrer les jobs selon leur type.

**Types de valeurs autorisés** :

- `Enum`, l'une des valeurs `bridge` ou `build`

**Notes** :

- Les jobs `bridge` sont des jobs déclencheurs qui démarrent des pipelines downstream.
- Les jobs `build` sont des jobs CI/CD standard.

### Pipeline {#job-pipeline}

**Description** : filtrer les jobs selon le pipeline auquel ils appartiennent, en utilisant l'IID du pipeline.

**Types de valeurs autorisés** : `Number` (IID du pipeline)

### Statut {#job-status}

**Description** : filtrer les jobs selon leur statut CI/CD.

**Types de valeurs autorisés** :

- `Enum`, l'une des valeurs `canceled`, `canceling`, `created`, `failed`, `manual`, `pending`, `preparing`, `running`, `scheduled`, `skipped`, `success`, `waiting_for_callback` ou `waiting_for_resource`

### Avec artefacts {#job-with-artifacts}

**Description** : filtrer les jobs selon qu'ils possèdent ou non des artefacts.

**Types de valeurs autorisés** : `Boolean` (`true` ou `false`)

## Champs d'affichage {#display-fields}

| Champ                  | Nom (et alias)                   | Description |
| ---------------------- | ---------------------------------- | ----------- |
| Actif                 | `active`                           | Afficher si le job est actif |
| Autoriser l'échec          | `allowFailure`                     | Afficher si le job est autorisé à échouer |
| Chemin de navigation des artefacts  | `browseArtifactsPath`              | Afficher l'URL permettant de parcourir l'archive des artefacts du job |
| Peut exécuter le job           | `canPlayJob`                       | Afficher si l'utilisateur actuel peut exécuter le job |
| Annulable             | `cancelable`                       | Afficher si le job peut être annulé |
| Chemin du commit            | `commitPath`                       | Afficher le chemin vers le commit qui a déclenché le job |
| Couverture               | `coverage`                         | Afficher le pourcentage de couverture du code |
| Créé le             | `created`, `createdAt`             | Afficher la date de création du job |
| Créé par un tag         | `createdByTag`                     | Afficher si le job a été créé par un tag |
| Durée               | `duration`                         | Afficher la durée du job |
| Effacé le              | `erased`, `erasedAt`               | Afficher la date à laquelle les artefacts du job ont été effacés |
| Code de sortie              | `exitCode`                         | Afficher le code de sortie du job |
| Message d'échec        | `failureMessage`                   | Afficher le message d'échec |
| Terminé le            | `finished`, `finishedAt`           | Afficher la date de fin du job |
| ID                     | `id`                               | Afficher l'ID du job |
| Type                   | `kind`                             | Afficher le type du job (`bridge` ou `build`) |
| Job manuel             | `manualJob`                        | Afficher s'il s'agit d'un job manuel |
| Nom                   | `name`                             | Afficher le nom du job |
| Pipeline               | `pipeline`                         | Afficher le pipeline auquel appartient le job |
| Chemin d'exécution              | `playPath`                         | Afficher le chemin pour exécuter le job |
| Exécutable               | `playable`                         | Afficher si le job peut être exécuté |
| Mis en file d'attente le              | `queued`, `queuedAt`               | Afficher la date à laquelle le job a été mis en file d'attente |
| Durée en file d'attente        | `queuedDuration`                   | Afficher la durée pendant laquelle le job a été en file d'attente avant de démarrer |
| Nom de la référence               | `refName`                          | Afficher le nom de la référence Git |
| Chemin de la référence               | `refPath`                          | Afficher le chemin vers la référence qui a déclenché le job |
| Réessayé                | `retried`                          | Afficher si le job a été réessayé |
| Chemin de nouvelle tentative             | `retryPath`                        | Afficher le chemin pour réessayer le job |
| Peut être réessayé              | `retryable`                        | Afficher si le job peut être réessayé |
| Planifié              | `scheduled`                        | Afficher si le job est planifié |
| Planifié le           | `scheduledAt`                      | Afficher la date à laquelle le job était planifié pour s'exécuter |
| Type de planification        | `schedulingType`                   | Afficher le type de planification |
| SHA court              | `shortSha`                         | Afficher le SHA court du commit |
| Source                 | `source`                           | Afficher la source du job |
| Étape                  | `stage`                            | Afficher l'étape du pipeline à laquelle appartient le job |
| Démarré le             | `started`, `startedAt`             | Afficher la date de démarrage du job |
| Statut                 | `status`                           | Afficher le statut du job |
| Bloqué                  | `stuck`                            | Afficher si le job est bloqué |
| Tags                   | `tags`                             | Afficher les tags du runner |
| Déclenché              | `triggered`                        | Afficher si le job a été déclenché |
| Chemin web               | `webPath`                          | Afficher le chemin web vers le job |

## Exemples {#examples}

- Répertorier tous les jobs échoués dans le projet `gitlab-org/gitlab` :

  ````yaml
  ```glql
  display: table
  fields: name, status, stage, startedAt
  query: type = Job and project = "gitlab-org/gitlab" and status = failed
  ```
  ````

- Répertorier tous les jobs avec des artefacts dans le projet `gitlab-org/gitlab` :

  ````yaml
  ```glql
  display: table
  fields: name, status, stage
  query: type = Job and project = "gitlab-org/gitlab" and withArtifacts = true
  ```
  ````
