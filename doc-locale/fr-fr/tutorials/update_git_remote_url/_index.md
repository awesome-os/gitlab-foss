---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : mettre à jour les URL distantes Git'
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Mettez à jour vos URL distantes Git si :

- Vous avez importé un projet existant depuis un autre hôte de dépôt Git.
- Votre organisation a déplacé vos projets vers une nouvelle instance GitLab avec un nouveau nom de domaine.
- Le projet a été renommé avec un nouveau chemin dans la même instance GitLab.

> [!note]
> Si vous ne disposez pas d'une copie de travail locale existante à partir de l'ancienne télécommande, vous n'avez pas besoin de ce tutoriel. Vous pouvez à la place cloner le projet à partir de la nouvelle URL GitLab.

Ce tutoriel explique comment mettre à jour l'URL distante de votre dépôt local sans :

- Perdre les modifications locales incomplètes.
- Perdre les modifications qui n'ont pas encore été publiées sur GitLab.
- Créer une nouvelle copie de travail clonée du dépôt à partir de la nouvelle URL.

Ce tutoriel utilise la commande `git-remote` pour [gérer les dépôts distants et suivis](https://git-scm.com/docs/git-remote).

Pour mettre à jour les URL distantes Git :

- [Déterminer les URL existantes et nouvelles](#determine-existing-and-new-urls)
- [mettre à jour les URL distantes Git](#update-git-remote-urls)
- [(Facultatif) Conserver les URL distantes d'origine](#optional-keep-original-remote-urls)

## Avant de commencer {#before-you-begin}

Vous devez disposer des éléments suivants :

- Un projet GitLab avec un dépôt Git et une nouvelle URL GitLab.
- Une copie de travail locale clonée du projet que vous migrez vers la nouvelle URL GitLab.
- Git [installé sur votre machine locale](../../topics/git/how_to_install_git/_index.md).
- Accès à l'interface de ligne de commande (CLI) de votre machine locale. Sous macOS, vous pouvez utiliser Terminal. Sous Windows, vous pouvez utiliser PowerShell. Les utilisateurs de Linux sont probablement déjà familiers avec la CLI de leur système.
- Identifiants d'authentification pour GitLab :
  - Vous devez vous authentifier auprès de GitLab pour mettre à jour les URL distantes Git. Si votre compte GitLab utilise l'authentification de base par nom d'utilisateur et mot de passe, vous devez avoir [l'authentification à deux facteurs (2FA)](../../user/profile/account/two_factor_authentication.md) désactivée pour vous authentifier depuis la CLI. Vous pouvez également [utiliser une clé SSH pour vous authentifier auprès de GitLab](../../user/ssh.md).

## Déterminer les URL existantes et nouvelles {#determine-existing-and-new-urls}

Pour mettre à jour l'URL distante Git, déterminez les URL existantes et nouvelles de votre dépôt :

1. Ouvrez un terminal ou une invite de commandes.
1. Accédez à votre copie de travail du dépôt local. Pour changer de répertoire, utilisez `cd` :

   ```shell
   cd <repository-name>
   ```

1. Chaque dépôt possède une télécommande par défaut nommée `origin`. Pour afficher les URL _fetch_ et _push_ actuelles de votre dépôt distant, exécutez :

   ```shell
   git remote -v
   ```

1. Copiez et notez les URL retournées. Elles sont généralement identiques.
1. Obtenez la nouvelle URL :
   1. Accédez à GitLab.
   1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
   1. Dans la barre latérale gauche, sélectionnez **Code** > **Dépôt** pour accéder à la page **Dépôt** du projet.
   1. Dans le coin supérieur droit, sélectionnez **Code**.
   1. Selon la méthode que vous utilisez pour l'authentification et le clonage avec `git`, copiez l'URL HTTPS ou SSH. Si vous n'êtes pas sûr, utilisez la même méthode que l'URL `origin` de l'étape précédente.
   1. Notez l'URL copiée.

## Mettre à jour les URL distantes Git {#update-git-remote-urls}

Pour mettre à jour l'URL distante Git :

1. Ouvrez un terminal ou une invite de commandes.
1. Accédez à votre copie de travail du dépôt local. Pour changer de répertoire, utilisez `cd` :

   ```shell
   cd <repository-name>
   ```

1. Mettez à jour l'URL distante en remplaçant `<new_url>` par la nouvelle URL du dépôt que vous avez copiée :

   ```shell
   git remote set-url origin <new_url>
   ```

1. Vérifiez que la mise à jour de l'URL distante a réussi. La commande suivante affiche la nouvelle URL pour les opérations fetch et push, liste les branches locales et confirme qu'elles sont suivies sur GitLab :

   ```shell
   git remote show origin
   ```

   - Si la mise à jour a échoué, revenez à l'étape précédente, vérifiez que vous disposez du bon `<new_url>` et réessayez.

Pour mettre à jour les URL distantes de plusieurs dépôts :

1. Utilisez la commande `git remote set-url`. Remplacez `origin` par le nom de la télécommande que vous souhaitez mettre à jour. Par exemple :

   ```shell
   git remote set-url <remote_name> <new_url>
   ```

1. Vérifiez chaque mise à jour d'URL distante :

   ```shell
   git remote show <remote_name>
   ```

Après avoir mis à jour l'URL distante, vous pouvez continuer à utiliser les commandes Git normalement. Votre prochaine commande `git fetch`, `git pull` ou `git push` utilisera la nouvelle URL de GitLab.

Félicitations, vous avez mis à jour avec succès l'URL distante de votre dépôt.

## (Facultatif) Conserver les URL distantes d'origine {#optional-keep-original-remote-urls}

Votre projet peut avoir plusieurs emplacements distants. Par exemple, vous avez un dépôt dupliqué à partir d'un projet hébergé sur GitHub, mais vous souhaitez travailler sur votre duplication dans GitLab avant de soumettre une pull request à GitHub.

Pour conserver l'URL distante d'origine en plus de la mettre à jour et maintenir à la fois les nouvelles et les anciennes URL distantes, vous pouvez ajouter une nouvelle télécommande au lieu de modifier celle existante.

Avec cette approche, vous pouvez effectuer une transition progressive vers la nouvelle URL tout en conservant l'accès au dépôt d'origine.

Pour ajouter une nouvelle URL distante :

1. Ouvrez un terminal ou une invite de commandes.
1. Accédez à votre copie de travail du dépôt local.
1. Ajoutez une nouvelle URL distante. Remplacez `<new_remote_name>` par un nom pour la nouvelle télécommande, par exemple `new-origin`, et `<new_url>` par la nouvelle URL du dépôt :

   ```shell
   git remote add <new_remote_name> <new_url>
   ```

1. Vérifiez que la nouvelle télécommande a bien été ajoutée :

   ```shell
   git remote -v
   ```

Vous pouvez désormais utiliser à la fois la télécommande d'origine et la nouvelle. Par exemple :

- Pour envoyer vers la télécommande d'origine : `git push origin main`
- Pour envoyer vers la nouvelle télécommande : `git push <new_remote_name> main`
