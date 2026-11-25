---
stage: Software Supply Chain Security
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Preuve de release
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Chaque fois qu'une release est créée, GitLab prend un instantané des données qui lui sont associées. Ces données sont enregistrées dans un fichier JSON et appelées *preuve de release*. La fonctionnalité inclut des artefacts de test, des jalons liés et des paquets correspondants pour faciliter les processus internes, tels que les audits externes.

Pour accéder à la preuve de release, sur la page Releases, sélectionnez le lien vers le fichier JSON répertorié sous l'en-tête **Collecte de preuves**.

Vous pouvez également [utiliser l'API](../../../api/releases/_index.md#collect-release-evidence) pour générer une preuve de release pour une release existante. De ce fait, chaque release peut avoir plusieurs instantanés de preuve de release. Vous pouvez consulter la preuve de release et ses détails sur la page Releases.

Lorsque le système de suivi des tickets est désactivé, la preuve de release [ne peut pas être téléchargée](https://gitlab.com/gitlab-org/gitlab/-/issues/208397).

Voici un exemple d'objet de preuve de release :

```json
{
  "release": {
    "id": 5,
    "tag_name": "v4.0",
    "name": "New release",
    "project": {
      "id": 20,
      "name": "Project name",
      "created_at": "2019-04-14T11:12:13.940Z",
      "description": "Project description"
    },
    "created_at": "2019-06-28 13:23:40 UTC",
    "description": "Release description",
    "milestones": [
      {
        "id": 11,
        "title": "v4.0-rc1",
        "state": "closed",
        "due_date": "2019-05-12 12:00:00 UTC",
        "created_at": "2019-04-17 15:45:12 UTC",
        "description": "milestone description",
      },
      {
        "id": 12,
        "title": "v4.0-rc2",
        "state": "closed",
        "due_date": "2019-05-30 18:30:00 UTC",
        "created_at": "2019-04-17 15:45:12 UTC",
        "description": "milestone description",
      }
    ],
    "packages": [
      {
        "id": 1,
        "name": "my-package",
        "version": "4.0",
        "package_type": "generic",
        "created_at": "2019-06-20 10:00:00 UTC"
      }
    ],
    "report_artifacts": [
      {
        "url":"https://gitlab.example.com/root/project-name/-/jobs/111/artifacts/download"
      }
    ]
  }
}
```

## Inclure des paquets comme preuves de release {#include-packages-as-release-evidence}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/283995) dans GitLab 18.11.

{{< /history >}}

Lors de la création d'une release, GitLab interroge automatiquement le [registre de paquets](../../packages/package_registry/_index.md) du projet pour rechercher les paquets dont la version correspond au tag de la release. Les paquets correspondants sont inclus dans le JSON de preuve de release sous la clé `packages`.

La correspondance de version fonctionne comme suit :

- Si le tag de release possède un préfixe `v` ou `V` (par exemple, `v1.0.0`), le préfixe est supprimé avant la mise en correspondance. Un tag `v1.0.0` correspond aux paquets dont la version est `1.0.0`.
- Si le tag de release n'a pas de préfixe (par exemple, `1.0.0`), il est mis en correspondance directement.
- Seuls les [paquets affichables](../../packages/package_registry/_index.md) sont inclus. Les paquets en attente de suppression ou dans un état d'erreur sont exclus.
- Plusieurs paquets peuvent correspondre à une seule release. Par exemple, si un projet publie à la fois un paquet générique et un paquet npm avec la version `1.0.0`, les deux sont inclus dans la preuve.

Chaque entrée de paquet dans la preuve contient les champs suivants :

| Champ          | Description                                                    |
|----------------|----------------------------------------------------------------|
| `id`           | L'identifiant unique du paquet.                                  |
| `name`         | Le nom du paquet.                                       |
| `version`      | La chaîne de version du paquet.                             |
| `package_type` | Le type du paquet (par exemple, `generic`, `npm`, `maven`). |
| `created_at`   | L'horodatage de la création du paquet.                    |

Aucune configuration supplémentaire n'est requise. Tant que des paquets existent dans le registre de paquets du projet avec une version correspondant au tag de la release, ils sont automatiquement inclus lors de la collecte de la preuve.

## Collecter la preuve de release {#collect-release-evidence}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lors de la création d'une release, la preuve de release est automatiquement collectée. Pour initier la collecte de preuves à tout autre moment, utilisez un [appel API](../../../api/releases/_index.md#collect-release-evidence). Vous pouvez collecter la preuve de release plusieurs fois pour une même release.

Les instantanés de collecte de preuves sont visibles sur la page Releases, ainsi que l'horodatage de la collecte de la preuve.

## Inclure des artefacts de rapport comme preuves de release {#include-report-artifacts-as-release-evidence}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous créez une release, si des [artefacts de job](../../../ci/yaml/_index.md#artifactsreports) sont inclus dans le dernier pipeline exécuté, ils sont automatiquement inclus dans la release en tant que preuves de release.

Bien que les artefacts de job expirent généralement, les artefacts inclus dans la preuve de release n'expirent pas.

Pour activer la collecte d'artefacts de job, vous devez spécifier les deux éléments suivants :

1. [`artifacts:paths`](../../../ci/yaml/_index.md#artifactspaths)
1. [`artifacts:reports`](../../../ci/yaml/_index.md#artifactsreports)

```yaml
ruby:
  script:
    - gem install bundler
    - bundle install
    - bundle exec rspec --format progress --format RspecJunitFormatter --out rspec.xml
  artifacts:
    paths:
      - rspec.xml
    reports:
      junit: rspec.xml
```

Si le pipeline s'est exécuté avec succès, lors de la création de votre release, le fichier `rspec.xml` est enregistré comme preuve de release.

Si vous [planifiez la collecte de preuves de release](#schedule-release-evidence-collection), certains artefacts peuvent déjà avoir expiré au moment de la collecte de preuves. Pour éviter cela, vous pouvez utiliser le mot-clé [`artifacts:expire_in`](../../../ci/yaml/_index.md#artifactsexpire_in). Pour plus d'informations, consultez le [ticket 222351](https://gitlab.com/gitlab-org/gitlab/-/issues/222351).

## Planifier la collecte de preuves de release {#schedule-release-evidence-collection}

Dans l'API :

- Si vous spécifiez une date `released_at` future, la release devient une **Upcoming release** et la preuve est collectée à la date de la release. Vous ne pouvez pas collecter la preuve de release avant cette date.
- Si vous spécifiez une date `released_at` passée, la release devient une **Release antérieure** et aucune preuve n'est collectée.
- Si vous ne spécifiez pas de date `released_at`, la preuve de release est collectée à la date de création de la release.
