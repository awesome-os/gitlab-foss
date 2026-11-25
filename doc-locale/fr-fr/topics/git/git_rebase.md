---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Introduction au rebase Git et au push forcé, méthodes pour résoudre les conflits de merge en ligne de commande."
title: Rebase et résolution des conflits de merge
---

Git rebase combine les modifications d'une branche dans une autre en déplaçant vos commits vers le sommet de la branche cible. Cette action :

- Met à jour les branches avec le dernier code de la branche cible.
- Maintient un historique de commits propre et linéaire pour faciliter le débogage et les revues de code.
- Résout les [conflits de merge](../../user/project/merge_requests/conflicts.md) au niveau du commit pour la résolution des conflits.
- Préserve l'ordre chronologique des modifications du code.

Lorsque vous effectuez un rebase :

1. Git importe tous les commits soumis à votre branche cible après que vous avez initialement créé votre branche à partir de celle-ci.
1. Git applique les commits de votre branche au-dessus des commits importés. Dans cet exemple, après la création d'une branche nommée `feature` (en orange), quatre commits de `main` (en violet) sont importés dans la branche `feature` :

   ![Une branche feature rebasée sur la branche main.](img/rebase_v17_10.drawio.svg)

Bien que la plupart des rebases soient effectués par rapport à `main`, vous pouvez rebaser par rapport à n'importe quelle autre branche. Vous pouvez également spécifier un dépôt distant différent. Par exemple, `upstream` au lieu de `origin`.

> [!warning]
> `git rebase` réécrit l'historique des commits. Cela peut provoquer des conflits dans les branches partagées et des conflits de merge complexes. Au lieu de rebaser votre branche par rapport à la branche par défaut, envisagez d'utiliser `git pull origin master`. Le pull a des effets similaires avec moins de risque de compromettre le travail des autres.

## Rebasage {#rebase}

Lorsque vous utilisez Git pour effectuer un rebase, chaque commit est appliqué à votre branche. Lorsque des conflits de merge surviennent, vous êtes invité à les résoudre.

Pour des options plus avancées sur vos commits, utilisez [un rebase interactif](#interactive-rebase).

Prérequis :

- Vous devez disposer des [permissions](../../user/permissions.md) nécessaires pour effectuer un push forcé vers les branches.

Pour utiliser Git afin de rebaser votre branche par rapport à la branche cible :

1. Ouvrez un terminal et accédez au répertoire de votre projet.
1. Assurez-vous de disposer du dernier contenu de la branche cible. Dans cet exemple, la branche cible est `main` :

   ```shell
   git fetch origin main
   ```

1. Extrayez votre branche :

   ```shell
   git checkout my-branch
   ```

1. Facultatif. Créez une sauvegarde de votre branche :

   ```shell
   git branch my-branch-backup
   ```

   Les modifications ajoutées à `my-branch` après ce point sont perdues si vous restaurez à partir de la branche de sauvegarde.
1. Rebasez par rapport à la branche `main` :

   ```shell
   git rebase origin/main
   ```

1. Si des conflits de merge existent :
   1. Résolvez les conflits dans votre éditeur.
   1. Indexez les modifications :

      ```shell
      git add .
      ```

   1. Continuez le rebase :

      ```shell
      git rebase --continue
      ```

1. Effectuez un push forcé de vos modifications vers la branche cible, tout en protégeant les commits des autres :

   ```shell
   git push origin my-branch --force-with-lease
   ```

## Rebase interactif {#interactive-rebase}

Utilisez un rebase interactif pour spécifier comment traiter chaque commit. Les instructions suivantes utilisent l'éditeur de texte [Vim](https://www.vim.org/) pour modifier les commits.

Pour effectuer un rebase interactif :

1. Ouvrez un terminal et accédez au répertoire de votre projet.
1. Assurez-vous de disposer du dernier contenu de la branche cible. Dans cet exemple, la branche cible est `main` :

   ```shell
   git fetch origin main
   ```

1. Extrayez votre branche :

   ```shell
   git checkout my-branch
   ```

1. Facultatif. Créez une sauvegarde de votre branche :

   ```shell
   git branch my-branch-backup
   ```

   Les modifications ajoutées à `my-branch` après ce point sont perdues si vous restaurez à partir de la branche de sauvegarde.
1. Dans l'interface GitLab, dans votre merge request, confirmez le nombre de commits à rebaser dans l'onglet **Validation**.
1. Ouvrez ces commits. Par exemple, pour modifier les cinq derniers commits :

   ```shell
   git rebase -i HEAD~5
   ```

   Git ouvre les commits dans l'éditeur de texte de votre terminal, du plus ancien au plus récent. Chaque commit affiche l'action à effectuer, le SHA et le titre du commit. Par exemple :

   ```shell
   pick 111111111111 Second round of structural revisions
   pick 222222222222 Update inbound link to this changed page
   pick 333333333333 Shifts from H4 to H3
   pick 444444444444 Adds revisions from editorial
   pick 555555555555 Revisions continue to build the concept part out

   # Rebase 111111111111..222222222222 onto zzzzzzzzzzzz (5 commands)
   #
   # Commands:
   # p, pick <commit> = use commit
   # r, reword <commit> = use commit, but edit the commit message
   # e, edit <commit> = use commit, but stop for amending
   # s, squash <commit> = use commit, but meld into previous commit
   # f, fixup [-C | -c] <commit> = like "squash" but keep only the previous
   ```

1. Passez en mode édition de Vim en appuyant sur <kbd>i</kbd>.
1. Utilisez les touches fléchées pour déplacer le curseur jusqu'au commit que vous souhaitez modifier.
1. Pour chaque commit, à l'exception du premier, remplacez `pick` par `squash` ou `fixup` (ou `s` ou `f`).
1. Répétez l'opération pour les commits restants.
1. Quittez le mode édition, enregistrez et fermez :

   - Appuyez sur <kbd>ESC</kbd>.
   - Saisissez `:wq`.

1. Lors d'un squash, Git vous invite à modifier le message de commit :

   - Les lignes commençant par `#` sont ignorées et ne sont pas incluses dans le message de commit.
   - Pour conserver le message actuel, saisissez `:wq`.
   - Pour modifier le message de commit, passez en mode édition, effectuez les modifications et enregistrez.

1. Poussez vos modifications vers la branche cible.

   - Si vous n'avez pas encore poussé vos commits vers la branche cible avant le rebase :

     ```shell
     git push origin my-branch
     ```

   - Si vous avez déjà poussé les commits :

     ```shell
     git push origin my-branch --force-with-lease
     ```

     Certaines actions nécessitent un push forcé pour apporter des modifications à la branche. Pour plus d'informations, consultez [push forcé vers une branche distante](#force-push-to-a-remote-branch).

## Résoudre les conflits en ligne de commande {#resolve-conflicts-from-the-command-line}

Pour avoir le plus de contrôle possible sur chaque modification, vous devez résoudre les conflits complexes localement en ligne de commande, plutôt que dans GitLab.

Prérequis :

- Vous devez disposer des [permissions](../../user/permissions.md) nécessaires pour effectuer un push forcé vers les branches.

1. Ouvrez le terminal et extrayez votre branche de fonctionnalité :

   ```shell
   git switch my-feature-branch
   ```

1. Rebasez votre branche par rapport à la branche cible. Dans cet exemple, la branche cible est `main` :

   ```shell
   git fetch
   git rebase origin/main
   ```

1. Ouvrez le fichier en conflit dans votre éditeur de code préféré.
1. Localisez et résolvez le bloc de conflit :
   1. Choisissez la version (avant ou après `=======`) que vous souhaitez conserver.
   1. Supprimez la version que vous ne souhaitez pas conserver.
   1. Supprimez les marqueurs de conflit.
1. Enregistrez le fichier.
1. Répétez le processus pour chaque fichier présentant des conflits.
1. Indexez vos modifications :

   ```shell
   git add .
   ```

1. Commitez vos modifications :

   ```shell
   git commit -m "Resolve merge conflicts"
   ```

   > [!warning]
   > Vous pouvez exécuter `git rebase --abort` pour arrêter le processus avant ce stade. Git abandonne le rebase et ramène la branche à l'état antérieur à l'exécution de `git rebase`. Après avoir exécuté `git rebase --continue`, vous ne pouvez plus abandonner le rebase.
1. Continuez le rebase :

   ```shell
   git rebase --continue
   ```

1. Effectuez un push forcé des modifications vers votre branche distante :

   ```shell
   git push origin my-feature-branch --force-with-lease
   ```

## Push forcé vers une branche distante {#force-push-to-a-remote-branch}

Les opérations Git complexes telles que le squash de commits, la réinitialisation d'une branche ou le rebase réécrivent l'historique de la branche. Git nécessite une mise à jour forcée pour ces modifications.

Le push forcé n'est pas recommandé sur les branches partagées, car vous risquez de détruire les modifications des autres.

Si la branche est [protégée](../../user/project/repository/branches/protected.md), vous ne pouvez pas effectuer de push forcé, sauf si vous :

- Annulez sa protection.
- Autorisez les pushs forcés.

Pour plus d'informations, consultez [autoriser le push forcé sur une branche protégée](../../user/project/repository/branches/protected.md#allow-force-push).

## Restaurer votre branche sauvegardée {#restore-your-backed-up-branch}

Si un rebase ou un push forcé échoue, restaurez votre branche à partir de sa sauvegarde :

1. Assurez-vous d'être sur la bonne branche :

   ```shell
   git checkout my-branch
   ```

1. Réinitialisez votre branche à partir de la sauvegarde :

   ```shell
   git reset --hard my-branch-backup
   ```

## Approbation après un rebase {#approving-after-rebase}

Après avoir rebasé une branche, Git modifie le committer Git et préserve l'auteur Git pour chaque commit rebasé. Si votre projet est configuré pour [empêcher les approbations par les utilisateurs qui ajoutent des commits](../../user/project/merge_requests/approvals/settings.md#prevent-approvals-by-users-who-add-commits), GitLab vous exclut en tant que committer Git de l'approbation. GitLab exclut également chaque auteur Git d'origine.

Après avoir approuvé et rebasé une merge request, GitLab peut continuer à afficher votre approbation. Votre approbation n'est pas comptabilisée dans les approbations requises pour la merge request.

## Sujets connexes {#related-topics}

- [Annuler et défaire des modifications](undo.md)
- [Documentation Git sur les branches et les rebases](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)
- [Paramètres de squash et de merge du projet](../../user/project/merge_requests/squash_and_merge.md#configure-squash-options-for-a-project)
- [Conflits de merge](../../user/project/merge_requests/conflicts.md)

## Dépannage {#troubleshooting}

Pour obtenir des informations sur le dépannage des pipelines CI/CD, consultez [le débogage des pipelines CI/CD](../../ci/debugging.md).

### `Unmergeable state` après l'action rapide `/rebase` {#unmergeable-state-after-rebase-quick-action}

La commande `/rebase` planifie une tâche en arrière-plan. La tâche tente de rebaser les modifications de la branche source sur le dernier commit de la branche cible. Si, après avoir utilisé l'[action rapide `/rebase`](../../user/project/quick_actions.md#rebase), vous voyez cette erreur, un rebase ne peut pas être planifié :

```plaintext
This merge request is currently in an unmergeable state, and cannot be rebased.
```

Cette erreur se produit si l'une de ces conditions est vraie :

- Des conflits existent entre la branche source et la branche cible.
- La branche source ne contient aucun commit.
- La branche source ou la branche cible n'existe pas.
- Une erreur s'est produite, ce qui a entraîné l'absence de diff généré.

Pour résoudre l'erreur `unmergeable state` :

1. Résolvez tous les conflits de merge.
1. Confirmez que la branche source existe et contient des commits.
1. Confirmez que la branche cible existe.
1. Confirmez que le diff a été généré.

### Action rapide `/merge` ignorée après `/rebase` {#merge-quick-action-ignored-after-rebase}

Si `/rebase` est utilisé, `/merge` est ignoré pour éviter une situation de compétition où la branche source est fusionnée ou supprimée avant d'être rebasée.
