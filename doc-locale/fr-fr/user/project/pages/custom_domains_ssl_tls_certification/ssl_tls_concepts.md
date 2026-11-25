---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Certificats SSL/TLS pour GitLab Pages
description: Concepts relatifs aux certificats HTTPS et SSL/TLS pour les domaines personnalisés sur GitLab Pages.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed

{{< /details >}}

Chaque projet GitLab Pages sur GitLab.com est disponible via HTTPS pour le domaine Pages par défaut (`*.gitlab.io`). Après avoir configuré votre projet Pages avec votre (sous-)domaine personnalisé, si vous souhaitez le sécuriser par HTTPS, vous devez émettre un certificat pour ce (sous-)domaine et l'installer sur votre projet.

> [!note]
> Vous n'êtes pas obligé d'ajouter des certificats à votre (sous-)domaine personnalisé sur votre projet GitLab Pages, bien que cela soit fortement recommandé.

## Importance du HTTPS {#importance-of-https}

Les sites GitLab Pages sont statiques. Ils n'utilisent pas de scripts côté serveur et ne traitent pas de transactions par carte de crédit. Pourquoi ont-ils donc besoin de connexions sécurisées ?

Lorsque le HTTPS est apparu en 1990, le [SSL](https://en.wikipedia.org/wiki/Transport_Layer_Security#SSL_1.0.2C_2.0_and_3.0) était considéré comme une mesure de sécurité « spéciale », nécessaire uniquement pour les grandes entreprises telles que les banques et les sites marchands effectuant des transactions financières.

<!-- vale gitlab_base.Spelling = NO -->

La situation est désormais bien différente. [Selon Josh Aas](https://letsencrypt.org/2015/10/29/phishing-and-malware.html), directeur exécutif de l'[Internet Security Research Group (ISRG)](https://en.wikipedia.org/wiki/Internet_Security_Research_Group) :

<!-- vale gitlab_base.rulename = YES -->

> Nous en sommes venus à réaliser que le HTTPS est important pour presque tous les sites web. Il est important pour tout site web permettant aux utilisateurs de se connecter avec un mot de passe, tout site web qui [suit ses utilisateurs](https://www.washingtonpost.com/news/the-switch/wp/2013/12/10/nsa-uses-google-cookies-to-pinpoint-targets-for-hacking/) de quelque manière que ce soit, tout site web qui [ne veut pas que son contenu soit modifié](https://arstechnica.com/tech-policy/2014/09/why-comcasts-javascript-ad-injections-threaten-security-net-neutrality/), et pour tout site proposant du contenu que les personnes pourraient ne pas vouloir que d'autres sachent qu'elles consomment. Nous avons également appris que tout site non sécurisé par HTTPS [peut être utilisé pour attaquer d'autres sites](https://krebsonsecurity.com/2015/04/dont-be-fodder-for-chinas-great-cannon/).

Les certificats sont importants car ils chiffrent la connexion entre le **client** (vous et vos visiteurs) et le **serveur** (où se trouve votre site), via une chaîne d'authentifications et de validations.

## Organisations soutenant le HTTPS {#organizations-supporting-https}

Il existe un mouvement considérable en faveur de la sécurisation de l'ensemble du web. Le W3C [soutient pleinement cette cause](https://w3ctag.github.io/web-https/) et en explique très bien les raisons. Richard Barnes, rédacteur pour le blog Mozilla Security, a suggéré que [Firefox abandonnerait le HTTP](https://blog.mozilla.org/security/2015/04/30/deprecating-non-secure-http/) et n'accepterait plus les connexions non sécurisées. Récemment, Mozilla a publié une [communication](https://blog.mozilla.org/security/2016/03/29/march-2016-ca-communication/) réitérant l'importance du HTTPS.

## Émission de certificats {#issuing-certificates}

GitLab Pages accepte les certificats fournis au format [PEM](https://knowledge.digicert.com/quovadis), émis par des [autorités de certification](https://en.wikipedia.org/wiki/Certificate_authority) ou sous forme de [certificats auto-signés](https://en.wikipedia.org/wiki/Self-signed_certificate). [Les certificats auto-signés ne sont généralement pas utilisés](https://www.mcafee.com/blogs/other-blogs/mcafee-labs/self-signed-certificates-secure-so-why-ban/) pour les sites web publics, pour des raisons de sécurité et afin de garantir que les navigateurs font confiance au certificat de votre site.

Les différents certificats ont des niveaux de sécurité différents. Un site web personnel statique ne nécessite pas le même niveau de sécurité qu'une application bancaire en ligne, par exemple.

Certaines autorités de certification proposent des certificats gratuits, dans le but de rendre internet plus sécurisé pour tous. La plus populaire est [Let's Encrypt](https://letsencrypt.org/), qui émet des certificats approuvés par la plupart des navigateurs, est open source et gratuite. Consultez [l'intégration de GitLab Pages avec Let's Encrypt](lets_encrypt_integration.md) pour activer le HTTPS sur votre domaine personnalisé.

Tout aussi populaires, les [certificats émis par Cloudflare](https://www.cloudflare.com/products/ssl/), qui propose également un [service CDN gratuit](https://blog.cloudflare.com/cloudflares-free-cdn-and-you/). Leurs certificats sont valables jusqu'à 15 ans. Consultez le tutoriel sur [comment ajouter un certificat Cloudflare à votre site web GitLab Pages](https://about.gitlab.com/blog/setting-up-gitlab-pages-with-cloudflare-certificates/).
