---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: YouTrack
description: "Configurez l'intégration YouTrack pour lier un projet GitLab à une instance YouTrack et référencer les tickets YouTrack dans GitLab."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

JetBrains [YouTrack](https://www.jetbrains.com/youtrack/) est une plateforme web de suivi des tickets et de gestion de projets.

Vous pouvez configurer YouTrack en tant que [système de suivi des tickets externe](../../../integration/external-issue-tracker.md) dans GitLab.

Pour activer l'intégration YouTrack dans un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **YouTrack**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Renseignez les champs obligatoires :
   - **URL du projet** : L'URL du projet dans YouTrack.
   - **URL du ticket** : L'URL permettant d'afficher un ticket dans le projet YouTrack. L'URL doit contenir `:id`. GitLab remplace `:id` par le numéro du ticket.
1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Une fois YouTrack configuré et activé, un lien apparaît sur les pages du projet GitLab. Ce lien vous redirige vers le projet YouTrack approprié.

Vous pouvez également désactiver le [système de suivi des tickets interne de GitLab](../issues/_index.md) dans ce projet. Pour plus d'informations sur les étapes et les conséquences de la désactivation des tickets GitLab, consultez :

- [Modifier la visibilité du projet](../../public_access.md#change-project-visibility).
- [Configurer les fonctionnalités et les permissions du projet](../settings/_index.md#configure-project-features-and-permissions).

## Référencer des tickets YouTrack dans GitLab {#reference-youtrack-issues-in-gitlab}

Vous pouvez référencer des tickets dans YouTrack en utilisant `<PROJECT>-<ID>` (par exemple `YT-101`, `Api_32-143` ou `gl-030`) où :

- `<PROJECT>` commence par une lettre et est suivi de lettres, de chiffres ou de traits de soulignement.
- `<ID>` est un nombre.

Les références à `<PROJECT>-<ID>` dans les merge requests, les commits ou les commentaires sont automatiquement liées à l'URL du ticket YouTrack.
