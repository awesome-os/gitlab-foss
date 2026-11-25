---
stage: ModelOps
group: MLOps
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Compatibilité du client MLflow
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/epics/8560) dans GitLab 15.11.
- [Disponible généralement](https://gitlab.com/groups/gitlab-org/-/work_items/9341) dans GitLab 17.8.

{{< /history >}}

[MLflow](https://mlflow.org/) est un outil open source populaire pour le suivi des expériences de Machine Learning. GitLab [Model experiment tracking](_index.md) et le [registre de modèles](../model_registry/_index.md) GitLab sont compatibles avec le client MLflow. La configuration nécessite des modifications minimales du code existant.

## Activer l'intégration du client MLflow {#enable-mlflow-client-integration}

Prérequis :

- Un client Python compatible avec GitLab :
  - Recommandé : le [client Python GitLab MLOps](https://gitlab.com/gitlab-org/modelops/mlops/gitlab-mlops).
  - Une autre option est la version du client MLflow. Le client MLflow est [compatible avec GitLab](https://gitlab.com/gitlab-org/modelops/mlops/mlflow-compatibility-qa).
- Un jeton d'accès [personnel](../../../profile/personal_access_tokens.md), [de projet](../../settings/project_access_tokens.md) ou [de groupe](../../../group/settings/group_access_tokens.md) avec le rôle Developer, Maintainer ou Owner et la portée `api`.
- L'ID du projet. Pour trouver l'ID du projet :
  1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
  1. Sélectionnez **Paramètres** > **Généralités**.

Pour utiliser la compatibilité du client MLflow depuis un environnement local :

1. Définissez l'URI de suivi et les variables d'environnement du jeton sur l'hôte qui exécute le code. Il peut s'agir de votre environnement local, d'un pipeline CI ou d'un hôte distant. Par exemple :

   ```shell
   export MLFLOW_TRACKING_URI="<your gitlab endpoint>/api/v4/projects/<your project id>/ml/mlflow"
   export MLFLOW_TRACKING_TOKEN="<your_access_token>"
   ```

1. Si le code d'entraînement contient l'appel à `mlflow.set_tracking_uri()`, supprimez-le.

Dans le registre de modèles, vous pouvez copier l'URI de suivi depuis le menu contextuel en haut à droite en sélectionnant l'ellipse verticale ({{< icon name="ellipsis_v" >}}).

## Expériences de modèles {#model-experiments}

Lorsque vous exécutez le code d'entraînement, vous pouvez utiliser le client MLflow pour créer des expériences, des runs, des modèles et des versions de modèles. Vous pouvez également l'utiliser pour consigner des paramètres, des métriques, des métadonnées et des artefacts dans GitLab.

Une fois les expériences consignées, elles sont répertoriées sous `/<your project>/-/ml/experiments`.

Les runs sont enregistrés et peuvent être explorés en sélectionnant une expérience, un modèle ou une version de modèle.

### Créer une expérience {#creating-an-experiment}

```python
import mlflow

# Create a new experiment
experiment_id = mlflow.create_experiment(name="<your_experiment>")

# Setting the active experiment also creates a new experiment if it doesn't exist.
mlflow.set_experiment(experiment_name="<your_experiment>")
```

### Créer un run {#creating-a-run}

```python
import mlflow

# Creating a run requires an experiment ID or an active experiment
mlflow.set_experiment(experiment_name="<your_experiment>")

# Runs can be created with or without a context manager
with mlflow.start_run() as run:
    print(run.info.run_id)
    # Your training code

with mlflow.start_run():
    # Your training code
```

### Consigner des paramètres et des métriques {#logging-parameters-and-metrics}

```python
import mlflow

mlflow.set_experiment(experiment_name="<your_experiment>")

with mlflow.start_run():
    # Parameter keys need to be unique in the scope of the run
    mlflow.log_param(key="param_1", value=1)

    # Metrics can be updated throughout the run
    mlflow.log_metric(key="metrics_1", value=1)
    mlflow.log_metric(key="metrics_1", value=2)
```

### Consigner des artefacts {#logging-artifacts}

```python
import mlflow

mlflow.set_experiment(experiment_name="<your_experiment>")

with mlflow.start_run():
    # Plaintext text files can be logged as artifacts using `log_text`
    mlflow.log_text('Hello, World!', artifact_file='hello.txt')

    mlflow.log_artifact(
        local_path='<local/path/to/file.txt>',
        artifact_path='<optional relative path to log the artifact at>'
    )
```

### Consigner des modèles {#logging-models}

Les modèles peuvent être consignés à l'aide de l'un des [types de modèles MLflow](https://mlflow.org/docs/latest/models.html#built-in-model-flavors) pris en charge. La consignation avec un type de modèle enregistre les métadonnées, ce qui facilite la gestion, le chargement et le déploiement des modèles dans différents outils et environnements.

```python
import mlflow
from sklearn.ensemble import RandomForestClassifier

mlflow.set_experiment(experiment_name="<your_experiment>")

with mlflow.start_run():
    # Create and train a simple model
    model = RandomForestClassifier(n_estimators=10, random_state=42)
    model.fit(X_train, y_train)

    # Log the model using MLflow sklearn model flavor
    mlflow.sklearn.log_model(model, artifact_path="")
```

### Charger un run {#loading-a-run}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/509595) dans GitLab 17.9.

{{< /history >}}

Vous pouvez charger un run depuis le registre de modèles GitLab pour, par exemple, effectuer des prédictions.

```python
import mlflow
import mlflow.pyfunc

run_id = "<your_run_id>"
download_path = "models"  # Local folder to download to

mlflow.pyfunc.load_model(f"runs:/{run_id}/", dst_path=download_path)

sample_input = [[1,0,3,4],[2,0,1,2]]
model.predict(data=sample_input)
```

### Associer un run à un job CI/CD {#associating-a-run-to-a-cicd-job}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/119454) dans GitLab 16.1.
- [Modifié](https://gitlab.com/groups/gitlab-org/-/work_items/9423) en version bêta dans GitLab 17.1.

{{< /history >}}

Si votre code d'entraînement est exécuté depuis un job CI/CD, GitLab peut utiliser ces informations pour enrichir les métadonnées du run. Pour associer un run à un job CI/CD :

1. Dans les [variables CI du projet](../../../../ci/variables/_index.md), incluez les variables suivantes :
   - `MLFLOW_TRACKING_URI` : `"<your gitlab endpoint>/api/v4/projects/<your project id>/ml/mlflow"`
   - `MLFLOW_TRACKING_TOKEN` : `<your_access_token>`

1. Dans votre code d'entraînement, au sein du contexte d'exécution du run, ajoutez l'extrait de code suivant :

   ```python
   import os
   import mlflow

   with mlflow.start_run(run_name=f"Run {index}"):
     # Your training code

     # Start of snippet to be included
     if os.getenv('GITLAB_CI'):
       mlflow.set_tag('gitlab.CI_JOB_ID', os.getenv('CI_JOB_ID'))
     # End of snippet to be included
   ```

## Registre de modèles {#model-registry}

Vous pouvez également gérer les modèles et les versions de modèles à l'aide du client MLflow. Les modèles sont enregistrés sous `/<your project>/-/ml/models`.

### Modèles {#models}

#### Créer un modèle {#creating-a-model}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
description = 'Model description'
model = client.create_registered_model(model_name, description=description)
```

**Remarques**

- L'argument `create_registered_model` `tags` est ignoré.
- `name` doit être unique au sein du projet.
- `name` ne peut pas être le nom d'une expérience existante.

#### Récupérer un modèle {#fetching-a-model}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
model = client.get_registered_model(model_name)
```

#### Mettre à jour un modèle {#updating-a-model}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
description = 'New description'
client.update_registered_model(model_name, description=description)
```

#### Supprimer un modèle {#deleting-a-model}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
client.delete_registered_model(model_name)
```

### Consigner des runs dans un modèle {#logging-runs-to-a-model}

Chaque modèle est associé à une expérience portant le même nom, préfixé par `[model]`. Pour consigner un run dans le modèle, utilisez l'expérience en transmettant le nom correct :

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
exp = client.get_experiment_by_name(f"[model]{model_name}")
run = client.create_run(exp.experiment_id)
```

### Version de modèle {#model-version}

#### Créer une version de modèle {#creating-a-model-version}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
description = 'Model version description'
model_version = client.create_model_version(model_name, source="", description=description)
```

Si le paramètre de version n'est pas transmis, il sera automatiquement incrémenté à partir de la dernière version téléchargée. Vous pouvez définir la version en transmettant un tag lors de la création de la version de modèle. La version doit respecter le format [SemVer](https://semver.org/).

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version>'
tags = { "gitlab.version": version }
client.create_model_version(model_name, version, description=description, tags=tags)
```

**Remarques**

- L'argument `run_id` est ignoré. Chaque version de modèle se comporte comme un run. La création d'une version de modèle à partir d'un run n'est pas encore prise en charge.
- L'argument `source` est ignoré. GitLab crée un emplacement de package pour les fichiers de la version de modèle.
- L'argument `run_link` est ignoré.
- L'argument `await_creation_for` est ignoré.

#### Mettre à jour un modèle {#updating-a-model-1}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version>'
description = 'New description'
client.update_model_version(model_name, version, description=description)
```

#### Récupérer une version de modèle {#fetching-a-model-version}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version>'
client.get_model_version(model_name, version)
```

#### Obtenir les dernières versions d'un modèle {#getting-latest-versions-of-a-model}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
client.get_latest_versions(model_name)
```

**Remarques**

- L'argument `stages` est ignoré.
- Les versions sont classées par version sémantique décroissante.

#### Charger une version de modèle {#loading-a-model-version}

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version'  # for example: '1.0.0'

# Alternatively search the version
version = mlflow.search_registered_models(filter_string="name='{model_name}'")[0].latest_versions[0].version

model = mlflow.pyfunc.load_model(f"models:/{model_name}/{latest_version}")

# Or load the latest version
model = mlflow.pyfunc.load_model(f"models:/{model_name}/latest")
```

#### Consigner des métriques et des paramètres dans une version de modèle {#logging-metrics-and-parameters-to-a-model-version}

Chaque version de modèle est également un run, ce qui permet aux utilisateurs de consigner des paramètres et des métriques. L'ID du run est accessible depuis la page de la version de modèle dans GitLab ou via le client MLflow :

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version>'
model_version = client.get_model_version(model_name, version)
run_id = model_version.run_id

# Your training code

client.log_metric(run_id, '<metric_name>', '<metric_value>')
client.log_param(run_id, '<param_name>', '<param_value>')
client.log_batch(run_id, metric_list, param_list, tag_list)
```

Étant donné que chaque fichier est limité à 5 Go, vous devez partitionner les modèles plus volumineux.

#### Consigner des artefacts dans une version de modèle {#logging-artifacts-to-a-model-version}

GitLab crée un package que le client MLflow peut utiliser pour télécharger des fichiers.

```python
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version>'
model_version = client.get_model_version(model_name, version)
run_id = model_version.run_id

# Your training code

client.log_artifact(run_id, '<local/path/to/file.txt>', artifact_path="")
client.log_figure(run_id, figure, artifact_file="my_plot.png")
client.log_dict(run_id, my_dict, artifact_file="my_dict.json")
client.log_image(run_id, image, artifact_file="image.png")
```

Les artefacts seront alors disponibles sous `https://<your project>/-/ml/models/<model_id>/versions/<version_id>`.

#### Lier une version de modèle à un job CI/CD {#linking-a-model-version-to-a-cicd-job}

Comme pour les runs, il est également possible de lier une version de modèle à un job CI/CD :

```python
import os
from mlflow import MlflowClient

client = MlflowClient()
model_name = '<your_model_name>'
version = '<your_version>'
model_version = client.get_model_version(model_name, version)
run_id = model_version.run_id

# Your training code

if os.getenv('GITLAB_CI'):
    client.set_tag(model_version.run_id, 'gitlab.CI_JOB_ID', os.getenv('CI_JOB_ID'))
```

## Méthodes du client MLflow prises en charge et mises en garde {#supported-mlflow-client-methods-and-caveats}

GitLab prend en charge les méthodes suivantes du client MLflow. Pour plus d'informations, consultez la [documentation MLflow](https://mlflow.org/docs/latest/index.html). Les équivalents MlflowClient des méthodes ci-dessous sont également pris en charge avec les mêmes mises en garde.

| Méthode                   | Pris en charge       | Version ajoutée | Commentaires                                                                                     |
|--------------------------|-----------------|---------------|----------------------------------------------------------------------------------------------|
| `create_experiment`      | Oui             | 15.11         |                                                                                              |
| `get_experiment`         | Oui             | 15.11         |                                                                                              |
| `get_experiment_by_name` | Oui             | 15.11         |                                                                                              |
| `delete_experiment`      | Oui             | 17.5          |                                                                                              |
| `set_experiment`         | Oui             | 15.11         |                                                                                              |
| `get_run`                | Oui             | 15.11         |                                                                                              |
| `delete_run`             | Oui             | 17.5          |                                                                                              |
| `start_run`              | Oui             | 15.11         | (16.3) Si aucun nom n'est fourni, le run reçoit un pseudonyme aléatoire.                        |
| `search_runs`            | Oui             | 15.11         | (16.4) `experiment_ids` ne prend en charge qu'un seul ID d'expérience avec tri par colonne ou par métrique. |
| `log_artifact`           | Oui, avec mise en garde | 15.11         | (15.11) `artifact_path` doit être vide. Ne prend pas en charge les répertoires.                         |
| `log_artifacts`          | Oui, avec mise en garde | 15.11         | (15.11) `artifact_path` doit être vide. Ne prend pas en charge les répertoires.                         |
| `log_batch`              | Oui             | 15.11         |                                                                                              |
| `log_metric`             | Oui             | 15.11         |                                                                                              |
| `log_metrics`            | Oui             | 15.11         |                                                                                              |
| `log_param`              | Oui             | 15.11         |                                                                                              |
| `log_params`             | Oui             | 15.11         |                                                                                              |
| `log_figure`             | Oui             | 15.11         |                                                                                              |
| `log_image`              | Oui             | 15.11         |                                                                                              |
| `log_text`               | Oui, avec mise en garde | 15.11         | (15.11) Ne prend pas en charge les répertoires.                                                        |
| `log_dict`               | Oui, avec mise en garde | 15.11         | (15.11) Ne prend pas en charge les répertoires.                                                        |
| `set_tag`                | Oui             | 15.11         |                                                                                              |
| `set_tags`               | Oui             | 15.11         |                                                                                              |
| `set_terminated`         | Oui             | 15.11         |                                                                                              |
| `end_run`                | Oui             | 15.11         |                                                                                              |
| `update_run`             | Oui             | 15.11         |                                                                                              |
| `log_model`              | Partiel         | 15.11         | (15.11) Enregistre les artefacts, mais pas les données du modèle. `artifact_path` doit être vide.          |
| `load_model`             | Oui             | 17.5          |                                                                                              |
| `download_artifacts`     | Oui             | 17.9          |                                                                                              |
| `list_artifacts`         | Oui             | 17.9          |                                                                                              |

Autres méthodes MlflowClient :

| Méthode                    | Pris en charge        | Version ajoutée | Commentaires                                         |
|---------------------------|------------------|---------------|--------------------------------------------------|
| `create_registered_model` | Oui, avec mises en garde | 16.8          | [Voir les notes](#creating-a-model)                   |
| `get_registered_model`    | Oui              | 16.8          |                                                  |
| `delete_registered_model` | Oui              | 16.8          |                                                  |
| `update_registered_model` | Oui              | 16.8          |                                                  |
| `create_model_version`    | Oui, avec mises en garde | 16.8          | [Voir les notes](#creating-a-model-version)           |
| `get_model_version`       | Oui              | 16.8          |                                                  |
| `get_latest_versions`     | Oui, avec mises en garde | 16.8          | [Voir les notes](#getting-latest-versions-of-a-model) |
| `update_model_version`    | Oui              | 16.8          |                                                  |
| `create_registered_model` | Oui              | 16.8          |                                                  |
| `create_registered_model` | Oui              | 16.8          |                                                  |

## Problèmes connus {#known-issues}

- Les méthodes du client MLflow non répertoriées dans les [méthodes prises en charge](#supported-mlflow-client-methods-and-caveats) peuvent tout de même fonctionner, mais n'ont pas été testées.
- Lors de la création d'expériences et de runs, les ExperimentTags sont stockés, même s'ils ne sont pas affichés.
