---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Proxy Go pour GitLab (déprécié)
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/27376) dans GitLab 13.1 [avec un feature flag](../../../administration/feature_flags/_index.md) nommé `go_proxy`. Fonctionnalité désactivée par défaut. Cette fonctionnalité est une [version expérimentale](../../../policy/development_stages_support.md).
- [Déprécié](https://gitlab.com/gitlab-org/gitlab/-/issues/592132) dans GitLab 19.1.

{{< /history >}}

> [!warning]
> Cette fonctionnalité a été [dépréciée](https://gitlab.com/gitlab-org/gitlab/-/issues/592132) dans GitLab 19.1 et sa suppression est prévue dans la version 20.0. Utilisez le [registre virtuel Go](https://gitlab.com/gitlab-org/gitlab/-/issues/592136) à la place, dès qu'il sera disponible.

Avec le proxy Go pour GitLab, chaque projet dans GitLab peut être récupéré avec le [protocole proxy Go](https://proxy.golang.org/).

Le proxy Go pour GitLab est une [version expérimentale](../../../policy/development_stages_support.md), et n'est pas prêt pour une utilisation en production en raison de problèmes de performance potentiels avec les grands dépôts. Consultez le [ticket 218083](https://gitlab.com/gitlab-org/gitlab/-/issues/218083).

GitLab n'affiche pas les modules Go dans le registre de paquets, même si le proxy Go est activé. Consultez le [ticket 213770](https://gitlab.com/gitlab-org/gitlab/-/issues/213770).

Pour la documentation des endpoints d'API spécifiques qu'utilise le proxy Go, consultez la [documentation de l'API du proxy Go](../../../api/packages/go_proxy.md).

## Ajouter GitLab comme proxy Go {#add-gitlab-as-a-go-proxy}

Pour utiliser GitLab comme proxy Go, vous devez utiliser Go 1.13 ou une version ultérieure.

L'endpoint proxy disponible est destiné à la récupération des modules par projet : `/api/v4/projects/:id/packages/go`

Pour récupérer des modules Go depuis GitLab, ajoutez l'endpoint spécifique au projet à `GOPROXY`.

Go interroge l'endpoint et revient au comportement par défaut :

```shell
go env -w GOPROXY='https://gitlab.example.com/api/v4/projects/1234/packages/go,https://proxy.golang.org,direct'
```

Avec cette configuration, Go récupère les dépendances dans cet ordre :

1. Go tente de récupérer depuis le proxy Go spécifique au projet.
1. Go tente de récupérer depuis [`proxy.golang.org`](https://proxy.golang.org).
1. Go récupère directement via les opérations du système de contrôle de version (comme `git clone`, `svn checkout`, etc.).

Si `GOPROXY` n'est pas spécifié, Go suit les étapes 2 et 3, ce qui correspond à définir `GOPROXY` sur `https://proxy.golang.org,direct`. Si `GOPROXY` contient uniquement l'endpoint spécifique au projet, Go interroge uniquement cet endpoint.

Pour plus de détails sur la définition des variables d'environnement Go, consultez [Définir les variables d'environnement](#set-environment-variables).

## Récupérer des modules depuis des projets privés {#fetch-modules-from-private-projects}

`go` ne prend pas en charge la transmission des identifiants via des connexions non sécurisées. Les étapes suivantes ne fonctionnent que si GitLab est configuré pour HTTPS :

1. Configurez Go pour inclure les identifiants d'authentification HTTP de base lors de la récupération depuis le proxy Go pour GitLab.
1. Configurez Go pour ignorer le téléchargement des sommes de contrôle des projets GitLab privés depuis la base de données publique des sommes de contrôle.

### Activer l'authentification des requêtes {#enable-request-authentication}

Créez un [jeton d'accès personnel](../../profile/personal_access_tokens.md) avec la portée définie sur `api` ou `read_api`.

Ouvrez votre fichier [`~/.netrc`](https://everything.curl.dev/usingcurl/netrc.html) et ajoutez le texte suivant. Remplacez les variables dans `< >` par vos valeurs.

Si vous effectuez une requête `go get` avec des identifiants HTTP invalides, vous recevrez une erreur 404.

> [!warning]
> Si vous utilisez une variable d'environnement appelée `NETRC`, Go utilise sa valeur comme nom de fichier et ignore `~/.netrc`. Si vous avez l'intention d'utiliser `~/.netrc` dans GitLab CI/CD, n'utilisez pas `NETRC` comme nom de variable d'environnement.

```plaintext
machine <url> login <username> password <token>
```

- `<url>` : L'URL GitLab, par exemple `gitlab.com`.
- `<username>` : votre nom d'utilisateur.
- `<token>` : votre jeton d'accès personnel.

### Désactiver les requêtes vers la base de données des sommes de contrôle {#disable-checksum-database-queries}

Lors du téléchargement des dépendances avec Go 1.13 et les versions ultérieures, les sources récupérées sont validées par rapport à la base de données des sommes de contrôle `sum.golang.org`.

Si la somme de contrôle des sources récupérées ne correspond pas à celle de la base de données, Go ne compile pas la dépendance.

Les modules privés échouent à la compilation parce que `sum.golang.org` ne peut pas récupérer la source des modules privés, et ne peut donc pas fournir de somme de contrôle.

Pour résoudre ce ticket, définissez `GONOSUMDB` sur une liste de projets privés séparés par des virgules. Pour plus de détails sur la définition des variables d'environnement Go, consultez [Définir les variables d'environnement](#set-environment-variables).

Par exemple, pour désactiver les requêtes de somme de contrôle pour `gitlab.com/my/project`, définissez `GONOSUMDB` :

```shell
go env -w GONOSUMDB='gitlab.com/my/project,<previous value>'
```

## Travailler avec Go {#working-with-go}

Si vous n'êtes pas familier avec la gestion des dépendances dans Go, ou avec Go en général, consultez la documentation suivante :

- [Référence des modules Go](https://go.dev/ref/mod)
- [Documentation (`golang.org`)](https://go.dev/doc/)
- [Apprendre (`go.dev/learn`)](https://go.dev/learn/)

### Définir les variables d'environnement {#set-environment-variables}

Go utilise des variables d'environnement pour contrôler diverses fonctionnalités. Vous pouvez gérer ces variables de toutes les manières habituelles. Cependant, Go 1.14 lit et écrit les variables d'environnement Go depuis et vers un fichier d'environnement Go spécial, `~/.go/env` par défaut.

- Si `GOENV` est défini sur un fichier, Go lit et écrit depuis et vers ce fichier à la place.
- Si `GOENV` n'est pas défini mais que `GOPATH` l'est, Go lit et écrit `$GOPATH/env`.

Les variables d'environnement Go peuvent être lues avec `go env <var>` et, dans Go 1.14 et les versions ultérieures, peuvent être écrites avec `go env -w <var>=<value>`. Par exemple, `go env GOPATH` ou `go env -w GOPATH=/go`.

### Publier une release d'un module {#release-a-module}

Les modules Go et les versions de modules sont définis par des dépôts sources, tels que Git, SVN et Mercurial. Un module est un dépôt qui contient `go.mod` et des fichiers Go. Les versions de modules sont définies par des tags du système de contrôle de version (VCS).

Pour publier un module, poussez `go.mod` et les fichiers source vers un dépôt VCS. Pour publier une version de module, poussez un tag VCS.
