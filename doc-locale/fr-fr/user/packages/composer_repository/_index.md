---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Paquets Composer dans le registre de paquets
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

> [!warning]
> Le registre de paquets Composer pour GitLab est en cours de développement et n'est pas prêt pour une utilisation en production en raison de fonctionnalités limitées. Cet [epic](https://gitlab.com/groups/gitlab-org/-/work_items/6817) détaille les travaux restants et les délais pour le rendre prêt pour la production.

Publiez des paquets [Composer](https://getcomposer.org/) dans le registre de paquets de votre projet. Ensuite, installez les paquets chaque fois que vous avez besoin de les utiliser comme dépendance.

Pour la documentation des endpoints d'API spécifiques utilisés par le client Composer, consultez la [documentation de l'API Composer](../../../api/packages/composer.md).

Composer v2.0 est recommandé. Composer v1.0 est pris en charge, mais ses performances sont moindres lorsqu'on travaille dans des groupes avec un très grand nombre de paquets.

Apprenez comment [créer un paquet Composer](../workflows/build_packages.md#composer).

## Publier un paquet Composer en utilisant l'API {#publish-a-composer-package-by-using-the-api}

Publiez un paquet Composer dans le registre de paquets, afin que toute personne pouvant accéder au projet puisse utiliser le paquet comme dépendance.

Prérequis :

- Un paquet dans un dépôt GitLab. Les paquets Composer doivent être versionnés selon la [spécification Composer](https://getcomposer.org/doc/04-schema.md#version). Si la version n'est pas valide, par exemple si elle comporte trois points (`1.0.0.0`), une erreur (`Validation failed: Version is invalid`) se produit lors de la publication.
- Un fichier `composer.json` valide à la racine du projet.
- La fonctionnalité Paquets est activée dans un dépôt GitLab.
- L'ID du projet, qui est affiché sur la [page d'aperçu du projet](../../project/working_with_projects.md#find-the-project-id).
- L'un des types de jetons suivants :
  - Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) dont la portée est définie sur `api`.
  - Un [jeton de déploiement](../../project/deploy_tokens/_index.md) dont la portée est définie sur `write_package_registry`.

Pour publier le paquet avec un jeton d'accès personnel :

- Envoyez une requête `POST` à l'[API Packages](../../../api/packages.md).

  Par exemple, vous pouvez utiliser `curl` :

  ```shell
  curl --fail-with-body --data tag=<tag> "https://__token__:<personal-access-token>@gitlab.example.com/api/v4/projects/<project_id>/packages/composer"
  ```

  - `<personal-access-token>` est votre jeton d'accès personnel.
  - `<project_id>` est l'ID de votre projet.
  - `<tag>` est le nom du tag Git de la version que vous souhaitez publier. Pour publier une branche, utilisez `branch=<branch>` à la place de `tag=<tag>`.

Pour publier le paquet avec un jeton de déploiement :

- Envoyez une requête `POST` à l'[API Packages](../../../api/packages.md).

  Par exemple, vous pouvez utiliser `curl` :

  ```shell
  curl --fail-with-body --data tag=<tag> --header "Deploy-Token: <deploy-token>" "https://gitlab.example.com/api/v4/projects/<project_id>/packages/composer"
  ```

  - `<deploy-token>` est votre jeton de déploiement
  - `<project_id>` est l'ID de votre projet.
  - `<tag>` est le nom du tag Git de la version que vous souhaitez publier. Pour publier une branche, utilisez `branch=<branch>` à la place de `tag=<tag>`.

Vous pouvez consulter le paquet publié en accédant à **Déployer** > **Registre de paquets** et en sélectionnant l'onglet **Composer**.

## Publier un paquet Composer en utilisant CI/CD {#publish-a-composer-package-by-using-cicd}

Vous pouvez publier un paquet Composer dans le registre de paquets dans le cadre de votre processus CI/CD.

1. Spécifiez un `CI_JOB_TOKEN` dans votre fichier `.gitlab-ci.yml` :

   ```yaml
   stages:
     - deploy

   deploy:
     stage: deploy
     script:
       - apk add curl
       - 'curl --fail-with-body --header "Job-Token: $CI_JOB_TOKEN" --data tag=<tag> "${CI_API_V4_URL}/projects/$CI_PROJECT_ID/packages/composer"'
     environment: production
   ```

1. Exécutez le pipeline.

Pour consulter le paquet publié, accédez à **Déployer** > **Registre de paquets** et sélectionnez l'onglet **Composer**.

### Utiliser un modèle CI/CD {#use-a-cicd-template}

Un fichier CI/CD Composer plus détaillé est également disponible sous forme de modèle `.gitlab-ci.yml` :

1. Dans la barre latérale gauche, sélectionnez **Vue d’ensemble du projet**.
1. Au-dessus de la liste de fichiers, sélectionnez **Configuration CI/CD**. Si ce bouton n'est pas disponible, sélectionnez **CI/CD Configuration** puis **Modifier**.
1. Dans la liste **Appliquer un modèle**, sélectionnez **Composer**.

> [!warning]
> N'enregistrez pas sauf si vous souhaitez écraser le fichier CI/CD existant.

## Publication de paquets avec le même nom ou la même version {#publishing-packages-with-the-same-name-or-version}

Lorsque vous publiez :

- Le même paquet avec des données différentes écrase le paquet existant.
- Le même paquet avec les mêmes données génère une erreur `400 Bad request`.

## Installer un paquet Composer {#install-a-composer-package}

Installez un paquet depuis le registre de paquets pour pouvoir l'utiliser comme dépendance.

Prérequis :

- Un paquet dans le registre de paquets.
- Le registre de paquets est activé dans le projet responsable de la publication du paquet.
- L'ID du groupe, qui se trouve sur la page d'accueil du groupe.
- L'un des types de jetons suivants :
  - Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) dont la portée est définie au minimum sur `api`.
  - Un [jeton de déploiement](../../project/deploy_tokens/_index.md) dont la portée est définie sur `read_package_registry`, `write_package_registry`, ou les deux.
  - Un [jeton de job CI/CD](../../../ci/jobs/ci_job_token.md)

Pour installer un paquet :

1. Ajoutez l'URL du registre de paquets au fichier `composer.json` de votre projet, ainsi que le nom et la version du paquet que vous souhaitez installer :

   - Connectez-vous au registre de paquets pour votre groupe :

     ```shell
     composer config repositories.<group_id> composer https://gitlab.example.com/api/v4/group/<group_id>/-/packages/composer/packages.json
     ```

   - Définissez la version de paquet requise :

     ```shell
     composer require <package_name>:<version>
     ```

   Résultat dans le fichier `composer.json` :

   ```json
   {
     ...
     "repositories": {
       "<group_id>": {
         "type": "composer",
         "url": "https://gitlab.example.com/api/v4/group/<group_id>/-/packages/composer/packages.json"
       },
       ...
     },
     "require": {
       ...
       "<package_name>": "<version>"
     },
     ...
   }
   ```

   Vous pouvez annuler cette configuration avec la commande :

   ```shell
   composer config --unset repositories.<group_id>
   ```

   - `<group_id>` est l'ID du groupe.
   - `<package_name>` est le nom du paquet défini dans le fichier `composer.json` de votre paquet.
   - `<version>` est la version du paquet.

1. Créez un fichier `auth.json` avec vos identifiants GitLab :

   Avec un jeton d'accès personnel :

   ```shell
   composer config gitlab-token.<DOMAIN-NAME> <personal_access_token>
   ```

   Résultat dans le fichier `auth.json` :

   ```json
   {
     ...
     "gitlab-token": {
       "<DOMAIN-NAME>": "<personal_access_token>",
       ...
     }
   }
   ```

   Avec un jeton de déploiement :

   ```shell
   composer config gitlab-token.<DOMAIN-NAME> <deploy_token_username> <deploy_token>
   ```

   Résultat dans le fichier `auth.json` :

   ```json
   {
     ...
     "gitlab-token": {
       "<DOMAIN-NAME>": {
         "username": "<deploy_token_username>",
         "token": "<deploy_token>",
       ...
     }
   }
   ```

   Avec un jeton de job CI/CD :

   ```shell
   composer config -- gitlab-token.<DOMAIN-NAME> gitlab-ci-token "${CI_JOB_TOKEN}"
   ```

   Résultat dans le fichier `auth.json` :

   ```json
   {
     ...
     "gitlab-token": {
       "<DOMAIN-NAME>": {
         "username": "gitlab-ci-token",
         "token": "<ci-job-token>",
       ...
     }
   }
   ```

   Vous pouvez annuler cette configuration avec la commande :

   ```shell
   composer config --unset --auth gitlab-token.<DOMAIN-NAME>
   ```

   - `<DOMAIN-NAME>` est l'URL de l'instance GitLab `gitlab.com` ou `gitlab.example.com`.
   - `<personal_access_token>` avec la portée définie sur `api`, ou `<deploy_token>` avec la portée définie sur `read_package_registry` et/ou `write_package_registry`.

1. Si vous utilisez GitLab Self-Managed, ajoutez `gitlab-domains` à `composer.json`.

   ```shell
   composer config gitlab-domains gitlab01.example.com gitlab02.example.com
   ```

   Résultat dans le fichier `composer.json` :

   ```json
   {
     ...
     "repositories": [
       { "type": "composer", "url": "https://gitlab.example.com/api/v4/group/<group_id>/-/packages/composer/packages.json" }
     ],
     "config": {
       ...
       "gitlab-domains": ["gitlab01.example.com", "gitlab02.example.com"]
     },
     "require": {
       ...
       "<package_name>": "<version>"
     },
     ...
   }
   ```

   Vous pouvez annuler cette configuration avec la commande :

   ```shell
   composer config --unset gitlab-domains
   ```

   > [!note]
   > Sur GitLab.com, Composer utilise par défaut le jeton GitLab de `auth.json` comme jeton privé. Sans la définition de `gitlab-domains` dans `composer.json`, Composer utilise le jeton GitLab en authentification basique, avec le jeton comme nom d'utilisateur et un mot de passe vide. Cela entraîne une erreur 401.

1. Une fois les fichiers `composer.json` et `auth.json` configurés, vous pouvez installer le paquet en exécutant :

   ```shell
   composer update
   ```

   Ou pour installer le paquet unique :

   ```shell
   composer req <package-name>:<package-version>
   ```

> [!warning]
> Ne committez jamais le fichier `auth.json` dans votre dépôt. Pour installer des paquets depuis un job CI/CD, envisagez d'utiliser l'outil [`composer config`](https://getcomposer.org/doc/articles/handling-private-packages.md#satis) avec votre jeton d'accès stocké dans une [variable CI/CD GitLab](../../../ci/variables/_index.md) ou dans [HashiCorp Vault](../../../ci/secrets/_index.md).

### Installer depuis la source {#install-from-source}

Vous pouvez installer depuis la source en extrayant directement le dépôt Git. Pour ce faire, choisissez l'une des options suivantes :

- Utilisez l'option `--prefer-source` :

  ```shell
  composer update --prefer-source
  ```

- Dans le fichier `composer.json`, utilisez le [champ `preferred-install` sous la clé `config`](https://getcomposer.org/doc/06-config.md#preferred-install) :

  ```json
  {
    ...
    "config": {
      "preferred-install": {
        "<package name>": "source"
      }
    }
    ...
   }
  ```

#### Accès SSH {#ssh-access}

Lorsque vous installez depuis la source, `composer` configure l'accès au dépôt Git du projet. Selon la visibilité du projet, le type d'accès est différent :

- Sur les projets publics, l'URL Git `https` est utilisée. Assurez-vous de pouvoir [cloner le dépôt avec HTTPS](../../../topics/git/clone.md#clone-with-https).
- Sur les projets internes ou privés, l'URL Git `ssh` est utilisée. Assurez-vous de pouvoir [cloner le dépôt avec SSH](../../../topics/git/clone.md#clone-with-ssh).

Vous pouvez accéder à l'URL Git `ssh` depuis un job CI/CD en utilisant les [clés SSH avec GitLab CI/CD](../../../ci/jobs/ssh_keys.md).

### Utilisation des jetons de déploiement {#working-with-deploy-tokens}

Bien que les paquets Composer soient accessibles au niveau du groupe, un jeton de déploiement de groupe ou de projet peut être utilisé pour y accéder :

- Un jeton de déploiement de groupe a accès à tous les paquets publiés dans les projets de ce groupe ou de ses sous-groupes.
- Un jeton de déploiement de projet n'a accès qu'aux paquets publiés dans ce projet particulier.

## Supprimer un paquet Composer {#delete-a-composer-package}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire.

Avant de supprimer un paquet, assurez-vous de comprendre les [risques de sécurité associés](../package_registry/supported_functionality.md#deleting-packages).

Pour supprimer un paquet, vous pouvez :

- [Utiliser l'interface utilisateur](../package_registry/reduce_package_registry_storage.md#delete-a-package).
- [Utiliser l'API](../../../api/packages.md#delete-a-project-package).

## Dépannage {#troubleshooting}

### Mise en cache {#caching}

Pour améliorer les performances, Composer met en cache les fichiers liés à un paquet. Composer ne supprime pas les données automatiquement. Le cache augmente à mesure que de nouveaux paquets sont installés. Si vous rencontrez des problèmes, videz le cache avec cette commande :

```shell
composer clearcache
```

### Exigence d'autorisation lors de l'utilisation de `composer install` {#authorization-requirement-when-using-composer-install}

Une autorisation est requise pour l'endpoint de [téléchargement d'une archive de paquet](../../../api/packages/composer.md#download-a-package-archive). Si vous rencontrez une invite de saisie d'identifiants lors de l'utilisation de `composer install`, suivez les instructions de la section [installer un paquet Composer](#install-a-composer-package) pour créer un fichier `auth.json`.

### La publication échoue avec `The file composer.json was not found` {#publish-fails-with-the-file-composerjson-was-not-found}

Vous pourriez voir une erreur indiquant `The file composer.json was not found`.

Ce problème survient lorsque les [exigences de configuration pour la publication d'un paquet](#publish-a-composer-package-by-using-the-api) ne sont pas satisfaites.

Pour résoudre l'erreur, committez un fichier `composer.json` dans le répertoire racine du projet.

## Commandes CLI prises en charge {#supported-cli-commands}

Le dépôt Composer GitLab prend en charge les commandes CLI Composer suivantes :

- `composer install` : installer les dépendances Composer.
- `composer update` : installer la dernière version des dépendances Composer.
