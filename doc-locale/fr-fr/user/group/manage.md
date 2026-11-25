---
stage: Tenant Scale
group: Organizations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Gérer les groupes
---

Utilisez des groupes pour gérer un ou plusieurs projets liés en même temps.

> [!note]
> Sur GitLab Self-Managed, si vous souhaitez voir une vue d'ensemble de votre organisation entière, vous devez créer un groupe principal. Pour plus d'informations sur les efforts visant à créer une vue organisationnelle de tous les groupes, [voir l'epic 9266](https://gitlab.com/groups/gitlab-org/-/work_items/9266). Un groupe principal offre des informations sur l'ensemble de votre organisation grâce à un [tableau de bord et centre de sécurité](../application_security/security_dashboard/_index.md) complet, un [rapport de vulnérabilités](../application_security/vulnerability_report/_index.md), un [centre de conformité](../compliance/compliance_center/_index.md) et des [analyses de flux de valeur](value_stream_analytics/_index.md).

## Ajouter un README de groupe {#add-a-group-readme}

Vous pouvez ajouter un fichier README pour fournir des informations sur votre équipe et inviter des utilisateurs à contribuer à vos projets. Le README s'affiche sur la page de présentation du groupe. Tous les membres du groupe peuvent consulter et modifier le README.

Prérequis :

- Pour créer le README depuis les paramètres du groupe, vous devez disposer du rôle Propriétaire pour le groupe.

Pour ajouter un README de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Dans la section **README du groupe**, sélectionnez **Ajouter un README**. Cette action crée un nouveau projet `gitlab-profile` qui contient le fichier `README.md`.
1. Dans l'invite de création d'un README, sélectionnez **Créer et ajouter un README**. Vous êtes redirigé vers le Web IDE, où un fichier README est créé.
1. Dans le Web IDE, modifiez et commitez le fichier `README.md`.

## Changer le propriétaire d'un groupe {#change-the-owner-of-a-group}

Vous pouvez changer le propriétaire d'un groupe. Chaque groupe doit toujours avoir au moins un membre humain avec le rôle Propriétaire. Les utilisateurs internes (« bots ») et les comptes de service ne peuvent pas être les seuls propriétaires d'un groupe.

- En tant qu'administrateur :
  1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
  1. Sélectionnez **Gérer** > **Membres**.
  1. Attribuez le rôle Propriétaire à un autre membre.
  1. Actualisez la page. Vous pouvez maintenant retirer le rôle Propriétaire au propriétaire d'origine.
- En tant que propriétaire actuel du groupe :
  1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
  1. Sélectionnez **Gérer** > **Membres**.
  1. Attribuez le rôle Propriétaire à un autre membre.
  1. Demandez au nouveau propriétaire de se connecter et de vous retirer le rôle Propriétaire.

## Modifier le chemin d'un groupe {#change-a-groups-path}

La modification du chemin d'un groupe (URL du groupe) peut avoir des effets secondaires imprévus. Lisez la description du comportement des redirections pour les [projets](../project/repository/_index.md#repository-path-changes) et dans l'[API](../../api/rest/_index.md#redirects) avant de continuer.

Si vous modifiez le chemin pour qu'il puisse être revendiqué par un autre groupe ou utilisateur, vous devez également renommer le groupe. Les noms et les chemins doivent être uniques.

Pour conserver la propriété de l'espace de nommage d'origine et protéger les redirections d'URL, créez un nouveau groupe et transférez-y les projets à la place.

Pour modifier le chemin de votre groupe (URL du groupe) :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Paramètres avancés**.
1. Sous **Modifier l'URL du groupe**, saisissez un nouveau nom.
1. Sélectionnez **Modifier l'URL du groupe**.

> [!warning]
> Il n'est pas possible de renommer un espace de nommage s'il contient un projet avec des tags du [registre de conteneurs](../packages/container_registry/_index.md), car le projet ne peut pas être déplacé.
>
> Pour vous assurer que les groupes comportant des milliers de sous-groupes sont traités correctement, vous devez tester la modification du chemin dans un environnement de test. Envisagez d'augmenter temporairement le [délai d'expiration du worker Puma](../../administration/operations/puma.md#change-the-worker-timeout). Pour plus d'informations sur notre solution visant à atténuer ce risque de délai d'expiration, consultez le [ticket 432065](https://gitlab.com/gitlab-org/gitlab/-/issues/432065).

## Modifier la protection de branche par défaut d'un groupe {#change-the-default-branch-protection-of-a-group}

L'administrateur d'une instance GitLab peut configurer des protections de branche par défaut pour [tous les projets d'une instance](../project/repository/branches/default.md#for-all-projects-in-an-instance). Les groupes de cette instance héritent de la protection de branche définie au niveau global. Les propriétaires de groupe peuvent [remplacer les paramètres de l'instance](../project/repository/branches/default.md#for-all-projects-in-a-group) pour les projets d'un groupe. Avec [GitLab Premium ou Ultimate](https://about.gitlab.com/pricing/), l'administrateur de l'instance peut désactiver ce privilège.

## Utiliser un nom personnalisé pour la branche initiale {#use-a-custom-name-for-the-initial-branch}

Lorsque vous créez un nouveau projet dans GitLab, une branche par défaut est créée lors du premier push. Le propriétaire du groupe peut [personnaliser la branche initiale](../project/repository/branches/default.md#change-the-default-branch-name-for-new-projects-in-a-group) pour les projets du groupe afin de répondre aux besoins de votre groupe.

## Archiver un groupe {#archive-a-group}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/epics/15019) dans GitLab 18.3 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `archive_group`. Fonctionnalité désactivée par défaut.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/526771) dans GitLab 18.9. Suppression du feature flag `archive_group`.

{{< /history >}}

Archivez un groupe et tous ses sous-groupes et projets. Une fois archivés, un groupe et son contenu deviennent en lecture seule, et les données du groupe sont conservées pour référence future.

De plus, les groupes archivés :

- Affichent un badge `Archived` sur la page du groupe
- Apparaissent dans l'onglet **Inactif** de la page **Votre travail** et de la page **Explorer**
- Ne peuvent pas être transférés vers un autre espace de nommage

### Limitations connues {#known-limitations}

Les tickets des groupes archivés continueront d'apparaître sur les tableaux des tickets jusqu'à ce que le [ticket 585677](https://gitlab.com/gitlab-org/gitlab/-/work_items/585677) soit résolu.

Prérequis :

- Vous devez être administrateur ou disposer du rôle Propriétaire pour le groupe.

Pour archiver un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Paramètres avancés**.
1. Dans la section **Archiver le groupe**, sélectionnez **Archiver**.

> [!note]
> L'archivage d'un groupe archive automatiquement tous ses sous-groupes et projets. Les sous-groupes ou projets individuels au sein d'un groupe archivé ne peuvent pas être désarchivés séparément.

Pour archiver un groupe directement depuis la vue liste **Votre travail** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Voir tous mes groupes**.
1. Dans l'onglet **Membre**, trouvez le groupe que vous souhaitez archiver et sélectionnez ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Archiver**.

Cette action est également disponible sur d'autres pages de liste.

### Désarchiver un groupe {#unarchive-a-group}

Désarchivez un groupe et tous ses sous-groupes et projets. Lorsque vous désarchivez un groupe :

- Les restrictions en lecture seule sont supprimées du groupe et de son contenu.
- Le groupe, ses sous-groupes et ses projets reviennent aux onglets **Actif** ou **Membre** dans les listes de groupes.

Prérequis :

- Vous devez être administrateur ou disposer du rôle Propriétaire pour le groupe.

Pour désarchiver un groupe :

1. Trouvez le groupe archivé.
   1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
   1. Sélectionnez **Voir tous mes groupes**.
   1. Dans l'onglet **Inactif**, sélectionnez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Sous **Paramètres avancés**, sélectionnez **Étendre**.
1. Dans la section **Désarchiver le groupe**, sélectionnez **Désarchiver**.

Pour désarchiver un groupe directement depuis la vue liste **Votre travail** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Voir tous mes groupes**.
1. Dans l'onglet **Inactif**, trouvez le groupe que vous souhaitez désarchiver et sélectionnez ({{< icon name="ellipsis_v" >}}).
1. Sélectionnez **Désarchiver**.

Cette action est également disponible sur d'autres pages de liste.

## Transférer un groupe {#transfer-a-group}

{{< history >}}

- Les transferts asynchrones pour les groupes [introduits](https://gitlab.com/gitlab-org/gitlab/-/work_items/594575) dans GitLab 18.11 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `groups_and_projects_async_transfer`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/250913) dans GitLab 19.4. Suppression du feature flag `groups_and_projects_async_transfer`.

{{< /history >}}

Transférez un groupe pour le déplacer d'un emplacement à un autre dans la même instance GitLab. Vous pouvez :

- Transférez un sous-groupe vers un groupe parent différent.
- Convertissez un groupe principal en sous-groupe.
- Convertissez un sous-groupe en groupe principal.

Prérequis :

- Le rôle Propriétaire pour les groupes source et de destination.
- Activez la création de sous-groupes dans le groupe de destination (le cas échéant).

> [!note]
> Vous ne pouvez pas transférer un groupe s'il est archivé ou en attente de suppression.

Pour transférer un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Paramètres avancés**.
1. Sélectionnez **Transférer le groupe**.
1. Dans la liste déroulante, sélectionnez le groupe.
1. Sélectionnez **Transférer le groupe**.

Après avoir confirmé le transfert :

- Le groupe est transféré de manière asynchrone.
- Un e-mail de confirmation est envoyé une fois le transfert terminé ou en cas d'échec.
- L'ancienne URL du groupe est redirigée vers la nouvelle URL du groupe. Actualisez la page pour voir la nouvelle URL du groupe. Pour les groupes volumineux, vous devez attendre que le transfert soit terminé avant de pouvoir voir le groupe dans l'espace de nommage de destination.

Après avoir transféré un groupe, assurez-vous de :

- Mettre à jour les remotes des dépôts locaux vers les nouvelles URL.
- Vérifier les accès et permissions des membres du groupe.
- Mettre à jour les configurations de packages si nécessaire.
- Tester les pipelines CI/CD et les intégrations.

Si vous devez copier un groupe vers une autre instance GitLab, [migrez le groupe par transfert direct](import/_index.md).

### Données transférées {#what-data-gets-transferred}

Un transfert de groupe comprend :

- Tous les sous-groupes et projets du groupe
- Les appartenances et rôles explicites du groupe
- Les paramètres et configurations du groupe

### Problèmes connus {#known-issues}

Lors du transfert d'un groupe, gardez à l'esprit les restrictions suivantes.

Restrictions d'appartenance :

- Les appartenances héritées sont perdues. Seuls les membres directs du groupe sont transférés.
- Si un propriétaire de groupe dispose d'une appartenance héritée, l'utilisateur qui effectue le transfert du groupe devient le nouveau propriétaire.

Restrictions de visibilité et d'accès :

- Si un groupe parent de destination a une visibilité moindre, les paramètres de visibilité de tous les sous-groupes et projets sont ajustés pour correspondre à la visibilité du groupe parent de destination.
- Les URL des dépôts changent. Vous devez mettre à jour vos dépôts locaux pour qu'ils pointent vers le nouvel emplacement. Pour plus d'informations, consultez [Modifications de la page du dépôt](../project/repository/_index.md#repository-path-changes).

Restrictions relatives aux packages et au registre de conteneurs :

- Les transferts échouent si le groupe de destination est un groupe principal dans lequel des packages npm conformes à la [convention de nommage npm](../packages/npm_registry/_index.md#naming-convention) existent dans l'un des projets du groupe ou dans l'un de ses sous-groupes.
- Les packages existants qui utilisent un point de terminaison de groupe doivent être mis à jour selon les étapes du package pour la configuration du point de terminaison au niveau du groupe.
- Les noms de packages existants doivent être mis à jour si le package utilise un point de terminaison au niveau de l'instance et que le groupe a été déplacé vers un autre groupe principal.

Restrictions d'abonnement :

- Les groupes principaux disposant d'un abonnement sur GitLab.com ne peuvent pas être transférés. Pour rendre le transfert possible, l'abonnement du groupe principal doit d'abord être supprimé. Ensuite, le groupe principal peut être transféré en tant que sous-groupe vers un autre groupe principal.

Restrictions du gestionnaire de secrets :

> [!warning]
> Tous les secrets dans GitLab Secrets Manager pour le groupe, ses sous-groupes et ses projets sont [définitivement supprimés lors du transfert](../../ci/secrets/secrets_manager/_index.md#transfer-of-a-project-or-group).

## Désactiver les notifications par e-mail {#disable-email-notifications}

Vous pouvez désactiver toutes les notifications par e-mail liées au groupe, y compris ses sous-groupes et projets.

Pour désactiver les notifications par e-mail :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Décochez la case **Activer les notifications par courriel**.

### Désactiver les aperçus diff dans les notifications par e-mail {#disable-diff-previews-in-email-notifications}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/24733) dans GitLab 15.6 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `diff_preview_in_email`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/issues/382055) dans GitLab 17.1. Suppression du feature flag `diff_preview_in_email`.

{{< /history >}}

Lorsque vous commentez du code dans une merge request, GitLab inclut quelques lignes du diff dans la notification par e-mail envoyée aux participants. Certaines politiques organisationnelles considèrent l'e-mail comme un système moins sécurisé, ou peuvent ne pas contrôler leur propre infrastructure d'e-mail. Cela peut présenter des risques pour la propriété intellectuelle ou le contrôle d'accès au code source.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour désactiver les aperçus diff pour tous les projets d'un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Décochez **Inclure les aperçus diff**.
1. Sélectionnez **Enregistrer les modifications**.

## E-mails d'expiration pour les jetons d'accès aux groupes et projets {#expiry-emails-for-group-and-project-access-tokens}

{{< history >}}

- Les notifications aux membres hérités du groupe [introduites](https://gitlab.com/gitlab-org/gitlab/-/issues/463016) dans GitLab 17.7 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `pat_expiry_inherited_members_notification`. Fonctionnalité désactivée par défaut.
- Feature flag `pat_expiry_inherited_members_notification` [activé par défaut dans GitLab 17.10](https://gitlab.com/gitlab-org/gitlab/-/issues/393772).
- Feature flag `pat_expiry_inherited_members_notification` supprimé dans GitLab `17.11`

{{< /history >}}

Les membres de groupe et de projet suivants reçoivent des e-mails de notification concernant les jetons d'accès arrivant bientôt à expiration :

- Pour les jetons d'accès aux groupes :
  - Les membres disposant du rôle Propriétaire.
  - Dans GitLab 17.7 et versions ultérieures, les membres qui héritent du rôle Propriétaire pour le groupe, si ce groupe ou son groupe parent dispose du paramètre approprié configuré.
- Pour les jetons d'accès aux projets :
  - Les membres du projet disposant du rôle Mainteneur ou Propriétaire.
  - Dans GitLab 17.7 et versions ultérieures, les membres du projet ayant hérité du rôle Mainteneur ou Propriétaire en raison de l'appartenance du projet à un groupe, si ce groupe ou son groupe parent dispose du paramètre approprié configuré.

Vous pouvez activer les notifications pour les membres hérités d'un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sous **Il convient d'envoyer les courriels de notification d'expiration concernant les jetons d'accès groupe et projet de ce groupe à :**, sélectionnez **Tous les membres directs et hérités du groupe ou du projet**.
1. Facultatif. Cochez la case **Imposer à tous les sous-groupes**.
1. Sélectionnez **Enregistrer les modifications**.

Pour plus d'informations, consultez :

- Pour les groupes, la [documentation sur les jetons d'accès aux groupes](settings/group_access_tokens.md#group-access-token-expiry-emails).
- Pour les projets, la [documentation sur les jetons d'accès aux projets](../project/settings/project_access_tokens.md#project-access-token-expiry-emails).

## Ajouter des déclencheurs de webhook supplémentaires pour l'expiration des jetons d'accès aux groupes {#add-additional-webhook-triggers-for-group-access-token-expiration}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/499732) de déclencheurs à 60 et 30 jours pour les webhooks des jetons d'accès aux projets et aux groupes dans GitLab 17.9 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `extended_expiry_webhook_execution_setting`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/issues/513684) dans GitLab 17.10. Suppression du feature flag `extended_expiry_webhook_execution_setting`.

{{< /history >}}

GitLab envoie plusieurs [e-mails d'expiration](settings/group_access_tokens.md#group-access-token-expiry-emails) et déclenche un [webhook](../project/integrations/webhook_events.md#project-and-group-access-token-events) associé avant l'expiration d'un jeton de groupe. Par défaut, ces webhooks se déclenchent 7 jours avant l'expiration d'un jeton.

Pour configurer ces webhooks afin qu'ils se déclenchent également 60 jours et 30 jours avant l'expiration d'un jeton :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Cochez la case **Ajouter des déclencheurs de crochet Web supplémentaires pour l'expiration des jetons d'accès aux groupes**.
1. Sélectionnez **Enregistrer les modifications**.

## Désactiver les mentions de groupe {#disable-group-mentions}

Vous pouvez empêcher des utilisateurs d'être ajoutés à une conversation et d'être notifiés lorsque quelqu'un [mentionne un groupe](../discussions/_index.md#mentions) dont ces utilisateurs sont membres.

Les groupes avec les mentions désactivées sont visualisés en conséquence dans la liste déroulante de saisie automatique.

Ces indicateurs visuels sont particulièrement utiles pour les groupes comportant de nombreux utilisateurs.

Pour désactiver les mentions de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Sélectionnez **Les mentions du groupe sont désactivées**.
1. Sélectionnez **Enregistrer les modifications**.

## Restreindre les extraits de code personnels pour les utilisateurs d'entreprise {#restrict-personal-snippets-for-enterprise-users}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/200575) dans GitLab 18.5 [avec le feature flag](../../administration/feature_flags/_index.md) `allow_personal_snippets_setting`. Fonctionnalité désactivée par défaut.
- [En disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/work_items/583564) dans GitLab 18.9. Suppression du feature flag `allow_personal_snippets_setting`.

{{< /history >}}

Vous pouvez empêcher les [utilisateurs d'entreprise](../enterprise_user/_index.md) de votre groupe de créer des [extraits de code](../snippets.md) dans leur espace de nommage personnel. Lorsque cette option est désactivée, les utilisateurs d'entreprise peuvent toujours créer des extraits de code de projet, et consulter et modifier leurs extraits de code personnels existants.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour restreindre les extraits de code personnels pour les utilisateurs d'entreprise :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Décochez la case **Autoriser les extraits de code personnels**.
1. Sélectionnez **Enregistrer les modifications**.

## Empêcher les invitations dans un groupe {#prevent-invitations-to-a-group}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/189898) dans GitLab 18.0. Fonctionnalité désactivée par défaut.

{{< /history >}}

Sur GitLab.com, vous pouvez supprimer la possibilité pour les utilisateurs d'inviter de nouveaux membres dans des sous-groupes ou des projets d'un groupe principal. Cela empêche également les propriétaires de groupe d'envoyer des invitations. Vous devez désactiver ce paramètre avant de pouvoir à nouveau inviter des utilisateurs.

Sur les instances GitLab Self-Managed et GitLab Dedicated, vous pouvez empêcher les invitations d'utilisateurs pour l'ensemble de l'instance. Pour plus d'informations, consultez [empêcher les invitations dans des groupes et des projets](../../administration/settings/visibility_and_access_controls.md#prevent-invitations-to-groups-and-projects).

> [!note]
> Des fonctionnalités telles que le [partage](../project/members/sharing_projects_groups.md) ou les [migrations](../import/_index.md) peuvent toujours permettre l'accès à ces sous-groupes et projets.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour empêcher les invitations dans un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Sélectionnez **Désactiver l'invitation des membres du groupe/projet**.
1. Sélectionnez **Enregistrer les modifications**.

## Exporter les membres au format CSV {#export-members-as-csv}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez exporter une liste de membres d'un groupe ou sous-groupe au format CSV.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre sous-groupe.
1. Sélectionnez **Gérer** > **Membres**.
1. Sélectionnez **Exporter au format CSV**.
1. Une fois le fichier CSV généré, il est envoyé par e-mail en pièce jointe à l'utilisateur qui l'a demandé.

La liste de sortie inclut les membres directs et les membres hérités des groupes ancêtres. Pour les membres avec `Minimal Access` dans le groupe sélectionné, leur `Max Role` et leur `Source` sont dérivés de leur appartenance aux sous-groupes. [Le ticket 390358](https://gitlab.com/gitlab-org/gitlab/-/issues/390358) suit la discussion sur la non-concordance entre la liste d'exportation CSV des membres du groupe et la liste des membres dans l'interface utilisateur.

## Activer l'accès restreint {#turn-on-restricted-access}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.
- Le groupe ou l'un de ses sous-groupes ou projets ne doit pas être partagé en externe.

Pour activer l'accès restreint :

1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sous **Contrôle des sièges**, sélectionnez **Accès restreint**.

Lorsque vous activez l'accès restreint, le paramètre permettant d'[empêcher l'invitation de groupes en dehors de la hiérarchie du groupe](../project/members/sharing_projects_groups.md#prevent-inviting-groups-outside-the-group-hierarchy) est automatiquement activé.

Vous pouvez toujours configurer indépendamment le [partage de projets pour le groupe et ses sous-groupes](../project/members/sharing_projects_groups.md#prevent-a-project-from-being-shared-with-groups) selon vos besoins.

## Définir un plafond d'utilisateurs pour un groupe {#set-a-user-cap-for-a-group}

Prérequis :

- Vous devez être affecté au rôle Propriétaire pour le groupe.

Pour définir un plafond d'utilisateurs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Vous pouvez définir un plafond uniquement sur le groupe principal.
1. Sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Depuis **Contrôle des sièges**, cochez la case **Définir le plafond d'utilisateurs** et saisissez le nombre d'utilisateurs dans le champ.
1. Sélectionnez **Enregistrer les modifications**.

Si vous avez déjà plus d'utilisateurs dans le groupe que la valeur du plafond d'utilisateurs, les utilisateurs ne sont pas supprimés. Cependant, vous ne pouvez pas en ajouter davantage sans approbation.

L'augmentation du plafond d'utilisateurs n'approuve pas les membres en attente.

Lorsque vous définissez un plafond d'utilisateurs, le paramètre permettant d'[empêcher l'invitation de groupes en dehors de la hiérarchie du groupe](../project/members/sharing_projects_groups.md#prevent-inviting-groups-outside-the-group-hierarchy) est automatiquement activé.

## Supprimer le plafond d'utilisateurs pour un groupe {#remove-the-user-cap-for-a-group}

Vous pouvez supprimer le plafond d'utilisateurs, afin qu'il n'y ait pas de limite au nombre de membres que vous pouvez ajouter à un groupe.

Prérequis :

- Vous devez être affecté au rôle Propriétaire pour le groupe.

Pour supprimer le plafond d'utilisateurs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Depuis **Contrôle des sièges**, sélectionnez **Accès ouvert**.
1. Sélectionnez **Enregistrer les modifications**.

## Approuver les membres en attente pour un groupe {#approve-pending-members-for-a-group}

Lorsque le nombre d'utilisateurs facturables atteint le plafond d'utilisateurs, tout nouveau membre est mis en attente et doit être approuvé.

Les membres en attente ne sont pas comptabilisés comme facturables. Les membres sont comptabilisés comme facturables uniquement après avoir été approuvés et ne sont plus en attente.

Prérequis :

- Vous devez être affecté au rôle Propriétaire pour le groupe.

Pour approuver les membres en attente parce qu'ils ont dépassé le plafond d'utilisateurs :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Quotas d'utilisation**.
1. Dans l'onglet **Sièges**, sous l'alerte, sélectionnez **Voir les approbations en attente**.
1. Pour chaque membre que vous souhaitez approuver, sélectionnez **Approuver**.

## Contrôler les modèles de projets intégrés {#control-built-in-project-templates}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/230790) dans GitLab 19.0 [avec le feature flag](../../administration/feature_flags/_index.md) `use_built_in_project_templates_enabled`. Fonctionnalité désactivée par défaut.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/work_items/593623) dans GitLab 19.2. Suppression du feature flag `use_built_in_project_templates_enabled`.

{{< /history >}}

Les [modèles de projets intégrés](../project/_index.md#create-a-project-from-a-built-in-template) remplissent les nouveaux projets avec des fichiers de démarrage. Vous pouvez contrôler si ces modèles sont disponibles lorsque les utilisateurs créent des projets dans votre groupe. Vous pouvez également imposer votre choix à tous les sous-groupes.

Le paramètre utilise l'héritage en cascade :

- Votre groupe hérite du paramètre de son groupe ancêtre le plus proche ou de l'instance.
- Une valeur définie pour votre groupe remplace la valeur héritée.
- Lorsque vous imposez le paramètre à votre groupe, tous les sous-groupes en héritent et ne peuvent pas le modifier.
- Lorsque vous modifiez le paramètre de votre groupe, la nouvelle valeur se propage en cascade à tous les sous-groupes.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour contrôler les modèles de projets intégrés pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Modèles de projets intégrés**.
1. Cochez ou décochez la case **Activer les modèles de projets intégrés**.
1. Facultatif. Pour empêcher les sous-groupes de modifier ce paramètre, cochez la case **Imposer à tous les sous-groupes**.
1. Sélectionnez **Enregistrer les modifications**.

Si un administrateur a [imposé ce paramètre](../../administration/project_templates.md#built-in-project-templates) pour l'instance, ou si un groupe parent l'a imposé pour ses sous-groupes, le paramètre est verrouillé et vous ne pouvez pas le modifier.

## Modèles de fichiers de groupe {#group-file-templates}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Utilisez les modèles de fichiers de groupe pour partager un ensemble de modèles pour les types de fichiers courants avec chaque projet d'un groupe. Il est analogue au [dépôt de modèles d'instance](../../administration/settings/instance_template_repository.md). Le projet sélectionné doit respecter les mêmes conventions de nommage que celles documentées sur cette page.

Vous pouvez uniquement choisir des projets du groupe comme source de modèles. Cela inclut les projets partagés avec le groupe, mais exclut les projets dans les sous-groupes ou les groupes parents du groupe en cours de configuration.

Vous pouvez configurer cette fonctionnalité pour les sous-groupes et les groupes parents immédiats. Un projet dans un sous-groupe a accès aux modèles de ce sous-groupe et de tous les groupes parents immédiats.

Pour apprendre à créer des modèles pour les tickets et les merge requests, consultez les [modèles de description](../project/description_templates.md).

Définissez des modèles de projets au niveau du groupe en définissant un groupe comme source de modèles. Pour plus d'informations, consultez les [modèles de projets au niveau du groupe](custom_project_templates.md).

### Activer les modèles de fichiers de groupe {#enable-group-file-template}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour activer les modèles de fichiers de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Modèles**.
1. Choisissez un projet à utiliser comme dépôt de modèles.
1. Sélectionnez **Enregistrer les modifications**.

## Paramètres des vérifications de fusion du groupe {#group-merge-checks-settings}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les propriétaires de groupe peuvent configurer des vérifications de merge request sur un groupe principal, qui s'appliquent à tous les sous-groupes et projets.

Si les paramètres sont hérités par un sous-groupe ou un projet, ils ne peuvent pas être modifiés dans le sous-groupe ou le projet qui les a hérités.

### Exiger un pipeline réussi pour la fusion {#require-a-successful-pipeline-for-merge}

Vous pouvez configurer tous les projets enfants de votre groupe pour exiger un pipeline complet et réussi avant la fusion.

Voir également [le paramètre au niveau du projet](../project/merge_requests/auto_merge.md#require-a-successful-pipeline-for-merge).

Prérequis :

- Vous devez être le propriétaire du groupe.

Pour activer ce paramètre :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Requêtes de fusion**.
1. Sous **Vérifications de fusion**, sélectionnez **Les pipelines doivent réussir**. Ce paramètre empêche également la fusion des merge requests s'il n'y a pas de pipeline.
1. Sélectionnez **Enregistrer les modifications**.

#### Autoriser la fusion après des pipelines ignorés {#allow-merge-after-skipped-pipelines}

Vous pouvez configurer les [pipelines ignorés](../../ci/pipelines/_index.md#skip-a-pipeline) pour qu'ils n'empêchent pas la fusion des merge requests.

Voir également [le paramètre au niveau du projet](../project/merge_requests/auto_merge.md#allow-merge-after-skipped-pipelines).

Prérequis :

- Vous devez être le propriétaire du groupe.

Pour modifier ce comportement :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Requêtes de fusion**.
1. Sous **Vérifications de fusion** :
   - Sélectionnez **Les pipelines doivent réussir**.
   - Sélectionnez **Les pipelines ignorés sont considérés réussis**.
1. Sélectionnez **Enregistrer les modifications**.

### Empêcher la fusion si tous les fils de discussion ne sont pas résolus {#prevent-merge-unless-all-threads-are-resolved}

Vous pouvez empêcher la fusion des merge requests jusqu'à ce que tous les fils de discussion soient résolus. Lorsque ce paramètre est activé, les projets enfants de votre groupe affichent le nombre de fils de discussion ouverts en orange sur les merge requests comportant au moins un fil de discussion ouvert.

Prérequis :

- Vous devez être le propriétaire du groupe.

Pour activer ce paramètre :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Requêtes de fusion**.
1. Sous **Vérifications de fusion**, sélectionnez **Tous les fils de conversation doivent être résolus**.
1. Sélectionnez **Enregistrer les modifications**.

## Exiger un SHA de commit sur l'API des merge requests {#require-a-commit-sha-on-the-merge-requests-api}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/244421) dans GitLab 19.2. Activé par défaut pour les nouveaux groupes.
- Interface utilisateur des paramètres de groupe et d'instance [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/243465) dans GitLab 19.3.
- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/251669) pour être désactivé par défaut pour les nouveaux groupes dans GitLab 19.2.6, GitLab 19.3.2 et GitLab 19.4.

{{< /history >}}

Exigez un SHA de commit sur l'API des merge requests pour vous assurer que seuls les commits révisés sont fusionnés. Lorsque ce paramètre est activé, GitLab rejette les appels au point de terminaison [fusionner une merge request](../../api/merge_requests.md#merge-a-merge-request) qui omettent le paramètre `sha` et renvoie une erreur `400`. La fusion échoue si le paramètre `sha` ne correspond pas au HEAD actuel de la branche source.

Ce paramètre est désactivé par défaut.

> [!note]
> Pour GitLab Self-Managed et GitLab Dedicated, ce paramètre est activé par défaut pour les nouveaux groupes créés dans :
>
> - GitLab 19.2.0 à GitLab 19.2.5
> - GitLab 19.3.0 à GitLab 19.3.1
>
> Si vous souhaitez désactiver le paramètre par défaut pour tous les nouveaux groupes, désactivez le paramètre et sélectionnez **Imposer à tous les sous-groupes** ou **Imposer ce paramètre à tous les groupes de cette instance**.

Prérequis :

- Le rôle Propriétaire pour le groupe.

Pour exiger un SHA de commit sur l'API des merge requests :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Requêtes de fusion**.
1. Cochez la case **Exiger le SHA du commit sur l'API de requêtes de fusion**.
1. Facultatif. Pour imposer ce paramètre à tous les sous-groupes et empêcher les sous-groupes de le modifier, cochez la case **Imposer à tous les sous-groupes**.
1. Sélectionnez **Enregistrer les modifications**.

Les administrateurs peuvent définir une valeur par défaut à l'échelle de l'instance pour ce paramètre, et éventuellement l'imposer afin que les nouveaux groupes ne puissent pas le remplacer.

Prérequis :

- Accès administrateur à l'instance.

Pour définir la valeur par défaut pour tous les groupes :

1. Dans la barre latérale gauche, en bas, sélectionnez **Admin**.
1. Sélectionnez **Paramètres** > **Généralités**.
1. Développez **Requêtes de fusion**.
1. Cochez la case **Exiger le SHA du commit sur l'API de requêtes de fusion**.
1. Facultatif. Pour imposer ce paramètre à tous les groupes nouveaux et existants de l'instance et empêcher les groupes de le modifier, sélectionnez **Imposer ce paramètre à tous les groupes de cette instance**.
1. Sélectionnez **Enregistrer les modifications**.

## Paramètres d'approbation des merge requests du groupe {#group-merge-request-approval-settings}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les paramètres d'approbation du groupe définissent les valeurs par défaut des [paramètres d'approbation des merge requests du projet](../project/merge_requests/approvals/settings.md) dans les sous-groupes et projets d'un groupe principal. Lorsque vous activez un paramètre de prévention pour un groupe, le paramètre de projet équivalent est verrouillé et les mainteneurs du projet ne peuvent pas le modifier. Lorsqu'un paramètre de prévention est laissé désactivé, les mainteneurs du projet peuvent le configurer pour des projets individuels. Pour plus d'informations, consultez [paramètres en cascade depuis l'instance ou le groupe principal](../project/merge_requests/approvals/settings.md#cascade-settings-from-the-instance-or-top-level-group).

Pour afficher les paramètres d'approbation des merge requests pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Approbations des requêtes de fusion**.
1. Sélectionnez les paramètres souhaités.
1. Sélectionnez **Enregistrer les modifications**.

Les paramètres d'approbation ne doivent pas être confondus avec les [règles d'approbation](../project/merge_requests/approvals/rules.md). La prise en charge de la définition de règles d'approbation de merge request pour les groupes est suivie dans l'[epic 4367](https://gitlab.com/groups/gitlab-org/-/work_items/4367).

## Analytiques d'activité du groupe {#group-activity-analytics}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour un groupe, vous pouvez voir combien de merge requests, de tickets et de membres ont été créés au cours des 90 derniers jours.

Les modifications apportées aux [wikis de groupe](../project/wiki/group.md) n'apparaissent pas dans les analytiques d'activité du groupe.

### Afficher l'activité du groupe {#view-group-activity}

Vous pouvez voir les actions les plus récentes effectuées dans un groupe, dans votre navigateur ou dans un flux RSS :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Activité**.

Pour afficher le flux d'activité au format Atom, sélectionnez l'icône **RSS** ({{< icon name="rss" >}}).

## Afficher les données utilisateur de GitLab Credits {#display-gitlab-credits-user-data}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Paramètre d'espace de nommage permettant l'affichage des données utilisateur [introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/215371) dans GitLab 18.7 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `usage_billing_dev`. [Activé par défaut](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/215714).
- Feature flag `usage_billing_dev` [supprimé](https://gitlab.com/gitlab-org/gitlab/-/work_items/566581) dans GitLab 18.10.

{{< /history >}}

Prérequis :

- Vous devez être propriétaire du groupe.
- Le groupe pour lequel vous consultez les données doit être un groupe principal.

Pour afficher les données utilisateur sur le [tableau de bord GitLab Credits](../../subscriptions/gitlab_credits_dashboard.md) :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Permissions et fonctionnalités du groupe**.
1. Pour le **Tableau de bord des crédits GitLab**, cochez la case **Afficher les données utilisateur**.
1. Sélectionnez **Enregistrer les modifications**.
