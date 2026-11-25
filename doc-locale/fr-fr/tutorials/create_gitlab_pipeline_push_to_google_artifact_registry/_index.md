---
stage: Verify
group: tutorials
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : créer un pipeline GitLab pour pousser vers Google Artifact Registry'
---

Découvrez comment connecter GitLab à Google Cloud et créer un pipeline GitLab à l'aide de runners sur Compute Engine pour pousser des images vers Artifact Registry.

## Avant de commencer {#before-you-begin}

1. Pour exécuter les commandes de cette page, configurez la CLI `gcloud` dans l'un des environnements de développement suivants :

   - [Cloud Shell](https://cloud.google.com/shell/docs/using-cloud-shell)
   - [Shell local](https://cloud.google.com/sdk/docs/install)

1. Créez ou sélectionnez un projet Google Cloud.

   > [!note]
   > Si vous ne prévoyez pas de conserver les ressources que vous créez dans cette procédure, créez un nouveau projet Google Cloud plutôt que de sélectionner un projet existant. Une fois ces étapes terminées, vous pourrez supprimer le projet, ce qui supprimera toutes les ressources qui lui sont associées.

   Pour créer un projet Google Cloud, exécutez la commande suivante :

   ```shell
   gcloud projects create PROJECT_ID
   ```

   Remplacez `PROJECT_ID` par un nom pour le projet Google Cloud que vous créez.
1. Sélectionnez le projet Google Cloud que vous avez créé :

   ```shell
   gcloud config set project PROJECT_ID
   ```

   Remplacez `PROJECT_ID` par le nom de votre projet Google Cloud.
1. [Assurez-vous que la facturation est activée pour votre projet Google Cloud](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#console).
1. Activez les API Compute Engine et Artifact Registry :

   ```shell
   gcloud services enable compute.googleapis.com artifactregistry.googleapis.com
   ```

1. Configurez l'intégration GitLab sur Google Cloud en suivant les instructions dans [Google Cloud Workload Identity Federation et les politiques IAM](../../integration/google_cloud_iam.md).
1. [Créez un dépôt Artifact Registry au format Docker en mode standard](https://cloud.google.com/artifact-registry/docs/repositories/create-repos#create).
1. Connectez votre dépôt Artifact Registry à votre projet GitLab en suivant les instructions dans [Configurer Google Artifact Registry dans un projet GitLab](../../user/project/integrations/google_artifact_management.md).

## Cloner votre dépôt GitLab {#clone-your-gitlab-repository}

1. Pour cloner votre dépôt GitLab dans votre environnement de travail via SSH ou HTTPS, suivez les instructions dans [Cloner un dépôt Git sur votre ordinateur local](../../topics/git/clone.md).
1. Si vous travaillez dans votre shell local, [installez Terraform](https://developer.hashicorp.com/terraform/install?product_intent=terraform). Terraform est déjà installé dans Cloud Shell.

## Créer un Dockerfile {#create-a-dockerfile}

1. Dans votre dépôt cloné, créez un nouveau fichier nommé `Dockerfile`.
1. Copiez et collez le contenu suivant dans votre `Dockerfile`.

   ```dockerfile
   # Dockerfile for test purposes. Generates a new random image in every build.
   FROM alpine:3.15.11
   RUN dd if=/dev/urandom of=random bs=10 count=1
   ```

1. Ajoutez votre `Dockerfile` à Git, faites un commit et poussez-le vers votre dépôt GitLab.

   ```shell
   git add Dockerfile
   git commit -m "add dockerfile"
   git push
   ```

   Vous êtes invité à saisir votre nom d'utilisateur et votre [jeton d'accès personnel](../../user/profile/personal_access_tokens.md).

Le Dockerfile génère une nouvelle image aléatoire à chaque build et est uniquement destiné à des fins de test.

## Activer les runners d'intégration continue (CI) sur Google Compute Engine {#enable-continuous-integration-ci-runners-on-google-compute-engine}

[GitLab Runner](https://docs.gitlab.com/runner/) est une application qui fonctionne avec GitLab CI/CD pour exécuter des jobs dans un pipeline. L'intégration GitLab sur Google Cloud vous aide à configurer une flotte de runners à mise à l'échelle automatique sur Compute Engine, avec un gestionnaire de runners qui crée des runners temporaires pour exécuter plusieurs jobs simultanément.

Pour configurer votre flotte de runners à mise à l'échelle automatique, suivez les instructions dans [Configurer GitLab Runner pour exécuter vos jobs CI/CD sur Google Cloud](../set_up_gitlab_google_integration/_index.md#set-up-gitlab-runner-to-execute-your-cicd-jobs-on-google-cloud). Sélectionnez Google Cloud comme environnement dans lequel vous souhaitez que vos runners exécutent vos jobs CI/CD, puis renseignez les autres détails de configuration.

Une fois les détails de vos runners renseignés, vous pouvez suivre les instructions de configuration pour configurer votre projet Google Cloud, installer et enregistrer GitLab Runner, et appliquer le terraform fourni dans votre environnement de travail afin d'appliquer la configuration.

## Créer un pipeline {#create-a-pipeline}

Créez un pipeline qui construit votre image Docker, la pousse vers le registre de conteneurs GitLab et copie l'image vers Google Artifact Registry.

1. Dans votre projet GitLab, créez un [fichier `.gitlab-ci.yml`](../../ci/quick_start/_index.md#create-a-gitlab-ciyml-file).
1. Pour créer un pipeline qui construit votre image, la pousse vers le registre de conteneurs GitLab et la copie vers Google Artifact Registry, modifiez le contenu de votre fichier `.gitlab-ci.yml` comme suit.

   Dans l'exemple, remplacez les éléments suivants :

   - `LOCATION` : la région Google Cloud dans laquelle vous avez créé votre dépôt Google Artifact Registry.
   - `PROJECT` : l'identifiant de votre projet Google Cloud.
   - `REPOSITORY` : l'identifiant du dépôt de votre dépôt Google Artifact Registry.

   ```yaml
   stages:
     - build
     - deploy

   variables:
     GITLAB_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

   build-sample-image:
     image: docker:24.0.5-cli
     stage: build
     services:
       - docker:24.0.5-dind
     before_script:
       - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
     script:
       - docker build -t $GITLAB_IMAGE .
       - docker push $GITLAB_IMAGE

   include:
     - component: gitlab.com/google-gitlab-components/artifact-registry/upload-artifact-registry@0.1.0
       inputs:
         stage: deploy
         source: $GITLAB_IMAGE
         target: LOCATION-docker.pkg.dev/PROJECT/REPOSITORY/image:v1.0.0
   ```

Le pipeline utilise Docker dans Docker pour construire l'image `docker:24.0.5`, la stocke dans le registre de conteneurs GitLab, puis utilise le [composant GitLab Google Artifact Registry](https://gitlab.com/explore/catalog/google-gitlab-components/artifact-registry) pour la pousser vers votre dépôt Google Artifact Registry avec la version `v1.0.0`.

## Afficher vos artefacts {#view-your-artifacts}

Pour afficher votre artefact dans GitLab :

1. Dans votre projet GitLab, dans la barre latérale gauche, sélectionnez **Version** > **Artéfacts**.
1. Sélectionnez le nom de l'artefact pour afficher les détails du build.

Pour afficher votre artefact dans Google Artifact Registry :

1. [Ouvrez la page **Dépôts** dans la console Google Cloud](https://console.cloud.google.com/artifacts).
1. Sélectionnez le nom de votre dépôt lié.
1. Sélectionnez le nom de l'image pour afficher le nom de version et les tags.
1. Sélectionnez le nom de la version de l'image pour afficher les informations de build, de pull et de manifeste de la version.

## Nettoyage {#clean-up}

Pour éviter que des frais soient facturés sur votre compte Google Cloud pour les ressources utilisées sur cette page, vous pouvez supprimer votre projet Google Cloud. Si vous souhaitez conserver votre projet, vous pouvez supprimer votre dépôt Google Artifact Registry.

Pour obtenir des informations sur la tarification de GitLab et de Google Artifact Registry ainsi que sur la gestion de projet, consultez les ressources suivantes :

- [Tarification GitLab](https://about.gitlab.com/free-trial/devsecops)
- [Supprimer un projet GitLab](../../user/project/working_with_projects.md#delete-a-project)
- [Tarification de Google Artifact Registry](https://cloud.google.com/artifact-registry/pricing)

### Supprimer votre dépôt Google Artifact Registry {#delete-your-google-artifact-registry-repository}

Si vous souhaitez conserver votre projet Google Cloud et uniquement supprimer la ressource de dépôt Google Artifact Registry, suivez les étapes de cette section. Si vous souhaitez supprimer l'intégralité de votre projet Google Cloud, suivez les étapes dans [Supprimer votre projet](#delete-your-google-cloud-project).

Avant de supprimer le dépôt, assurez-vous que les images que vous souhaitez conserver sont disponibles dans un autre emplacement.

Pour supprimer votre dépôt, exécutez la commande suivante :

```shell
gcloud artifacts repositories delete REPOSITORY \
    --location=LOCATION
```

Remplacez les éléments suivants :

- `REPOSITORY` par l'identifiant de votre dépôt Google Artifact Registry
- `LOCATION` par l'emplacement de votre dépôt

### Supprimer votre projet Google Cloud {#delete-your-google-cloud-project}

**Attention** : la suppression d'un projet a les effets suivants :

- Tout le contenu du projet est supprimé. Si vous avez utilisé un projet existant pour les tâches de ce document, sa suppression entraîne également la suppression de tout autre travail effectué dans ce projet.
- Les identifiants de projet personnalisés sont perdus. Lors de la création de ce projet, vous avez peut-être créé un identifiant de projet personnalisé que vous souhaitez réutiliser à l'avenir. Pour conserver les URL qui utilisent l'identifiant du projet, comme une URL appspot.com, supprimez les ressources sélectionnées dans le projet plutôt que de supprimer l'intégralité du projet.

Si vous prévoyez d'explorer plusieurs architectures, tutoriels ou tutoriels de démarrage rapide sur Google Cloud, la réutilisation des projets peut vous aider à éviter de dépasser les limites de quota de projet.

1. Dans la console Google Cloud, accédez à la [page **Gérer les ressources**](https://console.cloud.google.com/iam-admin/projects).
1. Dans la liste des projets, sélectionnez le projet que vous souhaitez supprimer, puis sélectionnez **Supprimer**.
1. Dans la boîte de dialogue, saisissez l'identifiant du projet, puis sélectionnez **Arrêter** pour supprimer le projet.

## Sujets connexes {#related-topics}

- Découvrez comment [optimiser les fichiers de configuration GitLab CI/CD](../../ci/yaml/yaml_optimization.md).
- Découvrez comment l'intégration GitLab sur Google Cloud utilise IAM avec la fédération d'identité de charge de travail pour contrôler l'accès à Google Cloud dans [Contrôle d'accès avec IAM](https://cloud.google.com/docs/gitlab).
