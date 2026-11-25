---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Charts Helm dans le registre de paquets
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Publiez des paquets Helm dans le registre de paquets de votre projet. Installez ensuite les paquets chaque fois que vous en avez besoin en tant que dépendance.

Pour la documentation des endpoints d'API spécifiques utilisés par les clients du gestionnaire de paquets Helm, consultez la [documentation de l'API Helm](../../../api/packages/helm.md).

## Créer un paquet Helm {#build-a-helm-package}

Pour en savoir plus, consultez la documentation Helm sur les sujets suivants :

- [Créer vos propres charts Helm](https://helm.sh/docs/intro/using_helm/#creating-your-own-charts)
- [Packager un chart Helm en archive de chart](https://helm.sh/docs/helm/helm_package/#helm-package)

## S'authentifier au dépôt Helm {#authenticate-to-the-helm-repository}

Pour vous authentifier au dépôt Helm, vous avez besoin de l'un des éléments suivants :

- Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) avec la portée définie sur `api`.
- Un [jeton de déploiement](../../project/deploy_tokens/_index.md) avec la portée définie sur `read_package_registry`, `write_package_registry`, ou les deux.
- Un [jeton de job CI/CD](../../../ci/jobs/ci_job_token.md).

## Publier un paquet {#publish-a-package}

> [!note]
> Vous pouvez publier des charts Helm avec des noms ou des versions en double. En cas de doublons, GitLab renvoie toujours le chart avec la version la plus récente.

Une fois créé, un chart peut être envoyé vers le canal souhaité avec `curl` ou `helm cm-push` :

- Avec `curl` :

  ```shell
  curl --fail-with-body --request POST \
       --form 'chart=@mychart-0.1.0.tgz' \
       --user <username>:<access_token> \
       https://gitlab.example.com/api/v4/projects/<project_id>/packages/helm/api/<channel>/charts
  ```

  - `<username>` : le nom d'utilisateur GitLab ou le nom d'utilisateur du jeton de déploiement.
  - `<access_token>` : le jeton d'accès personnel ou le jeton de déploiement.
  - `<project_id>` : l'ID du projet (comme `42`) ou le chemin [encodé en URL](../../../api/rest/_index.md#namespaced-paths) du projet (comme `group%2Fproject`).
  - `<channel>` : le nom du canal (comme `stable`).
- Avec le plugin [`helm cm-push`](https://github.com/chartmuseum/helm-push/#readme) :

  ```shell
  helm repo add --username <username> --password <access_token> project-1 https://gitlab.example.com/api/v4/projects/<project_id>/packages/helm/<channel>
  helm cm-push mychart-0.1.0.tgz project-1
  ```

  - `<username>` : le nom d'utilisateur GitLab ou le nom d'utilisateur du jeton de déploiement.
  - `<access_token>` : le jeton d'accès personnel ou le jeton de déploiement.
  - `<project_id>` : l'ID du projet (comme `42`).
  - `<channel>` : le nom du canal (comme `stable`).

### Canaux de release {#release-channels}

Vous pouvez publier des charts Helm vers des canaux dans GitLab. Les canaux sont une méthode permettant de différencier les dépôts de charts Helm. Par exemple, vous pouvez utiliser `stable` et `devel` comme canaux pour permettre aux utilisateurs d'ajouter le dépôt `stable` tandis que les charts `devel` sont isolés.

## Utiliser CI/CD pour publier un paquet Helm {#use-cicd-to-publish-a-helm-package}

Pour publier un paquet Helm de manière automatisée via [GitLab CI/CD](../../../ci/_index.md), vous pouvez utiliser `CI_JOB_TOKEN` à la place du jeton d'accès personnel dans vos commandes.

Par exemple :

```yaml
stages:
  - upload

upload:
  image: curlimages/curl:latest
  stage: upload
  script:
    - 'curl --fail-with-body --request POST --user gitlab-ci-token:$CI_JOB_TOKEN --form "chart=@mychart-0.1.0.tgz" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/helm/api/<channel>/charts"'
```

- `<username>` : le nom d'utilisateur GitLab ou le nom d'utilisateur du jeton de déploiement.
- `<access_token>` : le jeton d'accès personnel ou le jeton de déploiement.
- `<channel>` : le nom du canal (comme `stable`).

## Installer un paquet {#install-a-package}

> [!note]
> Pour chaque paquet, seul le fichier de paquet le plus récent est renvoyé.

Pour installer la dernière version d'un chart, utilisez la commande suivante :

```shell
helm repo add --username <username> --password <access_token> project-1 https://gitlab.example.com/api/v4/projects/<project_id>/packages/helm/<channel>
helm install my-release project-1/mychart
```

- `<username>` : le nom d'utilisateur GitLab ou le nom d'utilisateur du jeton de déploiement.
- `<access_token>` : le jeton d'accès personnel ou le jeton de déploiement.
- `<project_id>` : l'ID du projet (comme `42`).
- `<channel>` : le nom du canal (comme `stable`).

Si le dépôt a déjà été ajouté, vous devrez peut-être exécuter :

```shell
helm repo update
```

Pour mettre à jour le client Helm avec les charts les plus récents disponibles.

Consultez [Using Helm](https://helm.sh/docs/intro/using_helm/) pour plus d'informations.

## Supprimer un paquet Helm {#delete-a-helm-package}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire.

Avant de supprimer un paquet, assurez-vous de bien comprendre les [risques de sécurité associés](../package_registry/supported_functionality.md#deleting-packages).

Pour supprimer un paquet, vous pouvez :

- [Utiliser l'interface utilisateur](../package_registry/reduce_package_registry_storage.md#delete-a-package).
- [Utiliser l'API](../../../api/packages.md#delete-a-project-package).

## Dépannage {#troubleshooting}

### Le chart n'est pas visible dans le registre de paquets après l'envoi {#the-chart-is-not-visible-in-the-package-registry-after-uploading}

Vérifiez le [journal Sidekiq](../../../administration/logs/_index.md#sidekiqlog) pour détecter toute erreur connexe. Si vous voyez `Validation failed: Version is invalid`, cela signifie que la version dans votre fichier `Chart.yaml` ne respecte pas les [spécifications de versionnement des charts Helm](https://helm.sh/docs/topics/charts/#charts-and-versioning). Pour corriger l'erreur, utilisez la syntaxe de version correcte et envoyez à nouveau le chart.

### `helm push` génère une erreur {#helm-push-results-in-an-error}

Helm 3.7 a introduit un changement majeur pour le plugin `helm-push`. Vous pouvez mettre à jour le [plugin Chart Museum](https://github.com/chartmuseum/helm-push/#readme) pour utiliser `helm cm-push`.
