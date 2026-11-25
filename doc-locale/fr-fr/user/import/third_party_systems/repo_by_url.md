---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Migrer via une URL Git
description: "Importez des dépôts dans GitLab en utilisant une URL Git."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Importez vos dépôts existants en utilisant l'URL Git. Les imports effectués de cette manière n'incluent pas les tickets GitLab ni les merge requests.

## Prérequis {#prerequisites}

- [Source d'import Dépôt par URL](../../../administration/settings/import_and_export_settings.md#configure-allowed-import-sources) activée. Si elle n'est pas activée, demandez à votre administrateur GitLab de l'activer. La source d'import Dépôt par URL est activée par défaut sur GitLab.com.
- Le rôle Chargé de maintenance ou Propriétaire sur le groupe de destination vers lequel effectuer l'import.
- Si vous importez un dépôt privé, un jeton d'accès pour un accès authentifié au dépôt source peut être requis à la place d'un mot de passe.

## Importer un dépôt via l'interface utilisateur {#import-a-repository-through-the-ui}

Pour importer un dépôt via l'interface utilisateur :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Importer un projet**.
1. Sélectionnez **Dépôt par URL**.
1. Saisissez une **URL du dépôt Git**.
1. Renseignez les champs restants. Un nom d'utilisateur et un mot de passe (ou un jeton d'accès) sont requis pour les imports depuis des dépôts privés.
1. Sélectionnez **Créer le projet**.

Votre projet nouvellement créé s'affiche.

## Importer un dépôt via l'API {#import-a-repository-through-the-api}

Vous pouvez utiliser l'[API Projects](../../../api/projects.md#create-a-project) pour importer un dépôt Git :

```shell
curl --location "https://gitlab.example.com/api/v4/projects/" \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <your-token>' \
--data-raw '{
    "description": "New project description",
    "path": "new_project_path",
    "import_url": "https://username:password@example.com/group/project.git"
}'
```

Certains fournisseurs n'autorisent pas l'utilisation d'un mot de passe et exigent à la place un jeton d'accès.

## Importer un dépôt dont l'import a expiré {#import-a-timed-out-repository}

L'import de dépôts volumineux peut expirer après trois heures. Pour importer un dépôt dont l'import a expiré :

1. Clonez le dépôt :

   ```shell
   git clone --mirror https://example.com/group/project.git
   ```

   L'option `--mirror` garantit que toutes les branches, les tags et les refs sont copiés.

1. Ajoutez le nouveau dépôt distant :

   ```shell
   cd repository.git
   git remote add new-origin https://gitlab.com/group/project.git
   ```

1. Poussez tout vers le nouveau dépôt distant :

   ```shell
   git push --mirror new-origin
   ```

## Sujets connexes {#related-topics}

- [Paramètres d'import et d'export](../../../administration/settings/import_and_export_settings.md).
- [Configuration de Sidekiq pour les imports](../../../administration/sidekiq/configuration_for_imports.md).
- [Exécuter plusieurs processus Sidekiq](../../../administration/sidekiq/extra_sidekiq_processes.md).
- [Traitement de classes de jobs spécifiques](../../../administration/sidekiq/processing_specific_job_classes.md).
