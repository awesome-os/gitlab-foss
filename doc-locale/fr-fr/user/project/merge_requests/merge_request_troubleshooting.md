---
stage: AI Coding
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Aide au dépannage pour les merge requests.
title: Dépannage des merge requests
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous travaillez avec des merge requests, vous pouvez rencontrer les problèmes suivants.

## La merge request ne peut pas récupérer le statut du pipeline {#merge-request-cannot-retrieve-the-pipeline-status}

Cela peut se produire si Sidekiq ne prend pas en compte les modifications assez rapidement.

### Sidekiq {#sidekiq}

Sidekiq n'a pas traité le changement d'état CI assez rapidement. Attendez quelques secondes et le statut devrait se mettre à jour automatiquement.

### Impossible de récupérer le statut du pipeline {#pipeline-status-cannot-be-retrieved}

Les statuts de pipeline de merge request ne peuvent pas être récupérés dans les cas suivants :

1. Une merge request est créée
1. La merge request est fermée
1. Des modifications sont apportées au projet
1. La merge request est rouverte

Pour permettre la récupération correcte du statut du pipeline, fermez puis rouvrez la merge request.

## Rebaser une merge request depuis la console Rails {#rebase-a-merge-request-from-the-rails-console}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate

{{< /details >}}

En plus de la [quick action `/rebase`](../quick_actions.md#ready), les utilisateurs ayant accès à la [console Rails](../../../administration/operations/rails_console.md) peuvent rebaser une merge request depuis la console Rails. Remplacez `<username>`, `<namespace/project>` et `<iid>` par les valeurs appropriées :

> [!warning]
> Toute commande qui modifie des données directement peut être dommageable si elle n'est pas exécutée correctement ou dans les bonnes conditions. Nous recommandons vivement d'exécuter ces commandes dans un environnement de test et de prévoir une sauvegarde de l'instance prête à être restaurée par précaution.

```ruby
u = User.find_by_username('<username>')
p = Project.find_by_full_path('<namespace/project>')
m = p.merge_requests.find_by(iid: <iid>)
MergeRequests::RebaseService.new(project: m.target_project, current_user: u).execute(m)
```

## Corriger le statut incorrect d'une merge request {#fix-incorrect-merge-request-status}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Si une merge request reste à l'état **Ouvrir** après la fusion de ses modifications, les utilisateurs ayant accès à la [console Rails](../../../administration/operations/rails_console.md) peuvent corriger le statut de la merge request. Remplacez `<username>`, `<namespace/project>` et `<iid>` par les valeurs appropriées :

> [!warning]
> Toute commande qui modifie des données directement peut être dommageable si elle n'est pas exécutée correctement ou dans les bonnes conditions. Nous recommandons vivement d'exécuter ces commandes dans un environnement de test et de prévoir une sauvegarde de l'instance prête à être restaurée par précaution.

```ruby
u = User.find_by_username('<username>')
p = Project.find_by_full_path('<namespace/project>')
m = p.merge_requests.find_by(iid: <iid>)
MergeRequests::PostMergeService.new(project: p, current_user: u).execute(m)
```

L'exécution de cette commande sur une merge request comportant des modifications non fusionnées entraîne l'affichage d'un message incorrect dans la merge request : `merged into <branch-name>`.

## Fermer une merge request depuis la console Rails {#close-a-merge-request-from-the-rails-console}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Si la fermeture d'une merge request ne fonctionne pas via l'interface utilisateur ou l'API, essayez de la fermer dans une [session de console Rails](../../../administration/operations/rails_console.md#starting-a-rails-console-session) :

> [!warning]
> Les commandes qui modifient des données peuvent causer des dommages si elles ne sont pas exécutées correctement ou dans les bonnes conditions. Exécutez toujours les commandes dans un environnement de test d'abord et disposez d'une instance de sauvegarde prête à être restaurée.

```ruby
u = User.find_by_username('<username>')
p = Project.find_by_full_path('<namespace/project>')
m = p.merge_requests.find_by(iid: <iid>)
MergeRequests::CloseService.new(project: p, current_user: u).execute(m)
```

## Supprimer une merge request depuis la console Rails {#delete-a-merge-request-from-the-rails-console}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Si la suppression d'une merge request ne fonctionne pas via l'interface utilisateur ou l'API, essayez de la supprimer dans une [session de console Rails](../../../administration/operations/rails_console.md#starting-a-rails-console-session) :

> [!warning]
> Toute commande qui modifie des données directement peut être dommageable si elle n'est pas exécutée correctement ou dans les bonnes conditions. Nous recommandons vivement d'exécuter ces commandes dans un environnement de test et de prévoir une sauvegarde de l'instance prête à être restaurée par précaution.

```ruby
u = User.find_by_username('<username>')
p = Project.find_by_full_path('<namespace/project>')
m = p.merge_requests.find_by(iid: <iid>)
Issuable::DestroyService.new(container: m.project, current_user: u).execute(m)
```

## Échec du hook pre-receive de la merge request {#merge-request-pre-receive-hook-failed}

Si une merge request expire, vous pouvez voir des messages indiquant un problème de timeout du worker Puma :

- Dans l'interface GitLab :

  ```plaintext
  Something went wrong during merge pre-receive hook.
  500 Internal Server Error. Try again.
  ```

- Dans le fichier journal `gitlab-rails/api_json.log` :

  ```plaintext
  Rack::Timeout::RequestTimeoutException
  Request ran for longer than 60000ms
  ```

Cette erreur peut se produire si votre merge request :

- Contient de nombreux diffs.
- Présente un grand nombre de commits de retard par rapport à la branche cible.
- Fait référence à un fichier Git LFS verrouillé.

Les utilisateurs de GitLab Self-Managed peuvent demander à un administrateur d'examiner les journaux du serveur pour déterminer la cause de l'erreur. Les utilisateurs de GitLab.com doivent [contacter le support](https://support.gitlab.com/hc/en-us/articles/11626483177756-GitLab-Support#contact-support) pour obtenir de l'aide.

## Nombre de merge requests en cache {#cached-merge-request-count}

Dans un groupe, la barre latérale affiche le nombre total de merge requests ouvertes. Cette valeur est mise en cache si elle est supérieure à 1 000. La valeur mise en cache est arrondie aux milliers (ou aux millions) et mise à jour toutes les 24 heures.

## Extraire des merge requests localement via la référence `head` {#check-out-merge-requests-locally-through-the-head-ref}

Une merge request contient tout l'historique d'un dépôt, ainsi que les commits supplémentaires ajoutés à la branche associée à la merge request. Voici quelques façons d'extraire une merge request localement.

Vous pouvez extraire une merge request localement même si le projet source est une duplication (même une duplication privée) du projet cible.

Cela repose sur la référence `head` de la merge request (`refs/merge-requests/:iid/head`) disponible pour chaque merge request. Cela permet d'extraire une merge request en utilisant son identifiant plutôt que sa branche.

La référence `head` de la merge request est supprimée 14 jours après la fermeture ou la fusion de la merge request. La merge request n'est alors plus disponible pour une extraction locale depuis la référence `head` de la merge request. La merge request peut toujours être rouverte. Si la branche de la merge request existe, vous pouvez toujours extraire la branche, car elle n'est pas affectée.

### Extraire localement avec `glab` {#check-out-locally-using-glab}

```plaintext
glab mr checkout <merge_request_iid>
```

Plus d'informations sur le [client terminal GitLab](../../../editor_extensions/gitlab_cli/_index.md).

### Extraire localement en ajoutant un alias Git {#check-out-locally-by-adding-a-git-alias}

Ajoutez l'alias suivant à votre `~/.gitconfig` :

```plaintext
[alias]
    mr = !sh -c 'git fetch $1 merge-requests/$2/head:mr-$1-$2 && git checkout mr-$1-$2' -
```

Vous pouvez désormais extraire une merge request particulière depuis n'importe quel dépôt et n'importe quel remote. Par exemple, pour extraire la merge request avec l'ID 5 telle qu'affichée dans GitLab depuis le remote `origin`, exécutez :

```shell
git mr origin 5
```

Cela récupère la merge request dans une branche locale `mr-origin-5` et l'extrait.

### Extraire localement en modifiant `.git/config` pour un dépôt donné {#check-out-locally-by-modifying-gitconfig-for-a-given-repository}

Localisez la section correspondant à votre remote GitLab dans le fichier `.git/config`. Elle ressemble à ceci :

```plaintext
[remote "origin"]
  url = https://gitlab.com/gitlab-org/gitlab-foss.git
  fetch = +refs/heads/*:refs/remotes/origin/*
```

Vous pouvez ouvrir le fichier avec :

```shell
git config -e
```

Ajoutez maintenant la ligne suivante à la section précédente :

```plaintext
fetch = +refs/merge-requests/*/head:refs/remotes/origin/merge-requests/*
```

Au final, elle devrait ressembler à ceci :

```plaintext
[remote "origin"]
  url = https://gitlab.com/gitlab-org/gitlab-foss.git
  fetch = +refs/heads/*:refs/remotes/origin/*
  fetch = +refs/merge-requests/*/head:refs/remotes/origin/merge-requests/*
```

Vous pouvez désormais récupérer toutes les merge requests :

```shell
git fetch origin

...
From https://gitlab.com/gitlab-org/gitlab-foss.git
 * [new ref]         refs/merge-requests/1/head -> origin/merge-requests/1
 * [new ref]         refs/merge-requests/2/head -> origin/merge-requests/2
...
```

Pour extraire une merge request particulière :

```shell
git checkout origin/merge-requests/1
```

Ces commandes peuvent également être exécutées avec le script [`git-mr`](https://gitlab.com/glensc/git-mr).

## Erreur : `source branch <branch_name> does not exist.` alors que la branche existe {#error-source-branch-branch_name-does-not-exist-when-the-branch-exists}

Cette erreur peut se produire si le cache GitLab ne reflète pas l'état réel du dépôt Git. Cela peut se produire si le dossier de données Git est monté avec l'indicateur `noexec`.

Prérequis :

- Vous devez être administrateur.

Pour forcer une mise à jour du cache :

1. Ouvrez la console Rails GitLab avec cette commande :

   ```shell
   sudo gitlab-rails console
   ```

1. Dans la console Rails, exécutez ce script :

   ```ruby
   # Get the project
   project = Project.find_by_full_path('affected/project/path')

   # Check if the affected branch exists in cache (it may return `false`)
   project.repository.branch_names.include?('affected_branch_name')

   # Expire the branches cache
   project.repository.expire_branches_cache

   # Check again if the affected branch exists in cache (this time it should return `true`)
   project.repository.branch_names.include?('affected_branch_name')
   ```

1. Rechargez la merge request.

## Les approbations sont réinitialisées lorsqu'une automatisation approuve une merge request {#approvals-reset-when-automation-approves-a-merge-request}

Si vous automatisez la création de merge requests ou l'envoi de modifications vers celles-ci, vous souhaiterez peut-être créer des approbations automatisées pour ces merge requests. Dans GitLab Premium et Ultimate, par défaut, toutes les approbations sont supprimées [lorsque des commits sont ajoutés à la branche source](approvals/settings.md#remove-all-approvals-when-commits-are-added-to-the-source-branch). Pour éviter ce problème, ajoutez une logique à votre automatisation qui garantit que [les commits sont traités avant l'approbation](../../../api/merge_request_approvals.md#prevent-approval-resets-in-automated-merge-requests) de la merge request.

## Merge request marquée de façon inattendue comme fusionnée {#merge-request-unexpectedly-marked-as-merged}

Si une merge request fusionnée contient une note système `merged manually`, les commits de la branche source ont été fusionnés soit en dehors de l'interface GitLab, soit dans le cadre d'une autre merge request.

### Fusion effectuée en dehors de l'interface GitLab {#merged-outside-the-gitlab-ui}

Lorsque vous utilisez `git merge` pour fusionner une branche directement dans la branche cible en dehors de l'interface utilisateur, GitLab détecte l'opération et marque la merge request comme `merged manually`.

Cela peut se produire lorsque les envois directs vers la branche cible sont autorisés. Pour éviter cette situation, vous pouvez protéger la branche cible et la configurer pour ne pas autoriser les envois directs (**Autorisés à pousser et fusionner** est défini sur **Personne**).

Pour plus d'informations, consultez [protéger une branche](../repository/branches/protected.md#protect-a-branch).

### Fusionné dans le cadre d'une autre merge request {#merged-as-part-of-a-different-merge-request}

La merge request contient des commits qui ont déjà été fusionnés dans le cadre d'une autre merge request. Si cela se produit sur une branche protégée, les commits ont été approuvés avant d'être fusionnés, conformément aux paramètres de la branche protégée.

Pour plus d'informations, consultez [plusieurs branches contenant le même commit](../repository/branches/_index.md#multiple-branches-containing-the-same-commit).

> [!note]
> Dans certains cas, GitLab peut afficher `merged manually` au lieu de `Merged with !<merge_request_id>`. Pour plus d'informations, consultez le [ticket 456426](https://gitlab.com/gitlab-org/gitlab/-/issues/456426).
