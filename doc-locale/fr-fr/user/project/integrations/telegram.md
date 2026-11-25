---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Telegram
description: "Configurez l'intégration Telegram pour recevoir des notifications de GitLab dans des chats ou des canaux Telegram."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez configurer GitLab pour envoyer des notifications à un chat ou un canal Telegram. Pour configurer l'intégration Telegram, vous devez :

1. [Créer un bot Telegram](#create-a-telegram-bot).
1. [Configurer le bot Telegram](#configure-the-telegram-bot).
1. [Configurer l'intégration Telegram dans GitLab](#set-up-the-telegram-integration-in-gitlab).

## Créer un bot Telegram {#create-a-telegram-bot}

Pour créer un bot dans Telegram :

1. Démarrez une nouvelle conversation avec `@BotFather`.
1. [Créez un nouveau bot](https://core.telegram.org/bots/features#creating-a-new-bot) comme décrit dans la documentation Telegram.

Lorsque vous créez un bot, `BotFather` vous fournit un jeton d'API. Conservez ce jeton en lieu sûr, car vous en aurez besoin pour authentifier le bot dans Telegram.

## Configurer le bot Telegram {#configure-the-telegram-bot}

Pour configurer le bot dans Telegram :

1. Ajoutez le bot en tant qu'administrateur d'un canal nouveau ou existant.
1. Accordez au bot les droits `Post Messages` pour recevoir des événements.
1. Créez un identifiant pour le canal.
   - Pour les canaux publics, saisissez un lien public et copiez l'identifiant du canal (par exemple, `https://t.me/MY_IDENTIFIER`).
   - Pour les canaux privés, utilisez la méthode [`getUpdates`](https://telegram-bot-sdk.readme.io/reference/getupdates) avec votre jeton d'API et copiez l'identifiant du canal (par exemple, `-2241293890657`).

## Configurer l'intégration Telegram dans GitLab {#set-up-the-telegram-integration-in-gitlab}

{{< history >}}

- **Nom d'hôte** [introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/461313) dans GitLab 17.1.

{{< /history >}}

Prérequis :

- Accès administrateur pour activer l'intégration pour une instance.
- Le rôle Propriétaire pour activer l'intégration pour un groupe.
- Le rôle Chargé de maintenance ou Propriétaire pour activer l'intégration pour un projet.

Après avoir invité le bot dans un canal Telegram, vous pouvez configurer GitLab pour envoyer des notifications :

1. Pour activer l'intégration :
   - Pour votre groupe ou projet :
     1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
     1. Sélectionnez **Paramètres** > **Intégrations**.
   - Pour votre instance :
     1. Dans le coin supérieur droit, sélectionnez **Admin**.
     1. Sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Telegram**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Facultatif. Dans **Nom d'hôte**, saisissez le nom d'hôte de votre [serveur API de bot local](https://core.telegram.org/bots/api#using-a-local-bot-api-server).
1. Dans **Jeton**, [collez la valeur du jeton fournie par le bot Telegram](#create-a-telegram-bot).
1. Dans la section **Déclencheur**, cochez les cases correspondant aux événements GitLab que vous souhaitez recevoir dans Telegram.
1. Dans la section **Paramètres de notification** :
   - Dans **Identifiant du canal**, [collez l'identifiant du canal Telegram](#configure-the-telegram-bot).
   - Facultatif. Dans **ID du fil de discussion**, collez l'identifiant unique du fil de discussion cible (sujet dans un supergroupe forum).
   - Facultatif. Cochez la case **Envoyer une notification uniquement pour les pipelines cassés** pour ne recevoir des notifications que pour les pipelines en échec.
   - Facultatif. Cochez la case **Notifier uniquement en cas de changement de statut** pour ne recevoir des notifications que lorsque le statut du pipeline pour la référence change.
   - Facultatif. Dans la liste déroulante **Branches pour lesquelles des notifications doivent être envoyées**, sélectionnez les branches pour lesquelles vous souhaitez recevoir des notifications.
1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Le canal Telegram peut désormais recevoir tous les événements GitLab sélectionnés.
