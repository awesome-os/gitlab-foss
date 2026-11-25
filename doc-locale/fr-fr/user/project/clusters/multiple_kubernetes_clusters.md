---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Plusieurs clusters par projet avec des certificats de cluster (déprécié)
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed

{{< /details >}}

> [!warning]
> L'utilisation de plusieurs clusters Kubernetes pour un seul projet **avec des certificats de cluster** a été [dépréciée](https://gitlab.com/groups/gitlab-org/configure/-/work_items/8) dans GitLab 14.5. Pour connecter des clusters à GitLab, utilisez l'[agent GitLab pour Kubernetes](../../clusters/agent/_index.md).

Vous pouvez associer plus d'un cluster Kubernetes à votre projet. Vous pouvez ainsi disposer de différents clusters pour différents environnements, comme le développement, la staging, la production, etc. Ajoutez un autre cluster, comme vous l'avez fait la première fois, et assurez-vous de [définir une portée d'environnement](#setting-the-environment-scope) qui différencie le nouveau cluster des autres.

## Définir la portée de l'environnement {#setting-the-environment-scope}

Lorsque vous ajoutez plusieurs clusters Kubernetes à votre projet, vous devez les différencier à l'aide d'une portée d'environnement. La portée de l'environnement associe les clusters aux [environnements](../../../ci/environments/_index.md) de la même façon que fonctionnent les [variables CI/CD spécifiques à l'environnement](../../../ci/environments/_index.md#limit-the-environment-scope-of-a-cicd-variable).

La portée d'environnement par défaut est `*`, ce qui signifie que tous les jobs, quel que soit leur environnement, utilisent ce cluster. Chaque portée ne peut être utilisée que par un seul cluster dans un projet, et une erreur de validation se produit dans le cas contraire. De plus, les jobs pour lesquels aucun mot-clé d'environnement n'est défini ne peuvent accéder à aucun cluster.

Par exemple, un projet peut avoir les clusters Kubernetes suivants :

| Cluster     | Portée de l'environnement |
| ----------- | ----------------- |
| Développement | `*`               |
| Production  | `production`      |

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
    name: staging
    url: https://staging.example.com/

deploy to production:
  stage: deploy
  script: make deploy
  environment:
    name: production
    url: https://example.com/
```

Les résultats :

- Les détails du cluster de développement sont disponibles dans le job `deploy to staging`.
- Les détails du cluster de production sont disponibles dans le job `deploy to production`.
- Aucun détail de cluster n'est disponible dans le job `test` car il ne définit aucun environnement.
