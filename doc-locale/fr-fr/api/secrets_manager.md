---
stage: Software Supply Chain Security
group: Pipeline Security
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: API GitLab Secrets Manager
description: "API REST pour générer des jetons d'accès de courte durée pour GitLab Secrets Manager."
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/594090) dans GitLab 19.2 [avec le flag](../administration/feature_flags/_index.md) `secrets_manager_api_access`. Fonctionnalité désactivée par défaut.

{{< /history >}}

Utilisez cette API pour accéder aux secrets de [GitLab Secrets Manager](../ci/secrets/secrets_manager/_index.md) depuis des charges de travail non liées à CI/CD.

L'API génère un jeton JSON web (JWT) de courte durée pour un projet ou un groupe. Un client présente ce jeton au backend OpenBao pour lire les secrets directement, de la même façon que GitLab Runner lit les secrets lors d'un job CI/CD. La réponse inclut les informations de connexion OpenBao dont le client a besoin.

Vous appelez cette API avec un jeton d'accès personnel, un jeton d'accès de projet ou de groupe, ou un jeton de compte de service disposant de la portée `api`. Le jeton que l'API renvoie est un JWT OpenBao distinct et de courte durée, et non un jeton d'accès GitLab. Il expire après cinq minutes. La lecture d'une valeur de secret requiert également que le principal dispose de la permission de lecture pour ce secret.

Pour utiliser les informations de connexion renvoyées afin de lire un secret, consultez [Accéder aux secrets depuis des charges de travail non liées à CI/CD](../ci/secrets/secrets_manager/non_cicd_access.md).

## Créer un jeton d'accès Secrets Manager pour un projet {#create-a-secrets-manager-access-token-for-a-project}

Génère un jeton d'accès pour lire les secrets d'un projet.

```plaintext
POST /projects/:id/secrets_manager/access_token
```

Attributs pris en charge :

| Attribut | Type              | Obligatoire | Description |
|-----------|-------------------|----------|-------------|
| `id`      | entier ou chaîne | Oui      | L'ID ou le [chemin encodé en URL du projet](rest/_index.md#namespaced-paths). |

Exemple de requête :

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/projects/1/secrets_manager/access_token"
```

Exemple de réponse :

```json
{
  "expires_at": "2026-05-27T10:35:00Z",
  "provider": {
    "vault": {
      "server": "https://secrets.gitlab.com",
      "namespace": "org_5/group_42/project_99",
      "path": "secrets/kv",
      "version": "v2",
      "secrets_path": "explicit",
      "auth": {
        "jwt": {
          "path": "api_jwt/cel",
          "role": "all_api",
          "token": "<JWT>"
        }
      }
    }
  }
}
```

Attributs de la réponse :

| Attribut | Type | Description |
|-----------|------|-------------|
| `expires_at` | Chaîne | Horodatage ISO 8601 indiquant la date d'expiration du jeton. Les jetons sont valides pendant cinq minutes. |
| `provider.vault.server` | Chaîne | URL du serveur OpenBao auquel se connecter. Sur GitLab.com, il s'agit de `https://secrets.gitlab.com`. Sur GitLab Self-Managed, il s'agit de l'URL OpenBao configurée pour l'instance. |
| `provider.vault.namespace` | Chaîne | Espace de nommage OpenBao contenant les secrets du projet. Transmettez-le en tant qu'en-tête `X-Vault-Namespace`. |
| `provider.vault.path` | Chaîne | Chemin de montage du moteur de secrets KV. |
| `provider.vault.version` | Chaîne | Version du moteur de secrets KV. |
| `provider.vault.secrets_path` | Chaîne | Chemin de base dans le moteur KV où les secrets sont stockés. Ajoutez-le en préfixe d'un nom de secret pour construire le chemin de lecture (`<path>/data/<secrets_path>/<secret_name>`). |
| `provider.vault.auth.jwt.path` | Chaîne | Chemin de montage de la méthode d'authentification JWT. Authentifiez-vous à l'adresse `auth/<path>/login`. |
| `provider.vault.auth.jwt.role` | Chaîne | Rôle d'authentification JWT à utiliser pour la connexion. |
| `provider.vault.auth.jwt.token` | Chaîne | JWT de courte durée que le client présente à OpenBao. |

## Créer un jeton d'accès Secrets Manager pour un groupe {#create-a-secrets-manager-access-token-for-a-group}

Génère un jeton d'accès pour lire les secrets d'un groupe.

```plaintext
POST /groups/:id/secrets_manager/access_token
```

Attributs pris en charge :

| Attribut | Type              | Obligatoire | Description |
|-----------|-------------------|----------|-------------|
| `id`      | entier ou chaîne | Oui      | L'ID ou le [chemin encodé en URL du groupe](rest/_index.md#namespaced-paths). |

Exemple de requête :

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/1/secrets_manager/access_token"
```

Exemple de réponse :

```json
{
  "expires_at": "2026-05-27T10:35:00Z",
  "provider": {
    "vault": {
      "server": "https://secrets.gitlab.com",
      "namespace": "org_5/group_42/group_99",
      "path": "secrets/kv",
      "version": "v2",
      "secrets_path": "explicit",
      "auth": {
        "jwt": {
          "path": "api_jwt/cel",
          "role": "all_api",
          "token": "<JWT>"
        }
      }
    }
  }
}
```

Les attributs de la réponse sont identiques à ceux de [Créer un jeton d'accès Secrets Manager pour un projet](#create-a-secrets-manager-access-token-for-a-project), avec `provider.vault.namespace` limité au groupe.
