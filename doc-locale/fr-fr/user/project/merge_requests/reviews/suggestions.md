---
stage: AI Coding
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Suggérez des améliorations au code dans une merge request, et commitez ces améliorations directement depuis votre navigateur."
title: Suggérer des modifications
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les relecteurs peuvent suggérer des modifications de code avec une syntaxe Markdown dans les fils de discussion de diff de merge request. L'auteur de la merge request (ou d'autres utilisateurs disposant du rôle approprié) peut appliquer tout ou partie des suggestions depuis l'interface GitLab. L'application des suggestions ajoute un commit à la merge request, dont l'auteur est l'utilisateur qui a suggéré les modifications.

## Créer des suggestions {#create-suggestions}

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et repérez votre merge request.
1. Dans le menu secondaire, sélectionnez **Modifications**.
1. Trouvez les lignes de code que vous souhaitez modifier.
   - Pour sélectionner une seule ligne, survolez le numéro de ligne et sélectionnez **Ajouter un commentaire à cette ligne** ({{< icon name="comment" >}}).
   - Pour sélectionner plusieurs lignes :
     1. Survolez le numéro de ligne et sélectionnez **Ajouter un commentaire à cette ligne** ({{< icon name="comment" >}}) :

        ![L'icône Ajouter un commentaire affichée lors du survol d'un numéro de ligne.](img/comment_on_any_diff_line_v16_6.png)

     1. Sélectionnez et faites glisser votre sélection pour inclure toutes les lignes souhaitées. Pour plus d'informations, consultez [les suggestions multi-lignes](#multi-line-suggestions).
   - Pour commenter un fichier entier plutôt que des lignes spécifiques, dans l'en-tête du fichier, sélectionnez **Commenter ce fichier** ({{< icon name="comment" >}}).
1. Dans la barre d'outils de commentaire, sélectionnez **Insérer une suggestion** ({{< icon name="doc-code" >}}). GitLab insère un bloc de code pré-rempli dans votre commentaire, comme suit :

   ````markdown
   ```suggestion:-0+0
   The content of the line you selected is shown here.
   ```
   ````

1. Modifiez le bloc de code pré-rempli pour ajouter votre suggestion.
1. Pour ajouter votre commentaire immédiatement, sélectionnez **Ajouter un commentaire**, ou utilisez le raccourci clavier :
   - macOS : <kbd>Shift</kbd>+<kbd>Command</kbd>+<kbd>Enter</kbd>
   - Tous les autres systèmes d'exploitation : <kbd>Shift</kbd>+<kbd>Control</kbd>+<kbd>Enter</kbd>
1. Pour laisser votre commentaire non publié jusqu'à la fin d'une [révision](_index.md), sélectionnez **Démarrer une révision**, ou utilisez le raccourci clavier :
   - macOS : <kbd>Command</kbd>+<kbd>Enter</kbd>
   - Tous les autres systèmes d'exploitation : <kbd>Control</kbd>+<kbd>Enter</kbd>

### Suggestions multi-lignes {#multi-line-suggestions}

{{< history >}}

- Les suggestions multi-lignes ont [été modifiées](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/172981/) dans GitLab 17.7 pour prendre en charge le rendu lorsque la suggestion contient un bloc de code.

{{< /history >}}

Lorsque vous révisez un diff de merge request, vous pouvez proposer des modifications sur plusieurs lignes (jusqu'à 200) dans une seule suggestion, en :

- Sélectionnant et faisant glisser, comme décrit dans [créer des suggestions](#create-suggestions). GitLab crée un bloc de suggestion pour vous.
- Sélectionnant une seule ligne, puis en modifiant manuellement les décalages de plage dans le bloc de suggestion.

Les décalages de plage dans la première ligne de la suggestion décrivent les numéros de ligne relatifs à la ligne sélectionnée. Les décalages spécifient les lignes que votre suggestion entend remplacer. Par exemple, cette suggestion couvre 2 lignes au-dessus et 2 lignes en dessous de la ligne commentée :

````markdown
```suggestion:-2+2
## Prevent approval by author

By default, the author of a merge request cannot approve it. To change this setting:
```
````

Une fois appliquée, la suggestion remplace depuis 2 lignes au-dessus jusqu'à 2 lignes en dessous de la ligne commentée :

![L'aperçu d'une suggestion couvrant plusieurs lignes.](img/multi-line-suggestion-preview_v16_6.png)

GitLab limite les suggestions multi-lignes à 100 lignes au-dessus et 100 lignes en dessous de la ligne de diff commentée. Cela permet jusqu'à 201 lignes modifiées par suggestion.

Les commentaires multi-lignes affichent les numéros de ligne du commentaire au-dessus du corps du commentaire :

![Les numéros de ligne indiquant la plage d'un commentaire multi-ligne.](img/multiline-comment-saved_v17_5.png)

#### Utilisation de l'éditeur de texte enrichi {#using-the-rich-text-editor}

Lorsque vous insérez des suggestions, utilisez l'[éditeur de texte enrichi](../../../rich_text_editor.md) WYSIWYG pour naviguer vers le haut et vers le bas dans les numéros de ligne du fichier source dans l'interface.

Pour ajouter ou supprimer des lignes modifiées, à côté de **De la ligne**, sélectionnez **+** ou **-**.

![Les contrôles de l'éditeur de texte enrichi pour ajuster la plage d'une suggestion multi-ligne.](img/suggest_changes_v16_2.png)

## Appliquer des suggestions {#apply-suggestions}

Prérequis :

- Vous devez être l'auteur de la merge request, ou disposer du rôle Développeur, Chargé de maintenance ou Propriétaire pour le projet.

Pour appliquer des modifications suggérées directement depuis la merge request :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et repérez votre merge request.
1. Trouvez le commentaire contenant la suggestion que vous souhaitez appliquer.
   - Pour appliquer les suggestions individuellement, sélectionnez **Appliquer la suggestion**.
   - Pour appliquer plusieurs suggestions dans un seul commit, sélectionnez **Ajouter une suggestion au lot**.
1. Facultatif. Fournissez un message de commit personnalisé pour décrire votre modification. Si vous ne fournissez pas de message personnalisé, le message de commit par défaut est utilisé.
1. Sélectionnez **Appliquer**.

Après avoir appliqué une suggestion, GitLab :

- Marque la suggestion comme **Appliquée**.
- Résout le fil de discussion.
- Crée un nouveau commit avec les modifications.
- (Si l'utilisateur dispose du rôle Développeur) Pousse la modification suggérée directement dans la base de code dans la branche de la merge request.

## Rejeter des suggestions {#reject-suggestions}

Prérequis :

- Vous devez être l'auteur de la merge request, ou disposer du rôle Développeur, Chargé de maintenance ou Propriétaire pour le projet.

Pour rejeter une modification suggérée directement depuis la merge request :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et repérez votre merge request.
1. Trouvez le commentaire contenant la suggestion que vous souhaitez rejeter.
1. Facultatif. Ajoutez une réponse indiquant la raison du rejet de la suggestion.
1. Sélectionnez **Résoudre le fil de conversation**.

## Configurer le message de commit pour les suggestions appliquées {#configure-the-commit-message-for-applied-suggestions}

GitLab utilise un message de commit par défaut lors de l'application des suggestions, mais vous pouvez le modifier. Ce message prend en charge les espaces réservés. Par exemple, le message par défaut `Apply %{suggestions_count} suggestion(s) to %{files_count} file(s)` s'affiche comme suit si vous appliquez trois suggestions à deux fichiers différents :

```plaintext
Apply 3 suggestion(s) to 2 file(s)
```

Les merge requests créées à partir de duplications utilisent le modèle défini dans le projet cible. Pour répondre aux besoins de votre projet, personnalisez ces messages et incluez d'autres variables d'espace réservé.

Prérequis :

- Vous devez disposer du rôle de Chargé de maintenance.

Pour cela :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Requêtes de fusion**.
1. Faites défiler jusqu'à **Suggestions de fusion** et modifiez le texte selon vos besoins. Pour obtenir la liste des espaces réservés utilisables dans ce message, consultez [les variables prises en charge](#supported-variables).

### Variables prises en charge {#supported-variables}

Le modèle de messages de commit pour les suggestions appliquées prend en charge les variables suivantes :

| Variable               | Description | Exemple de résultat |
|------------------------|-------------|----------------|
| `%{branch_name}`       | Le nom de la branche à laquelle les suggestions ont été appliquées. | `my-feature-branch` |
| `%{files_count}`       | Le nombre de fichiers auxquels les suggestions ont été appliquées.| `2` |
| `%{file_paths}`        | Les chemins des fichiers auxquels les suggestions ont été appliquées. Les chemins sont séparés par des virgules.| `docs/index.md, docs/about.md` |
| `%{project_path}`      | Le chemin du projet. | `my-group/my-project` |
| `%{project_name}`      | Le nom lisible du projet. | `My Project` |
| `%{suggestions_count}` | Le nombre de suggestions appliquées.| `3` |
| `%{username}`          | Le nom d'utilisateur de la personne appliquant les suggestions. | `user_1` |
| `%{user_full_name}`    | Le nom complet de la personne appliquant les suggestions. | `User 1` |
| `%{co_authored_by}`    | Noms et adresses e-mail des auteurs de suggestions au format de pied de commit Git `Co-authored-by`. | `Co-authored-by: Zane Doe <zdoe@example.com>` <br> `Co-authored-by: Blake Smith <bsmith@example.com>` |

Par exemple, pour personnaliser le message de commit afin d'obtenir `Addresses user_1's review`, définissez le texte personnalisé sur `Addresses %{username}'s review`.

## Suggestions par lot {#batch-suggestions}

Prérequis :

- Vous devez disposer d'un rôle pour le projet qui vous permet de commiter sur la branche source.

Pour réduire le nombre de commits ajoutés à votre branche, appliquez plusieurs suggestions dans un seul commit.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Code** > **Requêtes de fusion** et repérez votre merge request.
1. Pour chaque suggestion que vous souhaitez appliquer, sélectionnez **Ajouter une suggestion au lot**.
1. Facultatif. Pour supprimer une suggestion, sélectionnez **Supprimer du lot**.
1. Après avoir ajouté les suggestions souhaitées, sélectionnez **Appliquer les suggestions**.

   > [!warning]
   > Si vous appliquez un lot de suggestions contenant des modifications provenant de plusieurs auteurs, le commit résultant vous crédite en tant qu'auteur. Si vous configurez votre projet pour [empêcher les approbations de la part des utilisateurs qui ajoutent des commits](../approvals/settings.md#prevent-approvals-by-users-who-add-commits), vous n'êtes plus un approbateur éligible pour cette merge request.

1. Facultatif. Fournissez un message de commit personnalisé pour les [suggestions par lot](#batch-suggestions) afin de décrire votre modification. Si vous n'en spécifiez pas, le message de commit par défaut est utilisé.

## Sujets connexes {#related-topics}

- [API Suggestions](../../../../api/suggestions.md)
