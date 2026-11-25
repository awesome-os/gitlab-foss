---
stage: Security Risk Management
group: Security Policies
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: API REST pour gérer les politiques de sécurité stockées dans le magasin de politiques pour les organisations et les groupes.
title: API du magasin de politiques
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/606971) dans GitLab 19.3 [avec le feature flag](../administration/feature_flags/_index.md) `security_policies_v2`. Fonctionnalité désactivée par défaut. Cette fonctionnalité est une [version expérimentale](../policy/development_stages_support.md).
- Points de terminaison du catalogue :
  - [Modifié](https://gitlab.com/gitlab-org/gitlab/-/work_items/598030) pour exiger une authentification dans GitLab 19.4.
  - Les déclencheurs `environment_advanced` et `deployment_promoted` ont été [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/252841) dans GitLab 19.4.
  - L'action `set_setting` a été [introduite](https://gitlab.com/gitlab-org/gitlab/-/work_items/630210) dans GitLab 19.6.
  - Les déclencheurs `project.before_settings_update`, `project.after_create` et `project.after_transfer` ainsi que l'attribut de déclencheur `[].kind` ont été [introduits](https://gitlab.com/gitlab-org/gitlab/-/work_items/634898) dans GitLab 19.6.
- Points de terminaison de politique :
  - [Modifié](https://gitlab.com/gitlab-org/gitlab/-/work_items/604367) pour persister les politiques dans la base de données dans GitLab 19.4.
  - L'attribut de réponse `policy_rego` a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/work_items/616505) dans GitLab 19.4.
  - L'attribut de réponse `scope_dimensions` a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/work_items/623359) dans GitLab 19.4.
- Le filtre `lifecycle_state` a été [introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/253089) dans GitLab 19.4.
- Points de terminaison de création et de mise à jour de politique :
  - Les limites sur `rules` et `actions` ont été [introduites](https://gitlab.com/gitlab-org/gitlab/-/work_items/612905) dans GitLab 19.4.
  - La validation Rego a été [introduite](https://gitlab.com/gitlab-org/gitlab/-/work_items/618556) dans GitLab 19.5.
- Les points de terminaison de groupe ont été [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/254842) dans GitLab 19.5.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Utilisez cette API pour créer des [politiques de sécurité](../user/application_security/policies/_index.md) dans le magasin de politiques. Une politique appartient à une organisation, répond à un seul déclencheur et contient les règles et les actions qui constituent son comportement.

Ces points de terminaison sont disponibles uniquement lorsque toutes les conditions suivantes sont remplies :

- Le feature flag `security_policies_v2` est activé.
- Un administrateur a activé la version expérimentale du magasin de politiques pour l'instance dans **Admin** > **Paramètres** > **Sécurité et conformité**.
- Pour les points de terminaison d'organisation, l'organisation a accepté de participer.
- Pour les points de terminaison de groupe, le groupe principal a accepté de participer.

Lorsque le feature flag, le paramètre d'instance ou l'adhésion de l'organisation n'est pas valide, les points de terminaison retournent `404 Not Found`. Lorsque l'instance n'est pas licenciée pour les politiques d'orchestration de sécurité, ou qu'un groupe n'a pas accepté de participer, ils retournent `403 Forbidden`.

## Catalogues {#catalogs}

Les points de terminaison du catalogue décrivent ce à partir de quoi une politique peut être construite et retournent le même contenu statique à chaque appelant éligible. L'appelant doit être un utilisateur authentifié dont l'organisation a le feature flag `security_policies_v2` activé. Dans le cas contraire, les points de terminaison retournent `404 Not Found`.

### Lister tous les déclencheurs {#list-all-triggers}

Liste tous les déclencheurs auxquels une politique peut répondre.

```plaintext
GET /security/policy_store/triggers
```

En cas de succès, renvoie [`200 OK`](rest/troubleshooting.md#status-codes) et les attributs de réponse suivants :

| Attribut | Type   | Description |
| --------- | ------ | ----------- |
| `[].id`   | Chaîne | ID du déclencheur, utilisé comme `trigger_type` lors de la création d'une politique. |
| `[].name` | Chaîne | Nom d'affichage du déclencheur. |
| `[].kind` | Chaîne | Soit `gate`, soit `event`. Un déclencheur `gate` est évalué avant la modification et peut l'arrêter. Un déclencheur `event` est évalué après la modification et ne peut pas l'arrêter. |

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/security/policy_store/triggers"
```

Exemple de réponse :

```json
[
  { "id": "deployment_requested", "name": "Deployment requested", "kind": "gate" },
  { "id": "environment_advanced", "name": "Environment advanced", "kind": "gate" },
  { "id": "deployment_promoted", "name": "Deployment promoted", "kind": "gate" },
  { "id": "project.before_settings_update", "name": "Project settings change requested", "kind": "gate" },
  { "id": "project.after_create", "name": "Project created", "kind": "event" },
  { "id": "project.after_transfer", "name": "Project transferred", "kind": "event" }
]
```

### Lister toutes les actions {#list-all-actions}

Liste toutes les actions qu'une politique peut effectuer.

```plaintext
GET /security/policy_store/actions
```

En cas de succès, renvoie [`200 OK`](rest/troubleshooting.md#status-codes) et les attributs de réponse suivants :

| Attribut | Type   | Description |
| --------- | ------ | ----------- |
| `[].id`   | Chaîne | ID de l'action. |
| `[].name` | Chaîne | Nom d'affichage de l'action. |

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/security/policy_store/actions"
```

Exemple de réponse :

```json
[
  { "id": "block", "name": "Block" },
  { "id": "require_approval", "name": "Require approval" },
  { "id": "set_setting", "name": "Set project setting" },
  { "id": "log_audit_trail", "name": "Log audit trail" }
]
```

### Lister tous les types de règles {#list-all-rule-kinds}

Liste tous les types de règles à partir desquels une politique peut être construite.

```plaintext
GET /security/policy_store/rules
```

En cas de succès, renvoie [`200 OK`](rest/troubleshooting.md#status-codes) et les attributs de réponse suivants :

| Attribut | Type   | Description |
| --------- | ------ | ----------- |
| `[].id`   | Chaîne | ID du type de règle. |
| `[].name` | Chaîne | Nom d'affichage du type de règle. |

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/security/policy_store/rules"
```

Exemple de réponse :

```json
[
  { "id": "custom", "name": "Custom" },
  { "id": "calendar", "name": "Calendar" },
  { "id": "environment", "name": "Environment" },
  { "id": "setting_validation", "name": "Project setting validation" }
]
```

## Attributs de politique {#policy-attributes}

Les points de terminaison de politique d'organisation et de groupe utilisent les mêmes attributs de portée, de règle, d'action et de réponse de politique.

### Attributs de portée de politique {#policy-scope-attributes}

`policy_scope` contient un ou plusieurs critères, et `match_mode` contrôle comment ils se combinent. Un critère désigne des identifiants, soit sous forme d'entiers, soit sous forme d'objets avec une clé `id`. GitLab déduplique et trie les identifiants, de sorte que l'ordre de création ne modifie pas le programme compilé.

| Attribut | Type | Description |
| --------- | ---- | ----------- |
| `application` | object | Listes `including` et `excluding` d'identifiants d'attributs de sécurité d'application. |
| `business_impact` | object | Listes `including` et `excluding` d'identifiants d'attributs de sécurité d'impact métier. |
| `business_unit` | object | Listes `including` et `excluding` d'identifiants d'attributs de sécurité d'unité métier. |
| `compliance_frameworks` | Tableau | Identifiants des référentiels de conformité que le projet doit porter. Prend une liste directement, plutôt que `including` et `excluding`. |
| `exposure` | object | Listes `including` et `excluding` d'identifiants d'attributs de sécurité d'exposition. |
| `groups` | object | Listes `including` et `excluding` d'identifiants de groupe. |
| `match_mode` | Chaîne | Soit `all`, soit `any`. Avec `all`, chaque critère doit correspondre. Avec `any`, une seule correspondance suffit. Toute autre valeur est traitée comme `all`. |
| `projects` | object | Listes `including` et `excluding` d'identifiants de projet. `excluding` accepte également `{"type": "personal"}` et `{"type": "archived"}`, qui excluent chaque projet de ce type. |

Par exemple :

```json
{
  "match_mode": "any",
  "compliance_frameworks": [{ "id": 5 }],
  "projects": { "including": [12, 34], "excluding": [{ "type": "archived" }] },
  "groups": { "including": [{ "id": 7 }] }
}
```

Une valeur que GitLab ne peut pas lire comme identifiant retourne `400 Bad Request`. Cela couvre une valeur qui n'est pas un nombre, et un nombre en dehors de la plage 1 à 9223372036854775807.

Trois cas sont acceptés et méritent d'être connus, car chacun définit la portée de la politique différemment de ce à quoi vous pourriez vous attendre :

- Une liste `including` qui ne désigne aucun identifiant ne correspond à rien pour ce critère. Avec `match_mode: all`, la politique ne s'applique alors à aucun projet. Avec `match_mode: any`, un autre critère peut encore correspondre.
- Une liste `excluding` qui ne désigne aucun identifiant n'exclut rien.
- Un critère que GitLab ne reconnaît pas n'a aucun effet. S'il s'agissait du seul critère fourni, la politique s'applique à chaque projet.

### Attributs de règle et d'action {#rule-and-action-attributes}

`rules` et `actions` sont des tableaux. Chaque entrée possède les attributs suivants :

| Attribut | Type           | Obligatoire | Description |
| --------- | -------------- | -------- | ----------- |
| `type`    | Chaîne         | Oui      | Pour une règle, l'un des identifiants retournés par [Lister tous les types de règles](#list-all-rule-kinds). Pour une action, l'un des identifiants retournés par [Lister toutes les actions](#list-all-actions). |
| `value`   | string or hash | Non       | Ce sur quoi l'entrée agit. Une règle `custom` prend la source Rego sous forme de chaîne. Toute autre règle prend un hash, de même que chaque action. Une règle `setting_validation` ne signale aucune violation sur un projet dont le contexte d'évaluation ne contient pas le paramètre nommé. |

Chaque tableau accepte au maximum 5 entrées, et chaque entrée doit être sérialisée en au plus 4096 octets. L'erreur pour une entrée trop grande désigne chaque position, par exemple `rules has an entry exceeding maximum size of 4096 bytes at 0`. Une entrée ne peut pas être vide. Une entrée vide retourne `400 Bad Request`, et l'erreur désigne chaque position vide, par exemple `rules[0] is blank`.

Le Rego d'une règle `custom`, ainsi que le module `policy_rego` dans lequel toutes les règles fusionnent, doivent être analysables. Une règle `custom` qui ne l'est pas retourne `400 Bad Request`. L'erreur désigne la position de la règle et inclut le message du moteur avec une ligne et une colonne dans le Rego que vous avez envoyé dans `value`, par exemple ``rules[0] is invalid: error: expecting `}` while parsing object (at line:column)``. Le module `policy_rego` est également analysé, après que toutes les règles y ont fusionné. Comme chaque règle a déjà été analysée séparément, un échec à cette étape est traité comme une défaillance du moteur de politique : la requête retourne `500 Internal Server Error`, la politique n'est pas stockée et la défaillance est signalée au suivi des erreurs.

Envoyez `rules` et `actions` en JSON avec un en-tête `Content-Type: application/json`. Un corps encodé en formulaire peut contenir les deux tableaux, mais chaque valeur d'un tableau arrive sous forme de chaîne, donc un `value` qui n'est pas une chaîne ne peut pas être exprimé de cette manière.

### Attributs de réponse {#response-attributes}

Les points de terminaison de politique retournent les attributs suivants :

| Attribut         | Type            | Description |
| ----------------- | --------------- | ----------- |
| `actions`         | Tableau           | Actions effectuées par la politique. |
| `created_at`      | Chaîne          | Date et heure de création de la politique. |
| `description`     | Chaîne          | Description de la politique. |
| `id`              | Entier         | ID de la politique. |
| `lifecycle_state` | Chaîne          | Soit `active`, soit `disabled`. |
| `mode`            | Chaîne          | L'une des valeurs `audit`, `warn` ou `enforce`. |
| `name`            | Chaîne          | Nom de la politique. |
| `namespace_id`    | Entier         | ID du groupe propriétaire de la politique. `null` pour une politique créée via un point de terminaison d'organisation, car l'organisation est propriétaire de cette politique, ou lorsque vous ne pouvez pas voir le groupe. |
| `organization_id` | Entier         | ID de l'organisation à laquelle appartient la politique. |
| `policy_rego`     | Chaîne          | Les règles de la politique, compilées en un seul module Rego. `null` pour une politique sans règles. |
| `policy_scope`    | object          | Portée structurée de la politique, ou `null` lorsque le Rego a été rédigé directement. |
| `rules`           | Tableau           | Règles de la politique. |
| `scope_dimensions`| Tableau           | Chemins de contexte pointés que `scope_rego` lit pour déterminer si la politique s'applique. GitLab dérive cette valeur et ignore donc toute valeur que vous envoyez pour elle. `null` lorsque `scope_rego` a été rédigé directement, sinon un tableau, vide lorsque la politique n'a pas de portée. |
| `scope_rego`      | Chaîne          | Portée de la politique, sous forme de programme en [Rego](https://www.openpolicyagent.org/docs/policy-language), le langage de politique d'Open Policy Agent. Soit rédigé directement, soit compilé à partir de `policy_scope`. Toujours présent, car une politique sans portée se compile en un programme qui s'applique à chaque projet. |
| `trigger_type`    | Chaîne          | Déclencheur auquel la politique répond. |
| `updated_at`      | Chaîne          | Date et heure de la dernière modification de la politique. |
| `version`         | Entier         | Révision de la politique. Une mise à jour qui modifie au moins une valeur l'augmente de un. |

## Politiques d'organisation {#organization-policies}

Utilisez les points de terminaison d'organisation pour gérer les politiques d'une organisation.

Prérequis :

- Vous devez être propriétaire de l'organisation ou administrateur de l'instance.

Pour inscrire une organisation, envoyez la mutation GraphQL `organizationUpdate` avec `policyStoreExperimentEnabled` défini sur `true`. La mutation retourne une erreur si la version expérimentale n'est pas disponible pour l'organisation.

Chaque appel à un point de terminaison de politique doit être [authentifié](rest/authentication.md). Un appelant qui ne peut pas administrer l'organisation reçoit `403 Forbidden`, et celui qui ne peut pas voir l'organisation du tout reçoit `404 Not Found`.

Une politique appartenant à une autre organisation est impossible à distinguer d'une politique qui n'existe pas. Un identifiant ne peut pas être utilisé pour lire ou modifier une politique dans différentes organisations.

### Lister toutes les politiques d'organisation {#list-all-organization-policies}

Liste toutes les politiques appartenant à une organisation.

```plaintext
GET /organizations/:id/security/policy_store
```

Attributs pris en charge :

| Attribut         | Type    | Obligatoire | Description |
| ----------------- | ------- | -------- | ----------- |
| `id`              | Entier | Oui      | ID de l'organisation. |
| `lifecycle_state` | Chaîne  | Non       | Retourne uniquement les politiques `active`, uniquement les politiques `disabled` ou les politiques `all`. Par défaut : `active`. |
| `namespace_ids`   | Tableau   | Non       | Identifiants d'espaces de nommage, généralement un groupe et ses ancêtres. Retourne uniquement leurs politiques et celles à l'échelle de l'organisation. Jusqu'à 21 identifiants uniques ; au-delà, retourne `400 Bad Request`. Sur GitLab.com, l'organisation par défaut ne retourne aucune politique à l'échelle de l'organisation et ne retourne aucune politique sans cela. |
| `page`            | Entier | Non       | Page de résultats à retourner. Par défaut : `1`. |
| `per_page`        | Entier | Non       | Nombre de résultats par page. La valeur par défaut est `20`, et toute valeur supérieure à `100` est limitée à `100`. |
| `trigger_type`    | Chaîne  | Non       | Retourne uniquement les politiques qui répondent à ce déclencheur. L'un des identifiants retournés par [Lister tous les déclencheurs](#list-all-triggers). |

Ce point de terminaison retourne des résultats [paginés](rest/_index.md#offset-based-pagination). Pour des raisons de performances, il ne retourne jamais les en-têtes `x-total` ou `x-total-pages`, ni le `rel="last"` `link`, quel que soit le nombre de politiques de l'organisation : vérifiez `x-next-page` pour savoir si une autre page suit.

En cas de succès, retourne [`200 OK`](rest/troubleshooting.md#status-codes) et un tableau d'[attributs de politique](#response-attributes). Sur GitLab.com, une requête à l'organisation par défaut sans `namespace_ids` retourne `400 Bad Request` lorsque `trigger_type` est `project.before_settings_update`, `project.after_create` ou `project.after_transfer`, car ces déclencheurs portent la hiérarchie de groupe.

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/organizations/1/security/policy_store?per_page=20"
```

Exemple de réponse :

```json
[
  {
    "id": 1,
    "organization_id": 1,
    "namespace_id": null,
    "name": "Block deployments on critical findings",
    "description": null,
    "version": 1,
    "trigger_type": "deployment_requested",
    "rules": [{ "type": "custom", "value": "package governance" }],
    "policy_rego": "package governance\n",
    "actions": [{ "type": "block" }],
    "policy_scope": null,
    "scope_dimensions": [],
    "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
    "mode": "enforce",
    "lifecycle_state": "active",
    "created_at": "2026-08-07T13:56:32.985Z",
    "updated_at": "2026-08-07T13:56:32.985Z"
  }
]
```

### Récupérer une politique d'organisation {#retrieve-an-organization-policy}

Récupère une seule politique d'une organisation.

```plaintext
GET /organizations/:id/security/policy_store/:policy_id
```

Attributs pris en charge :

| Attribut   | Type    | Obligatoire | Description |
| ----------- | ------- | -------- | ----------- |
| `id`        | Entier | Oui      | ID de l'organisation. |
| `policy_id` | Entier | Oui      | ID de la politique. |

En cas de succès, retourne [`200 OK`](rest/troubleshooting.md#status-codes) et les [attributs de politique](#response-attributes). Sur GitLab.com, l'organisation par défaut retourne `404 Not Found` pour chaque politique. Chaque client accède à ses politiques via son propre groupe.

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/organizations/1/security/policy_store/1"
```

Exemple de réponse :

```json
{
  "id": 1,
  "organization_id": 1,
  "namespace_id": null,
  "name": "Block deployments on critical findings",
  "description": null,
  "version": 1,
  "trigger_type": "deployment_requested",
  "rules": [{ "type": "custom", "value": "package governance" }],
  "policy_rego": "package governance\n",
  "actions": [{ "type": "block" }],
  "policy_scope": null,
  "scope_dimensions": [],
  "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
  "mode": "enforce",
  "lifecycle_state": "active",
  "created_at": "2026-08-07T13:56:32.985Z",
  "updated_at": "2026-08-07T13:56:32.985Z"
}
```

### Créer une politique d'organisation {#create-an-organization-policy}

Crée une politique dans une organisation.

```plaintext
POST /organizations/:id/security/policy_store
```

Attributs pris en charge :

| Attribut         | Type    | Obligatoire | Description |
| ----------------- | ------- | -------- | ----------- |
| `id`              | Entier | Oui      | ID de l'organisation. |
| `name`            | Chaîne  | Oui      | Nom de la politique. Maximum 255 caractères. Doit être unique dans l'organisation. |
| `rules`           | Tableau   | Oui      | Règles de la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Au moins une entrée est requise, jusqu'à 5. Chaque entrée doit être sérialisée en au plus 4096 octets. Rejeté lorsque les entrées compilent en un module Rego de plus de 65536 octets. Ce module est retourné comme `policy_rego`. |
| `trigger_type`    | Chaîne  | Oui      | Déclencheur auquel la politique répond. L'un des identifiants retournés par [Lister tous les déclencheurs](#list-all-triggers). |
| `actions`         | Tableau   | Non       | Actions effectuées par la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Jusqu'à 5 entrées. Chaque entrée doit être sérialisée en au plus 4096 octets. |
| `description`     | Chaîne  | Non       | Description de la politique. Maximum 4096 caractères. |
| `lifecycle_state` | Chaîne  | Non       | Soit `active`, soit `disabled`. Par défaut : `active`. |
| `mode`            | Chaîne  | Non       | L'une des valeurs `audit`, `warn` ou `enforce`. Par défaut : `warn`. |
| `policy_scope`    | object  | Non       | Portée structurée de la politique, que GitLab compile dans `scope_rego`. Pour ses attributs, consultez [Attributs de portée de politique](#policy-scope-attributes). Ne peut pas être combiné avec un `scope_rego` non vide. Rejeté lorsqu'il compile en plus de 4096 caractères de Rego. |
| `scope_rego`      | Chaîne  | Non       | Portée de la politique, rédigée directement sous forme de programme Rego. GitLab le stocke tel que vous l'avez rédigé. Maximum 4096 caractères. Une valeur non vide ne peut pas être combinée avec `policy_scope`. Une valeur vide a le même effet que l'omission. Une valeur qui ne peut pas être analysée comme Rego retourne `400 Bad Request`. |

En cas de succès, retourne [`201 Created`](rest/troubleshooting.md#status-codes) et les [attributs de politique](#response-attributes). Les conditions suivantes retournent `400 Bad Request` :

- Un attribut est invalide.
- Les deux formes de portée sont fournies.
- Le nom est déjà utilisé dans l'organisation.
- Un `scope_rego` compilé dépasse 4096 caractères.
- Le `rules` compile en plus de 65536 octets de Rego.
- `rules` ou `actions` contient plus de 5 entrées.
- Une entrée dans `rules` ou `actions` est sérialisée en plus de 4096 octets.

Sur GitLab.com, la création d'une politique dans l'organisation par défaut retourne [`422 Unprocessable Entity`](rest/troubleshooting.md#status-codes). Les groupes sans leur propre organisation partagent celle par défaut, de sorte qu'une politique à l'échelle de l'organisation s'y appliquerait à tous. Créez plutôt la politique dans un groupe.

Exemple de requête :

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "Block deployments on critical findings",
    "trigger_type": "deployment_requested",
    "rules": [{ "type": "custom", "value": "package governance" }],
    "actions": [{ "type": "block" }],
    "policy_scope": { "compliance_frameworks": [{ "id": 5 }] }
  }' \
  --url "https://gitlab.example.com/api/v4/organizations/1/security/policy_store"
```

Exemple de réponse :

```json
{
  "id": 1,
  "organization_id": 1,
  "namespace_id": null,
  "name": "Block deployments on critical findings",
  "description": null,
  "version": 1,
  "trigger_type": "deployment_requested",
  "rules": [{ "type": "custom", "value": "package governance" }],
  "policy_rego": "package governance\n",
  "actions": [{ "type": "block" }],
  "policy_scope": { "compliance_frameworks": [{ "id": 5 }] },
  "scope_dimensions": ["compliance_frameworks"],
  "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
  "mode": "warn",
  "lifecycle_state": "active",
  "created_at": "2026-08-07T13:56:32.985Z",
  "updated_at": "2026-08-07T13:56:32.985Z"
}
```

### Mettre à jour une politique d'organisation {#update-an-organization-policy}

Met à jour une politique dans une organisation. Chaque attribut autre que les paramètres de chemin est facultatif, mais une requête doit en nommer au moins un. Les attributs non envoyés sont conservés tels quels, et une mise à jour qui modifie au moins une valeur augmente `version` de un. Une requête qui réitère les valeurs stockées ne change rien et laisse `version` tel quel.

```plaintext
PATCH /organizations/:id/security/policy_store/:policy_id
```

Attributs pris en charge :

| Attribut         | Type    | Obligatoire | Description |
| ----------------- | ------- | -------- | ----------- |
| `id`              | Entier | Oui      | ID de l'organisation. |
| `policy_id`       | Entier | Oui      | ID de la politique. |
| `actions`         | Tableau   | Non       | Actions effectuées par la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Remplace les actions stockées, jusqu'à 5 entrées. Chaque entrée doit être sérialisée en au plus 4096 octets. |
| `description`     | Chaîne  | Non       | Description de la politique. Maximum 4096 caractères. |
| `lifecycle_state` | Chaîne  | Non       | Soit `active`, soit `disabled`. |
| `mode`            | Chaîne  | Non       | L'une des valeurs `audit`, `warn` ou `enforce`. |
| `name`            | Chaîne  | Non       | Nom de la politique. Maximum 255 caractères. Doit être unique dans l'organisation. |
| `policy_scope`    | object  | Non       | Portée structurée de la politique, que GitLab compile dans `scope_rego`. Pour ses attributs, consultez [Attributs de portée de politique](#policy-scope-attributes). Ne peut pas être combiné avec un `scope_rego` non vide. Rejeté lorsqu'il compile en plus de 4096 caractères de Rego. |
| `rules`           | Tableau   | Non       | Règles de la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Remplace les règles stockées, jusqu'à 5 entrées. Chaque entrée doit être sérialisée en au plus 4096 octets. Rejeté lorsque les entrées compilent en un module Rego de plus de 65536 octets. Ce module est retourné comme `policy_rego`. |
| `scope_rego`      | Chaîne  | Non       | Portée de la politique, rédigée directement sous forme de programme Rego. GitLab le stocke tel que vous l'avez rédigé. Maximum 4096 caractères. Envoyez une valeur vide pour retirer un programme rédigé manuellement et recompiler à partir de `policy_scope`. Une valeur qui ne peut pas être analysée comme Rego retourne `400 Bad Request`. |
| `trigger_type`    | Chaîne  | Non       | Déclencheur auquel la politique répond. L'un des identifiants retournés par [Lister tous les déclencheurs](#list-all-triggers). Pour une politique appartenant à un groupe, doit être `project.before_settings_update`, `project.after_create` ou `project.after_transfer`, car seuls ces déclencheurs portent la hiérarchie de groupe. |

Lorsque vous renommez une politique, GitLab doit recompiler un `scope_rego` généré, car le nom de la politique apparaît dans le programme généré. Un `scope_rego` rédigé directement est conservé tel quel.

En cas de succès, retourne [`200 OK`](rest/troubleshooting.md#status-codes) et les [attributs de politique](#response-attributes). Sur GitLab.com, l'organisation par défaut retourne `404 Not Found` pour chaque politique lorsque la requête est valide. Chaque client accède à ses politiques via son propre groupe. Les conditions suivantes retournent `400 Bad Request` :

- Aucun attribut à modifier n'est fourni.
- Un attribut est invalide.
- Les deux formes de portée sont fournies.
- Le nouveau nom est déjà utilisé dans l'organisation.
- Un `scope_rego` recompilé dépasse 4096 caractères.
- Le `rules` de remplacement compile en plus de 65536 octets de Rego.
- Le `rules` ou `actions` de remplacement contient plus de 5 entrées.
- Une entrée dans le `rules` ou `actions` de remplacement est sérialisée en plus de 4096 octets.
- La politique appartient à un groupe et le nouveau `trigger_type` n'est pas utilisable par une politique de groupe.

Exemple de requête :

```shell
curl --request PATCH --header "PRIVATE-TOKEN: <your_access_token>" \
  --data-urlencode "name=Renamed policy" \
  --url "https://gitlab.example.com/api/v4/organizations/1/security/policy_store/1"
```

Exemple de réponse :

```json
{
  "id": 1,
  "organization_id": 1,
  "namespace_id": null,
  "name": "Renamed policy",
  "description": null,
  "version": 2,
  "trigger_type": "deployment_requested",
  "rules": [{ "type": "custom", "value": "package governance" }],
  "policy_rego": "package governance\n",
  "actions": [{ "type": "block" }],
  "policy_scope": null,
  "scope_dimensions": [],
  "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
  "mode": "enforce",
  "lifecycle_state": "active",
  "created_at": "2026-08-07T13:56:32.985Z",
  "updated_at": "2026-08-07T14:02:47.198Z"
}
```

### Supprimer une politique d'organisation {#delete-an-organization-policy}

Supprime une politique d'une organisation.

```plaintext
DELETE /organizations/:id/security/policy_store/:policy_id
```

Attributs pris en charge :

| Attribut   | Type    | Obligatoire | Description |
| ----------- | ------- | -------- | ----------- |
| `id`        | Entier | Oui      | ID de l'organisation. |
| `policy_id` | Entier | Oui      | ID de la politique. |

En cas de succès, retourne [`204 No Content`](rest/troubleshooting.md#status-codes). Sur GitLab.com, l'organisation par défaut retourne `404 Not Found` pour chaque politique. Chaque client accède à ses politiques via son propre groupe.

Exemple de requête :

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/organizations/1/security/policy_store/1"
```

## Politiques de groupe {#group-policies}

Utilisez les points de terminaison de groupe pour gérer les politiques d'un groupe. Dans ces points de terminaison, `id` est l'ID ou le [chemin encodé en URL](rest/_index.md#namespaced-paths) du groupe.

Prérequis :

- Le groupe doit avoir accepté de participer à la version expérimentale du magasin de politiques. Un sous-groupe suit l'adhésion de son groupe principal.
- Pour lister ou récupérer des politiques, vous devez avoir le rôle Propriétaire pour le groupe, être auditeur ou être administrateur de l'instance.
- Pour créer, mettre à jour ou supprimer des politiques, vous devez avoir le rôle Propriétaire pour le groupe ou être administrateur de l'instance.

Un groupe accepte de participer via son paramètre `policy_store_experiment_enabled`. Un groupe qui a déjà des politiques de sécurité configurées via un projet de politique de sécurité ne peut pas accepter de participer.

### Lister toutes les politiques de groupe {#list-all-group-policies}

Liste toutes les politiques appartenant à un groupe.

```plaintext
GET /groups/:id/security/policy_store
```

Attributs pris en charge :

| Attribut         | Type              | Obligatoire | Description |
| ----------------- | ----------------- | -------- | ----------- |
| `id`              | integer or string | Oui      | ID ou [chemin encodé en URL](rest/_index.md#namespaced-paths) du groupe. |
| `lifecycle_state` | Chaîne            | Non       | Retourne uniquement les politiques `active`, uniquement les politiques `disabled` ou les politiques `all`. Par défaut : `active`. |
| `page`            | Entier           | Non       | Page de résultats à retourner. Par défaut : `1`. |
| `per_page`        | Entier           | Non       | Nombre de résultats par page. La valeur par défaut est `20`, et toute valeur supérieure à `100` est limitée à `100`. |
| `trigger_type`    | Chaîne            | Non       | Retourne uniquement les politiques qui répondent à ce déclencheur. L'un des identifiants retournés par [Lister tous les déclencheurs](#list-all-triggers). |

Ce point de terminaison retourne des résultats paginés. Pour des raisons de performances, il ne retourne jamais les en-têtes `x-total` ou `x-total-pages`, ni le `rel="last"` `link`, quel que soit le nombre de politiques du groupe : vérifiez `x-next-page` pour savoir si une autre page suit.

En cas de succès, retourne [`200 OK`](rest/troubleshooting.md#status-codes) et un tableau d'[attributs de politique](#response-attributes).

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/5/security/policy_store?per_page=20"
```

Exemple de réponse :

```json
[
  {
    "id": 1,
    "organization_id": 1,
    "namespace_id": 5,
    "name": "Block settings changes on critical findings",
    "description": null,
    "version": 1,
    "trigger_type": "project.before_settings_update",
    "rules": [{ "type": "custom", "value": "package governance" }],
    "policy_rego": "package governance\n",
    "actions": [{ "type": "block" }],
    "policy_scope": null,
    "scope_dimensions": [],
    "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
    "mode": "enforce",
    "lifecycle_state": "active",
    "created_at": "2026-08-07T13:56:32.985Z",
    "updated_at": "2026-08-07T13:56:32.985Z"
  }
]
```

### Récupérer une politique de groupe {#retrieve-a-group-policy}

Récupère une seule politique d'un groupe.

```plaintext
GET /groups/:id/security/policy_store/:policy_id
```

Attributs pris en charge :

| Attribut   | Type              | Obligatoire | Description |
| ----------- | ----------------- | -------- | ----------- |
| `id`        | integer or string | Oui      | ID ou [chemin encodé en URL](rest/_index.md#namespaced-paths) du groupe. |
| `policy_id` | Entier           | Oui      | ID de la politique. |

En cas de succès, retourne [`200 OK`](rest/troubleshooting.md#status-codes) et les [attributs de politique](#response-attributes).

Exemple de requête :

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/5/security/policy_store/1"
```

Exemple de réponse :

```json
{
  "id": 1,
  "organization_id": 1,
  "namespace_id": 5,
  "name": "Block settings changes on critical findings",
  "description": null,
  "version": 1,
  "trigger_type": "project.before_settings_update",
  "rules": [{ "type": "custom", "value": "package governance" }],
  "policy_rego": "package governance\n",
  "actions": [{ "type": "block" }],
  "policy_scope": null,
  "scope_dimensions": [],
  "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
  "mode": "enforce",
  "lifecycle_state": "active",
  "created_at": "2026-08-07T13:56:32.985Z",
  "updated_at": "2026-08-07T13:56:32.985Z"
}
```

### Créer une politique de groupe {#create-a-group-policy}

Crée une politique dans un groupe.

```plaintext
POST /groups/:id/security/policy_store
```

Attributs pris en charge :

| Attribut         | Type              | Obligatoire | Description |
| ----------------- | ----------------- | -------- | ----------- |
| `id`              | integer or string | Oui      | ID ou [chemin encodé en URL](rest/_index.md#namespaced-paths) du groupe. |
| `name`            | Chaîne            | Oui      | Nom de la politique. Maximum 255 caractères. Doit être unique dans l'organisation. |
| `rules`           | Tableau             | Oui      | Règles de la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Au moins une entrée est requise, jusqu'à 5. Chaque entrée doit être sérialisée en au plus 4096 octets. Rejeté lorsque les entrées compilent en un module Rego de plus de 65536 octets. Ce module est retourné comme `policy_rego`. |
| `trigger_type`    | Chaîne            | Oui      | Déclencheur auquel la politique répond. L'un des identifiants retournés par [Lister tous les déclencheurs](#list-all-triggers). Doit être `project.before_settings_update`, `project.after_create` ou `project.after_transfer`, car seuls ces déclencheurs portent la hiérarchie de groupe. |
| `actions`         | Tableau             | Non       | Actions effectuées par la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Jusqu'à 5 entrées. Chaque entrée doit être sérialisée en au plus 4096 octets. |
| `description`     | Chaîne            | Non       | Description de la politique. Maximum 4096 caractères. |
| `lifecycle_state` | Chaîne            | Non       | Soit `active`, soit `disabled`. Par défaut : `active`. |
| `mode`            | Chaîne            | Non       | L'une des valeurs `audit`, `warn` ou `enforce`. Par défaut : `warn`. |
| `policy_scope`    | object            | Non       | Portée structurée de la politique, que GitLab compile dans `scope_rego`. Pour ses attributs, consultez [Attributs de portée de politique](#policy-scope-attributes). Ne peut pas être combiné avec un `scope_rego` non vide. Rejeté lorsqu'il compile en plus de 4096 caractères de Rego. |
| `scope_rego`      | Chaîne            | Non       | Portée de la politique, rédigée directement sous forme de programme Rego. GitLab le stocke tel que vous l'avez rédigé. Maximum 4096 caractères. Une valeur non vide ne peut pas être combinée avec `policy_scope`. Une valeur vide a le même effet que l'omission. Une valeur qui ne peut pas être analysée comme Rego retourne `400 Bad Request`. |

En cas de succès, retourne [`201 Created`](rest/troubleshooting.md#status-codes) et les [attributs de politique](#response-attributes). Les conditions suivantes retournent `400 Bad Request` :

- Un attribut est invalide.
- Les deux formes de portée sont fournies.
- Le nom est déjà utilisé dans l'organisation.
- Un `scope_rego` compilé dépasse 4096 caractères.
- Le `rules` compile en plus de 65536 octets de Rego.
- `rules` ou `actions` contient plus de 5 entrées.
- Une entrée dans `rules` ou `actions` est sérialisée en plus de 4096 octets.
- Le `trigger_type` n'est pas utilisable par une politique de groupe.

Exemple de requête :

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "Block settings changes on critical findings",
    "trigger_type": "project.before_settings_update",
    "rules": [{ "type": "custom", "value": "package governance" }],
    "actions": [{ "type": "block" }],
    "policy_scope": { "compliance_frameworks": [{ "id": 5 }] }
  }' \
  --url "https://gitlab.example.com/api/v4/groups/5/security/policy_store"
```

Exemple de réponse :

```json
{
  "id": 1,
  "organization_id": 1,
  "namespace_id": 5,
  "name": "Block settings changes on critical findings",
  "description": null,
  "version": 1,
  "trigger_type": "project.before_settings_update",
  "rules": [{ "type": "custom", "value": "package governance" }],
  "policy_rego": "package governance\n",
  "actions": [{ "type": "block" }],
  "policy_scope": { "compliance_frameworks": [{ "id": 5 }] },
  "scope_dimensions": ["compliance_frameworks"],
  "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
  "mode": "warn",
  "lifecycle_state": "active",
  "created_at": "2026-08-07T13:56:32.985Z",
  "updated_at": "2026-08-07T13:56:32.985Z"
}
```

### Mettre à jour une politique de groupe {#update-a-group-policy}

Met à jour une politique dans un groupe. Chaque attribut autre que les paramètres de chemin est facultatif, mais une requête doit en nommer au moins un. Les attributs non envoyés sont conservés tels quels, et une mise à jour qui modifie au moins une valeur augmente `version` de un. Une requête qui réitère les valeurs stockées ne change rien et laisse `version` tel quel.

```plaintext
PATCH /groups/:id/security/policy_store/:policy_id
```

Attributs pris en charge :

| Attribut         | Type              | Obligatoire | Description |
| ----------------- | ----------------- | -------- | ----------- |
| `id`              | integer or string | Oui      | ID ou [chemin encodé en URL](rest/_index.md#namespaced-paths) du groupe. |
| `policy_id`       | Entier           | Oui      | ID de la politique. |
| `actions`         | Tableau             | Non       | Actions effectuées par la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Remplace les actions stockées, jusqu'à 5 entrées. Chaque entrée doit être sérialisée en au plus 4096 octets. |
| `description`     | Chaîne            | Non       | Description de la politique. Maximum 4096 caractères. |
| `lifecycle_state` | Chaîne            | Non       | Soit `active`, soit `disabled`. |
| `mode`            | Chaîne            | Non       | L'une des valeurs `audit`, `warn` ou `enforce`. |
| `name`            | Chaîne            | Non       | Nom de la politique. Maximum 255 caractères. Doit être unique dans l'organisation. |
| `policy_scope`    | object            | Non       | Portée structurée de la politique, que GitLab compile dans `scope_rego`. Pour ses attributs, consultez [Attributs de portée de politique](#policy-scope-attributes). Ne peut pas être combiné avec un `scope_rego` non vide. Rejeté lorsqu'il compile en plus de 4096 caractères de Rego. |
| `rules`           | Tableau             | Non       | Règles de la politique. Pour les attributs d'entrée, consultez [Attributs de règle et d'action](#rule-and-action-attributes). Remplace les règles stockées, jusqu'à 5 entrées. Chaque entrée doit être sérialisée en au plus 4096 octets. Rejeté lorsque les entrées compilent en un module Rego de plus de 65536 octets. Ce module est retourné comme `policy_rego`. |
| `scope_rego`      | Chaîne            | Non       | Portée de la politique, rédigée directement sous forme de programme Rego. GitLab le stocke tel que vous l'avez rédigé. Maximum 4096 caractères. Envoyez une valeur vide pour retirer un programme rédigé manuellement et recompiler à partir de `policy_scope`. Une valeur qui ne peut pas être analysée comme Rego retourne `400 Bad Request`. |
| `trigger_type`    | Chaîne            | Non       | Déclencheur auquel la politique répond. L'un des identifiants retournés par [Lister tous les déclencheurs](#list-all-triggers). Doit être `project.before_settings_update`, `project.after_create` ou `project.after_transfer`, car seuls ces déclencheurs portent la hiérarchie de groupe. |

Lorsque vous renommez une politique, GitLab doit recompiler un `scope_rego` généré, car le nom de la politique apparaît dans le programme généré. Un `scope_rego` rédigé directement est conservé tel quel.

En cas de succès, retourne [`200 OK`](rest/troubleshooting.md#status-codes) et les [attributs de politique](#response-attributes). Les conditions suivantes retournent `400 Bad Request` :

- Aucun attribut à modifier n'est fourni.
- Un attribut est invalide.
- Les deux formes de portée sont fournies.
- Le nouveau nom est déjà utilisé dans l'organisation.
- Un `scope_rego` recompilé dépasse 4096 caractères.
- Le `rules` de remplacement compile en plus de 65536 octets de Rego.
- Le `rules` ou `actions` de remplacement contient plus de 5 entrées.
- Une entrée dans le `rules` ou `actions` de remplacement est sérialisée en plus de 4096 octets.
- Le nouveau `trigger_type` n'est pas utilisable par une politique de groupe.

Exemple de requête :

```shell
curl --request PATCH --header "PRIVATE-TOKEN: <your_access_token>" \
  --data-urlencode "name=Renamed policy" \
  --url "https://gitlab.example.com/api/v4/groups/5/security/policy_store/1"
```

Exemple de réponse :

```json
{
  "id": 1,
  "organization_id": 1,
  "namespace_id": 5,
  "name": "Renamed policy",
  "description": null,
  "version": 2,
  "trigger_type": "project.before_settings_update",
  "rules": [{ "type": "custom", "value": "package governance" }],
  "policy_rego": "package governance\n",
  "actions": [{ "type": "block" }],
  "policy_scope": null,
  "scope_dimensions": [],
  "scope_rego": "package gitlab.scope\n\napplicable := [result.policy | some result in results; result.applies]\n...",
  "mode": "enforce",
  "lifecycle_state": "active",
  "created_at": "2026-08-07T13:56:32.985Z",
  "updated_at": "2026-08-07T14:02:47.198Z"
}
```

### Supprimer une politique de groupe {#delete-a-group-policy}

Supprime une politique d'un groupe.

```plaintext
DELETE /groups/:id/security/policy_store/:policy_id
```

Attributs pris en charge :

| Attribut   | Type              | Obligatoire | Description |
| ----------- | ----------------- | -------- | ----------- |
| `id`        | integer or string | Oui      | ID ou [chemin encodé en URL](rest/_index.md#namespaced-paths) du groupe. |
| `policy_id` | Entier           | Oui      | ID de la politique. |

En cas de succès, retourne [`204 No Content`](rest/troubleshooting.md#status-codes).

Exemple de requête :

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/5/security/policy_store/1"
```
