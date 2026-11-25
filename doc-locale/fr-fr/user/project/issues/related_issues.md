---
stage: Plan
group: Portfolio Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Tickets liés
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Modification](https://gitlab.com/groups/gitlab-org/-/work_items/10267) du rôle minimum requis de Reporter (si vrai) à Invité dans GitLab 17.0.

{{< /history >}}

Les tickets liés sont une relation bidirectionnelle entre deux tickets quelconques et apparaissent dans un bloc sous la description du ticket. Vous pouvez lier des tickets dans différents projets.

La relation s'affiche dans l'interface utilisateur uniquement si l'utilisateur peut voir les deux tickets. Lorsque vous tentez de fermer un ticket qui a des bloqueurs ouverts, un avertissement s'affiche.

> [!note]
> Pour gérer les tickets liés via notre API, consultez l'[API des liens de tickets](../../../api/issue_links.md).

## Ajouter un ticket lié {#add-a-linked-issue}

Prérequis :

- Vous devez disposer du rôle Invité, Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour les deux projets.

Pour lier un ticket à un autre :

1. Dans la section **Éléments liés** d'un ticket, sélectionnez le bouton d'ajout de ticket lié ({{< icon name="plus" >}}).
1. Sélectionnez la relation entre les deux tickets. L'une ou l'autre des options :
   - **en relation avec**
   - [**bloque**](#blocking-issues)
   - [**est bloqué(e) par**](#blocking-issues)
1. Saisissez le numéro du ticket ou collez l'URL complète du ticket.

   ![Lier des tickets associés au ticket actuel](img/related_issues_add_v15_3.png)

   Les tickets du même projet peuvent être spécifiés uniquement par le numéro de référence. Les tickets d'un projet différent nécessitent des informations supplémentaires, telles que le groupe et le nom du projet. Par exemple :

   - Le même projet : `#44`
   - Le même groupe : `project#44`
   - Groupe différent : `group/project#44`

   Les références valides sont ajoutées à une liste temporaire que vous pouvez consulter.

1. Une fois tous les tickets liés ajoutés, sélectionnez **Ajouter**.

Une fois que vous avez terminé d'ajouter tous les tickets liés, vous pouvez les voir classés par catégories afin de mieux comprendre visuellement leurs relations.

![Section pour afficher ou gérer les tickets associés](img/related_issue_block_v15_3.png)

Vous pouvez également ajouter un ticket lié depuis un message de commit ou la description d'un autre ticket ou d'une autre merge request. Pour plus d'informations, consultez [les tickets en lien croisé](crosslinking_issues.md).

## Supprimer un ticket lié {#remove-a-linked-issue}

Dans la section **Éléments liés** d'un ticket, sélectionnez le bouton de suppression ({{< icon name="close" >}}) sur le côté droit de chaque jeton de ticket à supprimer.

En raison de la relation bidirectionnelle, la relation n'apparaît plus dans aucun des deux tickets.

![Dissocier un ticket associé du ticket actuel](img/related_issues_remove_v15_3.png)

Consultez notre page [permissions](../../permissions.md) pour plus d'informations.

## Tickets bloquants {#blocking-issues}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous [ajoutez un ticket lié](#add-a-linked-issue), vous pouvez indiquer qu'il **bloque** ou **est bloqué(e) par** un autre ticket.

Les tickets bloqués par d'autres tickets ont une icône ({{< icon name="entity-blocked" >}}) à côté de leur titre, affichée dans les listes de tickets et les [tableaux](../issue_board.md). L'icône disparaît lorsque le ticket bloquant est fermé ou que leur relation est modifiée ou [supprimée](#remove-a-linked-issue).

Si vous tentez de fermer un ticket bloqué en utilisant le bouton « Fermer le ticket », un message de confirmation s'affiche.
