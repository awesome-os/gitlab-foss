---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Registre virtuel Maven
description: Utilisez le registre virtuel Maven pour configurer et gérer plusieurs registres upstream privés et publics.
---

{{< details >}}

- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/14137) dans GitLab 18.0 [avec le feature flag](../../../../administration/feature_flags/_index.md) `virtual_registry_maven`. Fonctionnalité désactivée par défaut.
- Feature flag [renommé](https://gitlab.com/gitlab-org/gitlab/-/issues/540276) en `maven_virtual_registry` dans GitLab 18.1.
- [Passage](https://gitlab.com/gitlab-org/gitlab/-/issues/540276) de la version expérimentale à la version bêta dans GitLab 18.1.
- [Activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197432) dans GitLab 18.2.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible en [version bêta](../../../../policy/development_stages_support.md#beta). Lisez attentivement la documentation avant d'utiliser cette fonctionnalité.

Le registre virtuel Maven utilise une URL unique et bien connue pour gérer et distribuer des packages provenant de plusieurs registres externes dans GitLab.

Utilisez le registre virtuel Maven pour :

- Créer un registre virtuel.
- Connecter le registre virtuel à des registres upstream publics et privés.
- Configurer les clients Maven pour extraire des packages à partir des upstreams configurés.
- Gérer les entrées de cache pour les upstreams disponibles.

Cette approche améliore les performances des packages au fil du temps et facilite la gestion de vos packages Maven.

Pour des informations générales sur la gestion des registres virtuels et des registres upstream, consultez [Registre virtuel](../_index.md).

## Prérequis {#prerequisites}

Avant de pouvoir utiliser le registre virtuel Maven :

- Consultez les [prérequis](../_index.md#prerequisites) pour utiliser le registre virtuel.
- Configurez l'authentification auprès du registre virtuel. Pour plus d'informations, consultez [S'authentifier auprès du registre virtuel](../_index.md#authenticate-to-the-virtual-registry).
- Sur GitLab Self-Managed : autorisez les requêtes sortantes vers le réseau local. Pour plus d'informations, consultez [autoriser les requêtes vers le réseau local](../../../../security/webhooks.md#allow-requests-to-the-local-network-from-webhooks-and-integrations).

Lors de l'utilisation du registre virtuel Maven, gardez à l'esprit les restrictions suivantes :

- Vous pouvez créer jusqu'à `20` registres virtuels Maven par groupe principal.
- Vous pouvez définir seulement `20` upstreams pour un registre virtuel Maven donné.
- Pour des raisons techniques, le paramètre `proxy_download` est activé de force, quelle que soit la valeur configurée dans la [configuration du stockage d'objets](../../../../administration/object_storage.md#proxy-download).
- La prise en charge de Geo n'est pas implémentée. Vous pouvez suivre son développement dans le [ticket 473033](https://gitlab.com/gitlab-org/gitlab/-/issues/473033).

## Gérer les registres virtuels {#manage-virtual-registries}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/epics/15090) dans GitLab 18.5 [avec le feature flag](../../../../administration/feature_flags/_index.md) `ui_for_virtual_registries`. Activés par défaut.
- [Modification](https://gitlab.com/gitlab-org/gitlab/-/issues/525934) dans GitLab 18.6 en un flag nommé `maven_virtual_registry`. Activés par défaut. Le feature flag `ui_for_virtual_registries` a été supprimé.

{{< /history >}}

Gérez les registres virtuels Maven pour votre groupe.

Vous pouvez également [utiliser l'API](../../../../api/maven_virtual_registries.md#manage-maven-virtual-registries).

### Créer un registre virtuel Maven {#create-a-maven-virtual-registry}

Pour créer un registre virtuel Maven :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Selon votre situation :
   - Si vous disposez d'un registre existant, sélectionnez **Créer un registre**. Dans la liste déroulante, sélectionnez **Maven**.
   - Si vous ne disposez pas d'un registre existant, dans la liste déroulante, sélectionnez **Maven**. Puis sélectionnez **Créer un registre**.
1. Saisissez un **Nom** et une **Description** facultative.
1. Sélectionnez **Créer un registre**.

## Gérer les registres upstream {#manage-upstream-registries}

Gérez les registres upstream Maven dans un registre virtuel.

### Créer un registre upstream Maven {#create-a-maven-upstream-registry}

Créez un registre upstream Maven pour le connecter au registre virtuel.

Prérequis :

- Vous devez disposer d'un registre virtuel Maven. Pour plus d'informations, consultez [Créer un registre virtuel](#create-a-maven-virtual-registry).

Pour créer un registre upstream Maven :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sous l'onglet **Registres**, sélectionnez un registre.
1. Sélectionnez **Ajouter un upstream**. Si le registre virtuel possède des upstreams existants, dans la liste déroulante, sélectionnez l'une des options suivantes :
   - **Créer un nouvel upstream** pour configurer l'upstream.
   - **Relier à l'upstream existant** > **Sélectionner l'upstream existant**.
     1. Dans la liste déroulante, sélectionnez un upstream.
     1. Facultatif. Sélectionnez **Tester l'upstream** pour tester la connexion à l'upstream avant de le créer.
     1. Sélectionnez **Ajouter un upstream**.
1. Remplissez les champs.
   - Indiquez à la fois un **nom_d_utilisateur** et un **mot de passe**, ou n'indiquez ni l'un ni l'autre. Si ces champs ne sont pas renseignés, une requête publique (anonyme) est utilisée pour accéder à l'upstream.
   - Si vous souhaitez connecter l'upstream à Maven Central, utilisez l'adresse suivante comme **URL de l'upstream** :

      ```plaintext
      https://repo1.maven.org/maven2
      ```

   - **Période de mise en cache des artéfacts** et **Période de mise en cache des métadonnées** sont définies par défaut à 24 heures. Définissez la valeur `0` pour désactiver les vérifications des entrées de cache, ou si vous utilisez Maven Central.
   - Si vous souhaitez tester la connexion à l'upstream avant de le créer, sélectionnez **Tester l'upstream**.

1. Sélectionnez **Créer un upstream**.

Pour plus d'informations sur les paramètres de validité du cache, consultez [Définir la période de validité du cache](../_index.md#set-the-cache-validity-period).

## Utiliser le registre virtuel Maven {#use-the-maven-virtual-registry}

Après avoir créé un registre virtuel, vous devez configurer les clients Maven pour extraire les dépendances via le registre virtuel.

### Configurer les clients Maven {#configure-maven-clients}

Le registre virtuel Maven prend en charge les clients Maven suivants :

- [`mvn`](https://maven.apache.org/index.html)
- [`gradle`](https://gradle.org/)
- [`sbt`](https://www.scala-sbt.org/)

Vous devez déclarer les registres virtuels dans la configuration du client Maven.

Tous les clients doivent être authentifiés. Pour l'authentification du client, vous pouvez utiliser un en-tête HTTP personnalisé ou l'authentification Basic Auth. Vous devez utiliser l'une des configurations ci-dessous pour chaque client.

{{< tabs >}}

{{< tab title="mvn" >}}

| Type de jeton            | Le nom doit être    | Jeton                                                                   |
| --------------------- | --------------- | ----------------------------------------------------------------------- |
| Jeton d'accès personnel | `Private-Token` | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton de déploiement de groupe    | `Deploy-Token`  | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton d'accès de groupe    | `Private-Token` | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton de job CI/CD          | `Job-Token`     | `${CI_JOB_TOKEN}`                                                       |
| Jeton OAuth 2.0       | `Authorization` | `Bearer <your_oauth_token>`                                             |

Ajoutez la section suivante à votre fichier [`settings.xml`](https://maven.apache.org/settings.html).

```xml
<settings>
  <servers>
    <server>
      <id>gitlab-maven</id>
      <configuration>
        <httpHeaders>
          <property>
            <name>REPLACE_WITH_NAME</name>
            <value>REPLACE_WITH_TOKEN</value>
          </property>
        </httpHeaders>
      </configuration>
    </server>
  </servers>
</settings>
```

Vous pouvez configurer le registre virtuel dans les applications `mvn` de deux manières :

- En tant que registre supplémentaire en plus du registre par défaut (Maven central). Dans cette configuration, vous pouvez extraire les dépendances du projet présentes à la fois dans le registre virtuel et dans le registre par défaut depuis l'un ou l'autre des registres déclarés.
- En tant que remplacement du registre par défaut (Maven central). Avec cette configuration, les dépendances sont extraites via le registre virtuel. Vous devez configurer Maven central comme dernier upstream du registre virtuel afin d'éviter de manquer des dépendances publiques requises.

Pour configurer un registre virtuel Maven en tant que registre supplémentaire, dans le fichier `pom.xml`, ajoutez un élément `repository` :

```xml
<repositories>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.example.com/api/v4/virtual_registries/packages/maven/<registry_id></url>
  </repository>
</repositories>
```

- `<id>` : l'identifiant identique à celui du `<server>` utilisé dans le `settings.xml`.
- `<registry_id>` : l'identifiant du registre virtuel Maven.

Pour configurer un registre virtuel Maven en tant que remplacement du registre par défaut, dans le `settings.xml`, ajoutez un élément `mirrors` :

```xml
<settings>
  <servers>
    ...
  </servers>
  <mirrors>
    <mirror>
      <id>central-proxy</id>
      <name>GitLab proxy of central repo</name>
      <url>https://gitlab.example.com/api/v4/virtual_registries/packages/maven/<registry_id></url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
</settings>
```

- `<registry_id>` : l'identifiant du registre virtuel Maven.

{{< /tab >}}

{{< tab title="gradle" >}}

| Type de jeton            | Le nom doit être    | Jeton                                                                   |
| --------------------- | --------------- | ----------------------------------------------------------------------- |
| Jeton d'accès personnel | `Private-Token` | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton de déploiement de groupe    | `Deploy-Token`  | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton d'accès de groupe    | `Private-Token` | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton de job CI/CD          | `Job-Token`     | `${CI_JOB_TOKEN}`                                                       |
| Jeton OAuth 2.0       | `Authorization` | `Bearer <your_oauth_token>`                                             |

Dans [votre répertoire `GRADLE_USER_HOME`](https://docs.gradle.org/current/userguide/directory_layout.html#dir:gradle_user_home), créez un fichier `gradle.properties` avec le contenu suivant :

```properties
gitLabPrivateToken=REPLACE_WITH_YOUR_TOKEN
```

Ajoutez une section `repositories` à votre [`build.gradle`](https://docs.gradle.org/current/userguide/tutorial_using_tasks.html).

- En Groovy DSL :

  ```groovy
  repositories {
      maven {
          url "https://gitlab.example.com/api/v4/virtual_registries/packages/maven/<registry_id>"
          name "GitLab"
          credentials(HttpHeaderCredentials) {
              name = 'REPLACE_WITH_NAME'
              value = gitLabPrivateToken
          }
          authentication {
              header(HttpHeaderAuthentication)
          }
      }
  }
  ```

- En Kotlin DSL :

  ```kotlin
  repositories {
      maven {
          url = uri("https://gitlab.example.com/api/v4/virtual_registries/packages/maven/<registry_id>")
          name = "GitLab"
          credentials(HttpHeaderCredentials::class) {
              name = "REPLACE_WITH_NAME"
              value = findProperty("gitLabPrivateToken") as String?
          }
          authentication {
              create("header", HttpHeaderAuthentication::class)
          }
      }
  }
  ```

- `<registry_id>` : l'identifiant du registre virtuel Maven.

{{< /tab >}}

{{< tab title="sbt" >}}

| Type de jeton            | Le nom d'utilisateur doit être                                        | Jeton                                                                   |
| --------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------- |
| Jeton d'accès personnel | Le nom d'utilisateur de l'utilisateur                                | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton de déploiement de groupe    | Le nom d'utilisateur du jeton de déploiement                            | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton d'accès de groupe    | Le nom d'utilisateur de l'utilisateur associé au jeton d'accès     | Collez le jeton tel quel ou définissez une variable d'environnement pour stocker le jeton. |
| Jeton de job CI/CD          | `gitlab-ci-token`                                       | `sys.env.get("CI_JOB_TOKEN").get`                                       |

L'authentification pour [SBT](https://www.scala-sbt.org/index.html) est basée sur l'[authentification HTTP de base](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication). Vous devez fournir un nom et un mot de passe.

Dans votre [`build.sbt`](https://www.scala-sbt.org/1.x/docs/Directories.html#sbt+build+definition+files), ajoutez les lignes suivantes :

```scala
resolvers += ("gitlab" at "<endpoint_url>")

credentials += Credentials("GitLab Virtual Registry", "<host>", "<username>", "<token>")
```

- `<endpoint_url>` : L'URL du registre virtuel Maven. Par exemple, `https://gitlab.example.com/api/v4/virtual_registries/packages/maven/<registry_id>`, où `<registry_id>` est l'identifiant du registre virtuel Maven.
- `<host>` : l'hôte présent dans le `<endpoint_url>` sans le schéma de protocole ni le port. Par exemple, `gitlab.example.com`.
- `<username>` : le nom d'utilisateur.
- `<token>` : le jeton configuré.

Assurez-vous que le premier argument de `Credentials` est `"GitLab Virtual Registry"`. Ce nom de realm doit correspondre exactement au [realm Basic Auth](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Authentication#www-authenticate_and_proxy-authenticate_headers) envoyé par le registre virtuel Maven.

{{< /tab >}}

{{< /tabs >}}

## Dépannage {#troubleshooting}

Lorsque vous utilisez des registres virtuels Maven, vous pouvez rencontrer les problèmes suivants.

### Erreur : `Connect to gitlab.example.com:443 failed: Connection timed out` {#error-connect-to-gitlabexamplecom443-failed-connection-timed-out}

Vous pouvez obtenir des erreurs de délai d'expiration de connexion intermittentes lors de l'extraction de dépendances Maven via le registre virtuel, par exemple :

```plaintext
Connect to gitlab.example.com:443 failed: Connect timed out
```

Ce problème peut se produire sur des instances GitLab Self-Managed lorsque l'URL du registre upstream est résolue en une adresse de réseau local. Par défaut, GitLab bloque les requêtes sortantes vers les adresses de réseau local pour des raisons de sécurité.

Pour résoudre ce problème :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres > Réseau**.
1. Développez **Requêtes sortantes**.
1. Cochez la case **Autoriser les requêtes vers le réseau local des crochets Web et des intégrations**.
1. Facultatif. Si vous préférez n'autoriser que des adresses spécifiques plutôt que toutes les requêtes du réseau local, dans **Adresses IP locales et noms de domaines auxquels les crochets et les intégrations peuvent accéder**, ajoutez le nom d'hôte ou l'adresse IP de votre registre upstream.
1. Sélectionnez **Enregistrer les modifications**.

Pour plus d'informations, consultez [autoriser les requêtes vers le réseau local](../../../../security/webhooks.md#allow-requests-to-the-local-network-from-webhooks-and-integrations).
