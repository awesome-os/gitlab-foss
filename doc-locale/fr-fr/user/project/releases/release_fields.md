---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Champs de release
---

Les champs suivants sont disponibles lorsque vous créez ou modifiez une release.

## Titre {#title}

Le titre de la release peut être personnalisé à l'aide du champ **Titre de la release** lors de la création ou de la modification d'une release. Si aucun titre n'est fourni, le nom du tag de la release est utilisé à la place.

## Nom du tag {#tag-name}

Le nom du tag de la release doit inclure la version de la release. GitLab utilise la [gestion sémantique de version](https://semver.org/) pour les releases, et vous pouvez l'utiliser également. Utilisez `(Major).(Minor).(Patch)`, comme indiqué dans la [politique de versionnage de GitLab](../../../policy/maintenance.md#versioning).

Par exemple, pour la version GitLab `16.10.1` :

- `16` représente la version majeure. La release majeure était `16.0.0`, mais souvent désignée par `16.0`.
- `10` représente la version mineure. La release mineure était `16.10.0`, mais souvent désignée par `16.10`.
- `1` représente le numéro de patch.

N'importe quelle partie du numéro de version peut comporter plusieurs chiffres, par exemple `16.10.11`.

## Description des notes de release {#release-notes-description}

Chaque release possède une description. Vous pouvez ajouter le texte de votre choix, mais envisagez d'inclure un journal des modifications pour décrire le contenu de votre release. Cela aide les utilisateurs à identifier rapidement les différences entre chaque release que vous publiez.

Les [messages de tag dans Git](https://git-scm.com/book/en/v2/Git-Basics-Tagging) peuvent être inclus dans les descriptions des notes de release en sélectionnant **Inclure le message du tag dans les notes de release**.

La description prend en charge le [Markdown](../../markdown.md).

## Ressources associées à une release {#release-assets}

Une release contient les types de ressources associées suivants :

- [Code source](#source-code)
- [Lien vers les documents associés](#links)

### Code source {#source-code}

GitLab génère automatiquement le code source archivé `zip`, `tar.gz`, `tar.bz2` et `tar` à partir du tag Git fourni. Ces ressources associées sont en lecture seule et [peuvent être téléchargées](../repository/_index.md#download-repository-source-code).

### Liens {#links}

Un lien est une URL qui peut pointer vers ce que vous souhaitez : de la documentation, des binaires compilés ou d'autres documents associés. Il peut s'agir de liens internes ou externes à votre instance GitLab. L'URL doit utiliser l'un des schémas suivants : `http`, `https` ou `ftp`. Chaque lien en tant que ressource associée possède les attributs suivants :

| Attribut   | Obligatoire | Description |
|-------------|----------|-------------|
| `name`      | Oui      | Le nom du lien. |
| `url`       | Oui      | L'URL pour télécharger un fichier. |
| `filepath`  | Non       | Le lien de redirection vers `url`. Doit commencer par une barre oblique (`/`). Consultez [cette section](#permanent-links-to-release-assets) pour plus d'informations. |
| `link_type` | Non       | Le type de contenu que les utilisateurs peuvent télécharger avec `url`. Consultez [cette section](#link-types) pour plus d'informations. |

#### Liens permanents vers les ressources associées à une release {#permanent-links-to-release-assets}

Les ressources associées à une release sont accessibles via une URL permanente. GitLab redirige toujours cette URL vers l'emplacement réel de la ressource associée, de sorte que même si les ressources associées sont déplacées vers un autre emplacement, vous pouvez continuer à utiliser la même URL. Cela est défini lors de la [création du lien](../../../api/releases/links.md#create-a-release-link) ou de sa [mise à jour](../../../api/releases/links.md#update-a-release-link) en utilisant l'attribut API `filepath`.

Le format de l'URL est :

```plaintext
https://host/namespace/project/-/releases/:release/downloads:filepath
```

Si vous disposez d'une ressource associée pour la release `v16.9.0-rc2` dans l'espace de nommage `gitlab-org` et le projet `gitlab-runner` sur `gitlab.com`, par exemple :

```json
{
  "name": "linux amd64",
  "filepath": "/binaries/gitlab-runner-linux-amd64",
  "url": "https://gitlab-runner-downloads.s3.amazonaws.com/v16.9.0-rc2/binaries/gitlab-runner-linux-amd64",
  "link_type": "other"
}
```

Cette ressource associée a un lien direct :

```plaintext
https://gitlab.com/gitlab-org/gitlab-runner/-/releases/v16.9.0-rc2/downloads/binaries/gitlab-runner-linux-amd64
```

L'emplacement physique de la ressource associée peut changer à tout moment, et le lien direct reste inchangé.

Si la release est privée, vous devez fournir un jeton d'accès personnel avec la portée `api` ou `read_api` en utilisant un paramètre de requête `private_token` ou un en-tête `HTTP_PRIVATE_TOKEN` lors de la requête. Par exemple :

```shell
curl --location --output filename "https://gitlab.example.com/my-group/my-project/-/releases/myrelease/downloads/<path-to-file>?private_token=<your_access_token>"
curl --location --output filename --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/my-group/my-project/-/releases/myrelease/downloads/<path-to-file>"
```

#### Liens permanents vers les ressources associées à la dernière release {#permanent-links-to-latest-release-assets}

Vous pouvez utiliser le `filepath` des [liens permanents vers les ressources associées à une release](#permanent-links-to-release-assets) en combinaison avec un [lien permanent vers la dernière release](_index.md#permanent-link-to-latest-release). Le `filepath` doit commencer par une barre oblique (`/`).

Le format de l'URL est :

```plaintext
https://host/namespace/project/-/releases/permalink/latest/downloads:filepath
```

Vous pouvez utiliser ce format pour fournir un lien permanent vers une ressource associée de la dernière release.

Si vous disposez d'une ressource associée avec [`filepath`](../../../api/releases/links.md#create-a-release-link) pour la dernière release `v16.9.0-rc2` dans l'espace de nommage `gitlab-org` et le projet `gitlab-runner` sur `gitlab.com`, par exemple :

```json
{
  "name": "linux amd64",
  "filepath": "/binaries/gitlab-runner-linux-amd64",
  "url": "https://gitlab-runner-downloads.s3.amazonaws.com/v16.9.0-rc2/binaries/gitlab-runner-linux-amd64",
  "link_type": "other"
}
```

Cette ressource associée a un lien direct :

```plaintext
https://gitlab.com/gitlab-org/gitlab-runner/-/releases/permalink/latest/downloads/binaries/gitlab-runner-linux-amd64
```

#### Types de lien {#link-types}

Les quatre types de lien sont « Runbook », « Package », « Image » et « Autre ». Le paramètre `link_type` accepte l'une des quatre valeurs suivantes :

- `runbook`
- `package`
- `image`
- `other` (par défaut)

Ce champ n'a aucun effet sur l'URL et n'est utilisé qu'à des fins visuelles dans la page Releases de votre projet.

#### Utiliser un package générique pour joindre des binaires {#use-a-generic-package-for-attaching-binaries}

Vous pouvez utiliser des [packages génériques](../../packages/generic_packages/_index.md) pour stocker des artefacts de job provenant d'une release ou d'un pipeline de tag, qui peuvent également être utilisés pour joindre des fichiers binaires à une entrée de release individuelle. Vous devez essentiellement :

1. [Envoyer les artefacts de job vers le registre de paquets générique](../../packages/generic_packages/_index.md#publish-a-package).
1. [Associer le lien du package à la release](#links).

L'exemple suivant génère des ressources associées à une release, les publie en tant que package générique, puis crée une release :

```yaml
stages:
  - build
  - upload
  - release

variables:
  # Package version can only contain numbers (0-9), and dots (.).
  # Must be in the format of X.Y.Z, and should match the /\A\d+\.\d+\.\d+\z/ regular expression.
  # See https://docs.gitlab.com/user/packages/generic_packages/#publish-a-package
  PACKAGE_VERSION: "1.2.3"
  DARWIN_AMD64_BINARY: "myawesomerelease-darwin-amd64-${PACKAGE_VERSION}"
  LINUX_AMD64_BINARY: "myawesomerelease-linux-amd64-${PACKAGE_VERSION}"
  PACKAGE_REGISTRY_URL: "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/myawesomerelease/${PACKAGE_VERSION}"

build:
  stage: build
  image: alpine:latest
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - mkdir bin
    - echo "Mock binary for ${DARWIN_AMD64_BINARY}" > bin/${DARWIN_AMD64_BINARY}
    - echo "Mock binary for ${LINUX_AMD64_BINARY}" > bin/${LINUX_AMD64_BINARY}
  artifacts:
    paths:
      - bin/

upload:
  stage: upload
  image: curlimages/curl:latest
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - |
      curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" --upload-file bin/${DARWIN_AMD64_BINARY} "${PACKAGE_REGISTRY_URL}/${DARWIN_AMD64_BINARY}"
    - |
      curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" --upload-file bin/${LINUX_AMD64_BINARY} "${PACKAGE_REGISTRY_URL}/${LINUX_AMD64_BINARY}"

release:
  # Caution, as of 2021-02-02 these assets links require a login, see:
  # https://gitlab.com/gitlab-org/gitlab/-/issues/299384
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - |
      glab release create "$CI_COMMIT_TAG" --name "Release $CI_COMMIT_TAG" \
        --assets-links="[{\"name\":\"${DARWIN_AMD64_BINARY}\",\"url\":\"${PACKAGE_REGISTRY_URL}/${DARWIN_AMD64_BINARY}\"},{\"name\":\"${LINUX_AMD64_BINARY}\",\"url\":\"${PACKAGE_REGISTRY_URL}/${LINUX_AMD64_BINARY}\"}]"
```

Les utilisateurs PowerShell peuvent avoir besoin d'échapper le guillemet double `"` dans une chaîne JSON avec un `` ` `` (accent grave) pour `--assets-link` et `ConvertTo-Json` avant de le transmettre à `release-cli`. Par exemple :

```yaml
release:
  script:
    - $env:assets = "[{`"name`":`"MyFooAsset`",`"url`":`"https://gitlab.com/upack/artifacts/download/$env:UPACK_GROUP/$env:UPACK_NAME/$($env:GitVersion_SemVer)?contentOnly=zip`"}]"
    - $env:assetsjson = $env:assets | ConvertTo-Json
    - glab release create $env:CI_COMMIT_TAG --name "Release $env:CI_COMMIT_TAG" --notes "Release $env:CI_COMMIT_TAG" --ref $env:CI_COMMIT_TAG --assets-links=$env:assetsjson
```

> [!note]
> Il n'est pas recommandé de joindre directement des liens vers des [artefacts de job](../../../ci/jobs/job_artifacts.md) à une release, car les artefacts sont éphémères et sont utilisés pour transmettre des données dans le même pipeline. Cela signifie qu'il existe un risque qu'ils expirent ou que quelqu'un les supprime manuellement.

### Nombre de nouvelles fonctionnalités et total des fonctionnalités {#number-of-new-and-total-features}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

Sur [GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/releases), vous pouvez afficher le nombre de nouvelles fonctionnalités et le total des fonctionnalités du projet.

![Badge indiquant le nombre de nouvelles fonctionnalités et le total des fonctionnalités dans une release GitLab.](img/feature_count_v14_6.png "Nombre de fonctionnalités dans une release")

Les totaux sont affichés sur des [shields](https://shields.io/) et sont générés par release par [une tâche Rake dans le dépôt `www-gitlab-com`](https://gitlab.com/gitlab-com/www-gitlab-com/-/blob/master/lib/tasks/update_gitlab_project_releases_page.rake).

| Élément             | Formule                                                                            |
|------------------|------------------------------------------------------------------------------------|
| `New features`   | Nombre total de publications de release toutes éditions confondues pour une seule release dans le projet. |
| `Total features` | Nombre total de publications de release dans l'ordre inverse pour toutes les releases du projet.     |

Les totaux sont également affichés par édition de licence.

| Élément             | Formule                                                                                             |
|------------------|-----------------------------------------------------------------------------------------------------|
| `New features`   | Nombre total de publications de release pour une seule édition et une seule release dans le projet.              |
| `Total features` | Nombre total de publications de release pour une seule édition dans l'ordre inverse pour toutes les releases du projet. |
