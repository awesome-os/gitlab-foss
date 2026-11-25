---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Pumble
description: "Configurez GitLab pour envoyer des notifications à un canal Pumble."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez configurer GitLab pour envoyer des notifications à un canal Pumble :

1. Créez un webhook pour le canal.
1. Ajoutez le webhook à GitLab.

## Créer un webhook pour votre canal Pumble {#create-a-webhook-for-your-pumble-channel}

1. Suivez les étapes décrites dans [Incoming Webhooks for Pumble](https://pumble.com/help/integrations/add-pumble-apps/incoming-webhooks-for-pumble/) dans la documentation Pumble.
1. Copiez l'URL du webhook.

## Configurer les paramètres dans GitLab {#configure-settings-in-gitlab}

Prérequis :

- Accès administrateur pour activer l'intégration pour une instance.
- Le rôle Propriétaire pour activer l'intégration pour un groupe.
- Le rôle Chargé de maintenance ou Propriétaire pour activer l'intégration pour un projet.

Une fois que vous disposez d'une URL de webhook pour votre canal Pumble, configurez GitLab pour envoyer des notifications :

1. Pour activer l'intégration pour votre groupe ou projet :
   1. Dans votre groupe ou projet, dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Pour activer l'intégration pour votre instance :
   1. Dans le coin supérieur droit, sélectionnez **Admin**.
   1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez l'intégration **Pumble**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Cochez les cases correspondant aux événements GitLab que vous souhaitez recevoir dans Pumble.
1. Collez l'URL du **Crochet Web** pour le canal Pumble.
1. Configurez les options restantes.
1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Le canal Pumble commence à recevoir tous les événements GitLab applicables.
