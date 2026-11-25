---
stage: Package
group: Container Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Registre virtuel de conteneurs
description: Utilisez le registre virtuel de conteneurs pour mettre en cache des images de conteneurs provenant de registres upstream.
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/548794) dans GitLab 18.5 [avec le feature flag](../../../../administration/feature_flags/_index.md) `container_virtual_registries`. Fonctionnalité désactivée par défaut.
- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/work_items/589631) de version expérimentale à version bêta dans GitLab 18.9.
- [Activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/224250) dans GitLab 18.10.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique.

Le registre virtuel de conteneurs GitLab est un proxy local que vous pouvez utiliser pour mettre en cache des images de conteneurs provenant de registres upstream. Il agit comme un cache pull-through, en stockant localement les images fréquemment consultées afin de réduire la consommation de bande passante et d'améliorer les performances de build.

## Prérequis {#prerequisites}

Avant de pouvoir utiliser le registre virtuel de conteneurs :

- Consultez les [prérequis](../_index.md#prerequisites) pour utiliser le registre virtuel.
- Configurez l'authentification auprès du registre virtuel. Pour plus d'informations, consultez [S'authentifier auprès du registre virtuel](../_index.md#authenticate-to-the-virtual-registry).

Lorsque vous utilisez le registre virtuel de conteneurs, tenez compte des restrictions suivantes :

- Vous pouvez créer jusqu'à `5` registres virtuels de conteneurs par groupe principal.
- Vous pouvez définir uniquement `5` upstreams pour un registre virtuel de conteneurs donné.
- La prise en charge de Geo n'est pas implémentée.

## Gérer les registres virtuels {#manage-virtual-registries}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/19283) dans GitLab 18.10 [avec le feature flag](../../../../administration/feature_flags/_index.md) `ui_for_container_virtual_registries`.
- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/582167) dans GitLab 18.11 en flag nommé `container_virtual_registries`. Le feature flag `ui_for_container_virtual_registries` a été supprimé.

{{< /history >}}

Gérez les registres virtuels de conteneurs pour votre groupe.

Vous pouvez également [utiliser l'API](../../../../api/container_virtual_registries.md).

### Créer un registre virtuel de conteneurs {#create-a-container-virtual-registry}

Pour créer un registre virtuel de conteneurs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Selon votre situation :
   - Vous disposez d'un registre existant, sélectionnez **Créer un registre**. Dans la liste déroulante, sélectionnez **Conteneur**.
   - Vous ne disposez pas d'un registre existant, dans la liste déroulante, sélectionnez **Conteneur**. Ensuite, sélectionnez **Créer un registre**.
1. Saisissez un **Nom** et une **Description** facultative.
1. Sélectionnez **Créer un registre**.

## Gérer les registres upstream {#manage-upstream-registries}

Gérez les registres de conteneurs upstream dans un registre virtuel.

### Créer un registre upstream de conteneurs {#create-a-container-upstream-registry}

Créez un registre upstream de conteneurs pour vous connecter au registre virtuel.

Prérequis :

- Vous devez disposer d'un registre virtuel de conteneurs. Pour plus d'informations, consultez [Créer un registre virtuel](#create-a-container-virtual-registry).

Pour créer un registre upstream de conteneurs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sous l'onglet **Registres**, sélectionnez un registre.
1. Sélectionnez **Ajouter un upstream**. Si le registre virtuel dispose d'upstreams existants, dans la liste déroulante, sélectionnez l'une des options suivantes :
   - **Créer un nouvel upstream** pour configurer l'upstream.
   - **Relier à l'upstream existant** > **Sélectionner l'upstream existant**.
     1. Dans la liste déroulante, sélectionnez un upstream.
     1. Facultatif. Sélectionnez **Tester l'upstream** pour tester la connexion à l'upstream avant de le créer.
     1. Sélectionnez **Ajouter un upstream**.
1. Remplissez les champs.
   - Incluez à la fois un **nom_d_utilisateur** et un **mot de passe**, ou ni l'un ni l'autre. Si ces champs ne sont pas renseignés, une requête publique (anonyme) est utilisée pour accéder à l'upstream.
   - Si vous souhaitez connecter l'upstream à Docker Hardened Images, utilisez ce qui suit comme **URL de l'upstream** :

     ```plaintext
     https://dhi.io
     ```

   - Si vous souhaitez connecter l'upstream à Docker Hub, utilisez ce qui suit comme **URL de l'upstream** :

     ```plaintext
     https://registry-1.docker.io
     ```

     L'API du registre Docker Hub est hébergée sur `registry-1.docker.io`, et non sur `docker.io`. La plupart des outils de conteneurs réécrivent `docker.io` automatiquement, mais le registre virtuel fait un proxy vers l'URL que vous fournissez.

     Si vous utilisez `https://docker.io`, le registre renvoie du HTML au lieu de réponses OCI.

   - La **Période de mise en cache des artéfacts** est définie par défaut à 24 heures. Définissez la valeur à `0` pour désactiver les vérifications des entrées du cache.
   - Si vous souhaitez tester la connexion à l'upstream avant de le créer, sélectionnez **Tester l'upstream**.

1. Sélectionnez **Créer un upstream**.

Pour plus d'informations sur les paramètres de validité du cache, consultez [Définir la période de validité du cache](../_index.md#set-the-cache-validity-period).

## S'authentifier auprès du registre virtuel de conteneurs {#authenticate-with-the-container-virtual-registry}

Le registre virtuel de conteneurs stocke et associe des images de conteneurs dans un registre associé à votre groupe principal. Pour accéder aux images de conteneurs, vous devez vous authentifier auprès du registre virtuel de conteneurs de votre groupe.

Pour vous authentifier manuellement, exécutez la commande suivante :

```shell
echo "$CONTAINER_REGISTRY_PASSWORD" | docker login gitlab.example.com/virtual_registries/container/1 --username <your_username> --password-stdin
```

Ou configurez l'authentification avec l'une des méthodes décrites dans [S'authentifier auprès du registre virtuel](../_index.md#authenticate-to-the-virtual-registry).

Le registre virtuel de conteneurs suit le [flux d'authentification par jeton Docker v2](https://distribution.github.io/distribution/spec/auth/token/) :

1. Après l'authentification du client, un jeton JWT émis au client autorise ce dernier à récupérer des images de conteneurs.
1. Le jeton expire conformément à sa durée d'expiration.
1. Lorsque le jeton expire, la plupart des clients Docker stockent les identifiants de l'utilisateur et demandent automatiquement un nouveau jeton sans action supplémentaire.

## Récupérer des images de conteneurs depuis le registre virtuel {#pull-container-images-from-the-virtual-registry}

Pour récupérer une image de conteneur via le registre virtuel :

1. Authentifiez-vous auprès du registre virtuel.
1. Utilisez le format d'URL du registre virtuel pour récupérer des images :

   ```plaintext
   gitlab.example.com/virtual_registries/container/<registry_id>/<image_path>:<tag>
   ```

Par exemple :

- Récupérer une image par son tag :

  ```shell
  docker pull gitlab.example.com/virtual_registries/container/1/library/alpine:latest
  ```

- Récupérer une image par son condensé :

  ```shell
  docker pull gitlab.example.com/virtual_registries/container/1/library/alpine@sha256:c9375e662992791e3f39e919b26f510e5254b42792519c180aad254e6b38f4dc
  ```

- Récupérer une image dans un `Dockerfile` :

  ```dockerfile
  FROM gitlab.example.com/virtual_registries/container/1/library/alpine:latest
  ```

- Récupérer une image dans un fichier `.gitlab-ci.yml` :

  ```yaml
  image: gitlab.example.com/virtual_registries/container/1/library/alpine:latest
  ```

Lorsque vous récupérez une image, le registre virtuel :

1. Vérifie si l'image est déjà mise en cache.
   1. Si l'image est mise en cache et toujours valide selon le paramètre `cache_validity_hours` de l'upstream, l'image est servie depuis le cache.
   1. Si l'image n'est pas mise en cache ou si le cache est invalide, l'image est récupérée depuis le registre upstream configuré et mise en cache.
1. Transmet l'image à votre client Docker.

### Validation du cache du registre virtuel pour les images {#virtual-registry-cache-validation-for-images}

Un tag d'image tel que `alpine:latest` récupère toujours la version la plus récente de l'image. La nouvelle version contient un manifeste d'image mis à jour. Le registre virtuel de conteneurs ne récupère pas de nouvelle image lorsque le manifeste change.

À la place, le registre virtuel de conteneurs :

1. Vérifie le paramètre `cache_validity_hours` dans l'upstream pour déterminer quand un manifeste d'image est invalide.
1. Envoie une requête HEAD à l'upstream. Si le manifeste est invalide, une nouvelle image est récupérée.

Par exemple, si votre pipeline récupère `node:latest` et que vous avez défini le paramètre `cache_validity_period` à 24 heures, le registre virtuel met l'image en cache et la met à jour soit à l'expiration du cache, soit lorsque `node:latest` change dans l'upstream.

## Dépannage {#troubleshooting}

### Erreur d'authentification : `HTTP Basic: Access Denied` {#authentication-error-http-basic-access-denied}

Si vous recevez une erreur `HTTP Basic: Access denied` lors de l'authentification auprès du registre virtuel, consultez la [résolution des problèmes d'authentification à deux facteurs](../../../profile/account/two_factor_authentication_troubleshooting.md#error-http-basic-access-denied-if-a-password-was-provided-for-git-authentication-).

### Échec de connexion au registre virtuel {#virtual-registry-connection-failure}

Si aucun alias de service n'est défini, l'image `docker:20.10.16` est incapable de trouver le service `dind`, et une erreur semblable à la suivante est générée :

```plaintext
error during connect: Get http://docker:2376/v1.39/info: dial tcp: lookup docker on 192.168.0.1:53: no such host
```

Pour résoudre cette erreur, définissez un alias de service pour le service Docker :

```yaml
services:
  - name: docker:20.10.16-dind
    alias: docker
```

### Problèmes d'authentification du registre virtuel depuis les jobs CI/CD {#virtual-registry-authentication-issues-from-cicd-jobs}

GitLab Runner s'authentifie automatiquement à l'aide du jeton de job CI/CD. Cependant, le moteur Docker sous-jacent est toujours soumis à son [processus de résolution des autorisations](https://docs.gitlab.com/runner/configuration/advanced-configuration/#precedence-of-docker-authorization-resolving).

Des erreurs de configuration du mécanisme d'authentification peuvent provoquer des erreurs `HTTP Basic: Access denied` et `403: Access forbidden`.

Vous pouvez utiliser les job logs pour consulter le mécanisme d'authentification utilisé pour vous authentifier auprès du registre virtuel :

```plaintext
Authenticating with credentials from $DOCKER_AUTH_CONFIG
```

```plaintext
Authenticating with credentials from /root/.docker/config.json
```

```plaintext
Authenticating with credentials from job payload (GitLab Registry)
```

Assurez-vous d'utiliser le mécanisme d'authentification attendu.

### Erreur `Not Found` ou `404` lors de la récupération d'une image {#not-found-or-404-error-when-pulling-image}

Ces erreurs peuvent indiquer que :

- L'utilisateur exécutant le job ne dispose pas du rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner, ni d'un rôle personnalisé avec accès minimum disposant de la capacité `read_virtual_registry`, pour le groupe propriétaire du registre virtuel.
- L'identifiant du registre virtuel dans l'URL est incorrect.
- Le registre upstream ne contient pas l'image demandée.
- Le registre virtuel n'a aucun upstream configuré.

Exemples de messages d'erreur :

```plaintext
ERROR: gitlab.example.com/virtual_registries/container/1/library/alpine:latest: not found
```

```plaintext
ERROR: Job failed: failed to pull image "gitlab.example.com/virtual_registries/container/1/library/alpine:latest" with specified policies [always]:
Error response from daemon: error parsing HTTP 404 response body: unexpected end of JSON input: "" (manager.go:237:1s)
```

Pour résoudre ces erreurs :

1. Vérifiez que vous disposez du rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner, ou d'un rôle personnalisé avec accès minimum disposant de la capacité `read_virtual_registry`, pour le groupe.
1. Confirmez que l'identifiant du registre virtuel est correct.
1. Vérifiez que le registre virtuel dispose d'au moins un upstream configuré.
1. Vérifiez que l'image existe dans le registre upstream.

### Erreur : `unexpected EOF` lorsque le compartiment S3 a Object Lock activé {#error-unexpected-eof-when-the-s3-bucket-has-object-lock-enabled}

Lorsque le compartiment de stockage d'objets du proxy de dépendances a S3 Object Lock activé, les récupérations d'images de conteneurs peuvent échouer avec `unexpected EOF` en cours de téléchargement d'une couche.

Exemple d'erreur du client Docker :

```plaintext
sha256:9db411d588e2: Downloading [==================================================>]  12.18MB/12.18MB
unexpected EOF
```

Le journal GitLab Workhorse affiche une réponse `400` de l'appel S3 `PutObject` upstream :

```plaintext
operation error S3: PutObject, https response error StatusCode: 400, ...
InvalidRequest: Content-MD5 OR x-amz-checksum- HTTP header is required for
Put Object requests with Object Lock parameters
```

Lorsqu'un compartiment est configuré avec Object Lock, S3 exige que chaque requête `PutObject` inclue un en-tête d'intégrité. Par défaut, l'AWS SDK utilisé par Workhorse n'envoie pas ces en-têtes. L'upload échoue, ce qui tronque la réponse que Workhorse diffuse en streaming au client Docker.

Pour vérifier la cause :

1. Vérifiez si Object Lock est activé sur le compartiment du proxy de dépendances :

   ```shell
   aws s3api get-object-lock-configuration --bucket DEPENDENCY_PROXY_BUCKET
   ```

   Si Object Lock est activé, la réponse contient `"ObjectLockEnabled": "Enabled"`.
1. Inspectez le journal Workhorse lors d'une récupération en échec. Le message `InvalidRequest: Content-MD5 OR x-amz-checksum-` confirme la cause.

Pour résoudre le problème :

1. Configurez l'AWS SDK dans Workhorse pour envoyer des en-têtes de somme de contrôle. Définissez les deux variables d'environnement suivantes sur le conteneur Workhorse :

   - `AWS_REQUEST_CHECKSUM_CALCULATION=when_supported`
   - `AWS_RESPONSE_CHECKSUM_VALIDATION=when_supported`

1. Pour :
   - GitLab installé avec le chart Helm, ajoutez les variables à votre `values.yaml` :

   ```yaml
   gitlab:
     webservice:
       extraEnv:
         AWS_REQUEST_CHECKSUM_CALCULATION: when_supported
         AWS_RESPONSE_CHECKSUM_VALIDATION: when_supported
   ```

   Ensuite, appliquez les valeurs :

   ```shell
   helm upgrade gitlab gitlab/gitlab -f values.yaml
   ```

   - GitLab installé avec le package Linux, ajoutez les variables à `/etc/gitlab/gitlab.rb` :

   ```ruby
   gitlab_workhorse['env'] = {
     'AWS_REQUEST_CHECKSUM_CALCULATION' => 'when_supported',
     'AWS_RESPONSE_CHECKSUM_VALIDATION' => 'when_supported'
   }
   ```

   Ensuite, reconfigurez :

   ```shell
   sudo gitlab-ctl reconfigure
   ```

Une fois Workhorse redémarré avec les nouvelles variables d'environnement, relancez la récupération. La requête suivante stocke le blob dans S3 et renvoie la couche complète au client Docker.
