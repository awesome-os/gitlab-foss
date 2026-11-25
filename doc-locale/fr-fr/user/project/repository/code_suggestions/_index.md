---
stage: AI Coding
group: DAP Repository Flows
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Code Suggestions vous aide à écrire du code dans GitLab plus efficacement en utilisant l'IA pour suggérer du code au fur et à mesure que vous tapez."
title: Suggestions de code
---

{{< details >}}

- Édition : [Gratuite](../../../../subscriptions/gitlab_credits.md#for-the-free-tier), GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< collapsible title="Informations sur le modèle" >}}

- [LLM par défaut](../../../gitlab_duo/model_selection.md#default-models)
- LLM pour Amazon Q : Amazon Q Developer
- Disponible sur [GitLab Duo avec des modèles auto-hébergés](../../../../administration/gitlab_duo_self_hosted/_index.md)

{{< /collapsible >}}

{{< history >}}

- [Modifié](https://gitlab.com/gitlab-org/fulfillment/meta/-/issues/2031) pour exiger le module complémentaire GitLab Duo Pro à partir du 15 février 2024. Auparavant, cette fonctionnalité était incluse avec les abonnements Premium et Ultimate.
- [Modifié](https://gitlab.com/gitlab-org/fulfillment/meta/-/issues/2031) pour exiger le module complémentaire GitLab Duo Pro ou GitLab Duo Enterprise pour toutes les versions GitLab prises en charge à partir du 17 octobre 2024.
- [Prise en charge du modèle de complétion de code Qwen2.5 hébergé par Fireworks AI introduite](https://gitlab.com/groups/gitlab-org/-/work_items/15850) dans GitLab 17.6, avec un feature flag nommé `fireworks_qwen_code_completion`.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/187397) de la prise en charge du modèle de complétion de code Qwen2.5 dans GitLab 17.11.
- Activation de `Codestral` hébergé par Fireworks par défaut via le feature flag `use_fireworks_codestral_code_completion` dans GitLab 17.11.
- Modifié pour inclure GitLab Duo Core dans GitLab 18.0.
- Activation de `Codestral` hébergé par Fireworks comme modèle par défaut dans GitLab 18.1.
- [Modification](https://gitlab.com/gitlab-org/gitlab/-/issues/545489) du modèle par défaut pour la génération de code vers Claude Sonnet 4 dans GitLab 18.2.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/issues/462750) du feature flag `code_suggestions_context` dans GitLab 18.6.
- Disponibilité pour l'édition Gratuite sur GitLab.com avec des GitLab Credits dans GitLab 18.10.
- Modification de l'accès des utilisateurs GitLab Duo Core à Code Suggestions. Désormais disponible dans le cadre de la plateforme GitLab Duo Agent Platform à partir de GitLab 19.0.

{{< /history >}}

> [!note]
> Code Suggestions est disponible pour :
>
> - GitLab Duo Agent Platform. La facturation est [basée sur l'utilisation](../../../../subscriptions/gitlab_credits.md).
> - GitLab Duo Pro ou Enterprise, GitLab Duo with Amazon Q. La facturation est basée sur votre module complémentaire.

Utilisez GitLab Duo Code Suggestions pour écrire du code plus efficacement en utilisant l'IA générative pour suggérer du code pendant votre développement.

- <i class="fa-youtube-play" aria-hidden="true"></i> [Voir une démo interactive](https://gitlab.navattic.com/code-suggestions).
  <!-- Video published on 2023-12-09 --> <!-- Demo published on 2024-02-01 -->
- <i class="fa-youtube-play" aria-hidden="true"></i> [Visionner une présentation](https://youtu.be/ds7SG1wgcVM)

## Prérequis {#prerequisites}

- [GitLab Duo Core est activé](../../../gitlab_duo/turn_on_off.md#turn-gitlab-duo-core-on-or-off).
- [Code Suggestions est configuré](set_up.md) dans votre IDE.
- Vous avez défini un [espace de nommage GitLab Duo par défaut](../../../profile/preferences.md#namespace-resolution-in-your-local-environment), ou avez un projet ouvert disposant d'un accès à GitLab Duo.

> [!note]
> GitLab Duo nécessite GitLab 17.2 ou une version ultérieure. Pour l'accès à GitLab Duo Core et pour la meilleure expérience utilisateur et les meilleurs résultats, [passez à GitLab 18.0 ou une version ultérieure](../../../../update/_index.md). Les versions antérieures peuvent continuer à fonctionner, mais l'expérience peut être dégradée.

## Utiliser Code Suggestions {#use-code-suggestions}

Pour utiliser Code Suggestions :

1. Ouvrez un projet dans votre IDE.
1. Rédigez votre code. Au fur et à mesure que vous tapez, des suggestions s'affichent. Code Suggestions fournit des extraits de code ou complète la ligne actuelle, selon la position du curseur.

1. Décrivez les exigences en langage naturel. Code Suggestions génère des fonctions et des extraits de code en fonction du contexte fourni.

1. Lorsque vous recevez une suggestion, vous pouvez effectuer l'une des actions suivantes :
   - Pour accepter une suggestion, appuyez sur <kbd>Tab</kbd>.
   - Pour accepter une suggestion partielle, appuyez sur <kbd>Control</kbd>+<kbd>Flèche droite</kbd> ou sur <kbd>Command</kbd>+<kbd>Flèche droite</kbd>.
   - Pour rejeter une suggestion, appuyez sur <kbd>Échap</kbd>. Dans Neovim, appuyez sur <kbd>Control</kbd>+<kbd>E</kbd> pour quitter le menu.
   - Pour ignorer une suggestion, continuez à taper comme vous le feriez habituellement.

## Afficher plusieurs suggestions de code {#view-multiple-code-suggestions}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab-vscode-extension/-/issues/1325) dans GitLab 17.1.

{{< /history >}}

Pour une suggestion de complétion de code dans VS Code, plusieurs options de suggestions peuvent être disponibles. Pour afficher toutes les suggestions disponibles :

1. Passez le curseur sur la suggestion de complétion de code.
1. Faites défiler les alternatives. L'une ou l'autre des options :
   - Utilisez les raccourcis clavier :
     - Sur Mac, appuyez sur <kbd>Option</kbd>+<kbd>[</kbd> pour afficher la suggestion précédente, et sur <kbd>Option</kbd>+<kbd>]</kbd> pour afficher la suggestion suivante.
     - Sur Linux et Windows, appuyez sur <kbd>Alt</kbd>+<kbd>[</kbd> pour afficher la suggestion précédente, et sur <kbd>Alt</kbd>+<kbd>]</kbd> pour afficher la suggestion suivante.
   - Dans la boîte de dialogue affichée, sélectionnez la flèche droite ou gauche pour voir les options suivantes ou précédentes.
1. Appuyez sur <kbd>Tab</kbd> pour appliquer la suggestion de votre choix.

## Complétion et génération de code {#code-completion-and-generation}

Code Suggestions utilise la complétion de code et la génération de code :

|  | Complétion de code | Génération de code |
| :---- | :---- | :---- |
| Objectif | Fournit des suggestions pour compléter la ligne de code actuelle.  | Génère du nouveau code basé sur un commentaire en langage naturel. |
| Déclencheur | Se déclenche lors de la saisie, généralement avec un court délai.  | Se déclenche lorsque vous appuyez sur <kbd>Entrée</kbd> après avoir rédigé un commentaire incluant des mots-clés spécifiques. |
| Portée | Limité à la ligne actuelle ou à un petit bloc de code.  | Peut générer des méthodes, des fonctions, voire des classes entières en fonction du contexte. |
| Précision | Plus précis pour les tâches simples et les courts blocs de code.  | Est plus précis pour les tâches complexes et les grands blocs de code, car un grand modèle de langage (LLM) plus puissant est utilisé, un contexte supplémentaire est envoyé dans la requête (par exemple, les bibliothèques utilisées par le projet) et vos instructions sont transmises au LLM. |
| Comment utiliser | La complétion de code suggère automatiquement des complétions pour la ligne que vous êtes en train de saisir. | Vous rédigez un commentaire et appuyez sur <kbd>Entrée</kbd>, ou vous saisissez une fonction ou méthode vide. |
| Quand utiliser | Utilisez la complétion de code pour compléter rapidement une ou quelques lignes de code. | Utilisez la génération de code pour des tâches plus complexes, des bases de code plus importantes, lorsque vous souhaitez écrire du nouveau code from scratch à partir d'une description en langage naturel, ou lorsque le fichier que vous modifiez contient moins de cinq lignes de code. |

Code Suggestions utilise toujours ces deux fonctionnalités. Vous ne pouvez pas utiliser uniquement la génération de code ou uniquement la complétion de code. Vous ne pouvez pas non plus les désactiver séparément.

<i class="fa-youtube-play" aria-hidden="true"></i> [Voir une démo de comparaison entre complétion de code et génération de code](https://www.youtube.com/watch?v=9dsyqMt9yg4).
<!-- Video published on 2024-09-26 -->

### Bonnes pratiques pour la génération de code {#best-practices-for-code-generation}

Pour obtenir les meilleurs résultats de la génération de code :

- Soyez aussi précis que possible tout en restant concis.
- Indiquez le résultat que vous souhaitez générer (par exemple, une fonction) et fournissez des détails sur ce que vous souhaitez accomplir.
- Ajoutez des informations supplémentaires, comme le framework ou la bibliothèque que vous souhaitez utiliser.
- Ajoutez un espace ou une nouvelle ligne après chaque commentaire. Cet espace indique au générateur de code que vous avez terminé vos instructions.
- Vérifiez et ajustez le [contexte disponible pour Code Suggestions](context.md).

Par exemple, pour créer un service web Python avec des exigences spécifiques, vous pourriez écrire quelque chose comme :

```plaintext
# Create a web service using Tornado that allows a user to sign in, run a security scan, and review the scan results.
# Each action (sign in, run a scan, and review results) should be its own resource in the web service
...
```

L'IA est non déterministe, il est donc possible que vous n'obteniez pas la même suggestion à chaque fois avec la même entrée. Pour générer du code de qualité, rédigez des tâches claires, descriptives et précises.

Pour des cas d'utilisation et des bonnes pratiques, consultez la [documentation des exemples GitLab Duo](../../../gitlab_duo/use_cases.md).

## Performances {#performance}

Découvrez les temps de réponse par défaut pour Code Suggestions, ainsi que les options de streaming, de mise en cache des invites et de configuration des connexions.

### Temps de réponse {#response-time}

Code Suggestions est propulsé par un modèle d'IA générative.

- Pour la complétion de code, les suggestions sont généralement à faible latence et prennent moins d'une seconde.
- Pour la génération de code, les algorithmes ou les grands blocs de code peuvent prendre plus de cinq secondes à générer.

Votre jeton d'accès personnel établit une connexion API sécurisée vers GitLab.com ou vers votre instance GitLab. Cette connexion API transmet de manière sécurisée une fenêtre de contexte depuis votre IDE/éditeur vers la [passerelle d'IA GitLab](https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist), un service hébergé par GitLab. La passerelle appelle les API des grands modèles de langage, puis la suggestion générée est transmise en retour à votre IDE/éditeur.

### Streaming {#streaming}

Les réponses de génération de code sont diffusées en streaming dans VS Code, les IDE JetBrains, Visual Studio et Eclipse, de sorte que le code généré apparaît plus tôt. Dans Neovim, le streaming nécessite la [fonctionnalité expérimentale ghost text](../../../../editor_extensions/neovim/setup.md#configure-the-extension).

Le streaming n'est pas activé pour la complétion de code.

### Mise en cache des prompts {#prompt-caching}

{{< history >}}

- [Introduite](https://gitlab.com/gitlab-org/gitlab/-/issues/535651) dans GitLab 18.0.

{{< /history >}}

La mise en cache des invites est activée par défaut sur tous les modèles hébergés par Fireworks afin d'améliorer la latence de Code Suggestions.

Lorsque la mise en cache des invites est activée, les données d'invite de complétion de code sont temporairement stockées en mémoire par le fournisseur du modèle.

La mise en cache des prompts améliore considérablement la latence en évitant le retraitement des données de prompt et d'entrée mises en cache. Les données mises en cache ne sont jamais enregistrées dans un stockage persistant.

Vous pouvez [désactiver la mise en cache des prompts](../../../gitlab_duo/data_usage.md#turn-off-prompt-caching) :

- Sur GitLab.com : pour un groupe principal.
- Sur GitLab Self-Managed : pour une instance.

Ce paramètre s'applique à toutes les fonctionnalités de GitLab Duo Agent Platform.

### Connexions directes et indirectes {#direct-and-indirect-connections}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/issues/462791) dans GitLab 17.2 [avec un feature flag](../../../../administration/feature_flags/_index.md) nommé `code_suggestions_direct_access`. Fonctionnalité désactivée par défaut.

{{< /history >}}

Par défaut, les requêtes de complétion de code sont envoyées directement depuis l'IDE vers la passerelle d'IA afin de minimiser la latence. Pour que cette connexion directe fonctionne, l'IDE doit être en mesure de se connecter à `https://cloud.gitlab.com:443`. Si cela n'est pas possible (par exemple, en raison de restrictions réseau), vous pouvez désactiver les connexions directes pour tous les utilisateurs. Dans ce cas, les requêtes de complétion de code sont envoyées indirectement via l'instance GitLab Self-Managed, qui à son tour envoie les requêtes à la passerelle d'IA. Cela peut entraîner une latence plus élevée pour vos requêtes.

#### Configurer les connexions directes ou indirectes {#configure-direct-or-indirect-connections}

Prérequis :

- Vous devez être administrateur de l'instance GitLab Self-Managed.

{{< tabs >}}

{{< tab title="Dans la version 17.4 et les versions ultérieures" >}}

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Fonctionnalités de GitLab Duo**.
1. Sous **Méthode de connexion**, choisissez une option :
   - Pour minimiser la latence des requêtes de complétion de code, sélectionnez **Connexions directes**.
   - Pour désactiver les connexions directes pour tous les utilisateurs, sélectionnez **Connexions indirectes via GitLab Self-Managed**.
1. Sélectionnez **Enregistrer les modifications**.

{{< /tab >}}

{{< tab title="Dans la version 17.3 et les versions antérieures" >}}

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Fonctionnalités d'IA natives**.
1. Choisissez une option :
   - Pour activer les connexions directes et minimiser la latence des requêtes de complétion de code, décochez la case **Désactiver les connexions directes pour les suggestions de code**.
   - Pour désactiver les connexions directes, cochez la case **Désactiver les connexions directes pour les suggestions de code**.

{{< /tab >}}

{{< /tabs >}}

## Limitations {#limitations}

### Troncature du contenu des fichiers {#truncation-of-file-content}

En raison des limites des LLM et pour des raisons de performances, le contenu du fichier actuellement ouvert est tronqué :

- Pour la complétion de code : à 32 000 tokens (environ 128 000 caractères).
- Pour la génération de code : à 80 000 tokens (environ 320 000 caractères).

Le contenu situé au-dessus du curseur est prioritaire par rapport au contenu situé en dessous. Le contenu au-dessus du curseur est tronqué à partir du côté gauche, et le contenu en dessous du curseur est tronqué à partir du côté droit. Ces chiffres représentent la taille maximale du contexte d'entrée pour Code Suggestions.

La prise en charge de l'augmentation de la limite de génération de code est proposée dans le [ticket 585841](https://gitlab.com/gitlab-org/gitlab/-/issues/585841).

### Longueur de sortie {#output-length}

En raison des limites des LLM et pour des raisons de performances, la sortie de Code Suggestions est limitée :

- Pour la complétion de code : à 64 tokens (environ 256 caractères).
- Pour la génération de code : à 2048 tokens (environ 7168 caractères).

### Précision des résultats {#accuracy-of-results}

Nous continuons à travailler sur la précision du contenu généré dans son ensemble. Cependant, Code Suggestions peut générer des suggestions qui sont :

- Non pertinentes.
- Incomplètes.
- Susceptibles d'entraîner des pipelines en échec.
- Potentiellement non sécurisées.
- Offensantes ou inappropriées.

Lors de l'utilisation de Code Suggestions, les bonnes pratiques de revue de code s'appliquent toujours.
