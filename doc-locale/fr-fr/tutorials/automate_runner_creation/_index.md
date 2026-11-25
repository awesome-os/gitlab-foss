---
stage: Tutorials
group: Tutorials
info: For assistance with this tutorial, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments-to-other-projects-and-subjects>.
title: 'Tutoriel : automatiser la création et l''enregistrement des runners'
---

Ce tutoriel décrit comment automatiser la création et l'enregistrement de runners.

Pour automatiser la création et l'enregistrement de runners :

1. [Créer un jeton d'accès personnel](#create-a-personal-access-token).
1. [Créer une configuration de runner](#create-a-runner-configuration).
1. [Automatiser l'installation et l'enregistrement de GitLab Runner](#automate-runner-installation-and-registration).
1. [Afficher les runners avec la même configuration](#view-runners-with-the-same-configuration).

> [!note]
> Les instructions de ce tutoriel décrivent la création et l'enregistrement de runners avec des jetons d'authentification de runner, qui ont remplacé la méthode d'enregistrement obsolète utilisant des jetons d'enregistrement. Pour plus d'informations, consultez [Le nouveau workflow d'enregistrement de runner](../../ci/runners/new_creation_workflow.md#the-new-runner-registration-workflow).

## Avant de commencer {#before-you-begin}

- GitLab Runner doit être installé sur votre instance GitLab.
- Pour créer des runners d'instance, vous devez être administrateur.
- Pour créer des runners de groupe, vous devez être administrateur ou disposer du rôle Propriétaire pour le groupe.
- Pour créer des runners de projet, vous devez être administrateur ou disposer du rôle Chargé de maintenance pour le projet.

## Créer un jeton d'accès {#create-an-access-token}

Créez un jeton d'accès pour pouvoir utiliser l'API REST afin de créer des runners.

Vous pouvez créer :

- Un jeton d'accès personnel à utiliser avec les runners partagés, de groupe et de projet.
- Un jeton d'accès de groupe ou de projet à utiliser avec les runners de groupe et de projet.

Le jeton d'accès n'est visible qu'une seule fois dans l'interface GitLab. Lorsque vous quittez la page, vous n'avez plus accès au jeton. Nous vous recommandons d'utiliser une solution de gestion des secrets pour stocker le jeton, comme HashiCorp Vault ou le plugin Terraform Keeper Secrets Manager.

### Créer un jeton d'accès personnel {#create-a-personal-access-token}

{{< history >}}

- [Augmentation](https://gitlab.com/gitlab-org/gitlab/-/issues/461901) de la limite de durée de vie maximale autorisée à 400 jours dans GitLab 17.6 [avec le feature flag](../../administration/feature_flags/_index.md) `buffered_token_expiration_limit`. Fonctionnalité désactivée par défaut.

{{< /history >}}

> [!flag]
> Un feature flag contrôle la disponibilité de l'extension de la limite de durée de vie maximale autorisée. Pour plus d'informations, consultez l'historique.

1. Dans le coin supérieur droit, sélectionnez votre avatar.
1. Sélectionnez **Modifier le profil**.
1. Dans la barre latérale gauche, sélectionnez **Accès** > **Jetons d'accès personnel**.
1. Sélectionnez **Ajouter un jeton**.
1. Saisissez un nom et une date d'expiration pour le jeton.
   - Le jeton expire à cette date à minuit UTC. Un jeton avec la date d'expiration 2024-01-01 expire à 00:00:00 UTC le 2024-01-01.
   - Si vous ne saisissez pas de date d'expiration, la date d'expiration est automatiquement définie à 365 jours après la date actuelle.
   - Par défaut, cette date peut être au maximum 365 jours après la date actuelle. Dans GitLab 17.6 ou une version ultérieure, vous pouvez [étendre cette limite à 400 jours](https://gitlab.com/gitlab-org/gitlab/-/issues/461901).
1. Dans la section **Sélectionner les portées**, cochez la case **create_runner**.
1. Sélectionnez **Créer un jeton d'accès personnel**.

### Créer un jeton d'accès de projet ou de groupe {#create-a-project-or-group-access-token}

{{< history >}}

- [Augmentation](https://gitlab.com/gitlab-org/gitlab/-/issues/461901) de la limite de durée de vie maximale autorisée à 400 jours dans GitLab 17.6 [avec le feature flag](../../administration/feature_flags/_index.md) `buffered_token_expiration_limit`. Fonctionnalité désactivée par défaut.

{{< /history >}}

> [!flag]
> Un feature flag contrôle la disponibilité de l'extension de la limite de durée de vie maximale autorisée. Pour plus d'informations, consultez l'historique.

Un jeton d'accès au projet donne accès à un seul projet, tandis qu'un jeton d'accès de groupe donne accès à tous les projets du groupe.

> [!warning]
> Les jetons d'accès au projet sont traités comme des [utilisateurs internes](../../administration/internal_users.md). Si un utilisateur interne crée un jeton d'accès au projet, ce jeton peut accéder à tous les projets dont le niveau de visibilité est défini sur [Interne](../../user/public_access.md).

Pour créer un jeton d'accès au projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Jetons d'accès**.
1. Sélectionnez **Ajouter un jeton**
1. Saisissez un nom. Le nom du jeton est visible par tout utilisateur disposant des autorisations nécessaires pour afficher le groupe ou le projet.
1. Saisissez une date d'expiration pour le jeton.
   - Le jeton expire à cette date à minuit UTC. Un jeton avec la date d'expiration 2024-01-01 expire à 00:00:00 UTC le 2024-01-01.
   - Si vous ne saisissez pas de date d'expiration, la date d'expiration est automatiquement définie à 365 jours après la date actuelle.
   - Par défaut, cette date peut être au maximum 365 jours après la date actuelle. Dans GitLab 17.6 ou une version ultérieure, vous pouvez [étendre cette limite à 400 jours](https://gitlab.com/gitlab-org/gitlab/-/issues/461901).
   - Un paramètre de [durée de vie maximale](../../administration/settings/account_and_limit_settings.md#limit-the-lifetime-of-access-tokens) à l'échelle de l'instance peut limiter la durée de vie maximale autorisée sur les instances GitLab Self-Managed.
1. Dans la liste déroulante **Sélectionner un rôle** :
   - Pour le jeton d'accès au projet, sélectionnez **Chargé de maintenance**.
   - Pour le jeton d'accès de groupe, sélectionnez **Propriétaire**.
1. Dans la section **Sélectionner les portées**, cochez la case **create_runner**.
1. Sélectionnez **Créer un jeton d'accès au projet**.

## Créer une configuration de runner {#create-a-runner-configuration}

Une configuration de runner est l'endroit où vous configurez les runners selon vos besoins.

Après avoir créé une configuration de runner, vous recevez une authentification de runner pour enregistrer le runner. Un ou plusieurs runners peuvent être associés à la même configuration lorsque ces runners sont enregistrés avec le même jeton d'authentification de runner. La configuration du runner est stockée dans le fichier `config.toml`.

Pour créer une configuration de runner, vous pouvez utiliser :

- L'API REST GitLab.
- La ressource Terraform `gitlab_user_runner`.

### Avec l'API REST GitLab {#with-the-gitlab-rest-api}

Avant de commencer, vous avez besoin de :

- L'URL de votre instance GitLab. Par exemple, si votre projet est hébergé sur `gitlab.example.com/yourname/yourproject`, l'URL de votre instance GitLab est `https://gitlab.example.com`.
- Pour les runners de groupe ou de projet, le numéro d'identifiant du groupe ou du projet. Le numéro d'identifiant est affiché dans la page de présentation du projet ou du groupe, sous le nom du projet ou du groupe.

Utilisez le jeton d'accès dans le point de terminaison REST [`POST /user/runners`](../../api/users.md#create-a-runner-linked-to-a-user) pour créer un runner :

1. Utilisez `curl` pour appeler le point de terminaison afin de créer un runner :

   {{< tabs >}}

   {{< tab title="Projet" >}}

   ```shell
   curl --silent --request POST --url "https://gitlab.example.com/api/v4/user/runners"
     --data "runner_type=project_type"
     --data "project_id=<project_id>"
     --data "description=<your_runner_description>"
     --data "tag_list=<your_comma_separated_job_tags>"
     --header "PRIVATE-TOKEN: <project_access_token>"
   ```

   {{< /tab >}}

   {{< tab title="Groupe" >}}

   ```shell
   curl --silent --request POST --url "https://gitlab.example.com/api/v4/user/runners"
     --data "runner_type=group_type"
     --data "group_id=<group_id>"
     --data "description=<your_runner_description>"
     --data "tag_list=<your_comma_separated_job_tags>"
     --header "PRIVATE-TOKEN: <group_access_token>"
   ```

   {{< /tab >}}

   {{< tab title="Partagé" >}}

   ```shell
   curl --silent --request POST --url "https://gitlab.example.com/api/v4/user/runners"
     --data "runner_type=instance_type"
     --data "description=<your_runner_description>"
     --data "tag_list=<your_comma_separated_job_tags>"
     --header "PRIVATE-TOKEN: <personal_access_token>"
   ```

   {{< /tab >}}

   {{< /tabs >}}
1. Enregistrez la valeur `token` retournée dans un emplacement sécurisé ou dans votre solution de gestion des secrets. La valeur `token` n'est retournée qu'une seule fois dans la réponse de l'API.

### Avec la ressource Terraform `gitlab_user_runner` {#with-the-gitlab_user_runner-terraform-resource}

Pour créer la configuration du runner avec Terraform, utilisez la [ressource Terraform `gitlab_user_runner`](https://gitlab.com/gitlab-org/terraform-provider-gitlab/-/blob/main/docs/resources/user_runner.md?ref_type=heads) du [fournisseur Terraform GitLab](https://gitlab.com/gitlab-org/terraform-provider-gitlab).

Voici un exemple de bloc de configuration :

```terraform
resource "gitlab_user_runner" "example_runner" {
  runner_type = "instance_type"
  description = "my-runner"
  tag_list = ["shell", "docker"]
}
```

## Automatiser l'installation et l'enregistrement de runners {#automate-runner-installation-and-registration}

Si vous hébergez le runner sur une instance de machine virtuelle dans un cloud public, vous pouvez automatiser l'installation et l'enregistrement du runner.

Après avoir créé un runner et sa configuration, vous pouvez utiliser le même jeton d'authentification de runner pour enregistrer plusieurs runners avec la même configuration. Par exemple, vous pouvez déployer plusieurs runners d'instance avec le même type d'exécuteur et les mêmes tags de job vers l'hôte de calcul cible. Chaque runner enregistré avec le même jeton d'authentification de runner possède un `system_id` unique, que GitLab Runner génère aléatoirement et stocke dans votre système de fichiers local.

Voici un exemple de workflow d'automatisation que vous pouvez utiliser pour enregistrer et déployer vos runners vers Google Compute Engine :

1. Utilisez [l'Infrastructure as Code Terraform](../../user/infrastructure/iac/_index.md) pour installer l'application runner sur une machine virtuelle hébergée sur Google Cloud Platform (GCP).
1. Dans le [fournisseur Terraform GCP](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance), utilisez la clé `metadata` pour ajouter le jeton d'authentification du runner au fichier de configuration du runner sur la machine virtuelle GCP.
1. Pour enregistrer le runner auprès de l'instance GitLab cible, utilisez un script `cloud-init` renseigné par le fournisseur Terraform GCP. Voici un exemple :

   ```shell
   #!/bin/bash
   apt update
   curl --location "https://packages.gitlab.com/install/repositories/runner/
   gitlab-runner/script.deb.sh" | bash
   GL_NAME=$(curl 169.254.169.254/computeMetadata/v1/instance/name
   --header "Metadata-Flavor:Google")
   GL_EXECUTOR=$(curl 169.254.169.254/computeMetadata/v1/instance/attributes/
   gl_executor --header "Metadata-Flavor:Google")
   apt update
   apt install -y gitlab-runner
   gitlab-runner register --non-interactive --name="$GL_NAME" --url="https://gitlab.com"
     --token="$RUNNER_TOKEN" --request-concurrency="12" --executor="$GL_EXECUTOR"
     --docker-image="alpine:latest"
   systemctl restart gitlab-runner
   ```

## Afficher les runners avec la même configuration {#view-runners-with-the-same-configuration}

Maintenant que vous avez automatisé la création et l'enregistrement de vos runners, vous pouvez afficher les runners qui utilisent la même configuration dans l'interface GitLab.

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **CI/CD** > **Runners**.
1. Dans le champ de recherche, saisissez la description du runner ou recherchez dans la liste des runners.
1. Pour afficher les runners qui utilisent la même configuration, dans l'onglet **Détails**, à côté de **Runners**, sélectionnez **Afficher les détails**.
