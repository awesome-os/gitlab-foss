---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Paramètres de GitLab Pages
description: "Options de configuration pour GitLab Pages, notamment les pages d'erreur personnalisées, les redirections et les domaines uniques."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

GitLab Pages propose des options de configuration pour personnaliser le déploiement et la présentation de votre site statique. Avec les paramètres de Pages, vous pouvez :

- Afficher des pages d'erreur personnalisées pour les réponses 403 et 404.
- Configurer des redirections d'URL via des fichiers `_redirects`.
- Déployer des pages depuis n'importe quelle branche à l'aide de règles CI/CD.
- Servir des ressources pré-compressées pour accélérer le chargement des pages.
- Personnaliser le dossier depuis lequel votre site est publié.
- Générer et gérer des domaines uniques pour vos sites.

Pour une introduction à Pages, consultez [GitLab Pages](_index.md).

## Prérequis pour GitLab Pages {#gitlab-pages-requirements}

En résumé, voici ce dont vous avez besoin pour publier votre site web dans GitLab Pages :

1. Domaine de l'instance : nom de domaine utilisé pour GitLab Pages (demandez à votre administrateur).
1. GitLab CI/CD : un fichier `.gitlab-ci.yml` avec un job spécifique nommé [`pages`](../../../ci/yaml/_index.md#pages) dans le répertoire racine de votre dépôt.
1. GitLab Runner activé pour le projet.

## GitLab Pages sur GitLab.com {#gitlab-pages-on-gitlabcom}

Si vous utilisez [GitLab Pages sur GitLab.com](#gitlab-pages-on-gitlabcom) pour héberger votre site web, alors :

- Le nom de domaine pour GitLab Pages sur GitLab.com est `gitlab.io`.
- Les domaines personnalisés et la prise en charge TLS sont activés.
- Les runners d'instance sont activés par défaut, fournis gratuitement, et peuvent être utilisés pour construire votre site web. Si vous le souhaitez, vous pouvez toujours utiliser votre propre runner.

## Exemples de projets {#example-projects}

Visitez le [groupe GitLab Pages](https://gitlab.com/groups/pages) pour obtenir une liste complète d'exemples de projets. Les contributions sont les bienvenues.

## Pages de codes d'erreur personnalisés {#custom-error-codes-pages}

Vous pouvez fournir vos propres pages d'erreur `403` et `404` en créant les fichiers `403.html` et `404.html` à la racine du répertoire `public/`. Il s'agit généralement du répertoire racine de votre projet, mais cela peut varier selon la configuration de votre générateur de site statique.

Dans le cas de `404.html`, plusieurs scénarios sont possibles. Par exemple :

- Si vous utilisez des Pages de projet (servies sous `/project-slug/`) et que vous essayez d'accéder à `/project-slug/non/existing_file`, GitLab Pages tente de servir d'abord `/project-slug/404.html`, puis `/404.html`.
- Si vous utilisez des Pages d'utilisateur ou de groupe (servies sous `/`) et que vous essayez d'accéder à `/non/existing_file`, GitLab Pages tente de servir `/404.html`.
- Si vous utilisez un domaine personnalisé et que vous essayez d'accéder à `/non/existing_file`, GitLab Pages tente de servir uniquement `/404.html`.

## Redirections dans GitLab Pages {#redirects-in-gitlab-pages}

Vous pouvez configurer des redirections pour votre site à l'aide d'un fichier `_redirects`. Pour plus d'informations, consultez [Créer des redirections pour GitLab Pages](redirects.md).

## Supprimer un site Pages {#delete-a-pages-site}

Supprimez définitivement tous les déploiements Pages d'un projet.

> [!warning]
> Cette modification ne peut pas être annulée.

Pour supprimer vos Pages :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Pages**.
1. Sélectionnez l'onglet **Domaines & paramètres**.
1. Sélectionnez **Supprimer le site Pages**.
1. Dans la boîte de dialogue de confirmation, sélectionnez **Supprimer le site Pages**.

Votre site Pages n'est plus déployé. Pour déployer à nouveau ce site Pages, exécutez un nouveau pipeline.

## Sous-domaines de sous-domaines {#subdomains-of-subdomains}

Lorsque vous utilisez Pages sous le domaine de premier niveau d'une instance GitLab (`*.example.io`), vous ne pouvez pas utiliser HTTPS avec des sous-domaines de sous-domaines. Si votre espace de nommage ou le nom de votre groupe contient un point (par exemple, `foo.bar`), le domaine `https://foo.bar.example.io` ne fonctionne pas.

Cette limitation est due au [protocole HTTP Over TLS](https://www.rfc-editor.org/rfc/rfc2818#section-3.1). Les pages HTTP fonctionnent tant que vous ne redirigez pas HTTP vers HTTPS.

## GitLab Pages dans les projets et les groupes {#gitlab-pages-in-projects-and-groups}

Vous devez héberger votre site web GitLab Pages dans un projet. Ce projet peut être [privé, interne ou public](../../public_access.md) et appartenir à un [groupe](../../group/_index.md) ou à un [sous-groupe](../../group/subgroups/_index.md).

Pour les [sites web de groupe](getting_started_part_one.md#user-and-group-website-examples), le groupe doit être au niveau supérieur et non un sous-groupe.

Pour les [sites web de projet](getting_started_part_one.md#project-website-examples), vous pouvez d'abord créer votre projet et y accéder sous `http(s)://namespace.example.io/project-path`.

## Options de configuration spécifiques pour Pages {#specific-configuration-options-for-pages}

Découvrez comment configurer GitLab CI/CD pour des cas d'utilisation spécifiques.

### `.gitlab-ci.yml` pour les sites web HTML simples {#gitlab-ciyml-for-plain-html-websites}

Supposons que votre dépôt contienne les fichiers suivants :

```plaintext
├── index.html
├── css
│   └── main.css
└── js
    └── main.js
```

L'exemple `.gitlab-ci.yml` ci-dessous déplace tous les fichiers du répertoire racine du projet vers le répertoire `public/`. La solution de contournement `.public` permet d'éviter que `cp` ne copie également `public/` dans lui-même en créant une boucle infinie :

```yaml
create-pages:
  script:
    - mkdir .public
    - cp -r * .public
    - mv .public public
  pages: true  # specifies that this is a Pages job and publishes the default public directory
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

L'exemple YAML précédent utilise des [noms de job définis par l'utilisateur](_index.md#user-defined-job-names).

### `.gitlab-ci.yml` pour un générateur de site statique {#gitlab-ciyml-for-a-static-site-generator}

Consultez ce document pour un [guide pas à pas](getting_started/pages_from_scratch.md).

### `.gitlab-ci.yml` pour un dépôt contenant du code {#gitlab-ciyml-for-a-repository-with-code}

N'oubliez pas que GitLab Pages est par défaut indépendant des branches/tags, et que son déploiement repose uniquement sur ce que vous spécifiez dans `.gitlab-ci.yml`. Vous pouvez limiter le job `pages` avec [`rules:if`](../../../ci/yaml/_index.md#rulesif), chaque fois qu'un nouveau commit est poussé vers une branche utilisée spécifiquement pour vos pages.

Ainsi, vous pouvez avoir le code de votre projet dans la branche `main` et utiliser une branche orpheline (appelons-la `pages`) pour héberger votre site de générateur statique.

Vous pouvez créer une nouvelle branche vide de cette façon :

```shell
git checkout --orphan pages
```

Le premier commit effectué sur cette nouvelle branche n'a pas de parent et constitue la racine d'un nouvel historique totalement déconnecté de toutes les autres branches et de tous les autres commits. Poussez les fichiers sources de votre générateur statique dans la branche `pages`.

Voici une copie de `.gitlab-ci.yml` dont la ligne la plus importante est la dernière, qui indique d'exécuter tout le contenu de la branche `pages` :

```yaml
create-pages:
  image: ruby:2.6
  script:
    - gem install jekyll
    - jekyll build -d public/
  pages: true  # specifies that this is a Pages job and publishes the default public directory
  rules:
    - if: '$CI_COMMIT_REF_NAME == "pages"'
```

Consultez un exemple qui présente des fichiers différents dans la [branche `main`](https://gitlab.com/pages/jekyll-branched/tree/main) et dont les fichiers sources pour Jekyll se trouvent dans une [branche `pages`](https://gitlab.com/pages/jekyll-branched/tree/pages) qui inclut également `.gitlab-ci.yml`.

L'exemple YAML précédent utilise des [noms de job définis par l'utilisateur](_index.md#user-defined-job-names).

### Servir des ressources compressées {#serving-compressed-assets}

La plupart des navigateurs modernes prennent en charge le téléchargement de fichiers dans un format compressé. Cela accélère les téléchargements en réduisant la taille des fichiers.

Avant de servir un fichier non compressé, Pages vérifie si le même fichier existe avec une extension `.br` ou `.gz`. Si c'est le cas et que le navigateur prend en charge la réception de fichiers compressés, c'est cette version qui est servie à la place de la version non compressée.

Pour tirer parti de cette fonctionnalité, l'artefact que vous téléversez vers Pages doit avoir la structure suivante :

```plaintext
public/
├─┬ index.html
│ | index.html.br
│ └ index.html.gz
│
├── css/
│   └─┬ main.css
│     | main.css.br
│     └ main.css.gz
│
└── js/
    └─┬ main.js
      | main.js.br
      └ main.js.gz
```

Pour ce faire, incluez une commande `script:` comme celle-ci dans le job pages de votre fichier `.gitlab-ci.yml` :

```yaml
create-pages:
  # Other directives
  script:
    # Build the public/ directory first
    - find public -type f -regex '.*\.\(htm\|html\|xml\|txt\|text\|js\|css\|svg\)$' -exec gzip -f -k {} \;
    - find public -type f -regex '.*\.\(htm\|html\|xml\|txt\|text\|js\|css\|svg\)$' -exec brotli -f -k {} \;
  pages: true  # specifies that this is a Pages job
```

En pré-compressant les fichiers et en incluant les deux versions dans l'artefact, Pages peut traiter les requêtes de contenu compressé et non compressé sans avoir à compresser les fichiers à la demande.

L'exemple YAML précédent utilise des [noms de job définis par l'utilisateur](_index.md#user-defined-job-names).

### Résolution des URL ambiguës {#resolving-ambiguous-urls}

GitLab Pages émet des hypothèses sur les fichiers à servir lors de la réception d'une requête pour une URL ne comportant pas d'extension.

Prenons un exemple de site Pages déployé avec les fichiers suivants :

```plaintext
public/
├── index.html
├── data.html
├── info.html
├── data/
│   └── index.html
└── info/
    └── details.html
```

Pages prend en charge l'accès à chacun de ces fichiers via plusieurs URL différentes. En particulier, il recherche toujours un fichier `index.html` si l'URL ne spécifie que le répertoire. Si l'URL fait référence à un fichier qui n'existe pas, mais que l'ajout de `.html` à l'URL mène à un fichier existant, c'est ce dernier qui est servi. Voici quelques exemples de ce qui se passe avec le site Pages précédent :

| Chemin URL             | Réponse HTTP |
| -------------------- | ------------- |
| `/`                  | `200 OK` : `public/index.html` |
| `/index.html`        | `200 OK` : `public/index.html` |
| `/index`             | `200 OK` : `public/index.html` |
| `/data`              | `302 Found` : redirection vers `/data/` |
| `/data/`             | `200 OK` : `public/data/index.html` |
| `/data.html`         | `200 OK` : `public/data.html` |
| `/info`              | `302 Found` : redirection vers `/info/` |
| `/info/`             | Page d'erreur `404 Not Found` |
| `/info.html`         | `200 OK` : `public/info.html` |
| `/info/details`      | `200 OK` : `public/info/details.html` |
| `/info/details.html` | `200 OK` : `public/info/details.html` |

Lorsque `public/data/index.html` existe, il est prioritaire sur le fichier `public/data.html` pour les chemins d'URL `/data` et `/data/`.

## Personnaliser le dossier par défaut {#customize-the-default-folder}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab-pages/-/merge_requests/859) dans GitLab 16.1 avec un flag Pages nommé `FF_CONFIGURABLE_ROOT_DIR`. Fonctionnalité désactivée par défaut.
- [Activée sur GitLab.com](https://gitlab.com/gitlab-org/gitlab-pages/-/issues/1073) dans GitLab 16.1.
- [Activée sur GitLab Self-Managed](https://gitlab.com/gitlab-org/gitlab-pages/-/merge_requests/890) dans GitLab 16.2.
- [Modifiée](https://gitlab.com/gitlab-org/gitlab/-/issues/500000) pour permettre l'utilisation de variables lorsqu'elles sont transmises à la propriété `publish` dans GitLab 17.9.
- [Déplacée](https://gitlab.com/gitlab-org/gitlab/-/issues/428018) : la propriété `publish` est désormais imbriquée sous le mot-clé `pages` dans GitLab 17.9.
- [Ajout automatique](https://gitlab.com/gitlab-org/gitlab/-/issues/428018) du chemin `pages.publish` à `artifacts:paths` dans GitLab 17.10.

{{< /history >}}

Par défaut, Pages recherche un dossier nommé `public` dans vos fichiers de build pour le publier.

Pour remplacer ce nom de dossier par une autre valeur, ajoutez une propriété `pages.publish` à la configuration de votre job `deploy-pages` dans `.gitlab-ci.yml`.

L'exemple suivant publie à la place un dossier nommé `dist` :

```yaml
create-pages:
  script:
    - npm run build
  pages:  # specifies that this is a Pages job
    publish: dist
```

L'exemple YAML précédent utilise des [noms de job définis par l'utilisateur](_index.md#user-defined-job-names).

Pour utiliser des variables dans le champ `pages.publish`, consultez [`pages.publish`](../../../ci/yaml/_index.md#pagespublish).

Pages utilise des artefacts pour stocker les fichiers de votre site. La valeur de `pages.publish` est donc automatiquement ajoutée à [`artifacts:paths`](../../../ci/yaml/_index.md#artifactspaths). L'exemple précédent est équivalent à :

```yaml
create-pages:
  script:
    - npm run build
  pages:
    publish: dist
  artifacts:
    paths:
      - dist
```

> [!note]
> Le mot-clé `publish` de premier niveau a été [déprécié](https://gitlab.com/gitlab-org/gitlab/-/issues/519499) dans GitLab 17.9 et doit désormais être imbriqué sous le mot-clé `pages`.

## Régénérer le domaine unique pour GitLab Pages {#regenerate-unique-domain-for-gitlab-pages}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/issues/481746) dans GitLab 17.7.

{{< /history >}}

Vous pouvez régénérer le domaine unique de votre site GitLab Pages.

Une fois le domaine régénéré, l'URL précédente n'est plus active. Toute personne qui tente d'accéder à l'ancienne URL reçoit une erreur `404`.

Prérequis

- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire dans le projet.
- Le paramètre **Utiliser un domaine unique** [doit être activé](_index.md#unique-domains) dans les paramètres Pages de votre projet.

Pour régénérer un domaine unique pour votre site GitLab Pages :

1. Dans la barre latérale gauche, sélectionnez **Déployer** > **Pages**.
1. À côté de **Accès aux pages**, appuyez sur **Régénérer le domaine unique**.
1. GitLab génère un nouveau domaine unique pour votre site Pages.

## Problèmes connus {#known-issues}

Pour obtenir la liste des problèmes connus, consultez le [gestionnaire de tickets public](https://gitlab.com/gitlab-org/gitlab/-/issues?label_name[]=Category%3APages) de GitLab.

## Dépannage {#troubleshooting}

### Erreur 404 lors de l'accès à l'URL d'un site GitLab Pages {#404-error-when-accessing-a-gitlab-pages-site-url}

Ce problème résulte très probablement d'un fichier `index.html` manquant dans le répertoire public. Si une erreur 404 se produit après le déploiement d'un site Pages, vérifiez que le répertoire public contient un fichier `index.html`. Si le fichier porte un nom différent, comme `test.html`, le site Pages reste accessible, mais le chemin complet sera nécessaire. Par exemple : `https://group-name.pages.example.com/project-slug/test.html`.

Le contenu du répertoire public peut être vérifié en [parcourant les artefacts](../../../ci/jobs/job_artifacts.md#download-job-artifacts) depuis le dernier pipeline.

Les fichiers répertoriés dans le répertoire public sont accessibles via l'URL Pages du projet.

Une erreur 404 peut également être liée à des permissions incorrectes. Si le [contrôle d'accès aux Pages](pages_access_control.md) est activé et qu'un utilisateur accède à l'URL Pages et reçoit une réponse 404, il est possible que cet utilisateur n'ait pas l'autorisation de consulter le site. Pour résoudre ce problème, vérifiez que l'utilisateur est membre du projet.

### Liens relatifs brisés {#broken-relative-links}

GitLab Pages prend en charge les URL sans extension. Cependant, en raison du problème décrit dans le [ticket n°354](https://gitlab.com/gitlab-org/gitlab-pages/-/issues/354), si une URL sans extension se termine par une barre oblique (`/`), les liens relatifs présents sur la page sont rompus.

Pour contourner ce problème :

- Assurez-vous que toutes les URL pointant vers votre site Pages comportent des extensions, ou ne se terminent pas par une barre oblique.
- Si possible, utilisez uniquement des URL absolues sur votre site.

### Impossible de lire le contenu multimédia sur Safari {#cannot-play-media-content-on-safari}

Safari exige que le serveur web prenne en charge l'[en-tête de requête Range](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/CreatingVideoforSafarioniPhone/CreatingVideoforSafarioniPhone.html#//apple_ref/doc/uid/TP40006514-SW6) pour lire votre contenu multimédia. Pour que GitLab Pages traite les requêtes HTTP Range, vous devez utiliser les deux variables suivantes dans votre fichier `.gitlab-ci.yml` :

```yaml
create-pages:
  stage: deploy
  variables:
    FF_USE_FASTZIP: "true"
    ARTIFACT_COMPRESSION_LEVEL: "fastest"
  script:
    - echo "Deploying pages"
  pages: true  # specifies that this is a Pages job and publishes the default public directory
  environment: production
```

La variable `FF_USE_FASTZIP` active le [feature flag](https://docs.gitlab.com/runner/configuration/feature-flags/#available-feature-flags) nécessaire pour [`ARTIFACT_COMPRESSION_LEVEL`](../../../ci/runners/configure_runners.md#artifact-and-cache-settings).

L'exemple YAML précédent utilise des [noms de job définis par l'utilisateur](_index.md#user-defined-job-names).

### Erreur `401` lors de l'accès à des sites GitLab Pages privés dans plusieurs onglets de navigateur {#401-error-when-accessing-private-gitlab-pages-sites-in-multiple-browser-tabs}

Lorsque vous essayez d'accéder simultanément à une URL Pages privée depuis deux onglets différents sans authentification préalable, deux valeurs `state` différentes sont renvoyées pour chaque onglet. Cependant, dans la session Pages, seule la valeur `state` la plus récente est stockée pour le client concerné. Par conséquent, après la saisie des identifiants, l'un des onglets renvoie une erreur `401 Unauthorized`.

Pour résoudre l'erreur `401`, actualisez la page.

### Échec du job `pages:deploy` {#failing-pagesdeploy-job}

Pour effectuer un déploiement avec GitLab Pages, le répertoire racine du contenu doit contenir un fichier `index.html` non vide, sans quoi le job `pages:deploy` échoue.

Le répertoire de contenu est `public/` par défaut, ou un répertoire spécifié avec le mot-clé `pages.publish` dans votre fichier `.gitlab-ci.yml`.
