---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Dépôt de paquets génériques GitLab
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Utilisez le dépôt de paquets génériques pour publier et gérer des fichiers génériques, tels que des binaires de release, dans le registre de paquets de votre projet. Cette fonctionnalité est particulièrement utile pour stocker et distribuer des artefacts qui ne correspondent pas à des formats de paquets spécifiques tels que npm ou Maven.

Le dépôt de paquets génériques fournit :

- Un emplacement pour stocker tout type de fichier en tant que paquet.
- Le contrôle de version pour vos paquets.
- L'intégration avec GitLab CI/CD.
- L'accès à l'API pour l'automatisation.

## S'authentifier auprès du registre de paquets {#authenticate-to-the-package-registry}

Pour interagir avec le registre de paquets, vous devez vous authentifier à l'aide de l'une des méthodes suivantes :

- Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) avec la portée définie sur `api`.
- Un [jeton d'accès au projet](../../project/settings/project_access_tokens.md) avec la portée définie sur `api` et le rôle Développeur, Chargé de maintenance ou Propriétaire.
- Un [job token CI/CD](../../../ci/jobs/ci_job_token.md).
- Un [jeton de déploiement](../../project/deploy_tokens/_index.md) avec la portée définie sur `read_package_registry`, `write_package_registry`, ou les deux.

N'utilisez pas de méthodes d'authentification autres que celles documentées ici. Les méthodes d'authentification non documentées sont susceptibles d'être supprimées à l'avenir.

Lorsque vous vous authentifiez auprès du registre de paquets, vous devez suivre ces bonnes pratiques :

- Pour accéder aux permissions associées au rôle Developer, utilisez un jeton d'accès personnel.
- Utilisez des job tokens CI/CD pour les pipelines automatisés.
- Utilisez des jetons de déploiement pour l'intégration de systèmes externes.
- Envoyez toujours les informations d'authentification via HTTPS.

### Authentification HTTP Basic {#http-basic-authentication}

Si vous utilisez un outil qui ne prend pas en charge les méthodes d'authentification standard, vous pouvez utiliser l'authentification HTTP Basic :

```shell
curl --user "<username>:<token>" <other options> <GitLab API endpoint>
```

Bien qu'il soit ignoré, vous devez fournir un nom d'utilisateur. Le jeton est votre jeton d'accès personnel, votre job token CI/CD ou votre jeton de déploiement.

## Publier un paquet {#publish-a-package}

Vous pouvez publier des paquets via l'API.

### Publier un fichier unique {#publish-a-single-file}

Pour publier un fichier unique, utilisez l'endpoint d'API suivant :

```shell
PUT /projects/:id/packages/generic/:package_name/:package_version/:file_name
```

Remplacez les espaces réservés dans l'URL par vos valeurs spécifiques :

- `:id` : L'ID de votre projet ou le chemin encodé en URL
- `:package_name` : nom de votre paquet
- `:package_version` : Version de votre paquet
- `:file_name` : nom du fichier que vous chargez. Voir [le format de nom de fichier de paquet valide](#valid-package-filename-format) ci-dessous.

Par exemple :

{{< tabs >}}

{{< tab title="Jeton d'accès personnel" >}}

Avec des en-têtes HTTP :

```shell
curl --location --header "PRIVATE-TOKEN: <personal_access_token>" \
     --upload-file path/to/file.txt \
     "https://gitlab.example.com/api/v4/projects/24/packages/generic/my_package/1.0.0/file.txt"
```

Avec l'authentification HTTP Basic :

```shell
curl --location --user "<username>:<personal_access_token>" \
     --upload-file path/to/file.txt \
     "https://gitlab.example.com/api/v4/projects/24/packages/generic/my_package/1.0.0/file.txt"
```

{{< /tab >}}

{{< tab title="Jeton d'accès au projet" >}}

Avec des en-têtes HTTP :

```shell
curl --location --header "PRIVATE-TOKEN: <project_access_token>" \
     --upload-file path/to/file.txt \
     "https://gitlab.example.com/api/v4/projects/24/packages/generic/my_package/1.0.0/file.txt"
```

Avec l'authentification HTTP Basic :

```shell
curl --location --user "<project_access_token_username>:project_access_token" \
     --upload-file path/to/file.txt \
     "https://gitlab.example.com/api/v4/projects/24/packages/generic/my_package/1.0.0/file.txt"
```

{{< /tab >}}

{{< tab title="Jeton de déploiement" >}}

Avec des en-têtes HTTP :

```shell
curl --location --header "DEPLOY-TOKEN: <deploy_token>" \
     --upload-file path/to/file.txt \
     "https://gitlab.example.com/api/v4/projects/24/packages/generic/my_package/1.0.0/file.txt"
```

Avec l'authentification HTTP Basic :

```shell
curl --location --user "<deploy_token_username>:<deploy_token>" \
     --upload-file path/to/file.txt \
     "https://gitlab.example.com/api/v4/projects/24/packages/generic/my_package/1.0.0/file.txt"
```

Remplacez `<deploy_token_username>` par le nom d'utilisateur de votre jeton de déploiement et `<deploy_token>` par votre jeton de déploiement réel.

{{< /tab >}}

{{< tab title="Job token CI/CD" >}}

Ces exemples concernent un fichier `.gitlab-ci.yml`. GitLab CI/CD fournit automatiquement le `CI_JOB_TOKEN`.

Avec des en-têtes HTTP :

```yaml
publish:
  stage: deploy
  script:
    - |
      curl --location --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
           --upload-file path/to/file.txt \
           "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/file.txt"
```

Avec l'authentification HTTP Basic :

```yaml
publish:
  stage: deploy
  script:
    - |
      curl --location --user "gitlab-ci-token:${CI_JOB_TOKEN}" \
           --upload-file path/to/file.txt \
           "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/file.txt"
```

{{< /tab >}}

{{< /tabs >}}

Chaque requête retourne une réponse indiquant le succès ou l'échec. Si votre chargement est réussi, le statut de la réponse est `201 Created`.

### Publier plusieurs fichiers {#publish-multiple-files}

Pour publier plusieurs fichiers ou un répertoire entier, vous devez effectuer un appel API pour chaque fichier.

Vous devez suivre ces bonnes pratiques lorsque vous publiez plusieurs fichiers dans le dépôt :

- Versionnage : utilisez un schéma de versionnage cohérent pour votre paquet. Celui-ci peut être basé sur la version de votre projet, le numéro de build ou la date.
- Organisation des fichiers : réfléchissez à la façon dont vous souhaitez structurer vos fichiers dans le paquet. Vous pouvez inclure un fichier manifeste qui liste tous les fichiers inclus et leur utilité.
- Automatisation : dans la mesure du possible, automatisez le processus de publication via des pipelines CI/CD. Cela garantit la cohérence et réduit les erreurs manuelles.
- Gestion des erreurs : implémentez la vérification des erreurs dans vos scripts. Par exemple, vérifiez le code de réponse HTTP de cURL pour vous assurer que chaque fichier a été chargé avec succès.
- Journalisation : conservez des journaux des fichiers chargés, indiquant quand et par qui ils l'ont été. Cela peut être crucial pour le dépannage et l'audit.
- Compression : pour les répertoires volumineux, envisagez de compresser le contenu en un seul fichier avant le chargement. Cela peut simplifier le processus de chargement et réduire le nombre d'appels API.
- Sommes de contrôle : les sommes de contrôle SHA256 sont automatiquement calculées et stockées pour les fichiers chargés. Utilisez les sommes de contrôle pour vérifier l'intégrité des fichiers téléchargés.

Par exemple :

{{< tabs >}}

{{< tab title="Avec un script Bash" >}}

Créez un script Bash pour itérer à travers les fichiers et les charger :

```shell
#!/bin/bash

TOKEN="<access_token>"
PROJECT_ID="24"
PACKAGE_NAME="my_package"
PACKAGE_VERSION="1.0.0"
DIRECTORY_PATH="./files_to_upload"

for file in "$DIRECTORY_PATH"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        curl --location --header "PRIVATE-TOKEN: $TOKEN" \
             --upload-file "$file" \
             "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/packages/generic/$PACKAGE_NAME/$PACKAGE_VERSION/$filename"
        echo "Uploaded: $filename"
    fi
done
```

{{< /tab >}}

{{< tab title="Avec GitLab CI/CD" >}}

Pour les chargements automatisés dans votre pipeline CI/CD, vous pouvez itérer à travers vos fichiers et les charger :

```yaml
upload_package:
  stage: publish
  script:
    - |
      for file in ./build/*; do
        if [ -f "$file" ]; then
          filename=$(basename "$file")
          curl --header "JOB-TOKEN: $CI_JOB_TOKEN" \
               --upload-file "$file" \
               "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/$filename"
          echo "Uploaded: $filename"
        fi
      done
```

{{< /tab >}}

{{< /tabs >}}

### Maintenir la structure de répertoires {#maintain-directory-structure}

Pour préserver la structure d'un répertoire publié, incluez le chemin relatif dans le nom du fichier :

```shell
#!/bin/bash

TOKEN="<access_token>"
PROJECT_ID="24"
PACKAGE_NAME="my_package"
PACKAGE_VERSION="1.0.0"
DIRECTORY_PATH="./files_to_upload"

find "$DIRECTORY_PATH" -type f | while read -r file; do
    relative_path=${file#"$DIRECTORY_PATH/"}
    curl --location --header "PRIVATE-TOKEN: $TOKEN" \
         --upload-file "$file" \
         "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/packages/generic/$PACKAGE_NAME/$PACKAGE_VERSION/$relative_path"
    echo "Uploaded: $relative_path"
done
```

## Télécharger un paquet {#download-a-package}

Vous pouvez télécharger des paquets via l'API.

### Télécharger un fichier unique {#download-a-single-file}

Pour télécharger un fichier de paquet unique, utilisez l'endpoint d'API suivant :

```shell
GET /projects/:id/packages/generic/:package_name/:package_version/:file_name
```

Remplacez les espaces réservés dans l'URL par vos valeurs spécifiques :

- `:id` : L'ID de votre projet ou le chemin encodé en URL
- `:package_name` : nom de votre paquet
- `:package_version` : Version de votre paquet
- `:file_name` : nom du fichier que vous téléchargez

Par exemple :

{{< tabs >}}

{{< tab title="Jeton d'accès personnel" >}}

Avec des en-têtes HTTP :

```shell
curl --header "PRIVATE-TOKEN: <access_token>" \
     --location \
     "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt" \
     --output file.txt
```

Avec l'authentification HTTP Basic :

```shell
curl --user "<username>:<access_token>" \
     --location \
     "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt" \
     --output file.txt
```

{{< /tab >}}

{{< tab title="Jeton d'accès au projet" >}}

Avec des en-têtes HTTP :

```shell
curl --header "PRIVATE-TOKEN: <project_access_token>" \
     --location \
     "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt" \
     --output file.txt
```

Avec l'authentification HTTP Basic :

```shell
curl --user "<project_access_token_username>:<project_access_token>" \
     --location \
     "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt" \
     --output file.txt
```

{{< /tab >}}

{{< tab title="Jeton de déploiement" >}}

Avec des en-têtes HTTP :

```shell
curl --header "DEPLOY-TOKEN: <deploy_token>" \
     --location \
     "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt" \
     --output file.txt
```

Avec l'authentification HTTP Basic :

```shell
curl --user "<deploy_token_username>:<deploy_token>" \
     --location \
     "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt" \
     --output file.txt
```

{{< /tab >}}

{{< tab title="Job token CI/CD" >}}

Ces exemples concernent un fichier `.gitlab-ci.yml`. GitLab CI/CD fournit automatiquement le `CI_JOB_TOKEN`.

Avec des en-têtes HTTP :

```yaml
download:
  stage: test
  script:
    - |
      curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
           --location \
           --output file.txt \
           "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/file.txt"
```

Avec l'authentification HTTP Basic :

```yaml
download:
  stage: test
  script:
    - |
      curl --user "gitlab-ci-token:${CI_JOB_TOKEN}" \
           --location \
           --output file.txt \
           "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/file.txt"
```

Chaque requête retourne une réponse indiquant le succès ou l'échec. Si votre chargement est réussi, le statut de la réponse est `201 Created`.

{{< /tab >}}

{{< /tabs >}}

### Télécharger plusieurs fichiers {#download-multiple-files}

Pour télécharger plusieurs fichiers ou un répertoire entier, vous devez effectuer un appel API pour chaque fichier, ou utiliser des outils supplémentaires.

Vous devez suivre ces bonnes pratiques lorsque vous téléchargez plusieurs fichiers depuis le dépôt :

- Versionnage : spécifiez toujours la version exacte du paquet que vous souhaitez télécharger pour garantir la cohérence.
- Structure de répertoires : lors du téléchargement, maintenez la structure de répertoires d'origine du paquet pour préserver l'organisation des fichiers.
- Automatisation : intégrez les téléchargements de paquets dans vos pipelines CI/CD ou vos scripts de build pour des workflows automatisés.
- Gestion des erreurs : implémentez des vérifications pour vous assurer que tous les fichiers sont téléchargés avec succès. Vous pouvez vérifier le code de statut HTTP ou l'existence du fichier après le téléchargement.
- Mise en cache : pour les paquets fréquemment utilisés, envisagez d'implémenter un mécanisme de mise en cache pour réduire l'utilisation du réseau et améliorer les temps de build.
- Téléchargements parallèles : pour les paquets volumineux comportant de nombreux fichiers, vous pouvez implémenter des téléchargements parallèles pour accélérer le processus.
- Sommes de contrôle : vérifiez l'intégrité des fichiers téléchargés à l'aide des sommes de contrôle SHA256. Les sommes de contrôle sont fournies dans les en-têtes de réponse et les réponses API à des fins de vérification.
- Téléchargements incrémentiels : pour les paquets volumineux qui changent fréquemment, envisagez d'implémenter un mécanisme permettant de télécharger uniquement les fichiers modifiés depuis le dernier téléchargement.

Par exemple :

{{< tabs >}}

{{< tab title="Avec un script Bash" >}}

Créez un script bash pour télécharger plusieurs fichiers :

```shell
#!/bin/bash

TOKEN="<access_token>"
PROJECT_ID="24"
PACKAGE_NAME="my_package"
PACKAGE_VERSION="1.0.0"
OUTPUT_DIR="./downloaded_files"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Array of files to download
files=("file1.txt" "file2.txt" "subdirectory/file3.txt")

for file in "${files[@]}"; do
    curl --location --header "PRIVATE-TOKEN: $TOKEN" \
         --output "$OUTPUT_DIR/$file" \
         --create-dirs \
         "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/packages/generic/$PACKAGE_NAME/$PACKAGE_VERSION/$file"
    echo "Downloaded: $file"
done
```

{{< /tab >}}

{{< tab title="Avec GitLab CI/CD" >}}

Pour les téléchargements automatisés dans votre pipeline CI/CD :

```yaml
download_package:
  stage: build
  script:
    - |
      FILES=("file1.txt" "file2.txt" "subdirectory/file3.txt")
      for file in "${FILES[@]}"; do
        curl --location --header "JOB-TOKEN: $CI_JOB_TOKEN" \
             --output "$file" \
             --create-dirs \
             "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/$file"
        echo "Downloaded: $file"
      done
```

{{< /tab >}}

{{< /tabs >}}

### Télécharger un paquet entier {#download-an-entire-package}

Pour télécharger tous les fichiers d'un paquet, vous devez :

1. Obtenir l'ID du paquet.
1. Lister le contenu du paquet à l'aide de l'API GitLab.
1. Télécharger chaque fichier.

Exécutez la commande suivante pour télécharger tous les fichiers d'un paquet :

```shell
TOKEN="<access_token>"
PROJECT_ID="24"
PACKAGE_NAME="my_package"
PACKAGE_VERSION="1.0.0"
GITLAB_URL="https://gitlab.example.com"
OUTPUT_DIR="./downloaded_package"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Step 1: Get the package ID
PACKAGE_ID=$(curl --location --header "PRIVATE-TOKEN: $TOKEN" \
     "$GITLAB_URL/api/v4/projects/$PROJECT_ID/packages?package_type=generic&package_name=$PACKAGE_NAME&package_version=$PACKAGE_VERSION" \
     | jq -r ".[] | select(.name==\"$PACKAGE_NAME\" and .version==\"$PACKAGE_VERSION\") | .id")

if [ -z "$PACKAGE_ID" ] || [ "$PACKAGE_ID" = "null" ]; then
    echo "Error: Package '$PACKAGE_NAME' version '$PACKAGE_VERSION' not found"
    exit 1
fi

echo "Found package ID: $PACKAGE_ID"

# Step 2: Get list of files in the package
files=$(curl --location --header "PRIVATE-TOKEN: $TOKEN" \
     "$GITLAB_URL/api/v4/projects/$PROJECT_ID/packages/$PACKAGE_ID/package_files" \
     | jq -r '.[].file_name')

if [ -z "$files" ]; then
    echo "Error: No files found in package"
    exit 1
fi

# Step 3: Download each file
for file in $files; do
    echo "Downloading: $file"
    curl --location --header "PRIVATE-TOKEN: $TOKEN" \
         --output "$OUTPUT_DIR/$file" \
         --create-dirs \
         "$GITLAB_URL/api/v4/projects/$PROJECT_ID/packages/generic/$PACKAGE_NAME/$PACKAGE_VERSION/$file"
    # Check if download was successful
    if [ $? -eq 0 ]; then
        echo "✓ Downloaded: $file"
    else
        echo "✗ Failed to download: $file"
    fi
done

echo "Package download complete"
```

## Supprimer un paquet {#delete-a-package}

Avant de supprimer un paquet, assurez-vous de comprendre les [risques de sécurité associés](../package_registry/supported_functionality.md#deleting-packages).

Pour supprimer un paquet, vous pouvez soit :

- [Utiliser l'interface utilisateur](../package_registry/reduce_package_registry_storage.md#delete-a-package).
- [Utiliser l'API](../../../api/packages.md#delete-a-project-package).

## Vérifier l'intégrité des fichiers avec des sommes de contrôle {#verify-file-integrity-with-checksums}

Les sommes de contrôle SHA256 sont automatiquement calculées et stockées pour tous les fichiers chargés. Vous pouvez utiliser ces sommes de contrôle pour vérifier l'intégrité des fichiers téléchargés.

Pour vérifier les sommes de contrôle, vous pouvez soit :

- Obtenir les sommes de contrôle depuis les en-têtes de réponse HTTP.
- Obtenir les sommes de contrôle depuis les réponses API.
- Intégrer la vérification des sommes de contrôle dans les pipelines CI/CD.

### Obtenir les sommes de contrôle depuis les en-têtes de réponse {#get-checksums-from-response-headers}

Lorsque vous téléchargez des fichiers, vous pouvez obtenir la somme de contrôle SHA256 dans l'en-tête de réponse `X-Checksum-SHA256`.

Prérequis :

Pour obtenir les sommes de contrôle dans les en-têtes de réponse, vous devez soit :

- Désactiver le stockage d'objets afin que les fichiers soient stockés localement.
- Activer le stockage d'objets, mais désactiver le téléchargement direct (les fichiers sont servis via GitLab Workhorse). Lorsque le téléchargement direct du stockage d'objets est activé, les fichiers sont redirigés vers le fournisseur de stockage d'objets, et les en-têtes personnalisés tels que `X-Checksum-SHA256` ne peuvent pas être inclus dans la réponse de redirection.

```shell
# Download a file and get the checksum from the response header
curl --header "PRIVATE-TOKEN: <access_token>" \
     --location \
     --output file.txt \
     --dump-header headers.txt \
     --url "https://gitlab.example.com/api/v4/projects/1/packages/generic/my_package/0.0.1/file.txt"

# Extract the checksum from the response header
CHECKSUM=$(grep "X-Checksum-SHA256:" headers.txt | cut -d' ' -f2 | tr -d '\r')
echo "Expected checksum: $CHECKSUM"

# Verify the downloaded file
ACTUAL_CHECKSUM=$(sha256sum file.txt | cut -d' ' -f1)
if [ "$CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
    echo "✓ File integrity verified"
else
    echo "✗ File integrity check failed"
fi
```

### Obtenir les sommes de contrôle depuis les réponses API {#get-checksums-from-api-responses}

Obtenez les sommes de contrôle en listant les fichiers de paquets dans les appels API :

```shell
# Get the package ID
PACKAGE_ID=$(curl --header "PRIVATE-TOKEN: <access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/1/packages?package_type=generic&package_name=my_package&package_version=0.0.1" \
     | jq -r ".[] | select(.name==\"my_package\" and .version==\"0.0.1\") | .id")

# Get file information, including checksums
curl --header "PRIVATE-TOKEN: <access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/1/packages/$PACKAGE_ID/package_files" \
     | jq '.[] | {file_name: .file_name, file_sha256: .file_sha256}'
```

### Vérifier l'intégrité des fichiers dans les pipelines CI/CD {#verify-file-integrity-in-cicd-pipelines}

Vous pouvez intégrer la vérification des sommes de contrôle dans vos pipelines CI/CD.

Prérequis :

Pour vérifier les sommes de contrôle dans les pipelines CI/CD, vous devez soit :

- Désactiver le stockage d'objets afin que les fichiers soient stockés localement.
- Activer le stockage d'objets, mais désactiver le téléchargement direct (les fichiers sont servis via GitLab Workhorse). Lorsque le téléchargement direct du stockage d'objets est activé, les fichiers sont redirigés vers le fournisseur de stockage d'objets, et les en-têtes personnalisés tels que `X-Checksum-SHA256` ne peuvent pas être inclus dans la réponse de redirection.

```yaml
verify_download:
  stage: test
  script:
    - |
      # Download file and get checksum from header
      curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
           --location \
           --output file.txt \
           --dump-header headers.txt \
           "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my_package/${CI_COMMIT_TAG}/file.txt"

      # Extract checksum from response header
      EXPECTED_CHECKSUM=$(grep "X-Checksum-SHA256:" headers.txt | cut -d' ' -f2 | tr -d '\r')

      # Calculate actual checksum
      ACTUAL_CHECKSUM=$(sha256sum file.txt | cut -d' ' -f1)

      # Verify integrity
      if [ "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
        echo "✓ File integrity verified"
      else
        echo "✗ File integrity check failed"
        exit 1
      fi
```

## Désactiver la publication de noms de paquets en double {#disable-publishing-duplicate-package-names}

{{< history >}}

- Le rôle requis a [changé](https://gitlab.com/gitlab-org/gitlab/-/issues/350682) de Developer à Maintainer dans GitLab 15.0.
- Le rôle requis a [changé](https://gitlab.com/gitlab-org/gitlab/-/issues/370471) de Maintainer à Owner dans GitLab 17.0.

{{< /history >}}

Par défaut, lorsque vous publiez un paquet portant le même nom et la même version qu'un paquet existant, les nouveaux fichiers sont ajoutés au paquet existant. Vous pouvez désactiver la publication de noms de fichiers en double dans les paramètres.

Prérequis :

- Vous devez avoir le rôle Propriétaire.

Pour désactiver la publication de noms de fichiers en double :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Paquets et registres**.
1. Dans la ligne **Générique** du tableau **Paquets dupliqués**, désactivez le bouton bascule **Autoriser les doublons**.
1. Facultatif. Dans la zone de texte **Exception**, saisissez une expression régulière correspondant aux noms et versions des paquets à autoriser.

> [!note]
> Si **Autoriser les doublons** est activé, vous pouvez spécifier les noms et versions des paquets qui ne doivent pas avoir de doublons dans la zone de texte **Exception**.

## Ajouter une politique de rétention des paquets {#add-a-package-retention-policy}

Implémentez une politique de rétention des paquets pour gérer le stockage et maintenir les versions pertinentes.

Pour ce faire :

- Utilisez les [politiques de nettoyage](../package_registry/reduce_package_registry_storage.md#cleanup-policy) intégrées à GitLab.

Vous pouvez également utiliser l'API pour implémenter des scripts de nettoyage personnalisés.

## Exemple de projet de paquet générique {#generic-package-sample-project}

Le projet [Write CI-CD Variables in Pipeline](https://gitlab.com/guided-explorations/cfg-data/write-ci-cd-variables-in-pipeline) contient un exemple fonctionnel que vous pouvez utiliser pour créer, charger et télécharger des paquets génériques dans GitLab CI/CD.

Il montre également comment gérer une version sémantique pour le paquet générique : la stocker dans une variable CI/CD, la récupérer, l'incrémenter et la réécrire dans la variable CI/CD lorsque les tests de téléchargement fonctionnent correctement.

## Format de nom de fichier de paquet valide {#valid-package-filename-format}

Les noms de fichiers de paquets valides peuvent inclure :

- Lettres : A-Z, a-z
- Chiffres : 0-9
- Caractères spéciaux : . (point), _ (tiret bas), - (trait d'union), + (plus), ~ (tilde), @ (arobase), / (barre oblique)

Le nom de fichier du paquet ne peut pas :

- Commencer par un tilde (~) ou l'arobase (@)
- Se terminer par un tilde (~) ou l'arobase (@)
- Inclure des espaces

## Dépannage {#troubleshooting}

### Erreurs HTTP 403 {#http-403-errors}

Vous pouvez obtenir une erreur `HTTP 403 Forbidden`. Cette erreur se produit dans l'un ou l'autre des cas suivants :

- Vous n'avez pas accès à une ressource.
- Le registre de paquets n'est pas activé pour le projet.

Pour résoudre le problème, assurez-vous que le registre de paquets est activé et que vous disposez de l'autorisation d'y accéder.

### Erreur de serveur interne lors de chargements de fichiers volumineux vers S3 {#internal-server-error-on-large-file-uploads-to-s3}

Le stockage d'objets compatible S3 [limite la taille d'une seule requête PUT à 5 Go](https://docs.aws.amazon.com/AmazonS3/latest/userguide/upload-objects.html). Si `aws_signature_version` est défini sur `2` dans les [paramètres de connexion au stockage d'objets](../../../administration/object_storage.md), tenter de publier un fichier de paquet dépassant la limite de 5 Go peut entraîner une réponse `HTTP 500: Internal Server Error`.

Si vous recevez des réponses `HTTP 500: Internal Server Error` lors de la publication de fichiers volumineux vers S3, définissez `aws_signature_version` sur `4` :

```ruby
# Consolidated Object Storage settings
gitlab_rails['object_store']['connection'] = {
  # Other connection settings
  'aws_signature_version' => '4'
}
# OR
# Storage-specific form settings
gitlab_rails['packages_object_store_connection'] = {
  # Other connection settings
  'aws_signature_version' => '4'
}
```
