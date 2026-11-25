---
stage: Analytics
group: Platform Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Sources de données GLQL
---

GLQL peut interroger les sources de données suivantes :

| Source de données | Mode standard | [Mode Analytics](../_index.md#analytics-mode) | Valeurs `type` | Description |
|---|---|---|---|---|
| Éléments de travail | {{< yes >}} | {{< no >}} | `Issue`, `Incident`, `TestCase`, `Requirement`, `Task`, `Ticket`, `Objective`, `KeyResult`, `Epic` | Tickets, epics et autres types d'éléments de travail. Valeur par défaut lorsque `type` est omis. |
| Les merge requests | {{< yes >}} | {{< yes >}} | `MergeRequest` | Revue de code et workflow de fusion. |
| Pipelines | {{< yes >}} | {{< yes >}} | `Pipeline` | Pipelines CI/CD. |
| Jobs | {{< yes >}} | {{< no >}} | `Job` | Jobs CI/CD au sein des pipelines. |
| Projets | {{< yes >}} | {{< no >}} | `Project` | Projets au sein d'un espace de nommage. |
| Sessions de la plateforme d'agents | {{< no >}} | {{< yes >}} | `AgentPlatformSession` | Analyses agrégées des sessions de la plateforme GitLab Duo Agent. |
| Événements d'utilisation de l'IA | {{< no >}} | {{< yes >}} | `AiUsageEvent` | Analyses agrégées des événements d'utilisation de GitLab Duo. |
| Suggestions de code | {{< no >}} | {{< yes >}} | `CodeSuggestion` | Analyses agrégées de GitLab Duo Code Suggestions. |
| Contributions | {{< no >}} | {{< yes >}} | `Contribution` | Analyses agrégées de l'activité de contribution. |
| Workflows Duo | {{< no >}} | {{< yes >}} | `DuoWorkflow` | Analyses agrégées des flows de la plateforme GitLab Duo Agent, y compris les crédits utilisés. |

Chaque source de données possède son propre ensemble de champs pris en charge pour le filtrage, l'affichage et le tri.

Spécifiez la source de données dans votre requête en utilisant le champ `type`. Par exemple, `type = Issue` ou `type = MergeRequest`. Pour les sources de données qui prennent en charge plusieurs types, utilisez l'opérateur `in` pour interroger tous les types. Par exemple, `type in (Issue, Task)`.

## Portées {#scopes}

Chaque source de données nécessite une portée pour définir l'emplacement à partir duquel les données sont interrogées. Les portées autorisées varient selon la source de données et sont documentées sur la page de chaque source de données.

Définissez la portée dans votre requête. Par exemple :

```yaml
query: type = issue and project = "gitlab-org/gitlab"
```

Si vous ne spécifiez pas de portée, GLQL la déduit de l'emplacement où la requête est intégrée :

- Dans un contexte de projet (comme la description d'un ticket ou d'une merge request), GLQL utilise le projet actuel.
- Dans un contexte de groupe (comme la description d'un epic), GLQL utilise le groupe actuel.

### Plusieurs groupes et projets {#multiple-groups-and-projects}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/628101) dans GitLab 19.5.

{{< /history >}}

En [mode Analytics](../_index.md#analytics-mode), les filtres `group` et `project` acceptent une liste, ce qui permet à une seule requête d'agréger des données sur plusieurs groupes ou projets. Utilisez l'opérateur `in` avec des chemins complets :

````yaml
```glql
display: table
mode: analytics
query: type = MergeRequest and group in ("gitlab-org", "gitlab-com") and merged > -30d
dimensions: merged(weekly) as "Week"
metrics: totalCount as "Total", throughputCount as "Merged"
sort: merged desc
```
````

Vous pouvez lister des groupes, des projets, ou les deux :

- `group in ("gitlab-org", "gitlab-com")` agrège tous les projets des groupes listés, y compris les sous-groupes.
- `project in ("gitlab-org/gitlab", "gitlab-org/gitaly")` agrège uniquement les projets listés.
- `group in ("gitlab-org") and project in ("gitlab-com/www-gitlab-com")` agrège l'union des deux listes.
- `group = "gitlab-org" and project in ("gitlab-org/gitlab", "gitlab-org/gitaly")` agrège uniquement les projets listés, qui doivent appartenir au groupe.

Par exemple, pour comparer des projets de différents groupes côte à côte :

````yaml
```glql
display: table
mode: analytics
query: type = Pipeline and project in ("gitlab-org/gitlab", "gitlab-org/gitaly", "gitlab-com/www-gitlab-com") and finished > -30d
dimensions: project as "Project"
metrics: totalCount as "Total", successRate as "Success rate"
sort: totalCount desc
```
````

Lorsque vous utilisez une liste :

- Vous pouvez lister au maximum 20 groupes et projets combinés.
- Vous devez avoir accès à chaque groupe et projet listé. Si l'un d'entre eux est manquant ou inaccessible, la requête échoue avec une erreur qui indique les chemins qui ne peuvent pas être lus.
- Une liste avec un seul chemin se comporte comme `group = "..."` ou `project = "..."`.
- Lorsque vous intégrez la requête dans un projet ou un groupe, GLQL utilise les chemins listés comme portée au lieu de ce projet ou de ce groupe.

Les listes ne sont pas prises en charge en mode standard. Les sources de données telles que les éléments de travail et les jobs acceptent une seule valeur `group` ou `project`, et une liste entraîne une erreur de compilation.
