---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Registre virtuel
description: "Utilisez le registre virtuel GitLab pour proxyer, mettre en cache et distribuer des paquets depuis plusieurs registres upstream."
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/14137) dans GitLab 18.0 [avec le feature flag](../../../administration/feature_flags/_index.md) `virtual_registry_maven`. Fonctionnalité désactivée par défaut.
- Feature flag [modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/540276) en `maven_virtual_registry` dans GitLab 18.1. Fonctionnalité désactivée par défaut. Le feature flag `virtual_registry_maven` a été supprimé.
- [Passage](https://gitlab.com/gitlab-org/gitlab/-/issues/540276) de la version expérimentale à la version bêta dans GitLab 18.1.
- [Activé sur GitLab.com, GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/197432) dans GitLab 18.2.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique.

Utilisez le registre virtuel GitLab pour proxyer et mettre en cache des paquets depuis plusieurs registres upstream derrière une URL unique et bien connue.

Avec cette approche, vous pouvez configurer vos applications pour utiliser un seul registre virtuel au lieu de plusieurs registres upstream.

> [!note]
> Le registre virtuel GitLab est disponible dans le cadre du programme [version bêta](../../../policy/development_stages_support.md#beta) de GitLab. Bien qu'il soit actuellement disponible dans les offres Premium et Ultimate, la disponibilité finale et la tarification seront annoncées lorsque le registre virtuel sera disponible en version générale.

## Prérequis {#prerequisites}

Pour configurer le registre virtuel :

- Vous devez disposer d'un groupe principal avec le rôle Maintainer ou Owner.
- Assurez-vous d'activer le paramètre des registres virtuels. Il est activé par défaut, mais [les Owners de groupe peuvent le désactiver](#turn-off-the-virtual-registry).
- Assurez-vous d'activer le paramètre du proxy de dépendances. Il est activé par défaut, mais [les administrateurs peuvent le désactiver](../../../administration/packages/dependency_proxy.md).
- Vous devez configurer l'authentification pour votre [format de paquet](#supported-package-formats) pris en charge.

## Désactiver le registre virtuel {#turn-off-the-virtual-registry}

Le registre virtuel est activé par défaut.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe principal.

Pour désactiver le registre virtuel :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Paramètres** > **Paquets et registres**.
1. Sous **Registre virtuel**, désactivez le bouton **Activer le registre virtuel**.

## Formats de paquets pris en charge {#supported-package-formats}

- [Paquets Maven](maven/_index.md)
- [Images de conteneur](container/_index.md)

## S'authentifier auprès du registre virtuel {#authenticate-to-the-virtual-registry}

{{< history >}}

- Accès pour les membres directs des projets au sein du groupe principal [supprimé](https://gitlab.com/gitlab-org/gitlab/-/issues/580977) dans GitLab 18.9.

{{< /history >}}

L'endpoint du registre virtuel peut être utilisé avec l'un des jetons suivants :

- Un [jeton d'accès personnel](../../profile/personal_access_tokens.md).
- Un [jeton de déploiement de groupe](../../project/deploy_tokens/_index.md) pour le groupe principal hébergeant le registre virtuel concerné.
- Un [jeton d'accès de groupe](../../group/settings/group_access_tokens.md) pour le groupe principal hébergeant le registre virtuel concerné.
- Un [jeton de job CI/CD](../../../ci/jobs/ci_job_token.md).
- Un [jeton OAuth 2.0](../../../api/oauth2.md), envoyé en tant qu'en-tête Bearer ou paramètre de requête.

Les jetons doivent disposer de l'une des portées suivantes :

- `api`
- `read_virtual_registry`

Les jetons d'accès et le jeton de job CI/CD sont résolus en utilisateurs. L'utilisateur résolu doit être :

- Un membre direct du groupe principal avec le rôle Invité, Planificateur, Reporter, Developer, Maintainer ou Owner.
- Un membre direct du groupe principal avec un [rôle personnalisé](../../custom_roles/_index.md) avec un accès minimum disposant de la capacité `read_virtual_registry`.
- Un administrateur d'instance GitLab.

> [!note]
> Les jetons de job CI/CD sont résolus en l'utilisateur qui a déclenché le pipeline. Cet utilisateur doit être un membre direct du groupe principal pour accéder au registre virtuel. Les [listes d'autorisation des jetons de job CI/CD](../../../ci/jobs/ci_job_token.md#control-job-token-access-to-your-project) ne s'appliquent pas à l'authentification du registre virtuel.

## Gérer les registres virtuels {#manage-virtual-registries}

Gérez les registres virtuels pour un groupe principal.

### Création d'un registre virtuel {#creating-a-virtual-registry}

Vous pouvez créer un registre virtuel pour l'un des [formats de paquets pris en charge](#supported-package-formats).

Lorsque vous créez un registre virtuel :

- Le registre est hébergé dans un groupe principal pour un format de paquet donné. Les projets et les sous-groupes ne sont pas pris en charge.
- L'objet registre virtuel est lié à une liste ordonnée d'upstreams disponibles (jusqu'à 20). Chaque upstream pointe vers un registre externe.
- Les registres externes peuvent être publics ou privés. Les identifiants pour les registres privés sont stockés dans l'upstream lui-même, vous n'avez donc pas besoin de les stocker dans la configuration du gestionnaire de paquets.

### Afficher un registre virtuel {#view-a-virtual-registry}

Pour afficher un registre virtuel :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.

### Modifier un registre virtuel {#edit-a-virtual-registry}

Pour modifier un registre virtuel existant :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Dans la ligne du registre que vous souhaitez modifier, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Apportez vos modifications et sélectionnez **Enregistrer les modifications**.

### Supprimer un registre virtuel {#delete-a-virtual-registry}

Pour supprimer un registre virtuel :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sous l'onglet **Registres**, dans la ligne du registre que vous souhaitez supprimer, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Sélectionnez **Supprimer le registre**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer**.

## Gérer les registres upstream {#manage-upstream-registries}

Gérez les registres upstream dans un registre virtuel pour un groupe principal.

### Afficher les registres upstream {#view-upstream-registries}

Pour afficher les registres upstream :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sélectionnez l'onglet **Upstreams** pour afficher tous les upstreams disponibles.

### Modifier un registre upstream {#edit-an-upstream-registry}

Pour modifier un registre upstream :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sélectionnez l'onglet **Upstreams**.
1. Dans la ligne de l'upstream que vous souhaitez modifier, sélectionnez **Modifier** ({{< icon name="pencil" >}}).
1. Apportez vos modifications et sélectionnez **Enregistrer les modifications**.

### Réordonner les registres upstream {#reorder-upstream-registries}

L'ordre des registres upstream détermine la priorité selon laquelle ils sont interrogés pour les paquets.

Pour modifier l'ordre des registres upstream :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registres virtuels**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sous l'onglet **Registres**, sélectionnez un registre.
1. Sous **Upstreams**, sélectionnez **Déplacer l'upstream vers le haut** ou **Déplacer l'upstream vers le bas** pour réordonner les upstreams.

Bonnes pratiques pour l'ordre des upstreams :

- Positionnez les registres privés avant les registres publics pour prioriser les paquets internes.
- Donnez la priorité aux registres contenant le plus de paquets en haut de la liste. Cette approche :
  - Augmente les chances qu'un registre de haute priorité puisse satisfaire la requête
  - Évite de parcourir toute la liste ordonnée pour trouver un registre upstream valide
- Placez les registres plus rapides ou plus fiables en tête de liste.
- Placez les registres publics en dernier, comme solutions de repli pour les dépendances publiques.
- Placez les registres contenant le moins de paquets en bas de la liste.

Pour plus d'informations sur l'ordre des upstreams, consultez [Priorisation des upstreams](#upstream-prioritization).

## Système de mise en cache {#caching-system}

Tous les registres upstream disposent d'un système de mise en cache qui :

- Stocke les requêtes dans une entrée de cache
- Sert les réponses pour les requêtes identiques depuis le registre virtuel GitLab

Ainsi, le registre virtuel n'a pas besoin de contacter à nouveau l'upstream lorsque le même paquet est demandé.

Si un chemin demandé n'a pas été mis en cache dans l'un des upstreams disponibles :

1. Le registre virtuel parcourt la liste ordonnée des upstreams pour en trouver un capable de satisfaire la requête.
1. Lorsqu'un upstream capable de satisfaire la requête est trouvé, le registre virtuel extrait la réponse de l'upstream avec les identifiants fournis si nécessaire.

Si le chemin demandé a été mis en cache dans l'un des upstreams disponibles :

1. Le registre virtuel vérifie la [période de validité du cache](#cache-validity-period) pour déterminer si l'entrée de cache doit être actualisée avant de transmettre la réponse.
1. Si le cache est valide, l'entrée de cache de l'upstream satisfait la requête.
   - Si un upstream de priorité inférieure dispose de la requête dans son cache, et qu'un upstream de priorité supérieure contient le fichier mais n'a pas mis la requête en cache, l'upstream de priorité inférieure satisfait la requête. Le registre virtuel ne parcourt pas à nouveau la liste ordonnée des upstreams.

Le registre virtuel retourne une erreur `404 Not Found` s'il ne peut pas trouver un upstream pour satisfaire la requête.

### Période de validité du cache {#cache-validity-period}

La période de validité du cache définit la durée, en heures, pendant laquelle une entrée de cache est considérée comme valide pour satisfaire une requête.

Avant que le registre virtuel n'extraie depuis une entrée de cache existante, il vérifie la période de validité du cache pour déterminer si l'entrée doit être actualisée ou non.

Si l'entrée est en dehors de la période de validité, le registre virtuel vérifie si la réponse de l'upstream est identique à celle présente dans le cache. Si :

- La réponse est identique, l'entrée est utilisée pour satisfaire la requête.
- La réponse n'est pas identique, la réponse est à nouveau téléchargée depuis l'upstream pour écraser l'entrée de cache de l'upstream.

Si le registre virtuel ne peut pas se connecter à un upstream en raison de conditions réseau, l'upstream satisfait la requête avec l'entrée de cache disponible.

Tant que le registre virtuel dispose de la réponse liée à une requête dans le cache, cette requête est satisfaite, même en dehors de la période de validité.

### Définir la période de validité du cache {#set-the-cache-validity-period}

La période de validité du cache est importante pour les performances globales du registre virtuel dans la satisfaction des requêtes. Contacter des registres externes est une opération coûteuse. Des périodes de validité plus courtes augmentent le nombre de vérifications, tandis que des périodes plus longues les diminuent.

Vous pouvez désactiver les vérifications de validité du cache en le définissant sur `0`.

La valeur par défaut de la période de validité du cache est de `24` heures.

Vous devez définir la période de validité du cache sur `0` lorsque le registre externe ciblé par l'upstream est connu pour avoir des réponses immuables. C'est souvent le cas avec les registres publics officiels. Pour plus d'informations, consultez votre [format de paquet pris en charge](#supported-package-formats).

Vous configurez la période de validité du cache lors de la création ou de la modification d'un upstream.

### Afficher les paquets mis en cache {#view-cached-packages}

Pour afficher les paquets mis en cache depuis les registres upstream :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sous l'onglet **Upstreams**, sélectionnez un upstream.
1. Consultez les métadonnées du cache pour les paquets mis en cache.

### Supprimer des entrées de cache {#delete-cache-entries}

Pour supprimer des entrées de cache :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Déployer** > **Registre virtuel**.
1. Sous **Types de registres**, sélectionnez **Afficher les registres**.
1. Sous l'onglet **Registres**, sélectionnez un registre.
1. À côté de **Upstreams**, sélectionnez **Vider tous les caches**.
   - Pour supprimer une entrée de cache spécifique, à côté d'un upstream, sélectionnez **Vider le cache**.

Lorsque vous supprimez une entrée de cache, la prochaine fois que le registre virtuel reçoit une requête pour ce fichier, il parcourt à nouveau la liste des upstreams pour en trouver un capable de satisfaire la requête.

### Utilisation du stockage d'objets {#object-storage-usage}

Les entrées de cache sauvegardent leurs fichiers dans le stockage d'objets dans le [bucket `dependency_proxy`](../../../administration/object_storage.md#configure-the-parameters-of-each-object).

L'utilisation du stockage d'objets est comptabilisée dans la [limite d'utilisation du stockage d'objets](../../storage_usage_quotas.md#view-storage) du groupe principal.

## Politiques de nettoyage {#cleanup-policies}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/572839) dans GitLab 18.6 [avec le feature flag](../../../administration/feature_flags/_index.md) `maven_virtual_registry`. Activés par défaut.
- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/572839) dans GitLab 18.6 [avec le feature flag](../../../administration/feature_flags/_index.md) `virtual_registry_cleanup_policies`. Fonctionnalité désactivée par défaut.
- [Interface utilisateur pour les politiques de nettoyage](https://gitlab.com/gitlab-org/gitlab/-/issues/548566) introduite dans GitLab 18.9 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `ui_for_virtual_registry_cleanup_policy`. Fonctionnalité désactivée par défaut.
- [Disponible en version générale](https://gitlab.com/gitlab-org/gitlab/-/issues/578060) dans GitLab 18.10. Les feature flags `virtual_registry_cleanup_policies` et `ui_for_virtual_registry_cleanup_policy` ont été supprimés.

{{< /history >}}

Les registres virtuels mettent en cache les paquets des registres upstream pour améliorer les performances et la disponibilité. Au fil du temps, ces entrées de cache peuvent s'accumuler et consommer un espace de stockage important. Utilisez des politiques de nettoyage pour gérer automatiquement le contenu mis en cache et réduire l'utilisation du stockage.

Une politique de nettoyage est un job planifié qui supprime les entrées de cache selon des règles configurables. Lorsqu'une politique de nettoyage s'exécute, elle identifie les entrées de cache qui n'ont pas été téléchargées récemment et les supprime du stockage.

Les politiques de nettoyage sont définies pour tous les registres virtuels du groupe principal.

### Workflow des politiques de nettoyage {#cleanup-policies-workflow}

Dans le registre virtuel, les politiques de nettoyage :

1. Identifient les entrées de cache qui n'ont pas été téléchargées dans la période de conservation spécifiée.
1. Suppriment les entrées de cache inutilisées du stockage d'objets.
1. Préservent les entrées de cache fréquemment consultées pour maintenir les performances.

Une politique de nettoyage affecte uniquement le contenu mis en cache depuis les registres upstream. Elle n'affecte pas :

- Les configurations des registres virtuels
- Les paramètres des registres upstream
- Les paquets stockés dans le registre de paquets de votre projet

### Gérer les politiques de nettoyage {#manage-cleanup-policies}

Gérez une politique de nettoyage pour les registres virtuels dans un groupe principal. Chaque groupe principal peut avoir jusqu'à une politique de nettoyage qui s'applique à tous les registres virtuels de ce groupe.

#### Créer une politique de nettoyage {#create-a-cleanup-policy}

Créez une politique de nettoyage et définissez la fréquence à laquelle elle s'exécute.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe principal.
- Le registre virtuel doit être activé pour le groupe.

Pour créer une politique de nettoyage :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Paramètres** > **Paquets et registres**.
1. À côté de **Politique de vidage du cache du registre virtuel**, sélectionnez **Définir la politique**.
1. Activez le bouton **Activer la stratégie de nettoyage**.
1. Configurez les paramètres de la politique de nettoyage :
   - Dans la liste déroulante **Lancer le nettoyage**, sélectionnez la fréquence à laquelle la politique de nettoyage s'exécute. Par défaut : **Tous les jours**.
   - Sous **Supprimer les éléments du cache non consultés ces derniers (jours)**, saisissez un nombre pour définir la fréquence à laquelle les entrées de cache inutilisées sont supprimées. Par défaut : `7` jours. Doit être compris entre `1` et `365`.
   - Facultatif. Sous **Notifications par e-mail**, cochez l'une ou les deux cases suivantes pour recevoir des notifications par e-mail :
     - **Envoyer des notifications par e-mail lorsque le vidage du cache est en cours d'exécution**
     - **Envoyer des notifications par e-mail si le vidage du cache échoue**
1. Sélectionnez **Enregistrer les modifications**.

#### Modifier une politique de nettoyage {#edit-a-cleanup-policy}

Modifiez une politique de nettoyage pour déterminer la fréquence à laquelle la politique s'exécute.

Prérequis :

- Disposer du rôle Propriétaire pour le groupe principal.

Pour modifier une politique de nettoyage :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Paramètres** > **Paquets et registres**.
1. À côté de **Politique de vidage du cache du registre virtuel**, sélectionnez **Modifier la politique**.
1. Apportez des modifications à votre politique de nettoyage.
1. Sélectionnez **Enregistrer les modifications**.

#### Désactiver les politiques de nettoyage {#turn-off-cleanup-policies}

Désactivez les politiques de nettoyage pour un groupe principal. Lorsqu'elle est désactivée, la politique de nettoyage conserve sa configuration mais ne s'exécute pas. Les entrées de cache existantes sont préservées.

Prérequis :

- Disposer du rôle Propriétaire pour le groupe principal.

Pour désactiver les politiques de nettoyage :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe. Ce groupe doit être au niveau principal.
1. Sélectionnez **Paramètres** > **Paquets et registres**.
1. À côté de **Politique de vidage du cache du registre virtuel**, sélectionnez **Modifier la politique**.
1. Désactivez le bouton **Activer la stratégie de nettoyage**.
1. Sélectionnez **Enregistrer les modifications**.

### Paramètres de la politique de nettoyage {#cleanup-policy-settings}

Utilisez les paramètres suivants pour contrôler une politique de nettoyage :

- **Cadence** : contrôle la fréquence à laquelle la politique de nettoyage s'exécute. Les options disponibles incluent des intervalles quotidiens, hebdomadaires et mensuels.
- **Durée de conservation** : détermine la durée de conservation des entrées de cache après leur dernier téléchargement. Les entrées qui n'ont pas été téléchargées dans cette période sont éligibles à la suppression.

### Surveiller l'exécution des politiques de nettoyage {#monitor-cleanup-policy-execution}

Après l'exécution d'une politique de nettoyage, vous pouvez consulter les métriques d'exécution suivantes :

- Quand la politique s'est exécutée pour la dernière fois.
- Quand la prochaine exécution de la politique est planifiée.
- Combien d'entrées de cache ont été supprimées.
- Espace de stockage total libéré.
- Les erreurs survenues lors de l'exécution.

Ces métriques vous aident à comprendre l'efficacité de votre politique de nettoyage afin d'ajuster les paramètres si nécessaire.

## Considérations de performance {#performance-considerations}

Les performances du registre virtuel peuvent varier en fonction de facteurs tels que :

- Si un fichier demandé est mis en cache depuis un registre upstream ou non
- La rapidité avec laquelle les registres upstream peuvent répondre si un fichier existe ou non
- Le client qui extrait les dépendances et la proximité du client avec l'instance GitLab

### Compromis {#tradeoffs}

Les registres virtuels sont plus avancés que les registres publics. Lorsque vous extrayez des dépendances avec un registre virtuel, cela peut prendre plus de temps qu'avec d'autres registres, tels que les registres publics officiels.

Par rapport aux registres publics, les registres virtuels prennent également en charge plusieurs registres upstream et l'authentification.

### Priorisation des upstreams {#upstream-prioritization}

Les registres upstream sont organisés en listes ordonnées. Lorsqu'un registre virtuel reçoit une requête pour un paquet :

- Le registre parcourt la liste ordonnée des upstreams pour en trouver un capable de satisfaire la requête.
- Si le fichier demandé est trouvé dans un upstream, le registre virtuel retourne ce fichier et le met en cache pour les requêtes futures. La mise en cache augmente la disponibilité des dépendances si vous les avez extraites au moins une fois via le registre virtuel.
- Si un fichier demandé n'est pas trouvé dans un cache, le registre virtuel parcourt la liste ordonnée pour trouver l'upstream avec la priorité la plus élevée capable de satisfaire la requête.

Ce système a un impact notable sur les performances d'un registre virtuel.

### Améliorations des performances avec l'utilisation {#performance-improvements-with-usage}

Lorsque vous créez un registre virtuel, le cache de chaque upstream configuré est vide. Chaque requête nécessite que le registre virtuel parcoure la liste des registres upstream disponibles pour satisfaire une requête. Ces requêtes initiales prennent plus de temps à satisfaire.

Lorsqu'un registre upstream met en cache une requête, le temps nécessaire pour satisfaire une requête identique diminue. Au fil du temps, les performances globales du registre virtuel s'améliorent à mesure que davantage de registres upstream mettent en cache davantage de requêtes.

### Utiliser le cache CI/CD {#use-the-cicd-cache}

Vous pouvez utiliser la [mise en cache dans GitLab CI/CD](../../../ci/caching/_index.md) pour que les jobs n'aient pas à télécharger les dépendances depuis le registre virtuel.

Cette méthode améliore le temps d'exécution, mais duplique également le stockage pour chaque dépendance (les dépendances sont stockées dans le cache CI/CD et le registre virtuel).
