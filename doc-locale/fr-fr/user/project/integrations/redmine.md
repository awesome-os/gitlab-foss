---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Redmine
description: "Configurez l'intégration Redmine pour lier un projet GitLab à un outil de suivi des tickets Redmine et référencer les tickets Redmine dans GitLab."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Prérequis :

- Vous devez [désactiver le suivi interne des tickets GitLab](../../../integration/external-issue-tracker.md#disable-the-gitlab-issue-tracker) dans le projet. Pour en savoir plus sur les étapes et les conséquences de la désactivation des tickets GitLab, consultez [changer la visibilité du projet](../../public_access.md#change-project-visibility) et [configurer les fonctionnalités et les autorisations du projet](../settings/_index.md#configure-project-features-and-permissions).

Vous pouvez utiliser [Redmine](https://www.redmine.org/) comme [outil de suivi des tickets externe](../../../integration/external-issue-tracker.md). Pour activer l'intégration Redmine dans un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Redmine**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Renseignez les champs obligatoires :

   - **URL du projet** : L'URL du projet Redmine à lier à ce projet GitLab.
   - **URL du ticket** : L'URL du ticket du projet Redmine à lier à ce projet GitLab. L'URL doit contenir `:id`. GitLab remplace cet ID par le numéro du ticket.
   - **URL de nouveau ticket** : L'URL à utiliser pour créer un nouveau ticket dans le projet Redmine lié à ce projet GitLab.

     <!-- The note below was originally added in January 2018: <https://gitlab.com/gitlab-org/gitlab/-/commit/778b231f3a5dd42ebe195d4719a26bf675093350> -->

     > [!note]
     > Cette URL n'est pas utilisée et sa suppression est prévue dans une prochaine release. Pour en savoir plus, consultez le [ticket 327503](https://gitlab.com/gitlab-org/gitlab/-/issues/327503).

1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Après avoir configuré et activé Redmine, un lien apparaît sur les pages du projet GitLab. Le lien vous redirige vers votre projet Redmine.

Par exemple, voici une configuration pour un projet nommé `gitlab-ci` :

- URL du projet : `https://redmine.example.com/projects/gitlab-ci`
- URL du ticket : `https://redmine.example.com/issues/:id`
- URL de nouveau ticket : `https://redmine.example.com/projects/gitlab-ci/issues/new`

## Référencer les tickets Redmine dans GitLab {#reference-redmine-issues-in-gitlab}

Vous pouvez référencer vos tickets Redmine en utilisant :

- `#<ID>`, où `<ID>` est un nombre (exemple : `#143`).
- `<PROJECT>-<ID>`, par exemple `API_32-143`, où :
  - `<PROJECT>` commence par une lettre majuscule, suivie de lettres majuscules, de chiffres ou de tirets bas.
  - `<ID>` est un nombre.

Dans les liens, la partie `<PROJECT>` est ignorée et ils pointent toujours vers l'adresse spécifiée dans **URL du ticket**.

Utilisez le format long (`<PROJECT>-<ID>`) si vous avez à la fois des outils de suivi des tickets internes et externes activés. Si vous utilisez le format court et qu'un ticket avec le même ID existe dans l'outil de suivi des tickets interne, c'est le ticket interne qui est lié.
