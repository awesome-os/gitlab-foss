---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Tri et classement des listes de tickets
description: "Triez les listes de tickets par date d'échéance, priorité, popularité, jalon, état de santé ou d'autres critères pour retrouver et organiser les éléments de travail."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez trier une liste de tickets de plusieurs façons. Les options de tri disponibles peuvent varier en fonction du contexte de la liste. Pour modifier le mode de tri d'une liste, consultez [trier les éléments de travail](../../work_items/_index.md#sort-work-items).

## Tri par tickets bloquants {#sorting-by-blocking-issues}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous triez par **Bloquant**, la liste de tickets est triée par ordre décroissant en fonction du nombre de tickets que chaque ticket [bloque](related_issues.md#blocking-issues).

## Tri par date de création, de mise à jour ou de fermeture {#sorting-by-created-updated-or-closed-date}

Lorsque vous triez par **Créés**, **Mis à jour** ou **Date de fermeture**, la liste de tickets est triée par ordre décroissant selon la date et l'horodatage correspondants. Les tickets créés, mis à jour ou fermés le plus récemment apparaissent en premier.

## Tri par date d'échéance {#sorting-by-due-date}

Lorsque vous triez par **Date d'échéance**, la liste de tickets est triée par ordre croissant selon la [date d'échéance](due_dates.md) du ticket. Les tickets dont la date d'échéance est la plus proche apparaissent en premier, et les tickets sans date d'échéance apparaissent en dernier.

## Tri par priorité du label {#sorting-by-label-priority}

Lorsque vous triez par **Priorité du label**, la liste de tickets est triée par ordre décroissant. Les tickets avec le label de priorité la plus élevée apparaissent en premier, puis tous les autres tickets.

Les égalités sont résolues de manière arbitraire. Seul le label de priorité la plus élevée est pris en compte ; les labels de priorité inférieure sont ignorés. Pour plus d'informations, consultez le [ticket 14523](https://gitlab.com/gitlab-org/gitlab/-/issues/14523).

Pour plus d'informations, consultez [priorité du label](../labels.md#set-label-priority).

## Tri manuel {#manual-sorting}

Lorsque vous triez par ordre **Manuel**, vous pouvez modifier l'ordre en faisant glisser et en déposant les tickets. L'ordre modifié est conservé, et toutes les personnes qui consultent la même liste voient l'ordre des tickets mis à jour, sous réserve de quelques exceptions.

Chaque ticket se voit attribuer une valeur d'ordre relative, représentant son ordre relatif par rapport aux autres tickets de la liste. Lorsque vous réorganisez un ticket par glisser-déposer, sa valeur d'ordre relative change.

De plus, chaque fois qu'un ticket apparaît dans une liste triée manuellement, la valeur d'ordre relative mise à jour est utilisée pour le classement. Ainsi, si quelqu'un fait glisser le ticket `A` au-dessus du ticket `B` dans votre instance GitLab, cet ordre est conservé chaque fois qu'ils apparaissent ensemble dans une liste.

Ce classement affecte également les [tableaux des tickets](../issue_board.md#ordering-issues-in-a-list). La modification de l'ordre dans une liste de tickets entraîne la modification du classement dans un tableau des tickets, et inversement.

## Tri par date d'échéance du jalon {#sorting-by-milestone-due-date}

Lorsque vous triez par **Date d'échéance du jalon**, la liste de tickets est triée par ordre croissant selon la date d'échéance du jalon associé. Les tickets dont les jalons ont la date d'échéance la plus proche apparaissent en premier, puis les tickets avec un jalon sans date d'échéance.

## Tri par popularité {#sorting-by-popularity}

Lorsque vous triez par **Popularité**, l'ordre des tickets est trié par ordre décroissant en fonction du nombre de votes positifs ([réactions emoji](../../emoji_reactions.md) avec « pouce levé ») sur chaque ticket. Vous pouvez utiliser cette option pour identifier les tickets qui sont très demandés.

Le nombre total de votes n'est pas additionné. Un ticket avec 18 votes positifs et 5 votes négatifs est considéré comme plus populaire qu'un ticket avec 17 votes positifs et aucun vote négatif.

## Tri par priorité {#sorting-by-priority}

Lorsque vous triez par **Priorité**, l'ordre des tickets est trié selon l'ordre suivant :

1. Les tickets avec des jalons ayant des dates d'échéance, où le jalon assigné le plus proche est listé en premier.
1. Les tickets avec des jalons sans date d'échéance.
1. Les tickets avec un label de priorité plus élevée.
1. Les tickets sans label priorisé.

Les égalités sont résolues de manière arbitraire.

Pour plus d'informations, consultez [priorité du label](../labels.md#set-label-priority).

## Tri par titre {#sorting-by-title}

Lorsque vous triez par **Intitulé**, l'ordre des tickets est trié par ordre alphabétique selon le titre du ticket, dans l'ordre suivant :

- Émoji
- Caractères spéciaux
- Chiffres
- Lettres : d'abord les lettres latines, puis les lettres accentuées (par exemple, `ö`)

## Tri par état de santé {#sorting-by-health-status}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous triez par **Santé**, la liste de tickets est triée selon l'[état de santé](managing_issues.md#health-status) des tickets. Par ordre décroissant, les tickets sont affichés dans l'ordre suivant :

1. Tickets **À risque**
1. Tickets **Attention requise**
1. Tickets **En bonne voie**
1. Tous les autres tickets

## Tri par poids {#sorting-by-weight}

Lorsque vous triez par **Poids**, la liste de tickets est triée par ordre croissant selon le [poids du ticket](../../work_items/weight.md). Les tickets avec le poids le plus faible apparaissent en premier, et les tickets sans poids apparaissent en dernier.

## Tri par état {#sorting-by-status}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/550262) dans GitLab 18.5 [avec le feature flag](../../../administration/feature_flags/_index.md) `work_item_status_mvc2`. Activés par défaut.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/576610) dans GitLab 18.6. Le feature flag `work_item_status_mvc2` a été supprimé.

{{< /history >}}

Lorsque vous triez par **Statut**, la liste de tickets est triée par ordre croissant selon l'[état du ticket](../../work_items/status.md). Les tickets sont d'abord triés par catégorie d'état. Si deux tickets partagent la même catégorie, le système revient au tri par identifiant de ticket.
