---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Paquets Conan 2 dans le registre de paquets
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/519741) dans GitLab 18.1 [avec le feature flag](../../../administration/feature_flags/_index.md) `conan_package_revisions_support`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/groups/gitlab-org/-/work_items/14896) dans GitLab 18.3. Le feature flag `conan_package_revisions_support` a été supprimé.

{{< /history >}}

Publiez des paquets Conan 2 dans le registre de paquets de votre projet. Installez ensuite les paquets chaque fois que vous devez les utiliser comme dépendance.

> [!warning]
> Le registre de paquets Conan 2 pour GitLab est en cours de développement et n'est pas prêt pour une utilisation en production en raison de fonctionnalités limitées. Cet [epic](https://gitlab.com/groups/gitlab-org/-/work_items/8258) détaille les travaux restants et les calendriers pour le rendre prêt pour la production.

Pour publier des paquets Conan 2 dans le registre de paquets, ajoutez le registre de paquets en tant que remote et authentifiez-vous auprès de celui-ci.

Vous pouvez ensuite exécuter des commandes `conan` et publier votre paquet dans le registre de paquets.

> [!note]
> Le registre Conan n'est pas conforme à FIPS et est désactivé lorsque le mode FIPS est activé.

Pour la documentation des endpoints d'API spécifiques utilisés par le client du gestionnaire de paquets Conan 2, consultez [l'API Conan v2](../../../api/packages/conan_v2.md)

Découvrez comment [créer un paquet Conan 2](../workflows/build_packages.md#conan-2).

## Ajouter le registre de paquets comme remote Conan {#add-the-package-registry-as-a-conan-remote}

Pour exécuter des commandes `conan`, vous devez ajouter le registre de paquets en tant que remote Conan pour votre projet ou votre instance. Vous pouvez ensuite publier des paquets dans le registre de paquets et en installer depuis celui-ci.

### Ajouter un remote pour votre projet {#add-a-remote-for-your-project}

Définissez un remote pour pouvoir travailler avec des paquets dans un projet sans avoir à spécifier le nom du remote dans chaque commande.

Lorsque vous définissez un remote pour un projet, les noms des paquets doivent être en minuscules. De plus, vos commandes doivent inclure la recette complète, y compris l'utilisateur et le canal, par exemple, `package_name/version@user/channel`.

Pour ajouter le remote :

1. Dans votre terminal, exécutez cette commande :

   ```shell
   conan remote add gitlab https://gitlab.example.com/api/v4/projects/<project_id>/packages/conan
   ```

1. Utilisez le remote en ajoutant `--remote=gitlab` à la fin de votre commande Conan 2.

   Par exemple :

   ```shell
   conan search hello* --remote=gitlab
   ```

## S'authentifier auprès du registre de paquets {#authenticate-to-the-package-registry}

GitLab requiert une authentification pour charger des paquets et pour installer des paquets depuis des projets privés et internes. (Vous pouvez, toutefois, installer des paquets depuis des projets publics sans authentification.)

Pour vous authentifier auprès du registre de paquets, vous avez besoin de l'un des éléments suivants :

- Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) avec la portée définie sur `api`.
- Un [jeton de déploiement](../../project/deploy_tokens/_index.md) avec la portée définie sur `read_package_registry`, `write_package_registry`, ou les deux.
- Un [jeton de job CI](#publish-a-conan-2-package-by-using-cicd).

> [!note]
> Les paquets des projets privés et internes sont masqués si vous n'êtes pas authentifié. Si vous tentez de rechercher ou de télécharger un paquet depuis un projet privé ou interne sans vous authentifier, vous recevrez l'erreur `unable to find the package in remote` dans le client Conan 2.

### Ajouter vos identifiants au remote GitLab {#add-your-credentials-to-the-gitlab-remote}

Associez votre jeton au remote GitLab afin de ne pas avoir à ajouter explicitement un jeton à chaque commande Conan 2.

Prérequis :

- Vous devez disposer d'un jeton d'authentification.
- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).

Dans un terminal, exécutez cette commande. Dans cet exemple, le nom du remote est `gitlab`. Utilisez le nom de votre remote.

```shell
conan remote login -p <personal_access_token or deploy_token> gitlab <gitlab_username or deploy_token_username>
```

Désormais, lorsque vous exécutez des commandes avec `--remote=gitlab`, votre nom d'utilisateur et votre mot de passe sont inclus dans les requêtes.

> [!note]
> Étant donné que votre authentification auprès de GitLab expire régulièrement, vous devrez peut-être saisir à nouveau votre jeton d'accès personnel de temps en temps.

## Publier un paquet Conan 2 {#publish-a-conan-2-package}

Publiez un paquet Conan 2 dans le registre de paquets, afin que toute personne pouvant accéder au projet puisse utiliser le paquet comme dépendance.

Prérequis :

- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).
- [L'authentification](#authenticate-to-the-package-registry) auprès du registre de paquets doit être configurée.
- Un [paquet Conan 2](../workflows/build_packages.md#conan-2) local doit exister.
- Vous devez disposer de l'ID du projet, qui est affiché sur la [page de présentation du projet](../../project/working_with_projects.md#find-the-project-id).

Pour publier le paquet, utilisez la commande `conan upload` :

```shell
conan upload hello/0.1@mycompany/beta -r gitlab
```

## Publier un paquet Conan 2 à l'aide de CI/CD {#publish-a-conan-2-package-by-using-cicd}

Pour utiliser des commandes Conan 2 dans [GitLab CI/CD](../../../ci/_index.md), vous pouvez utiliser `CI_JOB_TOKEN` à la place du jeton d'accès personnel dans vos commandes.

Vous pouvez fournir `CONAN_LOGIN_USERNAME` et `CONAN_PASSWORD` avec chaque commande Conan dans votre fichier `.gitlab-ci.yml`. Par exemple :

```yaml
create_package:
  image: <conan 2 image>
  stage: deploy
  script:
    - conan remote add gitlab ${CI_API_V4_URL}/projects/$CI_PROJECT_ID/packages/conan
    - conan new <package-name>/0.1
    - conan create . --channel=stable --user=mycompany
    - CONAN_LOGIN_USERNAME=ci_user CONAN_PASSWORD=${CI_JOB_TOKEN} conan upload <package-name>/0.1@mycompany/stable --remote=gitlab
  environment: production
```

Suivez le [guide officiel](https://docs.conan.io/2.17/examples/runners/docker/basic.html) pour créer une image Conan 2 appropriée à utiliser comme base de votre fichier CI.

### Re-publication d'un paquet avec la même recette {#re-publishing-a-package-with-the-same-recipe}

Lorsque vous publiez un paquet qui a la même recette (`package-name/version@user/channel`) qu'un paquet existant, Conan ignore le chargement car ils sont déjà présents sur le serveur.

## Installer un paquet Conan 2 {#install-a-conan-2-package}

Installez un paquet Conan 2 depuis le registre de paquets afin de pouvoir l'utiliser comme dépendance. Vous pouvez installer un paquet depuis la portée de votre projet. Si plusieurs paquets ont la même recette, lorsque vous installez un paquet, le paquet publié le plus récemment est récupéré.

Les paquets Conan 2 sont souvent installés comme dépendances à l'aide du fichier `conanfile.txt`.

Prérequis :

- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).
- Pour les projets privés et internes, vous devez configurer [l'authentification](#authenticate-to-the-package-registry) auprès du registre de paquets.

1. Créez un autre paquet en suivant le guide [Paquet Conan 2](../workflows/build_packages.md#conan-2). À la racine de votre projet, créez un fichier appelé `conanfile.txt`.

1. Ajoutez la recette Conan à la section `[requires]` du fichier :

   ```plaintext
   [requires]
   hello/0.1@mycompany/beta
   ```

1. À la racine de votre projet, créez un répertoire `build` et accédez à ce répertoire :

   ```shell
   mkdir build && cd build
   ```

1. Installez les dépendances listées dans `conanfile.txt` :

   ```shell
   conan install ../conanfile.txt
   ```

> [!note]
> Si vous essayez d'installer le paquet que vous avez créé dans ce tutoriel, la commande d'installation n'a aucun effet car le paquet existe déjà. Utilisez cette commande pour supprimer un paquet existant localement, puis réessayez :
>
> ```shell
> conan remove hello/0.1@mycompany/beta
> ```

## Supprimer un paquet Conan 2 {#remove-a-conan-2-package}

Il existe deux façons de supprimer un paquet Conan 2 du registre de paquets GitLab.

- Depuis la ligne de commande, à l'aide du client Conan 2 :

  ```shell
  conan remove hello/0.1@mycompany/beta --remote=gitlab
  ```

  Vous devez explicitement inclure le remote dans cette commande, sinon le paquet est supprimé uniquement de votre cache système local.

  > [!note]
  > Cette commande supprime tous les fichiers de recette et de paquet binaire du registre de paquets.

- Depuis l'interface utilisateur GitLab :

  Accédez à **Déployer** > **Registre de paquets** de votre projet. Supprimez le paquet en sélectionnant **Supprimer le dépôt** ({{< icon name="remove" >}}).

## Rechercher des paquets Conan 2 dans le registre de paquets {#search-for-conan-2-packages-in-the-package-registry}

Pour rechercher par nom de paquet complet ou partiel, ou par recette exacte, exécutez la commande `conan search`.

- Pour rechercher tous les paquets portant un nom de paquet spécifique :

  ```shell
  conan search hello --remote=gitlab
  ```

- Pour rechercher un nom partiel, comme tous les paquets commençant par `he` :

  ```shell
  conan search "he*" --remote=gitlab
  ```

La portée de votre recherche dépend de votre configuration du remote Conan. Votre recherche inclut tous les paquets du projet cible, à condition que vous ayez l'autorisation d'y accéder.

La limite des résultats de recherche est de 500 paquets, et les résultats sont triés par les paquets publiés le plus récemment.

> [!note]
> Lors de la recherche de paquets, l'interface de ligne de commande Conan v2 affiche uniquement les détails des paquets chargés avec Conan v2. Les paquets chargés avec Conan v1 apparaissent dans les résultats de recherche, mais leurs détails ne sont pas affichés. Cela est dû au fait que Conan v2 attend des références de paquets sans le champ `recipe_hash`, qui est présent dans les paquets chargés avec Conan v1.

## Télécharger un paquet Conan 2 {#download-a-conan-2-package}

Vous pouvez télécharger la recette et les binaires d'un paquet Conan 2 dans votre cache local sans utiliser de paramètres, à l'aide de la commande `conan download`.

Prérequis :

- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).
- Pour les projets privés et internes, vous devez configurer [l'authentification](#authenticate-to-the-package-registry) auprès du registre de paquets.

### Télécharger tous les paquets binaires {#download-all-binary-packages}

Vous pouvez télécharger tous les paquets binaires associés à une recette depuis le registre de paquets.

Pour télécharger tous les paquets binaires, exécutez la commande suivante :

```shell
conan download hello/0.1@mycompany/beta --remote=gitlab
```

### Télécharger les fichiers de recette {#download-recipe-files}

Vous pouvez télécharger uniquement les fichiers de recette sans aucun paquet binaire.

Pour télécharger les fichiers de recette, exécutez la commande suivante :

```shell
conan download hello/0.1@mycompany/beta --remote=gitlab --only-recipe
```

### Télécharger un paquet binaire spécifique {#download-a-specific-binary-package}

Vous pouvez télécharger un seul paquet binaire en référençant sa référence de paquet (connue sous le nom de `package_id` dans la documentation Conan 2).

Pour télécharger un paquet binaire spécifique, exécutez la commande suivante :

```shell
conan download Hello/0.1@foo+bar/stable:<package_reference> --remote=gitlab
```

## Commandes CLI prises en charge {#supported-cli-commands}

Le dépôt Conan GitLab prend en charge les commandes CLI Conan 2 suivantes :

- `conan upload` : chargez vos fichiers de recette et de paquet dans le registre de paquets.
- `conan install` : installez un paquet Conan 2 depuis le registre de paquets, ce qui inclut l'utilisation du fichier `conanfile.txt`.
- `conan download` : téléchargez les recettes de paquets et les binaires dans votre cache local sans utiliser de paramètres.
- `conan search` : recherchez dans le registre de paquets les paquets publics et les paquets privés auxquels vous avez l'autorisation d'accéder.
- `conan list` : listez les recettes, révisions ou paquets existants.
- `conan remove` : supprimez le paquet du registre de paquets.

## Révisions Conan {#conan-revisions}

Les révisions Conan garantissent l'immuabilité des paquets dans le registre de paquets. Lorsque vous apportez des modifications à une recette ou à un paquet sans en changer la version, Conan calcule un identifiant unique (révision) pour suivre ces modifications.

### Types de révisions {#types-of-revisions}

Conan utilise deux types de révisions :

- **Révisions de recette (RREV)** : générées lorsqu'une recette est exportée. Par défaut, Conan calcule les révisions de recette à l'aide du hachage de somme de contrôle du manifeste de la recette.
- **Révisions de paquet (PREV)** : générées lorsqu'un paquet est construit. Conan calcule les révisions de paquet à l'aide du hachage du contenu du paquet.

### Révisions de référence {#reference-revisions}

Vous pouvez référencer des paquets dans les formats suivants :

| Référence | Description |
| --- | --- |
| `lib/1.0@conan/stable` | Le dernier RREV pour `lib/1.0@conan/stable`. |
| `lib/1.0@conan/stable#RREV` | Le RREV spécifique pour `lib/1.0@conan/stable`. |
| `lib/1.0@conan/stable#RREV:PACKAGE_REFERENCE` | Un paquet binaire appartenant au RREV spécifique. |
| `lib/1.0@conan/stable#RREV:PACKAGE_REFERENCE#PREV` | Une révision de paquet binaire PREV appartenant au RREV spécifique. |

### Charger des révisions {#upload-revisions}

Pour charger toutes les révisions et leurs binaires dans le registre de paquets GitLab :

```shell
conan upload "hello/0.1@mycompany/beta#*" --remote=gitlab
```

Lorsque vous chargez plusieurs révisions, elles sont chargées de la plus ancienne à la plus récente. L'ordre relatif est préservé dans le registre.

### Lister les révisions {#list-revisions}

Pour lister toutes les révisions d'une recette spécifique dans Conan 2 :

```shell
conan list "hello/0.1@mycompany/beta#*" --remote=gitlab
```

Cette commande affiche toutes les révisions disponibles pour la recette spécifiée, ainsi que leurs hachages de révision et leurs dates de création.

Pour obtenir des informations détaillées sur une révision spécifique :

```shell
conan list "hello/0.1@mycompany/beta#revision_hash:*#*" --remote=gitlab
```

Cette commande affiche les paquets binaires spécifiques et les révisions de paquets disponibles pour cette révision.

### Supprimer des paquets avec des révisions {#delete-packages-with-revisions}

Vous pouvez supprimer des paquets à différents niveaux de granularité :

#### Supprimer une révision de recette spécifique {#delete-a-specific-recipe-revision}

Pour supprimer une révision de recette spécifique et tous ses paquets binaires associés :

```shell
conan remove "hello/0.1@mycompany/beta#revision_hash" --remote=gitlab
```

#### Supprimer des paquets pour une révision de recette spécifique {#delete-packages-for-a-specific-recipe-revision}

Pour supprimer tous les paquets associés à une révision de recette spécifique :

```shell
conan remove "hello/0.1@mycompany/beta#revision_hash:*" --remote=gitlab
```

#### Supprimer un paquet spécifique dans une révision {#delete-a-specific-package-in-a-revision}

Pour supprimer un paquet spécifique dans une révision de recette, vous pouvez utiliser :

```shell
conan remove "package_name/version@user/channel#revision_hash:package_id" --remote=gitlab
```

### Workflow de révisions immuables {#immutable-revisions-workflow}

Les révisions sont conçues pour être immuables. Lorsque vous modifiez une recette ou son code source :

- Une nouvelle révision de recette est créée lorsque vous exportez une recette.
- Les binaires existants appartenant à la révision de recette précédente ne sont pas inclus. Vous devez créer de nouveaux binaires pour la nouvelle révision de recette.
- Lorsque vous installez un paquet, Conan 2 récupère automatiquement la dernière révision, sauf si vous en spécifiez une.

Pour les paquets binaires, vous ne devez inclure qu'une seule révision de paquet par révision de recette et par référence de paquet (connue sous le nom de `package_id` dans la documentation Conan 2). Plusieurs révisions de paquet pour la même révision de recette et le même ID de paquet indiquent qu'un paquet a été reconstruit inutilement.
