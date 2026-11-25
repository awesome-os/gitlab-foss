---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Créer un cluster Azure AKS
---

Vous pouvez créer un cluster sur Azure Kubernetes Service (AKS) via [Infrastructure as Code (IaC)](../../_index.md). Ce processus utilise les fournisseurs Terraform Azure et Kubernetes pour créer des clusters AKS. Vous connectez les clusters à GitLab en utilisant l'agent GitLab pour Kubernetes.

**Avant de commencer** :

- Un compte Microsoft Azure, avec un ensemble de [credentials de sécurité](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest) configurés.
- [Un runner](https://docs.gitlab.com/runner/install/) que vous pouvez utiliser pour exécuter le pipeline CI/CD GitLab.

**Étapes** :

1. [Importer l'exemple de projet](#import-the-example-project).
1. [Enregistrer l'agent pour Kubernetes](#register-the-agent).
1. [Configurer votre projet](#configure-your-project).
1. [Provisionner votre cluster](#provision-your-cluster).

## Importer l'exemple de projet {#import-the-example-project}

Pour créer un cluster depuis GitLab en utilisant Infrastructure as Code, vous devez créer un projet à partir duquel gérer le cluster. Dans ce tutoriel, vous commencez avec un exemple de projet et le modifiez selon vos besoins.

Commencez par [importer l'exemple de projet par URL](../../../import/third_party_systems/repo_by_url.md).

Pour importer le projet :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Importer un projet**.
1. Sélectionnez **Dépôt par URL**.
1. Dans le champ **URL du dépôt Git**, saisissez `https://gitlab.com/gitlab-org/ci-cd/deploy-stage/environments-group/examples/gitlab-terraform-aks.git`.
1. Remplissez les champs et sélectionnez **Créer le projet**.

Ce projet vous fournit :

- Un cluster [Azure Kubernetes Service (AKS)](https://gitlab.com/gitlab-org/ci-cd/deploy-stage/environments-group/examples/gitlab-terraform-aks/-/blob/main/aks.tf).
- L'[agent GitLab pour Kubernetes](https://gitlab.com/gitlab-org/ci-cd/deploy-stage/environments-group/examples/gitlab-terraform-aks/-/blob/main/agent.tf) installé dans le cluster.

## Enregistrer l'agent {#register-the-agent}

Pour créer un agent GitLab pour Kubernetes :

1. Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.
1. Sélectionnez **Connecter un cluster (agent)**.
1. Dans la liste déroulante **Sélectionner un agent**, sélectionnez `aks-agent` et sélectionnez **Enregistrer un agent**.
1. GitLab génère un jeton d'enregistrement pour l'agent. Stockez ce jeton secret en lieu sûr, car vous en aurez besoin ultérieurement.
1. GitLab fournit une adresse pour le serveur d'agent (KAS), dont vous aurez également besoin ultérieurement.

## Configurer votre projet {#configure-your-project}

Utilisez des variables d'environnement CI/CD pour configurer votre projet.

**Configuration requise** :

1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Développez **Variables**.
1. Définissez la variable `ARM_CLIENT_ID` sur votre identifiant client Azure.
1. Définissez la variable `ARM_CLIENT_SECRET` sur votre secret client Azure.
1. Définissez la variable `ARM_TENANT_ID` sur votre principal de service.
1. Définissez la variable `TF_VAR_agent_token` sur le jeton d'agent affiché dans la tâche précédente.
1. Définissez la variable `TF_VAR_kas_address` sur l'adresse du serveur d'agent affichée dans la tâche précédente.

**Configuration facultative** :

Le fichier [`variables.tf`](https://gitlab.com/gitlab-org/ci-cd/deploy-stage/environments-group/examples/gitlab-terraform-aks/-/blob/main/variables.tf) contient d'autres variables que vous pouvez remplacer selon vos besoins :

- `TF_VAR_location` : définissez la région de votre cluster.
- `TF_VAR_cluster_name` : définissez le nom de votre cluster.
- `TF_VAR_kubernetes_version` : définissez la version de Kubernetes.
- `TF_VAR_create_resource_group` : activez ou désactivez la création d'un nouveau groupe de ressources. (Valeur par défaut : true).
- `TF_VAR_resource_group_name` : définissez le nom du groupe de ressources.
- `TF_VAR_agent_namespace` : définissez l'espace de nommage Kubernetes pour l'agent GitLab pour Kubernetes.

Consultez la documentation du [fournisseur Terraform Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) et du [fournisseur Terraform Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs) pour d'autres options de ressources.

## Provisionner votre cluster {#provision-your-cluster}

Après avoir configuré votre projet, déclenchez manuellement le provisionnement de votre cluster. Dans GitLab :

1. Dans la barre latérale gauche, sélectionnez **Compilation** > **Pipelines**.
1. À côté de **Exécuter** ({{< icon name="play" >}}), sélectionnez l'icône de liste déroulante ({{< icon name="chevron-lg-down" >}}).
1. Sélectionnez **Déployer** pour déclencher manuellement le job de déploiement.

Lorsque le pipeline se termine avec succès, vous pouvez afficher le nouveau cluster :

- Dans Azure : depuis le [portail Azure](https://portal.azure.com/#home), sélectionnez **Services Kubernetes** > **Afficher**.
- Dans GitLab : Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.

## Utiliser votre cluster {#use-your-cluster}

Une fois le cluster provisionné, il est connecté à GitLab et prêt pour les déploiements. Pour vérifier la connexion :

1. Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.
1. Dans la liste, consultez la colonne **État de la connexion**.

Pour plus d'informations sur les fonctionnalités de la connexion, consultez [la documentation de l'agent GitLab pour Kubernetes](../_index.md).

## Supprimer le cluster {#remove-the-cluster}

Un job de nettoyage n'est pas inclus dans votre pipeline par défaut. Pour supprimer toutes les ressources créées, vous devez modifier votre modèle GitLab CI/CD avant d'exécuter le job de nettoyage.

Pour supprimer toutes les ressources :

1. Ajoutez ce qui suit à votre fichier `.gitlab-ci.yml` :

   ```yaml
   stages:
     - init
     - validate
     - test
     - build
     - deploy
     - cleanup

   destroy:
     extends: .terraform:destroy
     needs: []
   ```

1. Dans la barre latérale gauche, sélectionnez **Version** > **Pipelines** et sélectionnez le pipeline le plus récent.
1. Pour le job `destroy`, sélectionnez **Exécuter** ({{< icon name="play" >}}).
