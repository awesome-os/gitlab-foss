---
stage: Tenant Scale
group: Organizations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Partage de projets et de groupes
description: "Invitations, héritage de groupe et visibilité des projets."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/issues/219230) pour afficher les membres des groupes invités dans l'onglet Membres de la page Membres dans GitLab 16.10 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `webui_members_inherited_users`. Fonctionnalité désactivée par défaut.
- Le feature flag `webui_members_inherited_users` a été [activé sur GitLab.com et GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab/-/issues/219230) dans GitLab 17.0.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/163627) du feature flag `webui_members_inherited_users` dans GitLab 17.4. Les membres des groupes invités sont affichés par défaut.
- Dans GitLab 18.0, les invitations de groupe sont limitées aux propriétaires.

{{< /history >}}

Vous pouvez partager par invitation :

- Un projet avec un groupe.
- Un groupe avec un autre groupe.

## Partage de projets {#sharing-projects}

Lorsque vous souhaitez qu'un groupe ait accès à votre projet, vous pouvez inviter le [groupe](../../group/_index.md) dans le projet. Les membres directs et hérités du groupe obtiennent l'accès au projet, qui devient un **projet partagé**.

Dans ce cas, les membres hérités sont des membres hérités des groupes parents dans les groupes invités. Seuls les membres du groupe invité obtiennent l'accès au projet partagé. Si vous souhaitez accorder l'accès au projet aux membres d'un sous-groupe du groupe que vous invitez, vous devez inviter le sous-groupe.

Le tableau suivant donne une vue d'ensemble des membres du groupe qui obtiennent l'accès à un projet partagé.

| Source du membre du groupe                                                  | Accès au projet partagé |
|----------------------------------------------------------------------|--------------------------|
| Membre direct du groupe invité                           | {{< yes >}}              |
| Membre hérité du groupe invité                        | {{< yes >}}              |
| Membre partagé du groupe invité[^supports-extending-project]              | {{< yes >}}              |
| Membre direct d'un sous-groupe, mais pas du groupe invité    | {{< no >}}               |
| Membre hérité d'un sous-groupe, mais pas du groupe invité | {{< no >}}               |

[^supports-extending-project]: GitLab prend en charge l'extension de l'accès au projet aux membres du groupe partagé, mais cette approche n'est pas recommandée. [L'epic 122](https://gitlab.com/groups/gitlab-org/-/epics/122) propose de modifier ce comportement et de passer à un modèle d'équipes pour le partage de groupes.

Le [niveau de visibilité](../../public_access.md) du groupe que vous invitez ne peut pas être plus restrictif que celui du projet. Par exemple, vous pouvez inviter :

- Un groupe **privé** dans un projet **privé**.
- Un groupe **privé** dans un projet **interne**.
- Un groupe **privé** dans un projet **public**.
- Un groupe **interne** dans un projet **interne**.
- Un groupe **interne** dans un projet **public**.
- Un groupe **public** dans un projet **public**.

Si le groupe principal du projet n'autorise pas le partage du projet en dehors de la hiérarchie, le groupe ou sous-groupe invité doit se trouver dans l'[espace de nommage](../../namespace/_index.md) du projet.

### Accès et rôles des membres {#member-access-and-roles}

Lorsque vous invitez un groupe dans un projet, les membres suivants obtiennent l'accès au projet :

- Membres directs du groupe.
- Membres hérités du groupe.
- Membres des autres [groupes partagés](#invite-a-group-to-a-group) avec le groupe invité.

L'accès de chaque membre dépend de :

- Son rôle dans le groupe.
- Le rôle maximal que vous choisissez lors de l'invitation du groupe.

Les membres invités conservent le rôle le moins élevé parmi ces deux rôles. Par exemple, si un membre a le rôle Invité dans son groupe et que vous ajoutez son groupe à un projet avec un rôle maximal de Chargé de maintenance, il conserve le rôle Invité dans le projet.

De plus :

- Sur la page du groupe, le projet est répertorié dans l'onglet **Projets partagés**.
- Sur la page **Membres** du projet, le groupe est répertorié dans l'onglet **Groupes**. Cette liste inclut les groupes publics et privés.
- Sur la page **Membres** du projet, les membres du groupe invité sont répertoriés dans l'onglet **Membres**.
- Sur la page des quotas d'utilisation, les membres qui ont le badge **Project Invite** à côté de leur profil sont comptabilisés parmi les membres facturables du groupe principal du projet partagé.

Le nom du groupe invité et la source d'appartenance sont [masqués](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/144638) dans les onglets **Membres** et **Groupes**, sauf dans les cas suivants :

- Le groupe invité est public.
- L'utilisateur actuel est membre du groupe invité.
- L'utilisateur actuel est propriétaire du projet.

> [!note]
> Le nom du groupe invité et la source d'appartenance sont masqués pour les membres qui n'ont pas accès au groupe invité. Les propriétaires de projet peuvent consulter les détails d'appartenance des groupes invités pour les aider à gérer l'accès à leurs projets.

### Exemples {#examples}

Un projet dans l'espace de nommage `group/subgroup01/project` :

- Peut être partagé avec `group/subgroup02` ou `group/subgroup01/subgroup03`.
- Peut être partagé avec `group_abc`, sauf si le groupe principal du projet n'autorise pas le partage du projet en dehors de la hiérarchie.

Pour un projet créé par `Group 1` :

- Les membres de `Group 1` ont accès au projet.
- Le propriétaire de `Group 1` peut inviter `Group 2` dans le projet. Ainsi, les membres de `Group 1` et de `Group 2` ont tous accès au projet partagé.

### Inviter un groupe dans un projet {#invite-a-group-to-a-project}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/issues/219230) pour afficher les membres des groupes invités dans l'onglet Membres de la page Membres dans GitLab 16.10 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `webui_members_inherited_users`. Fonctionnalité désactivée par défaut.
- Feature flag `webui_members_inherited_users` [activé sur GitLab.com et GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab/-/issues/219230) dans GitLab 17.0.
- La date d'expiration de l'accès pour les membres directs des sous-groupes et des projets a été [supprimée](https://gitlab.com/gitlab-org/gitlab/-/issues/471051), et le feature flag `webui_members_inherited_users` a été [supprimé](https://gitlab.com/gitlab-org/gitlab/-/issues/364078) dans GitLab 17.4.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le projet.
- Le partage du projet avec d'autres groupes ne doit pas être empêché.
- Vous devez être membre du groupe ou du sous-groupe invité.

Pour inviter un groupe dans un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez **Inviter un groupe**.
1. Dans la liste **Sélectionnez un groupe à inviter**, sélectionnez le groupe que vous souhaitez inviter.
1. Dans la liste **Sélectionner le rôle maximal**, sélectionnez le [rôle](../../permissions.md) que les membres du groupe invité peuvent avoir dans le projet. Les membres invités reçoivent le rôle le moins élevé parmi :
   - Le rôle maximal que vous sélectionnez
   - Leur rôle existant dans le groupe

   Les membres du groupe invité ne peuvent pas avoir un rôle plus élevé dans le projet que dans le groupe. Pour plus d'informations, consultez [l'accès et les rôles des membres](#member-access-and-roles).
1. Facultatif. Sélectionnez une **Date d’expiration de l’accès**. À partir de cette date, le groupe invité ne peut plus accéder au projet.
1. Sélectionnez **Inviter**.

Le groupe invité s'affiche dans l'onglet **Groupes**. Vous pouvez également utiliser l'API REST pour [répertorier les groupes invités d'un projet](../../../api/projects.md#list-all-invited-groups-in-a-project).

Les groupes privés sont :

- Masqués pour les utilisateurs non autorisés.
- Affichés dans les paramètres du projet pour les branches protégées, les tags protégés et les environnements protégés.

L'onglet **Membres** affiche :

- Les membres qui ont été ajoutés directement au projet.
- Les membres hérités de l'[espace de nommage](../../namespace/_index.md) du groupe auquel le projet a été ajouté.

Les membres du groupe invité ne s'affichent pas dans l'onglet **Membres**, sauf si le feature flag `webui_members_inherited_users` est activé.

#### Exemples {#examples-1}

Un projet nommé `project-01` a les membres directs suivants :

- Utilisateur A, Propriétaire
- Utilisateur B, Chargé de maintenance

Un groupe nommé `group-01` a les membres directs suivants :

- Utilisateur C, Propriétaire
- Utilisateur D, Chargé de maintenance
- Utilisateur E, Reporter

Lorsque `group-01` est invité dans `project-01` avec les permissions `Developer`, les utilisateurs ont les rôles suivants :

- Utilisateur A, Propriétaire
- Utilisateur B, Chargé de maintenance
- Utilisateur C, Développeur
- Utilisateur D, Développeur
- Utilisateur E, Reporter

Lorsque `group-01` est invité dans `project-01` avec les permissions `Owner`, les utilisateurs ont les rôles suivants :

- Utilisateur A, Propriétaire
- Utilisateur B, Chargé de maintenance
- Utilisateur C, Propriétaire
- Utilisateur D, Chargé de maintenance
- Utilisateur E, Reporter

### Afficher les projets partagés {#view-shared-projects}

Un projet partagé est un projet qui a invité les membres de votre groupe à accéder à ses ressources via l'action [**Inviter un groupe**](#invite-a-group-to-a-project).

Pour afficher les projets qui ont partagé l'accès avec votre groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Sur la page du groupe, sélectionnez l'onglet **Projets partagés**.

Une liste de projets partagés s'affiche. Vous pouvez également utiliser l'API REST pour [répertorier les projets partagés d'un groupe](../../../api/groups.md#list-shared-projects).

### Empêcher le partage d'un projet avec des groupes {#prevent-a-project-from-being-shared-with-groups}

Le partage d'un projet avec un autre groupe augmente le nombre d'utilisateurs pouvant inviter davantage de membres dans le projet. Chaque (sous-)groupe peut être une source supplémentaire d'autorisations d'accès, ce qui peut être source de confusion et difficile à contrôler.

Pour empêcher le partage d'un projet avec d'autres groupes :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Sélectionnez **Les projets dans `<group_name>` ne peuvent pas être partagés avec d'autres groupes**.
1. Sélectionnez **Enregistrer les modifications**.

Lorsque ce paramètre est activé :

- Il s'applique à tous les sous-groupes, sauf s'il est remplacé par un propriétaire de groupe.
- Les groupes déjà ajoutés à un projet perdent l'accès à celui-ci.

Lorsque ce paramètre est désactivé :

- Il s'applique uniquement à ce groupe, et non à ses sous-groupes.
- Pour désactiver ce paramètre pour tous les sous-groupes, vous devez mettre à jour chaque sous-groupe individuellement.

## Partage de groupes {#sharing-groups}

Lorsque vous souhaitez que les membres d'un autre groupe aient accès à votre groupe, vous pouvez inviter le [groupe](../../group/_index.md) dans votre groupe. Les membres directs du groupe obtiennent l'accès au groupe, qui devient un **groupe partagé**.

Seuls les membres directs du groupe invité obtiennent l'accès au groupe partagé, et non les membres hérités, partagés ou issus de sous-groupes. Pour accorder l'accès aux membres d'un sous-groupe, invitez directement le sous-groupe.

Le tableau suivant donne une vue d'ensemble des membres du groupe qui obtiennent l'accès à un groupe partagé :

| Source du membre du groupe                                        | Accès au groupe partagé |
|------------------------------------------------------------|------------------------|
| Membre direct du groupe invité                 | {{< yes >}}            |
| Membre hérité du groupe invité              | {{< no >}}             |
| Membre partagé du groupe invité                 | {{< no >}}             |
| Membre d'un sous-groupe, mais pas du groupe invité | {{< no >}}             |

### Accès et rôles des membres {#member-access-and-roles-1}

L'accès de chaque membre dépend de :

- Son rôle dans le groupe invité.
- Le rôle maximal que vous choisissez lors de l'invitation du groupe.

Les membres invités conservent le rôle le moins élevé parmi ces deux rôles. Par exemple, si un membre a le rôle Invité dans son groupe et que vous invitez son groupe dans un autre groupe avec un rôle maximal de Chargé de maintenance, il conserve le rôle Invité dans le nouveau groupe.

Après avoir invité un groupe dans votre groupe :

- Sur la page de présentation du groupe, les groupes avec lesquels ce groupe a été partagé sont répertoriés dans l'onglet **Groupes partagés**.
- Sur la page **Membres** du groupe, le groupe invité est répertorié dans l'onglet **Groupes**. Cette liste inclut les groupes publics et privés.
- Sur la page **Membres** du groupe, les membres du groupe invité sont répertoriés dans l'onglet **Membres**.
- Sur la page des quotas d'utilisation du groupe, les membres directs du groupe invité qui ont le badge **Group Invite** à côté de leur profil sont comptabilisés parmi les membres facturables du groupe invitant.

Le nom du groupe invité et la source d'appartenance sont [masqués](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/144638) dans les onglets **Membres** et **Groupes**, sauf dans les cas suivants :

- Le groupe invité est public.
- L'utilisateur actuel est membre du groupe invité.
- L'utilisateur actuel est propriétaire du projet.

> [!note]
> Le nom du groupe invité et la source d'appartenance sont masqués pour les membres qui n'ont pas accès au groupe invité. Cependant, même si les propriétaires de groupe ne peuvent pas accéder au groupe privé invité, ils peuvent voir la source des membres du groupe privé invité. Ce comportement est destiné à aider les propriétaires de groupe à mieux gérer les appartenances des groupes qu'ils possèdent.

### Exemples {#examples-2}

`User A` est un membre direct de `Group 1` et a le rôle Chargé de maintenance pour le groupe. `Group 2` invite `Group 1` avec le rôle Développeur. `User A` a le rôle Développeur dans `Group 2`.

`User B` est un membre hérité de `Group 1`. Cet utilisateur n'obtient pas l'accès à `Group 2` lorsque `Group 1` est invité.

### Inviter un groupe dans un groupe {#invite-a-group-to-a-group}

{{< history >}}

- La date d'expiration de l'accès pour les membres directs des sous-groupes et des projets a été [supprimée](https://gitlab.com/gitlab-org/gitlab/-/issues/471051) dans GitLab 17.4.

{{< /history >}}

De la même manière que vous invitez un groupe dans un projet, vous pouvez inviter un groupe dans un autre groupe.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe dans lequel vous souhaitez inviter d'autres personnes.
- Vous devez pouvoir accéder au groupe que vous souhaitez inviter.

Pour inviter un groupe dans votre groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez **Inviter un groupe**.
1. Dans la liste **Sélectionnez un groupe à inviter**, sélectionnez le groupe que vous souhaitez inviter.
1. Dans la liste **Sélectionner le rôle maximal**, sélectionnez le [rôle](../../permissions.md) que les membres du groupe invité peuvent avoir dans le groupe. Les membres invités reçoivent le rôle le moins élevé parmi :
   - Le rôle maximal que vous sélectionnez
   - Leur rôle existant dans le groupe invité

   Les membres invités ne peuvent pas avoir un rôle plus élevé que celui qu'ils ont dans le groupe invité. Pour plus d'informations, consultez [l'accès et les rôles des membres](#member-access-and-roles-1).
1. Sélectionnez le [rôle](../../permissions.md) le plus élevé ou le [rôle personnalisé](../../custom_roles/_index.md#assign-a-custom-role-to-an-invited-group) pour les utilisateurs du groupe.
1. Facultatif. Sélectionnez une **Date d’expiration de l’accès**. À partir de cette date, le groupe invité ne peut plus accéder au groupe.
1. Sélectionnez **Inviter**.

### Supprimer un groupe invité {#remove-an-invited-group}

Pour supprimer un groupe invité :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Groupes**.
1. À droite du groupe que vous souhaitez supprimer, sélectionnez **Supprimer le groupe** ({{< icon name="remove" >}}).

Lorsque vous supprimez le groupe invité de votre groupe :

- Tous les membres directs du groupe invité n'ont plus accès à votre groupe.
- Les membres du groupe invité ne sont plus comptabilisés parmi les membres facturables de votre groupe.

### Afficher les groupes partagés {#view-shared-groups}

Un groupe partagé est un groupe qui a invité les membres de votre groupe à accéder à ses ressources via l'action [**Inviter un groupe**](#invite-a-group-to-a-group).

Pour afficher les groupes qui ont partagé l'accès avec votre groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Sur la page du groupe, sélectionnez l'onglet **Groupes partagés**.

Une liste de groupes partagés s'affiche. Vous pouvez également utiliser l'API REST pour [répertorier les groupes partagés d'un groupe](../../../api/groups.md#list-shared-groups).

### Empêcher l'invitation de groupes en dehors de la hiérarchie du groupe {#prevent-inviting-groups-outside-the-group-hierarchy}

Vous pouvez configurer un groupe principal de sorte que ses sous-groupes et ses projets ne puissent pas inviter d'autres groupes en dehors de la hiérarchie du groupe principal. Cette option est disponible uniquement pour les groupes principaux.

Par exemple, dans la hiérarchie de groupes et de projets suivante :

- **Animals** > **Dogs** > **Dog Project**
- **Animals** > **Cats**
- **Plants** > **Trees**

Si vous empêchez l'invitation de groupes en dehors de la hiérarchie pour le groupe **Animals** :

- **Dogs** peut inviter le groupe **Cats**.
- **Dogs** ne peut pas inviter le groupe **Trees**.
- **Dog Project** peut inviter le groupe **Cats**.
- **Dog Project** ne peut pas inviter le groupe **Trees**.

Pour empêcher l'invitation de groupes en dehors de la hiérarchie du groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sélectionnez **Les membres ne peuvent pas inviter des groupes en dehors de `<group_name>` et de ses sous-groupes**.
1. Sélectionnez **Enregistrer les modifications**.

## Configuration d'un groupe pour la collaboration {#setting-up-a-group-for-collaboration}

Si vous envisagez de collaborer avec des utilisateurs externes sur des projets dans votre groupe, tenez compte des bonnes pratiques suivantes :

- Structurez vos groupes et sous-groupes de manière logique en fonction des besoins organisationnels. Évitez de créer des groupes inutiles.
- Si vous avez un grand nombre d'utilisateurs à gérer, envisagez d'organiser les utilisateurs dans des groupes distincts des groupes organisant les projets. Partagez ces groupes d'utilisateurs dans les groupes et les projets auxquels ils doivent avoir accès.
- Choisissez soigneusement les groupes que vous invitez dans vos projets. N'invitez que les groupes qui ont besoin d'un accès, afin d'éviter le surpartage et de maintenir la sécurité.
- Lorsque vous invitez un groupe :
  - Définissez le rôle maximal de manière appropriée. Il est préférable d'attribuer les permissions minimales nécessaires plutôt que de définir par défaut le rôle le plus élevé.
  - Les membres des sous-groupes du groupe invité n'obtiennent pas l'accès au projet. Vous pouvez préférer inviter les sous-groupes séparément.
- Vérifiez le rôle maximal des utilisateurs qui appartiennent à plusieurs groupes ayant accès à un projet. Pour éviter des permissions élevées non intentionnelles, vous pouvez modifier les rôles des utilisateurs.
- Examinez périodiquement l'accès des groupes aux projets partagés et mettez-le à jour si nécessaire. Si un groupe n'a plus besoin d'accéder à un projet, supprimez-le.
