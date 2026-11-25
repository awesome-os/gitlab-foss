---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Exemples de release CI/CD
---

La fonctionnalité de release de GitLab est flexible et peut être configurée pour correspondre à votre workflow. Cette page présente des exemples de jobs de release CI/CD. Chaque exemple illustre une méthode de création d'une release dans un pipeline CI/CD.

## Créer une release lors de la création d'un tag Git {#create-a-release-when-a-git-tag-is-created}

Dans cet exemple CI/CD, la release est déclenchée par l'un des événements suivants :

- Envoi d'un tag Git vers le dépôt.
- Création d'un tag Git dans l'interface utilisateur.

Vous pouvez utiliser cette méthode si vous préférez créer le tag Git manuellement et créer une release en conséquence.

> [!note]
> Ne fournissez pas de notes de release lorsque vous créez le tag Git dans l'interface utilisateur. La fourniture de notes de release crée une release, ce qui entraîne l'échec du pipeline.

Points clés dans l'extrait suivant d'un exemple de fichier `.gitlab-ci.yml` :

- Le bloc `rules` définit quand le job est ajouté au pipeline.
- Le tag Git est utilisé dans le nom et la description de la release.

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  rules:
    - if: $CI_COMMIT_TAG                 # Run this job when a tag is created
  script:
    - echo "running release_job"
  release:                               # See https://docs.gitlab.com/ci/yaml/#release for available properties
    tag_name: '$CI_COMMIT_TAG'
    description: '$CI_COMMIT_TAG'
```

## Créer une release lors de la fusion d'un commit sur la branche par défaut {#create-a-release-when-a-commit-is-merged-to-the-default-branch}

Dans cet exemple CI/CD, la release est déclenchée lorsque vous fusionnez un commit sur la branche par défaut. Vous pouvez utiliser cette méthode si votre workflow de release ne crée pas de tag manuellement.

Points clés dans l'extrait suivant d'un exemple de fichier `.gitlab-ci.yml` :

- Le tag Git, la description et la référence sont créés automatiquement dans le pipeline.
- Si vous créez un tag manuellement, le job `release_job` ne s'exécute pas.

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  rules:
    - if: $CI_COMMIT_TAG
      when: never                                  # Do not run this job when a tag is created manually
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH  # Run this job when commits are pushed or merged to the default branch
  script:
    - echo "running release_job for $TAG"
  release:                                         # See https://docs.gitlab.com/ci/yaml/#release for available properties
    tag_name: 'v0.$CI_PIPELINE_IID'                # The version is incremented per pipeline.
    description: 'v0.$CI_PIPELINE_IID'
    ref: '$CI_COMMIT_SHA'                          # The tag is created from the pipeline SHA.
```

> [!note]
> Les variables d'environnement définies dans `before_script` ou `script` ne sont pas disponibles pour l'expansion dans le même job. En savoir plus sur la [possibilité de rendre les variables disponibles pour l'expansion](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/6400).

## Créer des métadonnées de release dans un script personnalisé {#create-release-metadata-in-a-custom-script}

Dans cet exemple CI/CD, la préparation de la release est divisée en jobs distincts pour plus de flexibilité :

- Le job `prepare_job` génère les métadonnées de la release. N'importe quelle image peut être utilisée pour exécuter le job, y compris une image personnalisée. Les métadonnées générées sont stockées dans le fichier de variables `variables.env`. Ces métadonnées sont [transmises au job en aval](../../../ci/variables/dotenv_variables.md#pass-variables-to-later-jobs).
- Le `release_job` utilise le contenu du fichier de variables pour créer une release, en utilisant les métadonnées qui lui sont transmises dans le fichier de variables. Ce job doit utiliser l'image `registry.gitlab.com/gitlab-org/cli:latest` car elle contient le CLI `glab`.

```yaml
prepare_job:
  stage: prepare                                              # This stage must run before the release stage
  rules:
    - if: $CI_COMMIT_TAG
      when: never                                             # Do not run this job when a tag is created manually
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH             # Run this job when commits are pushed or merged to the default branch
  script:
    - echo "EXTRA_DESCRIPTION=some message" >> variables.env  # Generate the EXTRA_DESCRIPTION and TAG environment variables
    - echo "TAG=v$(cat VERSION)" >> variables.env             # and append to the variables.env file
  artifacts:
    reports:
      dotenv: variables.env                                   # Use artifacts:reports:dotenv to expose the variables to other jobs

release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  needs:
    - job: prepare_job
      artifacts: true
  rules:
    - if: $CI_COMMIT_TAG
      when: never                                  # Do not run this job when a tag is created manually
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH  # Run this job when commits are pushed or merged to the default branch
  script:
    - echo "running release_job for $TAG"
  release:
    name: 'Release $TAG'
    description: 'Created using the CLI $EXTRA_DESCRIPTION'  # $EXTRA_DESCRIPTION and the $TAG
    tag_name: '$TAG'                                                 # variables must be defined elsewhere
    ref: '$CI_COMMIT_SHA'                                            # in the pipeline. For example, in the
    milestones:                                                      # prepare_job
      - 'm1'
      - 'm2'
      - 'm3'
    released_at: '2020-07-15T08:00:00Z'  # Optional, is auto generated if not defined, or can use a variable.
    assets:
      links:
        - name: 'asset1'
          url: 'https://example.com/assets/1'
        - name: 'asset2'
          url: 'https://example.com/assets/2'
          filepath: '/pretty/url/1' # optional
          link_type: 'other' # optional
```

## Ignorer plusieurs pipelines lors de la création d'une release {#skip-multiple-pipelines-when-creating-a-release}

La création d'une release à l'aide d'un job CI/CD peut potentiellement déclencher plusieurs pipelines si le tag associé n'existe pas encore. Pour comprendre comment cela peut se produire, examinez les workflows suivants :

- Tag en premier, release en second :
  1. Un tag est créé depuis l'interface utilisateur ou envoyé.
  1. Un pipeline de tag est déclenché et exécute le job `release`.
  1. Une release est créée.
- Release en premier, tag en second :
  1. Un pipeline est déclenché lorsque des commits sont poussés ou fusionnés sur la branche par défaut. Le pipeline exécute le job `release`.
  1. Une release est créée.
  1. Un tag est créé.
  1. Un pipeline de tag est déclenché. Le pipeline exécute également le job `release`.

Dans le second workflow, le job `release` s'exécute dans plusieurs pipelines. Pour éviter cela, vous pouvez utiliser le [mot-clé `workflow:rules`](../../../ci/yaml/_index.md#workflowrules) pour déterminer si un job de release doit s'exécuter dans un pipeline de tag :

```yaml
release_job:
  rules:
    - if: $CI_COMMIT_TAG
      when: never                                  # Do not run this job in a tag pipeline
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH  # Run this job when commits are pushed or merged to the default branch
  script:
    - echo "Create release"
  release:
    name: 'My awesome release'
    tag_name: '$CI_COMMIT_TAG'
```
