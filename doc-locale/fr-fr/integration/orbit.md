---
stage: Orbit
group: Context Systems
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: GitLab Orbit
description: Configurez GitLab Orbit pour GitLab Self-Managed et GitLab Dedicated.
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

## Démarrer un essai gratuit {#start-a-free-trial}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/260183) dans GitLab 19.5 derrière un feature flag nommé `orbit_trial`, désactivé par défaut.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Si votre groupe principal n'est pas encore sous licence Orbit, vous pouvez démarrer un essai gratuit. L'essai offre au groupe des GitLab Credits gratuits pour Orbit. Les groupes qui ne répondent pas aux critères de l'essai voient une option **Contacter le service commercial** à la place.

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe principal.
- Le groupe doit répondre aux critères de l'essai.

Pour démarrer un essai gratuit :

1. Dans la barre latérale gauche, sélectionnez **Rechercher ou accéder à** et repérez votre groupe.
1. Sélectionnez **Paramètres > GitLab Orbit**.
1. Activez le bouton bascule **Activer GitLab Orbit**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Activer GitLab Orbit**.

Une fois l'essai démarré, Orbit s'active pour le groupe et indexe le groupe, ses sous-groupes et ses projets. L'indexation peut prendre jusqu'à quelques heures.

L'essai s'applique uniquement à ce groupe. Seul Orbit peut utiliser les crédits de l'essai. Lorsque l'essai se termine ou que les crédits sont épuisés, Orbit se met en pause. Pour continuer à utiliser Orbit, contactez le service commercial.

## Démarrer un essai gratuit pour l'instance {#start-a-free-trial-for-the-instance}

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/261678) dans GitLab 19.6 derrière des feature flags nommés `orbit_trial` et `orbit_promo_access_gate`, désactivés par défaut.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par des feature flags. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Lorsque votre instance ne fait pas partie de la version bêta d'Orbit et n'a pas souscrit à Orbit, un administrateur peut démarrer un essai gratuit pour l'instance. L'essai offre à l'instance des GitLab Credits gratuits pour Orbit, partagés par tous les groupes principaux.

Prérequis :

- Vous devez disposer d'un accès administrateur.
- Votre instance doit disposer d'une licence cloud en ligne.
- L'instance doit répondre aux critères de l'essai.

Pour démarrer un essai gratuit pour l'instance :

1. Dans la barre latérale gauche, en bas, sélectionnez **Admin**.
1. Sélectionnez **GitLab Orbit**.
1. Sélectionnez **Démarrer l'essai**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Démarrer l'essai**.

Vous pouvez également démarrer l'essai depuis l'onglet **Vue d'ensemble** du tableau de bord Orbit : sélectionnez **Accéder aux paramètres de GitLab Orbit** sur la carte au-dessus de la carte géographique, puis suivez les étapes sur la page Orbit **Admin**.

Vous et les Propriétaires des groupes principaux pouvez activer Orbit pour des groupes avant et pendant l'essai. Les crédits de l'essai couvrent les requêtes Orbit.

Lorsque l'essai se termine ou que les crédits sont épuisés, Orbit continue d'indexer vos groupes, mais les requêtes Orbit s'arrêtent. Pour relancer les requêtes Orbit, contactez le service commercial.

## Activer ou désactiver Orbit pour vos groupes {#turn-orbit-on-or-off-for-your-groups}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/orbit/knowledge-graph/-/work_items/1364) dans GitLab 19.4.

{{< /history >}}

L'onglet **Statut** répertorie vos groupes principaux avec leur état Orbit et leur statut d'indexation. Pour un groupe en cours d'indexation par Orbit, sélectionnez l'icône d'information ({{< icon name="information-o" >}}) pour afficher le statut d'indexation de chaque zone.

Prérequis :

- Pour activer ou désactiver Orbit, vous devez disposer du rôle Propriétaire pour le groupe principal.

Pour activer ou désactiver Orbit pour vos groupes :

1. Dans la barre latérale gauche, sélectionnez **Votre travail**.
1. Sélectionnez **GitLab Orbit**.
1. Sélectionnez l'onglet **Statut**.
1. Sélectionnez les groupes.
1. Sélectionnez **Actions** > **Activer GitLab Orbit** ou **Actions** > **Désactiver GitLab Orbit**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Activer GitLab Orbit** ou **Désactiver GitLab Orbit**.

Sur GitLab.com, l'activation d'Orbit pour un groupe éligible lance l'essai gratuit de ce groupe. La boîte de dialogue de confirmation affiche l'essai attribué à chaque groupe. Sur GitLab Self-Managed et GitLab Dedicated, pendant un essai gratuit pour l'instance, la boîte de dialogue de confirmation affiche la date de fin de l'essai.

Sur GitLab Self-Managed et GitLab Dedicated, vous pouvez activer Orbit pour un groupe sans essai gratuit ni achat. Orbit indexe le groupe, et l'onglet **Statut** affiche le statut d'indexation. Lorsque le feature flag `orbit_promo_access_gate` est activé, l'instance nécessite un essai gratuit ou un achat pour exécuter des requêtes Orbit. En attendant, l'onglet **Vue d'ensemble** affiche le nombre d'éléments de vos groupes, et une carte au-dessus de la carte géographique indique comment l'instance obtient des requêtes Orbit. Un administrateur d'une instance pouvant démarrer son essai gratuit voit **Accéder aux paramètres de GitLab Orbit** sur la carte. L'onglet **Éditeur de requêtes** indique comment obtenir des requêtes Orbit. Une fois l'essai gratuit de l'instance terminé, vous pouvez toujours activer Orbit pour d'autres groupes.

## Orbit dans GitLab Duo par défaut {#orbit-in-gitlab-duo-default}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/orbit/knowledge-graph/-/work_items/1319) dans GitLab 19.5.

{{< /history >}}

Orbit dans GitLab Duo est activé par défaut. Dans leurs préférences, les utilisateurs choisissent les fonctionnalités propulsées par Orbit qu'ils souhaitent utiliser.

Sur GitLab.com, Orbit dans GitLab Duo est activé pour les membres d'un groupe principal ayant Orbit activé. Sur GitLab Self-Managed et GitLab Dedicated, un administrateur configure le commutateur à l'échelle de l'instance, et l'instance doit disposer d'une licence incluant la fonctionnalité Orbit.

Les exigences en matière de disponibilité d'Orbit, de licence et d'inscription des espaces de nommage s'appliquent toujours.

### Désactiver Orbit dans GitLab Duo pour l'instance {#turn-off-orbit-in-gitlab-duo-for-the-instance}

Prérequis :

- Vous devez disposer d'un accès administrateur.
- Votre instance doit disposer d'une licence incluant la fonctionnalité Orbit.

Pour désactiver Orbit dans GitLab Duo pour tous les utilisateurs de l'instance :

1. Dans la barre latérale gauche, en bas, sélectionnez **Admin**.
1. Sélectionnez **GitLab Orbit**.
1. Désactivez le bouton bascule **Activer GitLab Orbit dans GitLab Duo**.

Le paramètre est enregistré lorsque vous modifiez le bouton bascule.

## Indexer automatiquement les espaces de nommage des groupes principaux {#index-top-level-group-namespaces-automatically}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/606375) dans GitLab 19.4.

{{< /history >}}

Prérequis :

- Vous devez disposer d'un accès administrateur.
- Votre instance doit disposer d'une licence incluant la fonctionnalité Orbit.

Pour indexer automatiquement les espaces de nommage des groupes principaux existants et nouveaux :

1. Dans la barre latérale gauche, en bas, sélectionnez **Admin**.
1. Sélectionnez **GitLab Orbit**.
1. Activez le bouton bascule **Activer automatiquement GitLab Orbit pour tous les groupes principaux**.
1. Sélectionnez **Activer pour tous les groupes principaux**.

Lorsque vous activez le paramètre, GitLab met en file d'attente un job en arrière-plan. Le job inscrit les espaces de nommage des groupes principaux qui ne sont pas déjà inscrits ou exclus par un administrateur. L'inscription se produit peu après plutôt qu'immédiatement. Un job en arrière-plan horaire inscrit également les groupes principaux nouvellement créés et supprime les inscriptions des groupes exclus. Le job horaire agit comme filet de sécurité après les modifications directes de la base de données. Ces modifications peuvent prendre jusqu'à une heure. Les espaces de nommage personnels ne sont pas inscrits.

Le job inscrit les groupes sans essai gratuit ni achat. Lorsque le feature flag `orbit_promo_access_gate` est activé et que l'essai gratuit de l'instance est terminé, le job inscrit les groupes uniquement si l'instance a souscrit à Orbit.

Lorsque vous désactivez **Activer automatiquement GitLab Orbit pour tous les groupes principaux**, les inscriptions existantes non exclues sont conservées. Le job en arrière-plan n'inscrit pas les nouveaux groupes principaux tant que vous n'avez pas réactivé le paramètre.

### Exclure les groupes principaux de l'indexation automatique {#exclude-top-level-groups-from-automatic-indexing}

Les administrateurs peuvent gérer les exclusions, que l'indexation automatique soit activée ou non :

1. Dans la barre latérale gauche, en bas, sélectionnez **Admin**.
1. Sélectionnez **GitLab Orbit**.
1. Dans **Groupes de niveau supérieur**, sélectionnez les groupes à exclure.
1. Sélectionnez **Actions** > **Exclure de l'indexation automatique**.
1. Si Orbit est activé pour un groupe sélectionné, sélectionnez **Exclure** pour confirmer.

Les groupes exclus ne sont pas automatiquement inscrits. Si un groupe exclu est déjà indexé, le job en arrière-plan horaire supprime son inscription et son index. Pour autoriser à nouveau l'inscription automatique, sélectionnez le groupe, puis sélectionnez **Actions** > **Supprimer l'exclusion**. Pour activer Orbit pour un groupe exclu, supprimez d'abord l'exclusion.

> [!note]
> Ce paramètre n'a aucun effet sur GitLab.com.

## Configurer les limites de débit d'Orbit {#configure-orbit-rate-limits}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/orbit/knowledge-graph/-/work_items/476) dans GitLab 19.6.

{{< /history >}}

Orbit limite le nombre de requêtes que chaque utilisateur peut effectuer en une minute. Lorsqu'un utilisateur dépasse une limite, GitLab rejette la requête. L'API REST renvoie une erreur `429 Too Many Requests`.

| Limite           | Valeur par défaut | S'applique à |
|-----------------|---------|------------|
| Requêtes         | 60      | Requêtes Orbit de type query, context, grep et skills, ainsi que la commande `query_graph`, depuis l'API REST et MCP. |
| Statut d'indexation | 30      | Requêtes de statut d'indexation Orbit depuis l'interface utilisateur et l'API GraphQL. |
| Nombre d'éléments     | 30      | Requêtes de nombre d'éléments Orbit depuis l'interface utilisateur et l'API GraphQL. |

Prérequis :

- Vous devez disposer d'un accès administrateur.

Pour configurer les limites de débit d'Orbit :

1. Dans le coin supérieur droit, sélectionnez {{< ui text="Administrateur" >}}.
1. Dans la barre latérale gauche, sélectionnez {{< ui text="Paramètres" >}} > {{< ui text="Réseau" >}}.
1. Développez {{< ui text="Limites de débit GitLab Orbit" >}}.
1. Remplissez les champs. Pour désactiver une limite, définissez-la sur `0`.
1. Facultatif. Dans {{< ui text="Utilisateurs à exclure de la limitation de fréquence" >}}, saisissez les noms d'utilisateur qui ne sont soumis à aucune limite de débit Orbit, par exemple, un utilisateur bot qui envoie de nombreuses requêtes. Vous pouvez saisir un maximum de 100 noms d'utilisateur.
1. Sélectionnez {{< ui text="Enregistrer les modifications" >}}.

Vous pouvez également définir ces limites avec l'[API des paramètres d'application](../api/settings.md).

Les requêtes grep d'Orbit sont également comptabilisées dans la [limite de débit de recherche](../administration/instance_limits.md#search-rate-limit). Pour exclure également un utilisateur de cette limite, ajoutez-le à {{< ui text="Utilisateurs à exclure de la limitation de fréquence" >}} dans {{< ui text="Paramètres" >}} > {{< ui text="Réseau" >}} > {{< ui text="Limitation de la fréquence des recherches" >}}.

## Afficher le statut d'Orbit {#view-orbit-status}

Pour afficher la configuration et le statut d'indexation d'Orbit, exécutez :

```shell
sudo gitlab-rake gitlab:orbit:info
```
