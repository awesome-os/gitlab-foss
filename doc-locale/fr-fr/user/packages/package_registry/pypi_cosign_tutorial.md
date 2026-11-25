---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : créer et signer des paquets Python avec GitLab CI/CD'
---

Ce tutoriel vous montre comment implémenter un pipeline sécurisé pour les paquets Python. Le pipeline comprend des étapes qui signent et vérifient cryptographiquement les paquets Python à l'aide de GitLab CI/CD et de [Sigstore Cosign](https://docs.sigstore.dev/).

À la fin, vous apprendrez à :

- Créer et signer des paquets Python à l'aide de GitLab CI/CD.
- Stocker et gérer les signatures de paquets à l'aide du registre de paquets générique.
- Vérifier les signatures de paquets en tant qu'utilisateur final.

## Quels sont les avantages de la signature de paquets ? {#what-are-the-benefits-of-package-signing}

La signature de paquets offre plusieurs avantages essentiels en matière de sécurité :

- Authenticité : les utilisateurs peuvent vérifier que les paquets proviennent de sources fiables.
- Intégrité des données : si un paquet est altéré lors de sa distribution, cela sera détecté.
- Non-répudiation : l'origine d'un paquet peut être prouvée de manière cryptographique.
- Sécurité de la chaîne d'approvisionnement : la signature de paquets protège contre les attaques sur la chaîne d'approvisionnement et les dépôts compromis.

## Avant de commencer {#before-you-begin}

Pour réaliser ce tutoriel, vous avez besoin de :

- Un compte GitLab et un projet de test.
- Des connaissances de base en matière de packaging Python, de GitLab CI/CD et des concepts de registre de paquets.

## Étapes {#steps}

Voici une vue d'ensemble de ce que vous allez faire :

1. [Configurer un projet Python.](#set-up-a-python-project)
1. [Ajouter une configuration de base.](#add-base-configuration)
1. [Configurer l'étape de build.](#configure-the-build-stage)
1. [Configurer l'étape de signature.](#configure-the-sign-stage)
1. [Configurer l'étape de vérification.](#configure-the-verify-stage)
1. [Configurer l'étape de publication.](#configure-the-publish-stage)
1. [Configurer l'étape de publication des signatures.](#configure-the-publish-signatures-stage)
1. [Configurer l'étape de vérification côté consommateur.](#configure-the-consumer-verification-stage)
1. [Vérifier les paquets en tant qu'utilisateur.](#verify-packages-as-a-user)

### Configurer un projet Python {#set-up-a-python-project}

Commencez par créer un projet de test. Ajoutez un fichier `pyproject.toml` à la racine de votre projet :

```toml
[build-system]
requires = ["setuptools>=45", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "<my_package>"  # Will be dynamically replaced by CI/CD pipeline
version = "<1.0.0>"    # Will be dynamically replaced by CI/CD pipeline
description = "<Your package description>"
readme = "README.md"
requires-python = ">=3.7"
authors = [
    {name = "<Your Name>", email = "<your.email@example.com>"},
]

[project.urls]
"Homepage" = "<https://gitlab.com/my_package>"  # Will be replaced with actual project URL
```

Assurez-vous de remplacer `Your Name` et `your.email@example.com` par vos propres informations personnelles.

Lorsque vous aurez terminé de construire votre pipeline CI/CD dans les étapes suivantes, le pipeline effectuera automatiquement les actions suivantes :

- Remplace `my_package` par une version normalisée du nom de votre projet.
- Remplace la `version` pour correspondre à la version du pipeline.
- Remplace l'URL `Homepage` pour correspondre à l'URL de votre projet GitLab.

#### Ajouter une configuration de base {#add-base-configuration}

À la racine de votre projet, ajoutez un fichier `.gitlab-ci.yml`. Ajoutez la configuration suivante :

```yaml
variables:
  # Base Python version for all jobs
  PYTHON_VERSION: '3.10'
  # Package names and versions
  PACKAGE_NAME: ${CI_PROJECT_NAME}
  PACKAGE_VERSION: "1.0.0"  # Use semantic versioning
  # Sigstore service URLs
  FULCIO_URL: 'https://fulcio.sigstore.dev'
  REKOR_URL: 'https://rekor.sigstore.dev'
  # Identity for Sigstore verification
  CERTIFICATE_IDENTITY: 'https://gitlab.com/${CI_PROJECT_PATH}//.gitlab-ci.yml@refs/heads/${CI_DEFAULT_BRANCH}'
  CERTIFICATE_OIDC_ISSUER: 'https://gitlab.com'
  # Pip cache directory for faster builds
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.pip-cache"
  # Auto-accept prompts from Cosign
  COSIGN_YES: "true"
  # Base URL for generic package registry
  GENERIC_PACKAGE_BASE_URL: "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${PACKAGE_VERSION}"

default:
  before_script:
    # Normalize package name once at the start of any job
    - export NORMALIZED_NAME=$(echo "${CI_PROJECT_NAME}" | tr '-' '_')

# Template for Python-based jobs
.python-job:
  image: python:${PYTHON_VERSION}
  before_script:
    # First normalize package name
    - export NORMALIZED_NAME=$(echo "${CI_PROJECT_NAME}" | tr '-' '_')
    # Then install Python dependencies
    - pip install --upgrade pip
    - pip install build twine setuptools wheel
  cache:
    paths:
      - ${PIP_CACHE_DIR}

# Template for Python + Cosign jobs
.python+cosign-job:
  extends: .python-job
  before_script:
    # First normalize package name
    - export NORMALIZED_NAME=$(echo "${CI_PROJECT_NAME}" | tr '-' '_')
    # Then install dependencies
    - apt-get update && apt-get install -y curl wget
    - wget -O cosign https://github.com/sigstore/cosign/releases/download/v2.2.3/cosign-linux-amd64
    - chmod +x cosign && mv cosign /usr/local/bin/
    - export COSIGN_EXPERIMENTAL=1
    - pip install --upgrade pip
    - pip install build twine setuptools wheel
stages:
  - build
  - sign
  - verify
  - publish
  - publish_signatures
  - consumer_verification
```

Cette configuration de base :

- Indique au pipeline d'utiliser Python `3.10` comme image de base pour assurer la cohérence
- Configure deux templates réutilisables : `.python-job` pour les opérations Python de base et `.python+cosign-job` pour les opérations de signature
- Implémente la mise en cache de pip pour accélérer les builds
- Normalise les noms de paquets en convertissant les traits d'union en underscores pour la compatibilité Python
- Définit toutes les variables clés au niveau du pipeline pour faciliter la gestion

### Configurer l'étape de build {#configure-the-build-stage}

L'étape de build crée les paquets de distribution Python.

Dans votre fichier `.gitlab-ci.yml`, ajoutez la configuration suivante :

```yaml
build:
  extends: .python-job
  stage: build
  script:
    # Initialize git repo with actual content
    - git init
    - git config --global init.defaultBranch main
    - git config --global user.email "ci@example.com"
    - git config --global user.name "CI"
    - git add .
    - git commit -m "Initial commit"

    # Update package name, version, and homepage URL in pyproject.toml
    - sed -i "s/name = \".*\"/name = \"${NORMALIZED_NAME}\"/" pyproject.toml
    - sed -i "s/version = \".*\"/version = \"${PACKAGE_VERSION}\"/" pyproject.toml
    - sed -i "s|\"Homepage\" = \".*\"|\"Homepage\" = \"https://gitlab.com/${CI_PROJECT_PATH}\"|" pyproject.toml

    # Debug: show updated file
    - echo "Updated pyproject.toml contents:"
    - cat pyproject.toml

    # Build package
    - python -m build
  artifacts:
    paths:
      - dist/
      - pyproject.toml
```

La configuration de l'étape de build :

- Initialise un dépôt Git pour le contexte de build
- Met à jour dynamiquement les métadonnées du paquet dans `pyproject.toml`
- Ajoute les paquets wheel (`.whl`) et de distribution source (`.tar.gz`)
- Conserve les artefacts de build pour les étapes suivantes
- Fournit une sortie de débogage pour la résolution des problèmes

### Configurer l'étape de signature {#configure-the-sign-stage}

L'étape de signature signe les paquets à l'aide de Sigstore Cosign.

Dans votre fichier `.gitlab-ci.yml`, ajoutez la configuration suivante :

```yaml
sign:
  extends: .python+cosign-job
  stage: sign
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  script:
    - |
      for file in dist/*.whl dist/*.tar.gz; do
        if [ -f "$file" ]; then
          filename=$(basename "$file")

          cosign sign-blob --yes \
            --fulcio-url=${FULCIO_URL} \
            --rekor-url=${REKOR_URL} \
            --oidc-issuer $CI_SERVER_URL \
            --identity-token $SIGSTORE_ID_TOKEN \
            --output-signature "dist/${filename}.sig" \
            --output-certificate "dist/${filename}.crt" \
            "$file"

          # Debug: Verify files were created
          echo "Checking generated signature and certificate:"
          ls -l "dist/${filename}.sig" "dist/${filename}.crt"
        fi
      done
  artifacts:
    paths:
      - dist/
```

La configuration de l'étape de signature :

- Utilise la [signature sans clé](https://docs.sigstore.dev/cosign/signing/overview/) de Sigstore pour une sécurité renforcée
- Signe les paquets wheel et de distribution source
- Crée des fichiers de signature (`.sig`) et de certificat (`.crt`) distincts
- Utilise une intégration OIDC pour l'authentification
- Inclut une journalisation détaillée pour la génération des signatures

### Configurer l'étape de vérification {#configure-the-verify-stage}

L'étape de vérification valide les signatures localement.

Dans votre fichier `.gitlab-ci.yml`, ajoutez la configuration suivante :

```yaml
verify:
  extends: .python+cosign-job
  stage: verify
  script:
    - |
      failed=0

      for file in dist/*.whl dist/*.tar.gz; do
        if [ -f "$file" ]; then
          filename=$(basename "$file")

          echo "Verifying file: $file"
          echo "Using signature: dist/${filename}.sig"
          echo "Using certificate: dist/${filename}.crt"

          if ! cosign verify-blob \
            --signature "dist/${filename}.sig" \
            --certificate "dist/${filename}.crt" \
            --certificate-identity "${CERTIFICATE_IDENTITY}" \
            --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
            "$file"; then
            echo "Verification failed for $filename"
            failed=1
          fi
        fi
      done

      if [ $failed -eq 1 ]; then
        exit 1
      fi
```

La configuration de l'étape de vérification :

- Vérifie les signatures immédiatement après la signature
- Vérifie les paquets wheel et de distribution source
- Valide l'identité du certificat et l'émetteur OIDC
- Échoue rapidement si une vérification échoue
- Fournit des journaux de vérification détaillés

### Configurer l'étape de publication {#configure-the-publish-stage}

L'étape de publication téléverse les paquets vers le registre de paquets PyPI de GitLab.

Dans votre fichier `.gitlab-ci.yml`, ajoutez la configuration suivante :

```yaml
publish:
  extends: .python-job
  stage: publish
  script:
    - |
      # Configure PyPI settings for GitLab package registry
      cat << EOF > ~/.pypirc
      [distutils]
      index-servers = gitlab
      [gitlab]
      repository = ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/pypi
      username = gitlab-ci-token
      password = ${CI_JOB_TOKEN}
      EOF

      # Upload packages using twine
      TWINE_PASSWORD=${CI_JOB_TOKEN} TWINE_USERNAME=gitlab-ci-token \
        twine upload --repository-url ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/pypi \
        dist/*.whl dist/*.tar.gz
```

La configuration de l'étape de publication :

- Configure l'authentification au registre PyPI
- Utilise le registre de paquets intégré de GitLab
- Publie les distributions wheel et source
- Utilise des jetons de job pour une authentification sécurisée
- Crée une configuration `.pypirc` réutilisable

### Configurer l'étape de publication des signatures {#configure-the-publish-signatures-stage}

L'étape de publication des signatures stocke les signatures dans le registre de paquets générique de GitLab.

Dans votre fichier `.gitlab-ci.yml`, ajoutez la configuration suivante :

```yaml
publish_signatures:
  extends: .python+cosign-job
  stage: publish_signatures
  script:
    - |
      for file in dist/*.whl dist/*.tar.gz; do
        if [ -f "$file" ]; then
          filename=$(basename "$file")

          ls -l "dist/${filename}.sig" "dist/${filename}.crt"

          echo "Publishing signatures for $filename"
          echo "Publishing to: ${GENERIC_PACKAGE_BASE_URL}/${filename}.sig"

          # Upload signature and certificate
          curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
               --fail \
               --upload-file "dist/${filename}.sig" \
               "${GENERIC_PACKAGE_BASE_URL}/${filename}.sig"

          curl --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
               --fail \
               --upload-file "dist/${filename}.crt" \
               "${GENERIC_PACKAGE_BASE_URL}/${filename}.crt"
        fi
      done
```

La configuration de l'étape de publication des signatures :

- Stocke les signatures dans le registre de paquets générique
- Maintient la correspondance entre les signatures et les paquets
- Utilise des conventions de nommage cohérentes pour les artefacts
- Inclut la vérification de la taille des signatures
- Fournit des journaux de téléversement détaillés

### Configurer l'étape de vérification côté consommateur {#configure-the-consumer-verification-stage}

L'étape de vérification côté consommateur simule la vérification des paquets par l'utilisateur final.

Dans votre fichier `.gitlab-ci.yml`, ajoutez la configuration suivante :

```yaml
consumer_verification:
  extends: .python+cosign-job
  stage: consumer_verification
  script:
    - |
      # Initialize git repo for setuptools_scm
      git init
      git config --global init.defaultBranch main

      # Create directory for downloading packages
      mkdir -p pkg signatures

      # Download the specific wheel version
      pip download --index-url "https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/api/v4/projects/${CI_PROJECT_ID}/packages/pypi/simple" \
          "${NORMALIZED_NAME}==${PACKAGE_VERSION}" --no-deps -d ./pkg --verbose

      # Download the specific source distribution version
      pip download --no-binary :all: \
          --index-url "https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/api/v4/projects/${CI_PROJECT_ID}/packages/pypi/simple" \
          "${NORMALIZED_NAME}==${PACKAGE_VERSION}" --no-deps -d ./pkg --verbose

      failed=0
      for file in pkg/*.whl pkg/*.tar.gz; do
        if [ -f "$file" ]; then
          filename=$(basename "$file")

          sig_url="${GENERIC_PACKAGE_BASE_URL}/${filename}.sig"
          cert_url="${GENERIC_PACKAGE_BASE_URL}/${filename}.crt"

          echo "Downloading signatures for $filename"
          echo "Signature URL: $sig_url"
          echo "Certificate URL: $cert_url"

          # Download signatures
          curl --fail --silent --show-error \
               --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
               --output "signatures/${filename}.sig" \
               "$sig_url"

          curl --fail --silent --show-error \
               --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
               --output "signatures/${filename}.crt" \
               "$cert_url"

          # Verify signature
          if ! cosign verify-blob \
            --signature "signatures/${filename}.sig" \
            --certificate "signatures/${filename}.crt" \
            --certificate-identity "${CERTIFICATE_IDENTITY}" \
            --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
            "$file"; then
            echo "Signature verification failed"
            failed=1
          fi
        fi
      done

      if [ $failed -eq 1 ]; then
        echo "Verification failed for one or more packages"
        exit 1
      fi
```

La configuration de l'étape de vérification côté consommateur :

- Simule l'installation de paquets dans un contexte réel
- Télécharge et vérifie les deux formats de paquets
- Utilise la correspondance de version exacte pour assurer la cohérence
- Implémente une gestion complète des erreurs
- Teste le workflow de vérification complet

### Vérifier les paquets en tant qu'utilisateur {#verify-packages-as-a-user}

En tant qu'utilisateur final, vous pouvez vérifier les signatures de paquets en suivant les étapes ci-dessous :

1. Installez Cosign :

   ```shell
   wget -O cosign https://github.com/sigstore/cosign/releases/download/v2.2.3/cosign-linux-amd64
   chmod +x cosign && sudo mv cosign /usr/local/bin/
   ```

   Cosign nécessite des permissions spéciales pour les installations globales. Utilisez `sudo` pour contourner les problèmes de permissions.

1. Téléchargez le paquet et ses signatures :

   ```shell
   # You can find your PROJECT_ID in your GitLab project's home page under the project name

   # Download the specific version of the package
   pip download your-package-name==1.0.0 --no-deps

   # The FILENAME will be the output from the pip download command
   # For example: your-package-name-1.0.0.tar.gz or your-package-name-1.0.0-py3-none-any.whl

   # Download signatures from GitLab's generic package registry
   # Replace these values with your project's details:
   # GITLAB_URL: Your GitLab instance URL (for example, https://gitlab.com)
   # PROJECT_ID: Your project's ID number
   # PACKAGE_NAME: Your package name
   # VERSION: Package version (for example, 1.0.0)
   # FILENAME: The exact filename of your downloaded package

   curl --output "${FILENAME}.sig" \
     "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${FILENAME}.sig"

   curl --output "${FILENAME}.crt" \
     "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${VERSION}/${FILENAME}.crt"
   ```

1. Vérifiez les signatures :

   ```shell
   # Replace CERTIFICATE_IDENTITY and CERTIFICATE_OIDC_ISSUER with the values from the project's pipeline
   export CERTIFICATE_IDENTITY="https://gitlab.com/your-group/your-project//.gitlab-ci.yml@refs/heads/main"
   export CERTIFICATE_OIDC_ISSUER="https://gitlab.com"

   # Verify wheel package
   FILENAME="your-package-name-1.0.0-py3-none-any.whl"
   COSIGN_EXPERIMENTAL=1 cosign verify-blob \
     --signature "${FILENAME}.sig" \
     --certificate "${FILENAME}.crt" \
     --certificate-identity "${CERTIFICATE_IDENTITY}" \
     --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
     "${FILENAME}"

   # Verify source distribution
   FILENAME="your-package-name-1.0.0.tar.gz"
   COSIGN_EXPERIMENTAL=1 cosign verify-blob \
     --signature "${FILENAME}.sig" \
     --certificate "${FILENAME}.crt" \
     --certificate-identity "${CERTIFICATE_IDENTITY}" \
     --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
     "${FILENAME}"
   ```

Lors de la vérification des paquets en tant qu'utilisateur final :

- Assurez-vous que les paquets téléchargés correspondent à la version exacte que vous souhaitez vérifier.
- Vérifiez chaque type de paquet (wheel et distribution source) séparément.
- Assurez-vous que l'identité du certificat correspond exactement à celle utilisée pour signer le paquet.
- Vérifiez que tous les composants de l'URL sont correctement définis. Par exemple, `GITLAB_URL` ou `PROJECT_ID`.
- Vérifiez que les noms de fichiers des paquets correspondent exactement à ce qui a été téléversé dans le registre.
- Utilisez le feature flag `COSIGN_EXPERIMENTAL=1` pour la vérification sans clé. Ce flag est obligatoire.
- Sachez que des vérifications échouées peuvent indiquer une altération ou des paires de certificats et de signatures incorrectes.
- Conservez une trace des valeurs d'identité du certificat et de l'émetteur issues du pipeline de votre projet.

## Dépannage {#troubleshooting}

Lors de ce tutoriel, vous pouvez rencontrer les erreurs suivantes :

### Erreur : `404 Not Found` {#error-404-not-found}

Si vous rencontrez une page d'erreur `404 Not Found` :

- Vérifiez tous les composants de l'URL.
- Vérifiez que la version du paquet existe dans le registre.
- Assurez-vous que les noms de fichiers correspondent exactement, y compris les tags de version et de plateforme.

### Échec de la vérification {#verification-failed}

Si la vérification de la signature échoue, assurez-vous que :

- `CERTIFICATE_IDENTITY` correspond au pipeline de signature.
- `CERTIFICATE_OIDC_ISSUER` est correct.
- La paire signature et certificat est correcte pour le paquet.

### Permission refusée {#permission-denied}

Si vous rencontrez des problèmes de permissions :

- Vérifiez que vous avez accès au registre de paquets.
- Vérifiez l'authentification si le registre est privé.
- Utilisez les permissions de fichiers correctes lors de l'installation de Cosign.

### Problèmes d'authentification {#authentication-issues}

Si vous rencontrez des problèmes d'authentification :

- Vérifiez les permissions de `CI_JOB_TOKEN`.
- Vérifiez la configuration de l'authentification au registre.
- Validez les paramètres d'accès du projet.

### Vérifier la configuration du paquet et les paramètres du pipeline {#verify-package-configuration-and-pipeline-settings}

Vérifiez la configuration du paquet. Assurez-vous que :

- Les noms de paquets utilisent des underscores (`_`), et non des traits d'union (`-`).
- Les chaînes de version utilisent un [PEP 440](https://peps.python.org/pep-0440/) valide.
- Le fichier `pyproject.toml` est correctement formaté.

Vérifiez les paramètres du pipeline. Assurez-vous que :

- OIDC est correctement configuré.
- Les dépendances entre jobs sont correctement définies.
- Les permissions requises sont en place.
