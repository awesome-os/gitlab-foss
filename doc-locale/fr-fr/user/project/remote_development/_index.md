---
stage: Create
group: Remote Development
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Utilisez votre navigateur web pour écrire du code dans un environnement sécurisé.
title: Développement à distance
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Le développement à distance est un ensemble de fonctionnalités que vous pouvez utiliser pour apporter des modifications au code sans avoir à installer de dépendances ni à cloner de dépôts localement. Ces fonctionnalités comprennent :

- [Web IDE](#web-ide)
- [Workspaces](#workspaces)

## Web IDE {#web-ide}

Vous pouvez utiliser le [Web IDE](../web_ide/_index.md) pour apporter des modifications à un projet, les committer et les pousser directement depuis votre navigateur web. Ainsi, vous pouvez mettre à jour n'importe quel projet sans avoir à installer de dépendances ni à cloner de dépôts localement.

Le Web IDE ne dispose cependant pas d'un environnement d'exécution natif dans lequel vous pourriez compiler du code, exécuter des tests ou générer des retours en temps réel.

## Workspaces {#workspaces}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate

{{< /details >}}

Vous pouvez utiliser les [workspaces](../../workspace/_index.md) pour créer un environnement de développement complet directement depuis GitLab. Cet environnement s'exécute sur un serveur distant et vous offre une expérience IDE complète sans avoir à installer de dépendances ni à cloner de dépôts localement.

Avec les workspaces, vous pouvez :

- Créer un nouvel environnement de développement.
- Accéder à un IDE complet, incluant un éditeur de code, un terminal et des outils de build.
- Intégrer votre workspace au reste de GitLab, notamment les merge requests et les pipelines CI/CD.
