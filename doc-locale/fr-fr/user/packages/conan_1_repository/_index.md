---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Paquets Conan 1 dans le registre de paquets
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

> [!warning]
> Le registre de paquets Conan pour GitLab est en cours de développement et n'est pas prêt pour une utilisation en production en raison de fonctionnalités limitées. Cet [epic](https://gitlab.com/groups/gitlab-org/-/work_items/6816) détaille les travaux restants et les délais pour le rendre prêt pour la production.

Publiez des paquets Conan dans le registre de paquets de votre projet. Installez ensuite les paquets chaque fois que vous avez besoin de les utiliser comme dépendance.

Pour publier des paquets Conan dans le registre de paquets, ajoutez le registre de paquets en tant que remote et authentifiez-vous auprès de celui-ci.

Vous pouvez alors exécuter des commandes `conan` et publier votre paquet dans le registre de paquets.

> [!note]
> Le registre Conan n'est pas conforme à la norme FIPS et est désactivé lorsque le mode FIPS est activé.

Pour la documentation des endpoints d'API spécifiques utilisés par le client du gestionnaire de paquets Conan, consultez [API Conan v1](../../../api/packages/conan_v1.md) ou [API Conan v2](../../../api/packages/conan_v2.md).

Découvrez comment [créer un paquet Conan 1](../workflows/build_packages.md#conan-1).

## Ajouter le registre de paquets en tant que remote Conan {#add-the-package-registry-as-a-conan-remote}

Pour exécuter des commandes `conan`, vous devez ajouter le registre de paquets en tant que remote Conan pour votre projet ou instance. Vous pouvez ensuite publier des paquets dans le registre de paquets et en installer depuis celui-ci.

### Ajouter un remote pour votre projet {#add-a-remote-for-your-project}

Configurez un remote pour pouvoir travailler avec des paquets dans un projet sans avoir à spécifier le nom du remote dans chaque commande.

Lorsque vous configurez un remote pour un projet, il n'y a aucune restriction sur les noms de vos paquets. Cependant, vos commandes doivent inclure la recette complète, y compris l'utilisateur et le canal, par exemple `package_name/version@user/channel`.

Pour ajouter le remote :

1. Dans votre terminal, exécutez cette commande :

   ```shell
   conan remote add gitlab https://gitlab.example.com/api/v4/projects/<project_id>/packages/conan
   ```

1. Utilisez le remote en ajoutant `--remote=gitlab` à la fin de votre commande Conan.

   Par exemple :

   ```shell
   conan search Hello* --remote=gitlab
   ```

### Ajouter un remote pour votre instance {#add-a-remote-for-your-instance}

Utilisez un seul remote pour accéder aux paquets dans l'ensemble de votre instance GitLab.

Cependant, lorsque vous utilisez ce remote, vous devez respecter ces [restrictions de nommage des paquets](#package-recipe-naming-convention-for-instance-remotes).

Pour ajouter le remote :

1. Dans votre terminal, exécutez cette commande :

   ```shell
   conan remote add gitlab https://gitlab.example.com/api/v4/packages/conan
   ```

1. Utilisez le remote en ajoutant `--remote=gitlab` à la fin de votre commande Conan.

   Par exemple :

   ```shell
   conan search 'Hello*' --remote=gitlab
   ```

#### Convention de nommage des recettes de paquets pour les remotes d'instance {#package-recipe-naming-convention-for-instance-remotes}

La convention de recette Conan standard est `package_name/version@user/channel`, mais si vous utilisez un [remote d'instance](#add-a-remote-for-your-instance), le champ `user` de la recette doit être le chemin du projet séparé par le signe plus (`+`).

Exemples de noms de recettes :

| Projet                | Paquet                                        | Pris en charge |
| ---------------------- | ---------------------------------------------- | --------- |
| `foo/bar`              | `my-package/1.0.0@foo+bar/stable`              | Oui       |
| `foo/bar-baz/buz`      | `my-package/1.0.0@foo+bar-baz+buz/stable`      | Oui       |
| `gitlab-org/gitlab-ce` | `my-package/1.0.0@gitlab-org+gitlab-ce/stable` | Oui       |
| `gitlab-org/gitlab-ce` | `my-package/1.0.0@foo/stable`                  | Non        |

Les [remotes de projet](#add-a-remote-for-your-project) ont une convention de nommage plus flexible.

## S'authentifier auprès du registre de paquets {#authenticate-to-the-package-registry}

GitLab requiert une authentification pour téléverser des paquets et pour installer des paquets depuis des projets privés et internes. (Vous pouvez cependant installer des paquets depuis des projets publics sans authentification.)

Pour vous authentifier auprès du registre de paquets, vous avez besoin de l'un des éléments suivants :

- Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) avec la portée définie sur `api`.
- Un [jeton de déploiement](../../project/deploy_tokens/_index.md) avec la portée définie sur `read_package_registry`, `write_package_registry`, ou les deux.
- Un [jeton de job CI](#publish-a-conan-package-by-using-cicd).

> [!note]
> Les paquets issus de projets privés et internes sont masqués si vous n'êtes pas authentifié. Si vous essayez de rechercher ou de télécharger un paquet depuis un projet privé ou interne sans vous authentifier, vous recevrez l'erreur `unable to find the package in remote` dans le client Conan.

### Ajouter vos identifiants au remote GitLab {#add-your-credentials-to-the-gitlab-remote}

Associez votre jeton au remote GitLab afin de ne pas avoir à ajouter explicitement un jeton à chaque commande Conan.

Prérequis :

- Vous devez disposer d'un jeton d'authentification.
- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).

Dans un terminal, exécutez cette commande. Dans cet exemple, le nom du remote est `gitlab`. Utilisez le nom de votre remote.

```shell
conan user <gitlab_username or deploy_token_username> -r gitlab -p <personal_access_token or deploy_token>
```

Désormais, lorsque vous exécutez des commandes avec `--remote=gitlab`, votre nom d'utilisateur et votre mot de passe sont inclus dans les requêtes.

> [!note]
> Étant donné que votre authentification auprès de GitLab expire régulièrement, vous devrez peut-être saisir à nouveau votre jeton d'accès personnel de temps en temps.

### Définir un remote par défaut pour votre projet (facultatif) {#set-a-default-remote-for-your-project-optional}

Si vous souhaitez interagir avec le registre de paquets GitLab sans avoir à spécifier un remote, vous pouvez configurer Conan pour qu'il utilise toujours le registre de paquets pour vos paquets.

Dans un terminal, exécutez cette commande :

```shell
conan remote add_ref Hello/0.1@mycompany/beta gitlab
```

> [!note]
> La recette du paquet inclut la version, de sorte que le remote par défaut pour `Hello/0.1@user/channel` ne fonctionne pas pour `Hello/0.2@user/channel`.

Si vous ne définissez pas d'utilisateur ou de remote par défaut, vous pouvez toujours inclure l'utilisateur et le remote dans vos commandes :

```shell
CONAN_LOGIN_USERNAME=<gitlab_username or deploy_token_username> CONAN_PASSWORD=<personal_access_token or deploy_token> <conan command> --remote=gitlab
```

## Publier un paquet Conan {#publish-a-conan-package}

Publiez un paquet Conan dans le registre de paquets afin que toute personne ayant accès au projet puisse utiliser le paquet comme dépendance.

Prérequis :

- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).
- L'[authentification](#authenticate-to-the-package-registry) auprès du registre de paquets doit être configurée.
- Un [paquet Conan](https://docs.conan.io/en/latest/creating_packages/getting_started.html) local doit exister.
  - Pour un remote d'instance, le paquet doit respecter la [convention de nommage](#package-recipe-naming-convention-for-instance-remotes).
- Vous devez disposer de l'ID du projet, qui est affiché sur la [page de présentation du projet](../../project/working_with_projects.md#find-the-project-id).

Pour publier le paquet, utilisez la commande `conan upload` :

```shell
conan upload Hello/0.1@mycompany/beta --all
```

## Publier un paquet Conan à l'aide de CI/CD {#publish-a-conan-package-by-using-cicd}

Pour utiliser des commandes Conan dans [GitLab CI/CD](../../../ci/_index.md), vous pouvez utiliser `CI_JOB_TOKEN` à la place du jeton d'accès personnel dans vos commandes.

Vous pouvez fournir `CONAN_LOGIN_USERNAME` et `CONAN_PASSWORD` avec chaque commande Conan dans votre fichier `.gitlab-ci.yml`. Par exemple :

```yaml
create_package:
  image: conanio/gcc7
  stage: deploy
  script:
    - conan remote add gitlab ${CI_API_V4_URL}/projects/$CI_PROJECT_ID/packages/conan
    - conan new <package-name>/0.1 -t
    - conan create . <group-name>+<project-name>/stable
    - CONAN_LOGIN_USERNAME=ci_user CONAN_PASSWORD=${CI_JOB_TOKEN} conan upload <package-name>/0.1@<group-name>+<project-name>/stable --all --remote=gitlab
  environment: production
```

Des images Conan supplémentaires à utiliser comme base de votre fichier CI sont disponibles dans la [documentation Conan](https://docs.conan.io/en/latest/howtos/run_conan_in_docker.html#available-docker-images).

### Republier un paquet avec la même recette {#re-publishing-a-package-with-the-same-recipe}

Lorsque vous publiez un paquet qui possède la même recette (`package-name/version@user/channel`) qu'un paquet existant, les fichiers en double sont téléversés avec succès et sont accessibles via l'interface utilisateur. Cependant, lors de l'installation du paquet, seul le paquet publié le plus récemment est retourné.

## Installer un paquet Conan {#install-a-conan-package}

Installez un paquet Conan depuis le registre de paquets afin de l'utiliser comme dépendance. Vous pouvez installer un paquet depuis la portée de votre instance ou de votre projet. Si plusieurs paquets partagent la même recette, lors de l'installation d'un paquet, le paquet publié le plus récemment est récupéré.

Les paquets Conan sont souvent installés en tant que dépendances à l'aide du fichier `conanfile.txt`.

Prérequis :

- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).
- Pour les projets privés et internes, vous devez configurer l'[authentification](#authenticate-to-the-package-registry) auprès du registre de paquets.

1. Dans le projet où vous souhaitez installer le paquet comme dépendance, ouvrez `conanfile.txt`. Ou, à la racine de votre projet, créez un fichier appelé `conanfile.txt`.

1. Ajoutez la recette Conan à la section `[requires]` du fichier :

   ```plaintext
   [requires]
   Hello/0.1@mycompany/beta

   [generators]
   cmake
   ```

1. À la racine de votre projet, créez un répertoire `build` et accédez à ce répertoire :

   ```shell
   mkdir build && cd build
   ```

1. Installez les dépendances répertoriées dans `conanfile.txt` :

   ```shell
   conan install .. <options>
   ```

> [!note]
> Si vous essayez d'installer le paquet que vous avez créé dans ce tutoriel, la commande d'installation n'a aucun effet car le paquet existe déjà. Supprimez `~/.conan/data` pour nettoyer les paquets stockés dans le cache.

## Supprimer un paquet Conan {#remove-a-conan-package}

Il existe deux façons de supprimer un paquet Conan du registre de paquets GitLab.

- Depuis la ligne de commande, à l'aide du client Conan :

  ```shell
  conan remove Hello/0.2@user/channel --remote=gitlab
  ```

  Vous devez inclure explicitement le remote dans cette commande, sinon le paquet est supprimé uniquement de votre cache système local.

  > [!note]
  > Cette commande supprime tous les fichiers de recettes et de paquets binaires du registre de paquets.

- Depuis l'interface utilisateur GitLab :

  Accédez à **Déployer** > **Registre de paquets** de votre projet. Supprimez le paquet en sélectionnant **Supprimer le dépôt** ({{< icon name="remove" >}}).

## Rechercher des paquets Conan dans le registre de paquets {#search-for-conan-packages-in-the-package-registry}

Pour effectuer une recherche par nom de paquet complet ou partiel, ou par recette exacte, exécutez la commande `conan search`.

- Pour rechercher tous les paquets portant un nom de paquet spécifique :

  ```shell
  conan search Hello --remote=gitlab
  ```

- Pour rechercher un nom partiel, comme tous les paquets commençant par `He` :

  ```shell
  conan search He* --remote=gitlab
  ```

La portée de votre recherche dépend de votre configuration du remote Conan :

- Si vous avez un remote configuré pour votre [instance](#add-a-remote-for-your-instance), votre recherche inclut tous les projets auxquels vous avez l'autorisation d'accéder. Cela inclut vos projets privés ainsi que tous les projets publics.

- Si vous avez un remote configuré pour un [projet](#add-a-remote-for-your-project), votre recherche inclut tous les paquets du projet cible, à condition que vous ayez l'autorisation d'y accéder.

La limite des résultats de recherche est de 500 paquets, et les résultats sont triés par les paquets publiés le plus récemment.

> [!note]
> Lors de la recherche de paquets, l'interface de ligne de commande Conan v1 affiche uniquement les détails des paquets téléversés avec Conan v1. Les paquets téléversés avec Conan v2 apparaissent dans les résultats de recherche, mais leurs détails ne sont pas affichés. Cela est dû au fait que Conan v1 attend le champ `recipe_hash` dans les métadonnées de référence du paquet, qui n'est présent que dans les paquets téléversés avec Conan v1.

## Récupérer les informations d'un paquet Conan depuis le registre de paquets {#fetch-conan-package-information-from-the-package-registry}

La commande `conan info` retourne des informations sur un paquet :

```shell
conan info Hello/0.1@mycompany/beta
```

## Télécharger un paquet Conan {#download-a-conan-package}

> [!note]
> Les paquets téléversés avant l'activation de l'[extraction des métadonnées d'informations Conan](#extract-conan-metadata) ne peuvent pas être téléchargés avec la commande CLI `conan download`.

Vous pouvez télécharger la recette et les binaires d'un paquet Conan dans votre cache local sans utiliser de paramètres grâce à la commande `conan download`.

Prérequis :

- Le remote Conan [doit être configuré](#add-the-package-registry-as-a-conan-remote).
- Pour les projets privés et internes, vous devez configurer l'[authentification](#authenticate-to-the-package-registry) auprès du registre de paquets.

### Télécharger tous les paquets binaires {#download-all-binary-packages}

Vous pouvez télécharger tous les paquets binaires associés à une recette depuis le registre de paquets.

Pour télécharger tous les paquets binaires, exécutez la commande suivante :

```shell
conan download Hello/0.1@foo+bar/stable --remote=gitlab
```

### Télécharger les fichiers de recette {#download-recipe-files}

Vous pouvez télécharger uniquement les fichiers de recette sans aucun paquet binaire.

Pour télécharger les fichiers de recette, exécutez la commande suivante :

```shell
conan download Hello/0.1@foo+bar/stable --remote=gitlab --recipe
```

### Télécharger un paquet binaire spécifique {#download-a-specific-binary-package}

Vous pouvez télécharger un seul paquet binaire en référençant sa référence de paquet (connue sous le nom de `package_id` dans la documentation Conan).

Pour télécharger un paquet binaire spécifique, exécutez la commande suivante :

```shell
conan download Hello/0.1@foo+bar/stable:<package_reference> --remote=gitlab
```

## Commandes CLI prises en charge {#supported-cli-commands}

Le dépôt Conan GitLab prend en charge les commandes CLI Conan suivantes :

- `conan upload` : téléversez vos fichiers de recette et de paquet dans le registre de paquets.
- `conan install` : installez un paquet Conan depuis le registre de paquets, ce qui inclut l'utilisation du fichier `conanfile.txt`.
- `conan download` : téléchargez les recettes et les binaires de paquets dans votre cache local sans utiliser de paramètres.
- `conan search` : recherchez dans le registre de paquets les paquets publics et les paquets privés pour lesquels vous disposez d'une autorisation d'affichage.
- `conan info` : consultez les informations d'un paquet donné depuis le registre de paquets.
- `conan remove` : supprimez le paquet du registre de paquets.

## Extraire les métadonnées Conan {#extract-conan-metadata}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/178728) dans GitLab 17.10 [avec le feature flag](../../../administration/feature_flags/_index.md) `parse_conan_metadata_on_upload`. Fonctionnalité désactivée par défaut.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/186292) dans GitLab 17.11. Le feature flag `parse_conan_metadata_on_upload` a été supprimé.

{{< /history >}}

Lorsque vous téléversez un paquet Conan, GitLab extrait automatiquement les métadonnées du fichier `conaninfo.txt`. Ces métadonnées incluent :

- Paramètres du paquet (comme `os`, `arch`, `compiler` et `build_type`)
- Options du paquet
- Exigences et dépendances du paquet

> [!note]
> Les paquets téléversés avant l'activation de cette fonctionnalité (GitLab 17.10) n'ont pas leurs métadonnées extraites. Pour ces paquets, certaines fonctionnalités de recherche et de téléchargement sont limitées.

## Révisions Conan {#conan-revisions}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/519741) dans GitLab 18.1 [avec le feature flag](../../../administration/feature_flags/_index.md) `conan_package_revisions_support`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/groups/gitlab-org/-/work_items/14896) dans GitLab 18.3. Le feature flag `conan_package_revisions_support` a été supprimé.

{{< /history >}}

Les révisions Conan 1 garantissent l'immuabilité des paquets dans le registre de paquets. Lorsque vous apportez des modifications à une recette ou à un paquet sans en modifier la version, Conan calcule un identifiant unique (révision) pour suivre ces modifications.

> [!note]
> Les révisions Conan 1 sont prises en charge uniquement lorsque le remote est configuré sur un [projet](#add-a-remote-for-your-project), et non pour l'ensemble de l'[instance](#add-a-remote-for-your-instance).

### Types de révisions {#types-of-revisions}

Conan utilise deux types de révisions :

- **Révisions de recette (RREV)** : générées lors de l'exportation d'une recette. Par défaut, Conan calcule les révisions de recette à l'aide du hachage de somme de contrôle du manifeste de recette.
- **Révisions de paquet (PREV)** : générées lors de la compilation d'un paquet. Conan calcule les révisions de paquet à l'aide du hachage du contenu du paquet.

### Activer les révisions {#enable-revisions}

Les révisions ne sont pas activées par défaut dans Conan 1.x. Pour activer les révisions, vous devez :

- Ajouter `revisions_enabled=1` dans la section `[general]` de votre fichier `_conan.conf_` (recommandé).
- Définir la variable d'environnement `CONAN_REVISIONS_ENABLED=1`.

### Référencer les révisions {#reference-revisions}

Vous pouvez référencer des paquets dans les formats suivants :

| Référence                                          | Description                                                       |
| -------------------------------------------------- | ----------------------------------------------------------------- |
| `lib/1.0@conan/stable`                             | Le dernier RREV pour `lib/1.0@conan/stable`.                       |
| `lib/1.0@conan/stable#RREV`                        | Le RREV spécifique pour `lib/1.0@conan/stable`.                     |
| `lib/1.0@conan/stable#RREV:PACKAGE_REFERENCE`      | Un paquet binaire appartenant au RREV spécifique.               |
| `lib/1.0@conan/stable#RREV:PACKAGE_REFERENCE#PREV` | Une révision de paquet binaire PREV appartenant au RREV spécifique. |

### Téléverser des révisions {#upload-revisions}

Pour téléverser toutes les révisions et leurs binaires dans le registre de paquets GitLab :

```shell
conan upload package_name/version@user/channel#* --all --remote=gitlab
```

Lorsque vous téléversez plusieurs révisions, elles sont téléversées de la plus ancienne à la plus récente. L'ordre relatif est préservé dans le registre.

### Rechercher des révisions {#search-for-revisions}

Pour rechercher toutes les révisions d'une recette spécifique dans Conan v1 :

```shell
conan search package_name/version@user/channel --revisions --remote=gitlab
```

Cette commande affiche toutes les révisions disponibles pour la recette spécifiée, ainsi que leurs hachages de révision et leurs dates de création.

Pour obtenir des informations détaillées sur une révision spécifique :

```shell
conan search package_name/version@user/channel#revision_hash --remote=gitlab
```

Cette commande affiche les paquets binaires spécifiques disponibles pour cette révision.

### Supprimer des paquets avec des révisions {#delete-packages-with-revisions}

Vous pouvez supprimer des paquets à différents niveaux de granularité :

#### Supprimer une révision de recette spécifique {#delete-a-specific-recipe-revision}

Pour supprimer une révision de recette spécifique et tous ses paquets binaires associés :

```shell
conan remove package_name/version@user/channel#revision_hash --remote=gitlab
```

#### Supprimer des paquets pour une révision de recette spécifique {#delete-packages-for-a-specific-recipe-revision}

Pour supprimer tous les paquets associés à une révision de recette spécifique :

```shell
conan remove package_name/version@user/channel#revision_hash --packages --remote=gitlab
```

#### Supprimer un paquet spécifique dans une révision {#delete-a-specific-package-in-a-revision}

Pour supprimer un paquet spécifique dans une révision de recette, vous pouvez utiliser l'une de ces commandes :

```shell
conan remove package_name/version@user/channel#revision_hash -p package_id --remote=gitlab
```

Ou :

```shell
conan remove package_name/version@user/channel#revision_hash:package_id --remote=gitlab
```

> [!note]
> Lorsque vous supprimez des paquets avec des révisions, vous devez inclure l'indicateur `--remote=gitlab`. Sinon, le paquet est supprimé uniquement de votre cache système local.

### Workflow des révisions immuables {#immutable-revisions-workflow}

Les révisions sont conçues pour être immuables. Lorsque vous modifiez une recette ou son code source :

- Une nouvelle révision de recette est créée lorsque vous exportez une recette.
- Les binaires existants appartenant à la révision de recette précédente ne sont pas inclus. Vous devez compiler de nouveaux binaires pour la nouvelle révision de recette.
- Lorsque vous installez un paquet, Conan récupère automatiquement la dernière révision, sauf si vous en spécifiez une.

Pour les binaires de paquets, vous ne devez inclure qu'une seule révision de paquet par révision de recette et référence de paquet (connue sous le nom de `package_id` dans la documentation Conan). Plusieurs révisions de paquet pour la même révision de recette et le même ID de paquet indiquent qu'un paquet a été recompilé inutilement.

## Dépannage {#troubleshooting}

### Rendre la sortie verbeuse {#make-output-verbose}

Pour obtenir une sortie plus détaillée lors du dépannage d'un problème Conan :

```shell
export CONAN_TRACE_FILE=/tmp/conan_trace.log # Or SET in windows
conan <command>
```

Vous trouverez d'autres conseils de journalisation dans la [documentation Conan](https://docs.conan.io/en/latest/mastering/logging.html).

### Erreurs SSL {#ssl-errors}

Si vous utilisez un certificat auto-signé, il existe deux méthodes pour gérer les erreurs SSL avec Conan :

- Utilisez la commande `conan remote` pour désactiver la vérification SSL.
- Ajoutez le fichier `crt` de votre serveur au fichier `cacert.pem`.

Pour en savoir plus à ce sujet, consultez la [documentation Conan](https://docs.conan.io/en/latest/howtos/use_tls_certificates.html).
