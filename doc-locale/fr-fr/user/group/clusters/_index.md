---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Clusters Kubernetes au niveau du groupe (basés sur les certificats) (obsolète)
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!warning]
> Cette fonctionnalité a été [dépréciée](https://gitlab.com/groups/gitlab-org/configure/-/work_items/8) dans GitLab 14.5. Pour connecter des clusters à GitLab, utilisez l'[agent GitLab pour Kubernetes](../../clusters/agent/_index.md).

Similaires aux clusters Kubernetes [au niveau du projet](../../project/clusters/_index.md) et [au niveau de l'instance](../../instance/clusters/_index.md), les clusters Kubernetes au niveau du groupe vous permettent de connecter un cluster Kubernetes à votre groupe, vous permettant ainsi d'utiliser le même cluster sur plusieurs projets.

Pour afficher vos clusters Kubernetes au niveau du groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Opération** > **Kubernetes**.

## Projet de gestion du cluster {#cluster-management-project}

Associez un [projet de gestion du cluster](../../clusters/management_project.md) à votre cluster pour gérer les ressources partagées nécessitant des privilèges `cluster-admin` pour l'installation, comme un contrôleur Ingress.

## Compatibilité RBAC {#rbac-compatibility}

Pour chaque projet d'un groupe disposant d'un cluster Kubernetes, GitLab crée un compte de service restreint avec [des privilèges `edit`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) dans l'espace de nommage du projet.

## Priorité des clusters {#cluster-precedence}

Si le cluster du projet est disponible et non désactivé, GitLab utilise le cluster du projet avant d'utiliser tout autre cluster appartenant au groupe contenant le projet. Dans le cas des sous-groupes, GitLab utilise le cluster du groupe ancêtre le plus proche du projet, à condition que le cluster ne soit pas désactivé.

## Plusieurs clusters Kubernetes {#multiple-kubernetes-clusters}

Vous pouvez associer plusieurs clusters Kubernetes à votre groupe et maintenir différents clusters pour différents environnements, tels que le développement, la pré-production et la production.

Lors de l'ajout d'un autre cluster, [définissez une portée d'environnement](#environment-scopes) pour différencier le nouveau cluster de vos autres clusters.

## Clusters gérés par GitLab {#gitlab-managed-clusters}

Vous pouvez choisir d'autoriser GitLab à gérer votre cluster à votre place. Si GitLab gère votre cluster, les ressources pour vos projets sont créées automatiquement. Consultez la section [Contrôles d'accès](../../project/clusters/cluster_access.md) pour plus de détails sur les ressources que GitLab crée pour vous.

Pour les clusters non gérés par GitLab, les ressources spécifiques au projet ne sont pas créées automatiquement. Si vous utilisez [Auto DevOps](../../../topics/autodevops/_index.md) pour les déploiements avec un cluster non géré par GitLab, vous devez vous assurer que :

- Le compte de service de déploiement du projet dispose des autorisations nécessaires pour déployer vers [`KUBE_NAMESPACE`](../../project/clusters/deploy_to_cluster.md#deployment-variables).
- `KUBECONFIG` reflète correctement toute modification apportée à `KUBE_NAMESPACE` (ce n'est [pas automatique](https://gitlab.com/gitlab-org/gitlab/-/issues/31519)). Il est déconseillé de modifier `KUBE_NAMESPACE` directement.

### Vider le cache du cluster {#clearing-the-cluster-cache}

Si vous choisissez d'autoriser GitLab à gérer votre cluster, GitLab stocke une version mise en cache des espaces de nommage et des comptes de service qu'il crée pour vos projets. Si vous modifiez ces ressources manuellement dans votre cluster, ce cache peut se désynchroniser avec votre cluster, ce qui peut entraîner l'échec des jobs de déploiement.

Pour vider le cache :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Opération** > **Kubernetes**.
1. Sélectionnez votre cluster.
1. Développez **Paramètres avancés**.
1. Sélectionnez **Vider le cache du cluster**.

## Domaine de base {#base-domain}

Les domaines au niveau du cluster permettent la prise en charge de plusieurs domaines par [cluster Kubernetes multiple](#multiple-kubernetes-clusters). Lors de la spécification d'un domaine, celui-ci est automatiquement défini comme variable d'environnement (`KUBE_INGRESS_BASE_DOMAIN`) pendant les étapes d'[Auto DevOps](../../../topics/autodevops/_index.md).

Le domaine doit avoir un DNS générique configuré sur l'adresse IP Ingress. [Plus de détails](../../project/clusters/gitlab_managed_clusters.md#base-domain).

## Portées d'environnement {#environment-scopes}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lors de l'ajout de plusieurs clusters Kubernetes à votre projet, vous devez les différencier à l'aide d'une portée d'environnement. La portée d'environnement associe les clusters aux [environnements](../../../ci/environments/_index.md) de la même manière que fonctionnent les [variables CI/CD spécifiques à l'environnement](../../../ci/environments/_index.md#limit-the-environment-scope-of-a-cicd-variable).

Lors de l'évaluation de l'environnement correspondant à la portée d'environnement d'un cluster, la [priorité des clusters](#cluster-precedence) entre en jeu. Le cluster au niveau du projet a la priorité, suivi du groupe ancêtre le plus proche, puis du parent de ce groupe, et ainsi de suite.

Par exemple, si votre projet possède les clusters Kubernetes suivants :

| Cluster    | Portée d'environnement   | Emplacement     |
| ---------- | ------------------- | ----------|
| Projet    | `*`                 | Projet   |
| Staging    | `staging/*`         | Projet   |
| Production | `production/*`      | Projet   |
| Test       | `test`              | Groupe     |
| Développement| `*`                 | Groupe     |

Et les environnements suivants sont définis dans le fichier `.gitlab-ci.yml` :

```yaml
stages:
  - test
  - deploy

test:
  stage: test
  script: sh test

deploy to staging:
  stage: deploy
  script: make deploy
  environment:
    name: staging/$CI_COMMIT_REF_NAME
    url: https://staging.example.com/

deploy to production:
  stage: deploy
  script: make deploy
  environment:
    name: production/$CI_COMMIT_REF_NAME
    url: https://example.com/
```

Le résultat est :

- Le cluster Project est utilisé pour le job `test`.
- Le cluster Staging est utilisé pour le job `deploy to staging`.
- Le cluster Production est utilisé pour le job `deploy to production`.

## Environnements du cluster {#cluster-environments}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour une vue consolidée des [environnements](../../../ci/environments/_index.md) CI déployés sur le cluster Kubernetes, consultez la documentation relative aux [environnements du cluster](../../clusters/environments.md).

## Sécurité des runners {#security-of-runners}

Pour des informations importantes sur la configuration sécurisée des runners, consultez la documentation [Sécurité des runners](../../project/clusters/cluster_access.md#security-of-runners) pour les clusters au niveau du projet.

## Plus d'informations {#more-information}

Pour des informations sur l'intégration de GitLab et Kubernetes, consultez [Clusters Kubernetes](../../infrastructure/clusters/_index.md).
