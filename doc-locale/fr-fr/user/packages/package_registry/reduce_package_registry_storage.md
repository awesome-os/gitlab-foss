---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Réduire le stockage du registre de paquets
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les registres de paquets accumulent des paquets et leurs ressources au fil du temps. Sans nettoyage régulier :

- Les listes de paquets mettent plus de temps à être récupérées, ce qui impacte les performances des pipelines CI/CD
- Les serveurs allouent davantage d'espace de stockage aux paquets inutilisés ou obsolètes
- Les utilisateurs peuvent avoir du mal à trouver les paquets pertinents parmi de nombreuses versions de paquets obsolètes

Vous devez mettre en place une stratégie de nettoyage régulière pour réduire la surcharge du registre de paquets et libérer de l'espace de stockage.

## Examiner l'utilisation du stockage du registre de paquets {#review-package-registry-storage-use}

Pour examiner la **Répartition de l'utilisation** du stockage :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Quotas d'utilisation**.
1. Depuis la page **Quotas d'utilisation**, examinez la **Répartition de l'utilisation** pour les paquets.

## Supprimer un paquet {#delete-a-package}

Vous ne pouvez pas modifier un paquet après l'avoir publié dans le registre de paquets. Vous devez alors supprimer le paquet et le republier.

Prérequis :

- Disposer du rôle Chargé de maintenance ou Propriétaire pour le projet.

Pour supprimer un paquet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Registre de paquets**.
1. Depuis la page **Registre de paquets**, sélectionnez le paquet que vous souhaitez supprimer.
   - Ou, depuis la page **Registre de paquets**, sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}) et sélectionnez **Supprimer le paquet**.
1. Dans la boîte de dialogue de confirmation **Supprimer la version du paquet**, sélectionnez **Supprimer définitivement**.

Le paquet est définitivement supprimé.

Pour supprimer un paquet, vous pouvez également utiliser [l'API](../../../api/packages.md#delete-a-project-package).

> [!note]
> Vous pouvez introduire un risque de confusion de dépendances si vous supprimez un paquet alors que le [transfert de requêtes](supported_functionality.md#forwarding-requests) est activé.

## Supprimer des ressources de paquet {#delete-package-assets}

Supprimez les ressources associées à un paquet pour réduire le stockage.

Prérequis :

- Disposer du rôle Chargé de maintenance ou Propriétaire pour le projet.

Pour supprimer des ressources de paquet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet ou votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Registre de paquets**.
1. Depuis la page **Registre de paquets**, sélectionnez un paquet pour afficher des détails supplémentaires.
1. Dans le tableau **Ressources**, trouvez le nom des ressources que vous souhaitez supprimer.
1. Sélectionnez les points de suspension verticaux ({{< icon name="ellipsis_v" >}}) et sélectionnez **Supprimer la ressource**.

Les ressources du paquet sont définitivement supprimées.

Pour supprimer un paquet, vous pouvez également utiliser [l'API](../../../api/packages.md#delete-a-package-file).

## Politique de nettoyage {#cleanup-policy}

Lorsque vous importez un paquet avec le même nom et la même version dans le registre de paquets, des ressources supplémentaires sont ajoutées au paquet.

Pour économiser de l'espace de stockage, vous devez conserver uniquement les ressources les plus récentes. Utilisez une politique de nettoyage pour définir des règles qui suppriment automatiquement les ressources de paquets dans un projet, afin de ne pas avoir à les supprimer manuellement.

### Activer la politique de nettoyage {#enable-the-cleanup-policy}

Prérequis :

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire.

Par défaut, la politique de nettoyage des paquets est désactivée. Pour l'activer :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Paquets et registres**.
1. Développez **Registre de paquets**.
1. Sous **Gérez le stockage utilisé par les ressources des paquets**, définissez les règles de manière appropriée.

### Règles disponibles {#available-rules}

- `Number of duplicated assets to keep` : certains formats de paquets prennent en charge plusieurs copies de la même ressource. Vous pouvez définir une limite sur le nombre de ressources dupliquées à conserver. Lorsque la limite est atteinte, les ressources les plus anciennes sont automatiquement supprimées. Les noms de fichiers uniques, tels que ceux générés par les snapshots Maven, ne sont pas comptabilisés comme des ressources dupliquées.

- `Number of duplicated assets to keep` s'exécute [toutes les 12 heures](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/models/packages/cleanup/policy.rb).

### Définir des limites de nettoyage pour préserver les ressources {#set-cleanup-limits-to-conserve-resources}

Un processus en arrière-plan exécute les politiques de nettoyage des paquets. Ce processus peut prendre beaucoup de temps et consomme des ressources serveur pendant son exécution.

Utilisez le paramètre suivant pour limiter le nombre de workers de nettoyage :

- `package_registry_cleanup_policies_worker_capacity` : le nombre maximum de workers de nettoyage s'exécutant simultanément. Ce nombre doit être supérieur ou égal à `0`. Vous devez commencer avec un nombre faible et l'augmenter après avoir surveillé les ressources utilisées par les workers en arrière-plan. Pour supprimer tous les workers et ne pas exécuter les politiques de nettoyage, définissez ce paramètre sur `0`. La valeur par défaut est `2`.
