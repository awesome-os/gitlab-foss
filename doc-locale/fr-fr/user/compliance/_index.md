---
stage: Software Supply Chain Security
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Fonctionnalités de conformité pour les utilisateurs
description: Fonctionnalités de conformité.
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les fonctionnalités de conformité de GitLab pour les utilisateurs garantissent que vos groupes et projets GitLab respectent les normes de conformité courantes.

## Automatisation des workflows conformes {#compliant-workflow-automation}

Il est important que les équipes de conformité aient la certitude que leurs contrôles et exigences sont correctement configurés, mais aussi qu'ils le restent. Une façon d'y parvenir consiste à vérifier manuellement les paramètres de façon périodique, mais cette méthode est sujette aux erreurs et chronophage. Une meilleure approche consiste à utiliser des paramètres à source unique de vérité et l'automatisation pour s'assurer que tout ce qu'une équipe de conformité a configuré reste configuré et fonctionne correctement. Ces fonctionnalités peuvent vous aider à automatiser la conformité :

| Fonctionnalité                                                                                                                                  | Instances                            | Groupes                               | Projets                             | Description |
|:-----------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------|:-------------------------------------|:-------------------------------------|:------------|
| [Frameworks de conformité](compliance_frameworks/_index.md)                                                                      | {{< no >}} | {{< yes >}} | {{< no >}} | Décrivez le type d'exigences de conformité que les projets doivent respecter. |
| [Pipelines de conformité](compliance_pipelines.md)                                                                                 | {{< no >}} | {{< yes >}} | {{< no >}} | Définissez une configuration de pipeline à exécuter pour tout projet associé à un framework de conformité donné. |
| [Paramètres d'approbation de la politique d'approbation des merge requests](../application_security/policies/merge_request_approval_policies.md#approval_settings) | {{< yes >}} | {{< yes >}} | {{< yes >}} | Appliquez une politique d'approbation des merge requests imposant plusieurs approbateurs et remplacez divers paramètres de projet dans tous les groupes ou projets appliqués de votre instance ou groupe GitLab. |

## Gestion des audits {#audit-management}

Un aspect important de tout programme de conformité est la capacité à revenir en arrière et à comprendre ce qui s'est passé, quand cela s'est produit et qui en était responsable. Vous pouvez l'utiliser dans des situations d'audit ainsi que pour comprendre la cause racine des problèmes lorsqu'ils surviennent.

Il est utile de disposer à la fois de listes brutes de bas niveau de données d'audit et de listes récapitulatives de haut niveau de données d'audit. Grâce à ces deux approches, les équipes de conformité peuvent rapidement déterminer si des problèmes existent, puis approfondir les détails de ces tickets. Ces fonctionnalités peuvent contribuer à offrir une visibilité sur GitLab et à auditer ce qui se passe :

| Fonctionnalité                                           | Instances                            | Groupes                               | Projets                             | Description |
|:--------------------------------------------------|:-------------------------------------|:-------------------------------------|:-------------------------------------|:------------|
| [Événements d'audit](audit_events.md)                   | {{< yes >}} | {{< yes >}} | {{< yes >}} | Pour préserver l'intégrité de votre code, les événements d'audit donnent aux administrateurs la possibilité de consulter toutes les modifications apportées dans le serveur GitLab via un système avancé d'événements d'audit, afin de contrôler, analyser et suivre chaque changement. |
| [Rapports d'audit](audit_events.md)                  | {{< yes >}} | {{< yes >}} | {{< yes >}} | Créez des rapports et accédez-y en vous basant sur les événements d'audit survenus. Utilisez les rapports GitLab préconstruits ou l'API pour créer les vôtres. |
| [Streaming d'événements d'audit](audit_event_streaming.md) | {{< yes >}} | {{< yes >}} | {{< yes >}} | Diffusez les événements d'audit GitLab vers un endpoint HTTP ou un service tiers, tel qu'AWS S3 ou GCP Logging. |
| [Centre de conformité](compliance_center/_index.md)  | {{< no >}} | {{< yes >}} | {{< yes >}} | Obtenez rapidement une visibilité sur la posture de conformité de votre organisation grâce aux rapports d'adhésion aux normes de conformité et aux rapports de violations. Gérez les frameworks de conformité de vos groupes de manière centralisée. |

## Gestion des politiques {#policy-management}

Les organisations ont des exigences en matière de politiques qui leur sont propres, qu'elles découlent de normes organisationnelles ou de mandats émanant d'organismes de réglementation. Les fonctionnalités suivantes vous aident à définir des règles et des politiques pour respecter les exigences de workflow, la séparation des tâches et les bonnes pratiques en matière de chaîne d'approvisionnement sécurisée :

| Fonctionnalité                                                                                                                                                                                                                                                                | Instances                            | Groupes                               | Projets                             | Description |
|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------|:-------------------------------------|:-------------------------------------|:------------|
| [Rôles utilisateur granulaires<br/>et permissions flexibles](../permissions.md)                                                                                                                                                                                                  | {{< yes >}} | {{< yes >}} | {{< yes >}} | Gérez les accès et les permissions avec cinq rôles utilisateur différents et des paramètres pour les utilisateurs externes. Définissez les permissions selon le rôle des personnes, plutôt qu'en accordant un simple accès en lecture ou en écriture à un dépôt. Ne partagez pas le code source avec les personnes qui n'ont besoin que d'un accès au système de suivi des tickets. |
| [Approbations des merge requests](../project/merge_requests/approvals/_index.md)                                                                                                                                                                                               | {{< yes >}} | {{< yes >}} | {{< yes >}} | Configurez les approbations requises pour les merge requests. |
| [Règles de push](../project/repository/push_rules.md)                                                                                                                                                                                                                      | {{< yes >}} | {{< yes >}} | {{< yes >}} | Contrôlez les pushs vers vos dépôts. |
| Séparation des tâches avec<br/>[les branches protégées](../project/repository/branches/protected.md#require-code-owner-approval) et<br/>[les chemins de configuration CI/CD personnalisés](../../ci/pipelines/settings.md#specify-a-custom-cicd-configuration-file) | {{< no >}} | {{< no >}} | {{< yes >}} | Utilisez les configurations YAML inter-projets de GitLab pour définir les déployeurs de code et les développeurs de code. Découvrez comment utiliser cette configuration pour définir ces rôles dans le [projet de déploiement avec séparation des tâches](https://gitlab.com/guided-explorations/separation-of-duties-deploy/blob/master/README.md) et le [projet de séparation des tâches](https://gitlab.com/guided-explorations/separation-of-duties/blob/master/README.md). |
| [Politiques de sécurité](../application_security/policies/_index.md)                                                                                                                                                                                                        | {{< yes >}} | {{< yes >}} | {{< yes >}} | Configurez des politiques personnalisables qui exigent l'approbation des merge requests selon des règles de politique, ou imposez l'exécution de scanners de sécurité dans les pipelines de projet pour répondre aux exigences de conformité. Les politiques peuvent être appliquées de manière granulaire à des projets spécifiques ou à l'ensemble des projets d'un groupe ou sous-groupe. |

## Autres fonctionnalités de conformité {#other-compliance-features}

Ces fonctionnalités peuvent également contribuer à répondre aux exigences de conformité :

| Fonctionnalité                                                                                                                        | Instances                            | Groupes                               | Projets                             | Description |
|:-------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------|:-------------------------------------|:-------------------------------------|:------------|
| [Vérifications de statut externes](../project/merge_requests/status_checks.md)                                                           | {{< no >}} | {{< no >}} | {{< yes >}} | Interfacez avec des systèmes tiers que vous utilisez déjà lors du développement pour vous assurer de rester conforme. |
| [Politiques d'approbation des licences](license_approval_policies.md)                                                                      | {{< no >}} | {{< no >}} | {{< yes >}} | Recherchez les licences associées aux dépendances. Cela vous permet de déterminer si les licences des dépendances de votre projet sont compatibles avec la licence de votre projet. |
| [Verrouiller l'appartenance au projet sur le groupe](../group/access_and_permissions.md#prevent-members-from-being-added-to-projects-in-a-group) | {{< no >}} | {{< yes >}} | {{< no >}} | Les propriétaires de groupe peuvent empêcher l'ajout de nouveaux membres aux projets d'un groupe. |

## Sujets connexes {#related-topics}

- [Conformité logicielle avec GitLab](https://about.gitlab.com/solutions/compliance/)
- [Sécuriser GitLab](../../security/_index.md)
- [Fonctionnalités de conformité pour les administrateurs](../../administration/compliance/compliance_features.md)
