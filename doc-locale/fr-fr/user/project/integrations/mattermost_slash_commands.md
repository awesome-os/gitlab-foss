---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Commandes slash de Mattermost
description: "Configurez les commandes slash de Mattermost pour exécuter des opérations GitLab courantes depuis un environnement de chat Mattermost."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez utiliser les [commandes slash](gitlab_slack_application.md#slash-commands) pour exécuter des opérations GitLab courantes, comme la création d'un ticket, depuis un environnement de chat [Mattermost](https://mattermost.com/).

GitLab peut également envoyer des événements (tels que `issue created`) à Mattermost dans le cadre des [notifications Mattermost](mattermost.md) configurées séparément.

Pour obtenir la liste des commandes slash disponibles, consultez [Commandes slash](gitlab_slack_application.md#slash-commands).

## Configurer les commandes slash {#configure-slash-commands}

Pour configurer les commandes slash dans Mattermost, vous devez effectuer les étapes suivantes.

### Activer les commandes slash personnalisées dans Mattermost {#enable-custom-slash-commands-in-mattermost}

Pour activer les commandes slash personnalisées depuis la console d'administration de Mattermost :

1. Connectez-vous à Mattermost en tant qu'utilisateur disposant de privilèges d'administrateur.
1. Dans le coin supérieur gauche, sélectionnez le logo Mattermost, puis sélectionnez **Console système**.
1. Sélectionnez **Gestion des intégrations**, et définissez ces valeurs sur `True` :
   - **Activer les commandes slash personnalisées**
   - **Autoriser les intégrations à remplacer les noms d’utilisateur**
   - **Autoriser les intégrations à remplacer les icônes des photos de profil**
1. Sélectionnez **Sauvegarder**, mais ne fermez pas cet onglet du navigateur. Vous en aurez besoin lors d'une étape ultérieure.

### Obtenir les valeurs de configuration depuis GitLab {#get-configuration-values-from-gitlab}

Pour obtenir les valeurs de configuration depuis GitLab :

1. Dans un autre onglet du navigateur, connectez-vous à GitLab en tant qu'utilisateur disposant d'un accès administrateur.
1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Commandes slash de Mattermost**. GitLab affiche les valeurs potentielles pour les paramètres de Mattermost.
1. Copiez la valeur **URL de la requête**. Toutes les autres valeurs sont des suggestions.
1. Ne fermez pas cet onglet du navigateur. Vous en aurez besoin lors d'une étape ultérieure.

### Créer une commande slash dans Mattermost {#create-a-slash-command-in-mattermost}

Pour créer une commande slash dans Mattermost :

1. [Dans l'onglet du navigateur Mattermost](#enable-custom-slash-commands-in-mattermost), accédez à la page de votre équipe.
1. Dans le coin supérieur gauche, sélectionnez le logo Mattermost, puis **Intégrations**.
1. Dans la barre latérale gauche, sélectionnez **Commandes slash**.
1. Sélectionnez **Ajouter une commande slash**.
1. Renseignez un **Nom d’affichage** et une **Description** pour votre nouvelle commande.
1. Renseignez un **Mot-clé de déclenchement de la commande** en fonction de la configuration de votre application :

   - Si vous souhaitez connecter un seul projet à votre équipe Mattermost, utilisez `/gitlab` comme mot déclencheur.
   - Si vous souhaitez connecter plusieurs projets, utilisez un mot déclencheur en lien avec votre projet, tel que `/project-name` ou `/gitlab-project-name`.
1. Pour le champ **URL de la requête**, [collez la valeur copiée depuis GitLab](#get-configuration-values-from-gitlab).
1. Pour toutes les autres valeurs, vous pouvez utiliser les suggestions de GitLab ou vos propres valeurs.
1. Copiez la valeur **Jeton**, puis sélectionnez **Terminé**.

### Fournir le jeton Mattermost à GitLab {#provide-the-mattermost-token-to-gitlab}

La création d'une commande slash dans Mattermost génère un jeton que vous devez fournir à GitLab :

1. [Dans l'onglet du navigateur GitLab](#get-configuration-values-from-gitlab), cochez la case **Actif**.
1. Dans la zone de texte **Jeton**, [collez le jeton copié depuis Mattermost](#create-a-slash-command-in-mattermost).
1. Sélectionnez **Enregistrer les modifications**.

Votre commande slash peut désormais communiquer avec votre projet GitLab.

## Connecter votre compte GitLab à Mattermost {#connect-your-gitlab-account-to-mattermost}

Prérequis :

- Pour exécuter des [commandes slash](gitlab_slack_application.md#slash-commands), vous devez disposer des [autorisations](../../permissions.md#project-permissions) nécessaires pour effectuer l'action dans le projet GitLab.

Pour interagir avec GitLab à l'aide des commandes slash de Mattermost :

1. Dans un environnement de chat Mattermost, exécutez votre nouvelle commande slash.
1. Sélectionnez **connecter votre compte GitLab** pour autoriser l'accès.

Vous pouvez voir tous les comptes de chat autorisés dans votre page de profil Mattermost sous **Chat**.

## Sujets connexes {#related-topics}

- [Commandes slash dans Mattermost](https://developers.mattermost.com/integrate/slash-commands/)

## Dépannage {#troubleshooting}

Lorsqu'une commande slash de Mattermost ne déclenche pas d'événement dans GitLab :

- Assurez-vous d'utiliser un canal public. Les webhooks Mattermost n'ont pas accès aux canaux privés.
- Si vous avez besoin d'un canal privé, modifiez le canal du webhook et sélectionnez un canal privé. Tous les événements sont envoyés au canal spécifié.
