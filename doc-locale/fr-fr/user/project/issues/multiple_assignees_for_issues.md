---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Découvrez comment assigner plusieurs personnes à un seul ticket dans GitLab pour clarifier la propriété, améliorer la collaboration et suivre les responsabilités partagées au sein de grandes équipes."
title: Plusieurs personnes assignées à un ticket
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les utilisateurs de GitLab Gratuite peuvent assigner un seul utilisateur à un ticket. Les utilisateurs de GitLab Premium et GitLab Ultimate peuvent assigner plusieurs utilisateurs à un ticket.

Dans les grandes équipes avec des responsabilités partagées, il peut être difficile de savoir qui travaille sur un ticket, qui a déjà terminé ou qui n'a pas encore commencé.

Vous pouvez ajouter plusieurs [personnes assignées](managing_issues.md#assignees) à un ticket, ce qui facilite son suivi et permet de mieux identifier la personne responsable.

Les personnes assignées multiples à un ticket fluidifient la collaboration et permettent d'afficher clairement les responsabilités partagées. Toutes les personnes assignées sont visibles dans les workflows de votre équipe et reçoivent des notifications (comme elles le feraient en tant que personnes assignées uniques), ce qui simplifie la communication et la gestion des responsabilités.

Lorsqu'une personne assignée termine son travail, elle se retire de la liste des personnes assignées, indiquant ainsi clairement que sa tâche est terminée.

## Assigner plusieurs utilisateurs à un ticket {#assign-multiple-users-to-an-issue}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le projet.

Pour assigner plusieurs utilisateurs à un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans la barre latérale droite, dans la section **Personnes assignées**, sélectionnez **Modifier**.
1. Dans la liste déroulante, sélectionnez les utilisateurs à assigner. La liste déroulante reste ouverte, ce qui vous permet de sélectionner plusieurs utilisateurs.
1. Sélectionnez **Appliquer**, ou cliquez sur n'importe quelle zone en dehors de la liste déroulante.

GitLab enregistre vos sélections uniquement lorsque vous fermez la liste déroulante.

Vous pouvez également utiliser l'[action rapide `/assign`](../quick_actions.md#assign) pour ajouter des personnes assignées.

## Supprimer une personne assignée {#remove-an-assignee}

Pour supprimer une personne assignée d'un ticket :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**, puis filtrez par **Type** = **Ticket** et sélectionnez votre ticket.
1. Dans la barre latérale droite, dans la section **Personnes assignées**, sélectionnez **Modifier**.
1. Dans la liste déroulante, désélectionnez l'utilisateur.
1. Sélectionnez **Appliquer**, ou cliquez sur n'importe quelle zone en dehors de la liste déroulante.

Vous pouvez également utiliser l'[action rapide `/unassign`](../quick_actions.md#unassign).

## Sujets connexes {#related-topics}

- [Assigner des utilisateurs à une tâche](../../tasks.md#assign-users-to-a-task)
- [API des tickets](../../../api/issues.md)
