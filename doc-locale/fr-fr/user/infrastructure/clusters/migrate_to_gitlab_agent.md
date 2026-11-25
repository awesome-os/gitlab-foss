---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Migrer vers l'agent GitLab pour Kubernetes"
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Pour connecter votre cluster Kubernetes à GitLab, vous pouvez utiliser :

- [Un workflow GitOps](../../clusters/agent/gitops.md).
- [Un workflow GitLab CI/CD](../../clusters/agent/ci_cd_workflow.md).
- [Une intégration basée sur des certificats](_index.md).

L'intégration basée sur des certificats est [dépréciée](https://about.gitlab.com/blog/deprecating-the-cert-based-kubernetes-integration/) dans GitLab 14.5. Les plans de mise hors service sont décrits :

- pour les [clients GitLab.com](../../../update/deprecations.md#gitlabcom-certificate-based-integration-with-kubernetes).
- pour les [clients GitLab Self-Managed](../../../update/deprecations.md#gitlab-self-managed-certificate-based-integration-with-kubernetes).

Si vous utilisez l'intégration basée sur des certificats, vous devriez migrer vers un autre workflow dès que possible.

En règle générale, pour migrer les clusters qui reposent sur GitLab CI/CD, vous pouvez utiliser le [workflow CI/CD](../../clusters/agent/ci_cd_workflow.md). Ce workflow utilise un agent pour se connecter à votre cluster. L'agent :

- N'est pas exposé à Internet.
- Ne nécessite pas un accès complet [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) à GitLab.

> [!note]
> L'intégration basée sur des certificats était utilisée pour des fonctionnalités GitLab populaires telles que les applications gérées par GitLab, les clusters gérés par GitLab et Auto DevOps.

## Trouver les clusters basés sur des certificats {#find-certificate-based-clusters}

Vous pouvez trouver tous les clusters basés sur des certificats dans une instance ou un groupe GitLab, y compris les sous-groupes et les projets, en utilisant [une API dédiée](../../../api/cluster_discovery.md#retrieve-certificate-based-clusters). L'interrogation de l'API avec un identifiant de groupe renvoie tous les clusters basés sur des certificats définis au niveau du groupe fourni ou en dessous.

Les clusters définis dans les groupes parents ne sont pas renvoyés dans ce cas. Ce comportement aide les propriétaires de groupe à trouver tous les clusters qu'ils doivent migrer.

Les clusters désactivés sont également renvoyés afin d'éviter de les oublier accidentellement.

> [!note]
> L'API de découverte de clusters ne fonctionne pas pour les espaces de nommage personnels.

## Migrer les déploiements génériques {#migrate-generic-deployments}

Pour migrer les déploiements génériques :

1. Installez l'[agent GitLab pour Kubernetes](../../clusters/agent/install/_index.md).
1. Suivez le workflow CI/CD pour [autoriser l'agent à accéder](../../clusters/agent/ci_cd_workflow.md#authorize-agent-access) aux groupes et aux projets, ou pour [sécuriser l'accès avec l'emprunt d'identité](../../clusters/agent/ci_cd_workflow.md#restrict-project-and-group-access-by-using-impersonation).
1. Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.
1. Dans la section des clusters basés sur des certificats, ouvrez le cluster qui sert la même portée d'environnement.
1. Sélectionnez l'onglet **Détails** et désactivez le cluster.

## Migrer des clusters gérés par GitLab vers des ressources Kubernetes {#migrate-from-gitlab-managed-clusters-to-kubernetes-resources}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate

{{< /details >}}

Avec les clusters gérés par GitLab, GitLab crée des comptes de service et des espaces de nommage distincts pour chaque branche et effectue les déploiements à l'aide de ces ressources.

Désormais, vous pouvez utiliser les [ressources Kubernetes gérées par GitLab](../../clusters/agent/managed_kubernetes_resources.md) pour accéder en libre-service aux ressources avec des contrôles de sécurité renforcés.

Avec les ressources Kubernetes gérées par GitLab, vous pouvez :

- Configurer des environnements de manière sécurisée sans intervention manuelle.
- Contrôler la création des ressources et les accès sans accorder aux développeurs des autorisations d'administration du cluster.
- Fournir des capacités en libre-service aux développeurs lorsqu'ils créent un nouveau projet ou environnement.
- Permettre aux développeurs de déployer des versions de test et de développement dans des espaces de nommage dédiés ou partagés.

Prérequis :

- Installez l'[agent GitLab pour Kubernetes](../../clusters/agent/install/_index.md).
- [Autorisez l'agent](../../clusters/agent/ci_cd_workflow.md#authorize-agent-access) à accéder aux projets ou groupes concernés.
- Vérifiez le statut de la case à cocher **Espace de nommage par environnement** sur la page d'intégration de votre cluster basé sur des certificats.

Pour migrer des clusters gérés par GitLab vers des ressources Kubernetes gérées par GitLab :

1. Si vous migrez un environnement existant, configurez un agent pour l'environnement via le [tableau de bord pour Kubernetes](../../../ci/environments/kubernetes_dashboard.md#configure-a-dashboard) ou l'[API Environments](../../../api/environments.md).
1. Configurez l'agent pour activer la gestion des ressources dans votre fichier de configuration d'agent :

   ```yaml
   ci_access:
      projects:
        - id: <your_group/your_project>
          access_as:
            ci_job: {}
          resource_management:
            enabled: true
      groups:
        - id: <your_other_group>
          access_as:
            ci_job: {}
          resource_management:
            enabled: true
   ```

1. Créez un modèle d'environnement sous `.gitlab/agents/<agent-name>/environment_templates/default.yaml`. Vérifiez le statut de la case à cocher **Espace de nommage par environnement** sur la page d'intégration de votre cluster basé sur des certificats.

   Si **Espace de nommage par environnement** était coché, utilisez le modèle suivant :

   ```yaml
   objects:
     - apiVersion: v1
       kind: Namespace
       metadata:
         # the `.legacy_namespace` produces something like:
         # '{{ .project.slug }}-{{ .project.id }}-{{ .environment.slug }}'
         # that is compatible with what the certificate-based cluster integration
         # would have generated.
         name: '{{ .legacy_namespace }}'
     - apiVersion: rbac.authorization.k8s.io/v1
       kind: RoleBinding
       metadata:
         name: 'bind-{{ .agent.id }}-{{ .project.id }}-{{ .environment.slug }}'
         namespace: '{{ .legacy_namespace }}'
       subjects:
         - kind: Group
           apiGroup: rbac.authorization.k8s.io
           name: 'gitlab:project_env:{{ .project.id }}:{{ .environment.slug }}'
       roleRef:
         apiGroup: rbac.authorization.k8s.io
         kind: ClusterRole
         name: admin
   ```

   Si **Espace de nommage par environnement** était décoché, utilisez le modèle suivant :

   ```yaml
   objects:
     - apiVersion: v1
       kind: Namespace
       metadata:
         name: '{{ .project.slug | slugify }}-{{ .project.id }}'
     - apiVersion: rbac.authorization.k8s.io/v1
       kind: RoleBinding
       metadata:
         name: 'bind-{{ .agent.id }}-{{ .project.id }}-{{ .environment.slug }}'
         namespace: '{{ .project.slug | slugify }}-{{ .project.id }}'
       subjects:
         - kind: Group
           apiGroup: rbac.authorization.k8s.io
           name: 'gitlab:project_env:{{ .project.id }}:{{ .environment.slug }}'
       roleRef:
         apiGroup: rbac.authorization.k8s.io
         kind: ClusterRole
         name: admin
   ```

1. Dans votre configuration CI/CD, utilisez l'agent avec la syntaxe `environment.kubernetes.agent: <path/to/agent/project:agent-name>`.
1. Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.
1. Dans la section des clusters basés sur des certificats, ouvrez le cluster qui sert la même portée d'environnement.
1. Sélectionnez l'onglet **Détails** et désactivez le cluster.

## Migrer depuis Auto DevOps {#migrate-from-auto-devops}

Dans votre projet Auto DevOps, vous pouvez utiliser l'agent GitLab pour Kubernetes afin de vous connecter à votre cluster Kubernetes.

Prérequis :

- Installez l'[agent GitLab pour Kubernetes](../../clusters/agent/install/_index.md).
- [Autorisez l'agent](../../clusters/agent/ci_cd_workflow.md#authorize-agent-access) à accéder aux projets ou groupes concernés.

Pour migrer depuis Auto DevOps :

1. Dans GitLab, accédez au projet dans lequel vous utilisez Auto DevOps.
1. Ajoutez trois variables. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD** et développez **Variables**.
   - Ajoutez une clé appelée `KUBE_INGRESS_BASE_DOMAIN` avec le domaine de déploiement de l'application comme valeur.
   - Ajoutez une clé appelée `KUBE_CONTEXT` avec une valeur telle que `path/to/agent/project:agent-name`. Sélectionnez la portée d'environnement de votre choix. Si vous ne savez pas quel est le contexte de votre agent, modifiez votre fichier `.gitlab-ci.yml` et ajoutez un job pour voir les contextes disponibles :

     ```yaml
     deploy:
       image: debian:13-slim
       variables:
         KUBECTL_VERSION: v1.34
         DEBIAN_FRONTEND: noninteractive
       script:
         # Follows https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management
         - apt-get update
         - apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg
         - curl --fail --silent --show-error --location "https://pkgs.k8s.io/core:/stable:/${KUBECTL_VERSION}/deb/Release.key" | gpg --dearmor --output /etc/apt/keyrings/kubernetes-apt-keyring.gpg
         - chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
         - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBECTL_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
         - chmod 644 /etc/apt/sources.list.d/kubernetes.list
         - apt-get update
         - apt-get install -y --no-install-recommends kubectl
         - kubectl config get-contexts
      ```

   - Ajoutez une clé appelée `KUBE_NAMESPACE` avec comme valeur l'espace de nommage Kubernetes cible de vos déploiements. Définissez la même portée d'environnement.
1. Sélectionnez **Ajouter une variable**.
1. Dans la barre latérale gauche, sélectionnez **Opération** > **Clusters Kubernetes**.
1. Dans la section des clusters basés sur des certificats, ouvrez le cluster qui sert la même portée d'environnement.
1. Sélectionnez l'onglet **Détails** et désactivez le cluster.
1. Modifiez votre fichier `.gitlab-ci.yml` et assurez-vous qu'il utilise le modèle Auto DevOps. Par exemple :

   ```yaml
   include:
     template: Auto-DevOps.gitlab-ci.yml

   variables:
     KUBE_INGRESS_BASE_DOMAIN: 74.220.23.215.nip.io
     KUBE_CONTEXT: "gitlab-examples/ops/gitops-demo/k8s-agents:demo-agent"
     KUBE_NAMESPACE: "demo-agent"
   ```

1. Pour tester votre pipeline, dans la barre latérale gauche, sélectionnez **Version** > **Pipelines**, puis **Nouveau pipeline**.

À titre d'exemple, [consultez ce projet](https://gitlab.com/gitlab-examples/ops/gitops-demo/hello-world-service).

## Migrer depuis les applications gérées par GitLab {#migrate-from-gitlab-managed-applications}

Les applications gérées par GitLab (GMA) ont été dépréciées et supprimées. L'agent pour Kubernetes ne les prend pas en charge. Pour migrer de GMA vers l'agent, suivez les étapes ci-dessous :

1. [Migrer des applications gérées par GitLab vers un projet de gestion de cluster](../../clusters/migrating_from_gma_to_project_template.md).
1. [Migrer le projet de gestion de cluster pour utiliser l'agent](../../clusters/management_project_template.md).

## Migrer un projet de gestion de cluster {#migrate-a-cluster-management-project}

Consultez [comment utiliser un projet de gestion de cluster avec l'agent GitLab pour Kubernetes](../../clusters/management_project_template.md).

## Migrer les fonctionnalités de surveillance du cluster {#migrate-cluster-monitoring-features}

Une fois que vous avez connecté un cluster Kubernetes à GitLab à l'aide de l'agent pour Kubernetes, vous pouvez utiliser [le tableau de bord pour Kubernetes](../../../ci/environments/kubernetes_dashboard.md) après avoir activé l'[accès utilisateur](../../clusters/agent/user_access.md).
