---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Outil CLI de release GitLab (déprécié)
---

<!--- start_remove The following content will be removed on remove_date: '2027-08-18' -->

> [!warning]
> Cette fonctionnalité a été [dépréciée](https://gitlab.com/gitlab-org/cli/-/issues/7859) dans GitLab 18.0 et est prévue pour suppression dans la version 20.0. Utilisez plutôt le [CLI GitLab](../../../editor_extensions/gitlab_cli/_index.md).
>
> Ce changement est un changement de rupture.

## Migrer de `release-cli` vers `glab` CLI {#migrate-from-release-cli-to-glab-cli}

Pour migrer de `release-cli` vers `glab` CLI, mettez à jour l'un des éléments suivants en fonction de la configuration de votre job :

1. Si votre job utilise le mot-clé `release`, mettez à jour la configuration pour utiliser l'image `cli:latest` :

   ```yaml
   release_job:
     stage: release
     image: registry.gitlab.com/gitlab-org/cli:latest
     rules:
       - if: $CI_COMMIT_TAG
     script:
       - echo "Running the release job."
     release:
       tag_name: $CI_COMMIT_TAG
       name: 'Release $CI_COMMIT_TAG'
       description: 'Release created using the CLI.'
   ```

   Pour plus d'informations, consultez [`release`](../../../ci/yaml/_index.md#release).

1. Si votre job utilise des commandes `release-cli` dans des blocs `script`, mettez à jour la configuration pour utiliser `glab release create` et configurez l'authentification pour l'[API Releases](../../../api/releases/_index.md).

### S'authentifier avec le jeton de job CI/CD {#authenticate-with-the-cicd-job-token}

Pour vous authentifier avec [`CI_JOB_TOKEN`](../../../ci/jobs/ci_job_token.md), définissez `GLAB_ENABLE_CI_AUTOLOGIN` sur `true`. Le CLI `glab` envoie `CI_JOB_TOKEN` dans l'en-tête `JOB-TOKEN`, que l'API Releases accepte.

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  rules:
    - if: $CI_COMMIT_TAG
  variables:
    GLAB_ENABLE_CI_AUTOLOGIN: "true"
  script:
    - |
      glab release create "$CI_COMMIT_TAG" \
      --name "Release $CI_COMMIT_TAG" \
      --notes "Release created with glab."
```

### S'authentifier avec un jeton d'accès {#authenticate-with-an-access-token}

Pour vous authentifier avec un jeton d'accès [personnel](../../profile/personal_access_tokens.md), [de projet](../settings/project_access_tokens.md) ou [de groupe](../../group/settings/group_access_tokens.md), définissez `GITLAB_TOKEN` sur votre jeton d'accès. Le jeton doit avoir la portée `api`.

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  rules:
    - if: $CI_COMMIT_TAG
  variables:
    GITLAB_TOKEN: $RELEASE_ACCESS_TOKEN
  script:
    - |
      glab release create "$CI_COMMIT_TAG" \
      --name "Release $CI_COMMIT_TAG" \
      --notes "Release created with glab."
```

> [!warning]
> Ne définissez pas `GITLAB_TOKEN` sur `$CI_JOB_TOKEN`. Le CLI `glab` envoie `GITLAB_TOKEN` dans l'en-tête `PRIVATE-TOKEN`, mais l'API Releases n'accepte un jeton de job que dans l'en-tête `JOB-TOKEN`. Cette combinaison renvoie `404 Not Found`. Pour vous authentifier avec le jeton de job CI/CD, définissez plutôt `GLAB_ENABLE_CI_AUTOLOGIN` sur `true`.

Pour obtenir la liste complète des options, consultez la référence de la commande [`glab release create`](https://docs.gitlab.com/cli/release/create/).

## Revenir à `release-cli` {#fall-back-to-release-cli}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/524346) dans GitLab 18.0, [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `ci_glab_for_release`. Activés par défaut.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/537398) dans GitLab 18.4. Le feature flag `ci_glab_for_release` a été supprimé.

{{< /history >}}

Les jobs CI/CD qui utilisent le mot-clé `release` font appel à un script qui revient à l'utilisation de `release-cli` si la version requise de `glab` n'est pas disponible sur le runner. La logique de secours est une protection visant à garantir que les projets n'ayant pas encore migré vers le CLI `glab` peuvent continuer à fonctionner.

Ce mécanisme de secours est [prévu pour être supprimé](https://gitlab.com/gitlab-org/gitlab/-/issues/537919) dans GitLab 20.0 avec la suppression de `release-cli`.

<!--- end_remove -->
