---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Apprenez à configurer GitLab Runner pour exécuter des jobs CI/CD dans Google Kubernetes Engine à l'aide de l'opérateur Kubernetes."
title: 'Tutoriel : configurer GitLab Runner pour utiliser Google Kubernetes Engine'
---

Ce tutoriel explique comment configurer GitLab Runner pour utiliser Google Kubernetes Engine (GKE) afin d'exécuter des jobs.

Dans ce tutoriel, vous configurez GitLab Runner pour exécuter des jobs en [mode cluster standard](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/configuration-overview).

Pour configurer GitLab Runner afin d'utiliser le GKE :

1. [Configurez votre environnement](#set-up-your-environment).
1. [Créez un cluster et connectez-vous à celui-ci](#create-and-connect-to-a-cluster).
1. [Installez et configurez l'opérateur Kubernetes](#install-and-configure-the-kubernetes-operator).
1. Facultatif. [Vérifiez que la configuration a réussi](#verify-your-configuration).

## Avant de commencer {#before-you-begin}

Avant de pouvoir configurer GitLab Runner pour utiliser le GKE, vous devez :

- Disposer d'un projet pour lequel vous avez le rôle Maintainer ou Owner. Si vous n'avez pas de projet, vous pouvez [en créer un](../../user/project/_index.md).
- [Obtenir le token d'authentification du runner de projet](../../ci/runners/runners_scope.md#create-a-project-runner-with-a-runner-authentication-token).
- Installer GitLab Runner.

## Configurer votre environnement {#set-up-your-environment}

Installez les outils nécessaires pour configurer et utiliser GitLab Runner dans le GKE.

1. [Installez et configurez Google Cloud CLI](https://cloud.google.com/sdk/docs/install). Vous utilisez Google Cloud CLI pour vous connecter au cluster.
1. [Installez et configurez kubectl](https://kubernetes.io/docs/tasks/tools/). Vous utilisez kubectl pour communiquer avec le cluster distant depuis votre environnement local.

## Créer un cluster et se connecter à celui-ci {#create-and-connect-to-a-cluster}

Cette étape explique comment créer un cluster et s'y connecter. Une fois connecté au cluster, vous utilisez kubectl pour interagir avec celui-ci.

1. Dans Google Cloud Platform, créez un cluster [standard](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster).
1. Installez le plugin d'authentification kubectl :

   ```shell
   gcloud components install gke-gcloud-auth-plugin
   ```

1. Connectez-vous au cluster :

   ```shell
   gcloud container clusters get-credentials CLUSTER_NAME --zone=CLUSTER_LOCATION
   ```

1. Affichez la configuration du cluster :

   ```shell
   kubectl config view
   ```

1. Vérifiez que vous êtes bien connecté au cluster :

   ```shell
   kubectl config current-context
   ```

## Installer et configurer l'opérateur Kubernetes {#install-and-configure-the-kubernetes-operator}

Maintenant que vous disposez d'un cluster, vous êtes prêt à installer et configurer l'opérateur Kubernetes.

1. Installez `cert-manager`. Ignorez cette étape si vous avez déjà un gestionnaire de certificats installé :

   ```shell
   kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml
   ```

1. Installez l'Operator Lifecycle Manager (OLM), un outil qui gère les opérateurs Kubernetes s'exécutant sur le cluster :

   ```shell
   curl --silent --location "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.24.0/install.sh" \
    | bash -s v0.24.0
   ```

1. Installez l'opérateur Kubernetes :

   ```shell
   kubectl create -f https://operatorhub.io/install/gitlab-runner-operator.yaml
   ```

1. Uniquement pour Operator Lifecycle Manager v0.25.0 et versions ultérieures. Ajoutez votre propre gestionnaire de certificats ou utilisez `cert-manager`.

   - Pour ajouter votre propre fournisseur de certificats :

     1. Dans le fichier `gitlab-runner-operator.yaml`, définissez l'espace de nommage du certificat et le nom du certificat dans le paramètre `env` :

        ```shell
        cat > gitlab-runner-operator.yaml << EOF
        apiVersion: operators.coreos.com/v1alpha1
        kind: Subscription
        metadata:
        name: gitlab-runner-operator
        namespace: gitlab-ns
        spec:
        channel: stable
        name: gitlab-runner-operator
        source: operatorhubio-catalog
        ca: webhook-server-cert
        sourceNamespace: olm
        config:
        env:
           - name: CERTIFICATE_NAMESPACE
             value: cert_namespace_desired_value
           - name: CERTIFICATE_NAME
           value: cert_name_desired_value
        EOF
        ```

     1. Appliquez le fichier `gitlab-runner-operator.yaml` au cluster Kubernetes :

        ```shell
        kubectl apply -f gitlab-runner-operator.yaml
        ```

   - Pour utiliser `cert-manager` :

     1. Utilisez le fichier `certificate-issuer-install.yaml` pour installer un `Certificate` et un `Issuer` dans l'espace de nommage par défaut, en plus de l'installation de l'opérateur :

        ```shell
        cat > certificate-issuer-install.yaml << EOF
        apiVersion: v1
        kind: Namespace
        metadata:
        labels:
           app.kubernetes.io/component: controller-manager
           app.kubernetes.io/managed-by: olm
           app.kubernetes.io/name: gitlab-runner-operator
        name: gitlab-runner-system
        ---
        apiVersion: cert-manager.io/v1
        kind: Certificate
        metadata:
        name: gitlab-runner-serving-cert
        namespace: gitlab-runner-system
        spec:
        dnsNames:
        - gitlab-runner-webhook-service.gitlab-runner-system.svc
        - gitlab-runner-webhook-service.gitlab-runner-system.svc.cluster.local
        issuerRef:
          kind: Issuer
          name: gitlab-runner-selfsigned-issuer
        secretName: webhook-server-cert
        ---
        apiVersion: cert-manager.io/v1
        kind: Issuer
        metadata:
        name: gitlab-runner-selfsigned-issuer
        namespace: gitlab-runner-system
        spec:
        selfSigned: {}
        EOF
        ```

     1. Appliquez le fichier `certificate-issuer-install.yaml` au cluster Kubernetes :

        ```shell
        kubectl create -f certificate-issuer-install.yaml
        ```

1. Créez un secret contenant le `runner-registration-token` de votre projet GitLab :

   ```shell
    cat > gitlab-runner-secret.yml << EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: gitlab-runner-secret
    type: Opaque
    stringData:
      runner-token: YOUR_RUNNER_AUTHENTICATION_TOKEN
    EOF
   ```

1. Appliquez le secret :

   ```shell
   kubectl apply -f gitlab-runner-secret.yml
   ```

1. Créez le fichier de définition de ressource personnalisée et incluez les informations suivantes :

   ```shell
    cat > gitlab-runner.yml << EOF
    apiVersion: apps.gitlab.com/v1beta2
    kind: Runner
    metadata:
      name: gitlab-runner
    spec:
      gitlabUrl: https://gitlab.example.com
      buildImage: alpine
      token: gitlab-runner-secret
    EOF
   ```

1. Appliquez le fichier de définition de ressource personnalisée :

   ```shell
   kubectl apply -f gitlab-runner.yml
   ```

C'est tout ! Vous avez configuré GitLab Runner pour utiliser le GKE. À l'étape suivante, vous pouvez vérifier si votre configuration fonctionne.

## Vérifier votre configuration {#verify-your-configuration}

Pour vérifier si les runners s'exécutent dans le cluster GKE, vous pouvez :

- Utiliser la commande suivante :

  ```shell
  kubectl get pods
  ```

  Vous devriez voir la sortie suivante. Cela indique que vos runners s'exécutent dans le cluster GKE :

  ```plaintext
  NAME                             READY   STATUS    RESTARTS   AGE
  gitlab-runner-hash-short_hash    1/1     Running   0          5m
  ```

- Consulter le job log dans GitLab :
  1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
  1. Sélectionnez **Version** > **Jobs** et trouvez le job.
  1. Pour consulter le job log, sélectionnez le statut du job.
