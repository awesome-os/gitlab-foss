---
stage: Security Risk Management
group: Security Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Afficher les découvertes dans l'onglet Rapports de la merge request."
title: Rapports de merge request
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/epics/20406) dans GitLab 19.0 [avec le feature flag](../../../administration/feature_flags/_index.md) `mr_reports_tab`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/234820) dans GitLab 19.1.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/234782) dans GitLab 19.1. Le feature flag `mr_reports_tab` a été supprimé.
- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/252613) pour être disponible dans toutes les éditions dans GitLab 19.5.

{{< /history >}}

L'onglet **Rapports** d'une merge request affiche les découvertes détaillées des analyses du pipeline CI/CD. L'onglet présente les découvertes des analyses de sécurité, les résultats de conformité de licence et les rapports de qualité du code dans une vue pleine page dédiée.

## Rapport d'analyse de sécurité {#security-scan-report}

{{< details >}}

- Édition : GitLab Ultimate

{{< /details >}}

Le rapport d'analyse de sécurité fournit un résumé des modifications qui se produiraient dans les découvertes si la branche source était fusionnée.

Par exemple, prenons deux pipelines avec ces résultats d'analyse :

- Le pipeline de la branche cible détecte deux vulnérabilités identifiées comme `V1` et `V2`.
- Le pipeline de la branche source détecte deux vulnérabilités identifiées comme `V1` et `V3`.

Le rapport d'analyse de sécurité affiche les résultats suivants :

- `V1` existe dans les deux branches et n'est donc pas affiché dans le rapport.
- `V2` apparaît dans le rapport comme **corrigé**.
- `V3` apparaît dans le rapport comme **a ajouté**.

Pour que le rapport d'analyse de sécurité affiche les différences entre la branche source et la branche cible, vous devez disposer de rapports de sécurité des deux branches. Le système vérifie les 10 commits les plus récents sur la branche cible pour identifier des pipelines de sécurité valides. Pour chaque commit, jusqu'à 10 des pipelines les plus récents sont vérifiés pour trouver un rapport de sécurité.

Cette approche garantit que même si un commit ignore le pipeline, un rapport de sécurité valide provenant d'un commit antérieur est trouvé. Si aucun rapport de sécurité n'est trouvé, toutes les découvertes sont répertoriées comme nouvelles. Avant d'activer l'analyse de sécurité dans les merge requests, assurez-vous que l'analyse de sécurité est activée pour la branche par défaut.

Pour chaque type de rapport de sécurité, le rapport affiche les 25 premières découvertes ajoutées et les 25 premières découvertes corrigées, triées par gravité. Pour voir toutes les découvertes sur la branche source de la merge request, sélectionnez **Voir toutes les découvertes du pipeline**.

### Afficher les découvertes de l'analyse de sécurité {#view-security-scan-findings}

Prérequis :

- Vous devez disposer au minimum du rôle Developer pour le projet.
- Vous devez [configurer l'analyse de sécurité](../../application_security/detect/security_configuration.md) pour le projet.
- L'analyse de sécurité doit avoir été exécutée et avoir généré un rapport sur le dernier pipeline pour la branche source d'une merge request.

Pour afficher les découvertes de l'analyse de sécurité :

1. Dans la barre latérale gauche, sélectionnez **Rechercher ou accéder à** et repérez votre projet.
1. Sélectionnez **Code** > **Requêtes de fusion**.
1. Sélectionnez une merge request.
1. Sélectionnez l'onglet **Rapports**.
1. Sélectionnez **Analyse de sécurité**.

## Rapport de conformité de licence {#license-compliance-report}

{{< details >}}

- Édition : GitLab Ultimate

{{< /details >}}

Le rapport de conformité de licence affiche les licences détectées dans les dépendances de votre projet en comparant les résultats du pipeline de la branche source avec ceux du pipeline de la branche cible.

Les licences sont regroupées en trois catégories :

- **Nouvelles licences** : licences détectées dans la branche source qui n'existent pas dans la branche cible.
- **Licences existantes** : licences qui existent dans les deux branches.
- **Licences supprimées** : licences qui existent dans la branche cible mais pas dans la branche source.

Pour chaque licence, le rapport affiche les informations suivantes :

- Nom et classification de la licence (autorisée, refusée ou inconnue)
- Nombre de dépendances utilisant la licence
- Liste des dépendances concernées avec les informations sur le gestionnaire de paquets et la version

Les classifications des licences sont déterminées par les [politiques d'approbation de licence](../../compliance/license_approval_policies.md) de votre projet.

### Afficher les découvertes de conformité de licence {#view-license-compliance-findings}

Prérequis :

- Vous devez disposer au minimum du rôle Developer pour le projet.
- Vous devez avoir [l'analyse des licences](../../compliance/license_scanning_of_cyclonedx_files/_index.md) configurée pour votre projet.

Pour afficher les découvertes de conformité de licence :

1. Dans la barre latérale gauche, sélectionnez **Rechercher ou accéder à** et repérez votre projet.
1. Sélectionnez **Code** > **Requêtes de fusion**.
1. Sélectionnez une merge request.
1. Sélectionnez l'onglet **Rapports**.
1. Sélectionnez **Conformité de licence**.

## Rapport de qualité du code {#code-quality-report}

Le rapport de qualité du code affiche les violations de qualité du code détectées dans votre merge request en comparant les résultats du pipeline de la branche source avec ceux du pipeline de la branche cible. Le rapport est disponible si un rapport de la branche cible est disponible pour la comparaison.

Le rapport affiche :

- **Nouvelles violations** : violations de qualité du code détectées dans la branche source qui n'existent pas dans la branche cible.
- **Violations résolues** : violations de qualité du code qui existent dans la branche cible mais pas dans la branche source. Les violations résolues sont marquées d'un badge.

Chaque violation affiche les informations suivantes :

- Description du problème de qualité du code
- Niveau de gravité (bloquant, critique, majeur, mineur ou informatif)
- Chemin du fichier et numéro de ligne où la violation se produit
- Nom du contrôle (la règle ou le linter qui a détecté la violation)

Les violations dupliquées, avec des empreintes identiques, sont supprimées. Une seule entrée est affichée.

### Afficher les découvertes de qualité du code {#view-code-quality-findings}

Prérequis :

- Rôle Developer, Maintainer ou Owner
- [Analyse de la qualité du code](../../../ci/testing/code_quality.md) configurée pour votre projet

Pour afficher les découvertes de qualité du code :

1. Dans la barre latérale gauche, sélectionnez **Rechercher ou accéder à** et repérez votre projet.
1. Sélectionnez **Code** > **Requêtes de fusion**.
1. Sélectionnez une merge request.
1. Sélectionnez l'onglet **Rapports**.
1. Sélectionnez **Qualité du code**.

## Dépannage {#troubleshooting}

Vous pourriez rencontrer les problèmes suivants lors de la consultation des rapports.

### Les vulnérabilités ignorées sont visibles dans le rapport d'analyse de sécurité {#dismissed-vulnerabilities-are-visible-in-the-security-scan-report}

Lorsque vous consultez le rapport d'analyse de sécurité dans une merge request, le rapport peut inclure des vulnérabilités déjà ignorées.

Aucune solution n'est disponible pour ce problème. Pour suivre la solution proposée, consultez le [ticket 411235](https://gitlab.com/gitlab-org/gitlab/-/issues/411235).

### Le rapport de conformité de licence est bloqué dans un état de chargement {#the-license-compliance-report-is-stuck-in-a-loading-state}

Un indicateur de chargement s'affiche dans les scénarios suivants :

- Pendant que le pipeline est en cours.
- Si le pipeline est terminé, mais que les résultats sont encore en cours d'analyse en arrière-plan.
- Si le job d'analyse des licences est terminé, mais que le pipeline est encore en cours d'exécution.

Le rapport de conformité de licence interroge le serveur toutes les quelques secondes pour obtenir des résultats mis à jour. Lorsque le pipeline est terminé, la première interrogation après la fin du pipeline déclenche l'analyse des résultats. Cette opération peut prendre quelques secondes en fonction de la taille du rapport généré.

L'état final est une exécution de pipeline réussie qui a été terminée, analysée et affichée dans le rapport.
