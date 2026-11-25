---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Comprendre et configurer les options de combinaison (squash) des commits disponibles dans GitLab.
title: Squash et merge
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

La fonction Squash and merge combine plusieurs petits commits en un seul commit significatif. Cette stratégie maintient l'historique de votre dépôt propre et facilite le suivi ou la restauration des modifications. Lorsque vous travaillez simultanément sur plusieurs fonctionnalités, le squashing sépare les modifications de chaque fonctionnalité en unités distinctes et logiques.

- Les petits commits sont regroupés, ce qui simplifie la [restauration de toutes les parties d'une modification](revert_changes.md).
- Lorsque le commit unique est fusionné dans la branche cible, l'historique complet des commits est conservé.
- Votre branche de base reste propre et contient des messages de commit significatifs.

## Workflow Squash and merge {#squash-and-merge-workflow}

Chaque fois qu'une branche est fusionnée dans votre branche de base, jusqu'à deux commits sont ajoutés :

- Le commit unique créé en combinant les commits de la branche.
- Un commit de fusion, sauf si vous avez activé les [fusions fast-forward](methods/_index.md#fast-forward-merge) dans votre projet. Les fusions fast-forward empêchent la création de commits de fusion supplémentaires, mais vous pouvez toujours combiner les commits de votre branche en un seul commit.

Par défaut, les commits combinés contiennent les métadonnées suivantes :

- Message : Description du commit combiné, ou un message personnalisé
- Auteur : utilisateur qui a créé la merge request
- Auteur du commit : utilisateur qui a initié le squash

Les propriétaires de projet peuvent [créer de nouveaux messages par défaut](commit_templates.md) pour tous les commits combinés et les commits de fusion.

## Définir les options de squash par défaut pour une merge request {#set-default-squash-options-for-a-merge-request}

Les utilisateurs autorisés à créer ou modifier une merge request peuvent définir les options de squash par défaut pour une merge request.

Prérequis :

- Votre projet doit être [configuré](#configure-squash-options-for-a-project) pour autoriser ou encourager le squashing.

Pour cela :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et repérez votre merge request.
1. Sélectionnez **Éditer**.
1. Cochez ou décochez la case **Squash commits when merge request is accepted**.
1. Sélectionnez **Enregistrer les modifications**.

## Combiner les commits dans une merge request {#squash-commits-in-a-merge-request}

Si votre projet vous permet de sélectionner des options de squashing pour les merge requests, pour combiner les commits dans le cadre du processus de fusion :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et repérez votre merge request.
1. Dans le widget de la merge request, assurez-vous que la case **Combiner (squash) les commits** est cochée. Cette case n'est pas affichée si l'option de squashing du projet est définie sur **Ne pas autoriser** ou **Exiger**.
1. Facultatif. Pour modifier le message du commit combiné ou le message du commit de fusion (selon la configuration de votre projet), sélectionnez **Modifier les messages de commit**.
1. Lorsque la merge request est prête à être fusionnée, sélectionnez **Fusionner**.

## Configurer les options de squash pour un projet {#configure-squash-options-for-a-project}

Prérequis :

- Vous devez disposer du rôle Maintainer ou Owner pour ce projet.

Pour configurer le comportement de squashing par défaut pour toutes les merge requests de votre projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Requêtes de fusion**.
1. Dans la section **Squasher les commits lors de la fusion**, sélectionnez le comportement souhaité :
   - **Ne pas autoriser** : le squashing n'est jamais effectué et l'option n'est pas affichée.
   - **Autoriser** : le squashing est autorisé, mais désactivé par défaut.
   - **Encourager** : le squashing est autorisé et sélectionné par défaut, mais peut être désactivé.
   - **Exiger** : le squashing est toujours effectué. Bien que les merge requests affichent l'option de squash, les utilisateurs ne peuvent pas la modifier.
1. Sélectionnez **Enregistrer les modifications**.

## Comportement des branches à longue durée de vie {#long-running-branch-behavior}

Vous ne devez pas effectuer de squash and merge sur des branches à longue durée de vie. Utilisez plutôt une [méthode de fusion](methods/_index.md) qui préserve l'historique des commits d'origine, comme les commits de fusion ou les fusions fast-forward.

Lorsque vous combinez et fusionnez une branche qui continue de recevoir de nouveaux commits, l'historique de la branche diverge de la branche cible. Le squashing crée un nouveau commit unique sur la branche cible avec un SHA différent. Si vous continuez à travailler sur la branche source sans rebaser ou fusionner la branche cible dans celle-ci, Git traite les historiques comme divergents.

Lorsque vous ouvrez une nouvelle merge request depuis cette branche source, vous voyez les éléments suivants :

- Les commits qui avaient déjà été fusionnés dans la merge request précédente.
- Un avertissement indiquant que la branche source est en retard par rapport à la branche cible.

Le diff affiche correctement uniquement les nouvelles modifications qui ne sont pas encore dans la branche cible.

Pour maintenir une branche à longue durée de vie synchronisée avec sa cible après une fusion par squash :

- Rebasez la branche source sur la branche cible après chaque fusion.
- Fusionnez la branche cible dans la branche source après chaque fusion.

## Sujets connexes {#related-topics}

- [Templates de message de commit](commit_templates.md)
- [Méthodes de fusion](methods/_index.md)
