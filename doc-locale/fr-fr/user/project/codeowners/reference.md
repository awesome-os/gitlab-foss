---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Découvrez les patterns de chemins de fichiers, les propriétaires, les commentaires, les sections et la manière dont les règles sont évaluées."
title: Syntaxe du fichier `CODEOWNERS`
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Le fichier `CODEOWNERS` utilise une syntaxe pour définir les règles de propriété. Chaque ligne du fichier représente une règle et spécifie un pattern de chemin de fichier ainsi qu'un ou plusieurs propriétaires. Les éléments clés sont :

- Chemins de fichiers : fichiers spécifiques, répertoires ou caractères génériques.
- Propriétaires du code : utilisez des mentions pour les utilisateurs, les groupes ou les rôles.
- Commentaires : les lignes commençant par `#` sont ignorées. Les commentaires en ligne ne sont pas pris en charge. Tout propriétaire du code répertorié dans un commentaire est analysé.
- Sections : regroupements facultatifs de règles, définis à l'aide de `[Section name]`.

> [!note]
> Si une entrée est dupliquée dans une section, [la dernière entrée est utilisée](advanced.md#define-code-owners-for-specific-files-or-directories). Les règles définies plus loin dans le fichier ont la priorité sur les règles antérieures.

Voici quelques exemples :

```plaintext
# Specify a default Code Owner for all files with a wildcard:
* @default-owner

# Specify multiple Code Owners to a specific file:
README.md @doc-team @tech-lead

# Specify a Code Owner to all files with a specific extension:
*.rb @ruby-owner

# Specify Code Owners with usernames or email addresses:
LICENSE @legal janedoe@gitlab.com

# Use group names to match groups and nested groups:
README @group @group/with-nested/subgroup

# Specify a Code Owner to a directory and all its contents:
/docs/ @all-docs
/docs/* @root-docs
/docs/**/*.md @markdown-docs  # Match specific file types in any subdirectory
/db/**/index.md @index-docs   # Match a specific file name in any subdirectory

# Use a section to group related rules:
[Documentation]
ee/docs    @docs
docs       @docs

# Assign a role as a Code Owner:
/config/ @@maintainer
```

## Sections {#sections}

Dans un fichier `CODEOWNERS`, les sections sont des zones nommées qui sont analysées séparément et toujours appliquées. Tant que vous ne définissez pas de section, GitLab traite l'intégralité de votre fichier `CODEOWNERS` comme une section unique. L'ajout de sections supplémentaires modifie la façon dont GitLab évalue le fichier :

- GitLab traite les [entrées sans sections](advanced.md#regular-entries-and-sections), y compris les règles définies avant le premier en-tête de section, comme s'il s'agissait d'une autre section sans nom.
- Chaque section applique ses règles séparément.
- Lorsqu'un chemin de fichier correspond à plusieurs entrées dans une section, seule la dernière entrée correspondante de cette section est utilisée.
- Lorsqu'un chemin de fichier correspond à des entrées dans plusieurs sections, la dernière entrée correspondante de chaque section est utilisée.

Par exemple, dans un fichier `CODEOWNERS` avec des sections qui définissent les propriétaires du code d'un fichier `README` :

```plaintext
* @admin

[README Owners]
README.md @user1 @user2
internal/README.md @user4

[README other owners]
README.md @user3
```

- Les propriétaires du code pour le fichier `README.md` dans le répertoire racine sont :
  - `@admin`, depuis la section sans nom.
  - `@user1` et `@user2`, depuis `[README Owners]`.
  - `@user3`, depuis `[README other owners]`.
- Les propriétaires du code pour `internal/README.md` sont :
  - `@admin`, depuis la section sans nom.
  - `@user4`, depuis `[README Owners]`. Les entrées `README.md` et `internal/README.md` dans cette section correspondent toutes les deux au fichier, mais seule la dernière entrée correspondante de la section est utilisée.
  - `@user3` depuis `[README other owners]`.

Pour ajouter une section au fichier `CODEOWNERS`, saisissez un nom de section entre crochets, suivi des fichiers ou répertoires, et des utilisateurs, groupes ou sous-groupes :

```plaintext
[README Owners]
README.md @user1 @user2
internal/README.md @user2
```

Chaque propriétaire du code dans le widget de merge request est répertorié sous un label. L'image suivante montre les sections `Default`, `Frontend` et `Technical Writing` :

![Le widget de merge request affichant les propriétaires du code regroupés par section.](img/sectional_code_owners_v17_4.png)

Pour plus d'options de configuration de section, consultez :

- [Propriétaires du code par défaut et sections facultatives](advanced.md#default-code-owners-and-optional-sections)
- [Entrées régulières et sections](advanced.md#regular-entries-and-sections)
- [Sections avec des noms en double](advanced.md#sections-with-duplicate-names)

### En-têtes et noms de sections {#section-headings-and-names}

Les en-têtes de section doivent avoir un nom. Les noms de section sont insensibles à la casse, et les [sections avec des noms en double](advanced.md#sections-with-duplicate-names) sont fusionnées. Pour les branches protégées uniquement, elles peuvent :

- Nécessiter une approbation (par défaut).
- Être facultatives (préfixées avec `^`).
- Nécessiter un nombre spécifique d'approbations. Pour plus d'informations, consultez [héritage de groupe et éligibilité](advanced.md#group-inheritance-and-eligibility) et [approbations affichées comme facultatives](troubleshooting.md#approvals-shown-as-optional).
- Inclure des propriétaires par défaut.

Exemples :

```plaintext
# Required section
[Section name]

# Optional section
^[Section name]

# Section requiring 5 approvals
[Section name][5]

# Section with @username as default owner
[Section name] @username

# Section with @group and @subgroup as default owners and requiring 2 approvals
[Section name][2] @group @subgroup
```

### Définir le propriétaire du code par défaut pour une section {#set-default-code-owner-for-a-section}

Si plusieurs chemins de fichiers dans une section partagent la même propriété, définissez des propriétaires du code par défaut pour la section. Tous les chemins de cette section héritent de ce paramètre par défaut, sauf si vous remplacez la valeur par défaut de la section sur une ligne spécifique.

Les propriétaires par défaut sont appliqués lorsqu'aucun propriétaire spécifique n'est indiqué pour les chemins de fichiers. Les propriétaires spécifiques définis à côté du chemin de fichier remplacent les propriétaires par défaut.

Par exemple :

```plaintext
[Documentation] @docs-team
docs/
README.md

[Database] @database-team @agarcia
model/db/
config/db/database-setup.md @docs-team
```

Dans cet exemple :

- `@docs-team` est propriétaire de tous les éléments de la section `Documentation`.
- `@database-team` et `@agarcia` sont propriétaires de tous les éléments de la section `Database`, à l'exception de `config/db/database-setup.md`, qui dispose d'une substitution l'attribuant à `@docs-team`.

Comparez ce comportement à celui obtenu lorsque vous utilisez [des entrées régulières et des sections ensemble](advanced.md#regular-entries-and-sections), lorsque les entrées dans les sections ne remplacent pas les entrées sans sections.

### Sections facultatives {#optional-sections}

Vous pouvez désigner des sections facultatives dans votre fichier Code Owners. Les sections facultatives vous permettent de désigner des responsables pour diverses parties de votre base de code, sans pour autant exiger leur approbation. Cette approche offre une politique plus souple pour les parties de votre projet qui sont fréquemment mises à jour, mais qui ne nécessitent pas de révisions strictes.

Pour traiter l'intégralité de la section comme facultative, faites précéder le nom de la section du caractère caret `^`.

Dans cet exemple, la section `[Go]` est facultative :

```plaintext
[Documentation]
*.md @root

[Ruby]
*.rb @root

^[Go]
*.go @root
```

La section facultative des propriétaires du code s'affiche dans les merge requests sous la description :

![Le widget de merge request affichant les sections facultatives des propriétaires du code.](img/optional_code_owners_sections_v17_4.png)

Si une section est dupliquée dans le fichier et que l'une d'elles est marquée comme facultative et l'autre non, la section est obligatoire.

Les sections facultatives du fichier `CODEOWNERS` sont traitées comme facultatives uniquement lorsque les modifications sont soumises via des merge requests. Si une modification est soumise directement à la branche protégée, l'approbation des propriétaires du code est toujours requise, même si la section est marquée comme facultative.

## Propriétaires du code éligibles {#eligible-code-owners}

Les règles d'éligibilité déterminent qui peut être un propriétaire du code valide. Des règles spécifiques s'appliquent en fonction de la méthode de référence dans le fichier `CODEOWNERS` : nom d'utilisateur, groupe ou rôle.

### Éligibilité des utilisateurs {#user-eligibility}

Pour être éligibles en tant que propriétaires du code, les utilisateurs référencés par leur nom d'utilisateur (`@username`) doivent être autorisés pour le projet. Les règles suivantes s'appliquent :

- Les paramètres de visibilité des projets et des groupes n'affectent pas l'éligibilité.
- Les utilisateurs [exclus d'un groupe](../../group/moderate_users.md) ne peuvent pas être propriétaires du code.
- Les utilisateurs éligibles comprennent ceux qui disposent des éléments suivants :
  - Une appartenance directe au projet avec le rôle Développeur, Mainteneur ou Propriétaire.
  - Une appartenance au groupe du projet (directe ou héritée).
  - Une appartenance à l'un des ancêtres du groupe du projet.
  - Une appartenance directe ou héritée à un groupe invité au projet.
  - Une appartenance directe (mais pas héritée) à un groupe invité dans le groupe du projet.
  - Une appartenance directe (mais pas héritée) à un groupe invité dans l'ancêtre du groupe du projet.

### Éligibilité des groupes {#group-eligibility}

Lors du référencement d'un groupe par son nom (`@group_name`) ou par un nom de groupe imbriqué (`@nested/group/names`), les règles suivantes s'appliquent :

- Les paramètres de visibilité des groupes n'affectent pas l'éligibilité.
- Seuls les membres directs du groupe référencé sont éligibles. Les membres hérités ne sont pas inclus.
- Les groupes éligibles comprennent :
  - Le groupe du projet.
  - Les ancêtres du groupe du projet.
  - Les groupes invités directement au projet avec le rôle Développeur, Mainteneur ou Propriétaire.
  - Les groupes partagés avec le groupe du projet ou ses ancêtres. Le groupe partagé doit avoir le rôle Développeur, Mainteneur ou Propriétaire dans le groupe parent. Pour plus d'informations, consultez [les groupes partagés avec les groupes parents](advanced.md#groups-shared-with-parent-groups).

### Éligibilité des rôles {#role-eligibility}

Lors du référencement d'un rôle (`@@role`), les règles suivantes s'appliquent :

- Seuls les rôles Développeur, Mainteneur et Propriétaire peuvent être utilisés comme propriétaires du code.
- Seuls les membres directs du projet avec le rôle spécifié sont éligibles.
- Les rôles ne sont pas inclusifs des rôles supérieurs. Par exemple, la spécification de `@@developer` n'inclut pas les utilisateurs disposant des rôles Mainteneur ou Propriétaire.

Pour plus d'informations sur l'héritage de groupe complexe et l'éligibilité, consultez [héritage de groupe et éligibilité](advanced.md#group-inheritance-and-eligibility).

## Ajouter un rôle en tant que propriétaire du code {#add-a-role-as-a-code-owner}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/282438) dans GitLab 17.7 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `codeowner_role_approvers`.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/497504) dans GitLab 17.8.
- [Disponible en général](https://gitlab.com/gitlab-org/gitlab/-/issues/512623) dans GitLab 17.9\. Feature flag `codeowner_role_approvers` supprimé.

{{< /history >}}

Vous pouvez ajouter ou définir un rôle pour les membres directs du projet en tant que propriétaires du code :

- Utilisez le préfixe `@@` pour définir un rôle.
- Seuls les rôles Développeur, Mainteneur et Propriétaire sont disponibles.
- Les rôles ne sont pas inclusifs des rôles supérieurs. Par exemple, la spécification de `@@developer` n'inclut pas les utilisateurs disposant des rôles Mainteneur ou Propriétaire.
- Seuls les membres directs du projet avec les rôles spécifiés sont des propriétaires du code éligibles.
- Il est possible de spécifier des rôles au pluriel. Par exemple, `@@developers` est accepté.

L'exemple suivant définit tous les membres directs du projet avec le rôle Développeur ou Mainteneur comme propriétaires du code pour `file.md` :

1. Ouvrez le fichier `CODEOWNERS`.
1. Ajoutez une ligne en suivant le pattern ci-dessous :

   ```plaintext
   file.md @@developer @@maintainer
   ```

1. Enregistrez le fichier.
1. Committez et fusionnez les modifications.

## Ajouter un groupe en tant que propriétaire du code {#add-a-group-as-a-code-owner}

Vous pouvez définir les membres directs d'un groupe ou d'un sous-groupe comme propriétaire du code. Pour plus d'informations sur l'appartenance à un groupe, consultez [types d'appartenance](../members/_index.md#membership-types).

Prérequis :

- Le groupe doit être [invité au projet](../members/sharing_projects_groups.md#invite-a-group-to-a-project).

Pour définir les membres directs d'un groupe ou d'un sous-groupe comme propriétaire du code :

1. Ouvrez le fichier `CODEOWNERS`.
1. Saisissez un texte qui suit l'un de ces patterns :

   ```plaintext
   # All direct group members as Code Owners for a file
   file.md @group-x

   # All direct subgroup members as Code Owners for a file
   file.md @group-x/subgroup-y

   # All direct group and direct subgroup members as Code Owners for a file
   file.md @group-x @group-x/subgroup-y
   ```

1. Enregistrez le fichier.
1. Committez et fusionnez les modifications.

### Exemple de configuration {#example-configuration}

```plaintext
[Maintainers]
* @gitlab-org/maintainers/group-name
```

Dans cet exemple :

- Le groupe `group-name` est répertorié dans la section `[Maintainers]`.
- Le `group-name` contient les membres directs suivants :

  ![La liste des membres du groupe présentant les utilisateurs éligibles au statut de propriétaire du code.](img/direct_group_members_v17_9.png)

- Dans le widget d'approbation de merge request, les mêmes membres directs sont répertoriés sous `Maintainers` :

  ![Le widget d'approbation de merge request répertoriant les membres du groupe en tant que Mainteneurs.](img/merge_request_maintainers_v17_9.png)

> [!note]
> Lorsque le [verrouillage global des appartenances aux groupes SAML](../../group/saml_sso/group_sync.md#global-saml-group-memberships-lock) est activé, vous ne pouvez pas définir un groupe ou un sous-groupe comme propriétaire du code. Pour plus d'informations, consultez [l'incompatibilité avec le verrouillage global des appartenances aux groupes SAML](troubleshooting.md#incompatibility-with-global-group-memberships-locks).

Si vous rencontrez des problèmes, consultez [utilisateur non affiché comme approbateur possible](troubleshooting.md#user-not-shown-as-possible-approver).

## Correspondance de chemins {#path-matching}

Les chemins peuvent être absolus, relatifs, de répertoire, avec des caractères génériques ou globstar, et sont mis en correspondance avec la racine du dépôt.

### Chemins absolus {#absolute-paths}

Les chemins commençant par `/` correspondent à partir de la racine du dépôt :

```plaintext
# Matches only README.md in the root.
/README.md

# Matches only README.md inside the /docs directory.
/docs/README.md
```

### Chemins relatifs {#relative-paths}

Les chemins sans `/` initial sont traités comme des [chemins globstar](#globstar-paths) :

```plaintext
# Matches /README.md, /internal/README.md, /app/lib/README.md
README.md @username

# Matches /internal/README.md, /docs/internal/README.md, /docs/api/internal/README.md
internal/README.md
```

> [!note]
> Lors de l'utilisation de chemins globstar, soyez vigilant quant aux correspondances non souhaitées. Par exemple, `README.md` sans `/` initial correspond à tout fichier `README.md` dans n'importe quel répertoire ou sous-répertoire du dépôt.

### Chemins de répertoire {#directory-paths}

Terminez un chemin par `/` pour faire correspondre tous les fichiers du répertoire et de ses sous-répertoires :

```plaintext
# Matches all files in /docs/ and its subdirectories
/docs/
```

### Chemins avec caractères génériques {#wildcard-paths}

Utilisez `*` pour faire correspondre plusieurs caractères :

```plaintext
# Any markdown files in the docs directory
/docs/*.md @username

# /docs/index file of any filetype
# For example: /docs/index.md, /docs/index.html, /docs/index.xml
/docs/index.* @username

# Any file in the docs directory with 'spec' in the name.
# For example: /docs/qa_specs.rb, /docs/spec_helpers.rb, /docs/runtime.spec
/docs/*spec* @username

# README.md files one level deep within the docs directory
# For example: /docs/api/README.md
/docs/*/README.md @username
```

### Chemins globstar {#globstar-paths}

Utilisez `**` pour faire correspondre des fichiers ou des patterns sur plusieurs niveaux de répertoires :

```plaintext
# For example: /docs/index.md, /docs/api/index.md, and /docs/api/graphql/index.md.
/docs/**/index.md
```

Pour faire correspondre tous les fichiers d'un répertoire, utilisez les [chemins de répertoire](#directory-paths) avec une barre oblique finale (`/`).

### Modèles d'exclusion {#exclusion-patterns}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/180162) dans GitLab 17.10 [avec le feature flag](../../../administration/feature_flags/_index.md) `codeowners_file_exclusions`.
- [Activée sur GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/517075) dans GitLab 17.10.
- [Disponibilité générale](https://gitlab.com/gitlab-org/gitlab/-/issues/517309) dans GitLab 17.11. Le feature flag `codeowners_file_exclusions` a été supprimé.

{{< /history >}}

Préfixez les fichiers ou les chemins avec `!` pour les exempter ou les exclure de l'obligation d'approbation du propriétaire du code. Les exclusions s'appliquent dans leur section. Dans l'exemple suivant :

- L'exclusion `pom.xml` s'applique à la section par défaut.
- L'exclusion `/config/**/*.rb` n'affecte que les fichiers Ruby dans la section Ruby.

```plaintext
# All files require approval from @username
* @username

# Except pom.xml which needs no approval
!pom.xml

[Ruby]
# All ruby files require approval from @ruby-team
*.rb @ruby-team

# Except Ruby files in the config directory
!/config/**/*.rb
```

Les consignes suivantes expliquent le comportement des patterns d'exclusion :

- Les exclusions sont évaluées dans l'ordre au sein de leur section. Par exemple :

  ```plaintext
  * @default-owner
  !*.rb                      # Excludes all Ruby files.
  /special/*.rb @ruby-owner  # This won't take effect as *.rb is already excluded.
  ```

- Après l'exclusion d'un pattern, il ne peut plus être inclus à nouveau dans la même section :

  ```plaintext
  [Ruby]
  *.rb @ruby-team           # All Ruby files need Ruby team approval.
  !/config/**/*.rb          # Ruby files in config don't need Ruby team approval.
  /config/routes.rb @ops    # This won't take effect as config Ruby files are excluded.
  ```

- Les fichiers correspondant à un pattern d'exclusion ne nécessitent pas d'approbation du propriétaire du code pour cette section. Si vous avez besoin d'exclusions différentes pour différents propriétaires, utilisez plusieurs sections :

  ```plaintext
  [Ruby]
  *.rb @ruby-team
  !/config/**/*.rb        # Config Ruby files don't need Ruby team approval.

  [Config]
  /config/ @ops-team      # Config files still require ops-team approval.
  ```

- Utilisez des exclusions pour les fichiers qui sont mis à jour automatiquement :

  ```plaintext
  * @default-owner

  # Files updated by automation don't need approval.
  !package-lock.json
  !yarn.lock
  !**/generated/          # Any files in generated directories.
  !.gitlab-ci.yml
  ```

## Propriétaires d'entrées {#entry-owners}

Les entrées doivent avoir un ou plusieurs propriétaires. Il peut s'agir de groupes, de sous-groupes et d'utilisateurs.

```plaintext
/path/to/entry.rb @group
/path/to/entry.rb @group/subgroup
/path/to/entry.rb @user
/path/to/entry.rb @group @group/subgroup @user
```

Pour plus d'informations sur l'ajout de groupes en tant que propriétaires du code, consultez [ajouter un groupe en tant que propriétaire du code](#add-a-group-as-a-code-owner).

## Sujets connexes {#related-topics}

- [Propriétaires du code](_index.md)
- [Configuration avancée de `CODEOWNERS`](advanced.md)
- [Approbations des merge requests](../merge_requests/approvals/_index.md)
- [Branches protégées](../repository/branches/protected.md)
- [Dépannage des propriétaires du code](troubleshooting.md)
