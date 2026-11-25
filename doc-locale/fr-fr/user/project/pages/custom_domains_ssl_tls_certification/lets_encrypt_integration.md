---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Certificats SSL Let's Encrypt automatiques pour GitLab Pages."
title: "Certificats Let's Encrypt de GitLab Pages"
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed

{{< /details >}}

L'intégration de GitLab Pages avec Let's Encrypt (LE) vous permet d'utiliser des certificats LE pour votre site web Pages avec des domaines personnalisés, sans avoir à les émettre et à les mettre à jour vous-même. GitLab s'en charge pour vous, de manière native.

[Let's Encrypt](https://letsencrypt.org) est une autorité de certification gratuite, automatisée et open source.

> [!warning]
> Cette fonctionnalité couvre uniquement les certificats pour les domaines personnalisés, et non le certificat wildcard requis pour exécuter le [daemon Pages](../../../../administration/pages/_index.md) (GitLab Self-Managed, Gratuite, GitLab Premium et GitLab Ultimate uniquement). La génération de certificats wildcard est suivie dans [ce ticket](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/3342).

## Prérequis {#prerequisites}

Avant de pouvoir activer le provisionnement automatique d'un certificat SSL pour votre domaine, assurez-vous de disposer des éléments suivants :

- Avoir créé un [projet](../_index.md#getting-started) dans GitLab contenant le code source de votre site web.
- Avoir acquis un domaine (`example.com`) et ajouté une [entrée DNS](_index.md) pointant vers votre site web Pages. Le domaine de premier niveau (`.com`) doit être un [suffixe public](https://publicsuffix.org/).
- [Avoir ajouté votre domaine à votre projet Pages](_index.md#step-1-add-a-custom-domain) et vérifié votre propriété.
- Avoir vérifié que votre site web est opérationnel et accessible via votre domaine personnalisé.

L'intégration de GitLab avec Let's Encrypt est activée et disponible sur GitLab.com. Pour les instances **GitLab Self-Managed**, assurez-vous que votre administrateur l'a [activée](../../../../administration/pages/_index.md#lets-encrypt-integration).

## Activation de l'intégration Let's Encrypt pour votre domaine personnalisé {#enabling-lets-encrypt-integration-for-your-custom-domain}

Une fois les prérequis satisfaits, activez l'intégration Let's Encrypt :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Pages**.
1. À côté du nom de domaine, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Activez le bouton bascule **Gestion automatique des certificats à l'aide de Let's Encrypt**.

   ![Le bouton bascule Let's Encrypt dans les paramètres du domaine personnalisé.](img/lets_encrypt_integration_v12_1.png)

1. Sélectionnez **Enregistrer les modifications**.

Une fois l'activation effectuée, GitLab obtient un certificat Let's Encrypt et l'ajoute au domaine Pages associé. GitLab le renouvelle également automatiquement.

> [!note]
> L'émission du certificat et la mise à jour de la configuration Pages peuvent prendre jusqu'à une heure. Si vous disposez déjà d'un certificat SSL dans les paramètres du domaine, il continue de fonctionner jusqu'à ce qu'il soit remplacé par le certificat Let's Encrypt.

## Dépannage {#troubleshooting}

### Une erreur s'est produite lors de l'obtention du certificat Let's Encrypt {#something-went-wrong-while-obtaining-the-lets-encrypt-certificate}

Il est possible que vous obteniez une erreur indiquant **Une erreur s'est produite lors de l'obtention du certificat Let's Encrypt**.

Ce problème survient lorsque Let's Encrypt ne peut pas atteindre ou valider votre domaine.

Pour résoudre ce problème :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Visibilité, fonctionnalités du projet, autorisations**.
1. Sous **Pages**, dans la liste déroulante, sélectionnez **Toute personne ayant accès**.
1. Sélectionnez **Déployer** > **Pages** > **Domaines & paramètres**.
1. À côté du nom de domaine, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Dans **État de la vérification**, sélectionnez **Relancer la vérification** ({{< icon name="retry" >}}).

Si vous obtenez la même erreur, vérifiez les points suivants :

- Assurez-vous de n'avoir défini qu'un seul enregistrement DNS `CNAME` ou `A` pour votre domaine.
- Assurez-vous que votre domaine ne possède pas d'enregistrement DNS `AAAA`.
- Si vous disposez d'un enregistrement DNS `CAA` pour votre domaine ou pour des domaines de niveau supérieur, assurez-vous qu'il inclut [`letsencrypt.org`](https://letsencrypt.org/docs/caa/).
- Assurez-vous que votre [domaine est vérifié](_index.md#step-1-add-a-custom-domain).
- Si vous utilisez des [déploiements parallèles](../parallel_deployments.md), assurez-vous que votre déploiement principal possède un `path_prefix` vide. Un `path_prefix` non vide (par exemple, `latest`) empêche le chemin `/.well-known/acme-challenge` d'être servi.

Revenez aux paramètres **Déployer** > **Pages** et relancez la vérification.

### L'obtention d'un certificat est bloquée depuis plus d'une heure {#obtaining-a-certificate-hangs-for-more-than-an-hour}

Si vous avez activé l'intégration Let's Encrypt, mais qu'aucun certificat n'est présent après une heure et que vous voyez le message suivant :

```plaintext
GitLab is obtaining a Let's Encrypt SSL certificate for this domain.
This process can take some time. Please try again later.
```

Supprimez et ajoutez à nouveau le domaine pour GitLab Pages en suivant ces étapes :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Pages**.
1. À côté du nom de domaine, sélectionnez **Supprimer**.
1. [Ajoutez à nouveau le domaine et vérifiez-le](_index.md#step-1-add-a-custom-domain).
1. [Activez l'intégration Let's Encrypt pour votre domaine](#enabling-lets-encrypt-integration-for-your-custom-domain).
1. Si vous obtenez toujours la même erreur :
   1. Assurez-vous de n'avoir correctement défini qu'un seul enregistrement DNS `CNAME` ou `A` pour votre domaine.
   1. Assurez-vous que votre domaine ne possède pas d'enregistrement DNS `AAAA`.
   1. Si vous disposez d'un enregistrement DNS `CAA` pour votre domaine ou pour des domaines de niveau supérieur, assurez-vous que [celui-ci inclut `letsencrypt.org`](https://letsencrypt.org/docs/caa/).
   1. Passez à l'étape 1.

<!-- Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, for example, `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
