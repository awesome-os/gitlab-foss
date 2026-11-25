---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Fonctionnalité Auto DevOps
description: "DevOps automatisé, détection de langage, déploiement et personnalisation."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Auto DevOps transforme votre code en applications prêtes pour la production sans la surcharge de configuration habituelle. L'ensemble du cycle de vie DevOps est préconfiguré selon les bonnes pratiques du secteur. Commencez avec les paramètres par défaut pour livrer rapidement, puis personnalisez lorsque vous avez besoin de plus de contrôle. Aucun fichier de configuration complexe ni expertise DevOps approfondie n'est requis.

Avec Auto DevOps, vous bénéficiez de :

- Pipelines CI/CD qui détectent automatiquement votre langage et votre framework
- Analyse de sécurité intégrée pour détecter les vulnérabilités avant qu'elles n'atteignent la production
- Tests de qualité du code et de performance à chaque commit
- Environnements éphémères prêts à l'emploi pour prévisualiser les modifications dans un environnement actif
- Déploiements rapides vers des clusters Kubernetes
- Stratégies de déploiement progressif qui réduisent les risques et les interruptions de service

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une introduction à Auto DevOps, regardez [Auto DevOps](https://youtu.be/0Tc0YYBxqi4).
<!-- Video published on 2018-06-22 -->

## Fonctionnalités d'Auto DevOps {#auto-devops-features}

Auto DevOps prend en charge le développement à chacune des [étapes DevOps](stages.md).

| Étape  | Fonctionnalité Auto DevOps |
|--------|---------------------|
| Build  | [Auto build](stages.md#auto-build) |
| Build  | [Auto dependency scanning](stages.md#auto-dependency-scanning) |
| Test   | [Auto test](stages.md#auto-test) |
| Test   | [Auto browser performance testing](stages.md#auto-browser-performance-testing) |
| Test   | [Auto code intelligence](stages.md#auto-code-intelligence) |
| Test   | [Auto code quality](stages.md#auto-code-quality) |
| Test   | [Auto container scanning](stages.md#auto-container-scanning) |
| Deploy | [Auto review apps](stages.md#auto-review-apps) |
| Deploy | [Auto deploy](stages.md#auto-deploy) |
| Secure | [Auto dynamic application security testing (DAST)](stages.md#auto-dast) |
| Secure | [Auto static application security testing (SAST)](stages.md#auto-sast) |
| Secure | [Auto secret detection](stages.md#auto-secret-detection) |

### Comparaison avec les plateformes applicatives et les PaaS {#comparison-to-application-platforms-and-paas}

Auto DevOps fournit des fonctionnalités souvent incluses dans une plateforme applicative ou dans une plateforme en tant que service (PaaS).

Inspiré de [Heroku](https://www.heroku.com/), Auto DevOps le dépasse sur plusieurs points :

- Auto DevOps fonctionne avec n'importe quel cluster Kubernetes.
- Il n'y a aucun coût supplémentaire.
- Vous pouvez utiliser un cluster hébergé par vous-même ou sur n'importe quel cloud public.
- Auto DevOps offre un parcours de progression incrémentale. Si vous avez besoin de [personnaliser](customize.md), commencez par modifier les modèles et faites évoluer à partir de là.

## Démarrer avec Auto DevOps {#get-started-with-auto-devops}

Pour démarrer, vous n'avez qu'à [activer Auto DevOps](#enable-or-disable-auto-devops). Cela est suffisant pour exécuter un pipeline Auto DevOps afin de compiler et tester votre application.

Si vous souhaitez compiler, tester et déployer votre application :

1. Consultez les [exigences pour le déploiement](requirements.md).
1. [Activez Auto DevOps](#enable-or-disable-auto-devops).
1. [Déployez votre application auprès d'un fournisseur cloud](#deploy-your-app-to-a-cloud-provider).

### Activer ou désactiver Auto DevOps {#enable-or-disable-auto-devops}

Auto DevOps exécute les pipelines automatiquement uniquement si un [`Dockerfile` ou un buildpack correspondant](stages.md#auto-build) existe.

Vous pouvez activer ou désactiver Auto DevOps pour un projet ou un groupe entier. Les administrateurs d'instance peuvent également [définir Auto DevOps comme valeur par défaut](../../administration/settings/continuous_integration.md#configure-auto-devops-for-all-projects) pour tous les projets d'une instance.

Avant d'activer Auto DevOps, envisagez de [le préparer pour le déploiement](requirements.md). Si vous ne le faites pas, Auto DevOps peut compiler et tester votre application, mais ne peut pas la déployer.

#### Par projet {#per-project}

Pour utiliser Auto DevOps pour des projets individuels, vous pouvez l'activer projet par projet. Si vous souhaitez l'utiliser pour davantage de projets, vous pouvez l'activer pour un [groupe](#per-group) ou une [instance](../../administration/settings/continuous_integration.md#configure-auto-devops-for-all-projects). Cela peut vous faire gagner du temps en évitant de l'activer dans chaque projet.

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.
- Assurez-vous que votre projet ne contient pas de fichier `.gitlab-ci.yml`. Si c'est le cas, votre configuration CI/CD a la priorité sur le pipeline Auto DevOps.

Pour activer Auto DevOps pour un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Développez **Auto DevOps**.
1. Cochez la case **Pipeline Auto DevOps par défaut**.
1. Facultatif mais recommandé. Ajoutez le [domaine de base](requirements.md#auto-devops-base-domain).
1. Facultatif mais recommandé. Choisissez la [stratégie de déploiement](requirements.md#auto-devops-deployment-strategy).
1. Sélectionnez **Enregistrer les modifications**.

GitLab déclenche le pipeline Auto DevOps sur la branche par défaut.

Pour vérifier qu'Auto DevOps fonctionne :

1. Dans la barre latérale gauche, sélectionnez **Compilation** > **Pipelines**.
1. Trouvez le pipeline déclenché sur la branche par défaut. Il doit être en cours d'exécution ou avoir été récemment terminé.
1. Sélectionnez le pipeline pour afficher ses jobs et ses étapes.

Le pipeline inclut des jobs pour les étapes Auto DevOps telles que `build`, `test`, `code_quality` et `sast` configurés pour votre projet.

Si le pipeline ne s'exécute pas ou si ces jobs sont manquants :

- Assurez-vous que votre projet respecte les [exigences d'Auto DevOps](requirements.md).
- Assurez-vous que **Pipeline Auto DevOps par défaut** est sélectionné dans **Paramètres** > **CI/CD** > **Auto DevOps**.

Pour le désactiver, suivez le même processus et décochez la case **Pipeline Auto DevOps par défaut**.

#### Par groupe {#per-group}

Lorsque vous activez Auto DevOps pour un groupe, les sous-groupes et les projets de ce groupe héritent de la configuration. Vous pouvez gagner du temps en activant Auto DevOps pour un groupe plutôt que de l'activer pour chaque sous-groupe ou projet.

Lorsqu'il est activé pour un groupe, vous pouvez toujours désactiver Auto DevOps pour les sous-groupes et les projets pour lesquels vous ne souhaitez pas l'utiliser.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour activer Auto DevOps pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Développez **Auto DevOps**.
1. Cochez la case **Pipeline Auto DevOps par défaut**.
1. Sélectionnez **Enregistrer les modifications**.

Pour désactiver Auto DevOps pour un groupe, suivez le même processus et décochez la case **Pipeline Auto DevOps par défaut**.

Après avoir activé Auto DevOps pour un groupe, vous pouvez déclencher le pipeline Auto DevOps pour n'importe quel projet appartenant à ce groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Assurez-vous que le projet ne contient pas de fichier `.gitlab-ci.yml`.
1. Sélectionnez **Compilation** > **Pipelines**.
1. Pour déclencher le pipeline Auto DevOps, sélectionnez **Nouveau pipeline**.

### Déployer votre application auprès d'un fournisseur cloud {#deploy-your-app-to-a-cloud-provider}

- [Utiliser Auto DevOps pour déployer vers un cluster Kubernetes sur Google Kubernetes Engine (GKE)](cloud_deployments/auto_devops_with_gke.md)
- [Utiliser Auto DevOps pour déployer vers un cluster Kubernetes sur Amazon Elastic Kubernetes Service (EKS)](cloud_deployments/auto_devops_with_eks.md)
- [Utiliser Auto DevOps pour déployer vers EC2](cloud_deployments/auto_devops_with_ec2.md)
- [Utiliser Auto DevOps pour déployer vers ECS](cloud_deployments/auto_devops_with_ecs.md)

## Mettre à niveau les dépendances Auto DevOps lors de la mise à jour de GitLab {#upgrade-auto-devops-dependencies-when-updating-gitlab}

Lors de la mise à jour de GitLab, vous pourriez avoir besoin de mettre à niveau les dépendances Auto DevOps pour correspondre à votre nouvelle version de GitLab :

- [Mise à niveau des ressources Auto DevOps](upgrading_auto_deploy_dependencies.md) :
  - Modèle Auto DevOps.
  - Modèle Auto Deploy.
  - Image Auto Deploy.
  - Helm.
  - Kubernetes.
  - Variables d'environnement.
- [Mise à niveau de PostgreSQL](upgrading_postgresql.md).

## Prise en charge des registres privés {#private-registry-support}

Il n'est pas garanti que vous puissiez utiliser un registre de conteneurs privé avec Auto DevOps.

À la place, utilisez le [registre de conteneurs GitLab](../../user/packages/container_registry/_index.md) avec Auto DevOps pour simplifier la configuration et éviter tout problème imprévu.

## Installer des applications derrière un proxy {#install-applications-behind-a-proxy}

L'intégration GitLab avec Helm ne prend pas en charge l'installation d'applications lorsqu'elle se trouve derrière un proxy.

Si vous souhaitez le faire, vous devez injecter les paramètres du proxy dans les pods d'installation lors de l'exécution.

## Sujets connexes {#related-topics}

- [Méthodologies continues](../../ci/_index.md)
- [Docker](https://docs.docker.com)
- [GitLab Runner](https://docs.gitlab.com/runner/)
- [Helm](https://helm.sh/docs/)
- [Kubernetes](https://kubernetes.io/docs/home/)
- [Prometheus](https://prometheus.io/docs/introduction/overview/)

## Dépannage {#troubleshooting}

Consultez [le dépannage d'Auto DevOps](troubleshooting.md).
