---
stage: GitLab Delivery
group: Operate
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Autres chemins de mise à niveau
description: "Passez d'une édition à une autre ou changez de méthode d'installation."
---

Les mises à niveau ne consistent pas toujours à passer d'une version de GitLab à une autre. D'autres chemins sont disponibles.

## Convertir vers l'édition Enterprise {#convert-to-enterprise-edition}

Vous pouvez convertir votre instance GitLab Community Edition (CE) en instance GitLab Enterprise Edition (EE) :

- [Convertir une instance de package Linux vers EE](package.md)
- [Convertir une instance Docker vers EE](docker.md)
- [Convertir une instance compilée manuellement vers EE](self_compiled.md)
- [Convertir une instance GitLab Helm chart vers EE](https://docs.gitlab.com/charts/installation/deployment/#convert-community-edition-to-enterprise-edition)

Si nécessaire, vous pouvez [revenir de l'édition Enterprise à l'édition Community](revert.md).

## Convertir une instance compilée manuellement en package Linux {#convert-a-self-compiled-instance-to-a-linux-package}

Si vous disposez d'une instance GitLab compilée manuellement, vous pouvez [convertir une instance GitLab compilée manuellement en package Linux](https://docs.gitlab.com/omnibus/update/convert_to_omnibus/).
