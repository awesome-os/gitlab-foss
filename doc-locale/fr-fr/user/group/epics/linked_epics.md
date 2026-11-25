---
stage: Plan
group: Portfolio Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Liez des epics pour coordonner le travail entre les équipes, gérer les dépendances et connecter l'exécution à court terme avec la planification à long terme dans GitLab."
title: Epics liés
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les epics liés sont une relation bidirectionnelle entre deux epics et apparaissent dans un bloc sous la description de l'epic. Vous pouvez lier des epics dans différents groupes.

La relation n'apparaît dans l'interface utilisateur que si l'utilisateur peut voir les deux epics. Lorsque vous tentez de fermer un epic qui a des bloqueurs ouverts, un avertissement s'affiche.

Pour gérer les éléments liés, consultez l'[API des epics liés](../../../api/linked_epics.md).

## Façons d'utiliser les epics liés {#ways-to-use-linked-epics}

Vous pouvez utiliser les epics liés pour résoudre plusieurs défis de planification et de coordination. Les exemples suivants montrent comment les epics liés aident les équipes à travailler plus efficacement ensemble.

### Initiatives transversales {#cross-functional-initiatives}

Utilisez les epics liés pour coordonner le travail entre plusieurs équipes et suivre les livrables interdépendants. Lorsque des équipes collaborent sur une grande initiative, chaque équipe peut gérer son propre epic tout en maintenant une visibilité sur les travaux connexes.

<!-- vale gitlab_base.OxfordComma = NO -->
Par exemple, lors du lancement d'une nouvelle fonctionnalité, les équipes de développement et de marketing travaillent souvent en parallèle. L'équipe de développement suit l'implémentation technique dans son epic, tandis que l'équipe marketing planifie les activités promotionnelles dans un epic séparé.
<!-- vale gitlab_base.OxfordComma = YES -->

En liant ces epics :

- Les équipes peuvent suivre les dépendances entre les travaux techniques et promotionnels.
- Chaque équipe maintient son autonomie tout en restant alignée sur l'initiative globale.
- Les parties prenantes obtiennent une visibilité sur la portée complète du lancement.
- Les équipes peuvent identifier et résoudre les bloqueurs au-delà des frontières organisationnelles.

Cette coordination aide à éliminer les silos et garantit que tous les aspects de l'initiative restent synchronisés.

Lorsque vous liez des epics entre groupes :

- Chaque équipe conserve son travail dans son propre groupe.
- Les équipes peuvent voir les travaux connexes sans passer d'un groupe à l'autre.
- Les mises à jour de statut se propagent automatiquement entre les epics liés.

### Gestion des dépendances {#dependency-management}

Utilisez les epics liés pour gérer et suivre les dépendances de travail. Lorsque le développement ne peut pas commencer avant que les modifications d'infrastructure soient terminées, les epics liés aident les équipes à gérer ces dépendances.

Par exemple, lors de la création d'une nouvelle fonctionnalité, les équipes ont souvent besoin de mises à jour de l'infrastructure avant que le développement puisse démarrer. L'équipe d'infrastructure suit ses travaux de migration de base de données dans un epic, tandis que l'équipe de développement planifie l'implémentation des fonctionnalités dans un autre epic.

En liant ces epics :

- Les équipes peuvent savoir quand les travaux d'infrastructure sont prêts pour le développement.
- Les équipes de développement peuvent mieux planifier leur capacité de sprint.
- Les chefs de produit peuvent identifier les retards potentiels dans le workflow.
- Les équipes restent informées de l'avancement sans réunions constantes.

Cette visibilité aide les équipes à effectuer les travaux dans le bon ordre et à éviter les tâches bloquées.

Lorsque vous liez des epics pour afficher les dépendances :

- Les travaux d'infrastructure et de développement restent connectés.
- Les équipes savent quand elles peuvent commencer leur travail.
- Les mises à jour de statut se propagent automatiquement entre les epics.

### Planification de haut niveau {#higher-level-planning}

Utilisez les epics liés pour connecter l'exécution à court terme avec la planification à long terme. Lors de la gestion d'une série de releases, vous pouvez organiser les objectifs de haut niveau et suivre les livrables de fonctionnalités individuelles.

Par exemple, lors de la planification de plusieurs releases sur plusieurs trimestres, vous pouvez créer des epics séparés pour chaque release. Liez ensuite ces epics de release à un epic de roadmap central qui suit l'avancement global du projet.

En liant ces epics :

- Les équipes peuvent comprendre comment leur travail s'inscrit dans la stratégie globale.
- Les chefs de produit peuvent suivre l'avancement de plusieurs releases.
- Les équipes restent concentrées sur le travail en cours tout en ayant une visibilité sur les plans futurs.
- Les parties prenantes peuvent suivre à la fois l'avancement détaillé et l'avancement de haut niveau.

Cette structure aide les équipes à progresser sur le travail en cours tout en maintenant les objectifs généraux.

Lorsque vous liez des epics pour la planification :

- L'avancement de chaque release est visible dans le roadmap.
- Les équipes peuvent voir les travaux à venir en avance.
- Les mises à jour de statut remontent vers la vue de haut niveau.

## Ajouter un élément lié {#add-a-linked-item}

{{< history >}}

- Possibilité de lier des tickets, des tâches, des objectifs et des résultats clés [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/468310) dans GitLab 18.1.

{{< /history >}}

Lier un epic à un autre :

- Epic
- Ticket
- Tâche
- Objectif
- Résultat clé

Prérequis :

- Vous devez disposer du rôle Invité, Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour les deux groupes, ou pour le groupe et le projet.
- Pour GitLab.com : l'epic que vous modifiez doit se trouver dans un groupe sous GitLab Ultimate. Les epics que vous liez peuvent se trouver dans un groupe d'une édition inférieure.

Pour lier un epic à un autre élément :

1. Dans la section **Éléments liés** d'un epic, sélectionnez **Ajouter**.
1. Sélectionnez la relation entre les deux éléments. L'une ou l'autre des options :

   - **en relation avec**
   - **bloque**
   - **est bloqué(e) par**

1. Pour saisir l'élément lié, effectuez l'une des opérations suivantes :

   - Saisissez `#`, suivi du numéro de l'élément. Par exemple, `#123`.
   - Saisissez `#`, suivi d'un mot du titre de l'élément. Par exemple, `#Deliver`.
   - Collez l'URL complète de l'élément.

   Les éléments du même groupe peuvent être spécifiés uniquement par le numéro de référence. Les éléments d'un groupe différent nécessitent des informations supplémentaires telles que le nom du groupe. Par exemple :

   - Le même groupe : `#44`
   - Groupe différent : `group#44`

   Les références valides sont ajoutées à une liste temporaire que vous pouvez examiner.

1. Sélectionnez **Ajouter**.

Les éléments liés sont ensuite affichés sur l'epic regroupés par relation. La relation n'apparaît dans l'interface utilisateur que si l'utilisateur peut voir les deux éléments.

Vous pouvez également ajouter des éléments liés en utilisant des [actions rapides](../../project/quick_actions.md) :

- `/relate`
- `/blocks`
- `/blocked_by`

## Supprimer un élément lié {#remove-a-linked-item}

Prérequis :

- Vous devez disposer du rôle Invité, Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe de l'epic.

Pour supprimer un élément lié :

1. En bas de la description, trouvez la section **Éléments liés** de l'élément de travail.
1. Pour chaque élément lié, sélectionnez **Supprimer** ({{< icon name="close" >}}).

La relation est supprimée des deux epics.

## Epics bloquants {#blocking-epics}

Lorsque vous [ajoutez un élément lié](#add-a-linked-item), vous pouvez indiquer qu'il **bloque** ou **est bloqué(e) par** un autre epic.

Si vous tentez de fermer un epic bloqué en utilisant le bouton **Fermer l'epic**, un message de confirmation s'affiche.
