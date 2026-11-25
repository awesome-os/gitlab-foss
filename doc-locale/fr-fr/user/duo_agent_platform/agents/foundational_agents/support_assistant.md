---
stage: Agent Foundations
group: AI Catalog
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
title: Support Assistant
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/237380) en tant que [version bêta](../../../../policy/development_stages_support.md#beta) dans GitLab 19.2.

{{< /history >}}

Le Support Assistant est un agent spécialisé qui vous aide à :

- Diagnostiquer un problème lié à un produit GitLab lorsque vous ne savez pas par où commencer.
- Trouver la documentation de dépannage pour une zone fonctionnelle spécifique.
- Vérifier si le problème est un problème connu.
- Préparer un ticket de support avec les informations de diagnostic pertinentes lorsque vous devez escalader vers un humain.

Le Support Assistant aide à diagnostiquer les problèmes GitLab. Pour les autres problèmes, le Support Assistant essaie de vous orienter vers l'équipe appropriée.

Pour plus d'informations sur le Support Assistant, consultez le [fichier YAML de configuration de l'agent](https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/blob/main/duo_workflow_service/agent_platform/v1/flows/configs/support_assistant/1.0.0.yml).

## Utiliser le Support Assistant {#use-the-support-assistant}

Prérequis :

- [Activer les agents par défaut](_index.md#turn-foundational-agents-on-or-off).
- [Activer les fonctionnalités en version bêta et expérimentales](../../turn_on_off.md#turn-on-beta-and-experimental-features).

Pour utiliser le Support Assistant :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale GitLab Duo, sélectionnez **Ajouter une discussion** ({{< icon name="pencil-square" >}}).
1. Dans la liste déroulante, sélectionnez **Support Assistant**.

   Une conversation Chat s'ouvre dans la barre latérale GitLab Duo située à droite de l'écran.
1. Décrivez votre problème GitLab avec vos propres mots, puis répondez aux questions de suivi au fur et à mesure que l'agent en diagnostique la cause. Pour obtenir les meilleurs résultats de votre demande :

   - Commencez par le symptôme et l'impact. Par exemple, « Les builds échouent depuis ce matin et bloquent toutes les fusions » apporte plus d'éléments exploitables que « la CI est cassée ».
   - Incluez le message d'erreur exact (avec les secrets masqués) et le code d'erreur, s'il y en a un.
   - Indiquez ce que vous avez déjà essayé, afin que l'agent ne suggère pas la même chose à nouveau.
   - Mentionnez votre environnement dès le début : GitLab.com SaaS, GitLab Self-Managed (et le type d'installation, tel que le package Linux ou le chart Helm), ou GitLab Dedicated, ainsi que la version.
   - Signalez l'urgence. S'il s'agit d'une panne en production, précisez-le, et l'agent passe directement à la préparation d'un ticket urgent.
   - Limitez-vous à un problème par conversation, afin que le diagnostic reste ciblé.

### Exemples de prompts {#example-prompts}

- « Mon pipeline échoue de manière intermittente sans message d'erreur clair. Par où dois-je commencer ? »
- « L'analyse des dépendances ne signale aucune vulnérabilité pour mon projet. »
- « J'obtiens des erreurs 403 lorsque j'appelle l'API avec un jeton d'accès personnel. »
- « Notre Geo secondaire est très en retard par rapport au principal. S'agit-il d'un problème connu ? »
- « J'ai besoin d'ouvrir un ticket de support pour des performances lentes de Gitaly. Que dois-je inclure ? »
- « Quelle archive de diagnostic dois-je collecter pour une installation GitLab Self-Managed basée sur Helm ? »
