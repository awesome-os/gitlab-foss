---
stage: Agent Foundations
group: Agent Execution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Utilisez des flows par défaut et des flows personnalisés pour automatiser des tâches de développement complexes avec plusieurs agents.
title: Flows
---

{{< details >}}

- Édition : [Gratuite](../../../subscriptions/gitlab_credits.md#for-the-free-tier), GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< collapsible title="Informations sur le modèle" >}}

- LLM : Anthropic [Claude Sonnet 4](https://www.anthropic.com/claude/sonnet)

{{< /collapsible >}}

{{< history >}}

- Introduction en [version expérimentale](../../../policy/development_stages_support.md) dans GitLab 18.4 [avec le feature flag](../../../administration/feature_flags/_index.md) `ai_catalog_flows`. Désactivé par défaut.
- Passage en [version bêta](../../../policy/development_stages_support.md) dans GitLab 18.7.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/569060) dans GitLab 18.7.
- [Activé sur GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/issues/569060) dans GitLab 18.8.
- Feature flag `ai_catalog_flows` [activé par défaut](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/216969) dans GitLab 18.8.
- Des flags supplémentaires sont requis pour les flows par défaut.
- Les flows par défaut sont passés en [disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/work_items/585273) dans GitLab 18.8.
- Les flows personnalisés sont passés en [version bêta](https://gitlab.com/gitlab-org/gitlab/-/work_items/585273) dans GitLab 18.8.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/239459) du feature flag `ai_catalog_flows` dans GitLab 19.2.
- Les flows personnalisés sont passés en [disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/work_items/602415) dans GitLab 19.2.

{{< /history >}}

Un flow est une combinaison d'un ou plusieurs agents travaillant ensemble pour résoudre un problème complexe.

GitLab propose deux types de flows :

- Les [flows par défaut](foundational_flows/_index.md) sont des workflows prêts pour la production, préconfigurés par GitLab pour les tâches de développement courantes.
- Les [flows personnalisés](custom.md) sont des workflows que vous créez pour automatiser les processus spécifiques de votre équipe. Vous définissez les étapes du workflow et les agents, et définissez des déclencheurs pour contrôler le moment où le flow s'exécute.

Les flows sont disponibles dans les IDE et dans l'interface GitLab.

- Dans l'interface, ils s'exécutent directement dans GitLab CI/CD, vous aidant à automatiser les tâches de développement courantes sans avoir à quitter votre navigateur.
- Dans les IDE, le flow de développement logiciel est disponible dans VS Code, Visual Studio et JetBrains. La prise en charge d'autres flows est en cours de proposition.

Pour plus d'informations sur la façon dont les flows s'exécutent dans CI/CD, consultez [la documentation sur l'exécution des flows](execution/_index.md). Pour des informations sur la sécurité des flows, consultez [la documentation sur l'identité composite](../composite_identity.md).

## Prérequis {#prerequisites}

<!-- Note: These prerequisites are duplicated on each flow sub-page. Update all pages when editing. -->

- Satisfaire aux [prérequis pour GitLab Duo Agent Platform](../_index.md#prerequisites).
- Activez **Autoriser les flows par défaut** [pour le groupe principal](foundational_flows/_index.md#turn-foundational-flows-on-or-off).
- [Configurer les règles push pour autoriser un compte de service](../troubleshooting.md#configure-push-rules-to-allow-a-service-account).
- [Configurer vos propres runners](execution/_index.md#configure-runners-to-execute-flows) ou activer les [runners hébergés par GitLab](../../../ci/runners/hosted_runners/_index.md) pour votre projet.
- Recommandé. Créez un [fichier de configuration d'agent](execution/_index.md#create-the-agent-configuration-file) afin que les flows dans CI/CD aient accès à la chaîne d'outils et aux dépendances de votre projet.

## Surveiller les flows en cours d'exécution dans l'interface GitLab {#monitor-running-flows-in-the-gitlab-ui}

Pour afficher les flows en cours d'exécution pour votre projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **IA** > **Sessions**.

## Afficher l'historique des flows dans les IDE {#view-flow-history-in-the-ides}

Pour afficher l'historique des flows que vous avez exécutés dans votre projet :

- Dans l'onglet **Flux**, faites défiler vers le bas et consultez **Sessions d'agent récentes**.

## Personnaliser les flows avec `AGENTS.md` {#customize-flows-with-agentsmd}

Utilisez les fichiers `AGENTS.md` pour fournir un contexte et des instructions que GitLab Duo doit suivre lors de l'exécution des flows par défaut et des flows personnalisés.

Pour plus d'informations, consultez [les fichiers de personnalisation `AGENTS.md`](../customize/agents_md.md).

## Donner un avis {#give-feedback}

Les flows font partie de la plateforme de développement alimentée par l'IA de GitLab. Vos retours nous aident à améliorer ces workflows. Pour signaler des problèmes ou suggérer des améliorations concernant les flows, [répondez à ce sondage](https://gitlab.fra1.qualtrics.com/jfe/form/SV_9GmCPTV7oH9KNuu).

## Sujets connexes {#related-topics}

- [Configurer l'environnement d'exécution des flows](execution/_index.md)
- [Flows par défaut](foundational_flows/_index.md)
- [Callbacks webhook](webhook_callbacks.md)
