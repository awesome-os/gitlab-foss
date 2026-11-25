---
stage: AI Clients
group: Duo Chat
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Où trouver GitLab Duo Chat et comment l'utiliser pour travailler avec des tickets."
title: "Tutoriel : gérer les tickets avec GitLab Duo Chat"
---

GitLab Duo Agentic Chat utilise des assistants IA appelés agents pour vous aider à accomplir des tâches spécifiques et à répondre à des questions complexes. Dans ce tutoriel, vous effectuerez les tâches suivantes pour vous familiariser avec l'interface GitLab Duo Chat :

- Demander à l'agent GitLab Duo par défaut de répondre à une question générale.
- Utiliser l'agent Planner pour effectuer des tâches de gestion de tickets plus complexes, notamment :
  - Rechercher et filtrer les bugs de haute priorité dans un ticket.
  - Rechercher les tickets qui vous sont assignés et décomposer le travail requis en sous-tâches.

## Avant de commencer {#before-you-begin}

- Satisfaire aux [prérequis de GitLab Duo Agent Platform](../../user/duo_agent_platform/_index.md#prerequisites).
- Définir un [espace de nommage GitLab Duo par défaut](../../user/profile/preferences.md#set-a-default-gitlab-duo-namespace).
- Choisissez un projet que vous connaissez bien. Assurez-vous d'avoir au moins un ticket ouvert qui vous est assigné.

## Ouvrir GitLab Duo Chat {#open-gitlab-duo-chat}

Commencez par vous familiariser avec l'interface de chat et démarrez votre première discussion.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale GitLab Duo à droite, sélectionnez **Ajouter une discussion**.
1. Choisissez maintenant quel agent utiliser. Pour poser une question générale, sélectionnez **GitLab Duo**.

   ![Démarrer une discussion et choisir un agent.](img/add_new_chat_v18_9.png)

Le panneau GitLab Duo s'ouvre depuis le côté droit de l'écran. Le panneau reste ouvert pendant que vous naviguez dans GitLab, afin que vous puissiez référencer du code, des tickets ou des merge requests pendant la discussion.

![Une nouvelle discussion vide dans le panneau GitLab Duo.](img/chat_panel_v18_9.png)

En bas du panneau, près de la zone de texte de discussion, vous pouvez choisir le grand modèle de langage à utiliser. Pour ce tutoriel, vous pouvez conserver la sélection par défaut.

![Le sélecteur de modèle.](img/choose_model_v18_9.png)

Essayez maintenant !

1. Dans la zone de texte de discussion, saisissez :

   ```plaintext
   Give me an overview of this project's architecture.
   ```

1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.

GitLab Duo résume ses conclusions dans le panneau.

## Rechercher et filtrer des tickets {#find-and-filter-issues}

Essayez maintenant de rechercher des tickets spécifiques dans votre projet. Vous souhaitez identifier tous les bugs de haute priorité dans le projet.

Pour cette tâche, passez à l'agent Planner.

1. Dans la barre latérale GitLab Duo, sélectionnez **Ajouter une discussion** > **Planificateur**.
1. Dans la zone de texte de discussion, saisissez :

   ```plaintext
   List all open issues labeled 'bug' and 'high-priority' created in the last 30 days.
   ```

1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.

L'agent Planner recherche dans votre projet et filtre les tickets selon vos critères. Vous recevez une liste des tickets correspondants avec leurs titres, numéros de ticket et liens.

Ensuite, essayez quelques invites de suivi pour filtrer par différents labels, plages de dates ou autres critères. Par exemple :

```plaintext
Order this list by date created, and then alphabetically by name.
```

## Analyser un ticket et créer des sous-tâches {#analyze-an-issue-and-create-subtasks}

Vous allez utiliser Chat pour afficher la liste des tickets qui vous sont assignés et en analyser un plus en détail.

1. Dans la conversation de l'agent Planner, dans la zone de texte de discussion, saisissez :

   ```plaintext
   Show me all the open issues assigned to me.
   ```

1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.
1. Choisissez l'un des tickets. Vous allez maintenant utiliser l'agent Planner pour créer des éléments enfants afin de décomposer le travail en étapes plus faciles à gérer.

   Ne vous inquiétez pas si vous n'avez pas besoin des éléments enfants, vous pouvez toujours les fermer ultérieurement.
1. Dans la zone de texte de discussion, saisissez :

   ```plaintext
   Analyze issue #<selected_issue_number> and suggest how to break up the work into two or three subtasks.
   ```

1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.
1. Passez en revue les éléments enfants suggérés et, si vous les approuvez, saisissez :

   ```plaintext
   Create these subtasks as child items under issue #<selected_issue_number>.
   ```

   Vous pouvez également utiliser des invites de suivi pour demander d'autres ajustements jusqu'à ce que vous soyez satisfait.
1. Appuyez sur <kbd>Entrée</kbd> ou sélectionnez **Envoyer**.
1. GitLab Duo prépare les éléments de travail pour la révision finale. Lisez les descriptions et consultez les paramètres de la requête JSON, puis sélectionnez **Approuver**.

   ![Approuver les éléments de travail préparés par GitLab Duo.](img/approve_chat_v18_9.png)

Les tickets sont ajoutés en tant qu'éléments enfants à votre ticket et le panneau de discussion affiche leurs liens. Vous pouvez ensuite ajouter des labels, assigner les tickets ou définir un jalon.

## Étapes suivantes {#next-steps}

Félicitations ! Vous avez appris à utiliser GitLab Duo Chat et l'agent Planner pour la gestion simple de tickets.

Vous pouvez continuer à affiner les détails des sous-tâches, par exemple :

- `Can you provide more detail on task 3?`
- `Split task 2 into separate tasks`
- `Add technical implementation notes to these tasks`

Ou, si vous avez effectué cet essai à titre expérimental, vous pouvez fermer les sous-tâches :

```plaintext
Close these subtasks and add a comment in each that says: "This subtask was created as part of a tutorial exercise."
```

Pour passer en revue le travail effectué, vous pouvez revenir à vos discussions précédentes. Dans la barre latérale GitLab Duo, sélectionnez **Historique GitLab Duo Chat** ({{< icon name="history" >}}).

![La liste de l'historique des discussions.](img/chat_history_v18_9.png)
