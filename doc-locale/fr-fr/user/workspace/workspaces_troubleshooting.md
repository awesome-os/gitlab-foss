---
stage: Create
group: Remote Development
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Créez un proxy de workspaces GitLab pour authentifier et autoriser les workspaces dans votre cluster.
title: Dépannage des workspaces
---

Lorsque vous utilisez des workspaces GitLab, vous pouvez rencontrer les problèmes suivants.

## Erreur : `Failed to renew lease` {#error-failed-to-renew-lease}

Lors de la création d'un workspace, vous pouvez rencontrer le message d'erreur suivant dans le journal de l'agent :

```plaintext
{"level":"info","time":"2023-01-01T00:00:00.000Z","msg":"failed to renew lease gitlab-agent-remote-dev-dev/agent-123XX-lock: timed out waiting for the condition\n","agent_id":XXXX}
```

Cette erreur est due à un problème connu dans l'agent GitLab pour Kubernetes. Cette erreur se produit lorsqu'une instance d'agent ne peut pas renouveler son bail de leadership, ce qui entraîne l'arrêt des modules réservés au leader, comme `remote_development`.

Pour résoudre ce problème :

1. Redémarrez l'instance d'agent.
1. Si le problème persiste, vérifiez l'état de santé et la connectivité de votre cluster Kubernetes.

## Erreur : `Workspace create failed: Expiration date must be before <date>` {#error-workspace-create-failed-expiration-date-must-be-before-date}

Lors de la création d'un workspace, vous pouvez rencontrer cette erreur dans l'interface utilisateur :

```plaintext
Workspace create failed: Expiration date must be before <date>
```

Cette erreur se produit lorsque le [jeton d'accès personnel créé pour l'authentification](_index.md#personal-access-token) au workspace nouvellement créé a une date d'expiration qui dépasse le paramètre d'instance pour l'expiration des jetons.

Pour résoudre ce problème, désactivez la [limite d'expiration des jetons d'accès pour l'instance](../../administration/settings/account_and_limit_settings.md#limit-the-lifetime-of-access-tokens). Le [ticket 579331](https://gitlab.com/gitlab-org/gitlab/-/work_items/579331) propose une limite configurable pour les jetons liés aux workspaces afin de remédier à cette limitation.

## Erreur : `No agents available to create workspaces` {#error-no-agents-available-to-create-workspaces}

Lorsque vous créez un workspace dans un projet, vous pouvez obtenir l'erreur suivante :

```plaintext
No agents available to create workspaces. Please consult Workspaces documentation for troubleshooting.
```

Cette erreur peut se produire pour plusieurs raisons. Suivez les étapes de dépannage ci-dessous.

### Vérifier les permissions {#check-permissions}

1. Assurez-vous de disposer du rôle Développeur, Mainteneur ou Propriétaire pour le projet workspace et le projet d'agent.
1. Vérifiez que l'agent est autorisé dans un groupe ancêtre de votre projet workspace.

Pour plus d'informations, voir [autoriser un agent](gitlab_agent_configuration.md#allow-a-cluster-agent-for-workspaces-in-a-group).

### Vérifier la configuration de l'agent {#check-agent-configuration}

Vérifiez que le module `remote_development` est activé dans la configuration de votre agent :

   ```yaml
   remote_development:
     enabled: true
   ```

Si le module `remote_development` est désactivé pour l'agent GitLab pour Kubernetes, définissez [`enabled`](settings.md#enabled) sur `true`.

### Vérifier la non-concordance du nom de l'agent {#check-agent-name-mismatch}

Assurez-vous que le nom d'agent que vous avez créé à l'étape [Créer un jeton d'agent GitLab pour Kubernetes](set_up_infrastructure.md#create-a-gitlab-agent-for-kubernetes-token) correspond au nom du dossier dans `.gitlab/agents/FOLDER_NAME/`.

Si les noms sont différents, renommez le dossier pour qu'il corresponde exactement au nom de l'agent.

### Vérifier le statut de connexion de l'agent {#check-agent-connection-status}

Vérifiez que l'agent est connecté à GitLab :

1. Accédez à votre groupe.
1. Sélectionnez **Opération** > **Clusters Kubernetes**.
1. Vérifiez si l'**État de la connexion** est **Connectés**. Si l'agent n'est pas connecté, consultez les journaux de l'agent :

   ```shell
   kubectl logs -f -l app=gitlab-agent -n gitlab-workspaces
   ```

## Erreur : `unsupported scheme in kas address` {#error-unsupported-scheme-in-kas-address}

Cette erreur se produit lorsque l'adresse GitLab Relay (KAS) ne contient pas le schéma de protocole requis.

Pour résoudre ce problème :

1. Ajoutez le préfixe `grpcs://` ou `wss://` à votre variable `TF_VAR_kas_address`. Par exemple : `grpcs://kas.gitlab.com`.
1. Mettez à jour votre configuration et redéployez l'agent.

## Erreur : `ImagePullBackOff` lors du démarrage d'un workspace dans un environnement hors connexion {#error-imagepullbackoff-when-starting-workspace-in-offline-environment}

Lorsque vous créez un workspace dans un environnement hors connexion, vous pouvez voir cette erreur :

```plaintext
workspace-example-abc123-def456   0/1   Init:ImagePullBackOff   0
```

Cette erreur se produit lorsque le workspace ne peut pas extraire les images de conteneur d'initialisation depuis `registry.gitlab.com`. Dans les environnements hors connexion, l'image du conteneur d'initialisation est codée en dur et ne peut pas être remplacée depuis votre devfile.

> [!warning]
> La solution de contournement suivante n'est pas prise en charge et est temporaire. Utilisez-la à vos propres risques jusqu'à ce que le [ticket 509983](https://gitlab.com/gitlab-org/gitlab/-/issues/509983) fournisse une solution prise en charge.

La solution de contournement est la suivante :

1. Déployez un [webhook de mutation Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) pour modifier les références d'images de conteneur d'initialisation.
1. Assurez-vous de disposer des privilèges d'administrateur de cluster pour créer, mettre à jour ou supprimer le `MutatingWebhookConfiguration`.

Pour un exemple d'implémentation, voir [A Simple Kubernetes Admission Webhook](https://slack.engineering/simple-kubernetes-webhook/).

## Erreur : `redirect URI included is not valid` {#error-redirect-uri-included-is-not-valid}

Lors de l'accès à un workspace, vous pouvez rencontrer une erreur OAuth concernant un URI de redirection non valide.

Cette erreur peut se produire pour les raisons suivantes :

- L'application OAuth n'est pas configurée correctement. Pour résoudre ce problème :
  1. Vérifiez que l'URI de redirection de votre application OAuth dans GitLab correspond à votre domaine.
  1. Mettez à jour l'URI de redirection de l'application OAuth. Par exemple : `https://YOUR_DOMAIN/auth/callback`.
- Le proxy de workspaces utilise des identifiants OAuth obsolètes. Pour résoudre ce problème :
  1. Vérifiez que le proxy utilise les derniers identifiants OAuth.
  1. Redémarrez le proxy de workspaces :

     ```shell
     kubectl rollout restart deployment -n gitlab-workspaces gitlab-workspaces-proxy
     ```

## Erreur : `Workspace does not exist` {#error-workspace-does-not-exist}

Vous pouvez obtenir une erreur dans VS Code indiquant

```plaintext
Workspace does not exist

Please select another workspace to open.
```

Ce problème se produit lorsque le workspace démarre correctement, mais que le répertoire de projet attendu est manquant car l'opération de clonage Git a échoué. Les opérations de clonage Git échouent en raison de problèmes réseau, de problèmes d'infrastructure ou de permissions de dépôt révoquées.

Pour résoudre ce problème :

1. Lorsque vous êtes invité à sélectionner un autre workspace dans la boîte de dialogue d'erreur, sélectionnez **Annuler**.
1. Dans le menu VS Code, sélectionnez **Fichier** > **Ouvrir le dossier**.
1. Accédez au répertoire `/projects` et sélectionnez **OK**.
1. Dans le panneau **EXPLORER**, recherchez un répertoire portant le même nom que votre projet.
   - Si le répertoire est manquant, l'opération de clonage Git a complètement échoué.
   - Si le répertoire existe mais est vide, l'opération de clonage a démarré mais ne s'est pas terminée.
1. Ouvrez un terminal. Dans le menu, sélectionnez **Terminal** > **Nouveau terminal**.
1. Accédez au répertoire des journaux du workspace :

   ```shell
   cd /tmp/workspace-logs/
   ```

1. Consultez les journaux pour détecter les erreurs pouvant indiquer pourquoi le clonage Git a échoué :

   ```shell
   less poststart-stderr.log
   ```

1. Résolvez le problème identifié et redémarrez votre workspace.

Si le problème persiste, créez un nouveau workspace avec une image de conteneur fonctionnelle incluant Git.

## Déboguer les événements `postStart` {#debug-poststart-events}

Lorsque vos événements `postStart` personnalisés échouent ou ne se comportent pas comme prévu, vous pouvez utiliser le répertoire des journaux du workspace pour déboguer les problèmes.

Scénarios de débogage `postStart` courants et leurs résolutions :

- `Command not found` : consultez `poststart-stderr.log` pour détecter les erreurs indiquant des dépendances manquantes dans votre image de conteneur.
- `Permission denied` : recherchez les erreurs de permission dans `poststart-stderr.log` qui pourraient nécessiter d'ajuster les permissions de fichiers ou la configuration utilisateur.
- `Network issues` : vérifiez les délais de connexion ou les échecs de résolution DNS lorsque vos événements `postStart` téléchargent des dépendances ou accèdent à des ressources externes.
- `Long-running commands` : si les événements `postStart` se bloquent, consultez `poststart-stdout.log` pour voir si les commandes sont toujours en cours d'exécution ou si elles se sont terminées avec succès.

Pour consulter les journaux d'exécution de la commande `postStart` :

1. Ouvrez un terminal dans votre workspace.
1. Accédez au répertoire des journaux du workspace :

   ```shell
   cd /tmp/workspace-logs/
   ```

1. Consultez les fichiers journaux :

   ```shell
   # Monitor postStart execution output in real-time
   tail -f poststart-stdout.log

   # Check postStart errors
   cat poststart-stderr.log

   # Check VS Code server startup
   cat start-vscode.log
   ```

1. Vérifiez les erreurs :

   ```shell
   # Search for error messages across all logs
   grep -i error *.log

   # Search for specific command output
   grep "your-command-name" poststart-stdout.log
   ```

1. Résolvez les problèmes identifiés et redémarrez votre workspace.

Pour plus d'informations, voir [Répertoire des journaux du workspace](_index.md#workspace-logs-directory) et [Fichiers journaux disponibles](_index.md#available-log-files).

<!--- Other suggested topics:

## DNS configuration

## Workspace stops unexpectedly

## Workspace creation fails due to quotas

## Network connectivity

## SSH connection failures

### Network policy restrictions

-->
