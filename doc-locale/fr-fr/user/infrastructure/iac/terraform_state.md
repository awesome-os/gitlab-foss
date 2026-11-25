---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: État Terraform/OpenTofu géré par GitLab
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Prise en charge des noms d'état contenant des points introduite dans GitLab 15.7 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `allow_dots_on_tf_state_names`. Fonctionnalité désactivée par défaut.
- Prise en charge des noms d'état contenant des points [généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/issues/385597) dans GitLab 16.0. Le feature flag `allow_dots_on_tf_state_names` a été supprimé.
- Prise en charge des états OpenTofu et Terraform gérés par GitLab [introduite](https://gitlab.com/gitlab-org/cli/-/issues/7954) dans GitLab 18.3. Nécessite GitLab CLI (`glab`) 1.66 ou une version ultérieure.

{{< /history >}}

La gestion des fichiers d'état d'infrastructure entre les équipes exige à la fois sécurité et fiabilité. L'état OpenTofu géré par GitLab élimine les défis habituels liés à la gestion des états. Avec une configuration minimale, vos états OpenTofu deviennent une extension naturelle de votre projet GitLab. Cette intégration centralise vos définitions d'infrastructure, votre code et votre état dans un emplacement sécurisé unique.

Avec l'état OpenTofu géré par GitLab, vous pouvez :

- Stocker les fichiers d'état de manière sécurisée avec un chiffrement automatique au repos
- Suivre les modifications grâce au versionnage intégré pour identifier qui a modifié quoi et quand
- Contrôler les accès à l'aide du modèle de permissions GitLab plutôt que de créer des systèmes d'authentification distincts
- Collaborer entre équipes sans conflits ni corruption des fichiers d'état
- S'intégrer de manière transparente à vos pipelines CI/CD GitLab existants
- Accéder à l'état à distance depuis les jobs CI/CD et les environnements de développement locaux

## Considérations relatives à la reprise après sinistre {#disaster-recovery-considerations}

Les fichiers d'état OpenTofu sont chiffrés avec le gem Ruby Lockbox lorsqu'ils sont au repos sur disque et dans le stockage d'objets. Le chiffrement utilise une clé dérivée du paramètre d'application `db_key_base`. En raison de cette approche de chiffrement, l'instance doit être disponible pour déchiffrer un fichier d'état.

Si l'instance passe hors ligne, vous ne pouvez pas accéder à vos fichiers d'état ni les déchiffrer. Cela devient problématique si vos fichiers d'état contiennent la configuration de l'infrastructure dont GitLab dépend pour fonctionner.

Si GitLab héberge des modules OpenTofu ou d'autres dépendances nécessaires à son amorçage, ces dépendances deviennent inaccessibles lorsque l'instance est hors ligne.

Pour éviter ce problème :

- Hébergez ou sauvegardez les dépendances séparément.
- Utilisez une instance GitLab distincte sans points de défaillance communs.
- Envisagez un hébergement alternatif pour les dépendances critiques d'amorçage.

## Prérequis {#prerequisites}

Pour GitLab Self-Managed, avant de pouvoir utiliser GitLab pour vos fichiers d'état OpenTofu :

- Un administrateur doit [configurer le stockage des états Terraform/OpenTofu](../../../administration/terraform_state.md).
- Vous devez activer le menu **Infrastructure** pour votre projet :
  1. Accédez à **Paramètres** > **Général**.
  1. Développez **Visibilité, fonctionnalités du projet, autorisations**.
  1. Sous **Infrastructure**, activez le bouton bascule.

## Sécuriser les données du plan {#secure-plan-data}

> [!warning]
> Les fichiers OpenTofu `plan.json` ou `plan.cache` ne sont pas chiffrés et peuvent contenir des données sensibles telles que des mots de passe, des jetons d'accès ou des certificats. Par défaut, les utilisateurs ayant le rôle Invité peuvent accéder à vos fichiers de plan.

Pour sécuriser les données de votre plan :

- Définissez `access: 'developer'` dans votre [configuration d'artefact](../../../ci/yaml/_index.md#artifactsaccess). Ce paramètre limite l'accès aux utilisateurs ayant le rôle Développeur ou supérieur.
- [Désactivez les pipelines publics](../../../ci/pipelines/settings.md#change-pipeline-visibility-for-non-project-members-in-public-projects).
- Chiffrez la sortie du plan.
- Définissez la visibilité du projet sur privée.

## Initialiser un état OpenTofu en tant que backend avec GitLab CI/CD {#initialize-an-opentofu-state-as-a-backend-by-using-gitlab-cicd}

Prérequis :

- Pour verrouiller, déverrouiller et écrire dans l'état avec `tofu apply`, vous devez avoir le rôle Chargé de maintenance ou Propriétaire.
- Pour lire l'état avec `tofu plan -lock=false`, vous devez avoir le rôle Développeur, Chargé de maintenance ou Propriétaire.

Pour configurer GitLab CI/CD en tant que backend :

1. Dans votre projet OpenTofu, dans un fichier `.tf` tel que `backend.tf`, définissez le [backend HTTP](https://opentofu.org/docs/language/settings/backends/http/) :

   ```hcl
   terraform {
     backend "http" {
     }
   }
   ```

1. Dans le répertoire racine de votre dépôt de projet, créez un fichier `.gitlab-ci.yml`. Utilisez le [composant CI/CD OpenTofu](https://gitlab.com/components/opentofu) pour créer votre fichier `.gitlab-ci.yml`.
1. Effectuez un push de votre projet vers GitLab. Cette action déclenche un pipeline, qui exécute les commandes `gitlab-tofu init`, `gitlab-tofu validate` et `gitlab-tofu plan`.
1. Déclenchez le job `deploy` manuel depuis le pipeline précédent. Cette action exécute la commande `gitlab-tofu apply`, qui provisionne l'infrastructure définie.

La sortie des commandes précédentes doit être consultable dans les job logs.

La CLI `gitlab-tofu` est une encapsulation de la CLI `tofu`.

### Personnaliser les variables d'environnement OpenTofu {#customizing-your-opentofu-environment-variables}

Vous pouvez utiliser les [variables de configuration HTTP OpenTofu](https://opentofu.org/docs/language/settings/backends/http/#configuration-variables) lorsque vous définissez vos jobs CI/CD.

Pour personnaliser votre `init` et remplacer la configuration OpenTofu, utilisez des variables d'environnement plutôt que l'approche `init -backend-config=...`. Lorsque vous utilisez `-backend-config`, la configuration est :

- Mise en cache dans la sortie de la commande `plan`.
- Généralement transmise à la commande `apply`.

Cette configuration peut entraîner des problèmes comme [l'impossibilité de verrouiller les fichiers d'état dans les jobs CI](troubleshooting.md#cant-lock-terraform-state-files-in-ci-jobs-for-terraform-apply-with-a-previous-jobs-plan).

#### Personnaliser le nom du fichier de plan {#customize-the-plan-filename}

Par défaut, la commande `gitlab-tofu plan` (ou `gitlab-terraform plan`) écrit toujours la sortie du plan dans un fichier nommé `plan.cache`.

Pour modifier le nom du fichier, définissez la variable d'environnement `TF_PLAN_CACHE` dans la configuration de votre pipeline CI/CD. Par exemple, pour définir le nom du fichier sur `my-plan.tfplan` :

```yaml
variables:
  TF_PLAN_CACHE: "my-plan.tfplan"
```

> [!note]
> Ne définissez pas le nom du fichier de sortie en passant l'option `-out=<filename>`. Les commandes GitLab remplacent cette option.

## Accéder à l'état depuis votre machine locale {#access-the-state-from-your-local-machine}

Vous pouvez accéder à l'état OpenTofu géré par GitLab depuis votre machine locale.

> [!warning]
> Sur les déploiements en cluster de GitLab, vous ne devez pas utiliser le stockage local. Un état fractionné peut se produire entre les nœuds, rendant les exécutions OpenTofu ultérieures incohérentes. Utilisez plutôt une ressource de stockage distant.

1. Assurez-vous que l'état OpenTofu a été [initialisé pour CI/CD](#initialize-an-opentofu-state-as-a-backend-by-using-gitlab-cicd).
1. Copiez une commande OpenTofu `init` préremplie :

   1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
   1. Sélectionnez **Opération** > **États Terraform**.
   1. À côté de l'environnement que vous souhaitez utiliser, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) et sélectionnez **Copier la commande Terraform init**.

1. Ouvrez un terminal et exécutez cette commande sur votre machine locale.

## Migrer vers un état OpenTofu géré par GitLab {#migrate-to-a-gitlab-managed-opentofu-state}

OpenTofu prend en charge la copie de l'état lorsque le backend change ou est reconfiguré. Utilisez ces actions pour migrer d'un autre backend vers l'état OpenTofu géré par GitLab.

Vous devez utiliser un terminal local pour exécuter les commandes nécessaires à la migration vers l'état OpenTofu géré par GitLab.

L'exemple suivant montre comment modifier le nom de l'état. Le même workflow est nécessaire pour migrer vers l'état OpenTofu géré par GitLab depuis un backend de stockage d'état différent.

Vous devez exécuter ces commandes [sur votre machine locale](#access-the-state-from-your-local-machine).

### Configurer le backend initial {#set-up-the-initial-backend}

{{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

Pour initialiser un backend avec `glab`, exécutez la commande suivante :

```shell
glab opentofu init <old_state_name>
```

{{< /tab >}}

{{< tab title="Manuellement avec OpenTofu CLI" >}}

Pour initialiser un backend avec OpenTofu CLI, exécutez la commande suivante :

```shell
PROJECT_ID="<gitlab-project-id>"
TF_USERNAME="<gitlab-username>"
TF_PASSWORD="<gitlab-personal-access-token>"
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/old-state-name"

tofu init \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${TF_PASSWORD} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

{{< /tab >}}

{{< /tabs >}}

Si le backend est initialisé avec succès, vous recevez la réponse suivante :

```plaintext
Initializing the backend...

Successfully configured the backend "http"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
re-run this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

### Modifier le backend {#change-the-backend}

Maintenant que `tofu init` a créé un répertoire `.terraform/` qui connaît l'emplacement de l'ancien état, vous pouvez lui indiquer le nouvel emplacement :

{{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

```shell
glab opentofu init <new-state-name> -- -migrate-state
```

{{< /tab >}}

{{< tab title="Manuellement avec OpenTofu CLI" >}}

```shell
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/<new-state-name>"

tofu init \
  -migrate-state \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${TF_PASSWORD} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

{{< /tab >}}

{{< /tabs >}}

Si le backend est initialisé avec succès, vous recevez la réponse suivante. Si vous saisissez `yes`, l'état est copié depuis l'ancien emplacement vers le nouvel emplacement. Vous pouvez ensuite reprendre son exécution dans GitLab CI/CD :

```plaintext
Initializing the backend...
Backend configuration changed!

Terraform has detected that the configuration specified for the backend
has changed. Terraform will now check for existing state in the backends.


Acquiring state lock. This may take a few moments...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "http" backend to the
  newly configured "http" backend. No existing state was found in the newly
  configured "http" backend. Do you want to copy this state to the new "http"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes


Successfully configured the backend "http"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

## Utiliser votre backend GitLab comme source de données distante {#use-your-gitlab-backend-as-a-remote-data-source}

Vous pouvez utiliser un backend d'état OpenTofu géré par GitLab comme [source de données OpenTofu](https://opentofu.org/docs/language/state/remote-state-data/).

1. Dans votre fichier `main.tf` ou tout autre fichier pertinent, déclarez ces variables. Laissez les valeurs vides.

   ```hcl
   variable "example_remote_state_address" {
     type = string
     description = "Gitlab remote state file address"
   }

   variable "example_username" {
     type = string
     description = "Gitlab username to query remote state"
   }

   variable "example_access_token" {
     type = string
     description = "GitLab access token to query remote state"
   }
   ```

1. Pour remplacer les valeurs de l'étape précédente, créez un fichier nommé `example.auto.tfvars`. Ce fichier ne doit pas être versionné dans votre dépôt de projet.

   ```plaintext
   example_remote_state_address = "https://gitlab.com/api/v4/projects/<TARGET-PROJECT-ID>/terraform/state/<TARGET-STATE-NAME>"
   example_username = "<GitLab username>"
   example_access_token = "<GitLab personal access token>"
   ```

1. Dans un fichier `.tf`, définissez la source de données à l'aide des [variables d'entrée OpenTofu](https://opentofu.org/docs/language/values/variables/) :

   ```hcl
   data "terraform_remote_state" "example" {
     backend = "http"

     config = {
       address = var.example_remote_state_address
       username = var.example_username
       password = var.example_access_token
     }
   }
   ```

   - **address** : L'URL du backend d'état distant que vous souhaitez utiliser comme source de données. Par exemple, `https://gitlab.com/api/v4/projects/<TARGET-PROJECT-ID>/terraform/state/<TARGET-STATE-NAME>`.
   - **username** : le nom d'utilisateur permettant de s'authentifier auprès de la source de données. Si vous utilisez un [jeton d'accès personnel](../../profile/personal_access_tokens.md) pour l'authentification, cette valeur correspond à votre nom d'utilisateur GitLab. Si vous utilisez GitLab CI/CD, cette valeur est `'gitlab-ci-token'`.
   - **password** : le mot de passe permettant de s'authentifier auprès de la source de données. Si vous utilisez un jeton d'accès personnel pour l'authentification, cette valeur correspond à la valeur du jeton (le jeton doit avoir la portée **API**). Si vous utilisez GitLab CI/CD, cette valeur correspond au contenu de la variable CI/CD `${CI_JOB_TOKEN}`.

Les sorties de la source de données peuvent maintenant être référencées dans vos ressources Terraform à l'aide de `data.terraform_remote_state.example.outputs.<OUTPUT-NAME>`.

Pour lire l'état OpenTofu dans le projet cible, vous devez avoir le rôle Développeur, Chargé de maintenance ou Propriétaire.

## Gérer les fichiers d'état OpenTofu {#manage-opentofu-state-files}

Pour afficher les fichiers d'état OpenTofu :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Opération** > **États Terraform**.

[Un epic existe](https://gitlab.com/groups/gitlab-org/-/epics/4563) pour suivre les améliorations de cette interface utilisateur.

### Gérer les versions individuelles d'un état OpenTofu {#manage-individual-opentofu-state-versions}

Gérez les versions d'état individuelles à l'aide de GitLab CLI (`glab`) ou de l'API.

Prérequis :

- Pour obtenir les versions d'état à l'aide de leur numéro de série, vous devez avoir le rôle Développeur, Chargé de maintenance ou Propriétaire.
- Pour supprimer les versions d'état à l'aide de leur numéro de série, vous devez avoir le rôle Chargé de maintenance ou Propriétaire.

Pour obtenir les versions d'état à l'aide de leur numéro de série : {{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

```shell
glab opentofu state download <your_state_name> <version_serial_number>
```

{{< /tab >}}

{{< tab title="Manuellement avec curl" >}}

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/versions/<version_serial_number>"
```

{{< /tab >}}

{{< /tabs >}}

Pour supprimer les versions d'état à l'aide de leur numéro de série :

{{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

```shell
glab opentofu state delete <your_state_name> <version_serial_number>
```

{{< /tab >}}

{{< tab title="Manuellement avec curl" >}}

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/versions/<version_serial_number>"
```

{{< /tab >}}

{{< /tabs >}}

### Supprimer un fichier d'état {#remove-a-state-file}

Prérequis :

- Pour supprimer un fichier d'état, vous devez avoir le rôle Chargé de maintenance ou Propriétaire.

{{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

```shell
glab opentofu state delete <your_state_name>
```

{{< /tab >}}

{{< tab title="Manuellement avec curl" >}}

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>"
```

Vous pouvez également utiliser le [jeton de job CI/CD](../../../ci/jobs/ci_job_token.md) et l'authentification de base :

```shell
curl --request DELETE --user "gitlab-ci-token:$CI_JOB_TOKEN" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>"
```

Vous pouvez également utiliser [l'API GraphQL](../../../api/graphql/reference/_index.md#mutationterraformstatedelete).

{{< /tab >}}

{{< tab title="Utilisation de l'interface utilisateur" >}}

Pour supprimer un fichier d'état via l'interface utilisateur :

1. Dans la barre latérale gauche, sélectionnez **Opération** > **États Terraform**.
1. Dans la colonne **Actions**, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **Supprimer le fichier d'état et les versions**.

{{< /tab >}}

{{< /tabs >}}

### Verrouiller et déverrouiller un état {#lock-and-unlock-a-state}

Prérequis :

- Pour verrouiller un fichier d'état, vous devez avoir le rôle Chargé de maintenance ou Propriétaire.

{{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

```shell
# Lock a state file
glab opentofu state lock <your_state_name>

# Unlock a state file
glab opentofu state unlock <your_state_name>
```

{{< /tab >}}

{{< tab title="Manuellement avec curl" >}}

```shell
# Lock a state file
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/lock"

# Unlock a state file
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/lock"
```

{{< /tab >}}

{{< tab title="Utilisation de l'interface utilisateur" >}}

Pour verrouiller ou déverrouiller un fichier d'état via l'interface utilisateur :

1. Dans la barre latérale gauche, sélectionnez **Opération** > **États Terraform**.
1. Dans la colonne **Actions**, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **Verrouiller** pour verrouiller ou **Actions** ({{< icon name="ellipsis_v" >}}) > **Déverrouiller**.

{{< /tab >}}

{{< /tabs >}}

### Télécharger un fichier d'état {#download-a-state-file}

Prérequis :

- Pour télécharger un fichier d'état, vous devez avoir le rôle Développeur, Chargé de maintenance ou Propriétaire.

{{< tabs >}}

{{< tab title="Utilisation de GitLab CLI (glab)" >}}

```shell
# Download the latest state
glab opentofu state download <your_state_name>

# Download a specific version (serial) of a state
glab opentofu state download <your_state_name> <your_serial>
```

{{< /tab >}}

{{< tab title="Manuellement avec curl" >}}

```shell
# Download the latest state
curl --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>"

# Download a specific version (serial) of a state
curl --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/versions/<version_serial_number>"
```

{{< /tab >}}

{{< tab title="Utilisation de l'interface utilisateur" >}}

Pour télécharger le dernier fichier d'état via l'interface utilisateur :

1. Dans la barre latérale gauche, sélectionnez **Opération** > **États Terraform**.
1. Dans la colonne **Actions**, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **Télécharger le JSON**.

Il n'est pas possible de télécharger une version spécifique de l'état via l'interface utilisateur.

{{< /tab >}}

{{< /tabs >}}

#### Protéger les données sensibles dans les fichiers d'état Terraform {#protect-sensitive-data-in-terraform-state-files}

Les fichiers d'état Terraform peuvent contenir des informations sensibles telles que des mots de passe, des clés privées, des jetons d'API et des chaînes de connexion à des bases de données. Dans GitLab, tout utilisateur ayant le rôle Développeur ou supérieur peut télécharger et consulter les fichiers d'état Terraform pour les projets dont il est membre.

Pour réduire l'exposition des données sensibles :

- Clients de GitLab Ultimate : créez un rôle personnalisé qui reproduit le rôle Développeur mais exclut la permission `admin_terraform_state`. Cette action permet aux membres de l'équipe de contribuer aux projets Infrastructure as Code (IaC) sans accéder aux fichiers d'état Terraform contenant des données sensibles.

  > [!note]
  > Les rôles personnalisés sont uniquement disponibles sur GitLab Ultimate. Les clients disposant de GitLab Premium ou d'une édition inférieure n'ont pas accès à cette option d'atténuation et doivent se concentrer sur les autres stratégies décrites précédemment.

- Utilisateurs OpenTofu : activez le chiffrement des états et des plans pour protéger les données sensibles au repos. GitLab prend en charge cela nativement via le [composant CI/CD OpenTofu](https://gitlab.com/components/opentofu), qui fournit la configuration du chiffrement. Même si des utilisateurs non autorisés accèdent au fichier d'état, le contenu chiffré reste protégé.
- Tous les utilisateurs :
  - Limitez l'appartenance au projet aux utilisateurs qui ont besoin d'accéder à l'état de l'infrastructure.
  - Utilisez un projet distinct pour stocker les états, en n'ajoutant que les utilisateurs nécessaires en tant que membres.
  - Utilisez des solutions de gestion de secrets externes comme HashiCorp Vault ou AWS Secrets Manager pour référencer les secrets de manière dynamique plutôt que de les stocker dans la configuration Terraform.
  - Marquez les valeurs sensibles à l'aide du paramètre Terraform [`sensitive`](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output) dans les définitions de variables. Cette action empêche les valeurs d'apparaître dans la sortie CLI et dans les fichiers de plan, bien qu'elles restent dans le fichier d'état.
  - Auditez régulièrement les membres du projet ayant le rôle Développeur et vérifiez le contenu des fichiers d'état pour détecter les secrets exposés par inadvertance.

## Sujets connexes {#related-topics}

- [Dépannage de l'état Terraform géré par GitLab](troubleshooting.md)
- [Exemple de projet : déploiement Terraform d'une instance AWS EC2 dans un VPC personnalisé](https://gitlab.com/gitlab-org/ci-cd/deploy-stage/environments-group/examples/gitlab-terraform-aws)
