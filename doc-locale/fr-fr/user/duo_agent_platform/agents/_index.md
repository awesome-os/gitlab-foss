---
stage: Agent Foundations
group: AI Catalog
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Découvrez les agents par défaut, personnalisés et externes disponibles dans la plateforme GitLab Duo Agent Platform."
title: Agents
---

{{< details >}}

- Édition : [Gratuite](../../../subscriptions/gitlab_credits.md#for-the-free-tier), GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< collapsible title="Informations sur le modèle" >}}

- [LLM par défaut](../model_selection.md#default-models)

{{< /collapsible >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/549914) dans GitLab 18.5 [avec le feature flag](../../../administration/feature_flags/_index.md) `global_ai_catalog`. Activé sur GitLab.com.
- Les agents par défaut et personnalisés sont [passés](https://gitlab.com/gitlab-org/gitlab/-/issues/568176) en version bêta dans GitLab 18.7.
- Les agents par défaut, externes et personnalisés sont [généralement disponibles](https://gitlab.com/gitlab-org/gitlab/-/work_items/585273) dans GitLab 18.8.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/223135) du feature flag `global_ai_catalog` dans GitLab 18.10.
- Disponible sur l’édition Gratuite sur GitLab.com avec des GitLab Credits dans GitLab 18.10.

{{< /history >}}

Les agents sont des assistants basés sur l'IA qui vous aident à accomplir des tâches spécifiques et à répondre à des questions complexes.

GitLab propose trois types d'agents :

- Les [agents par défaut](foundational_agents/_index.md) sont des agents préconstruits et prêts pour la production, créés par GitLab pour les workflows courants. Ces agents sont dotés d'une expertise spécialisée et d'outils adaptés à des domaines spécifiques. Les agents par défaut sont activés par défaut, ce qui vous permet de commencer à les utiliser avec GitLab Duo Chat.
- Les [agents personnalisés](custom.md) sont des agents que vous créez et configurez selon les besoins spécifiques de votre équipe. Vous définissez leur comportement à l'aide de prompts système et choisissez les outils auxquels ils peuvent accéder. Les agents personnalisés sont idéaux lorsque vous avez besoin de workflows spécialisés non couverts par les agents par défaut. Pour interagir avec un agent personnalisé, activez-le dans un groupe ou un projet afin de l'utiliser avec Chat.
- Les [agents externes](external.md) s'intègrent avec des fournisseurs de modèles d'IA extérieurs à GitLab. Utilisez des agents externes pour permettre à des fournisseurs de modèles comme Claude d'opérer dans GitLab. Vous pouvez déclencher un agent externe directement depuis une discussion, un ticket ou une merge request.
