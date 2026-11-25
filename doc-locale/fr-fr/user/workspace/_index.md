---
stage: Create
group: Remote Development
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Les workspaces sont des environnements sandbox virtuels permettant de créer et de gérer vos environnements de développement GitLab.
title: Espaces de travail
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Un workspace est un environnement sandbox virtuel pour votre code dans GitLab. Vous pouvez utiliser des workspaces pour créer et gérer des environnements de développement isolés pour vos projets GitLab. Ces environnements garantissent que les différents projets n'interfèrent pas les uns avec les autres.

Chaque workspace comprend son propre ensemble de dépendances, de bibliothèques et d'outils, que vous pouvez personnaliser pour répondre aux besoins spécifiques de chaque projet.

Un workspace peut exister pendant une durée maximale d'environ un an civil, soit `8760` heures. Passé ce délai, il est automatiquement terminé.

Pour une démonstration interactive, consultez [GitLab workspaces](https://tech-marketing.gitlab.io/static-demos/workspaces/ws_html.html).

> [!note]
> Un workspace s'exécute sur tout cluster Kubernetes `linux/amd64` prenant en charge l'agent GitLab pour Kubernetes (`agentk`). Si vous devez exécuter des commandes `sudo`, ou créer et exécuter des conteneurs dans votre workspace, des exigences spécifiques à la plateforme peuvent s'appliquer.
>
> Pour plus d'informations, consultez [la compatibilité des plateformes](configuration.md#platform-compatibility).

## Workspaces et projets {#workspaces-and-projects}

Les workspaces ont une portée définie au niveau du projet. Lorsque vous créez un workspace, vous devez :

- Assigner le workspace à un projet spécifique.
- Sélectionner un projet avec un [devfile](#devfile).

Le workspace peut interagir avec l'API GitLab, avec le niveau d'accès défini par les autorisations de l'utilisateur actuel. Un workspace en cours d'exécution reste accessible à l'utilisateur même si ses autorisations sont révoquées ultérieurement.

### Gérer les workspaces depuis un projet {#manage-workspaces-from-a-project}

Pour gérer les workspaces depuis un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. En haut à droite, sélectionnez **Code**.
1. Dans la liste déroulante, sous **Vos espaces de travail**, vous pouvez :
   - Redémarrer, arrêter ou terminer un workspace existant.
   - Créer un nouveau workspace.

> [!warning]
> Lorsque vous terminez un workspace, GitLab supprime toutes les données non enregistrées ou non commitées dans ce workspace. Les données ne peuvent pas être récupérées.

### Suppression des ressources associées à un workspace {#deleting-resources-associated-with-a-workspace}

Lorsque vous terminez un workspace, vous supprimez toutes les ressources associées à ce workspace. Lorsque vous supprimez un projet, `agentk`, un utilisateur ou un jeton associé à un workspace en cours d'exécution :

- Le workspace est supprimé de l'interface utilisateur.
- Dans le cluster Kubernetes, les ressources du workspace en cours d'exécution deviennent orphelines et ne sont pas automatiquement supprimées.

Pour nettoyer les ressources orphelines, un administrateur doit supprimer manuellement le workspace dans Kubernetes.

[L'epic 11452](https://gitlab.com/groups/gitlab-org/-/work_items/11452) propose de modifier ce comportement.

## Gérer les workspaces au niveau de l'agent {#manage-workspaces-at-the-agent-level}

Pour gérer tous les workspaces associés à `agentk` :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.
1. Sélectionnez l'agent configuré pour le développement à distance.
1. Sélectionnez l'onglet **Espaces de travail**.
1. Dans la liste, vous pouvez redémarrer, arrêter ou terminer un workspace existant.

> [!warning]
> Lorsque vous terminez un workspace, GitLab supprime toutes les données non enregistrées ou non commitées dans ce workspace. Les données ne peuvent pas être récupérées.

### Identifier un agent depuis un workspace en cours d'exécution {#identify-an-agent-from-a-running-workspace}

Dans les déploiements contenant plusieurs installations `agentk`, vous pouvez vouloir identifier un agent depuis un workspace en cours d'exécution.

Pour identifier un agent associé à un workspace en cours d'exécution, utilisez l'un des endpoints GraphQL suivants :

- `agent-id` pour retourner le projet auquel appartient l'agent.
- `Query.workspaces` pour retourner :
  - L'agent de cluster associé au workspace.
  - Le projet auquel appartient l'agent.

## Devfile {#devfile}

Les workspaces disposent d'une prise en charge intégrée des devfiles. Les devfiles sont des fichiers qui définissent un environnement de développement en spécifiant les outils, langages, runtimes et autres composants nécessaires à un projet GitLab. Utilisez-les pour configurer automatiquement votre environnement de développement selon vos spécifications définies. Ils créent des environnements de développement cohérents et reproductibles, quelle que soit la machine ou la plateforme utilisée.

Les workspaces prennent en charge à la fois le devfile GitLab par défaut et les devfiles personnalisés.

### Devfile GitLab par défaut {#gitlab-default-devfile}

{{< history >}}

- [Introduit avec Go](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/171230) dans GitLab 17.8.
- [Prise en charge ajoutée pour Node, Ruby et Rust](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/185393) dans GitLab 17.9.
- [Prise en charge ajoutée pour Python, PHP, Java et GCC](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/188199) dans GitLab 18.0.

{{< /history >}}

Un devfile GitLab par défaut est disponible pour tous les projets lorsque vous créez un workspace. Ce devfile contient :

```yaml
schemaVersion: 2.2.0
components:
  - name: development-environment
    attributes:
      gl/inject-editor: true
    container:
      image: "registry.gitlab.com/gitlab-org/gitlab-build-images/workspaces/ubuntu-24.04:[VERSION_TAG]"
```

> [!note]
> Ce conteneur `image` est mis à jour régulièrement. `[VERSION_TAG]` est un espace réservé uniquement. Pour la dernière version, consultez le [`default_devfile.yaml` par défaut](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/remote_development/settings/default_devfile.yaml).

L'image par défaut du workspace inclut des outils de développement tels que Ruby, Node.js, Rust, Go, Python, Java, PHP, GCC, ainsi que leurs gestionnaires de paquets correspondants. Ces outils sont mis à jour régulièrement.

Un devfile GitLab par défaut peut ne pas convenir à toutes les configurations d'environnement de développement. Dans ces cas, vous pouvez créer un [devfile personnalisé](#custom-devfile).

### Devfile personnalisé {#custom-devfile}

Si vous avez besoin d'une configuration d'environnement de développement spécifique, créez un devfile personnalisé. Vous pouvez définir un devfile aux emplacements suivants, relatifs au répertoire racine de votre projet :

```plaintext
- /.devfile.yaml
- /.devfile.yml
- /.devfile/{devfile_name}.yaml
- /.devfile/{devfile_name}.yml
```

> [!note]
> Les devfiles doivent être placés directement dans le dossier `.devfile`. Les sous-dossiers imbriqués ne sont pas pris en charge. Par exemple, `.devfile/subfolder/devfile.yaml` n'est pas reconnu.

### Règles de validation {#validation-rules}

- La taille du devfile ne doit pas dépasser 3 Mo.

| Propriété        | Règle explicite                                                                                                                                                                                                                                                                                                          |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `schemaVersion` | Doit être [`2.2.0`](https://devfile.io/docs/2.2.0/devfile-schema).                                                                                                                                                                                                                                                       |
| `components`    | \- Le devfile doit comporter au moins un composant.<br/>\- Les noms ne doivent pas commencer par `gl-`.<br/>\- Seuls `container` et `volume` sont pris en charge.<br/>- `mountSources` et `sourceMapping` ne sont pas pris en charge.                                                                                                                  |
| `commands`      | \- Les identifiants ne doivent pas commencer par `gl-`.<br/>\- Seuls les types de commandes `exec` et `apply` sont pris en charge.<br/>\- Pour les commandes `exec`, seules les options suivantes sont prises en charge : `commandLine`, `component`, `label` et `hotReloadCapable`.<br/>\- Lorsque `hotReloadCapable` est spécifié pour les commandes `exec`, il doit être défini sur `false`. |
| `events`        | \- Les noms ne doivent pas commencer par `gl-`.<br/>\- Seuls `preStart` et `postStart` sont pris en charge.<br/>\- La norme Devfile autorise uniquement les commandes exec à être liées aux événements `postStart`. Si vous souhaitez utiliser une commande apply, vous devez utiliser un événement `preStart`.                                                                        |
| `parent`        | N'est pas pris en charge.                                                                                                                                                                                                                                                                                                      |
| `projects`           | N'est pas pris en charge.                                                                                                                                                                                                                                                                                                      |
| `starterProjects`     | N'est pas pris en charge.                                                                                                                                                                                                                                                                                                      |
| `variables`  | Les clés ne doivent pas commencer par `gl-`, `gl_`, `GL-` ou `GL_`.                                                                                                                                                                                                                                                                |
| `attributes`       | - `pod-overrides` ne doit pas être défini au niveau racine ni dans `components`.<br/>- `container-overrides` ne doit pas être défini dans `components`.                                                                                                                                                                                   |

### Type de composant `container` {#container-component-type}

Utilisez le type de composant `container` pour définir une image de conteneur comme environnement d'exécution d'un workspace. Vous pouvez spécifier l'image de base, les dépendances et d'autres paramètres.

Le type de composant `container` prend en charge uniquement les propriétés de schéma suivantes :

| Propriété             | Description |
|----------------------|-------------|
| `image`[^create-custom-container] | Nom de l'image de conteneur à utiliser pour le workspace. |
| `memoryRequest`      | Quantité minimale de mémoire que le conteneur peut utiliser. |
| `memoryLimit`        | Quantité maximale de mémoire que le conteneur peut utiliser. |
| `cpuRequest`         | Quantité minimale de CPU que le conteneur peut utiliser. |
| `cpuLimit`           | Quantité maximale de CPU que le conteneur peut utiliser. |
| `env`                | Variables d'environnement à utiliser dans le conteneur. Les noms ne doivent pas commencer par `gl-`. |
| `endpoints`          | Mappages de ports à exposer depuis le conteneur. Les noms ne doivent pas commencer par `gl-`. |
| `volumeMounts`       | Volume de stockage à monter dans le conteneur. |
| `command`            | La commande permettant de remplacer le point d'entrée du conteneur. Consultez [l'attribut `overrideCommand`](#overridecommand-attribute). |
| `args`               | Les arguments de la commande du conteneur. Consultez [l'attribut `overrideCommand`](#overridecommand-attribute). |

[^create-custom-container]: lorsque vous créez des images de conteneur personnalisées pour la propriété `image`, vous pouvez utiliser l'[image de base du workspace](#workspace-base-image) comme fondation. Elle inclut des configurations essentielles pour l'accès SSH, les autorisations utilisateur et la compatibilité du workspace. Si vous choisissez de ne pas utiliser l'image de base, assurez-vous que votre image personnalisée répond à toutes les exigences du workspace.

#### Attribut `overrideCommand` {#overridecommand-attribute}

L'attribut `overrideCommand` est un booléen qui contrôle la façon dont les workspaces gèrent les points d'entrée des conteneurs. Cet attribut détermine si le point d'entrée original du conteneur est conservé ou remplacé par une commande de maintien en vie.

La valeur par défaut de `overrideCommand` dépend du type de composant :

- Composant principal avec l'attribut `gl/inject-editor: true` : par défaut, `true` lorsqu'il n'est pas spécifié.
- Tous les autres composants : par défaut, `false` lorsqu'il n'est pas spécifié.

Lorsque la valeur est `true`, le point d'entrée du conteneur est remplacé par `tail -f /dev/null` pour maintenir le conteneur en cours d'exécution. Lorsque la valeur est `false`, le conteneur utilise soit le `command`/`args` du composant devfile, soit le `Entrypoint`/`Cmd` de l'image de conteneur intégrée.

Le tableau suivant montre comment `overrideCommand` affecte le comportement du conteneur. Pour plus de clarté, les termes suivants sont utilisés dans le tableau :

- Composant Devfile : les propriétés `command` et `args` dans l'entrée du composant devfile.
- Image de conteneur : les champs `Entrypoint` et `Cmd` dans l'image de conteneur OCI.

| `overrideCommand` | Composant Devfile | Image de conteneur | Résultat |
|-------------------|-------------------|-----------------|--------|
| `true`            | Spécifié         | Spécifié       | Erreur de validation : le `command`/`args` du composant Devfile ne peut pas être spécifié lorsque `overrideCommand` est `true`. |
| `true`            | Spécifié         | Non spécifié   | Erreur de validation : le `command`/`args` du composant Devfile ne peut pas être spécifié lorsque `overrideCommand` est `true`. |
| `true`            | Non spécifié     | Spécifié       | Point d'entrée du conteneur remplacé par `tail -f /dev/null`. |
| `true`            | Non spécifié     | Non spécifié   | Point d'entrée du conteneur remplacé par `tail -f /dev/null`. |
| `false`           | Spécifié         | Spécifié       | `command`/`args` du composant Devfile utilisé comme point d'entrée. |
| `false`           | Spécifié         | Non spécifié   | `command`/`args` du composant Devfile utilisé comme point d'entrée. |
| `false`           | Non spécifié     | Spécifié       | `Entrypoint`/`Cmd` de l'image de conteneur utilisé. |
| `false`           | Non spécifié     | Non spécifié   | Le conteneur se termine prématurément (`CrashLoopBackOff`).[^create-workspace-cannot] |

[^create-workspace-cannot]: lorsque vous créez un workspace, il ne peut pas accéder aux détails de l'image de conteneur, par exemple depuis des registres privés ou internes. Lorsque `overrideCommand` est `false` et que le Devfile ne spécifie pas `command` ni `args`, GitLab ne valide pas les images de conteneur et ne vérifie pas les champs `Entrypoint` ou `Cmd` requis. Vous devez vous assurer que le Devfile ou le conteneur spécifie ces champs, faute de quoi le conteneur se termine prématurément et le workspace ne démarre pas.

### Événements `postStart` définis par l'utilisateur {#user-defined-poststart-events}

Vous pouvez définir des événements `postStart` personnalisés dans votre devfile pour exécuter des commandes après le démarrage du workspace. Ces événements `postStart` ne bloquent pas l'accessibilité du workspace. Le workspace devient disponible dès que l'initialisation interne est terminée, même si vos commandes `postStart` personnalisées sont encore en cours d'exécution ou en attente d'exécution.

Utilisez ce type d'événement pour :

- Configurer les dépendances de développement.
- Configurer l'environnement du workspace.
- Exécuter des scripts d'initialisation.

Les noms d'événements `postStart` ne doivent pas commencer par `gl-` et ne peuvent référencer que des commandes de type `exec`.

Pour un exemple illustrant la configuration des événements `postStart`, consultez les [exemples de configurations](#example-configurations).

#### Répertoire de travail pour les commandes `postStart` {#working-directory-for-poststart-commands}

Par défaut, les commandes `postStart` s'exécutent dans des répertoires de travail différents selon le composant :

- Composant principal avec l'attribut `gl/inject-editor: true` : les commandes s'exécutent dans le répertoire du projet (`/projects/<project-path>`).
- Autres composants : les commandes s'exécutent dans le répertoire de travail par défaut du conteneur.

Vous pouvez remplacer le comportement par défaut en spécifiant un `workingDir` dans la définition de votre commande :

```yaml
commands:
  - id: install-dependencies
    exec:
      component: tooling-container
      commandLine: "npm install"
      workingDir: "/custom/path"
  - id: setup-project
    exec:
      component: tooling-container
      commandLine: "echo 'Setting up in project directory'"
      # Runs in project directory by default
```

#### Suivi de la progression des événements `postStart` {#monitor-poststart-event-progress}

Lorsque votre workspace exécute des événements `postStart`, vous pouvez suivre leur progression et consulter les journaux du workspace. Pour vérifier la progression de vos scripts `postStart` :

1. Ouvrez un terminal dans votre workspace.
1. Accédez au répertoire des journaux du workspace :

   ```shell
   cd /tmp/workspace-logs/
   ```

1. Consultez les journaux de sortie pour voir les résultats des commandes :

   ```shell
   tail -f poststart-stdout.log
   ```

Toutes les sorties des commandes `postStart` sont capturées dans des fichiers journaux situés dans le [répertoire des journaux du workspace](#workspace-logs-directory).

### Exemples de configurations {#example-configurations}

Voici un exemple de configuration de devfile :

```yaml
schemaVersion: 2.2.0
variables:
  registry-root: registry.gitlab.com
components:
  - name: tooling-container
    attributes:
      gl/inject-editor: true
    container:
      image: "{{registry-root}}/gitlab-org/remote-development/gitlab-remote-development-docs/ubuntu:22.04"
      env:
        - name: KEY
          value: VALUE
      endpoints:
        - name: http-3000
          targetPort: 3000
  - name: database-container
    attributes:
      overrideCommand: false
    container:
      image: mysql
      command: ["echo"]
      args: ["-n", "user-defined entrypoint command"]
      env:
        - name: MYSQL_ROOT_PASSWORD
          value: "my-secret-pw"
commands:
  # Command 1: Container 1, no working directory (uses project directory)
  - id: install-dependencies
    exec:
      component: tooling-container
      commandLine: "npm install"

  # Command 2: Container 1, with working directory
  - id: setup-environment
    exec:
      component: tooling-container
      commandLine: "echo 'Setting up development environment'"
      workingDir: "/home/gitlab-workspaces"

  # Command 3: Container 2, no working directory (uses container default)
  - id: init-database
    exec:
      component: database-container
      commandLine: "echo 'Database initialized' > db-init.log"

  # Command 4: Container 2, with working directory
  - id: setup-database
    exec:
      component: database-container
      commandLine: "mkdir -p /var/lib/mysql/logs && echo 'DB setup complete' > setup.log"
      workingDir: "/var/lib/mysql"

events:
  postStart:
    - install-dependencies
    - setup-environment
    - init-database
    - setup-database
```

> [!note]
> Ce conteneur `image` est fourni à titre de démonstration uniquement.

Pour d'autres exemples, consultez les [projets `examples`](https://gitlab.com/gitlab-org/workspaces/examples).

## Exigences relatives au conteneur du workspace {#workspace-container-requirements}

Par défaut, les workspaces injectent et démarrent le [fork GitLab VS Code](https://gitlab.com/gitlab-org/gitlab-web-ide-vscode-fork) dans le conteneur qui possède un attribut `gl/inject-editor` défini dans le devfile. Le conteneur du workspace dans lequel le fork GitLab VS Code est injecté doit satisfaire aux exigences système suivantes :

- Architecture système : AMD64
- Bibliothèques système :
  - `glibc` 2.28 et versions ultérieures
  - `glibcxx` 3.4.25 et versions ultérieures

Ces exigences ont été testées sur Debian 10.13 et Ubuntu 20.04.

> [!note]
> GitLab extrait toujours l'image de l'injecteur d'outils du workspace depuis le registre GitLab (`registry.gitlab.com`). Cette image ne peut pas être remplacée.
>
> Si vous utilisez un registre de conteneurs privé pour vos autres images, GitLab récupère ces images spécifiques depuis le registre GitLab. Cette exigence peut avoir un impact sur les environnements soumis à des contrôles réseau stricts, tels que les environnements hors ligne.

## Image de base du workspace {#workspace-base-image}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab-build-images/-/merge_requests/983) dans GitLab 18.3.

{{< /history >}}

GitLab fournit une image de base de workspace (`registry.gitlab.com/gitlab-org/gitlab-build-images:workspaces-base`) qui sert de fondation à tous les environnements de workspace.

L'image de base comprend :

- Une fondation stable de système d'exploitation Linux.
- Un utilisateur préconfiguré avec les autorisations appropriées pour les opérations du workspace.
- Des outils de développement essentiels et des bibliothèques système.
- La gestion des versions pour les langages de programmation et les outils.
- La configuration du serveur SSH pour l'accès à distance.
- Des configurations de sécurité pour la prise en charge des identifiants utilisateur arbitraires.

Si vous préférez ne pas utiliser l'image de base du workspace, vous pouvez créer une image de workspace personnalisée. Pour vous assurer que GitLab peut correctement initialiser et se connecter à votre image personnalisée, copiez les commandes de configuration nécessaires depuis le [Dockerfile de l'image de base](https://gitlab.com/gitlab-org/gitlab-build-images/-/blob/master/Dockerfile.workspaces-base) dans votre propre Dockerfile.

### Étendre l'image de base {#extend-the-base-image}

Vous pouvez créer des images de workspace personnalisées basées sur l'image de base du workspace. Par exemple :

```dockerfile
FROM registry.gitlab.com/gitlab-org/gitlab-build-images:workspaces-base

# Install additional tools
RUN sudo apt-get update && sudo apt-get install -y \
    your-additional-package \
    && sudo rm -rf /var/lib/apt/lists/*

# Install specific language versions
RUN mise install python@3.11 && mise use python@3.11
```

## Modules complémentaires du workspace {#workspace-add-ons}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/385157) dans GitLab 17.2.

{{< /history >}}

L'extension GitLab pour VS Code est configurée par défaut dans les workspaces.

Avec cette extension, vous pouvez consulter les tickets, créer des merge requests et gérer les pipelines CI/CD. Cette extension alimente également les fonctionnalités d'IA telles que GitLab Duo Code Suggestions et GitLab Duo Chat.

## Marketplace d'extensions {#extension-marketplace}

{{< details >}}

- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/438491) en version [bêta](../../policy/development_stages_support.md#beta) dans GitLab 16.9 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `allow_extensions_marketplace_in_workspace`. Fonctionnalité désactivée par défaut.
- Le feature flag `allow_extensions_marketplace_in_workspace` [supprimé](https://gitlab.com/gitlab-org/gitlab/-/issues/454669) dans GitLab 17.6.

{{< /history >}}

Le Marketplace d'extensions VS Code donne accès à des extensions qui améliorent les fonctionnalités de l'IDE Web. Par défaut, l'IDE Web GitLab se connecte au [registre Open VSX](https://open-vsx.org/).

Pour plus d'informations, consultez [configurer le Marketplace d'extensions VS Code](../../administration/settings/vscode_extension_marketplace.md).

## Jeton d'accès personnel {#personal-access-token}

{{< history >}}

- Permission `api` [ajoutée](https://gitlab.com/gitlab-org/gitlab/-/issues/385157) dans GitLab 17.2.

{{< /history >}}

Lorsque vous créez un workspace, vous obtenez un jeton d'accès personnel qui expire dans 365 jours avec les permissions `write_repository` et `api`. Ce jeton est utilisé pour cloner le projet initialement, lors du démarrage du workspace, et pour configurer l'extension GitLab pour VS Code.

Toute opération Git que vous effectuez dans le workspace utilise ce jeton pour l'authentification et l'autorisation. La fermeture du workspace révoque le jeton.

Utilisez les [variables d'environnement](https://git-scm.com/docs/git-config/#Documentation/git-config.txt-GITCONFIGCOUNT) `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_n` et `GIT_CONFIG_VALUE_n` pour l'authentification Git dans le workspace. Ces variables nécessitent Git 2.31 ou une version ultérieure dans le conteneur du workspace.

## Interaction des pods dans un cluster {#pod-interaction-in-a-cluster}

Les workspaces s'exécutent en tant que pods dans un cluster Kubernetes. GitLab n'impose aucune restriction sur la manière dont les pods interagissent les uns avec les autres.

Envisagez d'isoler cette fonctionnalité des autres conteneurs de votre cluster en raison de cette exigence.

## Accès réseau et autorisation du workspace {#network-access-and-workspace-authorization}

Il incombe au client de restreindre l'accès réseau au plan de contrôle Kubernetes, car GitLab n'a pas le contrôle sur l'API.

Seul le créateur du workspace peut accéder au workspace et à tous les endpoints exposés dans ce workspace. Le créateur du workspace n'est autorisé à accéder au workspace qu'après authentification de l'utilisateur via OAuth.

## Ressources de calcul et stockage de volumes {#compute-resources-and-volume-storage}

Lorsque vous arrêtez un workspace, GitLab réduit à zéro les ressources de calcul allouées à ce workspace. Cependant, le volume provisionné pour le workspace existe toujours.

Pour supprimer le volume provisionné, vous devez terminer le workspace.

## Arrêt et fermeture automatiques du workspace {#automatic-workspace-stop-and-termination}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/work_items/14910) dans GitLab 17.6.

{{< /history >}}

Par défaut, un workspace :

- S'arrête 36 heures après le dernier démarrage ou redémarrage du workspace.
- Est terminé 722 heures après le dernier arrêt du workspace.

## Identifiants utilisateur arbitraires {#arbitrary-user-ids}

Vous pouvez fournir votre propre image de conteneur, qui peut s'exécuter sous n'importe quel identifiant utilisateur Linux.

GitLab ne peut pas prédire l'identifiant utilisateur Linux pour une image de conteneur. GitLab utilise l'autorisation d'identifiant de groupe Linux `root` pour créer, mettre à jour ou supprimer des fichiers dans un conteneur. Le runtime de conteneur utilisé par le cluster Kubernetes doit s'assurer que tous les conteneurs ont un identifiant de groupe Linux par défaut de `0`.

Si vous disposez d'une image de conteneur qui ne prend pas en charge les identifiants utilisateur arbitraires, vous ne pouvez pas créer, mettre à jour ou supprimer des fichiers dans un workspace. Pour créer une image de conteneur prenant en charge les identifiants utilisateur arbitraires, consultez [créer une image de workspace personnalisée prenant en charge les identifiants utilisateur arbitraires](create_image.md).

## Répertoire des journaux du workspace {#workspace-logs-directory}

Lors du démarrage d'un workspace, GitLab crée un répertoire de journaux pour capturer les sorties des différents processus d'initialisation et de démarrage.

Les journaux du workspace sont stockés dans `/tmp/workspace-logs/`.

Ce répertoire vous aide à surveiller la progression du démarrage du workspace et à résoudre les problèmes liés aux événements `postStart`, aux outils de développement et aux autres composants du workspace. Pour plus d'informations, consultez [déboguer les événements `postStart`](workspaces_troubleshooting.md#debug-poststart-events).

### Fichiers journaux disponibles {#available-log-files}

Le répertoire des journaux contient les fichiers journaux suivants :

| Fichier journal               | Objectif                    | Contenu |
|------------------------|----------------------------|---------|
| `poststart-stdout.log` | Sortie des commandes `postStart` | Sortie standard de toutes les commandes `postStart`, y compris les commandes définies par l'utilisateur et les tâches de démarrage internes de GitLab. |
| `poststart-stderr.log` | Erreurs des commandes `postStart` | Sortie d'erreurs et `stderr` des commandes `postStart`. Vous pouvez utiliser ces journaux pour résoudre les problèmes liés aux scripts de démarrage échoués. |
| `start-vscode.log`     | Démarrage du serveur VS Code     | Journaux provenant de l'initialisation du serveur du fork GitLab VS Code. |
| `start-sshd.log`       | Démarrage du démon SSH         | Sortie de l'initialisation du démon SSH, incluant le démarrage du serveur et les détails de configuration. |
| `clone-unshallow.log`  | Conversion du dépôt Git  | Journaux du processus en arrière-plan qui convertit le clone superficiel en clone complet et récupère l'historique Git complet du projet. |

> [!note]
> Les fichiers journaux sont recréés à chaque redémarrage d'un workspace. Les fichiers journaux précédents ne sont pas conservés lorsque vous arrêtez et redémarrez un workspace.

## Clonage superficiel {#shallow-cloning}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/543982) dans GitLab 18.2 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `workspaces_shallow_clone_project`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/550330) dans GitLab 18.3.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/558154) dans GitLab 18.4. Le feature flag `workspaces_shallow_clone_project` a été supprimé.

{{< /history >}}

Lorsque vous créez un workspace, GitLab utilise le clonage superficiel pour améliorer les performances. Un clone superficiel télécharge uniquement le dernier historique de commit au lieu de l'historique Git complet, ce qui réduit considérablement le temps de clonage initial pour les dépôts volumineux.

Une fois le workspace démarré, Git convertit le clone superficiel en clone complet en arrière-plan. Ce processus est transparent et n'affecte pas votre workflow de développement.

## Sujets connexes {#related-topics}

- [Créer un workspace](configuration.md#create-a-workspace)
- [Paramètres du workspace](settings.md)
- [Dépannage des workspaces](workspaces_troubleshooting.md)
- [Suggestions de code GitLab Duo](../duo_agent_platform/code_suggestions/_index.md)
- [GitLab Duo Agentic Chat](../gitlab_duo_chat/agentic_chat.md)
- [Référence de l'API GraphQL](../../api/graphql/reference/_index.md)
- [Documentation Devfile](https://devfile.io/docs/2.2.0/devfile-schema)
- [Documentation OpenShift sur les identifiants utilisateur arbitraires](https://docs.openshift.com/container-platform/4.12/openshift_images/create-images.html#use-uid_create-images)
