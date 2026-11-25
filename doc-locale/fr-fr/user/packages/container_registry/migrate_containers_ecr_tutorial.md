---
stage: Package
group: Container Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : migrer des images de conteneurs d''Amazon ECR vers GitLab'
description: "Tutoriel pour automatiser la migration en masse d'images de conteneurs dans GitLab depuis Amazon Elastic Container Registry."
---

La migration d'images de conteneurs entre registres peut être fastidieuse lorsqu'elle est effectuée manuellement. Ce tutoriel décrit comment configurer un pipeline CI/CD pour automatiser la migration en masse d'images de conteneurs depuis Amazon Elastic Container Registry (ECR) vers le registre de conteneurs GitLab.

Pour migrer des images de conteneurs depuis ECR :

1. [Configurer les permissions AWS](#configure-aws-permissions)
1. [Ajouter les informations d'identification AWS en tant que variables dans l'interface](#add-aws-credentials-as-variables-in-the-ui)
1. [Créer le pipeline de migration](#create-the-migration-pipeline)
1. [Exécuter et vérifier la migration](#run-and-verify-the-migration)

Une fois toutes les étapes effectuées, votre `.gitlab-ci.yml` devrait ressembler à la [configuration exemple](#example-gitlab-ciyml-configuration) fournie à la fin de ce tutoriel.

## Avant de commencer {#before-you-begin}

Vous devez disposer de :

- Le rôle Maintainer ou Owner dans votre projet GitLab
- L'accès à votre compte AWS avec les permissions nécessaires pour créer des utilisateurs IAM
- Votre identifiant de compte AWS
- Votre région AWS où se trouvent les dépôts ECR
- Un espace de stockage suffisant dans votre registre de conteneurs GitLab

## Configurer les permissions AWS {#configure-aws-permissions}

Dans AWS IAM, créez une nouvelle politique et un utilisateur avec un accès en lecture seule à ECR :

1. Dans la console de gestion AWS, accédez à IAM.
1. Créez une nouvelle politique :

   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "ecr:GetAuthorizationToken",
                   "ecr:BatchCheckLayerAvailability",
                   "ecr:GetDownloadUrlForLayer",
                   "ecr:DescribeRepositories",
                   "ecr:ListImages",
                   "ecr:DescribeImages",
                   "ecr:BatchGetImage"
               ],
               "Resource": "*"
           }
       ]
   }
   ```

1. Créez un nouvel utilisateur IAM et associez-lui la politique.
1. Générez et enregistrez les clés d'accès pour l'utilisateur IAM.

## Ajouter les informations d'identification AWS en tant que variables dans l'interface {#add-aws-credentials-as-variables-in-the-ui}

Configurez les informations d'identification AWS requises en tant que variables dans votre projet GitLab :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Développez **Variables**.
1. Sélectionnez **Ajouter une variable** et ajoutez :
   - `AWS_ACCOUNT_ID` : votre numéro de compte AWS.
   - `AWS_DEFAULT_REGION` : votre région ECR. Par exemple, `us-east-1`.
   - `AWS_ACCESS_KEY_ID` : l'identifiant de clé d'accès de votre utilisateur IAM.
     - Sélectionnez **Masquer la variable**.
   - `AWS_SECRET_ACCESS_KEY` : la clé d'accès secrète de votre utilisateur IAM.
     - Sélectionnez **Masquer la variable**.

## Créer le pipeline de migration {#create-the-migration-pipeline}

Créez un nouveau fichier `.gitlab-ci.yml` dans votre dépôt avec les configurations suivantes :

### Définir l'image et le service {#set-image-and-service}

Utilisez Docker-in-Docker pour gérer les opérations sur les conteneurs :

```yaml
image: docker:20.10
services:
  - docker:20.10-dind
```

### Définir les variables du pipeline {#define-pipeline-variables}

Configurez les variables requises pour le pipeline :

```yaml
variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""
  BULK_MIGRATE: "true"
```

### Configurer le job de migration {#configure-the-migration-job}

Créez le job de migration qui gère le transfert :

```yaml
migration:
  stage: deploy
  script:
    # Install required tools
    - apk add --no-cache aws-cli jq

    # Verify AWS credentials
    - aws sts get-caller-identity

    # Log in to registries
    - aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
    - docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

    # Get list of ECR repositories
    - REPOS=$(aws ecr describe-repositories --query 'repositories[*].repositoryName' --output text)

    # Process each repository
    - |
      for repo in $REPOS; do
        echo "Processing repository: $repo"

        # Get all tags for this repository
        TAGS=$(aws ecr describe-images --repository-name $repo --query 'imageDetails[*].imageTags[]' --output text)

        # Process each tag
        for tag in $TAGS; do
          echo "Processing tag: $tag"

          # Pull image from ECR
          docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${repo}:${tag}

          # Tag for GitLab registry
          docker tag ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${repo}:${tag} ${CI_REGISTRY_IMAGE}/${repo}:${tag}

          # Push to GitLab
          docker push ${CI_REGISTRY_IMAGE}/${repo}:${tag}
        done
      done
```

## Exécuter et vérifier la migration {#run-and-verify-the-migration}

Après avoir configuré le pipeline :

1. Effectuez un commit et un push du fichier `.gitlab-ci.yml` vers votre dépôt.
1. Accédez à **CI/CD** > **Pipelines** pour surveiller la progression de la migration.
1. Une fois la migration terminée, vérifiez-la :
   - Accédez à **Paquets et registres** > **Registre de conteneurs**.
   - Vérifiez que tous les dépôts et tags sont présents.
   - Testez le pull de certaines images migrées.

## Exemple de configuration `.gitlab-ci.yml` {#example-gitlab-ciyml-configuration}

Lorsque vous avez suivi toutes les étapes précédentes, le fichier `.gitlab-ci.yml` devrait ressembler à ceci :

```yaml
image: docker:20.10
services:
  - docker:20.10-dind

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""
  BULK_MIGRATE: "true"

migration:
  stage: deploy
  script:
    # Install required tools
    - apk add --no-cache aws-cli jq

    # Verify AWS credentials
    - aws sts get-caller-identity

    # Log in to registries
    - aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
    - docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

    # Get list of ECR repositories
    - REPOS=$(aws ecr describe-repositories --query 'repositories[*].repositoryName' --output text)

    # Process each repository
    - |
      for repo in $REPOS; do
        echo "Processing repository: $repo"

        # Get all tags for this repository
        TAGS=$(aws ecr describe-images --repository-name $repo --query 'imageDetails[*].imageTags[]' --output text)

        # Process each tag
        for tag in $TAGS; do
          echo "Processing tag: $tag"

          # Pull image from ECR
          docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${repo}:${tag}

          # Tag for GitLab registry
          docker tag ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${repo}:${tag} ${CI_REGISTRY_IMAGE}/${repo}:${tag}

          # Push to GitLab
          docker push ${CI_REGISTRY_IMAGE}/${repo}:${tag}
        done
      done
  rules:
    - if: $BULK_MIGRATE == "true"
```
