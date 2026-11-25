---
stage: GitLab Dedicated
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Migrer depuis Team Foundation Version Control
description: "Migrer depuis Team Foundation Version Control vers Git."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

[Team Foundation Version Control](https://learn.microsoft.com/en-us/azure/devops/repos/tfvc/what-is-tfvc?view=azure-devops) (TFVC) est un système de contrôle de version centralisé similaire à Git.

Les principales différences entre TFVC et Git sont les suivantes :

- Tandis que TFVC est centralisé et repose sur une architecture client-serveur, Git est distribué. Git offre un workflow plus flexible, car vous travaillez avec une copie de l'ensemble du dépôt. Vous pouvez, par exemple, changer rapidement de branche ou effectuer des fusions sans avoir à communiquer avec un serveur distant.
- Dans un système de contrôle de version centralisé, les modifications sont effectuées par fichier (ensemble de modifications), tandis que dans Git, un fichier commité est stocké dans son intégralité (snapshot).

Pour plus d'informations, consultez :

- La [comparaison de Git et TFVC](https://learn.microsoft.com/en-us/azure/devops/repos/tfvc/comparison-git-tfvc?view=azure-devops) par Microsoft.
- La [comparaison des logiciels de contrôle de version](https://en.wikipedia.org/wiki/Comparison_of_version_control_software) sur Wikipédia.

## Migrer vers Git {#migrate-to-git}

Nous ne fournissons pas d'outil pour migrer depuis TFVC vers Git. Pour obtenir des informations sur la migration :

- Si vous effectuez une migration sur Microsoft Windows, consultez :
  - L'outil [`git-tfs`](https://github.com/git-tfs/git-tfs).
  - Ces [informations sur la migration de TFS vers Git](https://github.com/git-tfs/git-tfs/blob/master/doc/usecases/migrate_tfs_to_git.md).
- Si vous utilisez un système Unix, consultez cet [outil de migration de TFVC vers Git](https://github.com/turbo/gtfotfs).
