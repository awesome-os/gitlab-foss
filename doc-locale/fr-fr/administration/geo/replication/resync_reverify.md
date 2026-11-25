---
stage: GitLab Dedicated
group: Geo
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Resynchroniser et revérifier les données Geo
description: "Resynchronisez et revérifiez manuellement des composants Geo individuels ou plusieurs composants en masse depuis l'interface utilisateur ou la console Rails."
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

La resynchronisation et la revérification sont des actions opérationnelles standard. Vous pouvez les utiliser pour relancer la réplication ou la vérification sans attendre l'intervalle de nouvelle tentative automatique, ou pour récupérer après des échecs de réplication ou de vérification.

Dans la [console Rails](../../operations/rails_console.md#starting-a-rails-console-session) d'un site Geo secondaire, vous pouvez :

- [Resynchroniser et revérifier manuellement des composants individuels](#resync-and-reverify-individual-components)
- [Resynchroniser et revérifier manuellement plusieurs composants](#resync-and-reverify-multiple-components)

## Resynchroniser et revérifier des composants individuels {#resync-and-reverify-individual-components}

Sur le site secondaire, accédez à **Admin** > **Geo** > **Replication** pour forcer une resynchronisation ou une revérification d'éléments individuels.

Toutefois, si cela ne fonctionne pas, vous pouvez effectuer la même action via la console Rails. Les sections suivantes décrivent comment utiliser les commandes internes de l'application dans la [console Rails](../../operations/rails_console.md#starting-a-rails-console-session) pour déclencher la réplication ou la vérification d'enregistrements individuels de manière synchrone ou asynchrone.

### Obtenir une instance de Replicator {#obtaining-a-replicator-instance}

> [!warning]
> Les commandes qui modifient des données peuvent causer des dommages si elles ne sont pas exécutées correctement ou dans les bonnes conditions. Exécutez toujours les commandes dans un environnement de test en premier et disposez d'une instance de sauvegarde prête à être restaurée.

Avant d'effectuer toute opération de synchronisation ou de vérification, vous devez obtenir une instance de Replicator.

Tout d'abord, [démarrez une session de console Rails](../../operations/rails_console.md#starting-a-rails-console-session) sur un site principal ou secondaire, selon ce que vous souhaitez faire.

Site principal :

- Vous pouvez calculer la somme de contrôle d'une ressource

Site secondaire :

- Vous pouvez synchroniser une ressource
- Vous pouvez calculer la somme de contrôle d'une ressource et la vérifier par rapport à la somme de contrôle du site principal

Ensuite, exécutez l'un des extraits de code suivants pour obtenir une instance de Replicator.

#### À partir de l'ID d'un enregistrement de modèle {#given-a-model-records-id}

- Remplacez `123` par l'ID réel.
- Remplacez `Packages::PackageFile` par l'une des [classes de modèle de type de données Geo](#geo-data-type-model-classes).

```ruby
model_record = Packages::PackageFile.find_by(id: 123)
replicator = model_record.replicator
```

#### À partir de l'ID d'un enregistrement de registre {#given-a-registry-records-id}

- Remplacez `432` par l'ID réel. Un enregistrement de registre peut avoir ou non le même ID que l'enregistrement de modèle qu'il suit.
- Remplacez `Geo::PackageFileRegistry` par l'une des [classes de registre Geo](#geo-registry-classes).

Sur un site Geo secondaire :

```ruby
registry_record = Geo::PackageFileRegistry.find_by(id: 432)
replicator = registry_record.replicator
```

#### À partir d'un message d'erreur dans le champ `last_sync_failure` d'un enregistrement de registre {#given-an-error-message-in-a-registry-records-last_sync_failure}

- Remplacez `Geo::PackageFileRegistry` par l'une des [classes de registre Geo](#geo-registry-classes).
- Remplacez `error message here` par le message d'erreur réel.

```ruby
registry = Geo::PackageFileRegistry.find_by("last_sync_failure LIKE '%error message here%'")
replicator = registry.replicator
```

#### À partir d'un message d'erreur dans le champ `verification_failure` d'un enregistrement de registre {#given-an-error-message-in-a-registry-records-verification_failure}

- Remplacez `Geo::PackageFileRegistry` par l'une des [classes de registre Geo](#geo-registry-classes).
- Remplacez `error message here` par le message d'erreur réel.

```ruby
registry = Geo::PackageFileRegistry.find_by("verification_failure LIKE '%error message here%'")
replicator = registry.replicator
```

### Effectuer des opérations avec une instance de Replicator {#performing-operations-with-a-replicator-instance}

Une fois que vous disposez d'une instance de Replicator stockée dans une variable `replicator`, vous pouvez effectuer de nombreuses opérations :

#### Synchronisation dans la console {#sync-in-the-console}

Cet extrait de code fonctionne uniquement sur un site secondaire.

Il exécute le code de synchronisation de manière synchrone dans la console, ce qui vous permet d'observer la durée de synchronisation d'une ressource ou de consulter une trace d'erreur complète.

```ruby
replicator.sync
```

Vous pouvez également rendre le niveau de journalisation de la console plus détaillé que le niveau de journalisation configuré, puis effectuer une synchronisation :

```ruby
Rails.logger.level = :debug
```

#### Somme de contrôle ou vérification dans la console {#checksum-or-verify-in-the-console}

Cet extrait de code fonctionne sur n'importe quel site principal ou secondaire.

Sur un site principal, il calcule la somme de contrôle de la ressource et stocke le résultat dans la base de données GitLab principale. Sur un site secondaire, il calcule la somme de contrôle de la ressource, la compare à la somme de contrôle dans la base de données GitLab principale (générée par le site principal) et stocke le résultat dans la base de données de suivi Geo.

Il exécute le code de calcul de somme de contrôle et de vérification de manière synchrone dans la console, ce qui vous permet d'observer la durée de l'opération ou de consulter une trace d'erreur complète.

```ruby
replicator.verify
```

#### Synchronisation dans un job Sidekiq {#sync-in-a-sidekiq-job}

Cet extrait de code fonctionne uniquement sur un site secondaire.

Il met en file d'attente un job pour que Sidekiq effectue une [synchronisation](#sync-in-the-console) de la ressource.

```ruby
replicator.enqueue_sync
```

#### Vérification dans un job Sidekiq {#verify-in-a-sidekiq-job}

Cet extrait de code fonctionne sur n'importe quel site principal ou secondaire.

Il met en file d'attente un job pour que Sidekiq effectue une [somme de contrôle ou une vérification](#checksum-or-verify-in-the-console) de la ressource.

```ruby
replicator.verify_async
```

#### Obtenir un enregistrement de modèle {#get-a-model-record}

Cet extrait de code fonctionne sur n'importe quel site principal ou secondaire.

```ruby
replicator.model_record
```

#### Obtenir un enregistrement de registre {#get-a-registry-record}

Cet extrait de code fonctionne uniquement sur un site secondaire, car les tables de registre sont stockées dans la base de données de suivi Geo.

```ruby
replicator.registry
```

### Classes de modèle de type de données Geo {#geo-data-type-model-classes}

Un type de données Geo est une classe de données spécifique requise par une ou plusieurs fonctionnalités GitLab pour stocker des données pertinentes, et qui est répliquée par Geo vers les sites secondaires.

- **Types Blob** :
  - `Ci::JobArtifact`
  - `Ci::PipelineArtifact`
  - `Ci::SecureFile`
  - `LfsObject`
  - `MergeRequestDiff`
  - `Packages::PackageFile`
  - `PagesDeployment`
  - `Terraform::StateVersion`
  - `Upload`
  - `DependencyProxy::Manifest`
  - `DependencyProxy::Blob`
- **Types de dépôt Git** :
  - `DesignManagement::Repository`
  - `ProjectRepository`
  - `ProjectWikiRepository`
  - `SnippetRepository`
  - `GroupWikiRepository`
- **Autres types** :
  - `ContainerRepository`

Les principales catégories de classes sont Registry, Model et Replicator. Si vous disposez d'une instance de l'une de ces classes, vous pouvez obtenir les autres. Registry et Model gèrent principalement l'état de la base de données PostgreSQL. Replicator sait comment répliquer ou vérifier les données non-PostgreSQL (fichier/dépôt Git/dépôt de conteneurs).

### Classes de registre Geo {#geo-registry-classes}

Dans le contexte de GitLab Geo, un **enregistrement de registre** désigne les tables de registre dans la base de données de suivi Geo. Chaque enregistrement suit un seul élément réplicable dans la base de données GitLab principale, tel qu'un fichier LFS ou un dépôt Git de projet. Les modèles Rails correspondant aux tables de registre Geo pouvant être interrogées sont :

- **Types Blob** :
  - `Geo::CiSecureFileRegistry`
  - `Geo::DependencyProxyBlobRegistry`
  - `Geo::DependencyProxyManifestRegistry`
  - `Geo::JobArtifactRegistry`
  - `Geo::LfsObjectRegistry`
  - `Geo::MergeRequestDiffRegistry`
  - `Geo::PackageFileRegistry`
  - `Geo::PagesDeploymentRegistry`
  - `Geo::PipelineArtifactRegistry`
  - `Geo::ProjectWikiRepositoryRegistry`
  - `Geo::SnippetRepositoryRegistry`
  - `Geo::TerraformStateVersionRegistry`
  - `Geo::UploadRegistry`
- **Types de dépôt Git** :
  - `Geo::DesignManagementRepositoryRegistry`
  - `Geo::ProjectRepositoryRegistry`
  - `Geo::ProjectWikiRepositoryRegistry`
  - `Geo::SnippetRepositoryRegistry`
  - `Geo::GroupWikiRepositoryRegistry`
- **Autres types** :
  - `Geo::ContainerRepositoryRegistry`

## Resynchroniser et revérifier plusieurs composants {#resync-and-reverify-multiple-components}

Lorsque des ressources de composants échouent à la synchronisation ou à la vérification, vous pouvez déclencher des actions en masse pour relancer la file d'attente de réplication. Ces actions réinitialisent le compteur de nouvelles tentatives et l'heure planifiée à 0, ce qui permet au système de traiter les ressources en échec plus rapidement plutôt que d'attendre jusqu'à 1 heure.

> [!note]
> Ces actions ne traitent pas immédiatement les ressources. Au lieu de cela, elles remettent en file d'attente les jobs d'arrière-plan qui gèrent la synchronisation et la vérification. Le travail de réplication effectif s'exécute de manière asynchrone via le processus de réplication Geo standard.

### Fonctionnement de la resynchronisation et de la revérification {#how-resync-and-reverification-works}

Lorsque vous déclenchez une action de resynchronisation ou de revérification, le système marque les enregistrements correspondants comme `pending`. Les workers d'arrière-plan de resynchronisation et de revérification Geo récupèrent ces enregistrements et les traitent selon la priorité normale de la file d'attente. Ce mécanisme vous permet d'accélérer le traitement des ressources en échec sans bloquer immédiatement l'opération.

> [!note]
> Il n'est pas possible de revérifier un enregistrement qui n'a pas été synchronisé avec succès. Seul un enregistrement synchronisé peut être vérifié.

Il est possible de déclencher des actions en masse depuis l'interface utilisateur ou depuis la console Rails.

### Depuis l'interface utilisateur {#from-the-ui}

Vous pouvez planifier une resynchronisation complète de toutes les ressources d'un composant depuis l'interface utilisateur :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Geo** > **Sites**.
1. Sous **Replication details**, sélectionnez le composant souhaité.

#### Resynchroniser les ressources pour le composant sélectionné {#resync-resources-for-the-selected-component}

1. Sélectionnez **Tout resynchroniser** : cette option réinitialise le statut de tous les enregistrements pour la ressource sélectionnée, qu'ils soient déjà synchronisés ou non.
1. Sélectionnez **Resynchroniser tous les éléments en échec** : cette option réinitialise tous les enregistrements pour lesquels la synchronisation a échoué.

#### Revérifier les ressources pour le composant sélectionné {#reverify-resources-for-the-selected-component}

1. Sélectionnez **Tout revérifier** : cette option réinitialise le statut de tous les enregistrements pour la ressource sélectionnée, qu'ils soient déjà vérifiés ou non.
1. Sélectionnez **Vérifier à nouveau tous les éléments en échec** : cette option réinitialise tous les enregistrements pour lesquels la vérification a échoué, mais dont la synchronisation a réussi.

#### Revérifier un composant sur tous les sites {#reverify-one-component-on-all-sites}

Si les sommes de contrôle du site principal sont remises en question, vous devez faire en sorte que le site principal recalcule les sommes de contrôle. Une « revérification complète » est alors réalisée, car après que chaque somme de contrôle est recalculée sur un site principal, des événements sont générés et propagés vers tous les sites secondaires, les amenant à recalculer leurs sommes de contrôle et à comparer les valeurs. Toute discordance marque le registre comme `sync failed`, ce qui entraîne la planification de nouvelles tentatives de synchronisation.

Vous pouvez recalculer la somme de contrôle du site principal depuis l'interface utilisateur :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Surveillance** > **Gestion des données**.
1. Sélectionnez le composant souhaité dans la liste déroulante.
1. Sélectionnez **Vérifier tout**.

> [!warning]
> **Tout resynchroniser**, **Tout revérifier** et **Vérifier tout** déclenchent une mise à jour de toutes les ressources, qu'elles soient déjà synchronisées ou vérifiées. Cette opération ne doit pas être exécutée lorsqu'il existe des milliers d'éléments d'un type d'objet dans l'instance (par exemple, les artefacts de job CI).

### Depuis la console Rails {#from-the-rails-console}

> [!warning]
> Les commandes qui modifient des données peuvent causer des dommages si elles ne sont pas exécutées correctement ou dans les bonnes conditions. Exécutez toujours les commandes dans un environnement de test en premier et disposez d'une instance de sauvegarde prête à être restaurée.

Les sections suivantes décrivent comment utiliser les commandes internes de l'application dans la [console Rails](../../operations/rails_console.md#starting-a-rails-console-session) pour déclencher la réplication ou la vérification en masse.

#### Synchroniser toutes les ressources d'un composant ayant échoué à la synchronisation {#sync-all-resources-of-one-component-that-failed-to-sync}

Le script suivant :

- Parcourt tous les dépôts en échec.
- Affiche les métadonnées de synchronisation et de vérification Geo, y compris les raisons du dernier échec.
- Tente de resynchroniser le dépôt.
- Signale tout échec et en indique la raison.
- Peut prendre un certain temps pour s'exécuter. Chaque vérification de dépôt doit se terminer avant de renvoyer le résultat. Si votre session expire, prenez des mesures pour permettre au processus de continuer à s'exécuter, par exemple en démarrant une session `screen`, ou en l'exécutant via [Rails runner](../../operations/rails_console.md#using-the-rails-runner) et `nohup`.

Exécutez ce script sur le site Geo secondaire.

```ruby
Geo::ProjectRepositoryRegistry.failed.find_each do |registry|
   begin
     puts "ID: #{registry.id}, Project ID: #{registry.project_id}, Last Sync Failure: '#{registry.last_sync_failure}'"
     registry.replicator.sync
     puts "Sync initiated for registry ID: #{registry.id}"
   rescue => e
     puts "ID: #{registry.id}, Project ID: #{registry.project_id}, Failed: '#{e}'", e.backtrace.join("\n")
   end
end; nil
```

#### Revérifier toutes les ressources dont le calcul de somme de contrôle a échoué sur le site principal {#reverify-all-resources-that-failed-to-checksum-on-the-primary-site}

Le système revérifie automatiquement toutes les ressources dont le calcul de somme de contrôle a échoué sur le site principal, mais il utilise un schéma de recul progressif pour éviter un volume excessif d'échecs.

Vous pouvez également, par exemple après avoir effectué une tentative d'intervention, déclencher manuellement la revérification plus tôt :

1. Connectez-vous en SSH à un nœud Rails GitLab sur le site principal.
1. Ouvrez la [console Rails](../../operations/rails_console.md#starting-a-rails-console-session).
1. En remplaçant `LfsObject` par l'une des [classes de modèle de type de données Geo](#geo-data-type-model-classes), marquez toutes les ressources comme `pending verification` :

   ```ruby
   LfsObject.verification_state_table_class.where(verification_state: 3).each_batch do |relation|
     relation.update_all(verification_state: 0)
   end
   ```
