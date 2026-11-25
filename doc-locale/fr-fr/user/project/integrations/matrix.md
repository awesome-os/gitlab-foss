---
stage: Growth
group: Engagement
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Matrix
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/) dans GitLab 17.3.

{{< /history >}}

Vous pouvez configurer GitLab pour envoyer des notifications à un salon Matrix.

## Configurer l'intégration Matrix dans GitLab {#set-up-the-matrix-integration-in-gitlab}

Prérequis :

- Accès administrateur pour l'activation au niveau de l'instance.
- Le rôle Propriétaire pour l'activation au niveau du groupe.
- Le rôle Mainteneur ou Propriétaire pour l'activation au niveau du projet.

Après avoir rejoint un salon Matrix, vous pouvez configurer GitLab pour envoyer des notifications :

1. Pour activer l'intégration :
   - **Pour votre groupe ou projet** :
     1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
     1. Sélectionnez **Paramètres** > **Intégrations**.
   - **Pour votre instance** :
     1. Dans le coin supérieur droit, sélectionnez **Admin**.
     1. Sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **Matrix**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Facultatif. Dans **Nom d'hôte**, saisissez le nom d'hôte de votre serveur.
1. Dans **Jeton**, collez la valeur du jeton de l'utilisateur Matrix.
1. Dans la section **Déclencheur**, cochez les cases correspondant aux événements GitLab que vous souhaitez recevoir dans Matrix.
1. Dans la section **Paramètres de notification** :
   - Dans **Identifiant du salon**, collez l'identifiant du salon Matrix.
   - Facultatif. Cochez la case **Envoyer une notification uniquement pour les pipelines cassés** pour recevoir des notifications uniquement pour les pipelines en échec.
   - Facultatif. Cochez la case **Envoyer une notification uniquement lorsque le statut change** pour recevoir des notifications uniquement lorsque le statut du pipeline pour la référence change.
   - Facultatif. Dans la liste déroulante **Branches pour lesquelles des notifications doivent être envoyées**, sélectionnez les branches pour lesquelles vous souhaitez recevoir des notifications.
1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

Le salon Matrix peut désormais recevoir tous les événements GitLab sélectionnés.
