---
stage: Software Supply Chain Security
group: Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Rôles personnalisés
description: Créez des rôles personnalisés avec des autorisations adaptées pour répondre aux besoins spécifiques de votre organisation.
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Capacité à créer et supprimer un rôle personnalisé via l'interface utilisateur [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/393235) dans GitLab 16.4.
- Capacité à utiliser l'interface utilisateur pour ajouter un utilisateur à votre groupe avec un rôle personnalisé, modifier le rôle personnalisé d'un utilisateur ou supprimer un rôle personnalisé d'un membre du groupe [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/393239) dans GitLab 16.7.
- Capacité à créer et supprimer un rôle personnalisé à l'échelle de l'instance sur GitLab Self-Managed [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/141562) dans GitLab 16.9.
- Les rôles d'administrateur personnalisés [introduits](https://gitlab.com/groups/gitlab-org/-/epics/15854) en tant que [version expérimentale](../../policy/development_stages_support.md) dans GitLab 17.7 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `custom_ability_read_admin_dashboard`.
- Capacité à gérer les rôles d'administrateur personnalisés via l'interface utilisateur [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/181346) dans GitLab 17.9 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `custom_admin_roles`. Fonctionnalité désactivée par défaut.
- Les rôles d'administrateur personnalisés sont [généralement disponibles](https://gitlab.com/groups/gitlab-org/-/epics/15957) dans GitLab 18.3. Le feature flag `custom_admin_roles` est activé par défaut.
- Feature flag `custom_admin_roles` supprimé dans GitLab 19.0.

{{< /history >}}

Les rôles personnalisés vous permettent de créer des rôles avec uniquement les [autorisations personnalisées](abilities.md) spécifiques requises par votre organisation. Chaque rôle personnalisé est basé sur un rôle par défaut existant. Par exemple, vous pouvez créer un rôle personnalisé basé sur le rôle Invité, mais incluant également l'autorisation de consulter le code dans un dépôt de projet.

GitLab propose deux types de rôles personnalisés :

- Rôles de membre personnalisés :
  - Peuvent être attribués aux membres d'un groupe ou d'un projet.
  - Héritent des mêmes autorisations dans tous les sous-groupes ou projets. Pour plus d'informations, consultez [les types d'appartenance](../project/members/_index.md#membership-types).
  - [Utilise un siège](../../subscriptions/manage_seats.md#gitlabcom-billing-and-usage) et devient un [utilisateur facturable](../../subscriptions/manage_seats.md#billable-users).
    - Un rôle de membre Invité personnalisé qui inclut uniquement l'autorisation `read_code` n'utilise pas de siège.
  - Peuvent être attribués aux membres d'un groupe SAML ou LDAP.
- Rôles d'administrateur personnalisés :
  - Peuvent être attribués à n'importe quel utilisateur de l'instance.
  - Accordent des autorisations pour effectuer des actions d'administration spécifiques.
  - Peuvent être attribués aux membres d'un groupe LDAP.

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une démonstration de la fonctionnalité des rôles personnalisés, consultez [[Démo] Un invité Ultimate peut consulter le code sur des dépôts privés via un rôle personnalisé](https://www.youtube.com/watch?v=46cp_-Rtxps).
<!-- Video published on 2023-02-13 -->

## Créer un rôle de membre personnalisé {#create-a-custom-member-role}

Pour créer un rôle de membre personnalisé, vous sélectionnez un rôle GitLab par défaut et ajoutez des [autorisations](abilities.md) supplémentaires. Le rôle par défaut définit les autorisations minimales disponibles pour le rôle personnalisé. Vous ne pouvez pas utiliser [auditeur](../../administration/auditor_users.md) comme rôle par défaut.

Les autorisations personnalisées peuvent permettre des actions généralement réservées au rôle Maintainer ou Owner. Par exemple, un rôle personnalisé avec l'autorisation de gérer les variables CI/CD permet également la gestion des variables CI/CD ajoutées par d'autres Maintainers ou Owners.

Les rôles de membre personnalisés sont disponibles pour les groupes et les projets :

- Sur GitLab.com, sous le groupe principal où le rôle personnalisé a été créé.
- Sur GitLab Self-Managed et GitLab Dedicated, dans l'ensemble de l'instance.

Prérequis :

- Pour GitLab.com, vous devez disposer du rôle Owner pour le groupe.
- Pour GitLab Self-Managed et GitLab Dedicated, vous devez disposer d'un accès administrateur à l'instance.
- Vous devez avoir moins de 10 rôles personnalisés.

Pour créer un rôle de membre personnalisé :

1. Dans la barre latérale gauche :
   - Pour GitLab.com, dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe.
   - Pour GitLab Self-Managed et GitLab Dedicated, dans le coin supérieur droit, sélectionnez **Admin**.
1. Sélectionnez **Paramètres** > **Rôles et autorisations**.
1. Sélectionnez **Nouveau rôle**.
1. Pour les instances GitLab Self-Managed et GitLab Dedicated uniquement. Sélectionnez **Rôle de membre**.
1. Saisissez un nom et une description pour le rôle personnalisé.
1. Dans la liste déroulante **Rôle de base**, sélectionnez un rôle par défaut.
1. Sélectionnez les autorisations souhaitées pour le rôle personnalisé.
1. Sélectionnez **Créer un rôle**.

Vous pouvez également [utiliser l'API](../../api/graphql/reference/_index.md#mutationmemberrolecreate) pour créer un rôle personnalisé.

## Créer un rôle d'administrateur personnalisé {#create-a-custom-admin-role}

{{< details >}}

- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour créer un rôle d'administrateur personnalisé, vous ajoutez des [autorisations](abilities.md) qui permettent des actions généralement réservées aux administrateurs. Chaque rôle d'administrateur personnalisé peut avoir une ou plusieurs autorisations.

Prérequis :

- Vous devez disposer d'un accès administrateur à l'instance.
- Vous devez avoir moins de 10 rôles personnalisés.

Pour créer un rôle d'administrateur personnalisé :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Rôles et autorisations**.
1. Sélectionnez **Nouveau rôle**.
1. Sélectionnez **Rôle d'administrateur**.
1. Saisissez un nom et une description pour le rôle personnalisé.
1. Sélectionnez les autorisations souhaitées pour le rôle personnalisé.
1. Sélectionnez **Créer un rôle**.

Vous pouvez également [utiliser l'API](../../api/graphql/reference/_index.md#mutationmemberroleadmincreate) pour créer un rôle personnalisé.

## Modifier un rôle personnalisé {#edit-a-custom-role}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/437590) dans GitLab 17.0.

{{< /history >}}

Vous pouvez modifier le nom, la description et les autorisations d'un rôle personnalisé, mais vous ne pouvez pas modifier le rôle par défaut. Si vous devez modifier le rôle par défaut, vous devez créer un nouveau rôle personnalisé.

Prérequis :

- Pour GitLab.com, vous devez disposer du rôle Owner pour le groupe.
- Pour GitLab Self-Managed et GitLab Dedicated, vous devez disposer d'un accès administrateur à l'instance.

Pour modifier un rôle personnalisé :

1. Dans la barre latérale gauche :
   - Pour GitLab.com, dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe.
   - Pour GitLab Self-Managed et GitLab Dedicated, dans le coin supérieur droit, sélectionnez **Admin**.
1. Sélectionnez **Paramètres** > **Rôles et autorisations**.
1. En regard d'un rôle personnalisé, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}) > **Modifier un rôle**.
1. Modifiez le rôle.
1. Sélectionnez **Enregistrer un rôle**.

Vous pouvez également utiliser l'API pour modifier un [rôle de membre personnalisé](../../api/graphql/reference/_index.md#mutationmemberroleupdate) ou un [rôle d'administrateur personnalisé](../../api/graphql/reference/_index.md#mutationmemberroleadminupdate).

## Afficher les détails d'un rôle personnalisé {#view-details-of-a-custom-role}

La page **Rôles et autorisations** répertorie les informations de base sur tous les rôles par défaut et personnalisés disponibles. Ces informations comprennent notamment le nom, la description et le nombre d'utilisateurs affectés à chaque rôle personnalisé. Chaque rôle personnalisé inclut un badge `Custom member role` ou `Custom admin role`.

Vous pouvez également consulter des informations plus détaillées sur un rôle personnalisé, notamment l'identifiant du rôle, le rôle par défaut et les autorisations spécifiques.

Prérequis :

- Pour GitLab.com, vous devez disposer du rôle Owner pour le groupe.
- Pour GitLab Self-Managed et GitLab Dedicated, vous devez disposer d'un accès administrateur à l'instance.

Pour afficher les détails d'un rôle personnalisé :

1. Dans la barre latérale gauche :
   - Pour GitLab.com, dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe.
   - Pour GitLab Self-Managed et GitLab Dedicated, dans le coin supérieur droit, sélectionnez **Admin**.
1. Sélectionnez **Paramètres** > **Rôles et autorisations**.
1. En regard d'un rôle personnalisé, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}) > **Afficher les détails**.

## Supprimer un rôle personnalisé {#delete-a-custom-role}

Vous ne pouvez pas supprimer des rôles personnalisés qui sont encore attribués à un utilisateur. Consultez [attribuer un rôle personnalisé à un utilisateur](#assign-a-custom-member-role).

Prérequis :

- Pour GitLab.com, vous devez disposer du rôle Owner pour le groupe.
- Pour GitLab Self-Managed et GitLab Dedicated, vous devez disposer d'un accès administrateur à l'instance.

Pour supprimer un rôle personnalisé :

1. Dans la barre latérale gauche :
   - Pour GitLab.com, dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe.
   - Pour GitLab Self-Managed et GitLab Dedicated, dans le coin supérieur droit, sélectionnez **Admin**.
1. Sélectionnez **Paramètres** > **Rôles et autorisations**.
1. En regard d'un rôle personnalisé, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}) > **Supprimer le rôle**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer le rôle**.

Vous pouvez également utiliser l'API pour supprimer un [rôle de membre personnalisé](../../api/graphql/reference/_index.md#mutationmemberroledelete) ou un [rôle d'administrateur personnalisé](../../api/graphql/reference/_index.md#mutationmemberroleadmindelete).

## Attribuer un rôle de membre personnalisé {#assign-a-custom-member-role}

Vous pouvez attribuer ou modifier des rôles pour les membres de vos groupes et projets. Vous pouvez effectuer cette opération pour des utilisateurs existants ou lorsque vous ajoutez un utilisateur à un [groupe](../group/_index.md#add-users-to-a-group), un [projet](../project/members/_index.md#add-users-to-a-project) ou une [instance](../profile/account/create_accounts.md).

Prérequis :

- Pour les groupes, vous devez disposer du rôle Owner pour le groupe.
- Pour les projets, vous devez disposer du rôle Maintainer ou Owner pour le projet.

Pour attribuer un rôle de membre personnalisé à un utilisateur existant :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre projet.
1. Sélectionnez **Gérer** > **Membres**.
1. Dans la colonne **Rôle**, sélectionnez le rôle d'un membre existant. Le panneau **Détails du rôle** s'ouvre.
1. Dans la liste déroulante **Rôle**, sélectionnez un rôle à attribuer au membre.
1. Sélectionnez **Mettre à jour le rôle** pour attribuer le rôle.

Vous pouvez également [utiliser l'API](../../api/graphql/reference/_index.md#mutationmemberroletouserassign) pour attribuer ou modifier des attributions de rôles personnalisés.

## Attribuer un rôle d'administrateur personnalisé {#assign-a-custom-admin-role}

{{< details >}}

- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez attribuer ou modifier des rôles d'administration aux utilisateurs de votre instance. Vous pouvez effectuer cette opération pour des utilisateurs existants ou lorsque vous ajoutez un utilisateur à l'[instance](../profile/account/create_accounts.md).

Prérequis :

- Vous devez être administrateur de l'instance GitLab.

Pour attribuer un rôle d'administrateur personnalisé à un utilisateur existant :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Vue d'ensemble** > **Utilisateurs**.
1. Sélectionnez **Modifier** pour un utilisateur.
1. Dans la section **Accès**, définissez le niveau d'accès sur **Normal** ou **Auditeur**.
1. Dans la liste déroulante **Espace d’administration**, sélectionnez un rôle d'administrateur personnalisé.

Vous pouvez également [utiliser l'API](../../api/graphql/reference/_index.md#mutationmemberroletouserassign) pour attribuer ou modifier des attributions de rôles personnalisés.

## Attribuer un rôle personnalisé à un groupe invité {#assign-a-custom-role-to-an-invited-group}

{{< history >}}

- Prise en charge des rôles personnalisés pour les groupes invités [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/443369) dans GitLab 17.4 derrière un feature flag nommé `assign_custom_roles_to_group_links_sm`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/issues/471999) dans GitLab 17.4.
- [Généralement disponible](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/225008) dans GitLab 18.10. Le feature flag `assign_custom_roles_to_group_links_sm` a été supprimé.

{{< /history >}}

Lorsque vous [invitez un groupe dans un groupe](../project/members/sharing_projects_groups.md#invite-a-group-to-a-group), vous pouvez attribuer un rôle personnalisé à chaque utilisateur du groupe.

Le rôle attribué est comparé aux rôles et autorisations des utilisateurs dans leur groupe d'origine. En général, les utilisateurs se voient attribuer le rôle avec le niveau d'accès le plus faible. Cependant, si les utilisateurs ont un rôle personnalisé dans leur groupe d'origine :

- Seul le rôle par défaut est utilisé pour les comparaisons de niveau d'accès. Les autorisations personnalisées ne sont pas comparées.
- Si les rôles personnalisés ont le même rôle par défaut, les utilisateurs conservent leur rôle personnalisé du groupe d'origine.

Le tableau suivant fournit des exemples du rôle maximum disponible pour les utilisateurs invités dans un groupe :

| Scénario                                                | Utilisateur avec le rôle Invité | Utilisateur avec le rôle Invité + `read_code` | Utilisateur avec le rôle Invité + `read_vulnerability` | Utilisateur avec le rôle Developer     | Utilisateur avec le rôle Developer + `admin_vulnerability` |
| ------------------------------------------------------- | -------------------- | ---------------------------------- | ------------------------------------------- | ---------------------------- | ------------------------------------------------ |
| **Invité avec le rôle Invité**                             | Invité                | Invité                            | Invité                                     | Invité                        | Invité                                          |
| **Invité avec le rôle Invité + `read_code`**               | Invité                | Invité + `read_code`              | Invité + `read_vulnerability`              | Invité + `read_code`          | Invité + `read_code`                            |
| **Invité avec le rôle Invité + `read_vulnerability`**      | Invité                | Invité + `read_code`              | Invité + `read_vulnerability`              | Invité + `read_vulnerability` | Invité + `read_vulnerability`                   |
| **Invité avec le rôle Developer**                         | Invité                | Invité + `read_code`              | Invité + `read_vulnerability`              | Développeur                    | Développeur                                      |
| **Invité avec le rôle Developer + `admin_vulnerability`** | Invité                | Invité + `read_code`              | Invité + `read_vulnerability`              | Développeur                    | Developer + `admin_vulnerability`              |

Vous pouvez uniquement attribuer des rôles personnalisés lorsque vous invitez un groupe dans un autre groupe. [Le ticket 468329](https://gitlab.com/gitlab-org/gitlab/-/issues/468329) propose d'attribuer un rôle personnalisé lors de l'invitation d'un groupe dans un projet.

## Objets pris en charge {#supported-objects}

Vous pouvez attribuer des rôles personnalisés et des autorisations aux éléments suivants :

| Objet | Version       | Ticket |
|--------|---------------|-------|
| Utilisateurs  | 15.9          | Disponible |
| Groupes | 17.7          | Partiellement pris en charge. La prise en charge supplémentaire de l'affectation de groupe dans les projets est proposée dans [le ticket 468329](https://gitlab.com/gitlab-org/gitlab/-/issues/468329) |
| Jetons | Non pris en charge | [Ticket 434354](https://gitlab.com/gitlab-org/gitlab/-/issues/434354) |

## Attribuer un rôle personnalisé à un groupe externe {#assign-a-custom-role-to-an-external-group}

{{< details >}}

- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez attribuer un rôle de membre personnalisé à tous les utilisateurs d'un groupe LDAP ou SAML externe, ou un rôle d'administrateur personnalisé aux utilisateurs synchronisés depuis un groupe LDAP uniquement.

Pour attribuer des rôles personnalisés à des groupes LDAP ou SAML :

- [Attribuer un rôle de membre personnalisé à un groupe SAML](../group/saml_sso/group_sync.md#configure-saml-group-links).
- [Attribuer un rôle de membre personnalisé à un groupe LDAP](../group/access_and_permissions.md#manage-group-memberships-with-ldap).
- [Attribuer un rôle d'administrateur personnalisé à un groupe LDAP](../../administration/auth/ldap/ldap_synchronization.md#assign-a-custom-admin-role-to-an-ldap-group).

## Contribuer à de nouvelles autorisations {#contribute-new-permissions}

Si une autorisation n'existe pas, vous pouvez :

- Discuter des demandes individuelles de rôles personnalisés et d'autorisations dans le [ticket 391760](https://gitlab.com/gitlab-org/gitlab/-/issues/391760).
- Créer un ticket pour demander l'autorisation à l'aide du [modèle de ticket de proposition d'autorisation](https://gitlab.com/gitlab-org/gitlab/-/work_items/new?description_template=Permission%20Proposal).
- Contribuer à GitLab et ajouter l'autorisation.
