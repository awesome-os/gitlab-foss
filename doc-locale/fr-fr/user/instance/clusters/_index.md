---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Clusters Kubernetes d'instance (basés sur les certificats) (obsolète)"
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

> [!warning]
> Cette fonctionnalité a été [dépréciée](https://gitlab.com/groups/gitlab-org/configure/-/work_items/8) dans GitLab 14.5. Pour connecter des clusters à GitLab, utilisez l'[agent GitLab pour Kubernetes](../../clusters/agent/_index.md).

Similaire aux clusters Kubernetes pour les [projets](../../project/clusters/_index.md) et les [groupes](../../group/clusters/_index.md), les clusters Kubernetes d'instance vous permettent de connecter un cluster Kubernetes à l'instance GitLab et d'utiliser le même cluster dans plusieurs projets.

Pour afficher les clusters Kubernetes de votre instance :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Kubernetes**.

## Priorité des clusters {#cluster-precedence}

GitLab tente de faire correspondre les clusters dans l'ordre suivant :

- Clusters de projet.
- Clusters de groupe.
- Clusters d'instance.

Pour être sélectionné, le cluster doit être activé et correspondre au [sélecteur d'environnement](../../../ci/environments/_index.md#limit-the-environment-scope-of-a-cicd-variable).

## Environnements de cluster {#cluster-environments}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour une vue consolidée des [environnements](../../../ci/environments/_index.md) CI déployés sur le cluster Kubernetes, consultez la documentation relative aux [environnements de cluster](../../clusters/environments.md).

## Plus d'informations {#more-information}

Pour en savoir plus sur l'intégration de GitLab et de Kubernetes, consultez la page [Clusters Kubernetes](../../infrastructure/clusters/_index.md).
