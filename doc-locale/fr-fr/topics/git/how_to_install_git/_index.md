---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Comment installer Git sur votre machine locale.
title: Installer Git
---

Pour contribuer aux projets GitLab, vous devez télécharger, installer et configurer le client Git sur votre machine locale. GitLab utilise le protocole SSH pour communiquer de manière sécurisée avec Git. Avec SSH, vous pouvez vous authentifier auprès du serveur distant GitLab sans avoir à saisir votre nom d'utilisateur et votre mot de passe à chaque fois.

Après avoir installé et configuré Git, [générez et ajoutez une paire de clés SSH](../../../user/ssh.md#generate-an-ssh-key-pair) à votre compte GitLab.

## Installer et mettre à jour Git {#install-and-update-git}

{{< tabs >}}

{{< tab title="macOS" >}}

Bien qu'une version de Git soit fournie par macOS, vous devriez installer la dernière version de Git. Une façon courante d'installer Git est d'utiliser [Homebrew](https://brew.sh/index.html).

Pour installer la dernière version de Git sur macOS avec Homebrew :

1. Si vous n'avez jamais installé Homebrew auparavant, suivez les [instructions d'installation de Homebrew](https://brew.sh/index.html).
1. Dans un terminal, installez Git en exécutant `brew install git`.
1. Vérifiez que Git fonctionne sur votre machine locale :

   ```shell
   git --version
   ```

Maintenez Git à jour en exécutant régulièrement la commande suivante :

```shell
brew update && brew upgrade git
```

{{< /tab >}}

{{< tab title="Ubuntu Linux" >}}

Bien qu'une version de Git soit fournie par Ubuntu, vous devriez installer la dernière version de Git. La dernière version est disponible via une archive de paquets personnelle (PPA).

Pour installer la dernière version de Git sur Ubuntu Linux avec un PPA :

1. Dans un terminal, configurez le PPA requis, mettez à jour la liste des paquets Ubuntu et installez `git` :

   ```shell
   sudo apt-add-repository ppa:git-core/ppa
   sudo apt-get update
   sudo apt-get install git
   ```

1. Vérifiez que Git fonctionne sur votre machine locale :

   ```shell
   git --version
   ```

Maintenez Git à jour en exécutant régulièrement la commande suivante :

```shell
sudo apt-get update && sudo apt-get install git
```

{{< /tab >}}

{{< tab title="Autres systèmes d'exploitation" >}}

Pour plus d'informations sur le téléchargement et l'installation de Git sur d'autres systèmes d'exploitation, consultez le [site officiel de Git](https://git-scm.com/downloads/).

{{< /tab >}}

{{< /tabs >}}

## Configurer Git {#configure-git}

Pour commencer à utiliser Git depuis votre machine locale, vous devez saisir vos identifiants afin de vous identifier en tant qu'auteur de votre travail.

Vous pouvez configurer votre identité Git localement ou globalement :

- Localement : à utiliser pour le projet actuel uniquement.
- Globalement : à utiliser pour tous les projets actuels et futurs.

{{< tabs >}}

{{< tab title="Configuration locale" >}}

Configurez votre identité Git localement pour l'utiliser uniquement pour le projet actuel.

Le nom complet et l'adresse e-mail doivent correspondre à ceux que vous utilisez dans GitLab.

1. Dans votre terminal, ajoutez votre nom complet. Par exemple :

   ```shell
   git config --local user.name "Alex Smith"
   ```

1. Ajoutez votre adresse e-mail. Par exemple :

   ```shell
   git config --local user.email "your_email_address@example.com"
   ```

1. Pour vérifier la configuration, exécutez :

   ```shell
   git config --local --list
   ```

{{< /tab >}}

{{< tab title="Configuration globale" >}}

Configurez votre identité Git globalement pour l'utiliser pour tous les projets actuels et futurs sur votre machine.

Le nom complet et l'adresse e-mail doivent correspondre à ceux que vous utilisez dans GitLab.

1. Dans votre terminal, ajoutez votre nom complet. Par exemple :

   ```shell
   git config --global user.name "Sidney Jones"
   ```

1. Ajoutez votre adresse e-mail. Par exemple :

   ```shell
   git config --global user.email "your_email_address@example.com"
   ```

1. Pour vérifier la configuration, exécutez :

   ```shell
   git config --global --list
   ```

{{< /tab >}}

{{< /tabs >}}

### Vérifier les paramètres de configuration Git {#check-git-configuration-settings}

Pour vérifier vos paramètres Git configurés, exécutez :

```shell
git config user.name && git config user.email
```

## Sujets connexes {#related-topics}

- [Documentation sur la configuration de Git](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)
- [Utiliser des clés SSH pour communiquer avec GitLab](../../../user/ssh.md)
