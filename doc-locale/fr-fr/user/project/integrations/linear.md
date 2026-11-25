---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Linear
description: "Configurez l'intégration Linear pour lier un projet GitLab à un workspace Linear et référencer des tickets Linear dans GitLab."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/198297) dans GitLab 18.3.

{{< /history >}}

Vous pouvez utiliser [Linear](https://linear.app/) comme [système de suivi des tickets externe](../../../integration/external-issue-tracker.md). Pour activer l'intégration Linear dans un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Linear**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Remplissez les champs obligatoires :

   - **URL de l'espace de travail** : L'URL du projet workspace Linear à lier à ce projet GitLab.

1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Une fois Linear configuré et activé, un lien apparaît sur les pages du projet GitLab. Le lien vous dirige vers votre workspace Linear.

Par exemple, voici une configuration pour un workspace nommé `example` :

- URL de l'espace de travail : `https://linear.app/example`

Vous pouvez également désactiver le [système de suivi des tickets interne de GitLab](../issues/_index.md) dans ce projet. Pour en savoir plus sur les étapes et les conséquences de la désactivation des tickets GitLab, consultez :

- [Modifier la visibilité du projet](../../public_access.md#change-project-visibility).
- [Configurer les fonctionnalités et les autorisations du projet](../settings/_index.md#configure-project-features-and-permissions).

## Référencer des tickets Linear dans GitLab {#reference-linear-issues-in-gitlab}

Vous pouvez référencer vos tickets Linear en utilisant :

- `<TEAM>-<ID>`, par exemple `API-123`, où :
  - `<TEAM>` est un identifiant d'équipe.
  - `<ID>` est un nombre.
