---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Notifications Mattermost
description: "Configurez les notifications Mattermost pour recevoir des notifications de GitLab dans les canaux Mattermost."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Utilisez l'intégration des notifications Mattermost pour envoyer des notifications relatives aux événements GitLab (par exemple, `issue created`) à Mattermost. Vous devez configurer [Mattermost](#configure-mattermost-to-receive-gitlab-notifications) et [GitLab](#configure-gitlab-to-send-notifications-to-mattermost).

Vous pouvez également utiliser les [commandes slash Mattermost](mattermost_slash_commands.md) pour contrôler GitLab depuis Mattermost.

## Configurer Mattermost pour recevoir des notifications GitLab {#configure-mattermost-to-receive-gitlab-notifications}

Pour utiliser l'intégration Mattermost, vous devez créer une intégration de webhook entrant dans Mattermost :

1. Connectez-vous à votre instance Mattermost.
1. [Activez les webhooks entrants](https://docs.mattermost.com/configure/integrations-configuration-settings.html#enable-incoming-webhooks).
1. [Ajoutez un webhook entrant](https://developers.mattermost.com/integrate/webhooks/incoming/#create-an-incoming-webhook).
1. Choisissez un nom d'affichage, une description et un canal. Ces éléments peuvent être remplacés dans GitLab.
1. Enregistrez-le et copiez l'**URL du crochet Web** nécessaire pour GitLab.

Les webhooks entrants peuvent être bloqués sur votre instance Mattermost. Demandez à votre administrateur Mattermost de les activer dans :

- **Mattermost System Console** > **Intégrations** > **Gestion des intégrations** dans les versions 5.12 et ultérieures de Mattermost.
- **Mattermost System Console** > **Intégrations** > **Intégrations personnalisées** dans les versions 5.11 et antérieures de Mattermost.

Le remplacement du nom d'affichage est désactivé par défaut. Demandez à votre administrateur de l'activer dans cette même section.

## Configurer GitLab pour envoyer des notifications à Mattermost {#configure-gitlab-to-send-notifications-to-mattermost}

Une fois le webhook entrant configuré sur l'instance Mattermost, vous pouvez configurer GitLab pour envoyer les notifications :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Notifications Mattermost**.
1. Sélectionnez les événements GitLab pour lesquels générer des notifications. Pour chaque événement sélectionné, saisissez jusqu'à 10 canaux Mattermost devant recevoir la notification. Vous n'avez pas besoin d'ajouter le signe dièse (`#`).
1. Renseignez la configuration de l'intégration :

   - **Crochet Web** : L'URL du webhook entrant sur Mattermost, similaire à `http://mattermost.example/hooks/5xo…`.
   - **Nom d'utilisateur** : Facultatif. Le nom d'utilisateur affiché dans les messages envoyés à Mattermost. Pour modifier le nom d'utilisateur du bot, saisissez une valeur.
   - **Envoyer une notification uniquement pour les pipelines cassés** : si vous sélectionnez l'événement **Pipeline** et que vous souhaitez recevoir des notifications uniquement pour les pipelines en échec.
   - **Notifier uniquement en cas de changement de statut** : si vous sélectionnez l'événement **Pipeline** et que vous souhaitez recevoir des notifications uniquement lorsque le statut du pipeline change pour la référence concernée.
   - **Branches pour lesquelles des notifications doivent être envoyées** : les branches pour lesquelles envoyer des notifications.
   - **Labels devant faire l'objet d'une notification** : Facultatif. Labels requis pour que le ticket ou la merge request déclenche une notification. Laissez ce champ vide pour recevoir des notifications pour tous les tickets et toutes les merge requests.
   - **Comportement des labels devant faire l'objet d'une notification** : lorsque vous utilisez le filtre **Labels devant faire l'objet d'une notification**, les messages sont envoyés lorsqu'un ticket ou une merge request contient l'un des labels spécifiés dans le filtre. Vous pouvez également choisir de déclencher des messages uniquement lorsque le ticket ou la merge request contient tous les labels définis dans le filtre.
