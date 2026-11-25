---
stage: Package
group: Container Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Réduire les transferts de données du registre de conteneurs
description: Conseils pour réduire la quantité de données transférées avec les registres de conteneurs GitLab.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Selon la fréquence à laquelle les images ou les tags sont téléchargés depuis le registre de conteneurs, les transferts de données peuvent être très importants. Cette page propose plusieurs recommandations et conseils pour réduire la quantité de données transférées avec le registre de conteneurs.

## Vérifier l'utilisation des transferts de données {#check-data-transfer-use}

L'utilisation des transferts n'est pas disponible dans l'interface utilisateur GitLab. [GitLab-#350905](https://gitlab.com/gitlab-org/gitlab/-/issues/350905) est l'epic qui suit les travaux visant à exposer ces informations.

## Déterminer la taille d'une image {#determine-image-size}

Utilisez ces outils et techniques pour déterminer la taille de votre image :

- [Skopeo](https://github.com/podman-container-tools/skopeo) : utilisez la commande Skopeo `inspect` pour examiner le nombre de couches et leurs tailles via des appels API. Vous pouvez ainsi inspecter ces données avant d'exécuter `docker pull IMAGE`.

- Docker dans CI : examinez et enregistrez la taille de l'image lors de l'utilisation de GitLab CI avant de pousser une image avec Docker. Par exemple :

  ```shell
  docker inspect "$CI_REGISTRY_IMAGE:$IMAGE_TAG" \
        | awk '/"Size": ([0-9]+)[,]?/{ printf "Final Image Size: %d\n", $2 }'
  ```

- [Dive](https://github.com/wagoodman/dive) est un outil permettant d'explorer une image Docker, le contenu de ses couches, et de découvrir des moyens de réduire sa taille.

## Réduire la taille d'une image {#reduce-image-size}

### Utiliser une image de base plus légère {#use-a-smaller-base-image}

Envisagez d'utiliser une image de base plus légère, telle que [Alpine Linux](https://alpinelinux.org/). Une image Alpine pèse environ 5 Mo, ce qui est plusieurs fois plus léger que les images de base populaires telles que [Debian](https://hub.docker.com/_/debian). Si votre application est distribuée sous forme de binaire statique autonome, comme pour les applications Go, vous pouvez également envisager d'utiliser l'image de base Docker [scratch](https://hub.docker.com/_/scratch/).

Si vous devez utiliser un système d'exploitation d'image de base spécifique, recherchez les variantes `-slim` ou `-minimal`, car elles permettent de réduire la taille de l'image.

Soyez également attentif aux paquets du système d'exploitation que vous installez par-dessus votre image de base. Ceux-ci peuvent représenter plusieurs centaines de mégaoctets. Essayez de limiter le nombre de paquets installés au strict minimum.

Les [builds multi-étapes](#use-multi-stage-builds) peuvent être un allié puissant pour supprimer les dépendances de build transitoires.

Vous pouvez également envisager d'utiliser des outils tels que :

- [DockerSlim](https://github.com/docker-slim/docker-slim) fournit un ensemble de commandes pour réduire la taille de vos images de conteneurs.
- Les images [Distroless](https://github.com/GoogleContainerTools/distroless) ne contiennent que votre application et ses dépendances d'exécution. Elles ne contiennent pas de gestionnaires de paquets, de shells ni aucun autre programme que l'on s'attendrait à trouver dans une distribution Linux standard.

### Minimiser les couches {#minimize-layers}

Chaque instruction dans votre Dockerfile crée une nouvelle couche, qui enregistre les modifications du système de fichiers appliquées lors de cette instruction. En général, des couches plus nombreuses ou plus volumineuses conduisent à des images plus grandes. Essayez de minimiser le nombre de couches pour installer les paquets dans le Dockerfile. Dans le cas contraire, chaque étape du processus de build peut augmenter la taille de l'image.

Il existe plusieurs stratégies pour réduire le nombre et la taille des couches. Par exemple, plutôt que d'utiliser une commande `RUN` par paquet du système d'exploitation à installer (ce qui créerait une couche par paquet), vous pouvez installer tous les paquets avec une seule commande `RUN` pour réduire le nombre d'étapes dans le processus de build et diminuer la taille de l'image.

Une autre stratégie utile consiste à supprimer toutes les dépendances de build transitoires et à désactiver ou vider le cache du gestionnaire de paquets du système d'exploitation avant et après l'installation d'un paquet.

Lors de la création de vos images, assurez-vous de ne copier que les fichiers pertinents. Pour Docker, l'utilisation d'un fichier [`.dockerignore`](https://docs.docker.com/reference/dockerfile/#dockerignore-file) permet de s'assurer que le processus de build ignore les fichiers non pertinents.

Vous pouvez utiliser d'autres outils tiers pour minifier vos images, tels que [DockerSlim](https://github.com/docker-slim/docker-slim). Sachez que, s'ils sont utilisés de manière incorrecte, ces outils peuvent supprimer des dépendances dont votre application a besoin pour fonctionner dans certaines conditions. Il est donc préférable de chercher à obtenir des images plus légères dès le processus de build plutôt que d'essayer de les minifier a posteriori.

### Utiliser les builds multi-étapes {#use-multi-stage-builds}

Avec les [builds multi-étapes](https://docs.docker.com/build/building/multi-stage/), vous utilisez plusieurs instructions `FROM` dans votre Dockerfile. Chaque instruction `FROM` peut utiliser une base différente et chacune commence une nouvelle étape de build. Vous pouvez copier sélectivement des artefacts d'une étape à une autre, en laissant de côté tout ce que vous ne souhaitez pas inclure dans l'image finale. Cela est particulièrement utile lorsque vous devez installer des dépendances de build, mais que vous n'avez pas besoin qu'elles soient présentes dans votre image finale.

## Utiliser une politique de pull d'image {#use-an-image-pull-policy}

Lorsque vous utilisez les exécuteurs `docker` ou `docker+machine`, vous pouvez définir un paramètre [`pull_policy`](https://docs.gitlab.com/runner/executors/docker/#using-the-if-not-present-pull-policy) dans le fichier `config.toml` de votre runner, qui définit le comportement du runner lors du pull d'images Docker. Pour éviter les transferts de données lors de l'utilisation d'images volumineuses et rarement mises à jour, envisagez d'utiliser la politique de pull `if-not-present` lors du pull d'images depuis des registres distants.

## Utiliser la mise en cache des couches Docker {#use-docker-layer-caching}

La mise en cache des couches Docker peut accélérer vos builds et réduire la quantité de données transférées. Pour plus d'informations, consultez [Mettre en cache les couches Docker dans les builds Docker-in-Docker](../../../ci/docker/docker_layer_caching.md).

## Vérifier la fréquence d'automatisation {#check-automation-frequency}

Nous créons souvent des scripts d'automatisation intégrés dans des images de conteneurs pour effectuer des tâches régulières à des intervalles spécifiques. Vous pouvez réduire la fréquence de ces intervalles dans les cas où l'automatisation extrait des images de conteneurs depuis le registre GitLab vers un service extérieur à GitLab.com.

## Tickets associés {#related-issues}

- Vous souhaiterez peut-être reconstruire votre image lorsque l'image Docker de base est mise à jour. Cependant, la [limite d'abonnement aux pipelines est trop basse](https://gitlab.com/gitlab-org/gitlab/-/issues/225278) pour exploiter cette fonctionnalité. Pour contourner ce problème, vous pouvez reconstruire l'image quotidiennement ou plusieurs fois par jour. [GitLab-#225278](https://gitlab.com/gitlab-org/gitlab/-/issues/225278) propose de relever la limite pour faciliter ce workflow.
