---
stage: Plan
group: Portfolio Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Connectez et suivez les relations entre les éléments de travail dans GitLab. Gérez les dépendances, associez les objectifs stratégiques à l'exécution et coordonnez les initiatives transverses."
title: Éléments liés
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les éléments liés créent des relations bidirectionnelles entre les éléments de travail, ce qui vous aide à visualiser et à gérer les dépendances dans l'ensemble de votre workflow.

Grâce aux éléments liés, vous pouvez connecter différents types d'éléments de travail, notamment des tickets, des epics, des tâches et des objectifs, afin d'illustrer les relations qui existent entre eux.

Ces connexions permettent à chacun de comprendre comment les différents éléments de travail sont liés entre eux et aux initiatives stratégiques plus larges.

## Utilisations des éléments liés {#ways-to-use-linked-items}

Vous pouvez utiliser les éléments liés pour résoudre plusieurs défis en matière de planification et de coordination.

Les exemples suivants illustrent comment les éléments liés aident les équipes à collaborer plus efficacement.

### Suivre les dépendances {#track-dependencies}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate

{{< /details >}}

Identifiez clairement les tâches qui bloquent d'autres éléments ou qui sont bloquées par eux.

Lorsque vous associez des éléments avec une relation de blocage :

- Les équipes peuvent immédiatement voir de quelles autres tâches elles dépendent.
- Les mises à jour de statut se propagent automatiquement entre les éléments liés.
- Des avertissements s'affichent lors de la fermeture d'éléments qui ont des bloqueurs ouverts.
- Les équipes peuvent éviter les retards en traitant les dépendances de manière proactive.

Cette visibilité facilite la coordination du travail entre les équipes et réduit les goulots d'étranglement.

### Relier les objectifs stratégiques aux détails d'implémentation {#connect-strategic-goals-with-implementation-details}

Utilisez les éléments liés pour connecter la planification de haut niveau à l'exécution quotidienne.

Lorsque vous associez des objectifs stratégiques à des tâches tactiques :

- Les équipes comprennent comment leur travail contribue aux objectifs plus larges.
- Les parties prenantes peuvent suivre la progression de la stratégie jusqu'à l'implémentation.
- Chacun bénéficie d'une visibilité sur la façon dont les efforts individuels soutiennent la vision globale.
- Les changements de stratégie peuvent être rapidement tracés jusqu'aux travaux d'implémentation concernés.

Ce lien entre les niveaux crée un alignement et une vision partagée au sein de l'organisation.

### Organiser les initiatives transverses {#organize-cross-functional-initiatives}

Associez les travaux connexes de différentes équipes et de différents projets pour coordonner des initiatives complexes.

Lorsque vous utilisez des éléments liés pour des travaux transverses :

- Chaque équipe peut travailler dans son propre domaine tout en maintenant des connexions avec les travaux connexes.
- Les dépendances entre les équipes spécialisées deviennent visibles.
- Les mises à jour de statut se propagent automatiquement entre les éléments connexes.
- Les équipes peuvent coordonner leurs efforts sans réunions constantes.

Cette coordination contribue à briser les silos et garantit que tous les aspects de l'initiative restent synchronisés.

## Types d'éléments liés {#types-of-linked-items}

GitLab prend en charge l'association de différents types d'éléments de travail :

- [Les tickets](../project/issues/related_issues.md) vous aident à suivre les tâches, les bugs et les fonctionnalités, et peuvent être associés pour illustrer les dépendances entre des éléments de travail distincts.
- [Les epics](../group/epics/linked_epics.md) vous permettent de gérer des initiatives transverses, d'afficher les dépendances et de connecter la planification stratégique à l'exécution au sein de plusieurs équipes ou projets. Disponible dans l'édition Ultimate.
- [Les tâches](../tasks.md#linked-items-in-tasks) offrent un suivi léger pour les unités de travail plus petites et peuvent être associées à d'autres éléments pour illustrer les relations ou les dépendances dans un projet.
- [Les OKR](../okrs.md#linked-items-in-okrs) permettent de connecter les objectifs stratégiques aux détails d'exécution, en s'assurant que le travail quotidien reste aligné sur les priorités organisationnelles de plus haut niveau.
- [Les incidents](../../operations/incident_management/incidents.md) représentent des interruptions de service ou des pannes nécessitant une restauration urgente et peuvent être associés à des éléments de travail connexes pour un meilleur suivi des problèmes opérationnels et de leur impact sur le travail planifié.
- [Les cas de test](../../ci/test_cases/_index.md) intègrent la planification des tests directement dans vos workflows GitLab, permettant aux équipes de documenter les scénarios de test et de suivre les exigences sur la même plateforme que celle où elles gèrent le code. Disponible dans l'édition Ultimate.

## Types de relations {#relationship-types}

Lors de l'association d'éléments, vous pouvez spécifier le type de relation :

- **Associé à** : indique une relation générale entre les éléments.
- **Bloque** : indique qu'un élément empêche la progression d'un autre élément.
- **Est bloqué par** : indique qu'un élément ne peut pas avancer tant qu'un autre élément n'est pas résolu.

## Tâches courantes avec les éléments liés {#common-tasks-with-linked-items}

Découvrez comment créer et gérer des relations entre vos éléments de travail grâce à ces procédures courantes.

### Ajouter un élément lié {#add-a-linked-item}

Prérequis :

- Vous devez disposer du rôle Invité, Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour les projets ou les groupes des deux éléments.

Le processus général pour ajouter des éléments liés est similaire pour tous les types d'éléments de travail :

1. Accédez à l'élément de travail que vous souhaitez modifier.
1. En bas de la description, trouvez la section **Éléments liés** de l'élément de travail.
1. Sélectionnez **Ajouter**.
1. Sélectionnez le type de relation : **en relation avec**, **bloque** ou **est bloqué(e) par**.
1. Saisissez la référence de l'élément à associer. Vous pouvez :
   - Saisissez `#` ou `&` (selon le type d'élément) suivi du numéro de l'élément.
   - Saisissez du texte pour rechercher l'élément par titre.
   - Collez l'URL complète de l'élément.
1. Sélectionnez **Ajouter** pour confirmer.

Vous pouvez également ajouter des éléments liés à l'aide des [actions rapides](../project/quick_actions.md) :

- `/relate`
- `/blocks`
- `/blocked_by`

Pour des informations détaillées propres à chaque type d'élément de travail, consultez la documentation correspondante :

- [Tickets liés](../project/issues/related_issues.md#add-a-linked-issue)
- [Epics liés](../group/epics/linked_epics.md#add-a-linked-item)
- [Tâches liées](../tasks.md#linked-items-in-tasks)
- [OKR liés](../okrs.md#linked-items-in-okrs)

### Supprimer un élément lié {#remove-a-linked-item}

Prérequis :

- Vous devez disposer du rôle Invité, Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour les projets ou les groupes des deux éléments.

Pour supprimer un élément lié :

1. Accédez à l'élément de travail que vous souhaitez modifier.
1. En bas de la description, trouvez la section **Éléments liés** de l'élément de travail.
1. Pour chaque élément lié, sélectionnez **Supprimer** ({{< icon name="close" >}}).

La relation bidirectionnelle est supprimée des deux éléments.

Vous pouvez également supprimer un élément lié à l'aide de l'[action rapide `/unlink`](../project/quick_actions.md#unlink).

### Configurer les préférences d'affichage des éléments liés {#configure-linked-item-display-preferences}

{{< history >}}

- Les options d'affichage des éléments liés ont été [développées](https://gitlab.com/gitlab-org/gitlab/-/work_items/551231) dans GitLab 18.10.

{{< /history >}}

Vous pouvez configurer les informations affichées dans la section **Éléments liés** afin de vous concentrer sur ce qui est le plus important pour votre workflow.

> [!note]
> Lorsque vous modifiez les informations affichées dans un élément de travail, vous les modifiez pour tous les éléments de travail de vos projets et groupes.

1. Dans le coin supérieur droit de l'en-tête de la section **Éléments liés**, sélectionnez **Options d'affichage** ({{< icon name="preferences" >}}).

   Par défaut, toutes les options et tous les champs sont visibles.
1. Pour modifier les informations affichées, activez ou désactivez les bascules suivantes :

   - Pour les options d'affichage :
     - **Afficher les éléments fermés**
   - Pour les champs affichés :
     - **Statut**
     - **Personne assignée**
     - **Labels**
     - **Poids**
     - **Jalon**
     - **Itération**
     - **Dates**
     - **Santé**
     - **Bloqué/Blocage**

## Sujets connexes {#related-topics}

- [Éléments de travail](_index.md)
- [Les tickets](../project/issues/_index.md)
- [Les epics](../group/epics/_index.md)
- [Tâches](../tasks.md)
- [OKR](../okrs.md)
