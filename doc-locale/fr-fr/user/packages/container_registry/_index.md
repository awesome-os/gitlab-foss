---
stage: Package
group: Container Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Registre de conteneurs GitLab
description: Utilisez le registre de conteneurs GitLab pour stocker des images de conteneurs pour votre projet GitLab.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez utiliser le registre de conteneurs intégré pour stocker des images de conteneurs pour chaque projet GitLab.

Un administrateur doit activer le registre de conteneurs pour votre instance GitLab. Pour plus d'informations, consultez [Administration du registre de conteneurs GitLab](../../../administration/packages/container_registry.md).

> [!note]
> Si vous téléchargez des images de conteneurs depuis Docker Hub, vous pouvez utiliser le [proxy de dépendances GitLab](../dependency_proxy/_index.md#use-the-dependency-proxy-for-docker-images) pour éviter les limites de débit et accélérer vos pipelines.

## Afficher le registre de conteneurs {#view-the-container-registry}

Vous pouvez afficher le registre de conteneurs pour un projet ou un groupe.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Registre de conteneurs**.

Vous pouvez rechercher, trier, filtrer et [supprimer](delete_container_registry_images.md#use-the-gitlab-ui) vos images de conteneurs. Vous pouvez partager une vue filtrée en copiant l'URL depuis votre navigateur.

### Afficher les tags d'une image de conteneur spécifique dans le registre de conteneurs {#view-the-tags-of-a-specific-container-image-in-the-container-registry}

Vous pouvez utiliser la page **Détails du tag** du registre de conteneurs pour afficher la liste des tags associés à une image de conteneur donnée :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Registre de conteneurs**.
1. Sélectionnez votre image de conteneur.

Vous pouvez afficher les détails de chaque tag, notamment la date de publication, l'espace de stockage consommé, ainsi que les condensés du manifeste et de la configuration.

Vous pouvez rechercher, trier et supprimer des tags sur cette page. Les tags sont triés par **Nom**. Si la base de données de métadonnées du registre de conteneurs est activée, vous pouvez également trier par **Publié**, ce qui est le paramètre par défaut et affiche en premier les tags publiés le plus récemment. Vous pouvez partager une vue filtrée en copiant l'URL depuis votre navigateur.

### Afficher les plateformes prises en charge pour les images multi-architectures {#view-supported-platforms-for-multi-architecture-images}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/228384) dans GitLab 19.1 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `container_registry_display_supported_platforms`. Fonctionnalité désactivée par défaut.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/240791) dans GitLab 19.2. Le feature flag `container_registry_display_supported_platforms` a été supprimé.

{{< /history >}}

Affichez les tags pointant vers une liste de manifestes Docker ou un index d'images OCI (images multi-architectures) pour voir les plateformes qu'ils prennent en charge.

Prérequis :

- Pour GitLab Self-Managed, un registre de conteneurs configuré avec une base de données de métadonnées. Pour plus d'informations, consultez [base de données de métadonnées du registre de conteneurs](../../../administration/packages/container_registry_metadata_database.md).

Pour afficher les plateformes prises en charge :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Registre de conteneurs**.
1. Sélectionnez une image de conteneur.
1. Développez les détails d'un tag multi-architectures.

Une ligne **Plateformes prises en charge** affiche un badge pour chaque plateforme, par exemple `linux/amd64` ou `linux/arm64/v8`. Pour les images Windows, les numéros de build connus sont associés à des libellés compréhensibles, par exemple `windows/amd64 (ltsc2022)`.

### Utilisation du stockage {#storage-usage}

Consultez l'utilisation du stockage du registre de conteneurs pour suivre et gérer la taille de vos dépôts de conteneurs dans vos projets et groupes.

Pour plus d'informations, consultez [afficher l'utilisation du registre de conteneurs](reduce_container_registry_storage.md#view-container-registry-usage).

## Utiliser des images de conteneurs depuis le registre de conteneurs {#use-container-images-from-the-container-registry}

Pour télécharger et exécuter une image de conteneur hébergée dans le registre de conteneurs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Registre de conteneurs**.
1. Recherchez l'image de conteneur avec laquelle vous souhaitez travailler et sélectionnez **Copier le chemin d'accès à l'image** ({{< icon name="copy-to-clipboard" >}}).
1. Utilisez `docker run` avec le lien copié :

   ```shell
   docker run [options] registry.example.com/group/project/image [arguments]
   ```

> [!note]
> Vous devez vous authentifier auprès du registre de conteneurs pour télécharger des images de conteneurs depuis un dépôt privé. Pour plus d'informations, consultez [s'authentifier auprès du registre de conteneurs](authenticate_with_container_registry.md).

## Convention de nommage pour vos images de conteneurs {#naming-convention-for-your-container-images}

Vos images de conteneurs doivent respecter cette convention de nommage :

```plaintext
<registry server>/<namespace>/<project>[/<optional path>]
```

Par exemple, si votre projet est `gitlab.example.com/mynamespace/myproject`, votre image de conteneur doit être nommée `gitlab.example.com/mynamespace/myproject`.

Vous pouvez ajouter des noms supplémentaires à la fin d'un nom d'image de conteneur, jusqu'à deux niveaux de profondeur.

Par exemple, les noms suivants sont tous des noms valides pour des images de conteneurs dans le projet nommé `myproject` :

```plaintext
registry.example.com/mynamespace/myproject:some-tag
```

```plaintext
registry.example.com/mynamespace/myproject/image:latest
```

```plaintext
registry.example.com/mynamespace/myproject/my/image:rc1
```

## Déplacer ou renommer des dépôts du registre de conteneurs {#move-or-rename-container-registry-repositories}

Le chemin d'un dépôt de conteneurs correspond toujours au chemin du dépôt du projet associé. Il n'est donc pas possible de renommer ou de déplacer uniquement le registre de conteneurs. À la place, vous pouvez :

- [Renommer le dépôt du projet](../../project/working_with_projects.md#rename-a-repository).
- [Transférer le projet](../../project/working_with_projects.md#transfer-a-project).

Pour des raisons de performances, le renommage de projets dont les dépôts de conteneurs sont remplis est limité aux projets comportant jusqu'à 1 000 dépôts de conteneurs.

Sur une instance GitLab Self-Managed, vous pouvez supprimer toutes les images de conteneurs avant de déplacer ou de renommer un groupe ou un projet. Par ailleurs, [le ticket 18383](https://gitlab.com/gitlab-org/gitlab/-/issues/18383#possible-workaround) contient des suggestions de la communauté pour contourner cette limitation. [L'epic 9459](https://gitlab.com/groups/gitlab-org/-/epics/9459) propose d'ajouter la prise en charge du déplacement de projets et de groupes avec des dépôts de conteneurs vers GitLab Self-Managed.

## Désactiver le registre de conteneurs pour un projet {#disable-the-container-registry-for-a-project}

Le registre de conteneurs est activé par défaut.

Vous pouvez toutefois supprimer le registre de conteneurs pour un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Visibilité, fonctionnalités du projet, autorisations** et désactivez **Registre de conteneurs**.
1. Sélectionnez **Enregistrer les modifications**.

L'entrée **Déployer** > **Registre de conteneurs** est supprimée de la barre latérale du projet.

## Modifier la visibilité du registre de conteneurs {#change-visibility-of-the-container-registry}

Par défaut, le registre de conteneurs est visible par toutes les personnes ayant accès au projet. Vous pouvez toutefois modifier la visibilité du registre de conteneurs pour un projet.

Pour plus d'informations sur les autorisations que ce paramètre accorde aux utilisateurs, consultez [les autorisations de visibilité du registre de conteneurs](#container-registry-visibility-permissions).

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Visibilité, fonctionnalités du projet, autorisations**.
1. Sous **Registre de conteneurs**, sélectionnez une option dans la liste déroulante :

   - **Toute personne ayant accès** (par défaut) : le registre de conteneurs est visible par toutes les personnes ayant accès au projet. Si le projet est public, le registre de conteneurs est également public. Si le projet est interne ou privé, le registre de conteneurs est également interne ou privé.

   - **Uniquement les membres du projet** : le registre de conteneurs est visible uniquement par les membres du projet ayant le rôle Reporter, Developer, Maintainer ou Owner. Cette visibilité est similaire au comportement d'un projet privé dont la visibilité du registre de conteneurs est définie sur **Toute personne ayant accès**.

1. Sélectionnez **Enregistrer les modifications**.

## Autorisations de visibilité du registre de conteneurs {#container-registry-visibility-permissions}

La possibilité d'afficher le registre de conteneurs et de télécharger des images de conteneurs est contrôlée par les autorisations de visibilité du registre de conteneurs. Vous pouvez modifier la visibilité via le paramètre de visibilité de l'interface utilisateur ou via l'[API](../../../api/container_registry.md#change-the-visibility-of-the-container-registry).

Les autres autorisations, telles que la mise à jour du registre de conteneurs et le push ou la suppression d'images de conteneurs, ne sont pas affectées par ce paramètre. Cependant, la désactivation du registre de conteneurs désactive toutes les opérations du registre de conteneurs. Pour plus d'informations, consultez [rôles et autorisations](../../permissions.md).

|                                                                                                                   |                                               | Anonyme<br/>(Tout le monde sur Internet) | Invité | Reporter, Developer, Maintainer, Owner |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------|--------------------------------------|-------|----------------------------------------|
| Projet public avec visibilité du registre de conteneurs <br/> définie sur **Toute personne ayant accès** (interface utilisateur) ou `enabled` (API)   | Afficher le registre de conteneurs <br/> et télécharger des images | Oui                                  | Oui   | Oui                                    |
| Projet public avec visibilité du registre de conteneurs <br/> définie sur **Uniquement les membres du projet** (interface utilisateur) ou `private` (API)   | Afficher le registre de conteneurs <br/> et télécharger des images | Non                                   | Non    | Oui                                    |
| Projet interne avec visibilité du registre de conteneurs <br/> définie sur **Toute personne ayant accès** (interface utilisateur) ou `enabled` (API) | Afficher le registre de conteneurs <br/> et télécharger des images | Non                                   | Oui   | Oui                                    |
| Projet interne avec visibilité du registre de conteneurs <br/> définie sur **Uniquement les membres du projet** (interface utilisateur) ou `private` (API) | Afficher le registre de conteneurs <br/> et télécharger des images | Non                                   | Non    | Oui                                    |
| Projet privé avec visibilité du registre de conteneurs <br/> définie sur **Toute personne ayant accès** (interface utilisateur) ou `enabled` (API)  | Afficher le registre de conteneurs <br/> et télécharger des images | Non                                   | Non    | Oui                                    |
| Projet privé avec visibilité du registre de conteneurs <br/> définie sur **Uniquement les membres du projet** (interface utilisateur) ou `private` (API)  | Afficher le registre de conteneurs <br/> et télécharger des images | Non                                   | Non    | Oui                                    |
| Tout projet avec registre de conteneurs `disabled`                                                                    | Toutes les opérations sur le registre de conteneurs          | Non                                   | Non    | Non                                     |

## Types d'images pris en charge {#supported-image-types}

Le registre de conteneurs prend en charge les formats d'images [Docker V2](https://distribution.github.io/distribution/spec/manifest-v2-2/) et [Open Container Initiative (OCI)](https://github.com/opencontainers/image-spec/blob/main/spec.md). De plus, le registre de conteneurs [est conforme à la spécification de distribution OCI](https://conformance.opencontainers.org/#gitlab-container-registry).

La prise en charge d'OCI signifie que vous pouvez héberger des formats d'images basés sur OCI dans le registre, tels que les packages de charts Helm 3+. Il n'y a pas de distinction entre les formats d'images dans l'API GitLab et l'interface utilisateur. [Le ticket 38047](https://gitlab.com/gitlab-org/gitlab/-/issues/38047) traite cette distinction, en commençant par Helm.

## Signatures d'images de conteneurs {#container-image-signatures}

{{< history >}}

- Affichage des signatures d'images de conteneurs [introduit](https://gitlab.com/groups/gitlab-org/-/epics/7856) dans GitLab 17.1.

{{< /history >}}

Dans le registre de conteneurs GitLab, vous pouvez utiliser le [champ `subject` du manifeste OCI 1.1](https://github.com/opencontainers/image-spec/blob/v1.1.0/manifest.md) pour associer des images de conteneurs à des [signatures Cosign](../../../ci/yaml/signing_examples.md). Vous pouvez ensuite afficher les informations de signature aux côtés de l'image de conteneur associée sans avoir à rechercher le tag de cette signature.

Lors de la consultation des tags d'une image de conteneur, une icône s'affiche à côté de chaque tag associé à une signature. Pour afficher les détails de la signature, sélectionnez l'icône.

Prérequis :

- Pour signer des images de conteneurs, Cosign v2.0 ou version ultérieure.
- Pour GitLab Self-Managed, vous avez besoin d'un registre de conteneurs GitLab configuré avec une base de données de métadonnées pour afficher les signatures. Pour plus d'informations, consultez [base de données de métadonnées du registre de conteneurs](../../../administration/packages/container_registry_metadata_database.md).

### Signer des images de conteneurs avec des données de référent OCI {#sign-container-images-with-oci-referrer-data}

Pour ajouter des données de référent aux signatures à l'aide de Cosign, vous devez :

- Définissez la variable d'environnement `COSIGN_EXPERIMENTAL` sur `1`.
- Ajoutez `--registry-referrers-mode oci-1-1` à la commande de signature.

Par exemple :

```shell
COSIGN_EXPERIMENTAL=1 cosign sign --registry-referrers-mode oci-1-1 <container image>
```

> [!note]
> Bien que le registre de conteneurs GitLab prenne en charge le champ `subject` du manifeste OCI 1.1, il n'implémente pas entièrement l'[API OCI 1.1 Referrers](https://github.com/opencontainers/distribution-spec/blob/v1.1.0/spec.md#listing-referrers).
