---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Notifications Slack (obsolète)
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!warning]
> Cette fonctionnalité a été [dépréciée](https://gitlab.com/gitlab-org/gitlab/-/issues/435909) dans GitLab 15.9. Utilisez plutôt l'[application GitLab pour Slack](gitlab_slack_application.md).

L'intégration des notifications Slack permet à votre projet GitLab d'envoyer des événements (tels que la création de tickets) à votre équipe Slack existante sous forme de notifications. La configuration des notifications Slack nécessite des modifications de configuration à la fois dans Slack et dans GitLab.

## Configurer Slack {#configure-slack}

1. Connectez-vous à votre équipe Slack et [démarrez une nouvelle configuration Incoming WebHooks](https://my.slack.com/services/new/incoming-webhook).
1. Identifiez le canal Slack vers lequel les notifications doivent être envoyées par défaut. Sélectionnez **Ajouter une intégration de webhook entrant** pour ajouter la configuration.
1. Copiez l'**URL du crochet Web** pour l'utiliser ultérieurement lors de la configuration de GitLab.

## Configurer GitLab {#configure-gitlab}

{{< history >}}

- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/106760) dans GitLab 15.9 pour limiter les canaux Slack à 10 par événement.
- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/254341) dans GitLab 19.5 pour masquer l'intégration pour les projets qui ne l'ont jamais utilisée.

{{< /history >}}

L'intégration **Notifications Slack** est masquée dans la liste **Paramètres** > **Intégrations** d'un projet lorsque toutes les conditions suivantes sont remplies :

- L'application GitLab pour Slack est activée pour l'instance, de sorte qu'une intégration de remplacement est disponible.
- Le projet ne dispose pas de sa propre intégration de notifications Slack.
- Le projet n'hérite pas d'une intégration de notifications Slack au niveau de l'instance.

Un projet qui a déjà des notifications Slack configurées continue de les voir dans la liste. Il en va de même pour un projet qui hérite d'une intégration au niveau de l'instance. Dans les deux cas, GitLab continue d'envoyer les notifications comme auparavant.

Pour configurer les notifications Slack :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Notifications Slack**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Dans la section **Déclencheur**, cochez les cases correspondant à chaque type d'événement GitLab à envoyer à Slack sous forme de notification. Pour une liste complète, consultez les [déclencheurs pour les notifications Slack](#triggers-for-slack-notifications). Par défaut, les messages sont envoyés au canal que vous avez configuré lors de la [configuration de Slack](#configure-slack).
1. Facultatif. Pour envoyer des messages à un canal différent, à plusieurs canaux, ou sous forme de message direct :
   - *Pour envoyer des messages à des canaux,* saisissez les noms des canaux Slack, séparés par des virgules.
   - *Pour envoyer des messages directs,* utilisez l'identifiant de membre trouvé dans le profil Slack de l'utilisateur.
1. Dans **Crochet Web**, saisissez l'URL du webhook que vous avez copiée lors de l'étape de [configuration de Slack](#configure-slack).
1. Facultatif. Dans **Nom d'utilisateur**, saisissez le nom d'utilisateur du bot Slack qui envoie les notifications.
1. Cochez la case **Envoyer une notification uniquement pour les pipelines cassés** pour ne recevoir des notifications qu'en cas d'échec.
1. Cochez la case **Envoyer une notification uniquement en cas de changement de statut** pour envoyer des notifications uniquement lorsque le statut du pipeline pour la référence change.
1. Dans la liste déroulante **Branches pour lesquelles des notifications doivent être envoyées**, sélectionnez les types de branches pour lesquels envoyer des notifications.
1. Laissez le champ **Labels à notifier** vide pour recevoir toutes les notifications, ou ajoutez des labels que le ticket ou la merge request doit avoir pour déclencher une notification.
1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Votre équipe Slack commence maintenant à recevoir les notifications d'événements GitLab telles que configurées.

## Déclencheurs pour les notifications Slack {#triggers-for-slack-notifications}

Les déclencheurs suivants sont disponibles pour les notifications Slack :

| Nom du déclencheur                                                              | Événement déclencheur |
| ------------------------------------------------------------------------- | ------------- |
| **Push**                                                                  | Une poussée vers le dépôt. |
| **Ticket**                                                                 | Un élément de travail est créé, fermé ou rouvert. |
| **Incident**                                                              | Un incident est créé, fermé ou rouvert. |
| **Ticket confidentiel**                                                    | Un élément de travail confidentiel est créé, fermé ou rouvert. |
| **Demande de fusion**                                                         | Une merge request est créée, fusionnée, approuvée, fermée ou rouverte. |
| **Note**                                                                  | Un commentaire est ajouté. |
| **Note confidentielle**                                                     | Une note interne ou un commentaire sur un élément de travail confidentiel est ajouté. |
| **Poussée d'étiquette**                                                              | Une nouvelle étiquette est poussée vers le dépôt ou supprimée. |
| **Pipeline**                                                              | Le statut d'un pipeline a changé. |
| **Page Wiki**                                                             | Une page wiki est créée ou mise à jour. |
| **Déploiement**                                                            | Un déploiement démarre ou se termine. |
| **Alerte**                                                                 | Une nouvelle alerte unique est enregistrée. |
| **[Mention de groupe](#trigger-notifications-for-group-mentions) en public**  | Un groupe est mentionné dans un contexte public. |
| **[Mention de groupe](#trigger-notifications-for-group-mentions) en privé** | Un groupe est mentionné dans un contexte confidentiel. |
| [**Vulnérabilité**](../../application_security/vulnerabilities/_index.md) | Une nouvelle vulnérabilité unique est enregistrée. |

## Déclencher des notifications pour les mentions de groupe {#trigger-notifications-for-group-mentions}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/417751) dans GitLab 16.4.
- Les restrictions sur les déclencheurs de notification [introduites](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/134677) dans GitLab 18.3 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `group_mention_access_check`. Fonctionnalité désactivée par défaut.

{{< /history >}}

Pour déclencher un [événement de notification](#triggers-for-slack-notifications) pour une mention de groupe, utilisez `@<group_name>` dans :

- Descriptions des tickets et des merge requests
- Commentaires sur les tickets, les merge requests et les commits

Les notifications ne sont déclenchées que si tous les membres directs du groupe ont l'autorisation de consulter la ressource (par exemple, la merge request) où la mention est effectuée. Une notification sera envoyée à au maximum 3 groupes par événement.

## Dépannage {#troubleshooting}

Si votre intégration Slack ne fonctionne pas, commencez le dépannage en recherchant dans les [journaux Sidekiq](../../../administration/logs/_index.md#sidekiqlog) les erreurs liées à votre service Slack.

### Erreur : `Something went wrong on our end` {#error-something-went-wrong-on-our-end}

Ce message d'erreur générique peut s'afficher dans l'interface GitLab. Consultez [les journaux](../../../administration/logs/_index.md#productionlog) pour trouver le message d'erreur et poursuivre le dépannage à partir de là.

### Erreur : `certificate verify failed` {#error-certificate-verify-failed}

Vous pourriez voir une entrée semblable à la suivante dans votre journal Sidekiq :

```plaintext
2019-01-10_13:22:08.42572 2019-01-10T13:22:08.425Z 6877 TID-abcdefg Integrations::ExecuteWorker JID-3bade5fb3dd47a85db6d78c5 ERROR: {:class=>"Integrations::ExecuteWorker :integration_class=>"SlackService", :message=>"SSL_connect returned=1 errno=0 state=error: certificate verify failed"}
```

Ce problème survient lorsqu'il y a un problème de communication entre GitLab et Slack, ou entre GitLab et lui-même. Le premier cas est moins probable, car les certificats de sécurité de Slack devraient toujours être approuvés.

Pour déterminer lequel de ces problèmes est à l'origine du problème :

1. Démarrez une console Rails :

   ```shell
   sudo gitlab-rails console -e production

   # for source installs:
   bundle exec rails console -e production
   ```

1. Exécutez les commandes suivantes :

   ```ruby
   # replace <SLACK URL> with your actual Slack URL
   result = Net::HTTP.get(URI('https://<SLACK URL>'));0

   # replace <GITLAB URL> with your actual GitLab URL
   result = Net::HTTP.get(URI('https://<GITLAB URL>'));0
   ```

Si GitLab ne fait pas confiance aux connexions HTTPS à lui-même, [ajoutez votre certificat aux certificats de confiance de GitLab](https://docs.gitlab.com/omnibus/settings/ssl/#install-custom-public-certificates).

Si GitLab ne fait pas confiance aux connexions à Slack, le magasin de confiance OpenSSL de GitLab est incorrect. Les causes habituelles sont :

- Remplacement du magasin de confiance avec `gitlab_rails['env'] = {"SSL_CERT_FILE" => "/path/to/file.pem"}`.
- Modification accidentelle du bundle CA par défaut `/opt/gitlab/embedded/ssl/certs/cacert.pem`.

### Mise à jour en masse pour désactiver l'intégration de notifications Slack {#bulk-update-to-disable-the-slack-notification-integration}

Pour désactiver les notifications pour tous les projets pour lesquels l'intégration Slack est activée, [démarrez une session de console Rails](../../../administration/operations/rails_console.md#starting-a-rails-console-session) et utilisez un script similaire au suivant :

> [!warning]
> Les commandes qui modifient des données peuvent causer des dommages si elles ne sont pas exécutées correctement ou dans les bonnes conditions. Exécutez toujours les commandes dans un environnement de test en premier et disposez d'une instance de sauvegarde prête à être restaurée.

```ruby
# Grab all projects that have the Slack notifications enabled
p = Project.find_by_sql("SELECT p.id FROM projects p LEFT JOIN integrations s ON p.id = s.project_id WHERE s.type_new = 'Integrations::Slack' AND s.active = true")

# Disable the integration on each of the projects that were found.
p.each do |project|
  project.slack_integration.update!(:active, false)
end
```
