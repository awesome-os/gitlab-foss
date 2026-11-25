---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: API REST pour enregistrer et désinscrire des appareils mobiles pour les notifications push.
title: API des abonnements aux notifications push mobiles
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248023) dans GitLab 19.3 [avec le feature flag](../administration/feature_flags/_index.md) `mobile_push_registration_api`. Fonctionnalité désactivée par défaut.
- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248026) de la distribution des notifications dans GitLab 19.3 [avec les feature flags](../administration/feature_flags/_index.md) `mobile_push_notifications_dispatch` et `mobile_push_notifications`. Fonctionnalité désactivée par défaut.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/issues/607603) du feature flag `mobile_push_notifications` dans GitLab 19.6.

{{< /history >}}

Enregistrez des appareils mobiles pour recevoir des notifications push pour les [éléments de la liste de tâches](todos.md) de l'utilisateur authentifié. Chaque notification push correspond à un élément de la liste de tâches. L'enregistrement d'un appareil ne distribue pas les notifications par lui-même : la distribution est activée séparément pour l'instance avec le feature flag `mobile_push_notifications_dispatch`.

## Enregistrer un appareil {#register-a-device}

Enregistre un jeton d'appareil pour l'utilisateur authentifié. Cet endpoint est un upsert idempotent : enregistrer à nouveau un jeton existant actualise ses attributs et l'horodatage `last_seen_at`, de sorte que les clients se réenregistrent à chaque démarrage de l'application. Les attributs omis de la requête conservent leurs valeurs stockées lorsque le jeton est déjà enregistré. L'enregistrement d'un jeton appartenant à un autre utilisateur le réattribue à l'utilisateur authentifié.

Chaque utilisateur peut enregistrer jusqu'à 20 appareils. Les abonnements non consultés pendant 90 jours sont supprimés automatiquement.

```plaintext
POST /user/push_subscriptions
```

Attributs pris en charge :

<!-- markdownlint-disable MD055 MD056 -->

| Attribut          | Type   | Obligatoire | Description |
|--------------------|--------|----------|-------------|
| `device_token`     | Chaîne | Oui      | Le jeton d'appareil APNs hexadécimal. |
| `platform`         | Chaîne | Non       | La plateforme de l'appareil. `ios` ou `macos`. Les nouveaux enregistrements utilisent `ios` par défaut. |
| `apns_environment` | Chaîne | Non       | L'environnement APNs pour lequel le jeton a été émis : `production` ou `sandbox`. Par défaut : `production`. |
| `bundle_id`        | Chaîne | Non       | L'identifiant du bundle de l'application. |
| `device_name`      | Chaîne | Non       | Un nom d'appareil lisible par l'utilisateur. |
| `app_version`      | Chaîne | Non       | La version de l'application installée. |
| `locale`           | Chaîne | Non       | La locale de l'appareil. |
| `payload_mode`     | Chaîne | Non       | `full` envoie le contenu de la notification dans le payload push. `id_only` envoie uniquement les identifiants d'enregistrement, pour des payloads sans contenu. Les nouveaux enregistrements utilisent `full` par défaut. |
{.sortable}

<!-- markdownlint-enable MD055 MD056 -->

Exemple de requête :

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --data "device_token=abcdef0123456789abcdef0123456789" \
  --data "apns_environment=sandbox" \
  --url "https://gitlab.example.com/api/v4/user/push_subscriptions"
```

En cas de succès, renvoie [`201`](rest/troubleshooting.md#status-codes) et les attributs de réponse suivants :

| Attribut    | Type    | Description |
|--------------|---------|-------------|
| `id`         | Entier | L'identifiant de l'abonnement. |
| `created_at` | Chaîne  | La date et l'heure de création de l'abonnement, au format ISO 8601. |

Exemple de réponse :

```json
{
  "id": 1,
  "created_at": "2026-07-30T18:15:31.189Z"
}
```

## Désinscrire un appareil {#unregister-a-device}

Supprime l'abonnement de l'utilisateur authentifié pour un jeton d'appareil, par exemple lors de la déconnexion. Le jeton est transmis dans le corps de la requête plutôt que dans l'URL afin qu'il n'apparaisse pas dans les journaux d'accès. Retourne `204 No Content` en cas de succès et `404 Not Found` lorsqu'aucun abonnement correspondant n'existe.

```plaintext
DELETE /user/push_subscriptions
```

Attributs pris en charge :

| Attribut      | Type   | Obligatoire | Description |
|----------------|--------|----------|-------------|
| `device_token` | Chaîne | Oui      | Le jeton d'appareil APNs hexadécimal. |

Exemple de requête :

```shell
curl --request DELETE \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --data "device_token=abcdef0123456789abcdef0123456789" \
  --url "https://gitlab.example.com/api/v4/user/push_subscriptions"
```
