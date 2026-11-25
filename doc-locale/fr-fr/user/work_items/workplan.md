---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Capturez l'intention, l'approche et les étapes d'une unité de travail dans un plan de travail structuré que les agents GitLab Duo peuvent exécuter."
title: Plan de travail
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed
- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/240718) dans GitLab 19.0 [avec le feature flag](../../administration/feature_flags/_index.md) `workplan`. Fonctionnalité désactivée par défaut.
- Le widget Plan de travail a [été modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/250010) dans GitLab 19.4.
- Affichage et mise en œuvre d'un plan de travail depuis GitLab Duo Agentic Chat [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/252727) dans GitLab 19.4.
- Affichage et mise en œuvre d'un plan de travail depuis GitLab Duo Agentic Chat [supprimés](https://gitlab.com/gitlab-org/gitlab/-/work_items/626672) dans GitLab 19.5.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Un plan de travail est un document Markdown structuré associé à un élément de travail. Il capture l'intention, l'approche et les étapes d'une unité de travail.

Un plan de travail fournit aux agents GitLab Duo une spécification convenue et un artefact consultable par un humain sur l'élément de travail. Avec ce contexte, un agent dispose de plus d'informations qu'une simple invite courte, ce qui lui permet d'exécuter le travail plus précisément.

Vous créez un plan de travail avec GitLab Duo ou en rédigez un manuellement. GitLab Duo rédige le plan de travail à partir du contexte de l'élément de travail, et vous l'affinez. Les agents utilisent ensuite le plan de travail comme spécification principale pour le travail.

Le plan de travail fait partie de la [plateforme d'agents GitLab Duo](../duo_agent_platform/_index.md) et du workflow de développement piloté par les spécifications.

Vous pouvez ajouter un plan de travail aux tickets et aux tâches.

Après avoir activé la planification pour un élément de travail, le widget **Plan de travail** apparaît et affiche le statut du plan de travail :

- **Pas encore créé** : l'élément de travail n'a pas de plan de travail, et vous pouvez en créer un.
- **Aucun plan de travail** : l'élément de travail n'a pas de plan de travail, et vous n'avez pas l'autorisation d'en créer un.
- **Prêt à afficher** : l'élément de travail dispose d'un plan de travail.

## Avantages {#benefits}

Un plan de travail sépare l'intention de la mise en œuvre :

- La description de l'élément de travail capture l'intention, c'est-à-dire ce que vous voulez et pourquoi. Les personnes lisent la description pour comprendre l'objectif.
- Le plan de travail capture la mise en œuvre, c'est-à-dire comment effectuer le travail. Les agents suivent le plan de travail pour réaliser le travail.

Cette séparation vous offre trois avantages :

- Protection de l'intention : un agent itère sur le plan de travail dans un champ distinct de la description de l'élément de travail, de sorte que votre intention reste intacte même lorsque le plan évolue au fil de plusieurs exécutions.
- Révision du plan : un agent s'arrête après avoir produit un plan de travail, ce qui vous permet de réviser, d'affiner et d'approuver le plan avant que tout travail ne commence.
- Focus de l'agent : le plan de travail étant un champ dédié, un agent chargé de planifier le travail y place ce contexte au lieu de réécrire la description ou d'autres parties de l'élément de travail.

## Quand utiliser un plan de travail {#when-to-use-a-workplan}

Utilisez un plan de travail lorsque vous prévoyez de confier du travail à un agent, soit en sélectionnant **Mettre en œuvre**, soit en fournissant vous-même le plan à un agent de codage. Un plan de travail apporte le plus de valeur lorsqu'un agent exécute le travail.

Vous n'avez pas besoin d'un plan de travail pour les modifications simples ou bien comprises, où la planification demande plus d'effort qu'elle n'en économise.

## Activer la planification pour un élément de travail {#turn-on-planning-for-a-work-item}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/250010) dans GitLab 19.4.

{{< /history >}}

Par défaut, le widget **Plan de travail** et le score de confiance sont masqués sur un élément de travail. Pour les afficher, activez la planification pour cet élément de travail.

Prérequis :

- L'élément de travail doit être un ticket ou une tâche.
- Autorisation de modifier l'élément de travail.

Pour activer la planification :

- Sur l'élément de travail, dans le coin supérieur droit, sélectionnez **Forfait**.

Le widget **Plan de travail** apparaît sur l'élément de travail, et le bouton **Forfait** n'apparaît plus. Une fois la planification activée pour un élément de travail, vous ne pouvez pas la désactiver.

## Créer un plan de travail {#create-a-workplan}

Créez un plan de travail pour décrire comment accomplir une unité de travail.

Prérequis :

- Planification activée pour l'élément de travail.
- Autorisation de modifier l'élément de travail.

Vous pouvez générer un plan de travail avec GitLab Duo ou en rédiger un manuellement.

### Générer un plan de travail avec GitLab Duo {#generate-a-workplan-with-gitlab-duo}

Prérequis :

- [GitLab Duo Chat](../gitlab_duo_chat/agentic_chat.md) activé.

Pour générer un plan de travail avec GitLab Duo :

1. Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Générer**.
1. Dans GitLab Duo Chat, répondez aux questions de l'[agent Planner](../duo_agent_platform/agents/foundational_agents/planner.md) jusqu'à ce que l'agent dispose de suffisamment de contexte.
1. Révisez le plan proposé et approuvez-le.

Après avoir approuvé le plan, GitLab Duo l'écrit dans le widget **Plan de travail**.

### Créer un plan de travail manuellement {#create-a-workplan-manually}

Pour créer un plan de travail manuellement :

1. Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Plus d'options** > **Créer manuellement**.
1. Facultatif. Dans la liste déroulante des modèles, sélectionnez un modèle de plan de travail.
1. Saisissez le contenu du plan de travail. Pour basculer entre les éditeurs, sélectionnez **Passer à l'édition en texte enrichi** ou **Passer à l'édition en texte brut**.
1. Sélectionnez **Enregistrer les modifications**.

Les modèles de plan de travail sont des [modèles de description](../project/description_templates.md) dont les noms de fichier se terminent par `.plan`.

## Afficher un plan de travail {#view-a-workplan}

Pour afficher un plan de travail :

1. Accédez à l'élément de travail.
1. Dans le widget **Plan de travail**, sélectionnez **Afficher**.

Le plan de travail s'ouvre dans un panneau et affiche le contenu rendu.

## Modifier un plan de travail {#edit-a-workplan}

Prérequis :

- Autorisation de modifier l'élément de travail.

Pour modifier un plan de travail :

1. Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Afficher**.
1. Dans le panneau, sélectionnez **Modifier**.
1. Effectuez vos modifications.
1. Sélectionnez **Enregistrer les modifications**.

Pour annuler vos modifications, sélectionnez **Annuler**.

## Regénérer un plan de travail {#regenerate-a-workplan}

Regénérez un plan de travail pour remplacer son contenu par une nouvelle version générée par GitLab Duo.

Prérequis :

- Autorisation de modifier l'élément de travail.

Pour regénérer un plan de travail :

1. Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Afficher**.
1. Dans le panneau, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) > **Générer à nouveau un plan de travail**.
1. Dans GitLab Duo Chat, répondez aux questions de l'agent Planner jusqu'à ce que l'agent dispose de suffisamment de contexte.

GitLab Duo remplace le plan de travail existant par la nouvelle version.

## Supprimer un plan de travail {#delete-a-workplan}

Prérequis :

- Autorisation de modifier l'élément de travail.

Pour supprimer un plan de travail :

1. Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Afficher**.
1. Dans le panneau, sélectionnez **Plus d'actions** ({{< icon name="ellipsis_v" >}}) > **Supprimer un plan de travail**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer**.

Cette action est irréversible.

## Score de confiance {#confidence-score}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248374) dans GitLab 19.3 [avec le feature flag](../../administration/feature_flags/_index.md) `workplan_score`. Fonctionnalité désactivée par défaut.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Le score de confiance indique dans quelle mesure un élément de travail est prêt à être exécuté par un agent. GitLab Duo évalue l'élément de travail en fonction de son exhaustivité, de sa clarté et de sa portée, puis associe le score à un niveau de confiance.

Prérequis :

- Planification activée pour l'élément de travail.

Dans le widget **Plan de travail** de l'élément de travail, le niveau de confiance apparaît sous la forme **Faible**, **Moyenne** ou **Élevée**. Le niveau de confiance n'apparaît qu'après que GitLab Duo a généré un plan de travail et calculé un score.

Pour améliorer le score, ajoutez plus de détails à la description de l'élément de travail et aux étapes du plan de travail, tels que les exigences, les critères d'acceptation et les contraintes.

## Journal de décisions {#decision-log}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/249268) dans GitLab 19.3 [avec le feature flag](../../administration/feature_flags/_index.md) `decision_log`. Fonctionnalité désactivée par défaut.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Le journal de décisions est un enregistrement des décisions prises concernant un élément de travail. Il conserve la raison de chaque décision à côté de l'élément de travail, afin que l'historique ne soit pas perdu dans le chat ou dans les fils de discussion de commentaires.

Le journal de décisions est disponible sur les tickets et les tâches, ainsi que sur les types d'éléments de travail personnalisés basés sur des tickets ou des tâches. Un élément de travail n'a pas besoin d'un plan de travail pour disposer d'un journal de décisions.

GitLab Duo ajoute une décision au journal lorsqu'il résout une question ouverte pendant la planification du travail. Vous pouvez également enregistrer vous-même une décision à tout moment.

Prérequis :

- Vous devez disposer au minimum du rôle Planificateur pour le projet.

Pour ouvrir le journal de décisions :

- Sur l'élément de travail, dans l'en-tête, sélectionnez **Journal de décisions** ({{< icon name="log" >}}).

Le bouton affiche le nombre de décisions sur l'élément de travail.

### Enregistrer une décision manuellement {#record-a-decision-manually}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/254465) dans GitLab 19.5 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `decision_log`. Fonctionnalité désactivée par défaut.

{{< /history >}}

Pour enregistrer une décision manuellement :

1. Sur l'élément de travail, dans l'en-tête, sélectionnez **Journal de décisions** ({{< icon name="log" >}}).
1. Dans le panneau, sélectionnez **Nouvelle décision**.
1. Remplissez les champs. Les champs obligatoires sont **Décision**, **Décidé par** et **Contexte**.
1. Facultatif. Dans **Pourquoi**, expliquez pourquoi vous avez choisi cette option plutôt que d'autres.
1. Facultatif. Dans **Lien source**, ajoutez un lien vers l'endroit où la discussion a eu lieu, tel que Slack, Google Docs ou GitLab.
1. Sélectionnez **Créer une décision**.

## Mettre en œuvre un plan de travail avec GitLab Duo {#implement-a-workplan-with-gitlab-duo}

Lorsqu'un plan de travail existe, GitLab Duo peut le mettre en œuvre dans une merge request. GitLab Duo traite le plan de travail comme la spécification principale et n'utilise la description de l'élément de travail et les commentaires que comme contexte supplémentaire.

Prérequis :

- Flows distants de la plateforme d'agents GitLab Duo activés.

Pour mettre en œuvre un plan de travail avec GitLab Duo, utilisez l'une des méthodes suivantes :

- Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Mettre en œuvre**.
- Ouvrez le plan de travail, puis mettez-le en œuvre depuis le panneau :
  1. Sur l'élément de travail, dans le widget **Plan de travail**, sélectionnez **Afficher**.
  1. Dans le panneau, sélectionnez **Mettre en œuvre**.

## Sujets connexes {#related-topics}

- [GitLab Duo Agent Platform](../duo_agent_platform/_index.md)
- [Agent Planner](../duo_agent_platform/agents/foundational_agents/planner.md)
- [Modèles de description](../project/description_templates.md)
- [Éléments de travail](_index.md)
