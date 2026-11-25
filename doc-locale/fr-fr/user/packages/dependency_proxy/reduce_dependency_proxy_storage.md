---
stage: Package
group: Container Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Réduire le stockage du proxy de dépendances pour les images de conteneur
description: "Gérez le stockage des blobs dans le Proxy de dépendance GitLab grâce aux politiques de nettoyage, à la suppression du cache via l'API et aux paramètres TTL."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Il n'existe pas de processus de suppression automatique pour les blobs. Sauf si vous les supprimez manuellement, ils sont stockés indéfiniment. Cette page présente plusieurs options pour supprimer les éléments inutilisés du cache.

## Vérifier l'utilisation du stockage du proxy de dépendances {#check-dependency-proxy-storage-use}

La page [**Quotas d'utilisation**](../../storage_usage_quotas.md) affiche l'utilisation du stockage pour le proxy de dépendances des images de conteneur.

## Utiliser l'API pour effacer le cache {#use-the-api-to-clear-the-cache}

Pour récupérer l'espace disque utilisé par des blobs d'image qui ne sont plus nécessaires, utilisez l'[API du proxy de dépendances](../../../api/dependency_proxy.md) pour effacer l'intégralité du cache. Si vous effacez le cache, la prochaine fois qu'un pipeline s'exécute, il doit extraire une image ou un tag depuis Docker Hub.

## Politiques de nettoyage {#cleanup-policies}

{{< history >}}

- Le rôle requis a été [modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/350682) de Développeur à Mainteneur dans GitLab 15.0.
- Le rôle requis a été [modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/370471) de Mainteneur à Propriétaire dans GitLab 17.0.

{{< /history >}}

### Activer les politiques de nettoyage depuis GitLab {#enable-cleanup-policies-from-within-gitlab}

Vous pouvez activer une politique de durée de vie (TTL) automatique pour le proxy de dépendances des images de conteneur depuis l'interface utilisateur. Pour ce faire, accédez aux **Paramètres** de votre groupe > **Paquets et registres** > **Proxy de dépendance** et activez le paramètre pour effacer automatiquement les éléments du cache après 90 jours.

### Activer les politiques de nettoyage avec GraphQL {#enable-cleanup-policies-with-graphql}

La politique de nettoyage est un job planifié que vous pouvez utiliser pour effacer les images en cache qui ne sont plus utilisées, libérant ainsi de l'espace de stockage supplémentaire. Les politiques utilisent une logique de durée de vie (TTL) :

- Le nombre de jours est configuré.
- Tous les fichiers du proxy de dépendances en cache qui n'ont pas été extraits pendant ce nombre de jours sont supprimés.

Utilisez l'[API GraphQL](../../../api/graphql/reference/_index.md#mutationupdatedependencyproxyimagettlgrouppolicy) pour activer et configurer les politiques de nettoyage :

```graphql
mutation {
  updateDependencyProxyImageTtlGroupPolicy(input:
    {
      groupPath: "<your-full-group-path>",
      enabled: true,
      ttl: 90
    }
  ) {
    dependencyProxyImageTtlPolicy {
      enabled
      ttl
    }
    errors
  }
}
```

Consultez le guide [Premiers pas avec GraphQL](../../../api/graphql/getting_started.md) pour apprendre à effectuer des requêtes GraphQL.

Lorsque la politique est initialement activée, le paramètre TTL par défaut est de 90 jours. Une fois activés, les fichiers obsolètes du proxy de dépendances sont mis en file d'attente pour suppression chaque jour. La suppression peut ne pas s'effectuer immédiatement en raison du temps de traitement. Si l'image est extraite après que les fichiers en cache ont été marqués comme expirés, les fichiers expirés sont ignorés et de nouveaux fichiers sont téléchargés et mis en cache depuis le registre externe.
