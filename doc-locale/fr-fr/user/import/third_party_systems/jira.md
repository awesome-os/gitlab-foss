---
stage: Plan
group: Work Items
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>.
title: Migrer depuis Jira
description: Options pour migrer depuis Jira
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Si vous utilisez Jira, vous pouvez soit :

- Démarrer de zéro dans GitLab sans migrer depuis Jira. Vous pouvez alors vous concentrer sur la mise en place de vos processus et workflows afin de tirer pleinement parti de GitLab.
- Migrer depuis Jira vers GitLab en utilisant l'une des options disponibles.

| Option de migration             | Description |
|:-----------------------------|:------------|
| GitLab Professional Services | Confier la migration à [GitLab Professional Services](https://about.gitlab.com/services/). |
| `Jira2Lab`                   | Utiliser [`Jira2Lab`](https://about.gitlab.com/blog/seamlessly-migrate-from-jira-to-gitlab-with-jira2lab-at-scale/), le fork GitLab Professional Services de `jira2gitlab`. |
| Script tiers           | Par exemple, utiliser [`jira2gitlab`](https://github.com/swingbit/jira2gitlab) pour la migration. |
| Importateur Jira                | [Utiliser l'importateur Jira](#use-the-jira-importer) intégré à GitLab. |
| Import de fichier CSV              | [Utiliser un fichier CSV](#use-a-csv-file) pour déplacer des données de Jira vers GitLab. |
| Votre propre script              | [Écrire votre propre script](#write-your-own-script) qui utilise l'API REST ou GraphQL de GitLab. |
| Service tiers          | Utiliser un service tiers qui maintient GitLab et Jira synchronisés, tels que ceux proposés par [Unito](https://marketplace.atlassian.com/apps/1218054/gitlab-2-way-integration-for-jira) et [Getint](https://marketplace.atlassian.com/apps/1223999/gitlab-integration-for-jira-two-way-sync-forge). |

## Utiliser l'importateur Jira {#use-the-jira-importer}

À l'aide de l'importateur Jira, vous pouvez importer vos tickets Jira dans GitLab. Les tickets issus de plusieurs projets Jira peuvent être importés dans un projet GitLab. GitLab importe directement le titre, la description et les labels du ticket. Vous pouvez également mapper les utilisateurs Jira aux membres du projet GitLab lors de la préparation de l'import.

Les autres métadonnées des tickets Jira qui ne sont pas formellement mappées aux champs des tickets GitLab sont importées dans la description du ticket GitLab sous forme de texte brut.

Le texte des tickets Jira n'est pas converti en GitLab Flavored Markdown, ce qui peut entraîner des problèmes de mise en forme du texte. Pour plus d'informations, consultez [le ticket 379104](https://gitlab.com/gitlab-org/gitlab/-/issues/379104).

[L'epic 2738](https://gitlab.com/groups/gitlab-org/-/epics/2738) propose l'ajout des personnes assignées aux tickets, des commentaires et d'autres améliorations à l'importateur Jira de GitLab.

### Prérequis {#prerequisites}

- Accès en lecture aux tickets Jira et rôle Maintainer ou Owner pour le projet GitLab dans lequel vous souhaitez importer.
- Configurer l'[intégration des tickets Jira](../../../integration/jira/_index.md) de GitLab.

### Importer des tickets Jira {#import-jira-issues}

L'import des tickets Jira s'effectue sous la forme d'un job en arrière-plan asynchrone, ce qui peut entraîner des délais en fonction de :

- La charge des files d'attente d'import.
- La charge système.
- D'autres facteurs.

L'import de projets volumineux peut prendre plusieurs minutes selon la taille de l'import.

Pour importer des tickets Jira dans un projet GitLab :

1. Sur la page {{< icon name="work-items" >}} **Éléments de travail**, sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **Importer depuis Jira**.
1. Sélectionnez la liste déroulante **Importer depuis** et sélectionnez le projet Jira à partir duquel vous souhaitez importer des tickets.

   Dans la section **Modèle de correspondances d'utilisateurs Jira-GitLab**, le tableau indique à quels utilisateurs GitLab vos utilisateurs Jira sont mappés. Lorsque le formulaire s'affiche, la liste déroulante est définie par défaut sur l'utilisateur effectuant l'import.

1. Pour modifier l'une des correspondances, sélectionnez la liste déroulante dans la colonne **Nom d'utilisateur GitLab** et sélectionnez l'utilisateur à mapper à chaque utilisateur Jira.

   Il est possible que la liste déroulante n'affiche pas tous les utilisateurs. Utilisez la barre de recherche pour trouver un utilisateur spécifique dans ce projet GitLab.

1. Sélectionnez **Continuer**. Une confirmation indiquant que l'import a démarré s'affiche.

   Pendant que l'import s'exécute en arrière-plan, vous pouvez accéder à la page **Éléments de travail** pour voir les nouveaux tickets (éléments de travail de type ticket) apparaître dans la liste.

1. Pour vérifier le statut de votre import, revenez à la page d'import Jira.

## Utiliser un fichier CSV {#use-a-csv-file}

Pour importer vos données de tickets Jira depuis un fichier CSV dans votre projet GitLab :

1. Exporter vos données Jira :
   1. Connectez-vous à votre instance Jira et accédez au projet que vous souhaitez migrer.
   1. Exportez les données du projet sous forme de fichier CSV.
   1. Modifiez votre fichier CSV pour qu'il corresponde aux [noms de colonnes requis par l'importateur CSV de GitLab](../../project/issues/csv_import.md).
      - Seuls `title`, `description`, `due_date` et `milestone` sont importés.
      - Vous pouvez ajouter des [actions rapides](../../project/quick_actions.md) au champ de description pour définir automatiquement d'autres métadonnées de ticket lors du processus d'import.
1. Créer un nouveau groupe et projet GitLab :
   1. Connectez-vous à votre compte GitLab et [créez un groupe](../../group/_index.md#create-a-group) pour héberger vos projets migrés.
   1. Dans le nouveau groupe, [créez un nouveau projet](../../project/_index.md#create-a-blank-project) pour accueillir les tickets Jira migrés.
1. Importer les données Jira dans GitLab :
   1. Dans votre nouveau projet GitLab, dans la barre latérale gauche, sélectionnez **Forfait** > **Éléments de travail**.
   1. Sélectionnez **Actions** ({{< icon name="ellipsis_v" >}}) > **Importer depuis Jira**.
   1. Suivez les instructions à l'écran pour terminer le processus d'import.
1. Vérifier la migration :
   1. Examinez les tickets importés pour vous assurer que le projet a bien été migré vers GitLab.
   1. Testez les fonctionnalités de votre projet Jira migré dans GitLab.
1. Ajuster vos workflows et paramètres :
   1. Personnalisez les [paramètres de votre projet](../../project/settings/_index.md) GitLab, tels que :
      - [Modèles de description](../../project/description_templates.md).
      - [Labels](../../project/labels.md).
      - [Jalons](../../project/milestones/_index.md).
   1. Familiarisez votre équipe avec l'interface GitLab et les nouveaux workflows ou processus introduits par la migration.
1. Lorsque vous êtes satisfait de la migration, vous pouvez décommissionner votre instance Jira et passer entièrement à GitLab.

## Écrire votre propre script {#write-your-own-script}

Pour un contrôle total sur le processus de migration, vous pouvez écrire votre propre script personnalisé qui migre vos tickets Jira vers GitLab selon vos besoins exacts. GitLab fournit des API pour vous aider à automatiser votre migration :

- [API REST](../../../api/rest/_index.md)
- [API GraphQL](../../../api/graphql/_index.md)

Pour commencer, familiarisez-vous avec les endpoints d'API GitLab suivants :

- [Les tickets](../../../api/issues.md)
- [Projets](../../../api/projects.md)
- [Labels](../../../api/labels.md)
- [Les jalons](../../../api/milestones.md)

Lorsque vous rédigez votre script, vous devez mapper les champs des tickets Jira à leurs équivalents GitLab correspondants.

| Champ du ticket Jira | Équivalent GitLab possible |
|:----|:-------|
| Champs personnalisés avec un nombre fixe d'options | Créez un ensemble de [labels à portée limitée](../../project/labels.md#scoped-labels) avec le nom du champ comme clé de label à portée limitée et les valeurs du champ comme valeurs de l'ensemble de labels à portée limitée. Par exemple, `input name::value1`, `input name::value2`. |
| Champs personnalisés avec des chaînes de texte ou des valeurs entières | Injectez le nom et la valeur du champ personnalisé dans une section de la description du ticket. |
| Statut | Utilisez les [statuts](../../work_items/status.md). |
| Priorité | Créez un [label à portée limitée](../../project/labels.md#scoped-labels) avec la priorité définie comme clé de label à portée limitée et les valeurs de priorité comme valeurs de l'ensemble de labels à portée limitée. Par exemple, `priority::1`. |
| Story Point | Mappez cette valeur à la valeur de **poids** du ticket GitLab. |
| Sprint | Mappez cette valeur à la valeur d'**itération** du ticket GitLab. Cette valeur n'est significative que pour les tickets qui n'ont pas été terminés ou qui sont planifiés pour un sprint futur. Avant d'importer les données, créez les [itérations](../../group/iterations/_index.md#iteration-cadences) requises dans le groupe parent de votre projet. |

Il peut également être nécessaire de gérer l'analyse du format de document Atlassian et de le mapper vers GitLab Flavored Markdown. Vous pouvez aborder cela de nombreuses façons différentes. Pour vous inspirer, [consultez un exemple de commit](https://gitlab.com/gitlab-org/gitlab/-/commit/4292a286d3f4ab26466f8e89125a4dbd194a9f3e). Ce commit a ajouté une méthode pour analyser le format de document Atlassian vers GitLab Flavored Markdown pour l'importateur Jira.

Si vous exécutez GitLab localement, vous pouvez également convertir le format de document Atlassian en GitLab Flavored Markdown manuellement dans la console Rails. Pour ce faire, exécutez :

```ruby
text = <document in Atlassian Document Format>
project = <project that wiki is in> or nil
Banzai.render(text, pipeline: :adf_commonmark, project: project)
```

## Sujets connexes {#related-topics}

- [Paramètres d'import et d'export](../../../administration/settings/import_and_export_settings.md)
- [Configuration Sidekiq pour les imports](../../../administration/sidekiq/configuration_for_imports.md)
- [Exécution de plusieurs processus Sidekiq](../../../administration/sidekiq/extra_sidekiq_processes.md)
- [Traitement de classes de jobs spécifiques](../../../administration/sidekiq/processing_specific_job_classes.md)
