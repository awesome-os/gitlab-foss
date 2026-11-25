---
stage: Software Supply Chain Security
group: Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Modérer les utilisateurs
---

Si vous avez le rôle Propriétaire pour un groupe, vous pouvez [approuver](manage.md#approve-pending-members-for-a-group), bannir ou supprimer automatiquement les membres inactifs.

> [!note]
> Cette rubrique concerne spécifiquement la modération des utilisateurs dans les groupes. Pour les informations relatives à GitLab Self-Managed, consultez la [documentation d'administration](../../administration/moderate_users.md).

## Bannir et débannir des utilisateurs {#ban-and-unban-users}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/155) dans GitLab 15.8 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `limit_unique_project_downloads_per_namespace_user`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/365724) dans GitLab 15.6.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/183101) dans GitLab 18.0. Suppression du feature flag `limit_unique_project_downloads_per_namespace_user`.

{{< /history >}}

Un propriétaire de groupe peut modérer l'accès des utilisateurs en les bannissant et en les débannissant. Vous devez bannir un utilisateur lorsque vous souhaitez lui bloquer l'accès au groupe.

Un utilisateur banni :

- Ne peut pas accéder au groupe ni à ses dépôts.
- Ne peut pas utiliser les [commandes slash](../project/integrations/gitlab_slack_application.md#slash-commands).
- N'occupe pas de [siège](../free_user_limit.md).

### Bannir un utilisateur {#ban-a-user}

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une démonstration du bannissement d'un utilisateur au niveau du groupe, consultez [Namespace level ban - Banning a user](https://youtu.be/1rbi1uEJmOI).

Prérequis :

- Dans le groupe principal, vous devez avoir le rôle Propriétaire.
- Dans le groupe principal, si l'utilisateur que vous souhaitez bannir a le rôle Propriétaire, vous devez [rétrograder l'utilisateur](manage.md#change-the-owner-of-a-group).

Pour bannir manuellement un utilisateur :

1. Accédez au groupe principal.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. En regard du membre que vous souhaitez bannir, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}).
1. Dans la liste déroulante, sélectionnez **Bannir le membre**.

### Débannir un utilisateur {#unban-a-user}

Pour débannir un utilisateur avec l'API GraphQL, consultez [`Mutation.namespaceBanDestroy`](../../api/graphql/reference/_index.md#mutationnamespacebandestroy).

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une démonstration du débannissement d'un utilisateur au niveau du groupe, consultez [Namespace level ban - Unbanning a user](https://www.youtube.com/watch?v=mTQVbP3MQrs).

Prérequis :

- Dans le groupe principal, vous devez avoir le rôle Propriétaire.

Pour débannir un utilisateur :

1. Accédez au groupe principal.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Banni**.
1. Pour le compte que vous souhaitez débannir, sélectionnez **Débloquer**.

## Supprimer automatiquement les membres inactifs {#automatically-remove-dormant-members}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/461339) dans GitLab 17.1 [avec le feature flag](../../administration/feature_flags/_index.md) `group_remove_dormant_members`. Fonctionnalité désactivée par défaut.
- [Publié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/178851) en tant que fonctionnalité en [version bêta](../../policy/development_stages_support.md#beta) dans GitLab 17.9.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Vous pouvez supprimer automatiquement les membres du groupe qui n'ont aucune activité dans le groupe pendant une période déterminée (la valeur par défaut et le minimum sont de 90 jours). Les actions suivantes sont comptabilisées comme une activité :

- Interactions avec les projets via des événements Git HTTP/SSH, tels que `clone` et `push`.
- Consultation de pages dans GitLab, telles que les tableaux de bord, les projets, les tickets, les merge requests ou les paramètres.
- Utilisation de l'API REST ou GraphQL dans la portée du groupe.

> [!note]
> L'activité n'a pas été enregistrée pour les membres ajoutés avant le 22/01/2025. Ces membres ne seront pas supprimés avant le 22/04/2025, même s'ils sont inactifs depuis plus de 90 jours.

- Les propriétaires de groupe inactifs ne sont ni désactivés ni supprimés du groupe.
- Les [utilisateurs enterprise](../enterprise_user/_index.md) inactifs ne sont pas supprimés, mais [désactivés](../../administration/moderate_users.md#deactivate-and-reactivate-users). Lorsque ces utilisateurs se reconnectent, leurs comptes sont réactivés et leur accès est rétabli. Cependant, lorsque [l'accès restreint](../../subscriptions/manage_seats.md#restricted-access) est actif sur le groupe enterprise et qu'aucun siège n'est disponible, l'utilisateur est placé en attente d'approbation au lieu d'être réactivé. Pour plus d'informations, consultez [la réactivation des utilisateurs enterprise inactifs](../../subscriptions/manage_seats.md#dormant-user-reactivation).

Pour activer la suppression automatique des membres inactifs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Général**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Faites défiler jusqu'à **Membres inactifs**.
1. Cochez la case **Supprimer les membres inactifs après une période d'inactivité**.
1. Dans le champ **Jours d'inactivité avant retrait**, saisissez le nombre de jours avant la suppression. Le minimum est de 90 jours, le maximum est de 1 827 jours (5 ans).
1. Sélectionnez **Enregistrer les modifications**.

Une fois que le membre a atteint le nombre de jours d'inactivité et a été supprimé du groupe :

- Il a toujours accès à GitLab.com.
- Il n'a pas accès au groupe.
- Les contributions apportées au groupe sont toujours assignées au membre supprimé.
