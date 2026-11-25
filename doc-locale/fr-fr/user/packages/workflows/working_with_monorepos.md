---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Workflows de gestion des paquets en monorepo
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Utilisez un projet monorepo comme registre de paquets pour publier des paquets dans plusieurs projets.

## Publier des paquets dans un projet et ses projets enfants {#publish-packages-to-a-project-and-its-child-projects}

Pour publier des paquets dans un projet et ses projets enfants, vous devez ajouter des fichiers de configuration pour chaque paquet. Pour apprendre à configurer des paquets pour un gestionnaire de paquets spécifique, consultez [Gestionnaires de paquets pris en charge](../package_registry/supported_functionality.md).

L'exemple suivant vous montre comment publier des paquets pour un projet et son projet enfant avec [npm](../npm_registry/_index.md).

Prérequis :

- Un [jeton d'accès personnel](../../profile/personal_access_tokens.md) avec la portée définie sur `api`.
- Un projet de test.

Dans cet exemple, `MyProject` est le projet parent. Il contient un projet enfant appelé `ChildProject` dans le répertoire `components` :

```plaintext
MyProject/
  |- src/
  |   |- components/
  |       |- ChildProject/
  |- package.json
```

Pour publier un paquet pour `MyProject` :

1. Accédez au répertoire `MyProject`.
1. Initialisez le projet en exécutant `npm init`. Assurez-vous que le nom du paquet respecte la [convention de nommage](../npm_registry/_index.md#naming-convention).
1. Créez un fichier `.npmrc`. Incluez l'URL du registre et le point de terminaison du projet. Par exemple :

   ```yaml
   //gitlab.example.com/api/v4/projects/<project_id>/packages/npm/:_authToken="${NPM_TOKEN}"
   @scope:registry=https://gitlab.example.com/api/v4/projects/<project_id>/packages/npm/
   ```

1. Publiez votre paquet depuis la ligne de commande. Remplacez `<token>` par votre jeton d'accès personnel :

   ```shell
   NPM_TOKEN=<token> npm publish
   ```

> [!warning]
> Ne codez jamais en dur des jetons GitLab (ou tout autre jeton) directement dans des fichiers `.npmrc` ou dans tout autre fichier pouvant être commité dans un dépôt.

Vous devriez voir le paquet pour `MyProject` publié dans le registre de paquets de votre projet.

Pour publier un paquet dans `ChildProject`, suivez les mêmes étapes. Le contenu du fichier `.npmrc` peut être identique à celui que vous avez ajouté dans `MyProject`.

Après avoir publié le paquet pour `ChildProject`, vous devriez voir le paquet dans le registre de paquets de votre projet.

## Publier des paquets dans d'autres projets {#publishing-packages-to-other-projects}

Un paquet est associé à un projet sur GitLab. Cependant, un paquet n'est pas associé au code de ce projet.

Par exemple, lors de la configuration d'un paquet pour npm ou Maven, le `project_id` définit l'URL du registre vers laquelle le paquet est publié.

Par exemple :

- npm : `https://gitlab.example.com/api/v4/projects/<project_id>/packages/npm/`
- maven : `https://gitlab.example.com/api/v4/projects/<project_id>/packages/maven/`

Si vous modifiez le `project_id` dans l'URL du registre pour pointer vers un autre projet, votre paquet est publié dans ce projet.

En modifiant le `project_id`, vous pouvez publier plusieurs paquets dans un seul projet, indépendamment du code. Pour plus d'informations, consultez [Stocker tous vos paquets dans un seul projet GitLab](project_registry.md).
