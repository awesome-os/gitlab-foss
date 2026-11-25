---
stage: Tenant Scale
group: Organizations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Entreprises
description: Hiérarchie des espaces de nommage.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed
- Statut : version bêta

{{< /details >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par des feature flags. Cette fonctionnalité n'est pas prête pour une utilisation en production.

Une organisation est l'entité de niveau supérieur dans la hiérarchie GitLab. Chaque organisation contient un ou plusieurs [groupes principaux](../namespace/_index.md), ainsi que tous leurs sous-groupes et projets.

Une organisation agit comme une couche d'administration au-dessus de ces groupes, avec une zone dédiée **Admin de l'organisation** où vous pouvez administrer les paramètres de l'organisation et gérer les utilisateurs.

Pour plus d'informations sur l'état du développement des organisations, consultez l'[epic 9265](https://gitlab.com/groups/gitlab-org/-/epics/9265).

Les organisations sont en version bêta fermée et disponibles sur invitation uniquement pour un ensemble limité de participants à la version bêta.

## Créer une organisation {#create-an-organization}

Créez une organisation à partir d'un groupe principal existant.

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/247436) dans GitLab 19.3 [avec le feature flag](../../administration/feature_flags/_index.md) `org_stage_beta`. Fonctionnalité désactivée par défaut.

{{< /history >}}

Prérequis :

- Le rôle Propriétaire pour le groupe principal depuis lequel vous démarrez, et pour tout autre groupe principal que vous souhaitez inclure.

Pour créer une organisation à partir d'un groupe principal existant :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Paramètres avancés**.
1. Dans la section **Créer une organisation**, sélectionnez **Créer une organisation**.
1. Dans la boîte de dialogue de confirmation **Créer vos organisations**, sélectionnez le groupe avec lequel vous souhaitez créer une organisation, puis sélectionnez **Continuer**.
1. Facultatif. Si vous disposez du rôle Propriétaire pour plusieurs groupes principaux, dans la boîte de dialogue de confirmation **Attribuer des groupes de niveau supérieur**, faites glisser ces groupes dans le conteneur de l'organisation. Les groupes que vous n'attribuez pas ne sont pas inclus. Sélectionnez **Continuer**.
1. Dans la boîte de dialogue de confirmation **Confirmer votre organisation**, passez en revue la structure proposée.
1. Sélectionnez **Confirmer**.

Après avoir confirmé la structure de votre organisation :

- Vos groupes et projets sont transférés dans l'organisation de manière asynchrone.
- Les utilisateurs membres d'un groupe ou d'un projet transféré deviennent membres de l'organisation.
- Vous recevez un e-mail lorsque le transfert est prêt. Les groupes plus importants prennent plus de temps à transférer.
- Tout utilisateur disposant du rôle Propriétaire dans l'ensemble des groupes principaux transférés devient administrateur de l'organisation.

Vous pouvez modifier ultérieurement le nom, l'URL, la description, la visibilité et l'avatar de l'organisation depuis la zone **Admin de l'organisation**.

> [!note]
> Après avoir confirmé la structure de votre organisation, vous ne pouvez pas ajouter ni supprimer vous-même des groupes principaux. Si vous souhaitez ajouter des groupes principaux supplémentaires à votre organisation après confirmation, contactez le support pour obtenir de l'aide. Vous ne pouvez pas non plus supprimer l'organisation tant qu'elle contient des groupes ou des projets. Si vous devez apporter des modifications, [contactez le support](https://support.gitlab.com/).

## Accéder à votre organisation {#go-to-your-organization}

Si vous êtes membre d'une ou plusieurs organisations, vous pouvez accéder à n'importe laquelle d'entre elles depuis la page **Organisations**. Pour accéder à une organisation :

1. Dans la barre latérale gauche, sélectionnez **Organisations**.
1. Dans la liste, sélectionnez l'organisation à laquelle vous souhaitez accéder.

## URL des organisations {#organization-urls}

Une organisation, ainsi que tout ce qu'elle contient, est adressée sous `/o/<organization-path>/`. Par exemple, `https://gitlab.example.com/o/my-org/-/overview`. Les URL de groupe et de projet existantes continuent de fonctionner.

Étant donné que `o` est un chemin réservé, aucun groupe principal ne peut utiliser `o` comme chemin.

L'organisation par défaut est une exception à ce schéma d'URL. Son contenu reste sur des URL sans portée.

## L'organisation par défaut {#the-default-organization}

Chaque instance GitLab possède une organisation par défaut. Chaque compte démarre dans l'organisation par défaut. L'organisation par défaut ne peut pas être supprimée.

Vous quittez l'organisation par défaut lorsque votre groupe principal rejoint une organisation qui vous appartient.

## Types d'utilisateurs et autorisations {#user-types-and-permissions}

Une organisation comporte deux types d'utilisateurs : l'administrateur de l'organisation et l'utilisateur standard de l'organisation.

Un type d'utilisateur décrit la relation d'une personne avec l'organisation. Pour un utilisateur standard de l'organisation, les rôles de groupe et de projet régissent l'accès aux groupes et aux projets. Les administrateurs de l'organisation ont un accès complet à tous les groupes et projets au sein de l'organisation.

Le tableau suivant répertorie les actions disponibles pour chaque type d'utilisateur :

| Action | Administrateur de l'organisation | Utilisateur standard de l'organisation |
|--------|----------------------------|-------------------|
| Afficher l'organisation | {{< yes >}} | {{< yes >}} |
| Créer un groupe | {{< yes >}} | {{< yes >}} |
| Mettre à jour l'organisation | {{< yes >}} | {{< no >}} |
| Accéder à la zone **Admin de l'organisation** | {{< yes >}} | {{< no >}} |
| Afficher les utilisateurs de l'organisation | {{< yes >}} | {{< no >}} |
| Gérer l'appartenance à l'organisation | {{< yes >}} | {{< no >}} |
| Transférer un groupe principal dans l'organisation | {{< yes >}} | {{< no >}} |
| Quitter l'organisation | {{< yes >}} | {{< yes >}} |
| Acheter des produits à portée d'organisation | {{< yes >}} | {{< no >}} |
| Attribuer des rôles de produit à l'organisation | {{< yes >}} | {{< no >}} |

### Rôles de groupe et de projet {#group-and-project-roles}

Au sein d'une organisation, les [rôles par défaut](../permissions.md#default-roles) continuent de contrôler l'accès aux groupes et aux projets.

Lorsqu'un groupe principal est transféré dans une organisation, ses membres de groupe et de projet deviennent des utilisateurs de l'organisation. Ils conservent leurs rôles et autorisations préexistants.

## Administrateurs d'instance et d'organisation {#instance-and-organization-administrators}

Les administrateurs d'instance peuvent gérer toutes les organisations de l'instance. Lorsqu'un administrateur d'instance et un administrateur d'organisation prennent des mesures conflictuelles, l'action de l'administrateur d'instance a la priorité.

Les administrateurs d'organisation gèrent leur propre organisation sans administrateur d'instance. Chaque organisation doit avoir au moins un administrateur d'organisation. Vous ne pouvez pas supprimer le dernier administrateur d'organisation ni modifier son type d'utilisateur.

| Administrateur              | Portée                      | Sur GitLab.com               | Sur GitLab Self-Managed                                  |
|----------------------------|----------------------------|-----------------------------|---------------------------------------------------------|
| Administrateur d'instance     | L'ensemble de l'instance GitLab | Un membre interne de l'équipe GitLab        | Souvent la même personne que l'administrateur de l'organisation |
| Administrateur de l'organisation | Une organisation           | Un utilisateur de votre organisation | Souvent la même personne que l'administrateur d'instance     |

### Afficher les organisations {#view-organizations}

Affichez les organisations dans votre instance GitLab.

Prérequis :

- Accès administrateur d'instance.

Pour afficher toutes les organisations :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Sélectionnez **Organisations**.

## Gérer l'appartenance à l'organisation {#manage-organization-membership}

Utilisez la zone **Admin de l'organisation** pour ajouter des utilisateurs à l'organisation, modifier leur type d'utilisateur et les supprimer.

Prérequis :

- Accès administrateur de l'organisation.

### Afficher les utilisateurs de l'organisation {#view-organization-users}

Pour afficher les utilisateurs de votre organisation :

1. Dans la barre latérale gauche, sélectionnez **Organisations**.
1. Dans la liste déroulante, sélectionnez l'organisation à laquelle vous souhaitez accéder.
1. Dans la barre latérale gauche, sélectionnez **Gérer l'organisation**. La zone **Admin de l'organisation** s'ouvre.
1. Sélectionnez **Présentation de l'organisation** > **Utilisateurs**.

### Ajouter un utilisateur à une organisation {#add-a-user-to-an-organization}

Pour ajouter un utilisateur à une organisation :

1. Dans la barre latérale gauche, sélectionnez **Organisations**.
1. Dans la liste déroulante, sélectionnez l'organisation à laquelle vous souhaitez accéder.
1. Dans la barre latérale gauche, sélectionnez **Gérer l'organisation**. La zone **Admin de l'organisation** s'ouvre.
1. Sélectionnez **Présentation de l'organisation** > **Utilisateurs**.
1. Sélectionnez **Inviter un utilisateur de l'organisation**.
1. Dans **Noms d'utilisateur GitLab**, recherchez et sélectionnez un ou plusieurs utilisateurs par nom d'utilisateur.
1. Sous **Type d'utilisateur de l'organisation**, sélectionnez l'une des options suivantes :
   - **Utilisateur standard de l'organisation** : accorde à un utilisateur l'accès aux groupes et aux projets dont il est membre.
   - **Administrateur de l'organisation** : accorde l'accès à tous les groupes, projets, utilisateurs, fonctionnalités et à la zone **Admin de l'organisation**.
1. Sélectionnez **Inviter**.

Vous pouvez également ajouter un utilisateur à une organisation en l'ajoutant à un groupe ou un projet de l'organisation.

### Gérer l'accès administrateur de l'organisation {#manage-organization-administrator-access}

Pour modifier le statut d'un utilisateur en tant qu'utilisateur standard ou administrateur de l'organisation :

1. Dans la barre latérale gauche, sélectionnez **Organisations**.
1. Dans la liste déroulante, sélectionnez l'organisation à laquelle vous souhaitez accéder.
1. Dans la barre latérale gauche, sélectionnez **Gérer l'organisation**. La zone **Admin de l'organisation** s'ouvre.
1. Sélectionnez **Présentation de l'organisation** > **Utilisateurs**.
1. En regard de l'utilisateur, sélectionnez **Modifier**.
1. Sous **Type d'utilisateur de l'organisation**, sélectionnez l'une des options suivantes :
   - **Utilisateur standard de l'organisation** : accorde à un utilisateur l'accès aux groupes et aux projets dont il est membre.
   - **Administrateur de l'organisation** : accorde l'accès à tous les groupes, projets, utilisateurs, fonctionnalités et à la zone **Admin de l'organisation**.
1. Sélectionnez **Enregistrer les modifications**.

### Supprimer un utilisateur d'une organisation {#remove-a-user-from-an-organization}

Lorsque vous supprimez un utilisateur d'une organisation, il est également supprimé de tous les groupes et projets de l'organisation.

Pour supprimer un utilisateur d'une organisation :

1. Dans la barre latérale gauche, sélectionnez **Organisations**.
1. Dans la liste déroulante, sélectionnez l'organisation à laquelle vous souhaitez accéder.
1. Dans la barre latérale gauche, sélectionnez **Gérer l'organisation**. La zone **Admin de l'organisation** s'ouvre.
1. Sélectionnez **Présentation de l'organisation** > **Utilisateurs**.
1. En regard de l'utilisateur, sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}) > **Supprimer de l'organisation**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer**.

## Visibilité de l'organisation {#organization-visibility}

Une organisation est soit publique, soit privée. La visibilité interne n'est pas disponible pour les organisations.

| Visibilité | Qui peut voir l'organisation | Visibilité de groupe et de projet autorisée |
|------------|-------------------------------|--------------------------------------|
| Publique | Tout le monde | Publique et privée |
| Privée | Utilisateurs de l'organisation uniquement | Privée |

Une organisation ne peut pas être plus restrictive que les groupes qu'elle contient. Par exemple, vous ne pouvez pas rendre une organisation privée si elle contient un groupe public.

## Markdown pris en charge pour la description de l'organisation {#supported-markdown-for-organization-description}

Le champ de description de l'organisation prend en charge un sous-ensemble limité du [Markdown GitLab Flavored](../markdown.md), notamment :

- [Emphase](../markdown.md#emphasis)
- [Liens](../markdown.md#links)
- [Exposants / Indices](../markdown.md#superscripts-and-subscripts)
