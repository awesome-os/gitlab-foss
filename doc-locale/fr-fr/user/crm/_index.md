---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Gestion des relations client (CRM)
description: "Gestion des clients, entreprises, contacts et autorisations."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum de Reporter à Planificateur dans GitLab 17.7.

{{< /history >}}

> [!note]
> Cette fonctionnalité n'est pas en développement actif, mais les [contributions de la communauté](https://about.gitlab.com/community/contribute/) sont les bienvenues. Pour déterminer si la fonctionnalité répond à vos besoins, consultez les éléments de travail ouverts dans [l'epic 5323](https://gitlab.com/groups/gitlab-org/-/epics/5323).

Avec la gestion des relations client (CRM), vous pouvez créer un enregistrement de contacts (personnes) et d'entreprises (sociétés) et les associer à des éléments de travail.

Par défaut, les contacts et les entreprises ne peuvent être créés que pour les groupes principaux. Pour créer des contacts et des entreprises dans d'autres groupes, [définissez le groupe comme source de contacts](#configure-the-contact-source).

Vous pouvez utiliser les contacts et les entreprises pour lier le travail aux clients à des fins de facturation et de reporting. Pour plus d'informations sur ce qui est prévu pour l'avenir, consultez [le ticket 2256](https://gitlab.com/gitlab-org/gitlab/-/issues/2256).

## Autorisations {#permissions}

| Autorisation                         | Invité | Planificateur | Reporter de groupe | Développeur, Mainteneur et Propriétaire de groupe |
|------------------------------------|-------|---------|----------------|----------------------------------------|
| Voir les contacts/entreprises        |       | ✓       | ✓              | ✓                                      |
| Voir les contacts des éléments de travail            |       | ✓       | ✓              | ✓                                      |
| Ajouter/supprimer des contacts d'éléments de travail      |       | ✓       | ✓              | ✓                                      |
| Créer/modifier des contacts/entreprises |       |         |                | ✓                                      |

## Activer la gestion des relations client (CRM) {#enable-customer-relations-management-crm}

Les fonctionnalités de gestion des relations client sont activées pour un groupe. Pour utiliser les fonctionnalités CRM dans un sous-groupe, vous devez également les activer pour le sous-groupe.

Pour activer la gestion des relations client dans un groupe ou un sous-groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre sous-groupe.
1. Sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sélectionnez **La relation client est activée**.
1. Sélectionnez **Enregistrer les modifications**.

## Configurer la source de contacts {#configure-the-contact-source}

{{< history >}}

- [Disponible](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/167475) dans GitLab 17.6.

{{< /history >}}

Par défaut, les contacts proviennent du groupe principal de l'élément de travail.

La source de contacts d'un groupe s'applique à tous les sous-groupes, sauf si ceux-ci ont une source de contacts configurée.

Pour configurer la source de contacts pour un groupe ou un sous-groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre sous-groupe.
1. Sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sélectionnez **Source du contact** > **Rechercher un groupe**.
1. Sélectionnez le groupe à partir duquel vous souhaitez sourcer les contacts.
1. Sélectionnez **Enregistrer les modifications**.

## Contacts {#contacts}

### Voir les contacts associés à un groupe {#view-contacts-linked-to-a-group}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour voir les contacts d'un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.

### Créer un contact {#create-a-contact}

Prérequis :

- Vous devez disposer du rôle Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour créer un contact :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. Sélectionnez **Nouveau contact**.
1. Remplissez tous les champs obligatoires.
1. Sélectionnez **Créer un nouveau contact**.

Vous pouvez également [créer](../../api/graphql/reference/_index.md#mutationcustomerrelationscontactcreate) des contacts à l'aide de l'API GraphQL.

### Modifier un contact {#edit-a-contact}

Prérequis :

- Vous devez disposer du rôle Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour modifier un contact existant :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. À côté du contact que vous souhaitez modifier, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Modifiez les champs requis.
1. Sélectionnez **Enregistrer les modifications**.

Vous pouvez également [modifier](../../api/graphql/reference/_index.md#mutationcustomerrelationscontactupdate) des contacts à l'aide de l'API GraphQL.

#### Modifier l'état d'un contact {#change-the-state-of-a-contact}

Chaque contact peut se trouver dans l'un des deux états suivants :

- **Actif** : les contacts dans cet état peuvent être ajoutés à un élément de travail.
- **Inactif** : les contacts dans cet état ne peuvent pas être ajoutés à un élément de travail.

Pour modifier l'état d'un contact :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. À côté du contact que vous souhaitez modifier, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Cochez ou décochez la case **Actif**.
1. Sélectionnez **Enregistrer les modifications**.

## Entreprises {#organizations}

### Voir les entreprises {#view-organizations}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour voir les entreprises d'un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. En haut à droite, sélectionnez **Organisations**.

### Créer une entreprise {#create-an-organization}

Prérequis :

- Vous devez disposer du rôle Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour créer une entreprise :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. En haut à droite, sélectionnez **Organisations**.
1. Sélectionnez **Nouvelle organisation**.
1. Remplissez tous les champs obligatoires.
1. Sélectionnez **Créer une nouvelle organisation**.

Vous pouvez également [créer](../../api/graphql/reference/_index.md#mutationcustomerrelationsorganizationcreate) des entreprises à l'aide de l'API GraphQL.

### Modifier une entreprise {#edit-an-organization}

Prérequis :

- Vous devez disposer du rôle Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour modifier une entreprise existante :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. En haut à droite, sélectionnez **Organisations**.
1. À côté de l'entreprise que vous souhaitez modifier, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Modifiez les champs requis.
1. Sélectionnez **Enregistrer les modifications**.

Vous pouvez également [modifier](../../api/graphql/reference/_index.md#mutationcustomerrelationsorganizationupdate) des entreprises à l'aide de l'API GraphQL.

## Tickets {#tickets}

Si vous utilisez [Service Desk](../project/service_desk/_index.md) et créez des tickets à partir d'e-mails, les tickets sont associés aux contacts correspondant aux adresses e-mail de l'expéditeur et des destinataires en copie (CC) de l'e-mail.

### Voir les éléments de travail associés à un contact {#view-work-items-linked-to-a-contact}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour voir les éléments de travail d'un contact, sélectionnez un contact dans la barre latérale de l'élément de travail, ou :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. À côté du contact dont vous souhaitez voir les éléments de travail, sélectionnez **Voir les éléments de travail** ({{< icon name="work-items" >}}).

### Voir les éléments de travail associés à une entreprise {#view-work-items-linked-to-an-organization}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour voir les éléments de travail d'une entreprise :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Forfait** > **Relation Client**.
1. En haut à droite, sélectionnez **Organisations**.
1. À côté de l'entreprise dont vous souhaitez voir les éléments de travail, sélectionnez **Voir les éléments de travail** ({{< icon name="work-items" >}}).

### Voir les contacts associés à un élément de travail {#view-contacts-linked-to-a-work-item}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Vous pouvez consulter les contacts associés à un élément de travail dans la barre latérale droite.

Pour voir les détails d'un contact, survolez le nom du contact.

Vous pouvez également consulter les contacts des éléments de travail à l'aide de l'API [GraphQL](../../api/graphql/reference/_index.md#mutationcustomerrelationsorganizationcreate).

### Ajouter des contacts à un élément de travail {#add-contacts-to-a-work-item}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour ajouter des contacts [actifs](#change-the-state-of-a-contact) à un élément de travail, utilisez la [commande rapide `/add_contacts`](../project/quick_actions.md#add_contacts) avec `[contact:address@example.com]`.

Vous pouvez également ajouter, supprimer ou remplacer des contacts d'éléments de travail à l'aide de l'API [GraphQL](../../api/graphql/reference/_index.md#mutationissuesetcrmcontacts).

### Supprimer des contacts d'un élément de travail {#remove-contacts-from-a-work-item}

Prérequis :

- Vous devez disposer du rôle Planificateur, Reporter, Développeur, Mainteneur ou Propriétaire pour le groupe.

Pour supprimer des contacts d'un élément de travail, utilisez la [commande rapide `/remove_contacts`](../project/quick_actions.md#remove_contacts) avec `[contact:address@example.com]`.

Vous pouvez également ajouter, supprimer ou remplacer des contacts d'éléments de travail à l'aide de l'API [GraphQL](../../api/graphql/reference/_index.md#mutationissuesetcrmcontacts).

## Autocomplétion des contacts {#autocomplete-contacts}

Lorsque vous utilisez la commande rapide `/add_contacts`, faites-la suivre de `[contact:` et une liste d'autocomplétion avec les contacts [actifs](#change-the-state-of-a-contact) s'affiche :

```plaintext
/add_contacts [contact:
```

Lorsque vous utilisez la commande rapide `/remove_contacts`, faites-la suivre de `[contact:` et une liste d'autocomplétion avec les contacts ajoutés à l'élément de travail s'affiche :

```plaintext
/remove_contacts [contact:
```

## Déplacement d'objets avec des entrées CRM {#moving-objects-with-crm-entries}

Lorsque vous déplacez un élément de travail ou un projet, le résultat dépend de la source de contacts du groupe parent :

- Si la source correspond, les éléments de travail conservent leurs contacts.
- Si la source change, les éléments de travail perdent leurs contacts.

Lorsque vous déplacez un groupe avec une [source de contacts configurée](#configure-the-contact-source) ou que sa source de contacts reste inchangée, les éléments de travail conservent leurs contacts.

Lorsque vous déplacez un groupe et que sa source de contacts change :

- Tous les contacts et entreprises uniques sont migrés vers le nouveau groupe principal.
- Les contacts qui existent déjà (par adresse e-mail) sont considérés comme des doublons et supprimés.
- Les entreprises qui existent déjà (par nom) sont considérées comme des doublons et supprimées.
- Tous les éléments de travail conservent leurs contacts ou sont mis à jour pour pointer vers des contacts ayant la même adresse e-mail.

Si vous n'avez pas l'autorisation de créer des contacts et des entreprises dans le nouveau groupe principal, le transfert de groupe échoue.
