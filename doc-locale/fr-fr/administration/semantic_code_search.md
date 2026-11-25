---
stage: AI Platform
group: AI Core Infra
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Administrer et configurer la recherche sémantique de code sur les instances GitLab Self-Managed.
title: Administration de la recherche sémantique de code
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Module d'extension : GitLab Duo Core, GitLab Duo Pro ou GitLab Duo Enterprise
- Offre : GitLab Self-Managed
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/16910) en [version bêta](../policy/development_stages_support.md#beta) dans GitLab 18.7.
- [Ajout](https://gitlab.com/gitlab-org/gitlab/-/work_items/588259) à GitLab Duo Core dans GitLab 18.8.
- [Ajout](https://gitlab.com/gitlab-org/gitlab/-/issues/590394) à GitLab Premium dans GitLab 18.9.

{{< /history >}}

> [!note]
> Pour la documentation utilisateur, consultez [la recherche sémantique de code](../user/gitlab_duo/semantic_code_search.md).

Grâce à la recherche sémantique de code, les fonctionnalités GitLab Duo natives à l'IA peuvent trouver des extraits de code pertinents dans votre dépôt.

## Prérequis {#prerequisites}

- Accès à la [passerelle d'IA GitLab](gitlab_duo/gateway.md) ou à [GitLab Duo Self-Hosted](gitlab_duo_self_hosted/_index.md).
- Fonctionnalités bêta et expérimentales activées [pour l'instance](../user/duo_agent_platform/turn_on_off.md#on-gitlab-self-managed-2).
- [Un stockage vectoriel configuré](#vector-storage) :
  - Elasticsearch 8.0 et versions ultérieures.
  - OpenSearch 2.0 et versions ultérieures.
  - PostgreSQL avec l'extension [`pgvector`](https://github.com/pgvector/pgvector).
- Pour GitLab Duo Self-Hosted, [un modèle d'embedding configuré](#configure-an-embedding-model).

## Stockage vectoriel {#vector-storage}

Il est recommandé d'utiliser Elasticsearch ou OpenSearch pour les dépôts de taille moyenne à grande. Utilisez PostgreSQL avec `pgvector` uniquement pour les configurations comportant quelques petits dépôts. Les performances d'indexation et de requête peuvent être limitées avec `pgvector`.

### Connexion au cluster de recherche avancée {#connect-to-the-advanced-search-cluster}

{{< history >}}

- [Introduction](https://gitlab.com/groups/gitlab-org/-/work_items/18905) dans GitLab 18.7.

{{< /history >}}

Si votre instance GitLab utilise Elasticsearch ou OpenSearch pour la [recherche avancée](../user/search/advanced_search.md), vous pouvez activer la recherche sémantique de code en vous connectant au même cluster :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Rechercher**.
1. Développez **Recherche sémantique**.
1. Pour **Stockage vectoriel**, sélectionnez **Configurer**.
1. Sur la page **Stockage vectoriel**, sous **Cluster de recherche avancée**, sélectionnez **Connecter**.

### Configurer un stockage vectoriel personnalisé {#configure-a-custom-vector-store}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/585318) dans GitLab 19.2.

{{< /history >}}

Pour configurer une connexion à un stockage vectoriel personnalisé :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Rechercher**.
1. Développez **Recherche sémantique**.
1. Pour **Stockage vectoriel**, sélectionnez **Configurer**.
1. Dans la liste déroulante **Adaptateur de recherche**, sélectionnez **Elasticsearch**, **OpenSearch** ou **PostgreSQL**.
1. Renseignez les champs correspondant à votre adaptateur.
1. Sélectionnez **Enregistrer les modifications**.

#### Elasticsearch {#elasticsearch}

| Paramètre      | Description |
|--------------|-------------|
| **URL**      | Liste d'URL séparées par des virgules pour votre cluster Elasticsearch (par exemple, `http://localhost:9200, http://localhost:9201`). |
| **Nom d'utilisateur** | Nom d'utilisateur des serveurs Elasticsearch protégés par un mot de passe. |
| **Mot de passe** | Mot de passe des serveurs Elasticsearch protégés par un mot de passe. |

#### OpenSearch {#opensearch}

| Paramètre      | Description |
|--------------|-------------|
| **URL**      | Liste d'URL séparées par des virgules pour votre cluster OpenSearch (par exemple, `http://localhost:9200, http://localhost:9201`). |
| **Nom d'utilisateur** | Nom d'utilisateur des serveurs OpenSearch protégés par un mot de passe. |
| **Mot de passe** | Mot de passe des serveurs OpenSearch protégés par un mot de passe. |

Pour utiliser AWS OpenSearch Service, sélectionnez **Utiliser le service AWS OpenSearch avec les identifiants IAM** et renseignez les champs :

| Paramètre                   | Description |
|---------------------------|-------------|
| **Région AWS**            | Région AWS de votre domaine OpenSearch. |
| **Clé d'accès AWS**        | ID de clé d'accès AWS. Requis uniquement si vous n'utilisez pas les identifiants d'instance de rôle. |
| **Clé d'accès secrète AWS** | Clé d'accès secrète AWS. Requis uniquement si vous n'utilisez pas les identifiants d'instance de rôle. |
| **ARN de rôle AWS**          | ARN de rôle IAM AWS de l'autorisation `AssumeRole` entre les comptes. |

#### PostgreSQL avec `pgvector` {#postgresql-with-pgvector}

Prérequis :

- Activez l'extension [`pgvector`](https://github.com/pgvector/pgvector) dans votre base de données PostgreSQL :

  ```sql
  CREATE EXTENSION vector;
  ```

| Paramètre      | Description |
|--------------|-------------|
| **Hôte**     | Nom d'hôte du serveur PostgreSQL. |
| **Port**     | Port du serveur PostgreSQL. La valeur par défaut est `5432`. |
| **Base de données** | Nom de la base de données PostgreSQL. |
| **Nom d'utilisateur** | Nom d'utilisateur PostgreSQL. |
| **Mot de passe** | Mot de passe PostgreSQL. |

## Configurer un modèle d'embedding {#configure-an-embedding-model}

Pour configurer un modèle d'embedding :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Rechercher**.
1. Développez **Recherche sémantique**.
1. Pour **Intégrations de code**, sélectionnez **Définir le modèle**. Si vous avez déjà configuré un modèle d'embedding, **Changer de modèle** s'affiche à la place.
1. Sur la page **Intégrations de code pour la recherche sémantique**, sélectionnez le modèle d'embedding, les dimensions d'embedding, la taille de lot pour les requêtes d'embedding et la stratégie de découpage.
1. Sélectionnez **Définir les intégrations**. Si vous avez déjà configuré un modèle d'embedding, **Mettre à jour les intégrations et lancer le processus de remplissage** s'affiche à la place.

> [!warning]
> Lorsque vous modifiez le modèle d'embedding ou les dimensions, un remplissage s'exécute et peut prendre plusieurs heures selon la taille de votre base de code. La recherche sémantique reste disponible pendant ce processus.

### Modèles d'embedding {#embedding-models}

#### Modèles gérés par GitLab {#gitlab-managed-models}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/582638) dans GitLab 19.0 [avec le feature flag](feature_flags/_index.md) `semantic_search_user_model_selection`. Fonctionnalité désactivée par défaut.
- Le feature flag `semantic_search_user_model_selection` a été [supprimé](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/246289) dans GitLab 19.3.

{{< /history >}}

Prérequis :

- Accès à la fois à la [passerelle d'IA GitLab](gitlab_duo/gateway.md) et à [GitLab Duo Self-Hosted](gitlab_duo_self_hosted/_index.md).

Les modèles gérés par GitLab sont proposés sur la [passerelle d'IA GitLab](gitlab_duo/gateway.md). Sélectionnez le modèle `text-embedding-005` fourni par la plateforme Gemini Enterprise Agent.

Pour plus d'informations sur les modèles gérés par GitLab avec une configuration [GitLab Duo Self-Hosted](gitlab_duo_self_hosted/_index.md), consultez la [configuration hybride de la passerelle d'IA et du modèle](gitlab_duo_self_hosted/_index.md#hybrid-ai-gateway-and-model-configuration).

> [!warning]
> GitLab limite les requêtes d'embedding pour l'indexation lorsque vous utilisez des modèles gérés par GitLab. Pour éviter ces limites de débit, configurez un [modèle auto-hébergé](#self-hosted-models).
>
> Si GitLab rend obsolète un modèle que vous avez sélectionné, vous devez vous-même passer à un autre modèle.

#### Modèles auto-hébergés {#self-hosted-models}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/588849) dans GitLab 19.1 [avec un feature flag](feature_flags/_index.md) nommé `semantic_search_user_model_selection`. Fonctionnalité désactivée par défaut.
- Le feature flag `semantic_search_user_model_selection` a été [supprimé](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/246289) dans GitLab 19.3.

{{< /history >}}

Prérequis :

- Accès à [GitLab Duo Self-Hosted](gitlab_duo_self_hosted/_index.md).
- [Modèles et fonctionnalités bêta auto-hébergés activés](gitlab_duo_self_hosted/configure_duo_features.md#turn-on-self-hosted-beta-models-and-features).

Les modèles auto-hébergés sont des modèles d'IA [hébergés sur votre propre infrastructure](gitlab_duo_self_hosted/_index.md).

Pour sélectionner un modèle auto-hébergé :

1. Configurez [GitLab Duo Self-Hosted](gitlab_duo_self_hosted/_index.md).
1. [Ajoutez un modèle auto-hébergé](gitlab_duo_self_hosted/configure_duo_features.md#add-a-self-hosted-model) avec une [famille de modèles d'embedding](gitlab_duo_self_hosted/configure_duo_features.md#embedding-model).

### Taille de lot pour les requêtes d'embedding {#batch-size-for-embedding-requests}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/246635) dans GitLab 19.4.

{{< /history >}}

La taille de lot pour les requêtes d'embedding indique le nombre d'entrées pour chaque requête d'embedding en masse. Maintenez cette valeur dans les limites de l'API en masse de votre modèle d'embedding sélectionné. Si vous laissez ce champ vide, la taille de lot par défaut du modèle d'embedding est utilisée. Si le modèle d'embedding n'a pas de taille de lot par défaut, une valeur de secours de 30 est utilisée à la place.

#### Mettre à jour la taille de lot {#update-batch-size}

Pour mettre à jour la taille de lot sans modifier le modèle d'embedding :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Rechercher**.
1. Développez **Recherche sémantique**.
1. Pour **Intégrations de code**, sélectionnez **Changer de modèle**.
1. Sur la page **Intégrations de code pour la recherche sémantique**, accédez à la section **Mettre à jour la taille de lot pour les requêtes d'embedding**.
1. Saisissez une nouvelle valeur :
   - Pour un modèle d'embedding actif sans remplissage en cours, mettez à jour la taille de lot pour le modèle actuel.
   - Pour un nouveau modèle d'embedding avec un remplissage en cours, mettez à jour la taille de lot pour le prochain modèle.
1. Sélectionnez **Mettre à jour la taille de lot**.

### Stratégie de découpage {#chunking-strategy}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/600201) dans GitLab 19.2 [avec le feature flag](feature_flags/_index.md) `semantic_search_user_model_selection`. Fonctionnalité désactivée par défaut.
- Le feature flag `semantic_search_user_model_selection` a été [supprimé](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/246289) dans GitLab 19.3.

{{< /history >}}

La stratégie de découpage est l'algorithme utilisé pour diviser les fichiers de code en extraits plus petits pour les embeddings. Sélectionnez l'une des stratégies suivantes :

- Octets de code : divise le code en blocs d'octets de taille fixe sans tenir compte de la structure ou de la sémantique du code. La taille de bloc désigne le nombre maximum d'octets par bloc. Utilisez cette stratégie dans les cas suivants :
  - Indexation plus rapide et taille de bloc plus prévisible.
  - Dépôts avec des types de fichiers et des langages variés.
- Code pre-BERT : divise le code en utilisant des limites sémantiques optimisées pour les modèles d'embedding basés sur BERT. La taille de bloc désigne le nombre maximum de tokens par bloc. Utilisez cette stratégie dans les cas suivants :
  - Meilleure qualité de recherche et blocs plus pertinents qui respectent la structure du code.
  - Dépôts avec du code bien structuré.

> [!warning]
> Vous pouvez sélectionner la stratégie de découpage uniquement lors de la première configuration du modèle d'embedding. Pour modifier la stratégie de découpage après le début de l'indexation, vous devez entièrement réindexer l'instance. La prise en charge de la réindexation automatique est proposée dans le [ticket 600200](https://gitlab.com/gitlab-org/gitlab/-/work_items/600200) et le [ticket 602138](https://gitlab.com/gitlab-org/gitlab/-/work_items/602138).

## Vérifier le statut de la recherche sémantique de code {#check-semantic-code-search-status}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/work_items/596795) dans GitLab 19.0.

{{< /history >}}

Pour vérifier le statut de la recherche sémantique de code, notamment le statut d'indexation, les détails de connexion au stockage vectoriel, les statistiques du dépôt et les tailles des files d'attente d'embedding, exécutez cette tâche Rake :

```shell
sudo gitlab-rake gitlab:semantic_search:code:info
```

Pour surveiller le statut en continu, indiquez un intervalle de surveillance en secondes :

```shell
sudo gitlab-rake "gitlab:semantic_search:code:info[5]"
```

Cette tâche actualise la sortie à l'intervalle spécifié. Pour arrêter la tâche, appuyez sur <kbd>Control</kbd>+<kbd>C</kbd>.

## Gérer la file d'attente morte {#manage-the-dead-queue}

Prérequis :

- Un jeton d'accès personnel avec les portées `admin_mode`, `ai_features` et `api`.

Lorsque la génération d'embedding échoue, les éléments passent par une chaîne de files d'attente de nouvelle tentative avec des délais croissants (5 minutes, 30 minutes, 2 heures et 8 heures). Les éléments qui échouent à chaque nouvelle tentative sont déplacés vers la file d'attente morte pour une intervention manuelle. Les éléments qui échouent avec une erreur de limite de débit ne suivent pas la chaîne. Ils retournent dans la première file d'attente de nouvelle tentative et réessaient toutes les 5 minutes jusqu'à ce que la limite de débit soit levée. Ils n'atteignent jamais la file d'attente morte. Vous pouvez vérifier la taille de la file d'attente morte dans la section `Embedding Queues` de la sortie de la [tâche Rake de statut](#check-semantic-code-search-status).

### Vider la file d'attente morte {#clear-the-dead-queue}

Pour supprimer tous les éléments de la file d'attente morte, exécutez cette commande :

```shell
curl --request DELETE \
  --header "PRIVATE-TOKEN: <your_token>" \
  "https://gitlab.example.com/api/v4/admin/active_context/dead_queue"
```

### Rejouer la file d'attente morte {#replay-the-dead-queue}

Pour replacer les éléments de la file d'attente morte dans une file d'attente de traitement pour une nouvelle tentative, utilisez le paramètre `queue` pour spécifier la cible. Les valeurs valides sont `retry_queue`, `second_retry_queue`, `third_retry_queue`, `fourth_retry_queue`, `code` et `code_backfill`.

Pour exécuter à nouveau les éléments dans toute la chaîne de nouvelles tentatives, utilisez `retry_queue` :

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_token>" \
  --data "queue=retry_queue" \
  "https://gitlab.example.com/api/v4/admin/active_context/dead_queue/replay"
```

Pour ajouter des éléments à la file d'attente de code principale, utilisez `code` :

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_token>" \
  --data "queue=code" \
  "https://gitlab.example.com/api/v4/admin/active_context/dead_queue/replay"
```
