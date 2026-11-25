---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Suivi du temps
description: "Estimations, temps passé et rapports."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Le suivi du temps pour les tâches a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/438577) dans GitLab 17.0.
- Le suivi du temps pour les epics a été [introduit](https://gitlab.com/groups/gitlab-org/-/epics/12396) dans GitLab 17.5. [Le nouveau look pour les epics](../group/epics/_index.md#epics-as-work-items) doit être activé.
- Le rôle minimum requis pour ajouter, modifier et supprimer une estimation a été [modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) de Reporter à Planificateur dans GitLab 17.7.
- Le suivi du temps pour les epics est [généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/issues/468310) dans GitLab 18.1.
- La durée totale de temps passé prise en charge a été portée de 1 an à 4 ans dans GitLab 18.10.

{{< /history >}}

Le suivi du temps permet d'enregistrer et de gérer le temps investi dans les éléments de travail GitLab. Le suivi du temps :

- Enregistre le temps réellement passé sur les tickets, les merge requests, les epics et les tâches.
- Estime le temps total nécessaire à la réalisation.
- Fournit des rapports détaillés des entrées de temps.
- Calcule les totaux à l'aide d'unités de temps standardisées.
- Suit l'historique via les actions rapides et l'interface utilisateur.

Vous pouvez consulter les informations de suivi du temps dans la barre latérale droite de vos éléments de travail :

![La section de suivi du temps dans la barre latérale droite d'un élément de travail.](img/time_tracking_sidebar_v18_3.png)

Saisissez et supprimez les données de suivi du temps à l'aide des [actions rapides](quick_actions.md) ou de l'interface utilisateur. Saisissez les actions rapides sur leurs propres lignes. Si vous utilisez une action rapide plusieurs fois dans un seul commentaire, seule sa dernière occurrence est appliquée.

## Autorisations {#permissions}

Différentes fonctionnalités de suivi du temps sont disponibles selon votre rôle :

- Pour ajouter, modifier et supprimer des estimations, vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour les tickets et les tâches, ou du rôle Developer pour les merge requests.
- Pour ajouter et modifier le temps passé, vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Pour supprimer une entrée de temps, vous devez en être l'auteur ou disposer du rôle Maintainer ou Owner.

## Estimations {#estimates}

L'estimation est conçue pour indiquer le temps total nécessaire à la réalisation d'un élément.

Vous pouvez voir le temps estimé restant en survolant les informations de suivi du temps dans la barre latérale droite.

![L'info-bulle du temps estimé restant lors du survol de la section de suivi du temps.](img/remaining_time_v18_3.png)

### Ajouter une estimation {#add-an-estimate}

Prérequis :

- Dans les tickets, vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Dans les tâches, vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Dans les merge requests, vous devez disposer du rôle Developer, Maintainer ou Owner pour le projet.

Pour saisir une estimation, utilisez l'[action rapide `/estimate`](quick_actions.md#estimate), suivie de la durée.

Par exemple, si vous devez saisir une estimation d'1 mois, 2 semaines, 3 jours, 4 heures et 5 minutes, tapez `/estimate 1mo 2w 3d 4h 5m`. Consultez les [unités de temps utilisables](#available-time-units).

Un élément ne peut avoir qu'une seule estimation. Chaque fois que vous saisissez une nouvelle estimation de temps, elle écrase la valeur précédente.

### Supprimer une estimation {#remove-an-estimate}

Prérequis :

- Dans les tickets, vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Dans les tâches, vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.
- Dans les merge requests, vous devez disposer du rôle Developer, Maintainer ou Owner pour le projet.

Pour supprimer entièrement une estimation, utilisez l'[action rapide `/remove_estimate`](quick_actions.md#remove_estimate).

## Temps passé {#time-spent}

Au fil de votre travail, vous pouvez enregistrer le temps que vous avez passé.

Chaque nouvelle entrée de temps passé est ajoutée au temps total passé actuel pour le ticket, la tâche ou la merge request.

Le temps total passé sur un ticket, une tâche ou une merge request ne peut pas dépasser 4 ans.

### Ajouter du temps passé {#add-time-spent}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

#### Via l'interface utilisateur {#using-the-user-interface}

{{< history >}}

- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/150564) dans GitLab 17.0. Lorsque vous ne spécifiez pas quand le temps a été passé, l'heure actuelle est utilisée.

{{< /history >}}

Pour ajouter une entrée de temps via l'interface utilisateur :

1. Dans la section **Suivi du temps** de la barre latérale, sélectionnez **Ajouter une entrée de temps** ({{< icon name="plus" >}}). Une boîte de dialogue s'ouvre.
1. Saisissez :

   - La durée du temps passé.
   - Facultatif. Quand il a été passé. Si ce champ est vide, l'heure actuelle est utilisée.
   - Facultatif. Un résumé.

1. Sélectionnez **Enregistrer**.

Le total **Passé** dans la barre latérale est mis à jour et vous pouvez consulter toutes les entrées dans un [rapport de suivi du temps](#view-an-items-time-tracking-report).

#### Via une action rapide {#using-a-quick-action}

Pour saisir le temps passé, utilisez l'[action rapide `/spend`](quick_actions.md#spend), suivie de la durée.

Par exemple, si vous devez enregistrer 1 mois, 2 semaines, 3 jours, 4 heures et 5 minutes, tapez `/spend 1mo 2w 3d 4h 5m`. Consultez les [unités de temps utilisables](#available-time-units).

Pour ajouter une entrée dans le [rapport de suivi du temps](#view-an-items-time-tracking-report) avec une note, créez un commentaire avec une description et l'action rapide. Il apparaît ensuite dans la colonne **Résumé/Notes** du rapport de suivi du temps. Par exemple :

```plaintext
Draft MR and respond to initial comments

/spend 30m
```

Pour enregistrer quand le temps a été passé, saisissez une date après la durée, en utilisant le format `YYYY-MM-DD`.

Par exemple, pour enregistrer 1 heure de temps passé le 31 janvier 2021, saisissez `/spend 1h 2021-01-31`.

Si vous saisissez une date future, aucun temps n'est enregistré.

#### Via les messages de commit {#using-commit-messages}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/16543) dans GitLab 18.3 avec un flag nommé `commit_time_tracking`. Fonctionnalité désactivée par défaut.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/215244/) dans GitLab 18.7. Suppression du feature flag `commit_time_tracking`.

{{< /history >}}

Vous pouvez enregistrer le temps passé sur des tickets directement dans les messages de commit. Utilisez cette approche pour suivre le temps au fil de votre travail, sans mettre à jour le ticket séparément.

Pour ajouter du temps passé dans un message de commit, incluez une référence à un ticket et un marqueur de suivi du temps au format `@<time>` sans espaces entre les unités de temps.

Par exemple :

```plaintext
Fix a bug in the login form #123 @1mo2d3h15m
```

Ce message de commit ajoute 1 mois, 2 jours, 3 heures et 15 minutes de temps passé au ticket #123.

Le marqueur de suivi du temps doit :

- Commencer par le symbole `@`.
- Être immédiatement suivi d'unités de temps sans espaces entre elles.
- Prendre en charge les unités de temps suivantes : mois (`mo`), jours (`d`), heures (`h`), minutes (`m`) et secondes (`s`).
- Utiliser les mêmes [unités de temps](#available-time-units) que le suivi du temps standard.

Lorsque vous poussez un commit contenant des informations de suivi du temps :

1. GitLab extrait le temps passé du message de commit.
1. Le temps est ajouté à tous les tickets référencés dans le même message de commit.
1. Une note système est ajoutée au ticket pour indiquer que du temps a été ajouté depuis un commit.
1. L'entrée de suivi du temps inclut le SHA et le titre du commit comme description.

##### Autorisations de l'auteur du commit {#commit-author-permissions}

Le temps n'est ajouté à un ticket depuis un message de commit que si l'auteur du commit a la permission de mettre à jour le ticket :

- L'auteur du commit doit disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet dans lequel le ticket existe.
- Si l'auteur ne dispose pas des autorisations suffisantes, les informations de suivi du temps dans son commit sont ignorées.
- Les vérifications des autorisations utilisent les mêmes règles que le suivi du temps standard.

##### Problèmes connus {#known-issues}

**Plusieurs durées dans un seul commit**

Lorsqu'un message de commit référence plusieurs tickets avec des durées différentes, seule la première durée est appliquée à tous les tickets référencés.

Par exemple, ce message de commit :

```plaintext
Fixes #41 @1h30m and fixes #40 @2h
```

Ajoute 1h30m aux tickets #41 et #40. La deuxième durée (`@2h`) est ignorée.

**Entrées de temps en double dues aux modifications du SHA de commit**

Lorsque le SHA d'un commit change (par exemple, après un rebasage ou un amendement), GitLab le traite comme un nouveau commit pour le suivi du temps. Cela peut créer des entrées de temps en double si le commit original et le nouveau commit sont tous deux référencés dans le ticket.

Pour éviter les entrées de temps en double lorsque les SHA de commit sont susceptibles de changer :

- Ajoutez le temps directement au ticket via l'interface utilisateur ou les actions rapides plutôt que via les messages de commit.
- Si vous devez utiliser des messages de commit pour le suivi du temps, ajoutez le temps uniquement après que l'historique de votre branche est finalisé.
- Avant de fusionner, vérifiez le rapport de suivi du temps du ticket pour identifier et supprimer les éventuels doublons.

### Éviter le suivi du temps en double dans les merge requests {#prevent-duplicate-time-tracking-in-merge-requests}

Lorsque vous fusionnez une merge request contenant des commits avec des informations de suivi du temps, GitLab empêche le suivi du temps en double :

- Le temps n'est suivi qu'une seule fois par commit, même si le même message de commit apparaît plusieurs fois dans l'historique du dépôt.
- GitLab empêche le suivi du temps en double en vérifiant si une entrée de temps avec le même titre et le même ID de commit existe déjà pour un ticket.
- Lorsque des commits sont fusionnés, aucun temps supplémentaire n'est comptabilisé. Cela empêche le double comptage du temps lorsque des branches de fonctionnalités sont fusionnées dans la branche par défaut.

### Soustraire du temps passé {#subtract-time-spent}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour soustraire du temps, saisissez une valeur négative. Par exemple, `/spend -3d` supprime trois jours du temps total passé. Vous ne pouvez pas descendre en dessous de 0 minute de temps passé. Ainsi, si vous supprimez plus de temps que celui déjà enregistré, GitLab ignore la soustraction.

### Supprimer le temps passé {#delete-time-spent}

Un timelog est une entrée unique de temps passé, positive ou négative.

Prérequis :

- Vous devez être l'auteur du timelog ou disposer du rôle Maintainer ou Owner pour le projet.

Pour supprimer un timelog :

- Dans le rapport de suivi du temps, à droite d'une entrée de timelog, sélectionnez **Supprimer le temps passé** ({{< icon name="remove" >}}).
- Utilisez l'[API GraphQL](../../api/graphql/reference/_index.md#mutationtimelogdelete).

### Supprimer tout le temps passé {#delete-all-the-time-spent}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Developer, Maintainer ou Owner pour le projet.

Pour supprimer tout le temps passé en une seule fois, utilisez l'[action rapide `/remove_time_spent`](quick_actions.md#remove_time_spent).

## Afficher le rapport de suivi du temps d'un élément {#view-an-items-time-tracking-report}

Pour afficher un rapport de suivi du temps passé sur un élément :

- Dans la barre latérale droite, à côté de **Passé**, sélectionnez la durée.

![Le rapport de suivi du temps affichant les entrées individuelles du temps passé.](img/time_tracking_report_v18_3.png)

Le détail du temps passé affiché est limité à 100 entrées au maximum.

## Rapport global de suivi du temps {#global-time-tracking-report}

{{< details >}}

- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/344002) dans GitLab 15.11 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `global_time_tracking_report`. Fonctionnalité désactivée par défaut.
- Activé sur GitLab.com dans GitLab 16.5.

{{< /history >}}

> [!flag]
> Sur GitLab Self-Managed, cette fonctionnalité n'est pas disponible par défaut. Pour rendre cette fonctionnalité disponible, un administrateur peut [activer le feature flag](../../administration/feature_flags/_index.md) `global_time_tracking_report`. Sur GitLab.com, cette fonctionnalité est disponible. Sur GitLab Dedicated, cette fonctionnalité n'est pas disponible. Cette fonctionnalité n'est pas prête pour une utilisation en production.

Affichez un rapport du temps passé sur les tickets, les tâches et les merge requests dans l'ensemble de GitLab.

Cette fonctionnalité est une [version expérimentale](../../policy/development_stages_support.md). Si vous trouvez un bug, ajoutez-le au [ticket de feedback](https://gitlab.com/gitlab-org/gitlab/-/issues/435222).

Pour afficher le rapport global de suivi du temps :

1. Dans votre navigateur, saisissez l'URL du rapport global :
   - Pour GitLab Self-Managed, ajoutez `/-/timelogs` à votre URL de base. Par exemple, `https://gitlab.example.com/-/timelogs`.
   - Pour GitLab.com, accédez à <https://gitlab.com/-/timelogs>.
1. Facultatif. Pour filtrer par un utilisateur spécifique, saisissez son nom d'utilisateur sans le symbole `@`.
1. Sélectionnez les dates de début et de fin.
1. Sélectionnez **Exécuter le rapport**.

![La page du rapport global de suivi du temps affichant les filtres et les résultats pour plusieurs éléments.](img/global_time_report_v16_5.png)

## Unités de temps disponibles {#available-time-units}

Les unités de temps suivantes sont disponibles :

| Unité de temps | Ce qu'il faut saisir                | Taux de conversion |
| --------- | --------------------------- | --------------- |
| Mois     | `mo`, `month` ou `months`  | 4 sem. (160 h)     |
| Semaine      | `w`, `week` ou `weeks`     | 5 j. (40 h)      |
| Jour       | `d`, `day` ou `days`       | 8 h             |
| Heure      | `h`, `hour` ou `hours`     | 60 min            |
| Minute    | `m`, `minute` ou `minutes` |                 |

### Limiter les unités affichées aux heures {#limit-displayed-units-to-hours}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les administrateurs GitLab peuvent limiter l'affichage des unités de temps aux heures. Pour ce faire :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Préférences**.
1. Développez **Localisation**.
1. Sous **Suivi du temps**, cochez la case **Limiter l'affichage des unités de suivi du temps aux heures**.
1. Sélectionnez **Enregistrer les modifications**.

Avec cette option activée, `75h` s'affiche à la place de `1w 4d 3h`.

## Sujets connexes {#related-topics}

- Références GraphQL pour le suivi du temps :
  - [Connection](../../api/graphql/reference/_index.md#timelogconnection)
  - [Edge](../../api/graphql/reference/_index.md#timelogedge)
  - [Champs](../../api/graphql/reference/_index.md#timelog)
  - [Timelogs](../../api/graphql/reference/_index.md#querytimelogs)
  - [Timelogs de groupe](../../api/graphql/reference/_index.md#grouptimelogs)
  - [Timelogs de projet](../../api/graphql/reference/_index.md#projecttimelogs)
  - [Timelogs utilisateur](../../api/graphql/reference/_index.md#usertimelogs)
