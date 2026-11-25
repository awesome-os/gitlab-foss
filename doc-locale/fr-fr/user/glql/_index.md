---
stage: Analytics
group: Platform Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: GitLab Query Language (GLQL)
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/work_items/14767) dans GitLab 17.4 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `glql_integration`. Fonctionnalité désactivée par défaut.
- Activé sur GitLab.com dans GitLab 17.4 pour un sous-ensemble de groupes et de projets.
- [Passé](https://gitlab.com/gitlab-org/gitlab/-/issues/476990) de version expérimentale à version bêta dans GitLab 17.10.
- [Activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/work_items/476990) dans GitLab 17.10.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/554870) dans GitLab 18.3. Suppression du feature flag `glql_integration`.

{{< /history >}}

GitLab Query Language (GLQL) est un langage de requête unique pour l'ensemble de GitLab. Utilisez-le pour filtrer et intégrer du contenu depuis n'importe quel endroit de la plateforme, à l'aide d'une syntaxe familière.

Intégrez des requêtes dans des blocs de code Markdown. Une vue intégrée est le rendu d'un bloc de code source GLQL.

Partagez vos commentaires dans le [ticket de feedback sur les vues intégrées, propulsées par GLQL](https://gitlab.com/gitlab-org/gitlab/-/issues/509792).

## Syntaxe de requête {#query-syntax}

La syntaxe de requête est principalement composée d'expressions logiques. Ces expressions suivent la syntaxe `<field> <operator> <value> and ...`.

### Sources de données {#data-sources}

GLQL peut interroger différentes sources de données telles que les éléments de travail, les merge requests, les pipelines, les jobs et les projets.

Pour une liste complète des sources de données prises en charge, consultez [les sources de données GLQL](data_sources/_index.md).

### Champs {#fields}

Utilisez les champs pour filtrer, afficher et trier les résultats.

Les champs que vous pouvez utiliser dépendent de la source de données que vous interrogez. Pour une liste complète des champs, opérateurs et valeurs pris en charge pour chaque source de données, consultez [les champs GLQL](fields.md).

### Opérateurs {#operators}

{{< history >}}

- La combinaison de `=` avec une autre comparaison sur le même champ de date ou de plage [a été modifiée](https://gitlab.com/gitlab-org/glql/-/merge_requests/516) pour renvoyer une erreur dans GitLab 19.5. Auparavant, une seule des deux conditions était appliquée.
- L'opérateur `not in` a été [introduit](https://gitlab.com/gitlab-org/glql/-/merge_requests/537) dans GitLab 19.5 pour les filtres de liste sur les sources de données analytiques.

{{< /history >}}

**Opérateurs de comparaison** :

| Opérateur GLQL | Description                             | Équivalent dans la recherche   |
|---------------|-----------------------------------------|------------------------|
| `=`           | Égal à / Inclut tous les éléments de la liste           | `is` (égal à)        |
| `!=`          | Différent de / N'est pas contenu dans la liste | `is not` (égal à)    |
| `in`          | Contenu dans la liste                       | `or` / `is one of`     |
| `not in`      | Non contenu dans la liste                   | `is not one of`        |
| `>`           | Supérieur à                            | {{< no >}} |
| `<`           | Inférieur à                               | {{< no >}} |
| `>=`          | Supérieur ou égal à                | {{< no >}} |
| `<=`          | Inférieur ou égal à                   | {{< no >}} |

**Opérateurs logiques** : seul `and` est pris en charge. `or` est indirectement pris en charge pour certains champs via l'opérateur de comparaison `in`.

L'opérateur `not in` exclut toutes les valeurs d'une liste, par exemple `flowType not in ("chat", "agentic_chat/v1")`. Il est disponible sur les champs de source de données analytiques qui le listent, et la liste doit contenir au moins une valeur. Utilisez `!=` pour exclure une seule valeur.

> [!note]
> Sur les champs où `=` sélectionne une plage, comme un seul jour sur les champs de date ou un nombre exact sur les filtres de plage tels que `activeDays`, vous ne pouvez pas combiner `=` avec une autre comparaison sur le même champ. Par exemple, `created = 2024-01-01 and created > 2023-01-01` renvoie une erreur. Utilisez soit l'égalité, soit la plage. Cela s'applique à toutes les sources de données et à tous les modes.

### Valeurs {#values}

Les valeurs peuvent inclure :

- Chaînes de caractères
- Nombres
- Dates relatives (comme `-1d`, `2w`, `-6m` ou `1y`)
- Dates absolues (au format `YYYY-MM-DD`, comme `2025-01-01`)
- Fonctions (comme `currentUser()` pour les champs utilisateur ou `today()` pour les dates)
- Valeurs d'énumération (comme `upcoming` ou `started` pour les jalons)
- Booléens (`true` ou `false`)
- Valeurs nullables (comme `null`, `none` ou `any`)
- Références GitLab (comme `~label` pour un label, `%Backlog` pour un jalon ou `@username` pour un utilisateur)
- Listes contenant n'importe laquelle des valeurs précédentes (entourées de parenthèses : `()` et délimitées par des virgules : `,`)

## Vues intégrées {#embedded-views}

Une vue intégrée est le rendu d'un bloc de code source GLQL en Markdown. La source inclut des attributs YAML qui décrivent comment afficher les résultats de la requête GLQL, ainsi que la requête elle-même.

### Zones prises en charge {#supported-areas}

{{< history >}}

- Les vues intégrées dans les fichiers Markdown du dépôt ont été [introduites](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197950) dans GitLab 18.3.

{{< /history >}}

Les vues intégrées peuvent être affichées dans les zones suivantes :

- Wikis de groupe et de projet
- Descriptions et commentaires de :
  - Les epics
  - Les tickets
  - Les merge requests
  - Éléments de travail (tâches, OKR ou epics)
- Fichiers Markdown du dépôt

### Syntaxe {#syntax}

La syntaxe de la source d'une vue intégrée est un sur-ensemble de YAML qui se compose de :

- Le paramètre `query` : Expressions jointes par un opérateur logique, tel que `and`.
- Paramètres liés à la couche de présentation, comme `display`, `limit`, ou `fields`, `title` et `description` représentés en YAML.

Une vue est définie en Markdown sous forme de bloc de code, de manière similaire à d'autres blocs de code comme Mermaid.

Par exemple :

- Afficher un tableau des 5 premiers tickets ouverts assignés à l'utilisateur authentifié dans `gitlab-org/gitlab`.
- Afficher les colonnes `title`, `state`, `health`, `description`, `epic`, `milestone`, `weight` et `updated`.

````yaml
```glql
display: table
title: GLQL table 🎉
description: This view lists my open issues
fields: title, state, health, epic, milestone, weight, updated
limit: 5
query: type = Issue AND group = "gitlab-org" AND assignee = currentUser() AND state = opened
```
````

Cette source doit afficher un tableau similaire à celui ci-dessous :

![Un tableau listant les tickets assignés à l'utilisateur actuel](img/glql_table_v18_5.png)

#### Syntaxe de présentation {#presentation-syntax}

{{< history >}}

- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/508956) dans GitLab 17.7 : la configuration de la couche de présentation à l'aide du front matter YAML est dépréciée.
- Les paramètres `title` et `description` ont été [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/183709) dans GitLab 17.10.
- Le tri et la pagination ont été [introduits](https://gitlab.com/gitlab-org/gitlab/-/issues/502701) dans GitLab 18.2.
- Le paramètre `collapsed` a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197824) dans GitLab 18.3.

{{< /history >}}

En dehors du paramètre `query`, vous pouvez configurer les détails de présentation de votre vue à l'aide de paramètres optionnels supplémentaires.

Paramètres pris en charge :

| Paramètre     | Valeur par défaut                                       | Description |
| ------------- | --------------------------------------------- | ----------- |
| `collapsed`   | `false`                                       | Indique si la vue doit être réduite ou développée. |
| `description` | Aucune                                          | Une description facultative à afficher sous le titre. |
| `display`     | `list`                                        | La manière d'afficher les résultats de la requête. Pour les types disponibles, consultez [Types d'affichage](#display-types). |
| `displayConfig` | Aucune                                        | Options spécifiques au type d'affichage, comme `stacked` pour les graphiques en colonnes. Consultez [Types d'affichage](display_types.md). |
| `fields`      | `title`                                       | Une liste de [champs](fields.md) séparés par des virgules à inclure dans la vue. |
| `limit`       | `100`                                         | Le nombre d'éléments à afficher sur la première page. La valeur maximale est `100`. |
| `sort`        | `updated desc`                                | Le [champ de tri des données](fields.md) suivi d'un ordre de tri (`asc` ou `desc`). |
| `title`       | `Embedded table view` ou `Embedded list view` | Un titre affiché en haut de la vue intégrée. |

#### Pagination {#pagination}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/502701) dans GitLab 18.2.

{{< /history >}}

Les vues intégrées affichent la première page de résultats par défaut. Le paramètre `limit` contrôle le nombre d'éléments affichés.

Pour charger la page suivante, dans la dernière ligne, sélectionnez **Charger davantage**.

#### Fonctions de champ {#field-functions}

Pour créer des colonnes générées dynamiquement, utilisez des fonctions dans les paramètres `fields` des vues. Pour une liste complète, consultez [Fonctions dans les vues intégrées](functions.md#functions-in-embedded-views).

#### Alias de champs personnalisés {#custom-field-aliases}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/535558) dans GitLab 18.0.

{{< /history >}}

Pour renommer la colonne d'une vue en tableau avec une valeur personnalisée, utilisez le mot-clé de syntaxe `AS` pour créer des alias de champs.

````yaml
```glql
display: list
fields: title, labels("workflow::*") AS "Workflow", labels("priority::*") AS "Priority"
limit: 5
query: type = Issue AND project = "gitlab-org/gitlab" AND assignee = currentUser() AND state = opened
```
````

Cette source affiche une vue avec les colonnes `Title`, `Workflow` et `Priority`.

### Types d'affichage {#display-types}

Le paramètre `display` contrôle la façon dont une vue intégrée affiche les résultats de requête, par exemple sous forme de liste, de tableau ou de graphique en colonnes. Par défaut, les résultats sont affichés sous forme de liste.

Pour la liste complète des types d'affichage et leur configuration, consultez [les types d'affichage GLQL](display_types.md).

### Actions sur les vues {#view-actions}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/184788) dans GitLab 17.11.
- L'action **Recharger** a été [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/537310) dans GitLab 18.0.

{{< /history >}}

Lorsqu'une vue apparaît sur une page, utilisez la liste déroulante **Actions sur les vues** ({{< icon name="ellipsis_v" >}}) pour effectuer une action sur celle-ci.

Actions prises en charge :

| Action        | Description                                                    |
| ------------- | -------------------------------------------------------------- |
| Afficher la source   | Afficher la source de la vue.                                   |
| Copier la source   | Copier la source de la vue dans le presse-papiers.                      |
| Copier le contenu | Copier le contenu du tableau ou de la liste dans le presse-papiers. |
| Recharger        | Recharger cette vue.                                              |

## Mode analytique {#analytics-mode}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/21212) dans GitLab 19.1.

{{< /history >}}

GLQL prend en charge un mode analytique pour les sources de données qui fournissent des métriques agrégées. Les requêtes en mode analytique utilisent `dimensions` et `metrics` au lieu de `fields` pour regrouper et agréger les données.

Certaines sources de données prennent en charge à la fois le mode standard et le mode analytique. Consultez la page de chaque [source de données](data_sources/_index.md) pour connaître les modes pris en charge.

### Syntaxe {#syntax-1}

Les requêtes en mode analytique utilisent la structure suivante :

````yaml
```glql
mode: analytics
query: type = <DataSource> and <filters>
dimensions: <dimension fields>
metrics: <metric fields>
sort: <field> <direction>
limit: <number>
```
````

| Paramètre | Obligatoire | Description |
|-----------|----------|-------------|
| `mode: analytics` | Oui | Requis pour utiliser le mode analytique. |
| `metrics` | Oui | Valeurs agrégées à calculer. Au moins une métrique est requise. |
| `dimensions` | Non | Champs permettant de regrouper les résultats. Sélectionnez n'importe quelle combinaison, ou omettez entièrement pour renvoyer une seule ligne agrégée. |
| `sort` | Non | Les champs de tri doivent également apparaître dans les dimensions ou métriques sélectionnées. |
| `limit` | Non | Lignes par page, jusqu'à `100`. Les types d'affichage en mode analytique, comme les graphiques et les statistiques, récupèrent automatiquement toutes les pages lorsque `limit` est omis, jusqu'à 1 000 lignes. Consultez [Prise en charge de la pagination](display_types.md#pagination-support). |

### Paramètres de champ {#field-parameters}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/glql/-/issues/130) dans GitLab 19.3.
- Les valeurs de liste dans les paramètres de champ ont été [introduites](https://gitlab.com/gitlab-org/glql/-/merge_requests/522) dans GitLab 19.5.
- Les valeurs `granularity` à nombre de jours fixe ont été [introduites](https://gitlab.com/gitlab-org/glql/-/merge_requests/528) dans GitLab 19.5.
- Le paramètre `origin` a été [introduit](https://gitlab.com/gitlab-org/glql/-/merge_requests/529) dans GitLab 19.5.

{{< /history >}}

Certaines dimensions et métriques acceptent un paramètre entre parenthèses après le nom du champ. Si vous omettez le paramètre, le champ utilise sa valeur par défaut. Vous pouvez passer le paramètre par position (`finished(weekly)`) ou par nom (`finished(granularity=weekly)`).

Un argument positionnel unique est lié au premier paramètre du champ, par exemple `created(30d)`. Lorsque vous passez plusieurs paramètres, utilisez la syntaxe nommée, par exemple `created(granularity=30d, origin=2026-07-16)`. Deux arguments positionnels renvoient une erreur.

Pour les champs qui acceptent des paramètres et leurs valeurs par défaut, consultez les pages [de source de données](data_sources/_index.md). Pour inclure le même champ plusieurs fois avec des paramètres différents, consultez [les alias personnalisés](#custom-aliases).

Par exemple, la requête suivante renvoie la durée médiane des pipelines en intervalles hebdomadaires :

````yaml
```glql
mode: analytics
query: type = Pipeline and project = "gitlab-org/gitlab" and finished >= -90d
dimensions: finished(weekly)
metrics: durationQuantile(0.5)
sort: finished desc
```
````

#### Valeurs de liste {#list-values}

Certains paramètres acceptent une liste. Écrivez-la entre crochets, par exemple `name(key=[v1, v2])` ou `name([v1, v2])`. `[]` est la liste vide. Les nombres peuvent être négatifs. Une valeur unique passée à un paramètre de liste est lue comme une liste d'un seul élément : ainsi `userTier(8)` est équivalent à `userTier(thresholds=[8])` et `totalCount(event="request_duo_chat_response")` est équivalent à `totalCount(event=["request_duo_chat_response"])`.

Les crochets sont réservés aux paramètres de champ uniquement. Les listes de filtre dans `query` utilisent toujours des parenthèses, par exemple `status in (paused, failed)`.

#### Granularité {#granularity}

Chaque dimension de date accepte un paramètre `granularity`. Les valeurs acceptées sont `daily`, `weekly`, `monthly`, ou un nombre fixe de jours de `1d` à `399d`, par exemple `created(30d)`. Vous pouvez écrire le nombre de jours sans guillemets (`created(30d)`), entre guillemets (`created("30d")`), ou par nom (`created(granularity=30d)`).

Les intervalles à nombre de jours fixe sont comptés à partir de l'époque Unix (1er janvier 1970), sauf si vous les ancrez avec `origin`, ils s'alignent donc rarement avec votre filtre de date par défaut.

Chaque page de source de données répertorie la granularité par défaut par dimension.

#### Origine {#origin}

`origin` est un second paramètre optionnel disponible sur chaque dimension de date. Il définit le point de départ à partir duquel les intervalles à nombre de jours fixe sont comptés.

La valeur est une date ou une date-heure ISO 8601. Écrivez une date sans guillemets, comme les dates de filtre (`origin=2026-07-16`). Une date-heure doit être mise entre guillemets (`origin="2026-07-16T00:00:00Z"`). Un décalage de fuseau horaire est converti en UTC. Les secondes fractionnaires ne sont pas acceptées. Les étiquettes d'intervalle utilisent des dates calendaires et n'affichent pas les limites horaires de la journée ; ainsi, un `origin` avec une heure du jour étiquette chaque intervalle selon la date UTC à laquelle il commence.

`origin` n'est valide qu'avec une granularité à nombre de jours fixe. `created(granularity=weekly, origin=...)` et `created(origin=...)` seul, qui utilise la valeur par défaut du calendrier, renvoient tous deux une erreur.

Les valeurs relatives telles que `-60d` ou `today()` ne sont pas acceptées. La prise en charge est proposée dans le [ticket 230](https://gitlab.com/gitlab-org/glql/-/work_items/230).

Par exemple, cette requête compare les merge requests fusionnées sur deux périodes consécutives de 30 jours :

````yaml
```glql
title: "Merge requests merged per 30-day period"
display: table
mode: analytics
query: type = MergeRequest and group = "gitlab-org" and merged >= 2026-07-16 and merged < 2026-09-14
dimensions: merged(granularity=30d, origin=2026-07-16) as "Period"
metrics: totalCount as "Merge requests"
sort: merged asc
```
````

`origin` aligne les intervalles de 30 jours sur le début de la période sélectionnée, de sorte que la requête renvoie une ligne par période. Les intervalles vides sont omis.

### Alias personnalisés {#custom-aliases}

{{< history >}}

- Les champs paramétrés dupliqués avec des alias uniques ont été [introduits](https://gitlab.com/gitlab-org/glql/-/issues/153) dans GitLab 19.3.

{{< /history >}}

Utilisez le mot-clé `as` pour renommer les colonnes de dimension ou de métrique :

```plaintext
dimensions: language as "Language", ideName as "IDE"
metrics: totalCount as "Total", acceptanceRate as "Acceptance Rate"
```

Vous pouvez inclure le même [champ paramétré](#field-parameters) plusieurs fois avec des paramètres différents :

```plaintext
metrics: durationQuantile(0.5) as "Median", durationQuantile(0.95) as "p95"
```

Lorsque vous dupliquez un champ :

- Chaque champ dupliqué doit avoir un alias unique.
- Les alias doivent être uniques pour toutes les dimensions et métriques.
- Les champs qui n'acceptent aucun paramètre ne peuvent pas être dupliqués.
- Les champs dupliqués doivent être triés par leur alias. Par exemple, `sort: Median desc`.
- Les alias utilisés dans `sort` doivent être un seul mot.

### Tri {#sorting}

Triez selon n'importe quel champ qui apparaît dans vos dimensions ou métriques sélectionnées. Vous ne pouvez pas trier selon un champ qui ne figure pas dans vos dimensions ou métriques sélectionnées. Pour les champs avec un [alias personnalisé](#custom-aliases), vous pouvez trier selon l'alias ou le nom de champ d'origine. Si le même champ est dupliqué avec des paramètres différents, vous devez trier selon l'alias.

```plaintext
sort: acceptanceRate desc
```

Plusieurs champs de tri sont pris en charge :

```plaintext
sort: totalCount desc, acceptanceRate asc
```

### Exemple {#example}

La requête suivante renvoie le taux d'acceptation des suggestions de code par langage pour les 30 derniers jours, triés par taux d'acceptation :

````yaml
```glql
display: table
mode: analytics
query: type = CodeSuggestion and timestamp >= -30d
dimensions: language as "Language"
metrics: totalCount as "Total", acceptanceRate as "Acceptance Rate"
sort: acceptanceRate desc
```
````

Pour plus d'informations, consultez les exemples pour une [source de données](data_sources/_index.md) spécifique.

## Intégration avec la recherche avancée {#advanced-search-integration}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/210854) dans GitLab 18.6 en tant que [version bêta](../../policy/development_stages_support.md#beta) avec des [feature flags](../../administration/feature_flags/_index.md) nommés `glql_work_items` et `glql_es_integration`. Activés par défaut.
- Le feature flag `glql_work_items` a été supprimé dans GitLab 18.10.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique.

GLQL utilise la recherche avancée lorsqu'elle est disponible pour accélérer les requêtes. La recherche avancée offre des temps de réponse plus rapides pour les requêtes complexes sur de grands ensembles de données.

La recherche avancée est :

- Activée par défaut pour les abonnements payants GitLab.com et GitLab Dedicated.
- Disponible pour GitLab Self-Managed lorsqu'un administrateur [active la recherche avancée](../../integration/advanced_search/elasticsearch.md#enable-advanced-search).

Si la recherche avancée n'est pas disponible, GLQL utilise PostgreSQL à la place.
