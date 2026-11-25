---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Intégrations de projet
description: "Documentation utilisateur pour les intégrations de projet et de groupe. Inclut une liste des intégrations disponibles."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!note]
> Pour la documentation administrateur, consultez [l'administration des intégrations de projet](../../../administration/settings/project_integration_management.md).

Vous pouvez intégrer des applications externes pour ajouter des fonctionnalités à GitLab.

Vous pouvez afficher et gérer les intégrations pour les éléments suivants :

- [Instance](../../../administration/settings/project_integration_management.md#configure-default-settings-for-an-integration) (GitLab Self-Managed)
- [Groupe](#manage-group-default-settings-for-a-project-integration)

Vous pouvez utiliser :

- [Paramètres par défaut de l'instance ou du groupe pour une intégration de projet](#use-instance-or-group-default-settings-for-a-project-integration)
- [Paramètres personnalisés pour une intégration de projet ou de groupe](#use-custom-settings-for-a-project-or-group-integration)

## Gérer les paramètres par défaut du groupe pour une intégration de projet {#manage-group-default-settings-for-a-project-integration}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour gérer les paramètres par défaut du groupe pour une intégration de projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez une intégration.
1. Remplissez les champs.
1. Sélectionnez **Enregistrer les modifications**.

> [!warning]
> Cette opération peut affecter la totalité ou la plupart des sous-groupes et des projets appartenant au groupe. Consultez les détails ci-dessous.

S'il s'agit de la première fois que vous configurez les paramètres du groupe pour une intégration :

- L'intégration est activée pour tous les sous-groupes et projets appartenant au groupe qui n'ont pas encore cette intégration configurée, si vous avez activé le bouton bascule **Activer l'intégration** dans les paramètres du groupe.
- Les sous-groupes et projets qui ont déjà l'intégration configurée ne sont pas affectés, mais peuvent choisir d'utiliser les paramètres hérités à tout moment.

Lorsque vous apportez d'autres modifications aux valeurs par défaut du groupe :

- Elles sont immédiatement appliquées à tous les sous-groupes et projets appartenant au groupe dont l'intégration est configurée pour utiliser les paramètres par défaut.
- Elles sont immédiatement appliquées aux nouveaux sous-groupes et projets, même ceux créés après la dernière sauvegarde des valeurs par défaut pour l'intégration. Si le paramètre par défaut de votre groupe a le bouton bascule **Activer l'intégration** activé, l'intégration est automatiquement activée pour tous ces sous-groupes et projets.
- Les sous-groupes et projets dont des paramètres personnalisés sont sélectionnés pour l'intégration ne sont pas immédiatement affectés et peuvent choisir d'utiliser les dernières valeurs par défaut à tout moment.

Si des [paramètres d'instance](../../../administration/settings/project_integration_management.md#configure-default-settings-for-an-integration) ont également été configurés pour la même intégration, les projets du groupe héritent des paramètres du groupe.

Seuls l'ensemble des paramètres d'une intégration peuvent être hérités. L'héritage par champ est proposé dans l'[epic 2137](https://gitlab.com/groups/gitlab-org/-/work_items/2137).

### Supprimer un paramètre par défaut de groupe {#remove-a-group-default-setting}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour supprimer un paramètre par défaut de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez une intégration.
1. Sélectionnez **Réinitialiser** et confirmez.

La réinitialisation d'un paramètre par défaut de groupe supprime les intégrations qui utilisent les paramètres par défaut et appartiennent à un projet ou à un sous-groupe du groupe.

## Utiliser les paramètres par défaut de l'instance ou du groupe pour une intégration de projet {#use-instance-or-group-default-settings-for-a-project-integration}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.

Pour utiliser les paramètres par défaut de l'instance ou du groupe pour une intégration de projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez une intégration.
1. Sur la droite, dans la liste déroulante, sélectionnez **Utiliser les paramètres par défaut**.
1. Sous **Activer l'intégration**, assurez-vous que la case **Actif** est cochée.
1. Remplissez les champs.
1. Sélectionnez **Enregistrer les modifications**.

## Utiliser des paramètres personnalisés pour une intégration de projet ou de groupe {#use-custom-settings-for-a-project-or-group-integration}

Prérequis :

- Vous devez disposer du rôle Maintainer ou Owner pour l'intégration de projet.
- Vous devez disposer du rôle Owner pour l'intégration de groupe.

Pour utiliser des paramètres personnalisés pour une intégration de projet ou de groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez une intégration.
1. Sur la droite, dans la liste déroulante, sélectionnez **Utiliser des paramètres personnalisés**.
1. Sous **Activer l'intégration**, assurez-vous que la case **Actif** est cochée.
1. Remplissez les champs.
1. Sélectionnez **Enregistrer les modifications**.

## Intégrations disponibles {#available-integrations}

Les intégrations suivantes peuvent être disponibles sur une instance GitLab. Si un administrateur d'instance a configuré une [liste d'autorisation d'intégrations](../../../administration/settings/project_integration_management.md#integration-allowlist), seules ces intégrations sont disponibles.

### CI/CD {#cicd}

| Intégration                                | Description                                | Hooks d'intégration |
|--------------------------------------------|--------------------------------------------|-------------------|
| [Atlassian Bamboo](bamboo.md)              | Exécuter des pipelines CI/CD avec Atlassian Bamboo. | {{< yes >}}       |
| Buildkite                                  | Exécuter des pipelines CI/CD avec Buildkite.        | {{< yes >}}       |
| Drone                                      | Exécuter des pipelines CI/CD avec Drone.            | {{< yes >}}       |
| [Jenkins](../../../integration/jenkins.md) | Exécuter des pipelines CI/CD avec Jenkins.          | {{< yes >}}       |
| JetBrains TeamCity                         | Exécuter des pipelines CI/CD avec TeamCity.         | {{< yes >}}       |

### Notifications d'événements {#event-notifications}

Aucune de ces intégrations ne dispose de hooks d'intégration.

| Intégration                                         | Description                                                            |
|-----------------------------------------------------|------------------------------------------------------------------------|
| Campfire                                            | Connecter Campfire au chat.                                              |
| [Discord Notifications](discord_notifications.md)   | Envoyer des notifications sur les événements de projet vers un canal Discord.          |
| [Google Chat](hangouts_chat.md)                     | Envoyer des notifications depuis votre projet GitLab vers un espace dans Google Chat. |
| [irker (passerelle IRC)](irker.md)                     | Envoyer des notifications d'événements vers des canaux IRC.                              |
| [Notifications Matrix](matrix.md)                   | Envoyer des notifications sur les événements de projet vers Matrix.                     |
| [Notifications Mattermost](mattermost.md)           | Envoyer des notifications sur les événements de projet vers des canaux Mattermost.        |
| [Notifications Microsoft Teams](microsoft_teams.md) | Envoyer des notifications d'événements vers Microsoft Teams.                           |
| [Pumble](pumble.md)                                 | Envoyer des notifications d'événements vers un canal Pumble.                          |
| Pushover                                            | Envoyer des notifications d'événements vers votre appareil.                               |
| [Telegram](telegram.md)                             | Envoyer des notifications sur les événements de projet vers Telegram.                   |
| [Unify Circuit](unify_circuit.md)                   | Envoyer des notifications sur les événements de projet vers Unify Circuit.              |
| [Webex Teams](webex_teams.md)                       | Envoyer des notifications d'événements vers Webex Teams.                               |

### Magasins {#stores}

| Intégration                                   | Description                                                    | Hooks d'intégration |
|-----------------------------------------------|----------------------------------------------------------------|-------------------|
| [Apple App Store Connect](apple_app_store.md) | Utiliser GitLab pour créer et publier une application dans l'Apple App Store. | {{< no >}}        |
| [Google Play](google_play.md)                 | Utiliser GitLab pour créer et publier une application dans Google Play.         | {{< no >}}        |
| [Harbor](harbor.md)                           | Utiliser Harbor comme registre de conteneurs pour GitLab.               | {{< no >}}        |
| Packagist                                     | Mettre à jour vos dépendances PHP dans Packagist.                     | {{< yes >}}       |

### Gestionnaires de tickets externes {#external-issue-trackers}

Les intégrations suivantes ajoutent des liens vers des [gestionnaires de tickets externes](../../../integration/external-issue-tracker.md) dans la barre latérale gauche de votre projet. Aucune de ces intégrations ne dispose de hooks d'intégration.

| Intégration                                     | Description                                             | Synchronisation des tickets  | Peut créer de nouveaux tickets |
|-------------------------------------------------|---------------------------------------------------------|-------------|-----------------------|
| [Bugzilla](bugzilla.md)                         | Utiliser Bugzilla comme gestionnaire de tickets.                       | {{< no >}}  | {{< yes >}}           |
| [ClickUp](clickup.md)                           | Utiliser ClickUp comme gestionnaire de tickets.                        | {{< no >}}  | {{< no >}}            |
| [Gestionnaire de tickets personnalisé](custom_issue_tracker.md) | Utiliser un gestionnaire de tickets personnalisé.                             | {{< no >}}  | {{< no >}}            |
| [Engineering Workflow Management (EWM)](ewm.md) | Utiliser EWM comme gestionnaire de tickets.                            | {{< no >}}  | {{< yes >}}           |
| [Linear](linear.md)                             | Utiliser Linear comme gestionnaire de tickets.                         | {{< no >}}  | {{< no >}}            |
| [Phorge](phorge.md)                             | Utiliser Phorge comme gestionnaire de tickets.                         | {{< no >}}  | {{< yes >}}           |
| [Redmine](redmine.md)                           | Utiliser Redmine comme gestionnaire de tickets.                        | {{< no >}}  | {{< yes >}}           |
| [YouTrack](youtrack.md)                         | Utiliser JetBrains YouTrack comme gestionnaire de tickets de votre projet. | {{< yes >}} | {{< no >}}            |

### Wikis externes {#external-wikis}

Les intégrations suivantes ajoutent des liens vers des wikis externes dans la barre latérale gauche de votre projet. Aucune de ces intégrations ne dispose de hooks d'intégration.

| Intégration                                              | Description                                         |
|----------------------------------------------------------|-----------------------------------------------------|
| [Confluence Workspace](confluence.md)                    | Utiliser Confluence Cloud Workspace comme wiki interne. |
| [Wiki externe](../wiki/_index.md#link-an-external-wiki) | Lier un wiki externe.                              |

### Autres {#other}

| Intégration                                                  | Description                                                                              | Hooks d'intégration |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------- | ----------------- |
| [Asana](asana.md)                                            | Ajouter des messages de commit en tant que commentaires dans les tâches Asana.                                          | {{< no >}} |
| Assembla                                                     | Gérer des projets avec Assembla.                                                           | {{< no >}} |
| [Beyond Identity](beyond_identity.md)                        | Vérifier que les clés GPG sont autorisées par Beyond Identity Authenticator.                    | {{< no >}} |
| [Datadog](../../../integration/datadog.md)                   | Tracer vos pipelines GitLab avec Datadog.                                                | {{< yes >}} |
| [Diffblue Cover](../../../integration/diffblue_cover.md)     | Écrire automatiquement des tests unitaires Java complets et similaires à ceux écrits par des humains.                           | {{< yes >}} |
| [E-mails lors d'un push](emails_on_push.md)                          | Envoyer des commits et des diffs lors d'un push par e-mail.                                                 | {{< no >}} |
| [GitGuardian](git_guardian.md)                               | Rejeter des commits en fonction des politiques GitGuardian.                                            | {{< no >}} |
| [GitHub](github.md)                                          | Recevoir des statuts pour les commits et les pull requests.                                          | {{< no >}} |
| [Application GitLab pour Slack](gitlab_slack_application.md)          | Utiliser l'application Slack native pour recevoir des notifications et exécuter des commandes.                      | {{< no >}} |
| [Google Artifact Management](google_artifact_management.md)  | Gérer vos artefacts dans Google Artifact Registry.                                       | {{< no >}} |
| [Google Cloud IAM](../../../integration/google_cloud_iam.md) | Gérer les autorisations pour les ressources Google Cloud avec Identity and Access Management (IAM). | {{< no >}} |
| [Jira](../../../integration/jira/_index.md)                  | Utiliser Jira comme gestionnaire de tickets.                                                            | {{< no >}} |
| [Commandes slash Mattermost](mattermost_slash_commands.md)    | Exécuter des commandes slash depuis un environnement de chat Mattermost.                                   | {{< no >}} |
| [E-mails de statut de pipeline](pipeline_status_emails.md)          | Envoyer le statut du pipeline à une liste de destinataires par e-mail.                               | {{< no >}} |
| [Pivotal Tracker](pivotal_tracker.md)                        | Ajouter des messages de commit en tant que commentaires dans les stories Pivotal Tracker.                              | {{< no >}} |
| [Squash TM](squash_tm.md)                                    | Mettre à jour les exigences Squash TM lorsque des tickets GitLab sont modifiés.                           | {{< yes >}} |

## Webhooks de projet {#project-webhooks}

Certaines intégrations utilisent des [webhooks](webhooks.md) pour des applications externes.

Vous pouvez configurer un webhook de projet pour écouter des événements spécifiques tels que des pushs, des tickets ou des merge requests. Lorsque le webhook est déclenché, GitLab envoie une requête POST avec des données vers l'URL de webhook spécifiée.

Pour obtenir la liste des intégrations qui utilisent des webhooks, consultez [Intégrations disponibles](#available-integrations).

## Limite des hooks de push {#push-hook-limit}

Si un seul push inclut des modifications sur plus de trois branches ou tags, les intégrations prises en charge par les événements `push_hooks` et `tag_push_hooks` ne sont pas exécutées.

Pour modifier le nombre de branches ou de tags pris en charge, configurez le [paramètre `push_event_hooks_limit`](../../../api/settings.md#available-settings).

## Vérification SSL {#ssl-verification}

Par défaut, le certificat SSL pour les requêtes HTTP sortantes est vérifié sur la base d'une liste interne d'autorités de certification. Le certificat SSL ne peut pas être auto-signé.

Vous pouvez désactiver la vérification SSL lorsque vous configurez des [webhooks](webhooks.md#configure-webhooks) et certaines intégrations.

## Sujets connexes {#related-topics}

- [API des intégrations](../../../api/project_integrations.md)
- [Portail développeur GitLab](https://developer.gitlab.com)
