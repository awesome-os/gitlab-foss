---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Réassigner les contributions et les appartenances
---

Les utilisateurs et utilisatrices disposant du rôle Propriétaire pour un groupe principal peuvent réassigner les contributions et les appartenances des utilisateurs et utilisatrices de l'espace réservé à des utilisateurs et utilisatrices actifs et non-bot existants. Sur l'instance de destination, les utilisateurs et utilisatrices disposant du rôle Propriétaire pour un groupe principal peuvent :

- Demander aux utilisateurs et utilisatrices de passer en revue la réassignation des contributions et des appartenances [dans l'interface utilisateur](#request-reassignment-in-ui) ou [via un fichier CSV](#request-reassignment-by-using-a-csv-file). Pour un grand nombre d'utilisateurs et d'utilisatrices de l'espace réservé, vous devriez utiliser un fichier CSV. Dans les deux cas, les utilisateurs et utilisatrices reçoivent une demande par e-mail pour accepter ou rejeter la réassignation. La réassignation ne commence qu'après que l'utilisateur ou l'utilisatrice sélectionné(e) [accepte la demande de réassignation](#accept-contribution-reassignment).
- Choisir de ne pas réassigner les contributions et les appartenances et [les conserver attribuées aux utilisateurs et utilisatrices de l'espace réservé](#keep-as-placeholder).

Sur GitLab Self-Managed et GitLab Dedicated, les administrateurs et administratrices peuvent réassigner les contributions et les appartenances aux utilisateurs et utilisatrices actifs et inactifs non-bot immédiatement, sans leur confirmation. Pour plus d'informations, consultez [ignorer la confirmation lorsque les administrateurs et administratrices réassignent des utilisateurs et utilisatrices de l'espace réservé](../../../administration/settings/import_and_export_settings.md#skip-confirmation-when-administrators-reassign-placeholder-users). Pour réassigner des contributions et des appartenances à des administrateurs et administratrices, consultez [autoriser le mappage des contributions aux administrateurs et administratrices](../../../administration/settings/import_and_export_settings.md#allow-contribution-mapping-to-administrators).

## Contourner la confirmation lors de la réassignation des utilisateurs et utilisatrices de l'espace réservé {#bypass-confirmation-when-reassigning-placeholder-users}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

{{< history >}}

- [Introduit sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/544024) dans GitLab 18.1 avec un feature flag nommé `group_owner_placeholder_confirmation_bypass`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/548946) dans GitLab 18.4.
- [Disponible en général sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/569771) dans GitLab 18.7. Le feature flag `group_owner_placeholder_confirmation_bypass` a été supprimé.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour contourner la confirmation pour les [utilisateurs et utilisatrices d'entreprise](../../enterprise_user/_index.md) lors de la réassignation des espaces réservés :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Permissions et fonctionnalités du groupe**.
1. Sous **Confirmation d'utilisateurs et d'utilisatrices de l'espace réservé**, cochez la case **Réassigner les espaces réservés à des utilisateurs et utilisatrices de l'entreprise sans confirmation de leur part**.
1. Dans **Date de rétablissement de la confirmation de l'utilisateur ou utilisatrice**, sélectionnez une date de fin pour contourner la confirmation de l'utilisateur ou de l'utilisatrice. La valeur par défaut est un jour.
1. Sélectionnez **Enregistrer les modifications**.

### Réassignation des contributions de plusieurs utilisateurs et utilisatrices de l'espace réservé {#reassigning-contributions-from-multiple-placeholder-users}

Vous pouvez réassigner toutes les contributions initialement attribuées à un seul utilisateur ou une seule utilisatrice de l'espace réservé à un seul utilisateur régulier actif, à des comptes de service, à des bots de projet et à des bots de groupe sur l'instance de destination. Vous ne pouvez pas répartir les contributions attribuées à un seul utilisateur ou une seule utilisatrice de l'espace réservé entre plusieurs utilisateurs et utilisatrices.

Vous pouvez réassigner les contributions de plusieurs utilisateurs et utilisatrices de l'espace réservé au même utilisateur ou à la même utilisatrice sur l'instance de destination si les utilisateurs et utilisatrices de l'espace réservé proviennent :

- D'instances sources différentes
- De la même instance source et sont importés dans différents groupes principaux sur l'instance de destination

Si un utilisateur ou une utilisatrice assigné(e) devient inactif ou inactive avant d'accepter la demande de réassignation, la réassignation en attente reste liée à l'utilisateur ou à l'utilisatrice jusqu'à ce qu'il ou elle l'accepte.

Les utilisateurs et utilisatrices qui reçoivent une demande de réassignation peuvent :

- [Accepter la demande](#accept-contribution-reassignment). Toutes les contributions et l'appartenance précédemment attribuées à l'utilisateur ou l'utilisatrice de l'espace réservé sont réattribuées à l'utilisateur ou l'utilisatrice qui accepte. Ce processus peut prendre quelques minutes, selon le nombre de contributions.
- [Rejeter la demande](#reject-contribution-reassignment) ou la signaler comme spam. Cette option est disponible dans l'e-mail de demande de réassignation.

Lorsque vous réassignez des contributions à des comptes de service, à des bots de projet et à des bots de groupe, la demande de réassignation est automatiquement approuvée.

Lors des importations ultérieures dans le même groupe principal, les contributions et les appartenances appartenant au même utilisateur ou à la même utilisatrice source sont automatiquement mappées à l'utilisateur ou à l'utilisatrice qui a précédemment accepté les réassignations pour cet utilisateur ou cette utilisatrice source.

Sur GitLab Self-Managed et GitLab Dedicated, les administrateurs et administratrices peuvent réassigner les contributions et les appartenances aux utilisateurs et utilisatrices actifs et inactifs non-bot immédiatement, sans leur confirmation. Pour plus d'informations, consultez [ignorer la confirmation lorsque les administrateurs et administratrices réassignent des utilisateurs et utilisatrices de l'espace réservé](../../../administration/settings/import_and_export_settings.md#skip-confirmation-when-administrators-reassign-placeholder-users). Pour réassigner des contributions et des appartenances à des administrateurs et administratrices, consultez [autoriser le mappage des contributions aux administrateurs et administratrices](../../../administration/settings/import_and_export_settings.md#allow-contribution-mapping-to-administrators).

### Finalisation de la réassignation {#completing-the-reassignment}

Le processus de réassignation doit être entièrement terminé avant de :

- [Déplacer un groupe importé dans la même instance GitLab](../../group/manage.md#transfer-a-group).
- [Déplacer un projet importé vers un groupe différent](../../project/working_with_projects.md#transfer-a-project).
- Dupliquer un ticket importé.
- Promouvoir un ticket importé en epic.

Si le processus n'est pas terminé, les contributions encore attribuées aux utilisateurs et utilisatrices de l'espace réservé ne peuvent pas être réassignées à de véritables utilisateurs et utilisatrices et restent associées aux utilisateurs et utilisatrices de l'espace réservé.

### Considérations relatives à la sécurité {#security-considerations}

La réassignation des contributions et des appartenances est irréversible. Vérifiez tout attentivement avant de commencer.

La réassignation des contributions et des appartenances à un utilisateur ou une utilisatrice incorrect(e) constitue une menace pour la sécurité, car l'utilisateur ou l'utilisatrice devient membre de votre groupe. Il ou elle peut alors consulter des informations qu'il ou elle ne devrait pas être en mesure de voir.

La réassignation des contributions aux utilisateurs et utilisatrices disposant d'un accès administrateur est désactivée par défaut, mais vous pouvez l'[activer](../../../administration/settings/import_and_export_settings.md#allow-contribution-mapping-to-administrators).

#### Considérations de sécurité relatives aux appartenances {#membership-security-considerations}

En raison du modèle d'autorisations de GitLab, lorsqu'un groupe ou un projet est importé dans un groupe parent existant, les membres du groupe parent bénéficient d'une [appartenance héritée](../../project/members/_index.md#membership-types) au groupe ou au projet importé.

La sélection d'un utilisateur ou d'une utilisatrice pour la réassignation des contributions et des appartenances qui dispose déjà d'une appartenance héritée existante au groupe ou au projet importé peut affecter la façon dont les appartenances lui sont réassignées.

GitLab n'autorise pas une appartenance dans un projet ou un groupe enfant à avoir un rôle inférieur à une appartenance héritée. Si une appartenance importée pour un utilisateur ou une utilisatrice assigné(e) a un rôle inférieur à son appartenance héritée existante, l'appartenance importée n'est pas réassignée à l'utilisateur ou à l'utilisatrice.

Cela a pour conséquence que leur appartenance au groupe ou au projet importé est plus élevée qu'elle ne l'était sur la source.

### Demander une réassignation dans l'interface utilisateur {#request-reassignment-in-ui}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Vous pouvez réassigner des contributions et des appartenances dans le groupe principal. Pour demander la réassignation des contributions et des appartenances :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Accédez au sous-onglet **En attente de réaffectation**, où les espaces réservés sont répertoriés dans un tableau.
1. Pour chaque espace réservé, examinez les informations dans les colonnes du tableau **Utilisateur de l'espace réservé** et **Source**.
1. Dans la colonne **Réassigner l'espace réservé à**, sélectionnez un utilisateur ou une utilisatrice dans la liste déroulante.
1. Sélectionnez **Réassigner**.

Les contributions d'un seul utilisateur ou d'une seule utilisatrice de l'espace réservé peuvent être réassignées à un utilisateur ou une utilisatrice actif(ve) non-bot sur l'instance de destination.

Avant qu'un utilisateur ou une utilisatrice accepte la réassignation, vous pouvez [annuler la demande](#cancel-reassignment-request).

Sur GitLab Self-Managed et GitLab Dedicated, les administrateurs et administratrices peuvent réassigner les contributions et les appartenances aux utilisateurs et utilisatrices actifs et inactifs non-bot immédiatement, sans leur confirmation. Pour plus d'informations, consultez [ignorer la confirmation lorsque les administrateurs et administratrices réassignent des utilisateurs et utilisatrices de l'espace réservé](../../../administration/settings/import_and_export_settings.md#skip-confirmation-when-administrators-reassign-placeholder-users). Pour réassigner des contributions et des appartenances à des administrateurs et administratrices, consultez [autoriser le mappage des contributions aux administrateurs et administratrices](../../../administration/settings/import_and_export_settings.md#allow-contribution-mapping-to-administrators).

### Demander une réassignation à l'aide d'un fichier CSV {#request-reassignment-by-using-a-csv-file}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/455901) dans GitLab 17.10 [avec le feature flag](../../../administration/feature_flags/_index.md) `importer_user_mapping_reassignment_csv`. Activés par défaut.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/478022) dans GitLab 18.0. Le feature flag `importer_user_mapping_reassignment_csv` a été supprimé.

{{< /history >}}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour un grand nombre d'utilisateurs et d'utilisatrices de l'espace réservé, vous pouvez réassigner les contributions et les appartenances à l'aide d'un fichier CSV. Vous pouvez télécharger un modèle CSV prérempli avec les informations suivantes. Par exemple :

| Hôte source          | Type d'importation | Identifiant de l'utilisateur ou de l'utilisatrice source | Nom de l'utilisateur ou de l'utilisatrice source | Nom d'utilisateur source |
|----------------------|-------------|------------------------|------------------|-----------------|
| `gitlab.example.com` | `gitlab`    | `alice`                | `Alice Coder`    | `a.coder`       |

Ne modifiez pas **Hôte source**, **Type d'importation** ni **Identifiant de l'utilisateur ou de l'utilisatrice source**. Ces informations permettent de localiser l'enregistrement de base de données correspondant après le téléchargement du fichier CSV complété. **Nom de l'utilisateur ou de l'utilisatrice source** et **Nom d'utilisateur source** identifient l'utilisateur ou l'utilisatrice source et ne sont pas utilisés après le téléchargement du fichier CSV.

Vous n'avez pas à mettre à jour chaque ligne du fichier CSV. Seules les lignes comportant un **Nom d'utilisateur GitLab** ou un **E-mail public GitLab** sont traitées. Toutes les autres lignes sont ignorées.

Pour demander la réassignation des contributions et des appartenances à l'aide d'un fichier CSV :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Sélectionnez **Réassigner avec CSV**.
1. Téléchargez le modèle CSV prérempli.
1. Dans **Nom d'utilisateur GitLab** ou **E-mail public GitLab**, saisissez le nom d'utilisateur ou l'adresse e-mail publique de l'utilisateur ou de l'utilisatrice GitLab sur l'instance de destination. Les administrateurs et administratrices d'instance peuvent réassigner des utilisateurs et utilisatrices avec n'importe quelle adresse e-mail confirmée.
1. Téléchargez le fichier CSV complété.
1. Sélectionnez **Réassigner**.

Vous ne pouvez attribuer que les contributions d'un seul utilisateur ou d'une seule utilisatrice de l'espace réservé à chaque utilisateur ou utilisatrice actif(ve) non-bot sur l'instance de destination. Les utilisateurs et utilisatrices reçoivent un e-mail pour examiner et [accepter les contributions](#accept-contribution-reassignment) que vous leur avez réassignées. Vous pouvez [annuler la demande de réassignation](#cancel-reassignment-request) avant que l'utilisateur ou l'utilisatrice ne l'examine.

Sur GitLab Self-Managed et GitLab Dedicated, les administrateurs et administratrices peuvent réassigner les contributions et les appartenances aux utilisateurs et utilisatrices actifs et inactifs non-bot immédiatement, sans leur confirmation. Pour plus d'informations, consultez [ignorer la confirmation lorsque les administrateurs et administratrices réassignent des utilisateurs et utilisatrices de l'espace réservé](../../../administration/settings/import_and_export_settings.md#skip-confirmation-when-administrators-reassign-placeholder-users). Pour réassigner des contributions et des appartenances à des administrateurs et administratrices, consultez [autoriser le mappage des contributions aux administrateurs et administratrices](../../../administration/settings/import_and_export_settings.md#allow-contribution-mapping-to-administrators).

Après avoir réassigné des contributions, GitLab vous envoie un e-mail indiquant le nombre de :

- Lignes traitées avec succès
- Lignes non traitées avec succès
- Lignes ignorées

Si certaines lignes n'ont pas été traitées avec succès, l'e-mail contient un fichier CSV avec des résultats plus détaillés.

Pour réassigner des utilisateurs et utilisatrices de l'espace réservé en masse sans utiliser l'interface utilisateur, consultez [API de réassignation des espaces réservés de groupe](../../../api/group_placeholder_reassignments.md).

### Conserver en tant qu'espace réservé {#keep-as-placeholder}

{{< history >}}

- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/535431) dans GitLab 18.5, l'opération peut être annulée.

{{< /history >}}

Il est possible que vous ne souhaitiez pas réassigner les contributions et les appartenances aux utilisateurs et utilisatrices de l'instance de destination. Par exemple, vous pouvez avoir d'anciens employés qui ont contribué sur l'instance source, mais qui n'existent pas en tant qu'utilisateurs et utilisatrices sur l'instance de destination.

Dans ces cas, vous pouvez conserver les contributions attribuées aux utilisateurs et utilisatrices de l'espace réservé. Les utilisateurs et utilisatrices de l'espace réservé ne conservent pas les informations d'appartenance car ils ou elles [ne peuvent pas être membres de projets ou de groupes](post_migration_mapping.md#placeholder-user-attributes).

Comme les noms et les noms d'utilisateur des utilisateurs et utilisatrices de l'espace réservé ressemblent aux noms et aux noms d'utilisateur des utilisateurs et utilisatrices sources, vous conservez une grande partie du contexte historique.

Vous pouvez conserver les contributions attribuées aux utilisateurs et utilisatrices de l'espace réservé une par une ou en masse. Lorsque vous réassignez des contributions en masse, l'ensemble de l'espace de nommage et les utilisateurs et utilisatrices ayant les [statuts de réassignation](#view-and-filter-by-reassignment-status) suivants sont affectés :

- `Not started`
- `Rejected`

Pour conserver les utilisateurs et utilisatrices de l'espace réservé un(e) à la fois :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Accédez au sous-onglet **En attente de réaffectation**, où les espaces réservés sont répertoriés dans un tableau.
1. Trouvez l'utilisateur ou l'utilisatrice de l'espace réservé que vous souhaitez conserver en examinant les colonnes **Utilisateur de l'espace réservé** et **Source**.
1. Dans la colonne **Réassigner l'espace réservé à**, sélectionnez **Ne pas réassigner**.
1. Sélectionnez **Confirmer**.

Pour conserver les utilisateurs et utilisatrices de l'espace réservé en masse :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Au-dessus de la liste, sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}) > **Tous les conserver en tant qu'espaces réservés**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Confirmer**.

Pour annuler l'opération :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Accédez au sous-onglet **Réaffecté**, où les espaces réservés sont répertoriés dans un tableau.
1. Sélectionnez **Annuler** dans la ligne appropriée.

### Annuler une demande de réassignation {#cancel-reassignment-request}

Avant qu'un utilisateur ou une utilisatrice accepte une demande de réassignation, vous pouvez annuler la demande :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Accédez au sous-onglet **En attente de réaffectation**, où les espaces réservés sont répertoriés dans un tableau.
1. Sélectionnez **Annuler** dans la ligne appropriée.

### Notifier à nouveau l'utilisateur ou l'utilisatrice au sujet des demandes de réassignation en attente {#notify-user-again-about-pending-reassignment-requests}

Si un utilisateur ou une utilisatrice ne donne pas suite à une demande de réassignation, vous pouvez le ou la relancer en envoyant un autre e-mail :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Accédez au sous-onglet **En attente de réaffectation**, où les espaces réservés sont répertoriés dans un tableau.
1. Sélectionnez **Notifier** dans la ligne appropriée.

### Afficher et filtrer par statut de réassignation {#view-and-filter-by-reassignment-status}

Pour afficher le statut de réassignation de tous les utilisateurs et utilisatrices de l'espace réservé :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau supérieur.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez l'onglet **Espaces réservés**.
1. Accédez au sous-onglet **En attente de réaffectation**, où les espaces réservés sont répertoriés dans un tableau.
1. Consultez le statut de chaque utilisateur ou utilisatrice de l'espace réservé dans la colonne **Statut de la réassignation**.

Dans l'onglet **En attente de réaffectation**, les statuts possibles sont :

- `Not started` - La réassignation n'a pas commencé.
- `Pending approval` - La réassignation est en attente d'approbation de l'utilisateur ou de l'utilisatrice.
- `Reassigning` - La réassignation est en cours.
- `Rejected` - La réassignation a été rejetée par l'utilisateur ou l'utilisatrice.
- `Failed` - La réassignation a échoué.

Dans l'onglet **Réaffecté**, les statuts possibles sont :

- `Success` - La réassignation a réussi.
- `Kept as placeholder` - L'utilisateur ou l'utilisatrice de l'espace réservé a été rendu(e) permanent(e).

Par défaut, le tableau est trié par ordre alphabétique par nom d'utilisateur ou d'utilisatrice de l'espace réservé. Vous pouvez également trier le tableau par statut de réassignation.

## Confirmer la réassignation des contributions {#confirm-contribution-reassignment}

Lorsque [**Ignorer la confirmation lorsque les administrateurs et administratrices réassignent des utilisateurs et utilisatrices de l'espace réservé**](../../../administration/settings/import_and_export_settings.md#skip-confirmation-when-administrators-reassign-placeholder-users) est activé :

- Les administrateurs et administratrices peuvent réassigner les contributions immédiatement sans confirmation de l'utilisateur ou de l'utilisatrice.
- Les administrateurs et administratrices peuvent réassigner les contributions aux utilisateurs et utilisatrices actifs et inactifs non-bot.
- Vous recevez un e-mail vous informant que des contributions vous ont été réassignées.

Si ce paramètre n'est pas activé, vous pouvez [accepter](#accept-contribution-reassignment) ou [rejeter](#reject-contribution-reassignment) la réassignation.

### Accepter la réassignation des contributions {#accept-contribution-reassignment}

Vous pouvez recevoir un e-mail vous informant qu'un processus d'importation a eu lieu et vous demandant de confirmer la réassignation des contributions à vous-même.

Si vous avez été informé(e) de ce processus d'importation, vous devez tout de même examiner très attentivement les détails de la réassignation. Les détails répertoriés dans l'e-mail sont :

- **Importé depuis** \- La plateforme d'origine du contenu importé. Par exemple, une autre instance de GitLab, GitHub ou Bitbucket.
- **Utilisateur ou utilisatrice d'origine** \- Le nom et le nom d'utilisateur de l'utilisateur ou de l'utilisatrice sur la plateforme source. Il pourrait s'agir de votre nom et de votre nom d'utilisateur sur cette plateforme.
- **Importé vers** \- Le nom de la nouvelle plateforme, qui ne peut être qu'une instance GitLab.
- **Réassigné à** \- Votre nom complet et votre nom d'utilisateur sur l'instance GitLab.
- **Réassigné par** \- Le nom complet et le nom d'utilisateur de votre collègue ou responsable qui a effectué l'importation.

### Rejeter la réassignation des contributions {#reject-contribution-reassignment}

Si vous recevez un e-mail vous demandant de confirmer la réassignation des contributions à vous-même et que vous ne reconnaissez pas ces informations ou constatez des erreurs :

1. Ne donnez pas suite ou rejetez la réassignation des contributions.
1. Parlez à un collègue de confiance ou à votre responsable.

### Considérations relatives à la sécurité {#security-considerations-1}

Vous devez examiner très attentivement les détails de réassignation de toute demande de réassignation. Si vous n'avez pas déjà été informé(e) de ce processus par un collègue de confiance ou votre responsable, soyez particulièrement vigilant(e).

Plutôt que d'accepter des réassignations sur lesquelles vous avez le moindre doute :

1. Ne donnez pas suite aux e-mails.
1. Parlez à un collègue de confiance ou à votre responsable.

N'acceptez les réassignations que de la part d'utilisateurs et d'utilisatrices que vous connaissez et en qui vous avez confiance. La réassignation des contributions est permanente et irréversible. L'acceptation de la réassignation peut entraîner une attribution incorrecte des contributions à votre nom.

Le processus de réassignation des contributions ne commence qu'après que vous avez accepté la demande de réassignation en sélectionnant **Approuver la réaffectation** dans GitLab. Le processus ne démarre pas en sélectionnant des liens dans l'e-mail.
