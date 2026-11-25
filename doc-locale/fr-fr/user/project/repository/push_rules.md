---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Utilisez les règles de poussée pour contrôler le contenu et le format des commits Git acceptés par votre dépôt. Définissez des standards pour les messages de commit et empêchez l'ajout accidentel de secrets ou d'identifiants."
title: Règles de poussée
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les règles de poussée sont des [hooks Git `pre-receive`](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks#:~:text=pre%2Dreceive,with%20the%20push.) que vous pouvez activer dans une interface conviviale. Les règles de poussée vous donnent plus de contrôle sur ce qui peut ou ne peut pas être poussé vers votre dépôt. Bien que GitLab propose des [branches protégées](branches/protected.md), vous pourriez avoir besoin de règles plus spécifiques, telles que :

- L'évaluation du contenu d'un commit.
- La vérification que les messages de commit correspondent aux formats attendus.
- L'application des [règles de nommage des branches](branches/_index.md#name-your-branch).
- L'évaluation des détails des fichiers.
- La prévention de la suppression des tags Git.
- L'obligation d'utiliser des commits signés.

GitLab utilise la [syntaxe RE2](https://github.com/google/re2/wiki/Syntax) pour les expressions régulières dans les règles de poussée. Vous pouvez les tester avec le [testeur d'expressions régulières regex101](https://regex101.com/). Chaque expression régulière est limitée à 511 caractères.

RE2 ne prend pas en charge le format `/pattern/flags`. Pour définir un indicateur, ajoutez-le au début de l'expression. Par exemple, utilisez `(?i)pattern` pour une correspondance de motif insensible à la casse.

Pour les règles de poussée personnalisées, utilisez les [hooks de serveur](../../../administration/server_hooks.md).

> [!note]
> Les règles de poussée sont ignorées lors de la synchronisation des duplications. Lorsque vous [mettez à jour votre duplication](forking_workflow.md#update-your-fork) depuis son projet en amont, les modifications sont appliquées directement sans validation par rapport aux règles de poussée de la duplication.

Les règles de poussée fonctionnent comme des modèles, et non comme des paramètres hérités :

- Les règles de poussée globales servent de modèle pour les nouveaux projets. Lorsque vous créez des règles de poussée globales, elles sont copiées dans tous les projets créés après ce point.
- Les règles de poussée de projet sont des copies indépendantes. Une fois un projet créé, ses règles de poussée ne se mettent pas automatiquement à jour lorsque vous modifiez les règles globales ou de groupe.
- La suppression des règles de poussée d'un projet retire tous les contrôles de règles de poussée du projet. Le projet ne revient pas à l'utilisation des règles globales ou de groupe.

Pour appliquer les règles de poussée globales mises à jour aux projets existants, vous devez [remplacer les règles de poussée globales](#override-global-push-rules-per-project) pour chaque projet individuellement.

> [!note]
> Si vous supprimez les règles de poussée d'un projet, le projet n'a plus aucune règle de poussée. Le projet n'hérite pas automatiquement des règles du groupe ou de l'instance. Pour restaurer les règles de poussée, vous devez les reconfigurer pour le projet.

## Activer les règles de poussée globales {#enable-global-push-rules}

Vous pouvez créer des règles de poussée qui servent de modèle pour tous les nouveaux projets. Vous pouvez remplacer ces règles dans des projets individuels ou des [groupes](#group-push-rules).

Lorsque vous configurez les règles de poussée globales :

- Tous les projets créés après la configuration des règles de poussée globales héritent d'une copie de cette configuration.
- Les projets existants ne sont pas affectés. Pour mettre à jour ces projets manuellement, voir [remplacer les règles de poussée globales par projet](#override-global-push-rules-per-project).
- Les modifications apportées aux règles de poussée globales ne mettent pas à jour les projets qui ont déjà des règles de poussée configurées.

Prérequis :

- Vous devez être administrateur.

Pour créer des règles de poussée globales :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Règles de poussée**.
1. Développez **Règles de poussée**.
1. Définissez la règle souhaitée.
1. Sélectionnez **Enregistrer les règles de poussée**.

## Règles de poussée de groupe {#group-push-rules}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les règles de poussée de groupe permettent aux mainteneurs de groupe de définir des règles de poussée pour les projets nouvellement créés dans le groupe spécifique.

Pour configurer les règles de poussée d'un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Dépôt**.
1. Développez la section **Règles de poussée prédéfinies**.
1. Sélectionnez les paramètres souhaités.
1. Sélectionnez **Enregistrer les règles de poussée**.

Les nouveaux projets héritent des règles de poussée de :

- Le groupe parent le plus proche ayant des règles de poussée définies.
- Les règles de poussée définies pour l'instance entière, si aucun groupe parent n'a de règles de poussée définies.

Seuls les projets héritent des règles de poussée. Les sous-groupes n'héritent pas des règles de poussée des groupes parents. Pour vérifier quelles règles de poussée s'appliquent aux nouveaux projets, créez un projet dans le sous-groupe et vérifiez les règles de poussée du projet.

## Remplacer les règles de poussée globales par projet {#override-global-push-rules-per-project}

Les règles de poussée de projet sont indépendantes des règles de poussée globales. Lorsque vous définissez des règles de poussée pour un projet, ces règles remplacent toutes les règles précédemment configurées pour ce projet.

Pour définir des règles de poussée pour un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Dépôt**.
1. Développez **Règles de poussée**.
1. Définissez la règle souhaitée.
1. Sélectionnez **Enregistrer les règles de poussée**.

Pour qu'un projet corresponde aux nouvelles règles de poussée globales, vous devez configurer les règles de poussée du projet afin qu'elles correspondent aux paramètres globaux. Les projets n'héritent pas automatiquement des modifications apportées aux règles de poussée globales.

## Vérifier les utilisateurs {#verify-users}

Utilisez ces règles pour valider les utilisateurs qui effectuent des commits.

> [!note]
> Ces règles de poussée s'appliquent uniquement aux commits et non aux [tags](tags/_index.md).

- **Rejeter les utilisateurs non vérifiés** : l'adresse e-mail du commiteur doit correspondre à l'une des [adresses e-mail vérifiées](../../profile/_index.md#add-emails-to-your-user-profile) de l'utilisateur ou à son [adresse e-mail de commit privée](../../profile/_index.md#use-an-automatically-generated-private-commit-email).
- **Rejeter les noms d'utilisateurs qui ne correspondent pas** : le nom de l'auteur du commit doit correspondre au nom du compte GitLab de l'utilisateur pour les commits où les adresses e-mail de l'auteur et du commiteur sont identiques. La vérification est ignorée lorsque ces adresses e-mail diffèrent, ce qui se produit lors de workflows tels que le cherry-picking ou le rebasage de commits d'autres contributeurs.

  Cette règle contribue à maintenir la propreté des commits en détectant les mauvaises configurations dans les paramètres Git des utilisateurs, mais ne prévient pas l'usurpation d'identité. Pour la vérification d'identité cryptographique, utilisez plutôt [**Rejeter les validations sans signature**](#require-signed-commits).
- **Vérifier si l'auteur de la validation est un utilisateur de GitLab** : les adresses e-mail de l'auteur et du commiteur du commit doivent toutes deux correspondre aux [adresses e-mail vérifiées](../../profile/_index.md#add-emails-to-your-user-profile) d'un utilisateur GitLab.
- **Adresse de courriel de l'auteur de la validation** : les adresses e-mail de l'auteur et du commiteur doivent toutes deux correspondre à l'expression régulière. Pour autoriser toute adresse e-mail, laissez ce champ vide.

Lorsque vous utilisez des [utilisateurs bots pour les projets](../settings/project_access_tokens.md#bot-users-for-projects) ou des [utilisateurs bots pour les groupes](../../group/settings/group_access_tokens.md#bot-users-for-groups), vous devez ajouter le suffixe d'e-mail généré afin que les jetons de bot puissent effectuer des commits et pousser des modifications.

### Commits signés par GitLab {#commits-signed-by-gitlab}

{{< history >}}

- [Modifié](https://gitlab.com/gitlab-org/gitlab/-/issues/587254) dans GitLab 19.3 pour inclure les commits en miroir.

{{< /history >}}

Les commits [signés par GitLab](signed_commits/web_commits.md) ont une adresse e-mail d'instance comme commiteur, par exemple `noreply@example.com`. Cette adresse n'appartient pas à un utilisateur GitLab. Les règles suivantes ne vérifient pas l'adresse e-mail du commiteur pour ces commits, quelle que soit la manière dont les commits parviennent au projet :

- **Rejeter les utilisateurs non vérifiés**
- **Vérifier si l'auteur de la validation est un utilisateur de GitLab**
- **Adresse de courriel de l'auteur de la validation**

GitLab vérifie plutôt l'adresse e-mail de l'auteur. L'exception est **Rejeter les utilisateurs non vérifiés**, que GitLab ignore pour les commits qui arrivent via un push Git, comme la [mise en miroir de dépôt](mirror/_index.md).

## Valider les messages de commit {#validate-commit-messages}

Utilisez ces règles pour vos messages de commit :

- **Exiger cette expression dans les messages de validation** : les messages doivent correspondre à l'expression. Pour autoriser tout message de commit, laissez ce champ vide. Utilise le mode multiligne, qui peut être désactivé en utilisant `(?-m)`. Quelques exemples de validation :

  - `JIRA\-\d+` exige que chaque commit fasse référence à un ticket Jira, comme `Refactored css. Fixes JIRA-123`.
  - `[[:^punct:]]\b$` rejette un commit si le dernier caractère est un signe de ponctuation. Le caractère de limite de mot (`\b`) prévient les faux négatifs, car Git ajoute un caractère de nouvelle ligne (`\n`) à la fin du message de commit.

  Les messages de commit créés dans l'interface GitLab définissent `\r\n` comme caractère de nouvelle ligne. Utilisez `(\r\n?|\n)` au lieu de `\n` dans votre expression régulière pour qu'elle corresponde correctement.

  Par exemple, pour la description de commit multiligne suivante :

  ```plaintext
  JIRA:
  Description
  ```

  Vous pouvez la valider avec cette expression régulière : `JIRA:(\r\n?|\n)\w+`.

- **Rejeter ces expressions dans les messages de validation** : les messages de commit ne doivent pas correspondre à l'expression. Pour autoriser tout message de commit, laissez ce champ vide. Utilise le mode multiligne, qui peut être désactivé en utilisant `(?-m)`.

## Valider les noms de branches {#validate-branch-names}

Pour valider vos noms de branches, saisissez une expression régulière pour **Nom de la branche**. Pour autoriser tout nom de branche, laissez ce champ vide. Votre [branche par défaut](branches/default.md) est toujours autorisée. Certains formats de noms de branches sont restreints par défaut pour des raisons de sécurité. Les noms comportant 40 caractères hexadécimaux, similaires aux hachages de commits Git, sont interdits.

Quelques exemples de validation :

- Les branches doivent commencer par `JIRA-`.

  ```plaintext
  ^JIRA-
  ```

- Les branches doivent se terminer par `-JIRA`.

  ```plaintext
  -JIRA$
  ```

- Les branches doivent commencer par `feature/`, dans toute combinaison de lettres majuscules et minuscules.

  ```plaintext
  (?i)^feature/
  ```

- Les branches doivent comporter entre `4` et `15` caractères, en acceptant uniquement les lettres minuscules, les chiffres et les tirets.

  ```plaintext
  ^[a-z0-9\\-]{4,15}$
  ```

## Prévenir les conséquences non intentionnelles {#prevent-unintended-consequences}

Utilisez ces règles pour prévenir les conséquences non intentionnelles.

- **Rejeter les validations sans signature** : le commit [doit être signé](signed_commits/_index.md). Cette règle peut bloquer certains commits légitimes [créés dans le Web IDE](#reject-unsigned-commits-and-the-web-ide), et permettre aux [commits non signés créés par GitLab d'apparaître dans l'historique des commits](#require-signed-commits).
- **Ne pas autoriser les utilisateurs à supprimer des tags Git avec `git push`** : les utilisateurs ne peuvent pas utiliser `git push` pour supprimer des tags Git.

## Valider les fichiers {#validate-files}

Utilisez ces règles pour valider les fichiers contenus dans le commit.

- **Empêcher la poussée de fichiers secrets** : les fichiers ne doivent pas contenir de [secrets](#prevent-pushing-secrets-to-the-repository).
- **Noms de fichiers interdits** : les fichiers qui n'existent pas dans le dépôt ne doivent pas correspondre à l'expression régulière. Pour autoriser tous les noms de fichiers, laissez ce champ vide. Voir les [exemples courants](#prohibit-files-by-name).
- **Taille maximale des fichiers** : les fichiers ajoutés ou mis à jour ne doivent pas dépasser cette taille de fichier (en Mo). Pour autoriser les fichiers de toute taille, définissez la valeur à `0`. Les fichiers suivis par Git LFS sont exemptés.

### Empêcher la poussée de secrets vers le dépôt {#prevent-pushing-secrets-to-the-repository}

Ne committez jamais de secrets, tels que des fichiers d'identifiants et des clés SSH privées, dans un système de contrôle de version. Dans GitLab, vous pouvez utiliser une liste prédéfinie de motifs de noms de fichiers pour empêcher les fichiers correspondants d'être poussés vers un dépôt. Les merge requests contenant un fichier correspondant sont bloquées. Cette règle de poussée ne restreint pas les fichiers déjà commités dans le dépôt. Vous devez mettre à jour la configuration des projets existants pour utiliser la règle, en suivant le processus décrit dans [remplacer les règles de poussée globales par projet](#override-global-push-rules-per-project).

Les fichiers bloqués par cette règle sont listés ci-dessous. Pour une liste complète des critères, référez-vous à [`files_denylist.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/checks/files_denylist.yml).

- Blobs d'identifiants AWS CLI :
  - `.aws/credentials`
  - `aws/credentials`
  - `homefolder/aws/credentials`
- Clés SSH RSA privées :
  - `/ssh/id_rsa`
  - `/.ssh/personal_rsa`
  - `/config/server_rsa`
  - `id_rsa`
  - `.id_rsa`
- Clés SSH DSA privées :
  - `/ssh/id_dsa`
  - `/.ssh/personal_dsa`
  - `/config/server_dsa`
  - `id_dsa`
  - `.id_dsa`
- Clés SSH ED25519 privées :
  - `/ssh/id_ed25519`
  - `/.ssh/personal_ed25519`
  - `/config/server_ed25519`
  - `id_ed25519`
  - `.id_ed25519`
- Clés SSH ECDSA privées :
  - `/ssh/id_ecdsa`
  - `/.ssh/personal_ecdsa`
  - `/config/server_ecdsa`
  - `id_ecdsa`
  - `.id_ecdsa`
- Clés SSH ECDSA_SK privées :
  - `/ssh/id_ecdsa_sk`
  - `/.ssh/personal_ecdsa_sk`
  - `/config/server_ecdsa_sk`
  - `id_ecdsa_sk`
  - `.id_ecdsa_sk`
- Clés SSH ED25519_SK privées :
  - `/ssh/id_ed25519_sk`
  - `/.ssh/personal_ed25519_sk`
  - `/config/server_ed25519_sk`
  - `id_ed25519_sk`
  - `.id_ed25519_sk`
- Tout fichier se terminant par ces suffixes :
  - `*.pem`
  - `*.key`
  - `*.history`
  - `*_history`

### Interdire les fichiers par nom {#prohibit-files-by-name}

Dans Git, les noms de fichiers incluent à la fois le nom du fichier et tous les répertoires précédant ce nom. Lorsque vous effectuez un `git push`, chaque nom de fichier dans la poussée est comparé à l'expression régulière dans **Noms de fichiers interdits**.

> [!note]
> Cette fonctionnalité utilise la [syntaxe RE2](https://github.com/google/re2/wiki/Syntax), qui ne prend pas en charge les anticipations positives ou négatives.

L'expression régulière peut :

- Correspondre aux noms de fichiers à n'importe quel emplacement dans votre dépôt.
- Correspondre aux noms de fichiers à des emplacements spécifiques.
- Correspondre à des noms de fichiers partiels.
- Exclure des types de fichiers spécifiques par extension.
- Combiner plusieurs expressions pour exclure plusieurs motifs.

### Exemples d'expressions régulières {#regular-expression-examples}

Ces exemples utilisent des motifs de limite de chaîne d'expression régulière courants :

- `^` : correspond au début d'une chaîne.
- `$` : correspond à la fin d'une chaîne.
- `\.` : correspond à un caractère point littéral. La barre oblique inverse protège le point.
- `\/` : correspond à une barre oblique avant littérale. La barre oblique inverse protège la barre oblique avant.

#### Empêcher des types de fichiers spécifiques {#prevent-specific-file-types}

- Pour empêcher la poussée de fichiers `.exe` vers n'importe quel emplacement dans le dépôt :

  ```plaintext
  \.exe$
  ```

#### Empêcher des fichiers spécifiques {#prevent-specific-files}

- Pour empêcher la poussée d'un fichier de configuration spécifique :

  - À la racine du dépôt :

    ```plaintext
    ^config\.yml$
    ```

  - Dans un répertoire spécifique :

    ```plaintext
    ^directory-name\/config\.yml$
    ```

- À n'importe quel emplacement, cet exemple empêche la poussée de tout fichier nommé `install.exe` :

  ```plaintext
  (^|\/)install\.exe$
  ```

#### Combiner des motifs {#combine-patterns}

Vous pouvez combiner plusieurs motifs en une seule expression. Cet exemple combine toutes les expressions précédentes :

```plaintext
(\.exe|^config\.yml|^directory-name\/config\.yml|(^|\/)install\.exe)$
```

## Exiger des commits signés {#require-signed-commits}

Les [commits signés](signed_commits/_index.md) sont des signatures numériques utilisées pour vérifier l'authenticité et l'intégrité des commits Git. Utilisez la règle de poussée **Rejeter les validations sans signature** pour imposer des commits signés aux contributeurs externes tout en permettant aux commits créés par GitLab de rester non signés.

Lorsque vous activez la règle de poussée **Rejeter les validations sans signature** :

- Les commits poussés depuis l'extérieur de GitLab (avec `git push`) doivent contenir une signature cryptographique valide. Les commits non signés sont rejetés.
- Les commits créés via l'interface GitLab ou l'API sont autorisés même sans signature. Ces commits peuvent provenir du Web IDE, d'actions de merge request et d'opérations API.

> [!warning]
> Étant donné que les commits créés dans GitLab sont exemptés de cette règle, des commits non signés peuvent toujours apparaître dans votre historique de commits, même lorsque la règle est activée. La règle valide uniquement les commits poussés depuis des clients Git externes.
>
> Pour plus d'informations, voir le [ticket 5361](https://gitlab.com/gitlab-org/gitaly/-/issues/5361).

La signature doit être créée avec une méthode de signature prise en charge :

- GPG
- SSH
- X.509

Les commits avec des signatures invalides ou corrompues sont rejetés.

### Activer la règle {#enable-the-rule}

Pour activer la règle de poussée **Rejeter les validations sans signature** :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Dépôt**.
1. Développez **Règles de poussée**.
1. Sélectionnez **Rejeter les validations sans signature**.
1. Sélectionnez **Enregistrer les règles de poussée**.

### Rejeter les commits non signés et le Web IDE {#reject-unsigned-commits-and-the-web-ide}

Si un projet applique la règle de poussée **Rejeter les validations sans signature**, les utilisateurs ne peuvent pas créer de commits via le Web IDE GitLab par défaut.

Pour autoriser les commits via le Web IDE dans un projet appliquant cette règle de poussée, un administrateur GitLab doit désactiver le feature flag `reject_unsigned_commits_by_gitlab` :

```ruby
Feature.disable(:reject_unsigned_commits_by_gitlab)
```

Lorsque ce feature flag est désactivé, les commits créés dans le Web IDE sont autorisés sans signature. Pour plus d'informations, voir [activer ou désactiver la fonctionnalité](../../../administration/feature_flags/_index.md#enable-or-disable-the-feature).

## Rejeter les commits non certifiés DCO {#reject-commits-that-arent-dco-certified}

Les commits signés avec le [Developer Certificate of Origin](https://developercertificate.org/) (DCO) certifient que le contributeur a rédigé, ou a le droit de soumettre, le code contribué dans ce commit. Vous pouvez exiger que tous les commits de votre projet soient conformes au DCO. Cette règle de poussée exige un trailer `Signed-off-by:` dans chaque message de commit et rejette tout commit qui en est dépourvu.

## Sujets connexes {#related-topics}

- [Protéger votre dépôt](protect.md)
- [Hooks de serveur Git](../../../administration/server_hooks.md) (anciennement appelés hooks de serveur), pour créer des règles de poussée personnalisées complexes
- [Commits signés](signed_commits/_index.md)
- [Branches protégées](branches/protected.md)
- [Détection des secrets](../../application_security/secret_detection/_index.md)

## Dépannage {#troubleshooting}

### Mise à jour groupée des règles de poussée pour tous les projets {#bulk-update-push-rules-for-all-projects}

Pour mettre à jour les règles de poussée afin qu'elles soient identiques pour tous les projets, utilisez la [console Rails](../../../administration/operations/rails_console.md#starting-a-rails-console-session) ou rédigez un script pour mettre à jour chaque projet à l'aide du [point de terminaison API des règles de poussée](../../../api/project_push_rules.md).

Par exemple, pour activer les cases à cocher **Vérifier si l'auteur de la validation est un utilisateur de GitLab** et **Ne pas autoriser les utilisateurs à supprimer des tags Git avec `git push`**, et créer un filtre pour n'autoriser que les commits provenant d'un domaine e-mail spécifique via la console Rails :

> [!warning]
> Les commandes qui modifient des données peuvent causer des dommages si elles ne sont pas exécutées correctement ou dans les bonnes conditions. Exécutez toujours les commandes dans un environnement de test en premier et assurez-vous d'avoir une instance de sauvegarde prête à être restaurée.

``` ruby
Project.find_each do |p|
  pr = p.push_rule || PushRule.new(project: p)
  # Check whether the commit author is a GitLab user
  pr.member_check = true
  # Do not allow users to remove Git tags with `git push`
  pr.deny_delete_tag = true
  # Commit author's email
  pr.author_email_regex = '@domain\.com$'
  pr.save!
end
```
