---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Éléments migrés lors de l'utilisation du transfert direct"
description: "Éléments de projet et de groupe inclus ou exclus lors de l'utilisation du transfert direct."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

De nombreux éléments sont migrés lors de l'utilisation de la méthode de transfert direct, et certains sont exclus.

> [!note]
> Les réactions emoji qui utilisent des emoji personnalisés ne sont migrées que si un emoji personnalisé portant le même nom existe sur la destination. Les réactions qui font référence à un emoji personnalisé absent de la destination sont ignorées.

## Éléments de groupe migrés {#migrated-group-items}

Les éléments de groupe migrés dépendent de la version de GitLab utilisée sur la destination. Pour déterminer si un élément de groupe spécifique est migré :

1. Consultez le fichier [`groups/stage.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/bulk_imports/groups/stage.rb) pour toutes les éditions et le fichier [`groups/stage.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/ee/bulk_imports/groups/stage.rb) pour Enterprise Edition correspondant à votre version sur la destination. Par exemple, pour la version 15.9 :
   - <https://gitlab.com/gitlab-org/gitlab/-/blob/15-9-stable-ee/lib/bulk_imports/groups/stage.rb> (toutes les éditions).
   - <https://gitlab.com/gitlab-org/gitlab/-/blob/15-9-stable-ee/ee/lib/ee/bulk_imports/groups/stage.rb> (Enterprise Edition).
1. Consultez le fichier [`group/import_export.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/import_export/group/import_export.yml) pour les groupes correspondant à votre version sur la destination. Par exemple, pour la version 15.9 : <https://gitlab.com/gitlab-org/gitlab/-/blob/15-9-stable-ee/lib/gitlab/import_export/group/import_export.yml>.

Tout autre élément de groupe n'est pas migré.

Les éléments de groupe migrés vers l'instance GitLab de destination incluent :

- Badges
- Tableaux
- Listes de tableaux
- Les epics
- Tableaux d'epics
- Listes de tableaux d'epics
- Labels de groupe

  > [!note]
  > Les labels de groupe ne peuvent pas conserver les priorités de label associées lors de l'import. Vous devez à nouveau prioriser ces labels manuellement après avoir migré le projet concerné vers l'instance de destination.

- Jalons de groupe
- Itérations
- Cadences d'itération
- [Membres](direct_transfer_migrations.md#user-membership-mapping)
- Paramètres d'espace de nommage
- Jalons de release
- Sous-groupes
- les importations ;
- les wikis.

### Éléments exclus {#excluded-items}

Certains éléments de groupe sont exclus de la migration parce qu'ils :

- Peuvent contenir des informations sensibles :
  - Variables CI/CD
  - Jetons de déploiement
  - Webhooks
- Ne sont pas pris en charge :
  - Champs personnalisés
  - Paramètres de cadence d'itération
  - Invitations de membres en attente
  - Règles push

De plus, les utilisateurs et les [jetons d'accès personnels](../../profile/personal_access_tokens.md) qu'ils créent sont exclus de la migration.

## Éléments de projet migrés {#migrated-project-items}

{{< history >}}

- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/339941) dans GitLab 15.6.
- Le feature flag `bulk_import_projects` a été [supprimé](https://gitlab.com/gitlab-org/gitlab/-/issues/339941) dans GitLab 15.10.
- Les migrations de projets via l'API ont été [ajoutées](https://gitlab.com/gitlab-org/gitlab/-/issues/390515) dans GitLab 15.11.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/461326) dans GitLab 18.3.

{{< /history >}}

Si vous choisissez de migrer des projets lorsque vous [sélectionnez des groupes à migrer](direct_transfer_migrations.md#select-the-groups-and-projects-to-import), les éléments de projet sont migrés avec les projets.

Les éléments de projet migrés dépendent de la version de GitLab utilisée sur la destination. Pour déterminer si un élément de projet spécifique est migré :

1. Consultez le fichier [`projects/stage.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/bulk_imports/projects/stage.rb) pour toutes les éditions et le fichier [`projects/stage.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/ee/bulk_imports/projects/stage.rb) pour Enterprise Edition correspondant à votre version sur la destination. Par exemple, pour la version 15.9 :
   - <https://gitlab.com/gitlab-org/gitlab/-/blob/15-9-stable-ee/lib/bulk_imports/projects/stage.rb> (toutes les éditions).
   - <https://gitlab.com/gitlab-org/gitlab/-/blob/15-9-stable-ee/ee/lib/ee/bulk_imports/projects/stage.rb> (Enterprise Edition).
1. Consultez le fichier [`project/import_export.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/import_export/project/import_export.yml) pour les projets correspondant à votre version sur la destination. Par exemple, pour la version 15.9 : <https://gitlab.com/gitlab-org/gitlab/-/blob/15-9-stable-ee/lib/gitlab/import_export/project/import_export.yml>.

Tout autre élément de projet n'est pas migré.

Si vous choisissez de ne pas migrer les projets avec les groupes ou si vous souhaitez relancer la migration d'un projet, vous pouvez lancer des migrations de projets uniquement à l'aide de l'[API](../../../api/bulk_imports.md).

Les éléments de projet migrés vers l'instance GitLab de destination incluent :

- Fonctionnalité Auto DevOps
- Badges
- Branches (y compris les branches protégées)

  > [!note]
  > Les branches importées respectent les [paramètres de protection de branche par défaut](../../project/repository/branches/protected.md) du groupe de destination. Ces paramètres peuvent entraîner l'import d'une branche non protégée en tant que branche protégée.

- Pipelines CI
  - Les enregistrements de pipeline et de job, tels que le statut, l'étape et les horodatages, sont migrés. Les job logs et les artefacts de job ne sont pas migrés.

  > [!warning]
  > Les pipelines importés pour les merge requests conservent leur statut source et peuvent satisfaire **Les pipelines doivent réussir** et la [vérification du pipeline de politique de sécurité](../../application_security/policies/pipeline_execution_policies.md#security-policy-pipeline-check) sur l'instance de destination sans être réexécutés. Exécutez un nouveau pipeline sur toutes les merge requests importées avant de les fusionner.

- Commentaires de commit
- Designs
- Merge requests externes
- Les tickets
- Tableaux des tickets
- Labels
- Objets LFS
- [Membres](direct_transfer_migrations.md#user-membership-mapping)
- Les merge requests
- Les jalons
- Historique des pipelines
- Les planifications de pipeline
- Projets
- Fonctionnalités du projet
- Règles push. Lors d'un import, les [règles push de groupe](../../project/repository/push_rules.md#group-push-rules) ont la priorité sur les règles push de projet. Si l'instance source possède des règles push de groupe, aucune règle push de projet n'est importée.
- Les releases
- Preuves de release
- Dépôts
- Paramètres
- les snippets ;
- les importations ;
- Rapports de vulnérabilités

  > [!note]
  > [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/501466) dans GitLab 17.7. Les rapports de vulnérabilités sont migrés sans leur statut. Pour plus d'informations, consultez [le ticket 512859](https://gitlab.com/gitlab-org/gitlab/-/issues/512859). Pour l'erreur `ActiveRecord::RecordNotUnique` lors de la migration des rapports de vulnérabilités, consultez [le ticket 509904](https://gitlab.com/gitlab-org/gitlab/-/issues/509904).

- les wikis.

### Éléments liés aux tickets {#issue-related-items}

Les éléments de projet liés aux tickets qui sont migrés vers l'instance GitLab de destination incluent :

- Commentaires de ticket
- Itérations de ticket
- Événements d'itération de ressource de ticket
- Événements de jalon de ressource de ticket
- Événements d'état de ressource de ticket
- Références d'URL de merge request
- Suivi du temps

### Éléments liés aux merge requests {#merge-request-related-items}

Les éléments de projet liés aux merge requests qui sont migrés vers l'instance GitLab de destination incluent :

- Références d'URL de ticket
- Approbateurs de merge request
- Commentaires de merge request
- Événements de jalon de ressource de merge request
- Événements d'état de ressource de merge request
- Relecteurs de merge request
- Cessionnaires multiples de merge request
- Suivi du temps

### Éléments liés aux paramètres {#setting-related-items}

Les éléments de projet liés aux paramètres qui sont migrés vers l'instance GitLab de destination incluent :

- Avatar
- Politique d'expiration des conteneurs
- Propriétés du projet
- Service Desk

### Éléments exclus {#excluded-items-1}

Certains éléments de projet sont exclus de la migration parce qu'ils :

- Peuvent contenir des informations sensibles :
  - Job logs CI/CD
  - Variables CI/CD
  - Images du registre de conteneurs
  - Clés de déploiement
  - Jetons de déploiement
  - Jetons chiffrés
  - Artefacts de job
  - Variables de planification de pipeline
  - Déclencheurs de pipeline
  - Webhooks
- Ne sont pas pris en charge :
  - Agents
  - [Pipelines CI/CD enfants](https://gitlab.com/gitlab-org/gitlab/-/issues/571159)
  - Registre de conteneurs
  - Champs personnalisés
  - Environnements
  - Feature flags
  - Registre d'infrastructure
  - Administrateurs d'instance dans les règles de protection de branche lors de la migration de GitLab Self-Managed vers GitLab.com ou GitLab Dedicated
  - Tickets liés
  - Règles d'approbation des merge requests
  - Dépendances de merge request
  - Registre de paquets
  - Domaines Pages
  - Invitations de membres en attente
  - Miroirs distants
  - Commentaires wiki

    > [!note]
    > Les règles d'approbation liées aux paramètres du projet sont importées.

- Ne contiennent pas de données récupérables :
  - Merge requests sans diff ni informations source (pour plus d'informations, consultez [le ticket 537943](https://gitlab.com/gitlab-org/gitlab/-/issues/537943))

De plus, les utilisateurs et les [jetons d'accès personnels](../../profile/personal_access_tokens.md) qu'ils créent sont exclus de la migration.
