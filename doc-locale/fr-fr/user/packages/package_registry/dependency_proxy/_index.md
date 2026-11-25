---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Proxy de dépendance pour les paquets
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

> [!warning]
> Le proxy de dépendance est en [version bêta](../../../../policy/development_stages_support.md#beta). Lisez attentivement la documentation avant d'utiliser cette fonctionnalité.

Le proxy de dépendance GitLab est un serveur proxy local qui télécharge et stocke des copies de paquets.

La première fois que vous demandez un paquet, GitLab le récupère depuis le registre de paquets en amont et en sauvegarde une copie dans votre projet. Lorsque vous demandez à nouveau le même paquet, GitLab fournit la copie sauvegardée dans le registre de paquets du projet.

Cette approche réduit le nombre de téléchargements depuis des sources externes et accélère les builds de paquets.

## Activer le proxy de dépendance {#enable-the-dependency-proxy}

Pour utiliser le proxy de dépendance pour les paquets, assurez-vous que votre projet est correctement configuré et que les utilisateurs qui tirent depuis le cache disposent de l'authentification nécessaire :

1. Dans la configuration globale, si les fonctionnalités suivantes sont désactivées, activez-les :
   - La [fonctionnalité `package`](../../../../administration/packages/_index.md#enable-or-disable-the-package-registry). Activés par défaut.
   - La [fonctionnalité `dependency_proxy`](../../../../administration/packages/dependency_proxy.md#turn-on-the-dependency-proxy). Activés par défaut.
1. Dans les paramètres du projet, si la [fonctionnalité `package`](../_index.md#turn-off-the-package-registry) est désactivée, activez-la. Elle est activée par défaut.
1. [Ajoutez une méthode d'authentification](#configure-a-client). Le proxy de dépendance prend en charge les mêmes [méthodes d'authentification](../supported_functionality.md#authenticate-with-the-registry) que le registre de paquets :
   - [Jeton d'accès personnel](../../../profile/personal_access_tokens.md)
   - [Jeton de déploiement de projet](../../../project/deploy_tokens/_index.md)
   - [Jeton de déploiement de groupe](../../../project/deploy_tokens/_index.md)
   - [Jeton de job](../../../../ci/jobs/ci_job_token.md)

## Mise en cache avancée {#advanced-caching}

Lorsque cela est possible, le proxy de dépendance pour les paquets utilise la mise en cache avancée pour stocker les paquets dans le registre de paquets du projet.

La mise en cache avancée vérifie la cohérence entre le registre de paquets du projet et le registre de paquets en amont. Si le registre en amont contient des fichiers mis à jour, le proxy de dépendance les utilise pour mettre à jour les fichiers mis en cache.

Lorsque la mise en cache avancée n'est pas prise en charge, le proxy de dépendance revient au comportement par défaut :

- Si le fichier demandé est trouvé dans le registre de paquets du projet, il est retourné.
- Si le fichier n'est pas trouvé, il est récupéré depuis le registre de paquets en amont.

La prise en charge de la mise en cache avancée dépend de la façon dont le registre de paquets en amont répond aux requêtes du proxy de dépendance, ainsi que du format de paquet utilisé.

Pour les paquets Maven :

| Registre de paquets                                                                                                                      | Mise en cache avancée prise en charge ? |
|---------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|
| [GitLab](../../maven_repository/_index.md)                                                                                            | {{< yes >}} |
| [Maven Central](https://mvnrepository.com/repos/central)                                                                              | {{< yes >}} |
| [Artifactory](https://jfrog.com/integrations/maven-repository/)                                                                        | {{< yes >}} |
| [Sonatype Nexus](https://help.sonatype.com/en/maven-repositories.html)                                                                | {{< yes >}} |
| [GitHub Packages](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-apache-maven-registry) | {{< no >}} |

### Autorisations {#permissions}

Lorsque le proxy de dépendance tire un fichier, voici ce qui se produit :

1. Le proxy de dépendance recherche un fichier dans le registre de paquets du projet. Il s'agit d'une opération de lecture.
1. Le proxy de dépendance peut publier un fichier de paquet dans le registre de paquets du projet. Il s'agit d'une opération d'écriture.

L'exécution des deux étapes dépend des autorisations de l'utilisateur. Le proxy de dépendance utilise les [mêmes autorisations que le registre de paquets](../_index.md#package-registry-visibility-permissions).

| Visibilité des projets | [Rôle](../../../permissions.md#roles) minimum | Peut lire les fichiers de paquets ? | Peut écrire des fichiers de paquets ? | Comportement |
|--------------------|-----------------------------------------------|-------------------------|--------------------------|----------|
| Public             | Anonyme                                     | {{< no >}}              | {{< no >}}               | Requête rejetée. |
| Public             | Invité                                         | {{< yes >}}             | {{< no >}}               | Fichier de paquet retourné depuis le cache ou le registre distant. |
| Public             | Développeur                                     | {{< yes >}}             | {{< yes >}}              | Fichier de paquet retourné depuis le cache ou le registre distant. Le fichier est publié dans le cache. |
| Interne           | Anonyme                                     | {{< no >}}              | {{< no >}}               | Requête rejetée |
| Interne           | Invité                                         | {{< yes >}}             | {{< no >}}               | Fichier de paquet retourné depuis le cache ou le registre distant. |
| Interne           | Développeur                                     | {{< yes >}}             | {{< yes >}}              | Fichier de paquet retourné depuis le cache ou le registre distant. Le fichier est publié dans le cache. |
| Privé            | Anonyme                                     | {{< no >}}              | {{< no >}}               | Requête rejetée |
| Privé            | Rapporteur                                      | {{< yes >}}             | {{< no >}}               | Fichier de paquet retourné depuis le cache ou le registre distant. |
| Privé            | Développeur                                     | {{< yes >}}             | {{< yes >}}              | Fichier de paquet retourné depuis le cache ou le registre distant. Le fichier est publié dans le cache. |

Au minimum, tout utilisateur pouvant utiliser le proxy de dépendance peut également utiliser le registre de paquets du projet.

Pour garantir que le cache est correctement alimenté au fil du temps, assurez-vous qu'un utilisateur disposant du rôle Développeur, Mainteneur ou Propriétaire tire les paquets avec le proxy de dépendance.

## Configurer un client {#configure-a-client}

La configuration d'un client pour le proxy de dépendance est similaire à la configuration d'un client pour le [registre de paquets](../supported_functionality.md#pulling-packages).

### Pour les paquets Maven {#for-maven-packages}

Pour les paquets Maven, [tous les clients pris en charge par le registre de paquets](../../maven_repository/_index.md) sont pris en charge par le proxy de dépendance :

- `mvn`
- `gradle`
- `sbt`

Pour l'authentification, vous pouvez utiliser toutes les méthodes acceptées par le [registre de paquets Maven](../../maven_repository/_index.md#edit-the-client-configuration). Nous vous recommandons d'utiliser la méthode [d'authentification HTTP de base](../../maven_repository/_index.md#basic-http-authentication), car elle est moins complexe.

Pour configurer le client :

1. Suivez les instructions de la section [Authentification HTTP de base](../../maven_repository/_index.md#basic-http-authentication).

   Assurez-vous d'utiliser l'URL de point de terminaison `https://gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven`.

1. Terminez la configuration pour votre client :

{{< tabs >}}

{{< tab title="mvn" >}}

L'[authentification HTTP de base](../../maven_repository/_index.md#basic-http-authentication) est acceptée. Cependant, nous vous recommandons d'utiliser l'[authentification par en-tête HTTP personnalisé](../../maven_repository/_index.md#custom-http-header), afin que `mvn` effectue moins de requêtes réseau.

Dans le fichier `pom.xml`, ajoutez un élément `repository` :

```xml
<repositories>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven</url>
  </repository>
</repositories>
```

Où :

- `<project_id>` est l'ID du projet à utiliser comme proxy de dépendance.
- `<id>` contient le nom du `<server>` utilisé dans la [configuration de l'authentification](../../maven_repository/_index.md#basic-http-authentication).

Par défaut, Maven Central est vérifié en premier via le [Super POM](https://maven.apache.org/guides/introduction/introduction-to-the-pom.html#Super_POM). Cependant, vous souhaiterez peut-être forcer `mvn` à vérifier le point de terminaison GitLab en premier. Pour ce faire, suivez les instructions de la section [transfert de requêtes](../../maven_repository/_index.md#additional-configuration-for-mvn).

{{< /tab >}}

{{< tab title="gradle" >}}

Ajoutez une section `repositories` à votre fichier [`build.gradle`](https://docs.gradle.org/current/userguide/tutorial_using_tasks.html).

- En Groovy DSL :

  ```groovy
  repositories {
      maven {
          url "https://gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven"
          name "GitLab"
          credentials(PasswordCredentials) {
              username = 'REPLACE_WITH_NAME'
              password = gitLabPrivateToken
          }
          authentication {
              basic(BasicAuthentication)
          }
      }
  }
  ```

- En Kotlin DSL :

  ```kotlin
  repositories {
      maven {
          url = uri("https://gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven")
          name = "GitLab"
          credentials(BasicAuthentication::class) {
              username = "REPLACE_WITH_NAME"
              password = findProperty("gitLabPrivateToken") as String?
          }
          authentication {
              create("basic", BasicAuthentication::class)
          }
      }
  }
  ```

Dans cet exemple :

- `<project_id>` est l'ID du projet à utiliser comme proxy de dépendance.
- `REPLACE_WITH_NAME` est expliqué dans la section [Authentification HTTP de base](../../maven_repository/_index.md#basic-http-authentication).

{{< /tab >}}

{{< tab title="sbt" >}}

Dans votre [`build.sbt`](https://www.scala-sbt.org/1.x/docs/Directories.html#sbt+build+definition+files), ajoutez les lignes suivantes :

```scala
resolvers += ("gitlab" at "https://gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven")

credentials += Credentials("GitLab Packages Registry", "<host>", "<name>", "<token>")
```

Dans cet exemple :

- `<project_id>` est l'ID du projet à utiliser comme proxy de dépendance.
- `<host>` est l'hôte présent dans `<endpoint url>` sans le schéma de protocole ni le port. Exemple : `gitlab.example.com`.
- `<name>` et `<token>` sont expliqués dans la section [Authentification HTTP de base](../../maven_repository/_index.md#basic-http-authentication).

{{< /tab >}}

{{< /tabs >}}

## Configurer le registre distant {#configure-the-remote-registry}

Le proxy de dépendance doit être configuré avec :

- L'URL du registre de paquets distant.
- Facultatif. Les identifiants requis.

Pour définir ces paramètres :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Paquets et registres**.
1. Développez **Registre de paquets**.
1. Sous **Proxy de dépendance**, remplissez le formulaire pour votre format de paquet :

{{< tabs >}}

{{< tab title="Maven" >}}

Tout registre de paquets Maven peut être connecté au proxy de dépendance. Vous pouvez autoriser la connexion avec le nom d'utilisateur et le mot de passe du registre de paquets Maven.

Pour définir ou mettre à jour le registre de paquets Maven distant, mettez à jour les champs suivants dans le formulaire :

- `URL` - L'URL du registre distant.
- `Username` - Facultatif. Le nom d'utilisateur à utiliser avec le registre distant.
- `Password` - Facultatif. Le mot de passe à utiliser avec le registre distant.

Vous devez soit définir à la fois le nom d'utilisateur et le mot de passe, soit laisser les deux champs vides.

{{< /tab >}}

{{< /tabs >}}

## Dépannage {#troubleshooting}

### Erreurs de tirage manuel de fichiers {#manual-file-pull-errors}

Vous pouvez tirer des fichiers manuellement avec cURL. Cependant, vous pourriez rencontrer l'une des réponses suivantes :

- `404 Not Found` - L'objet de paramètre du proxy de dépendance est introuvable parce qu'il n'existe pas ou parce que les [prérequis](#enable-the-dependency-proxy) n'ont pas été satisfaits.
- `401 Unauthorized` - L'utilisateur a été correctement authentifié mais ne disposait pas des autorisations nécessaires pour accéder à l'objet du proxy de dépendance.
- `403 Forbidden` - Un problème est survenu avec le [niveau de licence GitLab](#enable-the-dependency-proxy).
- `502 Bad Gateway` - Le registre de paquets distant n'a pas pu satisfaire la demande de fichier. Vérifiez les [paramètres du proxy de dépendance](#configure-the-remote-registry).
- `504 Gateway Timeout` - Le registre de paquets distant a expiré. Vérifiez les [paramètres du proxy de dépendance](#configure-the-remote-registry).

{{< tabs >}}

{{< tab title="Maven" >}}

```shell
curl --fail-with-body --verbose "https://<username>:<personal access token>@gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven/<group id and artifact id>/<version>/<file_name>"
```

- `<username>` et `<personal access token>` sont les identifiants permettant d'accéder au proxy de dépendance de l'instance GitLab.
- `<project_id>` est l'ID du projet.
- `<group id and artifact id>` représente le [group ID et l'artifact ID du paquet Maven](https://maven.apache.org/pom.html#Maven_Coordinates) joints par une barre oblique.
- `<version>` est la version du paquet.
- `file_name` est le nom exact du fichier.

Par exemple, pour un paquet avec :

- group ID : `com.my_company`.
- artifact ID : `my_package`.
- version : `1.2.3`.

La requête pour tirer manuellement un paquet est :

```shell
curl --fail-with-body --verbose "https://<username>:<personal access token>@gitlab.example.com/api/v4/projects/<project_id>/dependency_proxy/packages/maven/com/my_company/my_package/1.2.3/my_package-1.2.3.pom"
```

{{< /tab >}}

{{< /tabs >}}
