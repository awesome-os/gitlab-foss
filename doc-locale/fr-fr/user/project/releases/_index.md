---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Les releases
description: "Releases, versioning, ressources, étiquettes, jalons et preuve."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Créez une release pour packager votre projet lors des jalons critiques. Les releases combinent le code, les binaires, la documentation et les notes de release en un instantané complet de votre projet. Lors de la création d'une release, GitLab étiquette automatiquement votre code, archive un instantané et génère une preuve prête pour les audits. Cela crée un enregistrement permanent, idéal pour les exigences de conformité, et permet à vos utilisateurs d'avoir confiance dans votre processus de développement.

Vos utilisateurs bénéficient des avantages suivants :

- Accès facile à la dernière version stable et aux packages d'installation
- Documentation claire sur les nouvelles fonctionnalités et les corrections
- Possibilité de télécharger des versions spécifiques avec leurs ressources correspondantes
- Moyen simple de suivre l'évolution de votre projet dans le temps

> [!warning]
> La suppression d'une étiquette Git associée à une release entraîne également la suppression de la release.

Lors de la création d'une release, ou après celle-ci, vous pouvez :

- Ajouter des notes de release.
- Ajouter un message pour l'étiquette Git associée à la release.
- [Lui associer des jalons](#associate-milestones-with-a-release).
- Joindre des [ressources associées à une release](release_fields.md#release-assets), comme des runbooks ou des packages.

## Afficher les releases {#view-releases}

Pour afficher la liste des releases :

- Dans la barre latérale gauche, sélectionnez **Déployer** > **Release**, ou
- Sur la page de présentation du projet, si au moins une release existe, sélectionnez le nombre de releases.

  ![Nombre de releases](img/releases_count_v13_2.png "Compteur incrémental des releases")

  - Sur les projets publics, ce nombre est visible par tous les utilisateurs.
  - Sur les projets privés, ce nombre est visible par les utilisateurs disposant au minimum du [rôle](../../permissions.md#project-permissions) Reporter.

### Trier les releases {#sort-releases}

Pour trier les releases par **Date de sortie** ou **Date de création**, sélectionnez une option dans la liste déroulante d'ordre de tri. Pour basculer entre l'ordre croissant et l'ordre décroissant, sélectionnez **Ordre de tri**.

![Options de la liste déroulante de tri des releases](img/releases_sort_v13_6.png)

### Lien permanent vers la dernière release {#permanent-link-to-latest-release}

Vous pouvez accéder à la page de la dernière release via un lien permanent. GitLab redirige toujours l'URL du lien permanent vers l'adresse de la page de la dernière release.

Le format de l'URL est le suivant :

```plaintext
https://gitlab.example.com/namespace/project/-/releases/permalink/latest
```

Vous pouvez également ajouter un suffixe à l'URL du lien permanent. Par exemple, si la dernière release est `v17.7.0#release` dans l'espace de nommage `gitlab-org` et le projet `gitlab-runner`, le lien lisible serait :

```plaintext
https://gitlab.com/gitlab-org/gitlab-runner/-/releases/v17.7.0#release
```

Vous pouvez accéder à l'URL de la dernière release avec le lien permanent suivant :

```plaintext
https://gitlab.com/gitlab-org/gitlab-runner/-/releases/permalink/latest#release
```

Pour en savoir plus sur l'ajout de liens permanents vers des ressources associées à une release, consultez [Liens permanents vers les ressources de la dernière release](release_fields.md#permanent-links-to-latest-release-assets).

#### Préférences de tri {#sorting-preferences}

Par défaut, GitLab récupère la release en utilisant l'heure `released_at`. L'utilisation du paramètre de requête `?order_by=released_at` est facultative, et la prise en charge de `?order_by=semver` est suivie [dans ce ticket](https://gitlab.com/gitlab-org/gitlab/-/issues/352945).

### Suivre les releases avec un flux RSS {#track-releases-with-an-rss-feed}

GitLab fournit un flux RSS des releases d'un projet. Pour afficher le flux :

1. Pour les projets dont vous êtes membre :
   1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
   1. Sélectionnez **Déployer** > **Release**.
1. Pour tous les projets :
   1. Accédez à la page **Vue d'ensemble du projet**.
   1. Dans la barre latérale droite, sélectionnez **Release** ({{< icon name="rocket-launch" >}}).
1. Dans le coin supérieur droit, sélectionnez le symbole de flux ({{< icon name="rss" >}}).

## Créer une release {#create-a-release}

Vous pouvez créer une release :

- [En utilisant un job dans votre pipeline CI/CD](#creating-a-release-by-using-a-cicd-job).
- [Dans la page Releases](#create-a-release-in-the-releases-page).
- En utilisant l'[API Releases](../../../api/releases/_index.md#create-a-release).

### Créer une release dans la page Releases {#create-a-release-in-the-releases-page}

Prérequis :

- Vous devez disposer du rôle Développeur, Chargé de maintenance ou Propriétaire pour un projet. Pour plus d'informations, consultez [Autorisations de release](#release-permissions).

Pour créer une release dans la page Releases :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Release** et sélectionnez **Nouvelle release**.
1. Dans la liste déroulante [**Nom de l'étiquette**](release_fields.md#tag-name), au choix :
   - Sélectionnez une étiquette Git existante. La sélection d'une étiquette existante déjà associée à une release entraîne une erreur de validation.
   - Saisissez un nouveau nom d'étiquette Git.
     1. Dans le popover **Créer une étiquette**, sélectionnez une branche ou un SHA de commit à utiliser lors de la création de la nouvelle étiquette.
     1. Facultatif. Dans la zone de texte **Configurer le message de l'étiquette**, saisissez un message pour créer une [étiquette annotée](https://git-scm.com/book/en/v2/Git-Basics-Tagging#_annotated_tags).
     1. Sélectionnez **Enregistrer**.
1. Facultatif. Saisissez des informations supplémentaires sur la release, notamment :
   - [Titre](release_fields.md#title).
   - [Jalon](#associate-milestones-with-a-release).
   - [Notes de release](release_fields.md#release-notes-description).
   - Si le [message de l'étiquette](../repository/tags/_index.md) doit être inclus ou non.
   - [Liens vers les ressources](release_fields.md#links).
1. Sélectionnez **Créer une release**.

### Créer une release à l'aide d'un job CI/CD {#creating-a-release-by-using-a-cicd-job}

Vous pouvez créer une release directement dans le cadre du pipeline CI/CD GitLab en utilisant le [mot-clé `release`](../../../ci/yaml/_index.md#release) dans la définition du job. Il est conseillé de créer une release lors de l'une des dernières étapes de votre pipeline CI/CD.

La release n'est créée que si le job s'exécute sans erreur. Si l'API renvoie une erreur lors de la création de la release, le job de release échoue.

Les liens suivants présentent des exemples de configurations type pour créer une release à l'aide d'un job CI/CD :

- [Créer une release lors de la création d'une étiquette Git](release_cicd_examples.md#create-a-release-when-a-git-tag-is-created).
- [Créer une release lors de la fusion d'un commit sur la branche par défaut](release_cicd_examples.md#create-a-release-when-a-commit-is-merged-to-the-default-branch).
- [Créer des métadonnées de release dans un script personnalisé](release_cicd_examples.md#create-release-metadata-in-a-custom-script).

### Utiliser une autorité de certification SSL personnalisée {#use-a-custom-ssl-ca-certificate-authority}

Vous pouvez utiliser la variable CI/CD `ADDITIONAL_CA_CERT_BUNDLE` pour configurer une autorité de certification SSL personnalisée, utilisée pour vérifier le pair lorsque la CLI `glab` crée une release via l'API en utilisant HTTPS avec des certificats personnalisés. La valeur `ADDITIONAL_CA_CERT_BUNDLE` doit contenir la [représentation textuelle du certificat de clé publique X.509 PEM](https://www.rfc-editor.org/rfc/rfc7468#section-5.1) ou le `path/to/file` contenant l'autorité de certification. Par exemple, pour configurer cette valeur dans le fichier `.gitlab-ci.yml`, utilisez ce qui suit :

```yaml
release:
  variables:
    ADDITIONAL_CA_CERT_BUNDLE: |
        -----BEGIN CERTIFICATE-----
        MIIGqTCCBJGgAwIBAgIQI7AVxxVwg2kch4d56XNdDjANBgkqhkiG9w0BAQsFADCB
        ...
        jWgmPqF3vUbZE0EyScetPJquRFRKIesyJuBFMAs=
        -----END CERTIFICATE-----
  script:
    - echo "Create release"
  release:
    name: 'My awesome release'
    tag_name: '$CI_COMMIT_TAG'
```

La valeur `ADDITIONAL_CA_CERT_BUNDLE` peut également être configurée comme une [variable personnalisée dans l'interface utilisateur](../../../ci/variables/_index.md#for-a-project), soit en tant que `file`, ce qui nécessite le chemin d'accès au certificat, soit en tant que variable, ce qui nécessite la représentation textuelle du certificat.

### Créer plusieurs releases dans un seul pipeline {#create-multiple-releases-in-a-single-pipeline}

Un pipeline peut avoir plusieurs jobs `release`, par exemple :

```yaml
ios-release:
  script:
    - echo "iOS release job"
  release:
    tag_name: v1.0.0-ios
    description: 'iOS release v1.0.0'

android-release:
  script:
    - echo "Android release job"
  release:
    tag_name: v1.0.0-android
    description: 'Android release v1.0.0'
```

### Ressources associées à une release en tant que packages génériques {#release-assets-as-generic-packages}

Vous pouvez utiliser des [packages génériques](../../packages/generic_packages/_index.md) pour héberger vos ressources associées à une release.

Pour créer une release avec des ressources packagées :

1. Depuis un pipeline CI/CD, compilez vos fichiers de package.
1. Créez une release avec le job CLI `glab` :

   ```yaml
   Create Release:
     stage: release
     image: registry.gitlab.com/gitlab-org/cli:latest
     rules:
       - if: $CI_COMMIT_TAG
     script:
       - |
         glab release create "$CI_COMMIT_TAG" \
         --name "Release ${VERSION}" \
         --notes "Your release notes here" \
         path/to/your/release-asset-file \
         --use-package-registry
   ```

   Pour chaque ressource que vous souhaitez inclure, ajoutez un lien `--assets-link` supplémentaire.

## Releases à venir {#upcoming-releases}

Vous pouvez créer une release à l'avance en utilisant l'[API Releases](../../../api/releases/_index.md#upcoming-releases). Lorsque vous définissez une date `released_at` future, un badge **Release à venir** s'affiche à côté de l'étiquette de release. Lorsque la date et l'heure `released_at` sont passées, le badge est automatiquement supprimé.

![Une release à venir](img/upcoming_release_v18_8.png)

## Releases antérieures {#historical-releases}

Vous pouvez créer une release dans le passé en utilisant l'[API Releases](../../../api/releases/_index.md#historical-releases) ou l'interface utilisateur. Lorsque vous définissez une date `released_at` passée, un badge **Release antérieure** s'affiche à côté de l'étiquette de release. Étant donné que la release a été publiée dans le passé, la [preuve de release](release_evidence.md) n'est pas disponible.

## Modifier une release {#edit-a-release}

Pour modifier les détails d'une release après sa création, vous pouvez utiliser l'[API de mise à jour d'une release](../../../api/releases/_index.md#update-a-release) ou l'interface utilisateur.

Prérequis :

- Vous devez disposer du rôle Développeur, Chargé de maintenance ou Propriétaire.

Dans l'interface utilisateur :

1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Release**.
1. Dans le coin supérieur droit de la release que vous souhaitez modifier, sélectionnez **Modifier cette release** (l'icône en forme de crayon).
1. Sur la page **Modifier la release**, modifiez les détails de la release.
1. Sélectionnez **Enregistrer les modifications**.

## Supprimer une release {#delete-a-release}

Lorsque vous supprimez une release, ses ressources sont également supprimées. Toutefois, l'étiquette Git associée n'est pas supprimée. La suppression d'une étiquette Git associée à une release entraîne également la suppression de la release.

Prérequis :

- Vous devez disposer du rôle Développeur, Chargé de maintenance ou Propriétaire. En savoir plus sur les [autorisations de release](#release-permissions).

Pour supprimer une release, utilisez l'[API de suppression d'une release](../../../api/releases/_index.md#delete-a-release) ou l'interface utilisateur.

Dans l'interface utilisateur :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Release**.
1. Dans le coin supérieur droit de la release que vous souhaitez supprimer, sélectionnez **Modifier cette release** ({{< icon name="pencil" >}}).
1. Sur la page **Modifier la release**, sélectionnez **Supprimer**.
1. Sélectionnez **Supprimer la release**.

## Associer des jalons à une release {#associate-milestones-with-a-release}

Vous pouvez associer une release à un ou plusieurs [jalons de projet](../milestones/_index.md#project-milestones-and-group-milestones).

Les clients de [GitLab Premium](https://about.gitlab.com/pricing/) peuvent spécifier des [jalons de groupe](../milestones/_index.md#project-milestones-and-group-milestones) à associer à une release.

Vous pouvez effectuer cette opération dans l'interface utilisateur ou en incluant un tableau `milestones` dans votre requête à l'[API Releases](../../../api/releases/_index.md#create-a-release).

Dans l'interface utilisateur, pour associer des jalons à une release :

1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Release**.
1. Dans le coin supérieur droit de la release que vous souhaitez modifier, sélectionnez **Modifier cette release** (l'icône en forme de crayon).
1. Dans la liste **Jalons**, sélectionnez chaque jalon que vous souhaitez associer. Vous pouvez sélectionner plusieurs jalons.
1. Sélectionnez **Enregistrer les modifications**.

Sur la page **Déployer** > **Release**, le **Jalon** est répertorié dans la section supérieure, avec des statistiques sur les tickets dans les jalons.

![Une release avec un jalon associé](img/release_with_milestone_v12_9.png)

Les releases sont également visibles sur la page **Forfait** > **Jalons**, ainsi que lorsque vous sélectionnez un jalon sur cette page.

Voici un exemple de jalons sans release, avec une release et avec deux releases.

![Jalons avec et sans associations de releases](img/milestone_list_with_releases_v12_5.png)

> [!note]
> Les releases d'un projet de sous-groupe ne peuvent pas être associées au jalon d'un groupe parent. Pour en savoir plus, consultez le ticket n° 328054, [Les releases ne peuvent pas être associées au jalon d'un supergroupe](https://gitlab.com/gitlab-org/gitlab/-/issues/328054).

## Être notifié lors de la création d'une release {#get-notified-when-a-release-is-created}

Vous pouvez être notifié par e-mail lors de la création d'une nouvelle release pour votre projet.

Pour vous abonner aux notifications de releases :

1. Dans la barre latérale gauche, sélectionnez **Vue d'ensemble du projet**.
1. Sélectionnez **Paramètre de notification** (l'icône en forme de cloche).
1. Dans la liste, sélectionnez **Personnalisé**.
1. Cochez la case **Nouvelle release**.
1. Fermez la boîte de dialogue pour enregistrer.

## Empêcher les releases non intentionnelles en définissant un gel de déploiement {#prevent-unintentional-releases-by-setting-a-deploy-freeze}

Empêchez les releases en production non intentionnelles pendant une période que vous définissez en configurant une [période de *gel du déploiement*](../../../ci/environments/deployment_safety.md). Les gels de déploiement permettent de réduire l'incertitude et le risque lors de l'automatisation des déploiements.

Un chargé de maintenance peut définir une fenêtre de gel du déploiement dans l'interface utilisateur ou en utilisant l'[API Freeze Periods](../../../api/freeze_periods.md) pour définir un `freeze_start` et un `freeze_end`, définis comme des entrées [crontab](https://crontab.guru/).

Si le job en cours d'exécution se trouve dans une période de gel, GitLab CI/CD crée une variable d'environnement nommée `$CI_DEPLOY_FREEZE`.

Pour empêcher le job de déploiement de s'exécuter dans plusieurs projets d'un groupe, définissez le job `.freezedeployment` dans un fichier partagé au sein du groupe. Utilisez le mot-clé [`includes`](../../../ci/yaml/includes.md) pour incorporer le modèle dans le fichier `.gitlab-ci.yml` de votre projet :

```yaml
.freezedeployment:
  stage: deploy
  before_script:
    - '[[ ! -z "$CI_DEPLOY_FREEZE" ]] && echo "INFRASTRUCTURE OUTAGE WINDOW" && exit 1; '
  rules:
    - if: '$CI_DEPLOY_FREEZE'
      when: manual
      allow_failure: true
    - when: on_success
```

Pour empêcher le job de déploiement de s'exécuter, utilisez le mot-clé [`extends`](../../../ci/yaml/_index.md#extends) dans le job `deploy_to_production` de votre fichier `.gitlab-ci.yml` pour hériter de la configuration du job de modèle `.freezedeployment` :

```yaml
deploy_to_production:
  extends: .freezedeployment
  script: deploy_to_prod.sh
  environment: production
```

Cette configuration bloque les jobs de déploiement de manière conditionnelle et maintient la continuité du pipeline. Lorsqu'une période de gel est définie, le job échoue et le pipeline peut continuer sans déploiement. Le déploiement manuel est possible après la période de gel.

Cette approche offre un contrôle du déploiement lors des opérations de maintenance critiques et garantit le flux ininterrompu du pipeline CI/CD.

Pour définir une fenêtre de gel du déploiement dans l'interface utilisateur, suivez ces étapes :

1. Connectez-vous à GitLab en tant qu'utilisateur avec le rôle Chargé de maintenance.
1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Faites défiler jusqu'à **Gels de déploiement**.
1. Sélectionnez **Étendre** pour afficher le tableau des gels de déploiement.
1. Sélectionnez **Ajouter un gel de déploiement** pour ouvrir la fenêtre modale de gel de déploiement.
1. Saisissez l'heure de début, l'heure de fin et le fuseau horaire de la période de gel du déploiement souhaitée.
1. Sélectionnez **Ajouter un gel de déploiement** dans la fenêtre modale.
1. Une fois le gel de déploiement enregistré, vous pouvez le modifier en sélectionnant le bouton Modifier ({{< icon name="pencil" >}}) et le supprimer en sélectionnant le bouton Supprimer ({{< icon name="remove" >}}). ![Fenêtre modale de gel de déploiement pour définir une période de gel de déploiement](img/deploy_freeze_v14_3.png)

Si un projet contient plusieurs périodes de gel, toutes les périodes s'appliquent. En cas de chevauchement, le gel couvre l'intégralité de la période de chevauchement.

Pour plus d'informations, consultez [Sécurité des déploiements](../../../ci/environments/deployment_safety.md).

## Autorisations de release {#release-permissions}

### Afficher une release et télécharger des ressources {#view-a-release-and-download-assets}

- Les utilisateurs avec le rôle Reporter, Développeur, Chargé de maintenance ou Propriétaire ont accès en lecture et en téléchargement aux releases du projet.
- Les utilisateurs avec le rôle Invité ont accès en lecture et en téléchargement aux releases du projet. Cela inclut les noms d'étiquettes Git associés, la description de la release et les informations sur l'auteur des releases. Cependant, les autres informations liées au dépôt, telles que le [code source](release_fields.md#source-code) et la [preuve de release](release_evidence.md), sont masquées.

### Publier des releases sans donner accès au code source {#publish-releases-without-giving-access-to-source-code}

Vous pouvez rendre les releases accessibles aux non-membres du projet tout en réservant les informations liées au dépôt, telles que le [code source](release_fields.md#source-code) et la [preuve de release](release_evidence.md), aux seuls membres du projet. Ces paramètres sont idéaux pour les projets qui utilisent des releases pour donner accès à de nouvelles versions de logiciels, mais qui ne souhaitent pas que le code source soit accessible au public.

Pour rendre les releases disponibles publiquement, définissez les [paramètres de projet](../settings/_index.md#configure-project-features-and-permissions) suivants :

- **Visibilité du projet** est défini sur **Public**
- **Dépôt** est activé et défini sur **Uniquement les membres du projet**
- **Release** est activé et défini sur **Toute personne ayant accès**

### Créer, mettre à jour et supprimer une release et ses ressources {#create-update-and-delete-a-release-and-its-assets}

- Les utilisateurs avec le rôle Développeur, Chargé de maintenance ou Propriétaire ont un accès en écriture aux releases et aux ressources du projet.
- Si une release est associée à une [étiquette protégée](../protected_tags.md), l'utilisateur doit également être [autorisé à créer l'étiquette protégée](../protected_tags.md#configure-protected-tags).

À titre d'exemple de contrôle des autorisations de release, vous pouvez autoriser uniquement les utilisateurs avec le rôle Chargé de maintenance ou Propriétaire à créer, mettre à jour et supprimer des releases en protégeant l'étiquette avec un caractère générique (`*`), et en définissant **Chargé de maintenance** dans la colonne **Autorisé à créer**.

## Métriques de release {#release-metrics}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/259703) dans GitLab Premium 13.9.

{{< /history >}}

Les métriques de release au niveau du groupe sont disponibles en accédant à **Groupe** > **Données d'analyse** > **CI/CD**. Ces métriques incluent :

- Nombre total de releases dans le groupe
- Pourcentage de projets dans le groupe ayant au moins une release

## Exemple de projet fonctionnel {#working-example-project}

Le projet Guided Exploration [Utterly Automated Software and Artifact Versioning with GitVersion](https://gitlab.com/guided-explorations/devops-patterns/utterly-automated-versioning) illustre :

- L'utilisation des releases GitLab.
- L'utilisation de la [CLI GitLab](../../../editor_extensions/gitlab_cli/_index.md).
- La création d'un package générique.
- La liaison du package à la release.
- L'utilisation d'un outil appelé [GitVersion](https://gitversion.net/) pour déterminer et incrémenter automatiquement les versions de dépôts complexes.

Vous pouvez copier l'exemple de projet dans votre propre groupe ou instance à des fins de test. Des détails supplémentaires sur les autres patterns CI GitLab illustrés sont disponibles sur la page du projet.

## Dépannage {#troubleshooting}

### Erreurs lors de la création, de la mise à jour ou de la suppression de releases et de leurs ressources {#errors-when-creating-updating-or-deleting-releases-and-their-assets}

Si la release est associée à une [étiquette protégée](../protected_tags.md), la requête UI/API peut entraîner des échecs d'autorisation, tels que :

- `403 Forbidden`
- `Something went wrong while creating a new release`

Assurez-vous que l'utilisateur ou un compte de service/bot est également autorisé à [créer l'étiquette protégée](../protected_tags.md#configure-protected-tags).

Consultez [les autorisations de release](#release-permissions) pour plus d'informations.

### Remarque sur le stockage {#note-about-storage}

Cette fonctionnalité est basée sur les étiquettes Git, de sorte que pratiquement aucune donnée supplémentaire n'est nécessaire au-delà de ce qui est requis pour créer la release elle-même. Les ressources supplémentaires et la preuve de release générée automatiquement consomment de l'espace de stockage.

### Exigence de version pour la CLI GitLab {#gitlab-cli-version-requirement}

La façon d'utiliser le [mot-clé `release`](../../../ci/yaml/_index.md#release) est amenée à changer. L'outil `release-cli` est [en cours de remplacement](https://gitlab.com/groups/gitlab-org/-/epics/15437) par l'[outil CLI GitLab](https://gitlab.com/gitlab-org/cli/).

Vous devez utiliser l'outil CLI GitLab `v1.58.0` ou une version supérieure, sinon vous risquez de recevoir l'un de ces messages d'erreur ou avertissements :

- `Error: glab command not found. Please install glab v1.58.0 or higher.`
- `Error: Please use glab v1.58.0 or higher.`
- `Warning: release-cli will not be supported after 20.0. Please use glab version >= 1.58.0.`

Il existe deux façons d'obtenir l'outil CLI GitLab :

- Si vous utilisez l'image conteneur `registry.gitlab.com/gitlab-org/release-cli:<version>`, vous pouvez commencer à utiliser soit `registry.gitlab.com/gitlab-org/cli:v1.58.0`, soit `registry.gitlab.com/gitlab-org/release-cli:v0.24.0`, qui contient `glab` `v1.58.0`.
- Si vous avez installé manuellement release-cli ou l'outil CLI GitLab sur vos runners, assurez-vous que la version de la CLI GitLab est au moins `v1.58.0`.
