---
stage: Agent Foundations
group: Agent Execution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Personnalisez le comportement de la plateforme agent GitLab Duo pour l'adapter à votre workflow, vos standards de codage et les exigences de votre projet."
title: Personnaliser GitLab Duo Agent Platform
---

Vous pouvez personnaliser la plateforme agent pour l'adapter à votre workflow, vos standards de codage ou les exigences de votre projet.

## Options de personnalisation {#customization-options}

| Méthode | Fonctionnalités d'IA[^support-varies-where] | Cas d'utilisation | Pris en charge dans |
|--------|--------------------------|-----------|--------------|
| [Utiliser des règles personnalisées](custom_rules.md) pour fournir des instructions. | \- GitLab Duo Chat<br>\- Agents<br>\- Flows, à l'exclusion du flow Code Review | \- Appliquer des préférences personnelles.<br>\- Appliquer les standards de l'équipe. | \- Interface utilisateur GitLab<br>\- Extensions d'éditeur<br>\- GitLab Duo CLI |
| [Créer un fichier AGENTS.md](agents_md.md) pour fournir des instructions. | \- GitLab Duo Chat<br>\- Flows, à l'exclusion du flow Code Review | \- Tenir compte du contexte spécifique au projet.<br>\- Organiser un monorepo.<br>\- Appliquer des conventions propres à un répertoire. | \- Interface utilisateur GitLab<br>\- Extensions d'éditeur<br>\- GitLab Duo CLI<br>\- Outils de codage IA non-GitLab |
| [Créer des instructions de revue de merge request](review_instructions.md) pour garantir des standards de revue de code cohérents et spécifiques dans votre projet. | \- flow Code Review | Appliquer :<br>\- Des règles de revue spécifiques au langage.<br>\- Des standards de sécurité.<br>\- Des exigences de qualité du code.<br>\- Des directives spécifiques aux fichiers. | \- Interface utilisateur GitLab |
| [Créer des compétences d'agent](agent_skills.md) pour fournir des compétences. | \- GitLab Duo Chat<br>\- Flows, à l'exclusion du flow Code Review | \- Fournir des compétences partageables<br>\- Ajouter des commandes slash personnalisées | \- Interface utilisateur GitLab<br>\- Extensions d'éditeur<br>\- GitLab Duo CLI<br>\- Outils de codage IA non-GitLab |

[^support-varies-where]: la prise en charge varie selon l'endroit où vous utilisez ces fonctionnalités. Pour plus d'informations, consultez la documentation de chaque méthode de personnalisation.

## Bonnes pratiques {#best-practices}

Lorsque vous personnalisez la plateforme agent, appliquez les bonnes pratiques suivantes :

- Commencez par des instructions minimales, claires et simples, et ajoutez-en au fur et à mesure des besoins. Gardez le fichier d'instructions aussi court que possible.
- Assurez-vous que les instructions sont précises et exploitables. Fournissez des exemples si nécessaire.
- Choisissez la méthode qui correspond à votre cas d'utilisation.
- Combinez plusieurs méthodes pour adapter et contrôler le comportement de GitLab Duo.
- Si vous utilisez plusieurs méthodes, envisagez la structure de fichiers suivante pour votre projet :

  ```plaintext
  Project root directory
  |─ AGENTS.md                         # Applies to multiple Duo features
  |- skills/<skill-name>/
     |─ SKILL.md                       # Applies to multiple Duo features
  |─ .gitlab/duo/
     |─ chat-rules.md                  # Custom Chat-specific rules
     |─ mr-review-instructions.yaml    # Custom code review standards
     |─ ...                            # Other configuration as needed
  ```

  Vous pouvez inclure d'autres fichiers de configuration dans le dossier `.gitlab/duo/`, tels que des [définitions de flows personnalisés](../flows/custom.md), ou un fichier de [configuration du serveur MCP](../../model_context_protocol/mcp_server.md).
- Documentez vos choix dans des commentaires pour expliquer pourquoi certaines instructions existent.
- Protégez les fichiers de personnalisation avec les [propriétaires du code](../../project/codeowners/_index.md) pour gérer les modifications.

## Sujets connexes {#related-topics}

- [Hooks pour GitLab Duo CLI](../../gitlab_duo_cli/customize.md#hooks)
