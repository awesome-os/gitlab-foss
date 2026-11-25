---
stage: Security Risk Management
group: Security Policies
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Politiques d'approbation des licences"
description: "Comprendre comment spécifier des critères à l'aide d'une politique d'approbation des licences pour l'approbation d'une merge request avant qu'elle puisse être fusionnée. S'applique uniquement aux branches cibles protégées."
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Utilisez les politiques d'approbation des licences pour spécifier des critères déterminant quand une approbation est requise avant qu'une merge request puisse être fusionnée.

Les politiques d'approbation des licences s'appliquent uniquement aux branches cibles [protégées](../project/repository/branches/protected.md).

La vidéo suivante fournit un aperçu de ces politiques.

<div class="video-fallback">
  Voir la vidéo : <a href="https://www.youtube.com/watch?v=34qBQ9t8qO8">Présentation des politiques d'approbation des licences GitLab</a>.
</div>
<figure class="video-container">
  <iframe src="https://www.youtube-nocookie.com/embed/34qBQ9t8qO8" frameborder="0" allowfullscreen> </iframe>
</figure>

## Prérequis pour créer une nouvelle politique d'approbation des licences {#prerequisites-to-creating-a-new-license-approval-policy}

Les politiques d'approbation des licences s'appuient sur le résultat d'un job d'analyse des dépendances pour vérifier que les exigences ont été satisfaites. Si l'analyse des dépendances n'a pas été correctement configurée, et qu'en conséquence aucun job d'analyse des dépendances n'a été exécuté en lien avec une merge request ouverte, la politique ne dispose d'aucune donnée pour vérifier les exigences. Lorsque des données sont manquantes pour l'évaluation des politiques de sécurité, celles-ci échouent par défaut en mode fermé et supposent que la merge request pourrait contenir des vulnérabilités. Vous pouvez désactiver ce comportement par défaut avec la propriété `fallback_behavior` et configurer les politiques pour qu'elles échouent en mode ouvert. Une politique qui échoue en mode ouvert débloque toutes les règles invalides et non applicables.

Pour garantir l'application de vos politiques, vous devez activer l'analyse des dépendances sur vos projets de développement cibles. Vous pouvez y parvenir de plusieurs façons :

- Créez une [politique d'exécution de scan](../application_security/policies/scan_execution_policies.md) qui impose l'exécution de l'analyse des dépendances dans tous les projets de développement cibles.
- Travaillez avec vos équipes de développement pour configurer l'[analyse des dépendances](../application_security/dependency_scanning/_index.md) dans les fichiers `.gitlab-ci.yml` de chacun de leurs projets, ou activez-la à l'aide d'une [configuration de sécurité](../application_security/detect/security_configuration.md).

Les politiques d'approbation des licences nécessitent des informations de licence provenant des [packages pris en charge par GitLab](license_scanning_of_cyclonedx_files/_index.md#supported-languages-and-package-managers).

## Créer une nouvelle politique d'approbation des licences {#create-a-new-license-approval-policy}

Créez une politique d'approbation des licences pour appliquer la conformité des licences.

Pour créer une politique d'approbation des licences :

1. [Liez un projet de politique de sécurité](../application_security/policies/enforcement/security_policy_projects.md#link-to-a-security-policy-project) à votre groupe de développement, sous-groupe ou projet (le rôle Propriétaire est requis).
1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Sécuriser** > **Politiques**.
1. Créez une nouvelle [politique d'approbation des merge requests](../application_security/policies/merge_request_approval_policies.md).
1. Dans votre règle de politique, sélectionnez **Analyse des licences**.

## Critères définissant les licences nécessitant une approbation {#criteria-defining-which-licenses-require-approval}

Les types de critères suivants peuvent être utilisés pour déterminer quelles licences sont « approuvées » ou « refusées » et nécessitent une approbation.

- Lorsqu'une licence figurant dans une liste de licences explicitement interdites est détectée.
- Lorsqu'une licence est détectée, à l'exception des licences qui ont été explicitement listées comme acceptables.

## Critères pour comparer les licences détectées dans la branche de la merge request aux licences de la branche par défaut {#criteria-to-compare-licenses-detected-in-the-merge-request-branch-to-licenses-in-the-default-branch}

Les types de critères suivants peuvent être utilisés pour déterminer si une approbation est requise ou non, en fonction des licences présentes dans la branche par défaut :

- Les licences refusées peuvent être configurées pour ne nécessiter une approbation que si la licence refusée fait partie d'une dépendance qui n'existe pas déjà dans la branche par défaut.
- Les licences refusées peuvent être configurées pour nécessiter une approbation si la licence refusée existe dans un composant qui figure déjà dans la branche par défaut.

![Politique d'approbation des licences](img/license_approval_policy_v15_9.png)

Si une licence enfreignant la politique d'approbation des licences est détectée, elle bloque la merge request et demande au développeur de la supprimer. La merge request ne peut pas être fusionnée tant que la licence `denied` n'est pas supprimée, à moins qu'un approbateur éligible pour la politique d'approbation des licences n'approuve la merge request.

![Merge request avec des licences refusées](img/denied_licenses_v15_3.png)

## Dépannage {#troubleshooting}

### Les politiques d'approbation des licences bloquent les merge requests en raison de licences `unknown` {#license-approval-policies-block-merge-requests-due-to-unknown-licenses}

Les politiques d'approbation des licences peuvent bloquer les merge requests en raison de licences `unknown` dans certains scénarios.

> [!note]
> Les exclusions au niveau des packages utilisant des PURL dans le [champ `licenses`](../application_security/policies/merge_request_approval_policies.md#licenses_with_package_exclusion-object) ne fonctionnent pas avec les licences `unknown`. Le champ `licenses` prend en charge uniquement la correspondance avec les [noms de licences SPDX](https://spdx.org/licenses), et `unknown` n'est pas un nom de licence SPDX valide. Si vous configurez une licence `unknown` refusée avec une exclusion PURL, l'exclusion est ignorée lors de l'évaluation de l'approbation de la merge request, et la merge request est toujours bloquée. L'onglet **Licences** du pipeline semble respecter l'exclusion, mais le widget d'approbation de merge request ne le fait pas. Ces vues utilisent des chemins d'évaluation différents.

Cela peut se produire dans l'une des situations suivantes :

- Le job d'analyse des dépendances ne parvient pas à identifier une licence pour un composant particulier.
- Une licence nouvelle ou peu courante est utilisée et n'est pas reconnue par l'outil d'analyse.
- Les informations de licence sont manquantes ou incomplètes dans les métadonnées du composant.

Pour résoudre ce problème :

1. Examinez l'onglet **Licences** dans la page du pipeline pour identifier les composants dont les licences sont `unknown`, ou examinez les licences `out-of-policy` générées par le bot de sécurité GitLab.
1. Examinez manuellement ces composants pour déterminer leurs licences réelles.
1. Si les licences ne peuvent pas être déterminées ou ne sont pas acceptables, supprimez ou remplacez les composants concernés.

Si vous devez autoriser temporairement la fusion avec des licences `unknown` :

1. Modifiez votre politique d'approbation des licences.
1. Ajoutez `unknown` à la liste des licences autorisées.
1. Une fois le problème résolu, supprimez `unknown` de la liste des licences autorisées afin de maintenir une conformité appropriée des licences.

Consultez toujours votre équipe juridique lorsque vous traitez des problèmes de conformité des licences, en particulier lors de la gestion des licences `unknown`.
