---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Signez les commits et les tags dans votre dépôt GitLab avec des clés SSH.
title: Signer les commits et les tags avec des clés SSH
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous signez des commits ou des tags avec des clés SSH, GitLab utilise les clés SSH publiques associées à votre compte GitLab pour vérifier la signature de façon cryptographique. En cas de succès, GitLab affiche un label **Vérifié** sur le commit ou le tag.

Pour que GitLab considère un commit comme vérifié :

- Vous devez ajouter la clé SSH utilisée pour signer le commit à votre compte GitLab avec un [type d'utilisation](../../../ssh.md#add-an-ssh-key-to-your-gitlab-account) défini sur **Authentification et signature** ou **Signature**.
- L'adresse e-mail du committer dans votre configuration Git doit correspondre à une [adresse e-mail vérifiée](../../../profile/_index.md#change-your-primary-email) associée à votre compte GitLab.

Si la signature est valide mais que l'e-mail du committer ne correspond pas à un e-mail vérifié sur votre compte, le commit est marqué comme **Non vérifié**.

Vous pouvez utiliser les mêmes clés SSH pour l'authentification `git+ssh` à GitLab et pour signer les signatures de commit, à condition que leur type d'utilisation soit **Authentification et signature**. Cela peut être vérifié sur la page [d'ajout d'une clé SSH à votre compte GitLab](../../../ssh.md#add-an-ssh-key-to-your-gitlab-account).

Pour plus d'informations sur la gestion des clés SSH associées à votre compte GitLab, consultez [utiliser les clés SSH pour communiquer avec GitLab](../../../ssh.md).

## Configurer Git pour signer les commits et les tags avec votre clé SSH {#configure-git-to-sign-commits-and-tags-with-your-ssh-key}

Après avoir [créé une clé SSH](../../../ssh.md#generate-an-ssh-key-pair) et [l'avoir ajoutée à votre compte GitLab](../../../ssh.md#add-an-ssh-key-to-your-gitlab-account), configurez Git pour commencer à utiliser la clé.

Prérequis :

- Git 2.34.0 ou version ultérieure.
- OpenSSH 8.1 ou version ultérieure.

  > [!note]
  > OpenSSH 8.7 présente une fonctionnalité de signature défaillante. Si vous utilisez OpenSSH 8.7, mettez à niveau vers OpenSSH 8.8.

- Une clé SSH avec le **Type d'utilisation** `Authentication & Signing` ou `Signing`. Les types de clés SSH suivants sont pris en charge :
  - ED25519
  - ED25519_SK
  - RSA
  - ECDSA
  - ECDSA_SK

Pour configurer Git afin d'utiliser votre clé :

1. Configurez Git pour utiliser SSH pour la signature des commits :

   ```shell
   git config --global gpg.format ssh
   ```

1. Indiquez quelle clé SSH publique utiliser comme clé de signature et modifiez le nom de fichier (`~/.ssh/examplekey.pub`) pour indiquer l'emplacement de votre clé. Le nom de fichier peut différer selon la façon dont vous avez généré votre clé :

   ```shell
   git config --global user.signingkey ~/.ssh/examplekey.pub
   ```

## Signer les commits avec votre clé SSH {#sign-commits-with-your-ssh-key}

Prérequis :

- Vous avez [créé une clé SSH](../../../ssh.md#generate-an-ssh-key-pair).
- Vous avez [ajouté la clé](../../../ssh.md#add-an-ssh-key-to-your-gitlab-account) à votre compte GitLab.
- Vous avez [configuré Git pour signer les commits](#configure-git-to-sign-commits-and-tags-with-your-ssh-key) avec votre clé SSH.
- Votre `user.email` Git correspond à une [adresse e-mail vérifiée](../../../profile/_index.md#change-your-primary-email) associée à votre compte GitLab.

Pour signer un commit :

1. Utilisez le flag `-S` lors de la signature de vos commits :

   ```shell
   git commit -S -m "My commit msg"
   ```

1. Facultatif. Si vous ne souhaitez pas saisir le flag `-S` à chaque commit, demandez à Git de signer vos commits automatiquement :

   ```shell
   git config --global commit.gpgsign true
   ```

1. Si votre clé SSH est protégée, Git vous invite à saisir votre phrase secrète.
1. Effectuez un push vers GitLab.
1. Vérifiez que vos commits [sont vérifiés](#verify-commits). La vérification des signatures utilise le fichier `allowed_signers` pour associer les e-mails aux clés SSH. Pour obtenir de l'aide sur la configuration de ce fichier, consultez [vérifier les commits localement](#verify-commits-locally).

## Signer et vérifier les tags {#sign-and-verify-tags}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/384473) dans GitLab 18.3 [avec un feature flag](../../../../administration/feature_flags/_index.md) nommé `render_ssh_signed_tags_verification_status`. Fonctionnalité désactivée par défaut.
- [Activation sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/issues/561452) dans GitLab 18.11.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/596049) dans GitLab 19.1. Le feature flag `render_ssh_signed_tags_verification_status` a été supprimé.

{{< /history >}}

Après avoir [configuré Git pour signer les commits et les tags](#configure-git-to-sign-commits-and-tags-with-your-ssh-key) avec votre clé SSH, vous pouvez signer vos tags :

1. Lorsque vous créez un tag Git, ajoutez le flag `-s` :

   ```shell
   git tag -s v1.1.1 -m "My signed tag"
   ```

1. Effectuez un push vers GitLab et vérifiez que vos tags sont signés à l'aide de cette commande :

   ```shell
   git tag --verify v1.1.1
   ```

1. Facultatif. Pour signer les tags automatiquement sans le flag `-s`, exécutez :

   ```shell
   git config --global tag.gpgsign true
   ```

## Vérifier les commits {#verify-commits}

Vous pouvez vérifier tous les types de commits signés [dans l'interface utilisateur de GitLab](_index.md#verify-commits). Les commits signés avec une clé SSH peuvent également être vérifiés localement.

### Vérifier les commits localement {#verify-commits-locally}

Pour vérifier les commits localement, créez un [fichier de signataires autorisés](https://man7.org/linux/man-pages/man1/ssh-keygen.1.html#ALLOWED_SIGNERS) pour que Git associe les clés SSH publiques aux utilisateurs. Cet exemple utilise `~/.ssh/allowed_signers`, mais vous pouvez spécifier un chemin différent. Utilisez le même chemin dans les étapes suivantes.

1. Créez un répertoire SSH :

   ```shell
   mkdir -p ~/.ssh
   ```

1. Créez un fichier de signataires autorisés.

   ```shell
   touch ~/.ssh/allowed_signers
   ```

1. Configurez Git pour utiliser le fichier :

   ```shell
   git config gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"
   ```

1. Ajoutez votre entrée au fichier de signataires autorisés. Remplacez `<MY_KEY>` par le nom de votre clé. Si vous avez choisi un chemin différent à l'étape 1, remplacez `~/.ssh/allowed_signers` par ce chemin :

   ```shell
   # Declaring the `git` namespace helps prevent cross-protocol attacks.
   echo "$(git config --get user.email) namespaces=\"git\" $(cat ~/.ssh/<MY_KEY>.pub)" >> ~/.ssh/allowed_signers
   ```

   L'entrée résultante contient votre adresse e-mail, le type de clé et le contenu de la clé :

   ```plaintext
   example@gitlab.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAmaTS47vRmsKyLyK1jlIFJn/i8wdGQ3J49LYyIYJ2hv
   ```

1. Répétez cette étape pour chaque utilisateur supplémentaire que vous souhaitez vérifier. Si vous collaborez avec d'autres contributeurs, envisagez d'intégrer ce fichier dans votre dépôt Git.

1. Utilisez `git log --show-signature` pour afficher le statut de signature des commits :

   ```shell
   $ git log --show-signature

   commit e2406b6cd8ebe146835ceab67ff4a5a116e09154 (HEAD -> main, origin/main, origin/HEAD)
   Good "git" signature for johndoe@example.com with ED25519 key SHA256:Ar44iySGgxic+U6Dph4Z9Rp+KDaix5SFGFawovZLAcc
   Author: John Doe <johndoe@example.com>
   Date:   Tue Nov 29 06:54:15 2022 -0600

       SSH signed commit
   ```

## Commits signés avec des clés SSH supprimées {#signed-commits-with-removed-ssh-keys}

Vous pouvez révoquer ou supprimer vos clés SSH utilisées pour signer des commits. Pour plus d'informations, consultez [supprimer une clé SSH](../../../ssh.md#remove-an-ssh-key).

La suppression de votre clé SSH peut avoir un impact sur les commits signés avec cette clé :

- La révocation de votre clé SSH marque vos commits précédents comme **Non vérifié**. Jusqu'à ce que vous ajoutiez une nouvelle clé SSH, les nouveaux commits sont également marqués comme **Non vérifié**.
- La suppression de votre clé SSH n'a aucun impact sur vos commits précédents. Jusqu'à ce que vous ajoutiez une nouvelle clé SSH, les nouveaux commits sont marqués comme **Non vérifié**.

## Sujets connexes {#related-topics}

- [Signer les commits et les tags avec des certificats X.509](x509.md)
- [Signer les commits avec GPG](gpg.md)
- [API de commits](../../../../api/commits.md)
