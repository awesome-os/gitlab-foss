---
stage: Verify
group: Tutorials
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : configurer l''intégration Google Cloud'
---

<!-- vale gitlab_base.FutureTense = NO -->

Ce tutoriel vous montre comment intégrer Google Cloud à GitLab, afin que vous puissiez déployer directement vers Google Cloud.

Pour configurer l'intégration Google Cloud :

1. [Sécuriser votre utilisation avec Google Cloud Identity and Access Management (IAM)](#secure-your-usage-with-google-cloud-identity-and-access-management-iam)
1. [Se connecter à un dépôt Google Artifact Registry](#connect-to-a-google-artifact-registry-repository)
1. [Configurer GitLab Runner pour exécuter vos jobs CI/CD sur Google Cloud](#set-up-gitlab-runner-to-execute-your-cicd-jobs-on-google-cloud)
1. [Déployer vers Google Cloud avec des composants CI/CD](#deploy-to-google-cloud-with-cicd-components)

## Avant de commencer {#before-you-begin}

Pour configurer l'intégration, vous devez :

- Disposer d'un projet GitLab pour lequel vous avez le rôle Maintainer ou Owner.
- Disposer du rôle IAM [Owner](https://cloud.google.com/iam/docs/understanding-roles#owner) sur les projets Google Cloud que vous souhaitez utiliser.
- Avoir [la facturation activée pour votre projet Google Cloud](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#confirm_billing_is_enabled_on_a_project).
- Disposer d'un dépôt Google Artifact Registry avec le format Docker et le mode Standard.
- Installer la [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) et [Terraform](https://developer.hashicorp.com/terraform/install).

## Sécuriser votre utilisation avec Google Cloud Identity and Access Management (IAM) {#secure-your-usage-with-google-cloud-identity-and-access-management-iam}

Pour sécuriser votre utilisation de Google Cloud, vous devez configurer l'intégration Google Cloud IAM. Après cette étape, votre groupe ou projet GitLab est connecté à Google Cloud. Vous pouvez gérer les autorisations pour les ressources Google Cloud sans avoir besoin de clés de compte de service ni des risques associés, en utilisant la fédération d'identité de charge de travail.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre projet. Si vous configurez cela sur un groupe, les paramètres s'appliquent par défaut à tous les projets qu'il contient.
1. Sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Google Cloud IAM**.
1. Sélectionnez **Configuration guidée** et suivez les instructions.

## Se connecter à un dépôt Google Artifact Registry {#connect-to-a-google-artifact-registry-repository}

Maintenant que l'intégration Google IAM est configurée, vous pouvez vous connecter à un dépôt Google Artifact Registry. Après cette étape, vous pouvez consulter vos artefacts Google Cloud dans GitLab.

1. Dans votre projet GitLab, dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Registre d'artefacts Google**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Remplissez les champs :
   - **[ID du projet Google Cloud](https://cloud.google.com/resource-manager/docs/creating-managing-projects#identifying_projects)** : L'ID du projet Google Cloud dans lequel se trouve votre dépôt Artifact Registry.
   - **Nom du dépôt** : le nom de votre dépôt Artifact Registry.
   - **Emplacement du dépôt** : l'emplacement de votre dépôt Artifact Registry.
1. Dans **Configurer les politiques IAM Google Cloud**, suivez les instructions affichées à l'écran pour configurer les politiques IAM dans Google Cloud. Ces politiques sont requises pour utiliser le dépôt Artifact Registry dans votre projet GitLab.
1. Sélectionnez **Enregistrer les modifications**.
1. Pour consulter vos artefacts Google Cloud, dans la barre latérale gauche, sélectionnez **Déployer** > **Registre d'artefacts Google**.

Dans une étape ultérieure, vous enverrez vos images de conteneur vers Google Artifact Registry.

## Configurer GitLab Runner pour exécuter vos jobs CI/CD sur Google Cloud {#set-up-gitlab-runner-to-execute-your-cicd-jobs-on-google-cloud}

Vous pouvez configurer GitLab Runner pour exécuter des jobs CI/CD sur Google Cloud. Après cette étape, votre projet GitLab dispose d'une flotte de runners à mise à l'échelle automatique, avec un gestionnaire de runners qui crée des runners temporaires pour exécuter plusieurs jobs simultanément.

1. Dans votre projet GitLab, dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Développez la section **Runners**.
1. Sélectionnez **Nouveau runner de projet**.
1. Remplissez les champs.
   - Dans la section **Plateforme**, sélectionnez **Google Cloud**.
   - Dans la section **Étiquettes**, dans le champ **Étiquettes**, saisissez les étiquettes de job pour spécifier les jobs que le runner peut exécuter. S'il n'y a pas d'étiquettes de job pour ce runner, sélectionnez **Exécuter sans étiquette**.
   - Facultatif. Dans le champ **Description du runner**, ajoutez une description pour le runner qui s'affiche dans GitLab.
   - Facultatif. Dans la section **Configuration**, ajoutez des configurations supplémentaires.
1. Sélectionnez **Créer un runner**.
1. Renseignez les champs de la section **Étape 1 : spécifier l'environnement** pour définir l'environnement dans Google Cloud où les runners exécutent les jobs CI/CD.
1. Sous **Étape 2 : configurer GitLab Runner**, sélectionnez **Instructions de configuration**.
1. Suivez les instructions dans la fenêtre modale. Vous ne devez effectuer l'**Étape 1** qu'une seule fois pour le projet Google Cloud, afin qu'il soit prêt à provisionner les runners.

Après avoir suivi les instructions, il peut s'écouler une minute avant que votre runner soit en ligne et prêt à exécuter des jobs.

## Déployer vers Google Cloud avec des composants CI/CD {#deploy-to-google-cloud-with-cicd-components}

Une bonne pratique de développement consiste à réutiliser la syntaxe, comme les composants CI/CD, pour assurer la cohérence de vos pipelines.

Vous pouvez utiliser la bibliothèque de composants de GitLab et de Google pour permettre à votre projet GitLab d'interagir avec les ressources Google Cloud. Consultez les [composants CI/CD de Google](https://gitlab.com/google-gitlab-components).

### Copier des images de conteneur vers Google Artifact Registry {#copy-container-images-to-google-artifact-registry}

Avant de commencer, vous devez disposer d'une configuration CI/CD fonctionnelle qui génère et envoie des images de conteneur vers votre registre de conteneurs GitLab.

Pour copier des images de conteneur depuis votre registre de conteneurs GitLab vers votre Google Artifact Registry, incluez le [composant CI/CD de Google](https://gitlab.com/explore/catalog/google-gitlab-components/artifact-registry) dans votre pipeline. Après cette étape, chaque fois qu'une nouvelle image de conteneur est envoyée vers votre registre de conteneurs GitLab, elle est également envoyée vers votre Google Artifact Registry.

1. Dans votre projet GitLab, dans la barre latérale gauche, sélectionnez **Version** > **Éditeur de pipeline**.
1. Dans la configuration existante, ajoutez le composant comme suit.
   - Remplacez `<your_stage>` par l'étape dans laquelle ce job s'exécute. Elle doit être placée après la génération et l'envoi de l'image vers le registre de conteneurs GitLab.

   ```yaml
   include:
     - component: gitlab.com/google-gitlab-components/artifact-registry/upload-artifact-registry@main
       inputs:
         stage: <your_stage>
         source: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
         target: $GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_LOCATION-docker.pkg.dev/$GOOGLE_ARTIFACT_REGISTRY_PROJECT_ID/$GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_NAME/$CI_PROJECT_NAME:$CI_COMMIT_SHORT_SHA
   ```

1. Ajoutez un message de commit descriptif. **Branche cible** doit être votre branche par défaut.
1. Sélectionnez **Valider les modifications**.
1. Accédez à **Version** > **Pipelines** et vérifiez qu'un nouveau pipeline s'exécute.
1. Une fois le pipeline terminé avec succès, pour consulter l'image de conteneur qui a été copiée vers Google Artifact Registry, dans la barre latérale gauche, sélectionnez **Déployer** > **Registre d'artefacts Google**.

### Créer une release Google Cloud Deploy {#create-a-google-cloud-deploy-release}

Pour intégrer votre pipeline à Google Cloud Deploy, incluez le [composant CI/CD de Google](https://gitlab.com/explore/catalog/google-gitlab-components/cloud-deploy) dans votre pipeline. Après cette étape, votre pipeline crée une release Google Cloud Deploy avec votre application.

1. Dans votre projet GitLab, dans la barre latérale gauche, sélectionnez **Version** > **Éditeur de pipeline**.
1. Dans la configuration existante, ajoutez le [composant Google Cloud Deploy](https://gitlab.com/explore/catalog/google-gitlab-components/cloud-deploy).
1. Modifiez le `inputs` du composant.
1. Ajoutez un message de commit descriptif. **Branche cible** doit être votre branche par défaut.
1. Sélectionnez **Valider les modifications**.
1. Accédez à **Version** > **Pipelines** et vérifiez qu'un nouveau pipeline réussit.
1. Une fois le pipeline terminé avec succès, pour consulter la release, reportez-vous à la [documentation Google Cloud](https://docs.cloud.google.com/deploy/docs/view-release).

Et voilà ! Vous avez maintenant intégré Google Cloud à GitLab, et votre projet GitLab se déploie de façon transparente vers Google Cloud.

## Sujets connexes {#related-topics}

- [Intégration Google Cloud IAM](../../integration/google_cloud_iam.md)
- [Intégration Google Artifact Management](../../user/project/integrations/google_artifact_management.md)
- [Provisionnement des runners dans Google Cloud](../../ci/runners/provision_runners_google_cloud.md)
