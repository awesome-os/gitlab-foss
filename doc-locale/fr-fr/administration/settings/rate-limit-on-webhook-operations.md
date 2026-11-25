---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Limites de débit des opérations de webhook
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- Limite de débit pour les tests de webhook [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/150066) dans GitLab 17.0 avec un [flag](../feature_flags/_index.md) nommé `web_hook_test_api_endpoint_rate_limit`. Activés par défaut.
- Limite de débit pour les renvois d'événements de webhook [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/151130) dans GitLab 17.1 avec un [flag](../feature_flags/_index.md) nommé `web_hook_event_resend_api_endpoint_rate_limit`. Activés par défaut.
- Limites de débit personnalisables [introduites](https://gitlab.com/gitlab-org/gitlab/-/issues/587887) dans GitLab 19.3. Les feature flags `web_hook_test_api_endpoint_rate_limit` et `web_hook_event_resend_api_endpoint_rate_limit` ont été supprimés.
- Limite de débit pour la création de webhooks de projet [introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/605597) dans GitLab 19.6.
- Limites de débit pour la création de webhooks de groupe et de hooks système [introduites](https://gitlab.com/gitlab-org/gitlab/-/issues/635281) dans GitLab 19.6.

{{< /history >}}

Configurez la limite de débit par minute pour les requêtes qui :

- [Ajoutent un webhook de projet](../../api/project_webhooks.md#add-a-webhook-to-a-project) via l'API.
- [Créent un webhook de groupe](../../api/group_webhooks.md#create-a-group-hook) via l'API.
- [Ajoutent un hook système](../../api/system_hooks.md#add-new-system-hook) via l'API.
- [Testent un webhook](../../user/project/integrations/webhooks.md#test-a-webhook).
- [Renvoient un événement de webhook](../../user/project/integrations/webhooks.md#inspect-request-and-response-details).

| Limite | Valeur par défaut |
|-------|---------|
| Requêtes de création de webhooks de projet | 5 par minute |
| Requêtes de création de webhooks de groupe | 10 par minute |
| Requêtes de création de hooks système | 5 par minute |
| Requêtes de test de webhook | 5 par minute |
| Requêtes de renvoi d'événements de webhook | 5 par minute |

Les limites de projet et de groupe s'appliquent par utilisateur, pour un projet ou un groupe donné. Tous les webhooks d'un même projet ou groupe partagent la limite. La limite de création de hooks système s'applique par utilisateur sur l'ensemble de l'instance. Les limites de test et de renvoi d'événements couvrent à la fois l'interface utilisateur et l'API. Les limites de création de webhooks couvrent uniquement l'API.

Ces limites sont distinctes de la [limite de débit de livraison des webhooks](../instance_limits.md#webhook-rate-limit), qui limite la fréquence à laquelle les webhooks peuvent être déclenchés. La configuration des limites de débit de livraison des webhooks dépend du type d'instance :

- Sur GitLab Self-Managed, les administrateurs la configurent avec l'[API Plan limits](../../api/plan_limits.md).
- Sur GitLab.com, la limite de livraison [dépend de votre formule](../../user/gitlab_com/_index.md#webhooks) et ne peut pas être modifiée.

Par exemple, si vous définissez la limite de débit de test de webhook à 5 et que vous essayez de tester un webhook six fois en une minute, la dernière requête est bloquée. Au bout d'une minute, vous pouvez à nouveau tester le webhook.

Les limites de création de webhooks comptabilisent chaque requête de création d'un webhook qui passe l'authentification et l'autorisation, y compris les requêtes qui échouent à la validation. Les requêtes qui dépassent la limite retournent `429 Too Many Requests`.

## Modifier la limite de débit {#change-the-rate-limit}

Prérequis :

- Disposer d'un accès administrateur.

Pour modifier la limite de débit :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Réseau**.
1. Développez **Limites de requêtes des crochets Web**.
1. Définissez les valeurs des limites de débit disponibles. Saisissez `0` pour désactiver une limite de débit.
1. Sélectionnez **Enregistrer les modifications**.

Les requêtes qui dépassent la limite de débit sont journalisées dans le fichier `auth.log`.
