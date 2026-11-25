---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Redirections GitLab Pages
description: "Configurez les redirections et réécritures d'URL pour les sites GitLab Pages avec des règles au style Netlify."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Dans GitLab Pages, vous pouvez configurer des règles pour rediriger une URL vers une autre à l'aide de redirections HTTP [au style Netlify](https://docs.netlify.com/manage/routing/redirects/overview/#syntax-for-the-redirects-file).

Toutes les [options spéciales proposées par Netlify](https://docs.netlify.com/manage/routing/redirects/redirect-options/) ne sont pas prises en charge.

| Fonctionnalité                                           | Prise en charge              | Exemple |
|---------------------------------------------------|------------------------|---------|
| [Redirections (`301`, `302`)](#redirects)            | {{< yes >}} | `/wardrobe.html /narnia.html 302` |
| [Réécritures (`200`)](#rewrites)                     | {{< yes >}} | `/* / 200` |
| [Splats](#splats)                                 | {{< yes >}} | `/news/*  /blog/:splat` |
| [Espaces réservés](#placeholders)                     | {{< yes >}} | `/news/:year/:month/:date /blog-:year-:month-:date.html` |
| Réécritures (autres que `200`)                       | {{< no >}} | `/en/* /en/404.html 404` |
| Paramètres de requête                                  | {{< no >}} | `/store id=:id  /blog/:id  301` |
| Forcer ([shadowing](https://docs.netlify.com/manage/routing/redirects/rewrites-proxies/#shadowing)) | {{< no >}} | `/app/  /app/index.html  200!` |
| [Redirections au niveau du domaine](#domain-level-redirects) | {{< yes >}} | `http://blog.example.com/* https://www.example.com/blog/:splat 301` |
| Redirection par pays ou langue                   | {{< no >}} | `/  /anz     302  Country=au,nz` |
| Redirection par rôle                                  | {{< no >}} | `/admin/*  200!  Role=admin` |

> [!note]
> Les [cas de test du comportement de correspondance](https://gitlab.com/gitlab-org/gitlab-pages/-/blob/master/internal/redirects/matching_test.go) constituent une bonne ressource pour comprendre en détail comment GitLab implémente la correspondance de règles. Les contributions de la communauté sont les bienvenues pour tout cas limite non inclus dans cette suite de tests !

## Créer des redirections {#create-redirects}

Pour créer des redirections, créez un fichier de configuration nommé `_redirects` dans le répertoire `public/` de votre site GitLab Pages.

- Tous les chemins doivent commencer par une barre oblique `/`.
- Un code de statut par défaut de `301` est appliqué si aucun [code de statut](#http-status-codes) n'est fourni.
- Le fichier `_redirects` est soumis à une limite de taille de fichier et à un nombre maximum de règles par projet, configurés pour l'instance. Seules les premières règles correspondantes dans le maximum configuré sont traitées. La limite de taille de fichier par défaut est de 64 Ko et le nombre maximum de règles par défaut est de 1 000.
- Si votre site GitLab Pages utilise le nom de domaine par défaut (tel que `namespace.gitlab.io/project-slug`), vous devez préfixer chaque règle avec le chemin :

  ```plaintext
  /project-slug/wardrobe.html /project-slug/narnia.html 302
  ```

- Si votre site GitLab Pages utilise des [domaines personnalisés](custom_domains_ssl_tls_certification/_index.md), aucun préfixe de chemin de projet n'est nécessaire. Par exemple, si votre domaine personnalisé est `example.com`, votre fichier `_redirects` ressemblerait à ceci :

  ```plaintext
  /wardrobe.html /narnia.html 302
  ```

## Les fichiers ont priorité sur les redirections {#files-override-redirects}

Les fichiers ont priorité sur les redirections. Si un fichier existe sur le disque, GitLab Pages sert le fichier à la place de votre redirection. Par exemple, si les fichiers `hello.html` et `world.html` existent, et que le fichier `_redirects` contient la ligne suivante, la redirection est ignorée car `hello.html` existe :

```plaintext
/project-slug/hello.html /project-slug/world.html 302
```

GitLab ne prend pas en charge l'[option force](https://docs.netlify.com/manage/routing/redirects/rewrites-proxies/#shadowing) de Netlify pour modifier ce comportement.

## Codes de statut HTTP {#http-status-codes}

Un code de statut par défaut de `301` est appliqué si aucun code de statut n'est fourni, mais vous pouvez en définir un explicitement. Les codes HTTP suivants sont pris en charge :

- **301** : redirection permanente.
- **302** : redirection temporaire.
- **200** : réponse standard pour les requêtes HTTP réussies. Pages sert le contenu de la règle `to` si elle existe, sans modifier l'URL dans la barre d'adresse.

## Redirections {#redirects}

Pour créer une redirection, ajoutez une règle qui inclut un chemin `from`, un chemin `to` et un [code de statut HTTP](#http-status-codes) :

```plaintext
# 301 permanent redirect
/old/file.html /new/file.html 301

# 302 temporary redirect
/old/another_file.html /new/another_file.html 302
```

## Réécritures {#rewrites}

Fournissez un code de statut `200` pour servir le contenu du chemin `to` lorsque la requête correspond à `from` :

```plaintext
/old/file.html /new/file.html 200
```

Ce code de statut peut être utilisé en combinaison avec les [règles splat](#splats) pour réécrire dynamiquement l'URL.

## Redirections au niveau du domaine {#domain-level-redirects}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab-pages/-/merge_requests/936) dans GitLab 16.8 [avec le feature flag](../../../administration/feature_flags/_index.md) `FF_ENABLE_DOMAIN_REDIRECT`. Fonctionnalité désactivée par défaut.
- [Activé sur GitLab.com](https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/gitlab-com/-/merge_requests/3395) dans GitLab 16.9.
- [Activé sur GitLab Self-Managed et GitLab Dedicated](https://gitlab.com/gitlab-org/gitlab-pages/-/issues/1087) dans GitLab 16.10.
- [Passage en disponibilité générale](https://gitlab.com/gitlab-org/gitlab-pages/-/issues/1097) dans GitLab 17.4. Feature flag `FF_ENABLE_DOMAIN_REDIRECT` supprimé.

{{< /history >}}

Pour créer une redirection au niveau du domaine, ajoutez un chemin au niveau du domaine (commençant par `http://` ou `https://`) à l'un des éléments suivants :

- Le chemin `to` uniquement.
- Les chemins `from` et `to`.

Les [codes de statut HTTP](#http-status-codes) pris en charge sont `301` et `302` :

```plaintext
# 301 permanent redirect
http://blog.example.com/file_1.html https://www.example.com/blog/file_1.html 301
/file_2.html https://www.example.com/blog/file_2.html 301

# 302 temporary redirect
http://blog.example.com/file_3.html https://www.example.com/blog/file_3.html 302
/file_4.html https://www.example.com/blog/file_4.html 302
```

Les redirections au niveau du domaine peuvent être utilisées en combinaison avec les [règles splat](#splats) (y compris les espaces réservés splat) pour réécrire dynamiquement le chemin de l'URL.

## Splats {#splats}

Une règle avec un astérisque (`*`) dans son chemin `from`, appelée splat, correspond à n'importe quel élément au début, au milieu ou à la fin du chemin demandé. Cet exemple correspond à tout ce qui suit `/old/` et le réécrit en `/new/file.html` :

```plaintext
/old/* /new/file.html 200
```

### Espaces réservés splat {#splat-placeholders}

Le contenu mis en correspondance par un `*` dans le chemin `from` d'une règle peut être injecté dans le chemin `to` à l'aide de l'espace réservé `:splat` :

```plaintext
/old/* /new/:splat 200
```

Dans cet exemple, une requête vers `/old/file.html` sert le contenu de `/new/file.html` avec un code de statut `200`.

Si le chemin `from` d'une règle inclut plusieurs splats, la valeur du premier splat correspondant remplace tous les `:splat` dans le chemin `to`.

### Comportement de correspondance des splats {#splat-matching-behavior}

Les splats sont « gourmands » et correspondent au plus grand nombre de caractères possible :

```plaintext
/old/*/file /new/:splat/file 301
```

Dans cet exemple, la règle redirige `/old/a/b/c/file` vers `/new/a/b/c/file`.

Les splats correspondent également aux chaînes vides, de sorte que la règle précédente redirige `/old/file` vers `/new/file`.

### Faire correspondre une extension de fichier avec un splat {#match-a-file-extension-with-a-splat}

Un splat peut directement précéder une extension de fichier dans le chemin `from`. Par exemple, cette règle correspond à toute requête `.html` et la redirige vers le même chemin avec une barre oblique finale et sans extension :

```plaintext
/*.html /:splat/ 301
```

Dans cet exemple, une requête vers `/page.html` est redirigée vers `/page/`, et une requête vers `/docs/page.html` est redirigée vers `/docs/page/`.

### Réécrire toutes les requêtes vers un `index.html` racine {#rewrite-all-requests-to-a-root-indexhtml}

Les applications monopages (SPA) effectuent souvent leur propre routage à l'aide de routes côté client. Pour ces applications, réécrivez toutes les requêtes vers le `index.html` racine afin que la logique de routage puisse être gérée par l'application JavaScript.

Pour réécrire les requêtes vers `index.html` :

1. Ajoutez cette règle `_redirects` :

   ```plaintext
   /* /index.html 200
   ```

1. Pour que votre application monopage fonctionne avec des déploiements parallèles, modifiez la règle de redirection pour inclure le préfixe de chemin :

   ```plaintext
   /project/base/<prefix>/* /project/base/<prefix>/index.html 200
   ```

   Remplacez `<prefix>` par la valeur de votre préfixe de chemin.

## Espaces réservés {#placeholders}

Utilisez des espaces réservés dans les règles pour faire correspondre des parties de l'URL demandée et utilisez ces correspondances lors de la réécriture ou de la redirection vers une nouvelle URL.

Un espace réservé est formaté comme un caractère `:` suivi d'une chaîne de lettres (`[a-zA-Z]+`) dans les chemins `from` et `to` :

```plaintext
/news/:year/:month/:date/:slug /blog/:year-:month-:date-:slug 200
```

Cette règle indique à Pages de répondre à une requête pour `/news/2021/08/12/file.html` en servant le contenu de `/blog/2021-08-12-file.html` avec un `200`.

### Comportement de correspondance des espaces réservés {#placeholder-matching-behavior}

Par rapport aux [splats](#splats), les espaces réservés sont plus limités dans la quantité de contenu qu'ils peuvent mettre en correspondance. Les espaces réservés correspondent au texte entre les barres obliques (`/`), utilisez donc des espaces réservés pour faire correspondre des segments de chemin uniques.

De plus, les espaces réservés ne correspondent pas aux chaînes vides. Une règle telle que la suivante ne correspondrait pas à une URL de requête comme `/old/file` :

```plaintext
/old/:path /new/:path
```

## Déboguer les règles de redirection {#debug-redirect-rules}

Si une redirection ne fonctionne pas comme prévu, ou si vous souhaitez vérifier la syntaxe de votre redirection, consultez `[your pages url]/_redirects`. Le fichier `_redirects` n'est pas servi directement, mais votre navigateur affiche une liste numérotée de vos règles de redirection, et indique si chaque règle est valide ou invalide :

```plaintext
11 rules
rule 1: valid
rule 2: valid
rule 3: error: splats are not supported
rule 4: valid
rule 5: error: placeholders are not supported
rule 6: valid
rule 7: error: no domain-level redirects to outside sites
rule 8: error: url path must start with forward slash /
rule 9: error: no domain-level redirects to outside sites
rule 10: valid
rule 11: valid
```

## Différences par rapport à l'implémentation Netlify {#differences-from-netlify-implementation}

La plupart des règles `_redirects` prises en charge se comportent de la même façon dans GitLab et Netlify. Toutefois, il existe quelques différences mineures :

- **Toutes les URL de règles doivent commencer par une barre oblique** :

  Netlify n'exige pas que les URL commencent par une barre oblique :

  ```plaintext
  # Valid in Netlify, invalid in GitLab
  */path /new/path 200
  ```

  GitLab valide que toutes les URL commencent par une barre oblique. Un équivalent valide de l'exemple précédent :

  ```plaintext
  # Valid in both Netlify and GitLab
  /old/path /new/path 200
  ```

- **Toutes les valeurs d'espace réservé sont renseignées** :

  Netlify ne renseigne que les valeurs d'espace réservé qui apparaissent dans le chemin `to` :

  ```plaintext
  /old /new/:placeholder
  ```

  Pour une requête vers `/old` :

  - Netlify redirige vers `/new/:placeholder` (avec un `:placeholder` littéral).
  - GitLab redirige vers `/new/`.
