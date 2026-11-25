---
stage: Application Security Testing
group: Threat Research
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Analyse des sources malveillantes
description: Détectez les références à des domaines malveillants connus dans votre code source.
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com
- Statut : version expérimentale

{{< /details >}}

{{< history >}}

- [Introduit sur GitLab.com](https://gitlab.com/groups/gitlab-org/-/work_items/22809) en tant que [version expérimentale](../../../policy/development_stages_support.md#experiment) dans GitLab 19.3.

{{< /history >}}

L'analyse des sources malveillantes recherche les références à des domaines externes malveillants connus dans votre dépôt, tels que les CDN impliqués dans l'attaque de la chaîne d'approvisionnement polyfill.io. Chaque référence est signalée comme une vulnérabilité SAST.

Pour aider à décider de l'avenir de cette version expérimentale, partagez vos commentaires dans le [ticket 634760](https://gitlab.com/gitlab-org/gitlab/-/work_items/634760).

## Activer l'analyse des sources malveillantes {#turn-on-malicious-sources-scanning}

Pour activer l'analyse des sources malveillantes, ajoutez le [composant CI/CD des sources malveillantes](https://gitlab.com/explore/catalog/security-products/experiments/malicious-sources) à votre fichier `.gitlab-ci.yml` :

```yaml
include:
  - component: gitlab.com/security-products/experiments/malicious-sources/malicious-sources@0.2.0
```

Le composant ajoute un job `malicious-sources-scan` à l'étape `test`. Les résultats apparaissent dans le [rapport de vulnérabilités](../vulnerability_report/_index.md) et dans les merge requests.

## Domaines détectés {#detected-domains}

L'analyse des sources malveillantes détecte les références à ces domaines, avec une gravité `Critical` :

- `bootcdn.net`
- `bootcss.com` et `cdn.bootcss.com`
- `polyfill.com`
- `polyfill.io` et `cdn.polyfill.io`
- `staticfile.net` et `cdn.staticfile.net`
- `staticfile.org` et `cdn.staticfile.org`
- `unionadjs.com`

L'analyseur fait correspondre les références `https://`, `http://` et relatives au protocole (`//`) sans tenir compte de la casse.

## Exclure des chemins {#exclude-paths}

Pour ignorer des fichiers et des répertoires, définissez `SAST_EXCLUDED_PATHS` sur une liste de modèles de style gitignore séparés par des virgules. Le répertoire `.git` est toujours exclu.

```yaml
variables:
  SAST_EXCLUDED_PATHS: "node_modules, vendor, **/*.min.js"
```

## Ajouter des règles personnalisées {#add-custom-rules}

Pour détecter d'autres domaines, définissez `MALICIOUS_SOURCES_CUSTOM_RULES` sur une liste YAML de règles. Les règles personnalisées sont ajoutées aux règles intégrées.

```yaml
variables:
  MALICIOUS_SOURCES_CUSTOM_RULES: |
    - rule_id: malicious.example.test
      substring: //malicious.example.test
      severity: High
      title: "Malicious CDN: malicious.example.test"
      description: "Known malicious CDN observed in supply chain attacks."
```

| Champ              | Obligatoire | Description |
|--------------------|----------|-------------|
| `rule_id`          | Oui      | Identifiant unique. Pour remplacer une règle intégrée, utilisez le domaine de la règle comme identifiant. |
| `substring`        | Oui      | Texte littéral à faire correspondre sur chaque ligne. Les expressions régulières ne sont pas prises en charge. |
| `severity`         | Oui      | L'une des valeurs `Info`, `Low`, `Medium`, `High` ou `Critical`. |
| `title`            | Oui      | Nom affiché dans le résultat. |
| `description`      | Oui      | Explication affichée dans le rapport de vulnérabilités. |
| `case_insensitive` | Non       | Lorsque la valeur est `true`, la correspondance ignore la casse. La valeur par défaut est `false`. |
| `disabled`         | Non       | Lorsque la valeur est `true`, la règle est supprimée. La valeur par défaut est `false`. |

Pour désactiver une règle intégrée, définissez `disabled: true` sur son domaine :

```yaml
variables:
  MALICIOUS_SOURCES_CUSTOM_RULES: |
    - rule_id: cdn.polyfill.io
      disabled: true
```

Si le YAML n'est pas valide, l'analyse échoue avec une erreur.
