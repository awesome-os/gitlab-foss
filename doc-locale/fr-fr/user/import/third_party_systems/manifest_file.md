---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Migrer via un fichier manifeste
description: "Importez des dépôts dans GitLab à l'aide de fichiers manifestes."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Importez des dépôts Git à partir d'un fichier manifeste comme celui utilisé par le [dépôt Android](https://android.googlesource.com/platform/manifest/+/6dc9af1b583e5c6a4ab9c38e3f5646efd8079b7d/default.xml). Utilisez le manifeste pour importer un projet comportant de nombreux dépôts, comme l'Android Open Source Project (AOSP).

## Prérequis {#prerequisites}

- [Source d'importation de manifeste](../../../administration/settings/import_and_export_settings.md#configure-allowed-import-sources) activée. Si elle n'est pas activée, demandez à votre administrateur GitLab de l'activer. La source d'importation de manifeste est activée par défaut sur GitLab.com.
- Le rôle Maintainer ou Owner sur le groupe principal de destination vers lequel effectuer l'importation. Vous pouvez créer un nouveau groupe principal pour l'importation.

## Format du fichier manifeste {#manifest-file-format}

Le fichier manifeste doit être un fichier XML d'une taille maximale de 1 Mo. Le fichier doit contenir :

- Une balise `remote` avec un attribut `review` contenant une URL vers un serveur Git.
- Des balises `project` avec un attribut `name` et `path`.

GitLab construit l'URL du dépôt en combinant l'URL de la balise `remote` avec un nom de projet. L'attribut path est utilisé pour représenter le chemin du projet dans GitLab.

Par exemple :

```xml
<manifest>
  <remote review="https://android.googlesource.com/" />

  <project path="build/make" name="platform/build" />
  <project path="build/blueprint" name="platform/build/blueprint" />
</manifest>
```

Dans cet exemple, GitLab crée les projets suivants :

| GitLab                                            | URL d'importation |
|:--------------------------------------------------|:-----------|
| `https://gitlab.com/<group_name>/build/make`      | <https://android.googlesource.com/platform/build> |
| `https://gitlab.com/<group_name>/build/blueprint` | <https://android.googlesource.com/platform/build/blueprint> |

## Importer les dépôts {#import-the-repositories}

Pour importer des dépôts à l'aide d'un fichier manifeste :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Importer un projet**.
1. Sélectionnez **Fichier manifeste**.
1. Sélectionnez un groupe vers lequel vous souhaitez importer.
1. Choisissez un fichier manifeste au format XML à utiliser.
1. Sélectionnez **Lister les dépôts disponibles**. Vous êtes redirigé vers la page de statut d'importation avec une liste de projets basée sur le fichier manifeste.
1. Pour importer :
   - Tous les projets pour la première fois, sélectionnez **Importer tous les dépôts**.
   - Des projets individuels à nouveau, sélectionnez **Réimporter**. Indiquez un nouveau nom et sélectionnez à nouveau **Réimporter**. La réimportation crée une nouvelle copie du projet source.

## Sujets connexes {#related-topics}

- [Paramètres d'importation et d'exportation](../../../administration/settings/import_and_export_settings.md).
- [Configuration de Sidekiq pour les importations](../../../administration/sidekiq/configuration_for_imports.md).
- [Exécution de plusieurs processus Sidekiq](../../../administration/sidekiq/extra_sidekiq_processes.md).
- [Traitement de classes de jobs spécifiques](../../../administration/sidekiq/processing_specific_job_classes.md).
