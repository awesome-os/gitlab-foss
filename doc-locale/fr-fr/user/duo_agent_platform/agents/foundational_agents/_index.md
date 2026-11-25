---
stage: Agent Foundations
group: AI Catalog
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Agents de base
---

{{< details >}}

- Édition : [Gratuite](../../../../subscriptions/gitlab_credits.md#for-the-free-tier), GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/576618) en version bêta dans GitLab 18.6.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/work_items/585273) dans GitLab 18.8.
- Disponibilité pour l'édition Gratuite sur GitLab.com avec des GitLab Credits dans GitLab 18.10.

{{< /history >}}

Les agents de base sont des assistants IA spécialisés qui étendent les capacités de GitLab Duo Chat grâce à une expertise spécifique à chaque domaine et une conscience du contexte.

Contrairement à l'agent GitLab Duo polyvalent, les agents de base comprennent les workflows, les cadres et les bonnes pratiques propres à leurs domaines de spécialisation. Chaque agent combine une connaissance approfondie des fonctionnalités GitLab avec un raisonnement propre à chaque rôle, afin de fournir une aide ciblée qui correspond à la façon dont les praticiens travaillent réellement.

Les agents de base sont conçus et maintenus par GitLab et affichent un badge « maintenu par GitLab » ({{< icon name="tanuki-verified" >}}).

## Prérequis {#prerequisites}

- Satisfaire aux [prérequis pour GitLab Duo Agent Platform](../../_index.md#prerequisites).
- Avoir les [agents de base activés](#turn-foundational-agents-on-or-off).

## Agents de base disponibles {#available-foundational-agents}

Les agents de base suivants sont disponibles dans l'interface utilisateur de GitLab, VS Code et les IDE JetBrains. La disponibilité selon l'édition varie selon l'agent. Pour plus d'informations, consultez la page de chaque agent.

| Agent | Description |
|-------|-------------|
| [CI Expert](ci_expert_agent.md) | Créez, déboguez et optimisez les pipelines GitLab CI/CD. |
| [Data Analyst](data_analyst.md) | Analysez et visualisez les données de la plateforme. |
| [Flow Creator](flow_creator.md) | Créez des flows personnalisés pour le catalogue d'IA depuis le Chat. |
| [Onboarding Agent](onboarding_guide.md) | Adoptez la plateforme GitLab DevSecOps, depuis la première importation de dépôt jusqu'à la maturité en matière de sécurité et de conformité. |
| [Permissions Assistant](permissions_assistant.md) | Sélectionnez les autorisations appropriées pour un jeton d'accès personnel à granularité fine. |
| [Planificateur](planner.md) | Obtenez de l'aide pour la gestion de produits et les workflows de planification. |
| [Security Analyst](security_analyst_agent.md) | Obtenez de l'aide pour l'analyse de sécurité et la gestion des vulnérabilités. |
| [Support Assistant](support_assistant.md) | Diagnostiquez et résolvez les problèmes liés aux produits GitLab. |

## Dupliquer un agent {#duplicate-an-agent}

Pour apporter des modifications à un agent de base, créez-en une copie.

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.

Pour dupliquer un agent :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** > **Explorer**.
1. Sélectionnez **Catalogue d'IA**, puis sélectionnez l'onglet **Agents**.
1. Sélectionnez l'agent que vous souhaitez dupliquer.
1. Dans le coin supérieur droit, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **Dupliquer**.
1. Sous **Visibilité et accès** :
   1. Dans la liste déroulante **Géré par**, sélectionnez un projet pour l'agent.
   1. Pour **Visibilité**, sélectionnez **Privé** ou **Public**.
1. Facultatif. Modifiez les champs de votre choix.
1. Sélectionnez **Créer un agent**.

Un agent personnalisé est créé. Pour l'utiliser, vous devez [l'activer](../custom.md#enable-an-agent).

## Activer ou désactiver les agents de base {#turn-foundational-agents-on-or-off}

Par défaut, les agents de base sont activés. Vous pouvez les activer ou les désactiver pour un groupe principal (espace de nommage) ou pour une instance.

Si vous désactivez les agents de base par défaut :

- Les agents de base qui utilisent la configuration par défaut, y compris les agents nouvellement publiés, sont désactivés.
- Vous pouvez toujours utiliser l'agent GitLab Duo par défaut.

{{< tabs >}}

{{< tab title="Pour GitLab.com" >}}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **GitLab Duo**.
1. Sélectionnez **Modifier la configuration**.
1. Sous **Agents de base**, pour **Disponibilité par défaut**, sélectionnez l'une des options suivantes :
   - **Activée**
   - **Désactivée**
1. Sous **Paramètres de disponibilité**, pour chaque agent, sélectionnez l'une des options suivantes :
   - **Activée**
   - **Désactivée**
   - **Utiliser par défaut (Activé)** ou **Utiliser par défaut (Désactivé)**
1. Sélectionnez **Enregistrer les modifications**.

Ces paramètres s'appliquent aux :

- Utilisateurs dont le groupe principal est l'[espace de nommage GitLab Duo par défaut](../../../profile/preferences.md#set-a-default-gitlab-duo-namespace).
- Utilisateurs sans espace de nommage par défaut, qui visitent un espace de nommage appartenant au groupe principal.

Si vous désactivez les agents de base pour un groupe principal, les utilisateurs ayant ce groupe comme espace de nommage GitLab Duo par défaut ne peuvent pas accéder aux agents de base dans aucun espace de nommage.

{{< /tab >}}

{{< tab title="Pour une instance" >}}

Prérequis :

- Vous devez être administrateur.

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **GitLab Duo**.
1. Sélectionnez **Modifier la configuration**.
1. Sous **Agents de base**, pour **Disponibilité par défaut**, sélectionnez l'une des options suivantes :
   - **Activée**
   - **Désactivée**
1. Sous **Paramètres de disponibilité**, pour chaque agent, sélectionnez l'une des options suivantes :
   - **Activée**
   - **Désactivée**
   - **Utiliser par défaut (Activé)** ou **Utiliser par défaut (Désactivé)**
1. Sélectionnez **Enregistrer les modifications**.

{{< /tab >}}

{{< /tabs >}}
