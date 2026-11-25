---
stage: ModelOps
group: MLOps
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Expériences du modèle de machine learning
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/work_items/9341) dans GitLab 15.11.
- [Disponible en version générale](https://gitlab.com/groups/gitlab-org/-/work_items/9341) dans GitLab 17.8.

{{< /history >}}

Lorsque vous créez des modèles de machine learning, vous expérimentez probablement différents paramètres, configurations et approches d'ingénierie des fonctionnalités pour améliorer les performances du modèle. Pour reproduire vos expériences ultérieurement, vous devez effectuer un suivi efficace des métadonnées et des artefacts. Utilisez les expériences du modèle GitLab pour suivre et enregistrer les paramètres, les métriques et les artefacts directement dans GitLab.

## Qu'est-ce qu'une expérience ? {#what-is-an-experiment}

Dans un projet, une expérience est un ensemble d'exécutions de modèles comparables. Les expériences peuvent être de longue durée (par exemple, lorsqu'elles représentent un cas d'utilisation) ou de courte durée (résultats d'un réglage des hyperparamètres déclenché par une merge request), mais contiennent généralement des exécutions de modèles présentant un ensemble similaire de paramètres mesurés par les mêmes métriques.

![Tableau des expériences du modèle affichant les modèles, leur nombre d'exécutions, le créateur et la dernière activité.](img/experiments_v17_9.png)

## Exécution du modèle {#model-run}

Une exécution du modèle est une variante de l'entraînement d'un modèle de machine learning qui peut éventuellement être promue en version du modèle.

![Tableau de la liste des exécutions d'expériences avec l'identifiant d'exécution, les horodatages de création, le nom du créateur et le statut.](img/runs_v17_9.png)

L'objectif d'un data scientist est de trouver l'exécution du modèle dont les valeurs de paramètres conduisent aux meilleures performances du modèle, telles qu'indiquées par les métriques définies.

![Page de détails et de métadonnées de l'expérience affichant l'identifiant d'exécution ML flow, les informations sur la source et les paramètres.](img/run_v17_9.png)

Exemples de paramètres :

- Algorithme (tel que la régression linéaire ou l'arbre de décision).
- Hyperparamètres pour l'algorithme (taux d'apprentissage, profondeur de l'arbre, nombre d'époques).
- Fonctionnalités incluses.

## Suivre de nouvelles expériences et exécutions {#track-new-experiments-and-runs}

Les expériences et les essais ne peuvent être suivis qu'via la compatibilité client [MLflow](https://www.mlflow.org/docs/latest/tracking/). Consultez [Compatibilité du client MLflow](mlflow_client.md) pour en savoir plus sur l'utilisation de GitLab comme backend pour le client MLflow.

## Explorer les exécutions du modèle {#explore-model-runs}

Pour répertorier les expériences actives en cours :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Analyse** > **Expériences avec ce modèle**.
1. Pour afficher toutes les exécutions qui ont été enregistrées, ainsi que leurs métriques, paramètres et métadonnées, sélectionnez une expérience.
1. Pour afficher les détails d'une exécution, sélectionnez **Détails**.

## Afficher les artefacts journalisés {#view-log-artifacts}

Les artefacts d'essai sont enregistrés sous forme de paquets. Après qu'un artefact a été journalisé pour une exécution, tous les artefacts journalisés pour cette exécution sont répertoriés dans le registre de paquets. Le nom du paquet pour une exécution est `ml_experiment_<experiment_id>`, où la version correspond à l'IID de l'exécution. Le lien vers les artefacts est également accessible depuis la liste **Exécutions de l'expérience** ou **Détail de l'exécution**.

## Afficher les informations CI {#view-ci-information}

Vous pouvez associer des exécutions au job CI qui les a créées, permettant ainsi d'accéder rapidement à la merge request, au pipeline et à l'utilisateur qui a déclenché le pipeline :

![Page de détail de l'exécution affichant le job CI associé, le pipeline et les informations sur l'utilisateur.](img/run_detail_ci_v17_9.png)

## Afficher les métriques journalisées {#view-logged-metrics}

Lorsque vous exécutez une expérience, GitLab journalise certaines données associées, notamment ses métriques, paramètres et métadonnées. Vous pouvez afficher les métriques dans un graphique à des fins d'analyse.

Pour afficher les métriques journalisées :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Analyse** > **Expériences avec ce modèle**.
1. Sélectionnez l'expérience que vous souhaitez afficher.
1. Sélectionnez l'onglet **Performance**.

![Graphique des performances d'une expérience](img/metrics_v17_10.png)
