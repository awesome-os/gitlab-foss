---
stage: Analytics
group: Platform Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Analyse des merge requests
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/21214) dans GitLab 19.3.
- `timeToMergeQuantile` [modifié](https://gitlab.com/gitlab-org/glql/-/merge_requests/501) pour indiquer les secondes dans GitLab 19.5.
- Les métriques `timeToMergeMin`, `timeToMergeMax`, `timeToMergeMean` et `timeToMergeSum` ont été [introduites](https://gitlab.com/gitlab-org/glql/-/merge_requests/507) dans GitLab 19.5.
- Le filtre et la dimension `createdByDuo`, ainsi que la métrique `acceptanceRate`, ont été [introduits](https://gitlab.com/gitlab-org/glql/-/merge_requests/518) dans GitLab 19.5.
- Les opérateurs `!=` et `not in` sur les filtres `state` et `targetBranch` ont été [introduits](https://gitlab.com/gitlab-org/glql/-/merge_requests/537) dans GitLab 19.5.

{{< /history >}}

Le mode analytique renvoie des métriques agrégées pour les merge requests, avec des données généralement disponibles dans un délai de 10 minutes.

Pour interroger des enregistrements de merge requests individuels, utilisez [Merge requests](merge_requests.md).

## Portées autorisées {#allowed-scopes}

| Portée     | Description                                                               |
| --------- | -------------------------------------------------------------------------- |
| `project` | Interroger les merge requests dans un projet spécifique.                               |
| `group`   | Interroger les merge requests dans tous les projets d'un groupe, y compris les sous-groupes. |

Pour agréger les merge requests sur plusieurs groupes ou projets, utilisez une liste avec l'opérateur `in`. Pour plus d'informations, consultez [plusieurs groupes et projets](_index.md#multiple-groups-and-projects).

## Filtres de requête {#query-filters}

Utilisez ces champs dans le paramètre `query` pour filtrer vos résultats.

| Champ                              | Nom           | Opérateurs                 |
| ---------------------------------- | -------------- | ------------------------- |
| [Créé à](#created-at)          | `created`      | `=`, `>`, `<`, `>=`, `<=` |
| [Créé par Duo](#created-by-duo)  | `createdByDuo` | `=`, `!=`                 |
| [Fusionné à](#merged-at)            | `merged`       | `=`, `>`, `<`, `>=`, `<=` |
| [État](#state)                    | `state`        | `=`, `!=`, `in`, `not in` |
| [Branche cible](#target-branch)    | `targetBranch` | `=`, `!=`, `in`, `not in` |

### Créé à {#created-at}

**Description** : filtrer les merge requests par date de création.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

### Créé par Duo {#created-by-duo}

**Description** : filtrer les merge requests selon qu'une session GitLab Duo Agent Platform les a créées ou non.

**Types de valeurs autorisés** :

- `Boolean` (`true` ou `false`)

### Fusionné à {#merged-at}

**Description** : filtrer les merge requests par date de fusion.

**Types de valeurs autorisés** :

- `AbsoluteDate` (au format `YYYY-MM-DD`)
- `RelativeDate` (au format `<sign><digit><unit>`, où le signe est `+`, `-`, ou omis, le chiffre est un entier, et `unit` est l'une des valeurs `d` (jours), `w` (semaines), `m` (mois) ou `y` (années))

**Notes** :

- Pour l'opérateur `=`, la plage horaire est considérée de 00:00 à 23:59 dans le fuseau horaire de l'utilisateur.

### État {#state}

**Description** : filtrer les merge requests par état.

**Types de valeurs autorisés** :

- `Enum`, l'une des valeurs `opened`, `closed`, `merged` ou `locked`
- `List` (utilisez l'opérateur `in` ou `not in` pour plusieurs valeurs)

**Notes** :

- La valeur `all` n'est pas prise en charge. Pour inclure les merge requests dans tous les états, omettez le filtre.

### Branche cible {#target-branch}

**Description** : filtrer les merge requests par branche cible.

**Types de valeurs autorisés** :

- `String`
- `List` (utilisez l'opérateur `in` ou `not in` pour plusieurs valeurs)

## Dimensions {#dimensions}

| Dimension     | Nom           | Description                              |
| ------------- | -------------- | ---------------------------------------- |
| Créé à    | `created`      | Regrouper par date de création. Accepte un [paramètre `granularity`](../_index.md#field-parameters) parmi `daily`, `weekly`, `monthly`, ou un nombre de jours tel que `30d` (par défaut : `weekly`), ainsi qu'un `origin` facultatif. Par exemple, `created(monthly)` ou `created(granularity=30d, origin=2026-07-16)`. |
| Créé par Duo | `createdByDuo` | Regrouper selon qu'une session GitLab Duo Agent Platform a créé la merge request ou non. |
| Fusionné à     | `merged`       | Regrouper par date de fusion. Accepte un [paramètre `granularity`](../_index.md#field-parameters) parmi `daily`, `weekly`, `monthly`, ou un nombre de jours tel que `30d` (par défaut : `weekly`), ainsi qu'un `origin` facultatif. Par exemple, `merged(monthly)` ou `merged(granularity=30d, origin=2026-07-16)`. |
| État         | `state`        | Regrouper par état de merge request.            |
| Branche cible | `targetBranch` | Regrouper par branche cible.                  |

## Métriques {#metrics}

| Métrique                 | Nom                   | Description                              |
| ---------------------- | ---------------------- | ---------------------------------------- |
| Taux d'acceptation        | `acceptanceRate`       | Part des merge requests qui ont été fusionnées. |
| Nombre de traitements       | `throughputCount`      | Nombre de merge requests fusionnées.         |
| Délai de fusion maximum      | `timeToMergeMax`       | Délai le plus long entre la création et la fusion, en secondes. |
| Délai de fusion moyen     | `timeToMergeMean`      | Délai moyen entre la création et la fusion, en secondes. |
| Délai de fusion minimum      | `timeToMergeMin`       | Délai le plus court entre la création et la fusion, en secondes. |
| Quantile du délai de fusion | `timeToMergeQuantile`  | Délai entre la création et la fusion, en secondes, affiché sous forme de durée. Par exemple, `1d 2h`. Accepte un [paramètre `quantile`](../_index.md#field-parameters) compris entre `0.01` et `0.99` (par défaut : `0.5`, la médiane). Par exemple, `timeToMergeQuantile(0.95)`. |
| Somme des délais de fusion      | `timeToMergeSum`       | Délai total entre la création et la fusion pour l'ensemble des merge requests fusionnées, en secondes. |
| Nombre total            | `totalCount`           | Nombre total de merge requests.          |

## Champs de tri {#sort-fields}

Trier selon n'importe quel champ inclus dans les dimensions ou métriques sélectionnées. Pour plus d'informations, consultez [le tri en mode analytique](../_index.md#sorting).

## Exemples {#examples}

- Tendance hebdomadaire du débit des merge requests pour les 30 derniers jours :

  ````yaml
  ```glql
  title: "Weekly merge request throughput (last 30 days)"
  display: table
  mode: analytics
  query: type = MergeRequest and project = "gitlab-org/gitlab" and merged > -30d
  dimensions: merged(weekly) as "Week"
  metrics: totalCount as "Total", throughputCount as "Merged", timeToMergeQuantile(0.5) as "Median time to merge"
  sort: merged desc
  ```
  ````

- Délais de fusion médian et p95 par semaine :

  ````yaml
  ```glql
  title: "Median and p95 time to merge by week"
  display: table
  mode: analytics
  query: type = MergeRequest and project = "gitlab-org/gitlab" and merged > -90d
  dimensions: merged(weekly) as "Week"
  metrics: timeToMergeQuantile(0.5) as "Median time to merge", timeToMergeQuantile(0.95) as "p95 time to merge"
  sort: merged desc
  ```
  ````

- Merge requests regroupées par état :

  ````yaml
  ```glql
  title: "Merge requests by state (last 30 days)"
  display: table
  mode: analytics
  query: type = MergeRequest and project = "gitlab-org/gitlab" and created > -30d
  dimensions: state as "State"
  metrics: totalCount as "Total"
  sort: totalCount desc
  ```
  ````

- Débit par branche cible dans un groupe :

  ````yaml
  ```glql
  title: "Merge request throughput by target branch"
  display: table
  mode: analytics
  query: type = MergeRequest and group = "gitlab-org" and merged > -30d
  dimensions: targetBranch as "Target branch"
  metrics: totalCount as "Total", throughputCount as "Merged"
  sort: throughputCount desc
  ```
  ````

- Taux d'acceptation des merge requests créées par GitLab Duo par rapport aux autres merge requests :

  ````yaml
  ```glql
  title: "Merge request acceptance rate by origin (last 30 days)"
  display: table
  mode: analytics
  query: type = MergeRequest and group = "gitlab-org" and created > -30d
  dimensions: createdByDuo as "Created by Duo"
  metrics: totalCount as "Total", throughputCount as "Merged", acceptanceRate as "Acceptance rate"
  sort: totalCount desc
  ```
  ````

- Nombre total de merge requests pour un groupe, sans regroupement :

  ````yaml
  ```glql
  title: "Merge requests created in the last 7 days"
  display: table
  mode: analytics
  query: type = MergeRequest and group = "gitlab-org" and created > -7d
  metrics: totalCount as "Total"
  ```
  ````
