---
stage: Software Supply Chain Security
group: Authentication
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Utilisateurs et utilisatrices professionnels
description: "Gérer les utilisateurs et utilisatrices de l'organisation via la vérification des domaines et des contrôles professionnels centralisés."
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

Les utilisateurs et utilisatrices professionnels sont similaires aux utilisateurs et utilisatrices GitLab standard, mais sont administrés par une organisation. Chaque utilisateur ou utilisatrice professionnel(le) est revendiqué(e) et géré(e) par un groupe principal spécifique. Pour revendiquer des utilisateurs et utilisatrices professionnels, vous devez vérifier un domaine de groupe et disposer d'un [abonnement](../../subscriptions/_index.md) actif.

Si l'abonnement expire ou est annulé :

- Tous les utilisateurs et utilisatrices professionnels existants restent des utilisateurs et utilisatrices professionnels dans le groupe.
- Les propriétaires de groupe ne peuvent pas gérer leurs utilisateurs et utilisatrices professionnels.
- Les adresses e-mail principales des comptes utilisateurs doivent provenir d'un domaine vérifié.
- Les nouveaux utilisateurs et nouvelles utilisatrices professionnels ne peuvent pas être associés au groupe tant qu'un abonnement n'est pas renouvelé.

## Gérer les domaines de groupe {#manage-group-domains}

Pour revendiquer des utilisateurs et utilisatrices GitLab.com en tant qu'utilisateurs et utilisatrices professionnels, vous devez ajouter et vérifier la propriété d'un domaine. Les domaines de groupe sont ajoutés au groupe principal et s'appliquent à tous les sous-groupes et projets du groupe.

Bien que chaque groupe puisse avoir plusieurs domaines, vous ne pouvez associer chaque domaine qu'à un seul groupe à la fois. Si vous déplacez votre domaine vers un autre groupe payant, tous les utilisateurs et utilisatrices professionnels sont automatiquement revendiqués par le nouveau groupe.

Les domaines de groupe sont liés à un projet de votre groupe principal. Le projet lié doit avoir [GitLab Pages](../project/pages/_index.md) activé pour vérifier le domaine, mais n'a pas besoin de créer ni de déployer un site web GitLab Pages. Sur GitLab.com, GitLab Pages est activé par défaut pour tous les projets, aucune configuration n'est donc requise.

Même si le domaine est lié à un projet, il est disponible pour l'ensemble de la hiérarchie du groupe, y compris tous les sous-groupes et projets imbriqués. Les membres du projet lié disposant [du rôle Maintainer ou Owner](../permissions.md#project-permissions) peuvent modifier ou supprimer le domaine. Si ce projet est supprimé, vos domaines associés sont également supprimés.

Pour plus d'informations sur les domaines de groupe, consultez [l'epic 5299](https://gitlab.com/groups/gitlab-org/-/epics/5299).

### Ajouter des domaines de groupe {#add-group-domains}

Prérequis :

- Vous devez disposer du rôle Owner pour un groupe principal.
- Vous devez contrôler un domaine personnalisé `example.com` ou un sous-domaine `subdomain.example.com` correspondant au domaine de messagerie que vous souhaitez vérifier.
- Vous devez être en mesure de créer des enregistrements DNS `TXT` pour votre domaine afin de prouver votre propriété.
- Vous devez disposer d'un projet dédié dans le groupe principal qui utilise [GitLab Pages](../project/pages/_index.md).

Pour ajouter un domaine personnalisé pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Vérification des domaines**.
1. Dans le coin supérieur droit, sélectionnez **Ajouter un domaine**.
1. Configurez les paramètres du domaine :
   - **Domaine** : saisissez le nom de domaine.
   - **Projet** : créez un lien vers un projet existant dans le groupe.
   - **Certificat** : sélectionnez une option de certificat :
     - Si vous ne disposez pas d'un certificat SSL/TLS ou si vous ne souhaitez pas en utiliser un, sélectionnez **Gestion automatique des certificats à l'aide de Let's Encrypt**.
     - Si vous souhaitez fournir votre propre certificat SSL/TLS, sélectionnez **Entrer manuellement les informations du certificat**.

       > [!note]
       > Un certificat valide n'est pas requis pour la vérification du domaine. Vous pouvez ignorer les avertissements relatifs aux certificats auto-signés si vous n'utilisez pas GitLab Pages.

1. Sélectionnez **Ajouter un domaine**. GitLab enregistre les informations du domaine.
1. Vérifiez la propriété du domaine :
   1. Dans **TXT**, copiez le code de vérification.
   1. Dans les paramètres DNS de votre fournisseur de domaine, ajoutez le code de vérification en tant qu'enregistrement `TXT`.
   1. Dans GitLab, dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez votre groupe.
   1. Sélectionnez **Paramètres** > **Vérification des domaines**.
   1. À côté du nom de domaine, sélectionnez **Relancer la vérification** ({{< icon name="retry" >}}).

Après une vérification réussie, le statut du domaine passe à **Vérifié** et peut être utilisé pour la gestion des utilisateurs et utilisatrices professionnels.

> [!note]
> En général, la propagation DNS se termine en quelques minutes, mais peut prendre jusqu'à 24 heures. Tant qu'elle n'est pas terminée, le domaine reste non vérifié dans GitLab.
>
> Si le domaine est toujours non vérifié après sept jours, GitLab supprime automatiquement le domaine.
>
> Après la vérification, GitLab revérifie périodiquement le domaine. Pour éviter tout problème potentiel, maintenez l'enregistrement `TXT` sur votre fournisseur de domaine.

### Afficher les domaines de groupe {#view-group-domains}

Pour afficher tous les domaines personnalisés d'un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Vérification des domaines**.

### Modifier les domaines de groupe {#edit-group-domains}

Pour modifier un domaine personnalisé pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Vérification des domaines**.
1. À côté du nom de domaine, sélectionnez **Modifier** ({{< icon name="pencil" >}}).

Depuis cet écran, vous pouvez :

- Afficher le domaine personnalisé.
- Afficher l'enregistrement DNS à ajouter.
- Afficher l'entrée de vérification TXT.
- Relancer la vérification.
- Modifier les paramètres du certificat.

### Supprimer des domaines de groupe {#delete-group-domains}

La suppression d'un domaine de groupe peut avoir un impact sur les utilisateurs et utilisatrices professionnels de votre groupe. Après avoir supprimé le domaine :

- Tous les utilisateurs et utilisatrices professionnels existants restent des utilisateurs et utilisatrices professionnels dans le groupe.
- Les nouveaux utilisateurs et nouvelles utilisatrices professionnels ne peuvent pas être associés au groupe tant qu'un autre domaine n'est pas vérifié.

Pour supprimer un domaine personnalisé pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Vérification des domaines**.
1. À côté du nom de domaine, sélectionnez **Supprimer le domaine** ({{< icon name="remove" >}}).
1. Lorsque vous y êtes invité, sélectionnez **Supprimer le domaine**.

## Gérer les utilisateurs et utilisatrices professionnels {#manage-enterprise-users}

En plus des [autorisations standard des membres de groupe](../permissions.md#group-permissions), les propriétaires d'un groupe principal peuvent également gérer les utilisateurs et utilisatrices professionnels dans leur groupe.

Vous pouvez également [utiliser l'API](../../api/group_enterprise_users.md) pour interagir avec les utilisateurs et utilisatrices professionnels.

### Revendications automatiques d'utilisateurs et utilisatrices professionnels {#automatic-claims-of-enterprise-users}

Prérequis :

- Le groupe principal doit [ajouter et vérifier un domaine de groupe](#add-group-domains).
- L'adresse e-mail principale de l'utilisateur ou de l'utilisatrice doit correspondre au domaine vérifié.
- Le compte utilisateur doit remplir au moins l'une des conditions suivantes :
  - Le compte utilisateur a été créé le 1er février 2021 ou après cette date.
  - Le compte utilisateur possède une identité SAML ou SCIM associée au groupe de l'organisation.
  - Le compte utilisateur possède un attribut `provisioned_by_group_id` correspondant à l'ID du groupe.
  - Le compte utilisateur est déjà membre de l'abonnement de groupe acheté ou renouvelé le 1er février 2021 ou après cette date.

Après qu'un groupe a vérifié la propriété d'un domaine, les utilisateurs et utilisatrices disposant d'une adresse e-mail de ce domaine sont automatiquement revendiqués par le groupe en tant qu'utilisateurs et utilisatrices professionnels. Aucune action directe n'est requise de la part des propriétaires de groupe.

Tous les membres de groupe existants disposant d'une adresse e-mail d'un domaine différent conservent leur accès existant, mais ne peuvent pas être gérés par les propriétaires de groupe. Pour revendiquer ces utilisateurs et utilisatrices, ils et elles doivent mettre à jour leur adresse e-mail principale pour qu'elle corresponde à votre domaine de groupe.

Le processus de revendication peut prendre jusqu'à quatre jours avant de se déclencher. Vous pouvez immédiatement lancer ce processus en [revérifiant manuellement le domaine de groupe](#edit-group-domains).

Après qu'un groupe revendique un utilisateur ou une utilisatrice professionnelle :

- L'utilisateur ou l'utilisatrice reçoit un [e-mail de bienvenue](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/app/views/notify/user_associated_with_enterprise_group_email.html.haml).
- L'ID du groupe est ajouté à l'attribut `enterprise_group_id` de l'utilisateur ou de l'utilisatrice.

### Identification des utilisateurs et utilisatrices professionnels {#identifying-enterprise-users}

Vous pouvez identifier les utilisateurs et utilisatrices professionnels depuis la [liste des membres](../group/_index.md#filter-and-sort-members-in-a-group). Tous les utilisateurs et utilisatrices professionnels ont un badge `Enterprise` à côté de leur nom.

Vous pouvez découvrir les membres de groupe non professionnels en analysant la liste des utilisateurs et utilisatrices facturables à l'adresse : `https://gitlab.com/groups/<group_id>/-/usage_quotas#seats-quota-tab`.

Dans cette liste, les utilisateurs et utilisatrices non professionnels ont l'un des éléments suivants :

- Une adresse e-mail provenant d'un domaine non vérifié.
- Aucune adresse e-mail visible.

### Restreindre les méthodes d'authentification {#restrict-authentication-methods}

Vous pouvez restreindre les méthodes d'authentification spécifiques disponibles pour les utilisateurs et utilisatrices professionnels, ce qui peut contribuer à réduire l'empreinte de sécurité de vos utilisateurs et utilisatrices.

- [Désactiver l'authentification par mot de passe](../group/saml_sso/_index.md#disable-password-and-passkey-authentication-for-enterprise-users).
- [Désactiver les jetons d'accès personnels](../profile/personal_access_tokens.md#disable-personal-access-tokens-for-enterprise-users).
- [Désactiver les clés SSH](../ssh_advanced.md#disable-ssh-keys-for-enterprise-users).
- [Désactiver l'authentification à deux facteurs](../../security/two_factor_authentication.md#enterprise-users).

### Restreindre les extraits de code personnels {#restrict-personal-snippets}

Vous pouvez empêcher les utilisateurs et utilisatrices professionnels de créer des [extraits de code personnels](../snippets.md) dans leur espace de nommage personnel. Pour plus d'informations, consultez [Restreindre les extraits de code personnels pour les utilisateurs et utilisatrices professionnels](../group/manage.md#restrict-personal-snippets-for-enterprise-users).

### Restreindre la création de groupes et de projets {#restrict-group-and-project-creation}

Vous pouvez restreindre la création de groupes et de projets pour les utilisateurs et utilisatrices professionnels, ce qui vous aide à définir :

- Si les utilisateurs et utilisatrices professionnels peuvent créer des groupes principaux.
- Le nombre maximum de projets personnels que chaque utilisateur ou utilisatrice professionnelle peut créer.

Ces restrictions sont définies dans la réponse SAML. Pour plus d'informations, consultez [configurer les paramètres des utilisateurs et utilisatrices professionnels depuis la réponse SAML](../group/saml_sso/_index.md#configure-enterprise-user-settings-from-saml-response).

### Contourner la confirmation par e-mail pour les utilisateurs et utilisatrices provisionnés {#bypass-email-confirmation-for-provisioned-users}

Par défaut, les utilisateurs et utilisatrices provisionnés avec SAML ou SCIM reçoivent un e-mail de vérification pour confirmer leur identité. Vous pouvez à la place configurer GitLab avec un domaine personnalisé et GitLab confirme automatiquement les comptes utilisateurs. Les utilisateurs et utilisatrices reçoivent tout de même un e-mail de bienvenue pour les utilisateurs et utilisatrices professionnels.

Pour plus d'informations, consultez [contourner la confirmation par e-mail des utilisateurs et utilisatrices avec des domaines vérifiés](../group/saml_sso/_index.md#bypass-user-email-confirmation-with-verified-domains).

### Afficher les adresses e-mail d'un utilisateur ou d'une utilisatrice professionnelle {#view-the-email-addresses-for-an-enterprise-user}

Prérequis :

- Vous devez disposer du rôle Owner pour un groupe principal.

Pour afficher l'adresse e-mail d'un utilisateur ou d'une utilisatrice professionnelle :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Survolez le nom de l'utilisateur ou de l'utilisatrice professionnelle.

Vous pouvez également utiliser l'[API des membres de groupe](../../api/group_members.md) et l'[API des membres de projet](../../api/project_members.md) pour accéder aux informations des utilisateurs et utilisatrices. Pour les utilisateurs et utilisatrices professionnels du groupe, ces informations incluent les adresses e-mail des utilisateurs et utilisatrices.

### Modifier les adresses e-mail d'un utilisateur ou d'une utilisatrice professionnelle {#change-the-email-addresses-for-an-enterprise-user}

Les utilisateurs et utilisatrices professionnels peuvent suivre le même processus que les autres utilisateurs et utilisatrices GitLab pour [modifier leur adresse e-mail principale](../profile/_index.md#change-your-primary-email). La nouvelle adresse e-mail doit provenir d'un domaine vérifié. Si votre organisation ne possède aucun domaine vérifié, vos utilisateurs et utilisatrices professionnels ne peuvent pas modifier leur adresse e-mail principale.

Les propriétaires de groupe peuvent modifier l'adresse e-mail des utilisateurs et utilisatrices professionnels de leur groupe via l'[API des utilisateurs et utilisatrices professionnels de groupe](../../api/group_enterprise_users.md#update-an-enterprise-user).

Seul le support GitLab peut modifier l'adresse e-mail principale pour la remplacer par une adresse e-mail provenant d'un domaine non vérifié. Cette action [libère l'utilisateur ou l'utilisatrice professionnelle](#release-an-enterprise-user).

### Supprimer un utilisateur ou une utilisatrice professionnelle {#delete-an-enterprise-user}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe principal.

Vous pouvez utiliser l'[API des utilisateurs et utilisatrices professionnels de groupe](../../api/group_enterprise_users.md#delete-an-enterprise-user) pour supprimer un utilisateur ou une utilisatrice professionnelle et retirer définitivement le compte de GitLab. Cette action est différente de la libération de l'utilisateur ou de l'utilisatrice, qui supprime uniquement les fonctionnalités de gestion professionnelle du compte. Lorsque vous supprimez l'utilisateur ou l'utilisatrice, vous pouvez choisir de :

- Supprimer définitivement l'utilisateur ou l'utilisatrice et ses [contributions](../profile/account/delete_account.md#associated-records).
- Conserver ses contributions et les transférer vers un utilisateur fantôme.

### Libérer un utilisateur ou une utilisatrice professionnelle {#release-an-enterprise-user}

Vous pouvez supprimer les fonctionnalités de gestion professionnelle des comptes d'utilisateurs et utilisatrices professionnels. Vous pourriez avoir besoin de le faire si, par exemple, un utilisateur ou une utilisatrice souhaite conserver son compte GitLab après avoir quitté son entreprise. Lorsque vous libérez un utilisateur ou une utilisatrice, les rôles et autorisations de son compte restent inchangés, mais le propriétaire du groupe perd les options de gestion pour cet utilisateur ou cette utilisatrice. Par exemple, l'utilisateur ou l'utilisatrice libéré(e) peut accéder aux méthodes d'authentification que le propriétaire du groupe avait précédemment désactivées.

Si vous devez supprimer définitivement le compte, [supprimez l'utilisateur ou l'utilisatrice](#delete-an-enterprise-user) à la place.

Pour libérer un utilisateur ou une utilisatrice professionnelle individuel(le) de votre groupe, le support GitLab doit mettre à jour l'adresse e-mail principale de l'utilisateur ou de l'utilisatrice pour la remplacer par une adresse e-mail provenant d'un domaine non vérifié. Cette action libère automatiquement le compte.

Pour libérer tous les utilisateurs et utilisatrices professionnels revendiqués, vous pouvez [supprimer le groupe](../group/_index.md#schedule-a-group-for-deletion) lui-même plutôt que le domaine de groupe. Cela est utile pour les organisations qui testent la fonctionnalité des utilisateurs et utilisatrices professionnels.

La possibilité pour les propriétaires de groupe de modifier les adresses e-mail principales est proposée dans le [ticket 412966](https://gitlab.com/gitlab-org/gitlab/-/issues/412966).

### Réactivation des utilisateurs et utilisatrices professionnels inactifs {#dormant-enterprise-user-reactivation}

Lorsque la [suppression automatique des membres inactifs](../group/moderate_users.md#automatically-remove-dormant-members) est active, les utilisateurs et utilisatrices professionnels inactifs sont désactivés au lieu d'être supprimés du groupe. Lorsque ces utilisateurs et utilisatrices se reconnectent, leurs comptes sont réactivés.

Cependant, lorsque l'[accès restreint](../../subscriptions/manage_seats.md#restricted-access) est actif sur le groupe professionnel et qu'aucun siège n'est disponible, l'utilisateur ou l'utilisatrice est mis(e) en attente d'approbation au lieu d'être réactivé(e). Leurs appartenances aux groupes et projets existants sont préservées.

### Masquer les adresses e-mail des utilisateurs et utilisatrices professionnels {#hide-email-addresses-for-enterprise-users}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197475) dans GitLab 18.3.

{{< /history >}}

Les propriétaires de groupe peuvent masquer l'adresse e-mail publique des pages de profil pour tous les utilisateurs et utilisatrices professionnels de leur groupe. Les propriétaires peuvent toujours [afficher les adresses e-mail depuis la page des membres](#view-the-email-addresses-for-an-enterprise-user).

Prérequis :

- Vous devez disposer du rôle Owner pour un groupe principal.
- Le groupe doit avoir la [vérification des domaines](#manage-group-domains) configurée.

Pour masquer les adresses e-mail des utilisateurs et utilisatrices professionnels :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Général**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sous **Utilisateurs et utilisatrices professionnels**, cochez la case **Rendre l'adresse email invisible aux profils publics**.
1. Sélectionnez **Enregistrer les modifications**.

### Empêcher les utilisateurs et utilisatrices professionnels de supprimer leur propre compte {#prevent-enterprise-users-from-deleting-their-own-account}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/241926) dans GitLab 19.2 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `deleting_account_disabled_for_enterprise_users`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248605) dans GitLab 19.4. Le feature flag `deleting_account_disabled_for_enterprise_users` a été supprimé.

{{< /history >}}

Les propriétaires de groupe peuvent empêcher les utilisateurs et utilisatrices professionnels de leur groupe de supprimer leurs propres comptes. Lorsque ce paramètre est désactivé, les utilisateurs et utilisatrices professionnels ne peuvent pas supprimer leur compte depuis leurs paramètres utilisateur. La section de suppression de compte affiche un message indiquant que la suppression de compte n'est pas autorisée. Les propriétaires de groupe peuvent toujours [supprimer un utilisateur ou une utilisatrice professionnelle](#delete-an-enterprise-user).

Prérequis :

- Le rôle Owner pour un groupe principal.
- Le groupe doit avoir la [vérification des domaines](#manage-group-domains) configurée.

Pour empêcher les utilisateurs et utilisatrices professionnels de supprimer leur propre compte :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Général**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sous **Utilisateurs et utilisatrices professionnels**, décochez la case **Permettre aux utilisateurs et utilisatrices professionnels de supprimer leurs propres comptes**.
1. Sélectionnez **Enregistrer les modifications**.

### Activer l'Extension Marketplace pour les utilisateurs et utilisatrices professionnels {#enable-the-extension-marketplace-for-enterprise-users}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/161819) en version [bêta](../../policy/development_stages_support.md#beta) dans GitLab 17.4 [avec des feature flags](../../administration/feature_flags/_index.md) nommés `web_ide_oauth` et `web_ide_extensions_marketplace`. Fonctionnalité désactivée par défaut.
- `web_ide_oauth` [activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/163181) dans GitLab 17.4.
- `web_ide_extensions_marketplace` [activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/459028) dans GitLab 17.4.
- `web_ide_oauth` [supprimé](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/167464) dans GitLab 17.5.
- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/508996) du [feature flag](../../administration/feature_flags/_index.md) `vscode_extension_marketplace_settings` dans GitLab 17.10. Fonctionnalité désactivée par défaut.
- `web_ide_extensions_marketplace` [activé sur GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/184662), et `vscode_extension_marketplace_settings` [activé sur GitLab.com et GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/184662) dans GitLab 17.11.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/192659) dans GitLab 18.1. Les feature flags `web_ide_extensions_marketplace` et `vscode_extension_marketplace_settings` ont été supprimés.

{{< /history >}}

L'Extension Marketplace VS Code donne accès à des extensions qui améliorent les fonctionnalités du Web IDE et des workspaces. Les propriétaires de groupe principal peuvent contrôler l'accès à la marketplace pour les utilisateurs et utilisatrices professionnels de leur groupe.

Prérequis :

- Vous devez disposer du rôle Owner pour un groupe principal.

Pour activer l'Extension Marketplace pour les utilisateurs et utilisatrices professionnels :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Général**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sous **Utilisateurs et utilisatrices professionnels**, cochez la case **Activer la marketplace d'extensions**.
1. Sélectionnez **Enregistrer les modifications**.

## Dépannage {#troubleshooting}

### Impossible de désactiver l'authentification à deux facteurs pour un utilisateur ou une utilisatrice professionnelle {#cannot-disable-two-factor-authentication-for-an-enterprise-user}

Si un utilisateur ou une utilisatrice ne possède pas de badge **Enterprise**, un propriétaire de groupe ne peut pas désactiver ni réinitialiser la 2FA pour son compte. Le propriétaire doit plutôt indiquer à l'utilisateur ou à l'utilisatrice professionnelle de consulter les [options de récupération](../profile/account/two_factor_authentication_troubleshooting.md#recovery-options-and-2fa-reset) disponibles.

## Sujets connexes {#related-topics}

- [Domaines personnalisés GitLab Pages](../project/pages/custom_domains_ssl_tls_certification/_index.md).
