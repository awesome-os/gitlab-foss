---
stage: Tutorials
group: Tutorials
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Connectez Claude Desktop au serveur MCP de GitLab et créez un ticket.
title: "Tutoriel : connecter Claude Desktop au serveur MCP de GitLab"
---

Avec le [serveur GitLab Model Context Protocol (MCP)](../../user/model_context_protocol/mcp_server.md), vous pouvez connecter des outils et applications d'IA externes à votre instance GitLab. Dans ce tutoriel, vous allez configurer le serveur MCP de GitLab pour le connecter à Claude Desktop. Une fois Claude Desktop intégré avec succès au serveur MCP, vous demanderez à Claude de créer un ticket dans votre instance GitLab.

## Avant de commencer {#before-you-begin}

- Autorisez l'accès au serveur MCP :
  - Sur GitLab.com, [pour le groupe principal](../../user/group/access_and_permissions.md#allow-access-to-the-mcp-server).
  - Sur GitLab Self-Managed et GitLab Dedicated, [pour l'instance](../../administration/settings/visibility_and_access_controls.md#allow-access-to-the-mcp-server).
- Installez [Claude Desktop](https://support.claude.com/en/articles/10065433-install-claude-desktop) pour votre système d'exploitation.
- Installez la version 20 ou une version ultérieure de Node.js. Assurez-vous que Node.js est accessible globalement au moyen de la variable d'environnement `PATH` (`which -a node`).
- Disposez d'au moins un projet actif dans lequel vous pouvez créer un ticket.

## Connecter Claude Desktop au serveur MCP GitLab {#connect-claude-desktop-to-the-gitlab-mcp-server}

1. Ouvrez Claude Desktop.
1. Modifiez le fichier de configuration. Vous pouvez procéder de l'une des manières suivantes :
   - Dans Claude Desktop, sélectionnez **Paramètres** > **Développeur** > **Modifier la configuration**.
   - Dans votre système de fichiers, accédez à `claude_desktop_config.json` et ouvrez le fichier. Par exemple :
     - Sur macOS : `~/Library/Application Support/Claude/claude_desktop_config.json`.
     - Sur Windows : `%APPDATA%\Claude\claude_desktop_config.json`.
1. Ajoutez l'entrée suivante pour le serveur MCP de GitLab, en la modifiant si nécessaire :
   - Si `npx` est installé localement plutôt que globalement, renseignez le chemin complet de `npx` dans le paramètre `"command":`.
   - Remplacez `<gitlab.example.com>` par l'une des valeurs suivantes :
     - pour GitLab Self-Managed, l'URL de votre instance GitLab ;
     - Sur GitLab.com, `GitLab.com`.

   ```json
   {
     "mcpServers": {
       "GitLab": {
         "command": "npx",
         "args": [
           "-y",
           "mcp-remote",
           "https://<gitlab.example.com>/api/v4/mcp"
         ]
       }
     }
   }
   ```

1. Enregistrez la configuration et redémarrez Claude Desktop.
1. Lors de la première connexion, Claude Desktop ouvre une fenêtre de navigateur pour l'authentification OAuth. Examinez et approuvez la demande.
1. Accédez à **Paramètres** > **Développeur** et vérifiez la nouvelle configuration MCP GitLab.

![Affichage des serveurs MCP locaux connectés dans Claude Desktop](img/view_local_mcp_servers_v18_10.png)

## Personnaliser les permissions des outils {#customize-tool-permissions}

Une fois le serveur MCP connecté avec succès, vous pouvez personnaliser les outils que Claude peut utiliser lors de ses interactions avec votre instance GitLab. Par exemple, vous pouvez configurer Claude pour qu'il demande une approbation avant d'exécuter certaines actions, comme la création d'un ticket ou la gestion d'un pipeline CI/CD.

Pour afficher les permissions des outils dans Claude :

1. Dans la barre latérale gauche, sélectionnez **Personnaliser** > **Connecteurs**.
1. Sous **Bureau**, sélectionnez **GitLab**.
1. Définissez `create_issue` sur **Approbation requise** ou **Toujours autoriser**.

![Affichage des permissions des outils pour un connecteur dans Claude Desktop](img/view_connectors_v18_10.png)

## Tester la connexion {#test-the-connection}

Maintenant que vous avez connecté Claude Desktop au serveur MCP avec succès, testez la connexion avec une invite :

1. Dans la zone de texte du chat, saisissez :

   ```plaintext
   Which MCP server version are you using?
   ```

1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.

Claude devrait répondre avec la version du serveur ainsi que des détails sur l'intégration et les outils qu'il a utilisés pour répondre à l'invite.

![Vérification de la version du serveur MCP avec une invite, et identification des outils utilisés par Claude](img/verify_mcp_server_version_v18_10.png)

## Créer un ticket dans un projet {#create-an-issue-in-a-project}

Maintenant, demandez à Claude de trouver un projet spécifique dans lequel vous pouvez créer un ticket de test.

1. Dans la zone de texte du chat, saisissez :

   ```plaintext
   Can you find my project <project_name>?
   ```

   Remplacez `<project_name>` par votre projet.
1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.
1. Une fois que Claude a trouvé votre projet, demandez à Claude de créer un ticket dans le projet. Dans la zone de texte du chat, saisissez :

   ```plaintext
   Can you create an issue in the project called "Test issue from MCP server", and give it the following description: "This is a test issue created by Claude Desktop and the GitLab MCP server."
   ```

1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.
1. Si vous avez défini `create_issue` sur **Approbation requise**, Claude demandera l'autorisation de créer un ticket. Sélectionnez **Toujours autoriser** ou, dans la liste déroulante, sélectionnez **Autoriser une fois**.

   ![Accorder à Claude l'autorisation de créer un ticket dans le projet](img/grant_permission_to_create_issue_v18_10.png)

Une fois que Claude a créé le ticket, il fournit les détails du ticket, notamment une URL pour y accéder depuis votre navigateur.
