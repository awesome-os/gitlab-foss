---
stage: AI Coding
group: DAP Repository Flows
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Code Suggestions vous aide à écrire du code dans GitLab plus efficacement en utilisant l'IA pour suggérer du code au fur et à mesure de votre saisie."
title: Suggestions de code
---

{{< details >}}

- Édition : [Gratuite](../../../subscriptions/gitlab_credits.md#for-the-free-tier), GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< collapsible title="Informations sur le modèle" >}}

- [LLM par défaut](../../gitlab_duo/model_selection.md#default-models)
- LLM pour Amazon Q : Amazon Q Developer
- Disponible sur [GitLab Duo avec des modèles auto-hébergés](../../../administration/gitlab_duo_self_hosted/_index.md)

{{< /collapsible >}}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/fulfillment/meta/-/issues/2031) pour exiger le module complémentaire GitLab Duo Pro à partir du 15 février 2024. Auparavant, cette fonctionnalité était incluse avec les abonnements Premium et Ultimate.
- [Modification](https://gitlab.com/gitlab-org/fulfillment/meta/-/issues/2031) pour exiger le module complémentaire GitLab Duo Pro ou GitLab Duo Enterprise pour toutes les versions GitLab prises en charge à partir du 17 octobre 2024.
- [Introduction de la prise en charge du modèle de complétion de code Qwen2.5 hébergé par Fireworks AI](https://gitlab.com/groups/gitlab-org/-/work_items/15850) dans GitLab 17.6, avec un feature flag nommé `fireworks_qwen_code_completion`.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/187397) de la prise en charge du modèle de complétion de code Qwen2.5 dans GitLab 17.11.
- Activation par défaut de `Codestral` hébergé par Fireworks via le feature flag `use_fireworks_codestral_code_completion` dans GitLab 17.11.
- Modification pour inclure GitLab Duo Core dans GitLab 18.0.
- Activation de `Codestral` hébergé par Fireworks comme modèle par défaut dans GitLab 18.1.
- [Modification](https://gitlab.com/gitlab-org/gitlab/-/issues/545489) du modèle par défaut pour la génération de code en faveur de Claude Sonnet 4 dans GitLab 18.2.
- [Suppression](https://gitlab.com/gitlab-org/gitlab/-/issues/462750) du feature flag `code_suggestions_context` dans GitLab 18.6.
- Disponibilité pour l'édition Gratuite sur GitLab.com avec des GitLab Credits dans GitLab 18.10.
- Modification de l'accès des utilisateurs GitLab Duo Core à Code Suggestions. Désormais disponible dans le cadre de la plateforme d'agents GitLab Duo à partir de GitLab 19.0.

{{< /history >}}

> [!note]
> Code Suggestions est disponible pour :
>
> - GitLab Duo Agent Platform. La facturation est [basée sur l'utilisation](../../../subscriptions/gitlab_credits.md).
> - GitLab Duo Pro ou Enterprise, GitLab Duo with Amazon Q. La facturation est basée sur votre module complémentaire.

Utilisez GitLab Duo Code Suggestions pour écrire du code plus efficacement en utilisant l'IA générative pour suggérer du code pendant que vous développez.

- <i class="fa-youtube-play" aria-hidden="true"></i> [Voir une démo interactive](https://gitlab.navattic.com/code-suggestions).
  <!-- Video published on 2023-12-09 --> <!-- Demo published on 2024-02-01 -->
- <i class="fa-youtube-play" aria-hidden="true"></i> [Visionner une présentation](https://youtu.be/ds7SG1wgcVM)

## Prérequis {#prerequisites}

- [GitLab Duo Core est activé](../turn_on_off.md#turn-gitlab-duo-core-on-or-off).
- [Code Suggestions est configuré](../../project/repository/code_suggestions/set_up.md) dans votre IDE.
- Vous avez défini un [espace de nommage GitLab Duo par défaut](../../profile/preferences.md#namespace-resolution-in-your-local-environment), ou vous avez un projet ouvert disposant d'un accès à GitLab Duo.

> [!note]
> GitLab Duo nécessite GitLab 17.2 ou une version ultérieure. Pour accéder à GitLab Duo Core et bénéficier de la meilleure expérience utilisateur et des meilleurs résultats, [passez à GitLab 18.0 ou une version ultérieure](../../../update/_index.md). Les versions antérieures pourraient continuer à fonctionner, mais l'expérience pourrait être dégradée.

## Utiliser Code Suggestions {#use-code-suggestions}

Pour utiliser Code Suggestions :

1. Ouvrez un projet dans votre IDE.
1. Rédigez votre code. Au fur et à mesure de votre saisie, des suggestions s'affichent. Code Suggestions fournit des extraits de code ou complète la ligne actuelle, selon la position du curseur.
1. Décrivez les exigences en langage naturel. Code Suggestions génère des fonctions et des extraits de code en fonction du contexte fourni.
1. Lorsque vous recevez une suggestion, vous pouvez effectuer l'une des actions suivantes :
   - Pour accepter une suggestion, appuyez sur <kbd>Tab</kbd>.
   - Pour accepter une suggestion partielle, appuyez sur <kbd>Control</kbd>+<kbd>Flèche droite</kbd> ou sur <kbd>Command</kbd>+<kbd>Flèche droite</kbd>.
   - Pour rejeter une suggestion, appuyez sur <kbd>Esc</kbd>. Dans Neovim, appuyez sur <kbd>Control</kbd>+<kbd>E</kbd> pour fermer le menu.
   - Pour ignorer une suggestion, continuez à taper comme vous le faites habituellement.

## Afficher plusieurs suggestions de code {#view-multiple-code-suggestions}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab-vscode-extension/-/issues/1325) dans GitLab 17.1.

{{< /history >}}

Pour une suggestion de complétion de code dans VS Code, plusieurs options de suggestion peuvent être disponibles. Pour afficher toutes les suggestions disponibles :

1. Survolez la suggestion de complétion de code.
1. Faites défiler les alternatives. L'une ou l'autre des options :
   - Utilisez les raccourcis clavier :
     - Sur Mac, appuyez sur <kbd>Option</kbd>+<kbd>[</kbd> pour afficher la suggestion précédente, et sur <kbd>Option</kbd>+<kbd>]</kbd> pour afficher la suggestion suivante.
     - Sur Linux et Windows, appuyez sur <kbd>Alt</kbd>+<kbd>[</kbd> pour afficher la suggestion précédente, et sur <kbd>Alt</kbd>+<kbd>]</kbd> pour afficher la suggestion suivante.
   - Dans la boîte de dialogue affichée, sélectionnez la flèche droite ou gauche pour accéder aux options suivantes ou précédentes.
1. Appuyez sur <kbd>Tab</kbd> pour appliquer la suggestion de votre choix.

## Complétion et génération de code {#code-completion-and-generation}

Code Suggestions utilise la complétion de code et la génération de code :

|  | Complétion de code | Génération de code |
| :---- | :---- | :---- |
| Objectif | Fournit des suggestions pour compléter la ligne de code actuelle.  | Génère du nouveau code à partir d'un commentaire en langage naturel. |
| Déclencheur | Se déclenche lors de la saisie, généralement avec un court délai.  | Se déclenche en appuyant sur <kbd>Entrée</kbd> après avoir rédigé un commentaire contenant des mots-clés spécifiques. |
| Portée | Limité à la ligne actuelle ou à un petit bloc de code.  | Peut générer des méthodes, des fonctions, voire des classes entières en fonction du contexte. |
| Précision | Plus précis pour les tâches simples et les courts blocs de code.  | Est plus précis pour les tâches complexes et les grands blocs de code, car un grand modèle de langage (LLM) plus puissant est utilisé, un contexte supplémentaire est envoyé dans la requête (par exemple, les bibliothèques utilisées par le projet) et vos instructions sont transmises au LLM. |
| Comment utiliser | La complétion de code suggère automatiquement des complétions pour la ligne que vous saisissez. | Vous rédigez un commentaire et appuyez sur <kbd>Entrée</kbd>, ou vous saisissez une fonction ou méthode vide. |
| Quand utiliser | Utilisez la complétion de code pour compléter rapidement une ou quelques lignes de code. | Utilisez la génération de code pour des tâches plus complexes, des bases de code plus importantes, lorsque vous souhaitez écrire du nouveau code à partir de zéro en vous basant sur une description en langage naturel, ou lorsque le fichier que vous modifiez comporte moins de cinq lignes de code. |

Code Suggestions utilise toujours ces deux fonctionnalités. Vous ne pouvez pas utiliser uniquement la génération de code ou uniquement la complétion de code. Vous ne pouvez pas non plus les désactiver séparément.

<i class="fa-youtube-play" aria-hidden="true"></i> [Voir une démo comparative entre la complétion de code et la génération de code](https://www.youtube.com/watch?v=9dsyqMt9yg4).
<!-- Video published on 2024-09-26 -->

### Bonnes pratiques pour la génération de code {#best-practices-for-code-generation}

Pour obtenir les meilleurs résultats de la génération de code :

- Soyez aussi précis que possible tout en restant concis.
- Indiquez le résultat que vous souhaitez générer (par exemple, une fonction) et fournissez des détails sur ce que vous souhaitez accomplir.
- Ajoutez des informations supplémentaires, comme le framework ou la bibliothèque que vous souhaitez utiliser.
- Ajoutez un espace ou un saut de ligne après chaque commentaire. Cet espace indique au générateur de code que vous avez terminé vos instructions.
- Examinez et ajustez le [contexte disponible pour Code Suggestions](../../project/repository/code_suggestions/context.md#change-what-code-suggestions-uses-for-context).

Par exemple, pour créer un service web Python avec des exigences spécifiques, vous pourriez écrire quelque chose comme :

```plaintext
# Create a web service using Tornado that allows a user to sign in, run a security scan, and review the scan results.
# Each action (sign in, run a scan, and review results) should be its own resource in the web service
...
```

L'IA est non déterministe, ce qui signifie que vous n'obtiendrez pas forcément la même suggestion à chaque fois avec la même entrée. Pour générer du code de qualité, rédigez des tâches claires, descriptives et précises.

Pour les cas d'usage et les bonnes pratiques, consultez la [documentation des exemples GitLab Duo](../../gitlab_duo/use_cases.md).

## Précision des résultats {#accuracy-of-results}

Nous continuons à travailler sur la précision du contenu généré dans son ensemble. Cependant, Code Suggestions peut générer des suggestions qui sont :

- Non pertinentes.
- Incomplètes.
- Susceptibles d'entraîner des échecs de pipelines.
- Potentiellement non sécurisées.
- Offensantes ou inappropriées.

Lors de l'utilisation de Code Suggestions, les bonnes pratiques de revue de code s'appliquent toujours.

## Sujets connexes {#related-topics}

- [Extensions et langages pris en charge](../../project/repository/code_suggestions/supported_extensions.md)
- [Limitations de Code Suggestions](../../project/repository/code_suggestions/_index.md#limitations)
- [Mise en cache des prompts](../../project/repository/code_suggestions/_index.md#prompt-caching)
- [Connexions directes et indirectes](../../project/repository/code_suggestions/_index.md#direct-and-indirect-connections)
- [Conscience contextuelle de Code Suggestions](../../project/repository/code_suggestions/context.md)
- [Dépannage de Code Suggestions](../../project/repository/code_suggestions/troubleshooting.md)
- [Repository X-Ray](../../project/repository/code_suggestions/repository_xray.md)
