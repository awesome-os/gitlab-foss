---
stage: Verify
group: Pipeline Execution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "API d'équilibrage des tests"
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/607450) dans GitLab 19.4 [avec le feature flag](../administration/feature_flags/_index.md) `parallel_test_balancing`. Fonctionnalité désactivée par défaut.

{{< /history >}}

> [!flag]
> La disponibilité de cette fonctionnalité est contrôlée par un feature flag. Pour plus d'informations, consultez l'historique. Cette fonctionnalité est disponible à des fins de test, mais n'est pas prête pour une utilisation en production.

Utilisez cette API pour distribuer les tests sur les nœuds d'un job CI/CD [`parallel:`](../ci/yaml/_index.md#parallel) en fonction des durées des tests, afin que chaque nœud termine à peu près au même moment.

Une division de test est une unité de travail à distribuer entre les nœuds. Lorsque vous divisez par fichier, chaque division de test correspond à un fichier de test. Les nœuds alimentent un pool partagé en attente avec leur division de test statique, puis demandent de manière répétée des lots de divisions de test à durée budgétée au fur et à mesure qu'ils se terminent. Les nœuds plus rapides absorbent plus de travail. Lorsqu'un nœud est réessayé, il reçoit l'ensemble exact de divisions de test qui lui avait été assigné à l'origine.

Les deux endpoints :

- Doivent être appelés depuis le job parallèle en cours d'exécution, authentifié avec un [jeton de job CI/CD](../ci/jobs/ci_job_token.md) (`CI_JOB_TOKEN`).
- Renvoient `422 Unprocessable Entity` lorsque le job appelant n'utilise pas le mot-clé `parallel:`.
- Renvoient `422 Unprocessable Entity` pour les pipelines créés il y a plus de 7 jours, car les données d'équilibrage des tests, y compris les nouvelles tentatives, sont conservées pendant 7 jours à compter de la création du pipeline.

## Initialiser l'équilibrage des tests pour un job parallèle {#initialize-test-balancing-for-a-parallel-job}

Alimente le pool partagé en attente du groupe de jobs avec la division de test statique de l'appelant et réclame un premier lot de divisions de test. Si le nœud a déjà réclamé des divisions de test (par exemple, lorsqu'un job est réessayé ou récupéré après un plantage), l'ensemble de tests précédemment réclamé est renvoyé inchangé et le paramètre `test_splits` est ignoré.

Cet endpoint renvoie `422 Unprocessable Entity` lorsque l'alimentation ferait dépasser au pool partagé du groupe de jobs 50 000 divisions de test.

```plaintext
POST /job/test_balancing/initialize
```

Attributs pris en charge :

| Attribut                         | Type            | Obligatoire | Description |
|-----------------------------------|-----------------|----------|-------------|
| `test_splits`                     | tableau de hachages | Oui      | Les divisions de test de la division statique assignée à ce nœud. Maximum 1 000 entrées. |
| `test_splits[].path`              | Chaîne          | Oui      | Le chemin de la division de test, relatif à la racine du dépôt. Maximum 1 024 caractères. |
| `test_splits[].expected_duration` | float           | Non       | La durée attendue de la division de test, en secondes. La valeur par défaut est 300 si non renseignée. |

En cas de succès, renvoie [`201 Created`](rest/troubleshooting.md#status-codes) et les attributs de réponse suivants :

| Attribut                         | Type   | Description |
|-----------------------------------|--------|-------------|
| `mode`                            | Chaîne | `seed` lorsque le pool a été alimenté et qu'un premier lot a été réclamé, ou `retry` lorsqu'un ensemble de tests précédemment réclamé a été rejoué. |
| `test_splits`                     | Tableau  | Les divisions de test que le nœud doit exécuter. En cas de `retry`, l'ensemble de tests original complet. |
| `test_splits[].path`              | Chaîne | Le chemin de la division de test, relatif à la racine du dépôt. |
| `test_splits[].expected_duration` | float  | La durée attendue au moment de l'alimentation, en secondes. La valeur par défaut est 300 si non renseignée. |

Exemple de requête :

```shell
curl --request POST \
  --header "JOB-TOKEN: $CI_JOB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"test_splits": [{"path": "spec/models/user_spec.rb", "expected_duration": 12.5}]}' \
  --url "https://gitlab.example.com/api/v4/job/test_balancing/initialize"
```

Exemple de réponse :

```json
{
  "mode": "seed",
  "test_splits": [
    {
      "path": "spec/models/user_spec.rb",
      "expected_duration": 12.5
    }
  ]
}
```

## Demander le prochain lot de tests {#request-the-next-batch-of-tests}

Réclame de manière atomique un lot de divisions de test en attente à durée budgétée pour le nœud appelant, en commençant par le plus lent. Un tableau `test_splits` vide signifie que la file d'attente est épuisée et que le nœud doit arrêter de demander des lots.

Le serveur choisit automatiquement la taille du lot en fonction de la durée totale restante attendue dans le pool partagé. Lorsqu'une grande quantité de durée reste, le serveur renvoie des lots plus grands pour réduire le nombre de requêtes. Au fur et à mesure que le pool se vide, le serveur renvoie des lots plus petits afin que le travail reste équilibré entre les nœuds.

Pour réessayer une requête en toute sécurité, par exemple après un délai d'attente dépassé, envoyez à nouveau les mêmes `run_id` et `seq` :

- Si le serveur a déjà réclamé un lot pour cette requête, il renvoie le même lot au lieu d'en réclamer un nouveau.
- Si le serveur a déjà reçu une requête avec un `seq` plus élevé pour le même `run_id`, il renvoie un tableau `test_splits` vide et ne réclame aucune division de test.

```plaintext
POST /job/test_balancing/request
```

Attributs pris en charge :

| Attribut | Type    | Obligatoire | Description |
|-----------|---------|----------|-------------|
| `run_id`  | Chaîne  | Non       | Un identifiant généré par le client pour le processus qui envoie les requêtes. Utilisez la même valeur pour chaque requête du processus. Obligatoire avec `seq`. Maximum 64 caractères. |
| `seq`     | Entier | Non       | Le numéro de séquence de la requête dans l'exécution. Augmentez la valeur pour chaque nouvelle requête, et réutilisez la valeur uniquement lorsque vous réessayez cette requête. Obligatoire avec `run_id`. Minimum 1. |

En cas de succès, renvoie [`201 Created`](rest/troubleshooting.md#status-codes) et les attributs de réponse suivants :

| Attribut                         | Type   | Description |
|-----------------------------------|--------|-------------|
| `test_splits`                     | Tableau  | Les divisions de test que le nœud doit exécuter. Vide lorsque la file d'attente est épuisée. |
| `test_splits[].path`              | Chaîne | Le chemin de la division de test, relatif à la racine du dépôt. |
| `test_splits[].expected_duration` | float  | La durée attendue au moment de l'alimentation, en secondes. La valeur par défaut est 300 si non renseignée. |

Exemple de requête :

```shell
curl --request POST \
  --header "JOB-TOKEN: $CI_JOB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"run_id": "3f2b8c1e-6d4a-4f0b-9a7e-2c5d8e1f4a6b", "seq": 1}' \
  --url "https://gitlab.example.com/api/v4/job/test_balancing/request"
```

Exemple de réponse :

```json
{
  "test_splits": [
    {
      "path": "spec/features/login_spec.rb",
      "expected_duration": 210.4
    }
  ]
}
```
