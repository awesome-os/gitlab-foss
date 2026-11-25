---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Notifications Microsoft Teams
description: "Configurez l'intégration Microsoft Teams pour recevoir des notifications de GitLab dans Microsoft Teams."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Vous pouvez intégrer les notifications Microsoft Teams à GitLab et afficher des notifications concernant les projets GitLab dans Microsoft Teams. Pour intégrer les services, vous devez :

1. [Configurer Microsoft Teams](#configure-microsoft-teams) pour ajouter un webhook qui surveille les modifications.
1. [Configurer votre projet GitLab](#configure-your-gitlab-project) pour envoyer des notifications au webhook Microsoft Teams.

## Configurer Microsoft Teams {#configure-microsoft-teams}

> [!warning]
> Microsoft a [annoncé](https://devblogs.microsoft.com/microsoft365dev/retirement-of-office-365-connectors-within-microsoft-teams/) le retrait des connecteurs Office 365 dans Microsoft Teams. Les nouvelles intégrations doivent utiliser les workflows Power Automate. Les intégrations existantes basées sur des connecteurs doivent être migrées avant décembre 2025.

Pour configurer Microsoft Teams afin de recevoir des notifications de GitLab, vous devez disposer d'un workflow qui accepte le contenu du webhook GitLab et publie des messages dans votre canal. Vous pouvez créer :

- Un workflow Power Automate à l'aide d'un modèle.
- Un workflow personnalisé.

### Créer un workflow Power Automate {#create-a-power-automate-workflow}

1. Dans Microsoft Teams, à côté du chat dans lequel vous souhaitez recevoir des notifications, sélectionnez **Autres options de chat** ({{< icon name="ellipsis_h" >}}).
1. Sélectionnez **Workflows**.
1. Recherchez et sélectionnez le modèle de workflow **Envoyer des alertes webhook à un canal**.
1. Sous **Paramètres**, saisissez l'équipe et le canal, puis sélectionnez **Sauvegarder**.
1. Une fois le workflow créé, dans la boîte de dialogue Workflows, sélectionnez **Copier le lien du webhook**.
1. Copiez l'URL du webhook fournie. Vous utilisez cette URL de webhook pour configurer GitLab.
1. Fermez la boîte de dialogue Workflows.

#### Modifier le workflow pour accepter les payloads GitLab {#modify-the-workflow-to-accept-gitlab-payloads}

Le modèle de workflow par défaut attend le format Adaptive Card, mais GitLab envoie le format Office 365 Connector Card. Pour modifier le workflow :

1. Accédez à Power Automate et connectez-vous avec votre compte Microsoft.
1. Sélectionnez **Mes flows** et trouvez le workflow que vous avez créé.
1. Sélectionnez **Modifier** pour modifier le workflow.
1. Sélectionnez l'action existante **Publier une carte dans une conversation ou un canal** et supprimez-la.
1. Sélectionnez **Ajouter une action** et recherchez **Publier un message dans une conversation ou un canal**.
1. Configurez l'action :
   - **Publier en tant que** : Flow bot
   - **Publier dans** : Canal
   - **Équipe** : sélectionnez votre équipe
   - **Canal** : sélectionnez votre canal
   - **Message** : à droite de la zone de texte, sélectionnez **Insérer une expression** et saisissez `triggerOutputs()?['body']?['attachments'][0]?['content']`. Sélectionnez **Ajouter**.
1. Sélectionnez **Enregistrer**.

### Créer un workflow personnalisé {#create-a-custom-workflow}

Pour plus de contrôle sur le format du message, créez un workflow personnalisé :

1. Accédez à Power Automate et sélectionnez **Créer** > **Flux de cloud instantané**.
1. Nommez votre workflow et sélectionnez **Lors de la réception d’une requête HTTP** comme déclencheur, puis sélectionnez **Créer**.
1. Sélectionnez **Ajouter une action** et recherchez **Publier un message dans une conversation ou un canal** (Microsoft Teams).
1. Dans la configuration du déclencheur, laissez le schéma JSON vide pour accepter tout payload.
1. Configurez l'action :
   - **Publier en tant que** : Flow bot
   - **Publier dans** : Canal
   - **Équipe** : sélectionnez votre équipe
   - **Canal** : sélectionnez votre canal
   - **Message** : à droite de la zone de texte, sélectionnez **Insérer une expression** et saisissez `triggerOutputs()?['body']?['attachments'][0]?['content']`. Sélectionnez **Ajouter**.
1. Sélectionnez **Enregistrer**.
1. Dans le workflow, sélectionnez le déclencheur **manuel**. Copiez l'**URL HTTP** depuis le déclencheur. Vous utilisez cette URL pour configurer GitLab.

## Configurer votre projet GitLab {#configure-your-gitlab-project}

Après avoir configuré Microsoft Teams pour recevoir des notifications, vous devez configurer GitLab pour envoyer les notifications :

1. Connectez-vous à GitLab en tant qu'administrateur.
1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Microsoft Teams notifications**.
1. Pour activer l'intégration, sélectionnez **Actif**.
1. Dans la section **Déclencheur**, cochez la case en regard de chaque événement souhaité :
   - Push
   - Ticket
   - Ticket confidentiel
   - Demande de fusion
   - Note
   - Note confidentielle
   - Push de tag
   - Pipeline
   - Page wiki
1. Dans **Crochet Web**, collez l'URL que vous avez copiée lors de la création d'un workflow Power Automate ou personnalisé.
1. Facultatif. Si vous sélectionnez le déclencheur de pipeline, cochez la case **Envoyer une notification uniquement pour les pipelines cassés** pour envoyer des notifications uniquement lorsque des pipelines échouent.
1. Facultatif. Si vous sélectionnez le déclencheur de pipeline, cochez la case **Notifier uniquement en cas de changement d’état** pour envoyer des notifications uniquement lorsque le statut du pipeline pour la référence change.
1. Sélectionnez les branches pour lesquelles vous souhaitez envoyer des notifications.
1. Sélectionnez **Enregistrer les modifications**.

## Sujets connexes {#related-topics}

- [Documentation Microsoft Power Automate](https://learn.microsoft.com/en-us/power-automate/)
- [Documentation Microsoft Teams sur la création de webhooks entrants](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)
