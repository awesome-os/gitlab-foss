---
stage: Plan
group: Planner Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Markdown spécifique aux wikis
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

## Liens {#links}

Les rubriques suivantes expliquent le comportement des liens dans les wikis.

Lorsque vous créez un lien vers des pages wiki, utilisez le slug de la page plutôt que son nom. Un slug de page est la version compatible avec les URL du titre de la page, dans laquelle les espaces sont remplacés par des tirets et les caractères spéciaux sont supprimés ou convertis. Par exemple, une page intitulée « How to Use GitLab » a le slug `How-to-Use-GitLab`.

### Liens de type wiki {#wiki-style-links}

En plus des [liens Markdown](../../markdown.md#links) standard, les wikis prennent en charge une syntaxe de lien de type wiki spéciale qui simplifie la création de liens entre les pages wiki.

#### Syntaxe à double crochets {#double-bracket-syntax}

Vous pouvez créer des liens vers des pages wiki en utilisant des doubles crochets :

```markdown
[[Home]]
```

Cette syntaxe crée un lien vers une page wiki avec le slug `Home`. Si la page n'existe pas, lorsque vous sélectionnez le lien, vous pouvez créer cette page.

Lorsque le slug de la page contient des tirets, le lien affiche le slug tel quel :

```markdown
[[Home-page-new-slug]]
```

Cela affiche `Home-page-new-slug` comme texte du lien.

#### Syntaxe à double crochets avec texte personnalisé {#double-bracket-syntax-with-custom-text}

Si le slug de la page est différent du titre que vous souhaitez afficher, utilisez le caractère pipe (`|`) pour séparer le texte affiché du slug de la page :

```markdown
[[How to use GitLab|how-to-use-gitlab]]
```

Cela affiche « How to use GitLab » comme texte du lien, mais renvoie vers la page avec le slug `how-to-use-gitlab`.

Vous pouvez également utiliser cette syntaxe pour fournir un titre plus lisible pour les pages avec des slugs comportant des tirets :

```markdown
[[Home page (renamed)|Home-page-new-slug]]
```

Cela affiche « Home page (renamed) » comme texte du lien, mais renvoie vers la page avec le slug `Home-page-new-slug`.

#### Syntaxe alternative pour les pages wiki {#alternative-wiki-page-syntax}

Vous pouvez également utiliser la syntaxe `[wiki_page:PAGE_SLUG]` :

```markdown
[wiki_page:Home]
```

Pour les références inter-projets, spécifiez le chemin complet du projet :

```markdown
[wiki_page:namespace/project:Home]
[wiki_page:group1/subgroup:Home]
```

#### Reconnaissance automatique des URL {#automatic-url-recognition}

Lorsque vous collez une URL complète vers une page wiki sans aucune mise en forme Markdown, GitLab la convertit automatiquement en lien et affiche le slug de la page avec des espaces à la place des tirets :

```markdown
https://gitlab.com/namespace/project/-/wikis/Home-page-new-slug
```

Cela s'affiche automatiquement sous forme de lien avec le texte « Home page new slug » (tirets convertis en espaces).

### Lien direct vers une page {#direct-page-link}

Un lien direct vers une page inclut le slug d'une page qui pointe vers cette page, au niveau de base du wiki.

Cet exemple crée un lien vers une page `documentation` à la racine de votre wiki :

```markdown
[Link to Documentation](documentation-top-page)
```

### Lien direct vers un fichier {#direct-file-link}

Un lien direct vers un fichier pointe vers l'extension d'un fichier, par rapport à la page actuelle.

Si l'exemple suivant se trouve sur une page à l'emplacement `<your_wiki>/documentation/related`, il renvoie vers `<your_wiki>/documentation/file.md` :

```markdown
[Link to File](file.md)
```

### Lien hiérarchique {#hierarchical-link}

Un lien hiérarchique peut être construit par rapport à la page wiki actuelle en utilisant des chemins relatifs tels que `./<page>` ou `../<page>`.

Si cet exemple se trouve sur une page à l'emplacement `<your_wiki>/documentation/main`, il renvoie vers `<your_wiki>/documentation/related` :

```markdown
[Link to Related Page](related)
```

Si cet exemple se trouve sur une page à l'emplacement `<your_wiki>/documentation/related/content`, il renvoie vers `<your_wiki>/documentation/main` :

```markdown
[Link to Related Page](../main)
```

Si cet exemple se trouve sur une page à l'emplacement `<your_wiki>/documentation/main`, il renvoie vers `<your_wiki>/documentation/related.md` :

```markdown
[Link to Related Page](related.md)
```

Si cet exemple se trouve sur une page à l'emplacement `<your_wiki>/documentation/related/content`, il renvoie vers `<your_wiki>/documentation/main.md` :

```markdown
[Link to Related Page](../main.md)
```

### Lien racine {#root-link}

Un lien racine commence par `/` et est relatif à la racine du wiki.

Cet exemple crée un lien vers `<wiki_root>/documentation` :

```markdown
[Link to Related Page](/documentation)
```

Cet exemple crée un lien vers `<wiki_root>/documentation.md` :

```markdown
[Link to Related Page](/documentation.md)
```

## Éditeur diagrams.net {#diagramsnet-editor}

Dans les wikis, vous pouvez utiliser l'éditeur [diagrams.net](https://app.diagrams.net/) pour créer des diagrammes. Vous pouvez également modifier des diagrammes créés avec l'éditeur diagrams.net. L'éditeur de diagrammes est disponible dans l'éditeur en texte brut comme dans l'éditeur en texte enrichi.

Pour plus d'informations, consultez [Diagrams.net](../../../administration/integration/diagrams_net.md).

### Éditeur en texte brut {#plain-text-editor}

Pour créer un diagramme dans l'éditeur en texte brut :

1. Sur la page wiki que vous souhaitez modifier, sélectionnez **Modifier**.
1. Dans la zone de texte, assurez-vous d'utiliser l'éditeur en texte brut (le bouton en bas à gauche indique **Passer à l'édition en texte enrichi**).
1. Dans la barre d'outils de l'éditeur, sélectionnez **Insérer ou modifier un diagramme** ({{< icon name="diagram" >}}).
1. Créez le diagramme dans l'éditeur [app.diagrams.net](https://app.diagrams.net/).
1. Sélectionnez **Enregistrer et quitter**.

Une référence d'image Markdown vers le diagramme est insérée dans le contenu du wiki.

Pour modifier un diagramme dans l'éditeur en texte brut :

1. Sur la page wiki que vous souhaitez modifier, sélectionnez **Modifier**.
1. Dans la zone de texte, assurez-vous d'utiliser l'éditeur en texte brut (le bouton en bas à gauche indique **Passer à l'édition en texte enrichi**).
1. Positionnez votre curseur dans la référence d'image Markdown qui contient le diagramme.
1. Sélectionnez **Insérer ou modifier un diagramme** ({{< icon name="diagram" >}}).
1. Modifiez le diagramme dans l'éditeur [app.diagrams.net](https://app.diagrams.net/).
1. Sélectionnez **Enregistrer et quitter**.

Une référence d'image Markdown vers le diagramme est insérée dans le contenu du wiki, remplaçant le diagramme précédent.

### Éditeur en texte enrichi {#rich-text-editor}

Pour créer un diagramme dans l'éditeur en texte enrichi :

1. Sur la page wiki que vous souhaitez modifier, sélectionnez **Modifier**.
1. Dans la zone de texte, assurez-vous d'utiliser l'éditeur en texte enrichi (le bouton en bas à gauche indique **Passer à l'édition en texte brut**).
1. Dans la barre d'outils de l'éditeur, sélectionnez **Plus d'options** ({{< icon name="plus" >}}).
1. Dans la liste déroulante, sélectionnez **Créer ou modifier un diagramme**.
1. Créez le diagramme dans l'éditeur [app.diagrams.net](https://app.diagrams.net/).
1. Sélectionnez **Enregistrer et quitter**.

Le diagramme tel qu'il est visualisé dans l'éditeur diagrams.net est inséré dans le contenu du wiki.

Pour modifier un diagramme dans l'éditeur en texte enrichi :

1. Sur la page wiki que vous souhaitez modifier, sélectionnez **Modifier**.
1. Dans la zone de texte, assurez-vous d'utiliser l'éditeur en texte enrichi (le bouton en bas à gauche indique **Passer à l'édition en texte brut**).
1. Sélectionnez le diagramme que vous souhaitez modifier.
1. Dans la barre d'outils flottante, sélectionnez **Modifier le diagramme** ({{< icon name="diagram" >}}).
1. Modifiez le diagramme dans l'éditeur [app.diagrams.net](https://app.diagrams.net/).
1. Sélectionnez **Enregistrer et quitter**.

Le diagramme sélectionné est remplacé par une version mise à jour.
