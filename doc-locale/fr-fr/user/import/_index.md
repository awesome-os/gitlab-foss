---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Importation et migration vers GitLab
description: "Migration de dépôt, dépôts tiers et mappage des contributions des utilisateurs."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Importez votre travail existant dans GitLab.

Un outil de migration est disponible pour certaines plateformes tierces. Certaines prennent en charge le [mappage post-migration](mapping/post_migration_mapping.md) des contributions des utilisateurs et des appartenances.

| Migrer depuis                                                                   | Groupes                  | Projets    | Outil de migration | Mappage post-migration |
|:-------------------------------------------------------------------------------|:------------------------|:------------|:---------------|:-----------------------|
| [GitLab (par transfert direct)](../group/import/_index.md)                 | {{< yes >}}             | {{< yes >}} | {{< yes >}}    | {{< yes >}}            |
| [GitLab (par export de fichier)](../project/settings/import_export.md)          | {{< yes >}}[^file-export-deprecated] | {{< yes >}} | {{< yes >}}    | {{< no >}}             |
| [Bitbucket Server](bitbucket_server.md)                                        | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< yes >}}            |
| [GitHub](../project/import/github.md)                                          | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< yes >}}            |
| [Gitea](gitea.md)                                                              | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< yes >}}            |
| [Bitbucket Cloud](bitbucket_cloud.md)                                          | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< no >}}             |
| [FogBugz](third_party_systems/fogbugz.md)                                      | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< no >}}             |
| Dépôt Git via un [fichier manifeste](third_party_systems/manifest_file.md) | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< no >}}             |
| Dépôt Git via une [URL de dépôt](third_party_systems/repo_by_url.md)  | {{< no >}}              | {{< yes >}} | {{< yes >}}    | {{< no >}}             |
| [IBM DevOps ClearCase](third_party_systems/clearcase.md)                       | {{< no >}}              | {{< yes >}} | {{< no >}}     | {{< no >}}             |
| [Concurrent Versions System (CVS)](third_party_systems/cvs.md)                 | {{< no >}}              | {{< yes >}} | {{< no >}}     | {{< no >}}             |
| [Perforce P4](third_party_systems/perforce.md)                                 | {{< no >}}              | {{< yes >}} | {{< no >}}     | {{< no >}}             |
| [Subversion](#migrate-from-subversion)                                         | {{< no >}}              | {{< yes >}} | {{< no >}}     | {{< no >}}             |
| [Team Foundation Version Control (TFVC)](third_party_systems/tfvc.md)          | {{< no >}}              | {{< yes >}} | {{< no >}}     | {{< no >}}             |
| [Jira (tickets uniquement)](third_party_systems/jira.md)                              | {{< no >}}              | {{< no >}}  | {{< yes >}}    | {{< no >}}             |

[^file-export-deprecated]: l'utilisation des exports de fichiers pour la migration de groupes est dépréciée.

## Migrer depuis Subversion {#migrate-from-subversion}

GitLab ne peut pas migrer automatiquement les dépôts Subversion vers Git. Pour convertir des dépôts Subversion en Git, vous pouvez utiliser des outils externes, par exemple :

- [`git svn`](https://git-scm.com/book/en/v2/Git-and-Other-Systems-Migrating-to-Git), pour les dépôts très petits et basiques.
- [`reposurgeon`](http://www.catb.org/~esr/reposurgeon/repository-editing.html), pour les dépôts plus grands et plus complexes.

## Migrer en faisant appel aux Services Professionnels {#migrate-by-engaging-professional-services}

Si vous préférez, vous pouvez faire appel aux Services Professionnels de GitLab pour migrer des groupes et des projets vers GitLab plutôt que de le faire vous-même. Pour plus d'informations, consultez le [catalogue des Services Professionnels](https://about.gitlab.com/services/catalog/).

## Consulter l'historique des imports de projets {#view-project-import-history}

Vous pouvez consulter tous les imports de projets que vous avez créés. Cette liste inclut :

- Les chemins des projets sources si les projets ont été importés depuis des systèmes externes, ou la méthode d'import si des projets GitLab ont été migrés.
- Les chemins des projets de destination.
- La date de début de chaque import.
- Le statut de chaque import.
- Les détails des erreurs si des erreurs se sont produites.

L'historique inclut également les projets créés à partir de :

- Modèles [intégrés](../project/_index.md#create-a-project-from-a-built-in-template).
- Modèles [personnalisés](../project/_index.md#create-a-project-from-a-custom-template).

GitLab utilise [l'import de dépôt par URL](third_party_systems/repo_by_url.md) pour créer un nouveau projet à partir d'un modèle.

Pour consulter l'historique des imports de projets :

1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Importer un projet**.
1. Dans le coin supérieur droit, sélectionnez le lien **Historique**.
1. Si des erreurs surviennent pour un import particulier, sélectionnez **Détails** pour les consulter.

## Import de projets avec des objets LFS {#importing-projects-with-lfs-objects}

Lors de l'import d'un projet contenant des objets LFS, si le projet possède un fichier [`.lfsconfig`](https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-config.adoc) avec un hôte URL (`lfs.url`) différent de l'hôte URL du dépôt, les fichiers LFS ne sont pas téléchargés.

## Sujets connexes {#related-topics}

- [Déplacement des dépôts gérés par GitLab](../../administration/operations/moving_repositories.md).
