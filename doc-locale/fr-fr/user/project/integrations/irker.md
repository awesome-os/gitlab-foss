---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: irker (passerelle IRC)
description: "Configurez l'intégration irker pour envoyer des notifications push GitLab aux canaux IRC."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

GitLab fournit un moyen d'envoyer des messages de mise à jour à un serveur irker. Une fois l'intégration configurée, chaque push vers un projet déclenche l'envoi de données directement au serveur irker.

Voir aussi la [documentation de l'API d'intégration irker](../../../api/project_integrations.md).

Pour plus d'informations, consultez la [page d'accueil du projet irker](https://gitlab.com/esr/irker).

## Configurer un daemon irker {#set-up-an-irker-daemon}

Vous devez configurer un daemon irker. Pour ce faire :

1. Téléchargez le code irker [depuis son dépôt](https://gitlab.com/esr/irker) :

   ```shell
   git clone https://gitlab.com/esr/irker.git
   ```

1. Exécutez le script Python nommé `irkerd`. Ce script fait office de passerelle. Il agit à la fois comme client IRC, pour envoyer des messages à un serveur IRC, et comme serveur TCP, pour recevoir des messages du service GitLab.

Si le serveur irker s'exécute sur la même machine, vous avez terminé. Sinon, vous devez suivre les premières étapes de la section suivante.

> [!warning]
> irker ne dispose pas d'authentification intégrée, ce qui le rend vulnérable aux spams sur les canaux IRC s'il est hébergé en dehors d'un pare-feu. Pour éviter les abus, assurez-vous d'exécuter le daemon sur un réseau sécurisé. Pour plus de détails, consultez [l'analyse de sécurité d'irker](http://www.catb.org/~esr/irker/security.html).

## Effectuez ces étapes dans GitLab {#complete-these-steps-in-gitlab}

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Intégrations**.
1. Sélectionnez **irker (passerelle IRC)**.
1. Sous **Activer l'intégration**, cochez la case **Actif**.
1. Facultatif. Sous **Hôte du serveur**, saisissez l'adresse de l'hôte du serveur où s'exécute `irkerd`. Si ce champ est vide, la valeur par défaut est `localhost`.
1. Facultatif. Sous **Port du serveur**, saisissez le port du serveur de `irkerd`. Si ce champ est vide, la valeur par défaut est `6659`.
1. Facultatif. Sous **URI IRC par défaut**, saisissez l'URI IRC par défaut, au format `irc[s]://domain.name`. Elle est ajoutée en préfixe à chaque canal ou utilisateur fourni sous **Destinataires**, qui n'est pas une URI complète.
1. Sous **Destinataires**, saisissez les utilisateurs ou canaux devant recevoir les mises à jour, séparés par des espaces (par exemple, `#channel1 user1`). Pour plus de détails, consultez [Saisir les destinataires irker](#enter-irker-recipients).
1. Facultatif. Pour mettre les messages en évidence, cochez la case **Coloriser les messages**.
1. Facultatif. Sélectionnez **Tester les paramètres**.
1. Sélectionnez **Enregistrer les modifications**.

## Saisir les destinataires irker {#enter-irker-recipients}

Si vous avez laissé la zone de texte **URI IRC par défaut** vide, saisissez les destinataires sous forme d'URI complète : `irc[s]://irc.network.net[:port]/#channel`. Si vous avez saisi une URI IRC par défaut, vous pouvez utiliser uniquement les noms de canaux ou d'utilisateurs.

Pour envoyer des messages :

- Vers un canal (par exemple, `#chan`), irker accepte les noms de canaux de la forme `chan` et `#chan`.
- Vers un canal protégé par mot de passe, ajoutez `?key=thesecretpassword` au nom du canal, en remplaçant `thesecretpassword` par le mot de passe du canal. Par exemple, `chan?key=hunter2`. Ne mettez pas le signe `#` devant le nom du canal. Si vous le faites, irker tente de rejoindre un canal nommé `#chan?key=password`, ce qui peut divulguer le mot de passe du canal via la commande IRC `/whois`. Un bug persistant d'irker est à l'origine de ce comportement.
- Dans une requête utilisateur, ajoutez `,isnick` après le nom d'utilisateur. Par exemple, `UserSmith,isnick`.
