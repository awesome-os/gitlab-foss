---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Utilisez Git LFS pour gérer les ressources binaires, comme les images et les vidéos, sans alourdir la taille de votre dépôt Git."
title: Git Large File Storage (LFS)
---

Git Large File Storage (LFS) est une extension Git open source qui aide les dépôts Git à gérer efficacement les fichiers binaires volumineux. Git ne peut pas suivre les modifications apportées aux fichiers binaires (comme les fichiers audio, vidéo ou image) de la même façon qu'il suit les modifications apportées aux fichiers texte. Alors que les fichiers texte peuvent générer des diffs en texte brut, toute modification d'un fichier binaire oblige Git à remplacer intégralement le fichier dans le dépôt. Les modifications répétées de fichiers volumineux augmentent la taille de votre dépôt. Au fil du temps, cette augmentation de taille peut ralentir les opérations Git courantes telles que `clone`, `fetch` ou `pull`.

Utilisez Git LFS pour stocker les fichiers binaires volumineux en dehors de votre dépôt Git, en ne laissant qu'un petit pointeur textuel à gérer par Git. Lorsque vous ajoutez un fichier à votre dépôt à l'aide de Git LFS, GitLab :

1. Ajoute le fichier dans le stockage d'objets configuré de votre projet, plutôt que dans le dépôt Git.
1. Ajoute un pointeur dans votre dépôt Git, plutôt que le fichier volumineux. Le pointeur contient des informations sur votre fichier, comme suit :

   ```plaintext
   version https://git-lfs.github.com/spec/v1
   oid sha256:lpca0iva5kpz9wva5rgsqsicxrxrkbjr0bh4sy6rz08g2c4tyc441rto5j5bctit
   size 804
   ```

   - Version - la version de la spécification Git LFS utilisée
   - OID - La méthode de hachage utilisée et un identifiant d'objet unique, sous la forme `{hash-method}:{hash}`.
   - Size - La taille du fichier, en octets.

1. Met en file d'attente un job pour recalculer les statistiques de votre projet, y compris la taille de stockage et le stockage d'objets LFS. Votre stockage d'objets LFS correspond à la somme des tailles de tous les objets LFS associés à votre dépôt.

Les fichiers gérés avec Git LFS affichent un badge **LFS** à côté du nom du fichier :

![Statut de suivi Git LFS](img/lfs_badge_v16_0.png)

Les clients Git LFS utilisent l'authentification HTTP Basic et communiquent avec votre serveur via HTTPS. Une fois la requête authentifiée, le client Git LFS reçoit des instructions indiquant où récupérer (ou envoyer) le fichier volumineux.

Votre dépôt Git reste plus léger, ce qui vous aide à respecter les limites de taille des dépôts. Pour plus d'informations, consultez les limites de taille des dépôts [pour GitLab Self-Managed](../../../administration/settings/account_and_limit_settings.md#repository-size-limit) et [pour GitLab.com](../../../user/gitlab_com/_index.md#account-and-limit-settings).

## Comprendre le fonctionnement de Git LFS avec les duplications {#understand-how-git-lfs-works-with-forks}

Lorsque vous dupliquez un dépôt, votre duplication inclut les objets LFS existants du dépôt en amont qui existaient au moment de la duplication. Si vous ajoutez de nouveaux objets LFS à votre duplication, ils appartiennent uniquement à votre duplication, et non au dépôt en amont. Le stockage d'objets total n'augmente que pour votre duplication.

Lorsque vous créez une merge request depuis votre duplication vers le projet en amont et que votre merge request contient un nouvel objet Git LFS, GitLab associe le nouvel objet LFS au projet en amont après la fusion.

## Configurer Git LFS pour un projet {#configure-git-lfs-for-a-project}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

GitLab active Git LFS par défaut pour GitLab Self-Managed et GitLab.com. Il propose à la fois des paramètres au niveau du serveur et des paramètres spécifiques au projet.

- Pour configurer Git LFS sur votre instance, par exemple pour mettre en place un stockage d'objets distant, consultez [l'administration de Git Large File Storage (LFS)](../../../administration/lfs/_index.md).
- Pour configurer Git LFS pour un projet spécifique :

  1. Dans le répertoire racine de votre copie locale du dépôt, exécutez `git lfs install`. Cette commande ajoute :
     - Un hook Git pre-push dans votre dépôt.
     - Un [fichier `.gitattributes`](../../../user/project/repository/files/git_attributes.md) pour gérer le suivi des fichiers individuels et des types de fichiers.
  1. Ajoutez les fichiers et les types de fichiers que vous souhaitez suivre avec Git LFS.

## Activer ou désactiver Git LFS pour un projet {#enable-or-disable-git-lfs-for-a-project}

Git LFS est activé par défaut pour GitLab Self-Managed et GitLab.com.

Prérequis :

- Vous devez disposer du rôle Développeur, Chargé de maintenance ou Propriétaire pour le projet.

Pour activer ou désactiver Git LFS pour votre projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez la section **Visibilité, fonctionnalités du projet, autorisations**.
1. Sélectionnez le bouton bascule **Git Large File Storage (LFS)**.
1. Sélectionnez **Enregistrer les modifications**.

## Ajouter et suivre des fichiers {#add-and-track-files}

Vous pouvez ajouter des fichiers volumineux à Git LFS. Cela vous aide à gérer les fichiers dans les dépôts Git. Lorsque vous suivez des fichiers avec Git LFS, ils sont remplacés par des pointeurs textuels dans Git et stockés sur un serveur distant. Pour plus d'informations, consultez [Git LFS](../file_management.md#git-lfs).

Lorsque vous [configurez Git LFS pour un projet](#configure-git-lfs-for-a-project), assurez-vous de disposer d'un fichier `.gitattributes` dans le répertoire racine du projet. Sans fichier `.gitattributes` à la racine, l'interface utilisateur affiche un avertissement même si vous avez correctement configuré LFS dans les sous-répertoires de votre projet. Pour plus d'informations, consultez [le message d'avertissement de configuration LFS](troubleshooting.md#warning-possible-lfs-configuration-issue).

## Cloner un dépôt qui utilise Git LFS {#clone-a-repository-that-uses-git-lfs}

Lorsque vous clonez un dépôt qui utilise Git LFS, Git détecte les fichiers suivis par LFS et les clone via HTTPS. Si vous exécutez `git clone` avec une URL SSH, comme `user@hostname.com:group/project.git`, vous devez saisir à nouveau vos identifiants GitLab pour l'authentification HTTPS.

Par défaut, les opérations Git LFS s'effectuent via HTTPS, même lorsque Git communique avec votre dépôt via SSH. Dans GitLab 17.2, [la prise en charge SSH pure pour LFS](https://gitlab.com/groups/gitlab-org/-/work_items/11872) a été introduite. Pour savoir comment activer cette fonctionnalité, consultez [le protocole de transfert SSH pur](../../../administration/lfs/_index.md#pure-ssh-transfer-protocol).

Pour récupérer les nouveaux objets LFS d'un dépôt que vous avez déjà cloné, exécutez cette commande :

```shell
git lfs fetch origin main
```

## Migrer un dépôt existant vers Git LFS {#migrate-an-existing-repository-to-git-lfs}

Consultez la [documentation `git-lfs-migrate`](https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-migrate.adoc) pour savoir comment migrer un dépôt Git existant avec Git LFS.

## Supprimer un fichier Git LFS de l'historique du dépôt {#delete-a-git-lfs-file-from-repository-history}

Il est important de comprendre les différences entre l'arrêt du suivi d'un fichier dans Git LFS et la suppression d'un fichier :

- Arrêter le suivi : le fichier reste sur le disque et dans l'historique de votre dépôt. Si des utilisateurs extraient des branches ou des tags historiques, ils ont toujours besoin de la version LFS du fichier.
- Supprimer : le fichier est supprimé, mais reste dans l'historique de votre dépôt.

Pour supprimer un fichier suivi avec Git LFS, consultez [supprimer un fichier](../undo.md#remove-a-file-from-a-repository).

Pour purger intégralement tout l'historique d'un fichier, passé et présent, consultez [gérer les informations sensibles](../undo.md#handle-sensitive-information).

> [!warning]
> La purge de l'historique des fichiers nécessite la réécriture de l'historique Git. Cette action est destructrice et irréversible.

## Réduire la taille du dépôt après la suppression de fichiers volumineux {#reduce-repository-size-after-removing-large-files}

Si vous devez supprimer des fichiers volumineux de l'historique de votre dépôt afin de réduire la taille totale de celui-ci, consultez [réduire la taille du dépôt](../../../user/project/repository/repository_size.md#methods-to-reduce-repository-size).

## Sujets connexes {#related-topics}

- Utilisez Git LFS pour configurer des [verrous de fichiers exclusifs](../file_management.md#configure-file-locks).
- Article de blog : [Premiers pas avec Git LFS](https://about.gitlab.com/blog/getting-started-with-git-lfs-tutorial/)
- [Git LFS avec Git](../file_management.md#git-lfs)
- [Administration de GitLab Git Large File Storage (LFS)](../../../administration/lfs/_index.md) pour GitLab Self-Managed
- [Dépannage de Git LFS](troubleshooting.md)
- [Le fichier `.gitattributes`](../../../user/project/repository/files/git_attributes.md)
