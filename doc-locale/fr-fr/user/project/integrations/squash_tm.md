---
stage: Plan
group: Portfolio Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Squash TM
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque l'intégration de [Squash TM](https://www.squashtest.com/en/squash-gitlab-platform) (Test Management) est activée et configurée dans GitLab, les tickets (généralement des user stories) créés dans GitLab sont synchronisés en tant qu'exigences dans Squash TM, et la progression des tests est reportée dans les tickets GitLab.

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une présentation de l'optimisation de votre workflow DevSecOps avec l'intégration Squash TM et GitLab, consultez [Leverage Requirements and Test management in your SDLC](https://www.youtube.com/watch?v=XAiNUmBiqm4).
<!-- Video published on 2024-05-15 -->

## Configurer Squash TM {#configure-squash-tm}

1. Facultatif. Demandez à votre administrateur système de [configurer un jeton dans le fichier de propriétés](https://tm-en.doc.squashtest.com/latest/redirect/gitlab-integration-token.html).
1. Suivez la [documentation Squash TM](https://tm-en.doc.squashtest.com/latest/redirect/gitlab-integration-configuration.html) pour :
   1. Créer un serveur GitLab.
   1. Activer le plugin `Xsquash4GitLab`.
   1. Configurer une synchronisation.
   1. Dans le panneau **Synchronisation en temps réel**, copiez les champs suivants pour les utiliser ultérieurement dans GitLab :

      - **URL du crochet Web**.
      - **Jeton secret** si votre administrateur système Squash TM en a configuré un à l'étape 1.

## Configurer GitLab {#configure-gitlab}

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Squash TM**.
1. Assurez-vous que le bouton **Actif** est activé.
1. Dans la section **Déclencheur**, indiquez le type de ticket concerné par la synchronisation en temps réel.
1. Remplissez les champs :

   - Saisissez l'**URL du crochet Web de Squash TM**.
   - Saisissez le **jeton secret** si votre administrateur système Squash TM l'a configuré précédemment.
