---
stage: AI Coding
group: DAP Repository Flows
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Code Suggestions prend en charge plusieurs éditeurs et langages.
title: Extensions et langages pris en charge
---

Code Suggestions est disponible dans les extensions d'éditeur suivantes et pour les langages suivants.

## Extensions d'éditeur prises en charge {#supported-editor-extensions}

Pour utiliser Code Suggestions, utilisez l'une des extensions d'éditeur suivantes :

| IDE                                                             | Extension |
|-----------------------------------------------------------------|-----------|
| Visual Studio Code (VS Code)                                    | [GitLab for VS Code](https://marketplace.visualstudio.com/items?itemName=GitLab.gitlab-workflow) |
| [GitLab Web IDE (VS Code dans le cloud)](../../web_ide/_index.md) | Aucune configuration requise. |
| Microsoft Visual Studio (2022 pour Windows)                      | [Extension GitLab pour Visual Studio](https://marketplace.visualstudio.com/items?itemName=GitLab.GitLabExtensionForVisualStudio) |
| JetBrains IDEs                                                  | [Plugin GitLab Duo pour JetBrains](https://plugins.jetbrains.com/plugin/22325-gitlab-duo) |
| Neovim                                                          | [Plugin `gitlab.vim`](https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim) |
| Eclipse                                                          | [GitLab for Eclipse](../../../../editor_extensions/eclipse/setup.md) |

Un [serveur de langage GitLab](https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp) est utilisé dans VS Code, les JetBrains IDEs, Visual Studio, Eclipse et Neovim. Le serveur de langage permet des itérations plus rapides sur davantage de plateformes. Vous pouvez également le configurer pour prendre en charge Code Suggestions dans des IDEs pour lesquels GitLab ne fournit pas de support officiel.

Vous pouvez exprimer votre intérêt pour la prise en charge d'autres extensions d'IDE [dans ce ticket](https://gitlab.com/gitlab-org/editor-extensions/meta/-/issues/78).

## Langages pris en charge par IDE {#supported-languages-by-ide}

Dans VS Code, Code Suggestions fonctionne avec tous les langages pris en charge par l'IDE, à l'exception du texte brut. Pour certains langages, comme Kotlin, Scala ou Terraform, vous devez installer une extension tierce pour ajouter la prise en charge du langage dans VS Code. Vous pouvez [désactiver Code Suggestions pour des langages spécifiques](#manage-languages-for-code-suggestions).

Pour les autres IDEs, le tableau suivant liste les langages pris en charge par défaut par Code Suggestions. Code Suggestions fonctionne également avec d'autres langages, mais vous devez [ajouter la prise en charge manuellement](#add-support-for-more-languages).

| Langage                            | Web IDE     | JetBrains IDEs | Visual Studio 2022 pour Windows | Neovim                   | Eclipse |
|-------------------------------------|-------------|----------------|--------------------------------|--------------------------|---------|
| C                                   | {{< yes >}} | {{< no >}}     | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| C++                                 | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| C#                                  | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| CSS                                 | {{< yes >}} | {{< no >}}     | {{< no >}}                     | {{< no >}}               | {{< no >}} |
| Go                                  | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Google SQL                          | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< no >}} |
| HAML                                | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| HTML                                | {{< yes >}} | {{< no >}}     | {{< no >}}                     | {{< no >}}               | {{< no >}} |
| Java                                | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| JavaScript                          | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Kotlin                              | {{< no >}}  | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Markdown                            | {{< yes >}} | {{< no >}}     | {{< no >}}                     | {{< no >}}               | {{< no >}} |
| PHP                                 | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Python                              | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Ruby                                | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Rust                                | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Scala                               | {{< no >}}  | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Scripts shell (uniquement `bash`)         | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Svelte                              | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Swift                               | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| TypeScript (fichiers `.ts` et `.tsx`) | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |
| Terraform                           | {{< no >}}  | {{< yes >}}    | {{< no >}}                     | {{< yes >}}[^requires-third-party] | {{< yes >}} |
| Vue                                 | {{< yes >}} | {{< yes >}}    | {{< yes >}}                    | {{< yes >}}              | {{< yes >}} |

[^requires-third-party]: Neovim nécessite une extension tierce qui fournit le type de fichier `terraform`.

> [!note]
> Certains langages ne sont pas pris en charge dans tous les JetBrains IDEs, ou peuvent nécessiter une prise en charge supplémentaire via des plugins. Consultez la documentation JetBrains pour obtenir des informations spécifiques à votre IDE.

## Prise en charge de l'Infrastructure as Code (IaC) {#support-for-infrastructure-as-code-iac}

Code Suggestions fonctionne avec les interfaces d'Infrastructure as Code, notamment :

- Kubernetes Resource Model (KRM)
- Google Cloud CLI
- Terraform

## Gérer les langages pour Code Suggestions {#manage-languages-for-code-suggestions}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab-vscode-extension/-/blob/main/CHANGELOG.md#4210-2024-07-16) dans GitLab for VS Code 4.21.0
- Les suggestions pour tous les langages sont [activées](https://gitlab.com/gitlab-org/gitlab-vscode-extension/-/releases/v6.92.0) par défaut dans GitLab for VS Code 6.92.0 lors du release GitLab 19.5.

{{< /history >}}

Dans VS Code, Code Suggestions est activé pour tous les langages par défaut. Vous pouvez le désactiver pour des langages spécifiques.

Pour activer ou désactiver Code Suggestions pour le langage du fichier actuel :

1. Dans VS Code, ouvrez un fichier dans le langage souhaité.
1. Ouvrez la palette de commandes :
   - Pour macOS, appuyez sur <kbd>Command</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>.
   - Pour Windows ou Linux, appuyez sur <kbd>Control</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>.
1. Sélectionnez **GitLab : activer ou désactiver les suggestions de code pour le langage actuel**.

Vous pouvez également sélectionner l'icône GitLab Duo dans la barre d'état, puis sélectionner l'option pour activer ou désactiver Code Suggestions pour le langage actuel.

Pour désactiver Code Suggestions pour plusieurs langages :

1. Dans VS Code, ouvrez l'éditeur de paramètres :
   - Pour macOS, appuyez sur <kbd>Commande</kbd>+<kbd>,</kbd>.
   - Pour Windows ou Linux, appuyez sur <kbd>Ctrl</kbd>+<kbd>,</kbd>.
1. Sélectionnez **Extensions** > **GitLab** > **GitLab Duo**.
1. Sous **GitLab › Duo Code Suggestions : Langages désactivés**, sélectionnez **Ajouter un élément**.
1. Saisissez l'[identifiant de langage](https://code.visualstudio.com/docs/languages/identifiers#_known-language-identifiers), par exemple `python` ou `markdown`.
1. Sélectionnez **OK**.

Vos modifications sont enregistrées automatiquement et prennent effet immédiatement.

Lorsque vous désactivez Code Suggestions pour un langage, l'icône GitLab Duo change pour indiquer que les suggestions ne sont pas disponibles pour ce langage.

Si vous avez désactivé des langages dans le paramètre **Enabled Supported Languages** d'une version antérieure de l'extension, ils sont ajoutés à **Disabled Languages** lors de la mise à jour.

## Ajouter la prise en charge d'autres langages {#add-support-for-more-languages}

Dans VS Code, vous n'avez pas besoin d'ajouter des langages. Code Suggestions fonctionne avec tous les langages, à l'exception du texte brut.

Dans les autres IDEs, si le langage souhaité ne dispose pas de Code Suggestions par défaut, vous pouvez ajouter la prise en charge de votre langage localement. Cependant, Code Suggestions peut ne pas fonctionner comme prévu.

{{< tabs >}}

{{< tab title="JetBrains IDEs" >}}

Prérequis :

- Vous avez installé et activé le [plugin GitLab Duo pour JetBrains IDEs](../../../../editor_extensions/jetbrains_ide/_index.md).
- Vous avez suivi les instructions de [configuration de l'extension JetBrains](../../../../editor_extensions/jetbrains_ide/setup.md) et autorisé l'extension à accéder à votre compte GitLab.

Pour cela :

1. Recherchez le langage souhaité dans la liste des [identifiants de langage](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentItem). Vous aurez besoin de l'identifiant pour vos langages lors d'une étape ultérieure.
1. Dans votre IDE, dans la barre supérieure, sélectionnez le nom de votre IDE, puis sélectionnez **Paramètres**.
1. Dans la barre latérale gauche, sélectionnez **Outils** > **GitLab Duo**.
1. Sous **Langages activés pour les suggestions de code** > **Langages supplémentaires**, ajoutez l'identifiant pour chaque langage que vous souhaitez prendre en charge. Les identifiants doivent être en minuscules, par exemple `html`. Séparez les identifiants multiples par des virgules, par exemple `html,powershell,latex`, et n'ajoutez pas de points en début d'identifiant.
1. Sélectionnez **OK**.

{{< /tab >}}

{{< tab title="Eclipse" >}}

Prérequis :

- Vous avez installé et activé le [plugin GitLab for Eclipse](../../../../editor_extensions/eclipse/_index.md).
- Vous avez suivi les instructions de [configuration d'Eclipse](../../../../editor_extensions/eclipse/setup.md) et autorisé l'extension à accéder à votre compte GitLab.

Pour cela :

1. Dans la barre d'outils inférieure d'Eclipse, sélectionnez l'icône GitLab.
1. Sélectionnez **Afficher les paramètres**.
1. Faites défiler jusqu'à la section **Langages activés pour les suggestions de code**.
1. Dans **Langages supplémentaires**, ajoutez une liste d'identifiants de langage séparés par des virgules. N'ajoutez pas de points en début d'identifiant. Par exemple, utilisez `html`, `md` et `powershell`.

{{< /tab >}}

{{< /tabs >}}
