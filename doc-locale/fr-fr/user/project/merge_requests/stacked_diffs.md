---
stage: AI Coding
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Utilisez les diffs empilés pour créer de petites modifications qui s'appuient les unes sur les autres afin de livrer une fonctionnalité."
title: Diffs empilés
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- Publié dans [la v1.42.0 de la CLI GitLab](https://gitlab.com/gitlab-org/cli/-/releases/v1.42.0) en tant que [version expérimentale](../../../policy/development_stages_support.md#experiment).

{{< /history >}}

Utilisez les diffs empilés dans la [CLI GitLab](https://docs.gitlab.com/cli/) pour créer de petites modifications qui s'appuient les unes sur les autres afin de livrer une fonctionnalité. Chaque pile est indépendante, ce qui vous permet de :

- Continuer à développer de nouvelles fonctionnalités pendant que les modifications précédentes sont examinées.
- Répondre aux retours de révision sur des diffs spécifiques sans affecter les autres travaux.
- Fusionner les diffs indépendamment au fur et à mesure de leur approbation.

Le workflow pour les diffs empilés est le suivant :

1. Créer des modifications : lorsque vous exécutez `glab stack save`, la CLI GitLab :

   - Indexe toutes vos modifications.
   - Crée un nouveau commit avec votre message.
   - Crée une nouvelle branche pour ce commit.
   - Vous déplace automatiquement vers la nouvelle branche.

1. Synchroniser avec GitLab : lorsque vous exécutez `glab stack sync`, la CLI GitLab :

   - Envoie toutes les branches de votre pile vers GitLab.
   - Crée une merge request pour chaque diff qui n'en possède pas encore.
   - Enchaîne les merge requests entre elles. Chaque merge request, à l'exception de la première, cible la branche du diff précédent.

La commande de base pour cette fonctionnalité dans la CLI est [`stack`](https://docs.gitlab.com/cli/stack/), que vous étendez ensuite avec [d'autres commandes](#available-commands).

<div class="video-fallback">
  Pour en savoir plus, consultez : <a href="https://www.youtube.com/watch?v=TOQOV8PWYic">Présentation des diffs empilés dans la CLI</a>.
</div>
<figure class="video-container">
  <iframe src="https://www.youtube-nocookie.com/embed/TOQOV8PWYic" frameborder="0" allowfullscreen> </iframe>
</figure>
<!-- Video published on 2024-06-18 -->

Cette fonctionnalité est une [version expérimentale](../../../policy/development_stages_support.md). Nous serions ravis de recueillir vos retours dans le [ticket 7473](https://gitlab.com/gitlab-org/cli/-/issues/7473).

## Créer un diff empilé {#create-a-stacked-diff}

Créez un diff empilé lorsque vous souhaitez décomposer une grande fonctionnalité en modifications plus petites et révisables.

Prérequis :

- Vous devez avoir la [CLI GitLab](https://docs.gitlab.com/cli/) installée et authentifiée.

Pour créer un diff empilé :

1. Dans votre terminal, créez une nouvelle pile et donnez-lui un nom. Par exemple :

   ```shell
   glab stack create add-authentication
   ```

1. Effectuez votre premier ensemble de modifications dans votre éditeur.
1. Enregistrez vos modifications en tant que premier diff :

   ```shell
   glab stack save
   ```

   Lorsque vous y êtes invité, saisissez un message de commit décrivant cette modification.

1. Effectuez votre prochain ensemble de modifications et enregistrez-les en tant que deuxième diff :

   ```shell
   glab stack save
   ```

   Chaque fois que vous exécutez `glab stack save`, vous créez un nouveau diff et une nouvelle branche. Lorsque vous y êtes invité, saisissez un message de commit décrivant cette modification.

1. Lorsque vous êtes prêt à envoyer vos modifications vers GitLab et à créer des merge requests, exécutez :

   ```shell
   glab stack sync
   ```

Vos merge requests sont disponibles pour révision. Vous pouvez continuer à créer d'autres diffs dans cette pile ou basculer pour travailler sur autre chose.

## Ajouter des modifications à un diff dans une pile {#add-changes-to-a-diff-in-a-stack}

Pour revenir à un point spécifique de la pile afin d'y ajouter d'autres modifications :

1. Affichez la liste des piles :

   ```shell
   glab stack move
   ```

1. Sélectionnez la pile que vous souhaitez modifier et appuyez sur <kbd>Entrée</kbd>.
1. Effectuez vos modifications.
1. Lorsque vous êtes prêt, enregistrez vos modifications et exécutez :

   ```shell
   glab stack amend
   ```

1. Facultatif. Modifiez la description de la pile.
1. Envoyez vos modifications :

   ```shell
   glab stack sync
   ```

Lorsque vous synchronisez une pile existante, GitLab :

- Met à jour la pile existante avec vos nouvelles modifications.
- Rebase les autres merge requests de la pile pour intégrer vos dernières modifications.

## Commandes disponibles {#available-commands}

Utilisez ces commandes pour travailler avec les diffs empilés :

| Commande                                               | Description |
|-------------------------------------------------------|-------------|
| [`create`](https://docs.gitlab.com/cli/stack/create/) | Créer une nouvelle pile. |
| [`save`](https://docs.gitlab.com/cli/stack/save/)     | Enregistrer vos modifications en tant que nouveau diff. |
| [`amend`](https://docs.gitlab.com/cli/stack/amend/)   | Modifier le diff actuel. |
| [`prev`](https://docs.gitlab.com/cli/stack/prev/)     | Passer au diff précédent. |
| [`next`](https://docs.gitlab.com/cli/stack/next/)     | Passer au diff suivant. |
| [`first`](https://docs.gitlab.com/cli/stack/first/)   | Passer au premier diff. |
| [`last`](https://docs.gitlab.com/cli/stack/last/)     | Passer au dernier diff. |
| [`move`](https://docs.gitlab.com/cli/stack/move/)     | Sélectionner n'importe quel diff depuis une liste. |
| [`sync`](https://docs.gitlab.com/cli/stack/sync/)     | Envoyer les branches et créer/mettre à jour les merge requests. |

### Choisir entre save et amend {#choose-between-save-and-amend}

Utilisez les commandes suivantes selon vos besoins :

- `glab stack save` : crée un nouveau diff (commit et branche). Utilisez cette commande lorsque vous ajoutez une nouvelle modification logique à votre pile.
- `glab stack amend` : modifie le diff actuel. Utilisez cette commande lorsque vous répondez à des retours de révision ou que vous corrigez la modification actuelle.

## Sujets connexes {#related-topics}

- [Merge requests empilées](reviews/stacked_merge_requests.md)
