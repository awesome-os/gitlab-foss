---
stage: Package
group: Package Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Gestionnaires de paquets pris en charge et fonctionnalités
---

Le registre de paquets GitLab prend en charge différentes fonctionnalités pour chaque type de paquet. Cette prise en charge inclut la publication et l'extraction de paquets, le transfert de requêtes, la gestion des doublons et l'authentification.

## Gestionnaires de paquets pris en charge {#supported-package-managers}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!warning]
> Les formats de gestionnaires de paquets ne sont pas tous prêts pour une utilisation en production.

Le registre de paquets prend en charge les types de gestionnaires de paquets suivants :

| Type de paquet                                      | Statut |
|---------------------------------------------------|--------|
| [Composer](../composer_repository/_index.md)      | [version bêta](https://gitlab.com/groups/gitlab-org/-/work_items/6817) |
| [Conan 1](../conan_1_repository/_index.md)            | [version bêta](https://gitlab.com/groups/gitlab-org/-/work_items/6816) |
| [Conan 2](../conan_2_repository/_index.md)            | [version bêta](https://gitlab.com/groups/gitlab-org/-/work_items/8258) |
| [Debian](../debian_repository/_index.md)          | [version expérimentale](https://gitlab.com/groups/gitlab-org/-/work_items/6057) |
| [Paquets génériques](../generic_packages/_index.md) | Disponibilité générale     |
| [Go](../go_proxy/_index.md)                       | [version expérimentale](https://gitlab.com/groups/gitlab-org/-/work_items/3043) |
| [Helm](../helm_repository/_index.md)              | Disponibilité générale      |
| [Maven](../maven_repository/_index.md)            | Disponibilité générale      |
| [npm](../npm_registry/_index.md)                  | Disponibilité générale      |
| [NuGet](../nuget_repository/_index.md)            | Disponibilité générale      |
| [PyPI](../pypi_repository/_index.md)              | Disponibilité générale      |
| [Gemmes Ruby](../rubygems_registry/_index.md)       | [version expérimentale](https://gitlab.com/groups/gitlab-org/-/work_items/3200) |

[Voir la signification de chaque statut](../../../policy/development_stages_support.md).

Vous pouvez également utiliser l'[API](../../../api/packages.md) pour administrer le registre de paquets.

## Publication de paquets {#publishing-packages}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les paquets peuvent être publiés dans votre projet, votre groupe ou votre instance.

| Type de paquet                                           | Projet | Groupe | Instance |
|--------------------------------------------------------|---------|-------|----------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | Oui       | Non     | Non        |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | Oui       | Non     | Non        |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | Non        | Non     | Non        |
| [npm](../npm_registry/_index.md)                       | Oui       | Non     | Non        |
| [NuGet](../nuget_repository/_index.md)                 | Oui       | Non     | Non        |
| [PyPI](../pypi_repository/_index.md)                   | Oui       | Non     | Non        |
| [Paquets génériques](../generic_packages/_index.md)      | Oui       | Non     | Non        |
| [Terraform](../terraform_module_registry/_index.md)    | Oui       | Non     | Non        |
| [Composer](../composer_repository/_index.md)           | Non        | Oui    | Non        |
| [Conan 1](../conan_1_repository/_index.md)             | Oui       | Non     | Oui       |
| [Conan 2](../conan_2_repository/_index.md)             | Oui       | Non     | Non        |
| [Helm](../helm_repository/_index.md)                   | Oui       | Non     | Non        |
| [Debian](../debian_repository/_index.md)               | Oui       | Non     | Non        |
| [Go](../go_proxy/_index.md)                            | Oui       | Non     | Non        |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Oui       | Non     | Non        |

## Extraction de paquets {#pulling-packages}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les paquets peuvent être extraits de votre projet, votre groupe ou votre instance.

| Type de paquet                                           | Projet | Groupe | Instance |
|--------------------------------------------------------|---------|-------|----------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | Oui       | Oui     | Oui       |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | Oui       | Oui     | Oui       |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | Oui       | Oui     | Oui       |
| [npm](../npm_registry/_index.md)                       | Oui       | Oui     | Oui       |
| [NuGet](../nuget_repository/_index.md)                 | Oui       | Oui     | Non        |
| [PyPI](../pypi_repository/_index.md)                   | Oui       | Oui     | Non        |
| [Paquets génériques](../generic_packages/_index.md)      | Oui       | Non      | Non        |
| [Terraform](../terraform_module_registry/_index.md)    | Non        | Oui     | Non        |
| [Composer](../composer_repository/_index.md)           | Oui       | Oui     | Non        |
| [Conan 1](../conan_1_repository/_index.md)             | Oui       | Non      | Oui       |
| [Conan 2](../conan_2_repository/_index.md)             | Oui       | Non      | Non        |
| [Helm](../helm_repository/_index.md)                   | Oui       | Non      | Non        |
| [Debian](../debian_repository/_index.md)               | Oui       | Non      | Non        |
| [Go](../go_proxy/_index.md)                            | Oui       | Non      | Oui       |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Oui       | Non      | Non        |

## Transfert de requêtes {#forwarding-requests}

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Prérequis :

- Sur GitLab.com : vous devez être le Propriétaire du groupe.
- Sur GitLab Self-Managed : Vous devez être administrateur.

Lorsqu'un paquet est introuvable dans le registre de paquets de votre projet, les requêtes sont transférées vers le registre public correspondant du gestionnaire de paquets.

Le comportement de transfert par défaut varie selon le type de paquet et peut introduire une [vulnérabilité de confusion de dépendances](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610). Le tableau ci-dessous indique les gestionnaires de paquets qui prennent en charge le transfert de paquets.

Pour réduire les risques de sécurité associés :

- Vérifiez que le paquet n'est pas activement utilisé.
- Mettez en œuvre un outil de contrôle de version, comme Git, pour suivre les modifications apportées aux paquets.
- Désactivez le transfert de requêtes :
  - Les administrateurs d'instance peuvent désactiver le transfert dans la zone **Admin**. Pour plus d'informations, consultez [Contrôler le transfert de paquets](../../../administration/settings/continuous_integration.md#control-package-forwarding).
  - Les propriétaires de groupe peuvent désactiver le transfert de paquets dans les paramètres du groupe.

Pour désactiver le transfert de requêtes pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Paquets et registres**.
1. Sous **Transfert de paquet**, décochez l'une des cases suivantes :
   - **Transférer les requêtes de paquets npm**
   - **Transférer les requêtes de paquets PyPI**
1. Sélectionnez **Enregistrer les modifications**.

| Type de paquet                                           | Prise en charge du transfert de requêtes | Considérations de sécurité |
|--------------------------------------------------------|-----------------------------|------------------------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | [Oui (désactivé par défaut)](../../../administration/settings/continuous_integration.md#control-package-forwarding) | Nécessite une activation explicite pour la sécurité. |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | [Oui (désactivé par défaut)](../../../administration/settings/continuous_integration.md#control-package-forwarding) | Nécessite une activation explicite pour la sécurité. |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | [Oui (désactivé par défaut)](../../../administration/settings/continuous_integration.md#control-package-forwarding) | Nécessite une activation explicite pour la sécurité. |
| [npm](../npm_registry/_index.md)                       | [Oui](../../../administration/settings/continuous_integration.md#control-package-forwarding) | Envisagez de désactiver pour les paquets privés. |
| [PyPI](../pypi_repository/_index.md)                   | [Oui](../../../administration/settings/continuous_integration.md#control-package-forwarding) | Envisagez de désactiver pour les paquets privés. |
| [NuGet](../nuget_repository/_index.md)                 | Non                           | Non |
| [Paquets génériques](../generic_packages/_index.md)      | Non                           | Non |
| [Terraform](../terraform_module_registry/_index.md)    | Non                           | Non |
| [Composer](../composer_repository/_index.md)           | Non                           | Non |
| [Conan 1](../conan_1_repository/_index.md)               | Non                           | Non |
| [Conan 2](../conan_2_repository/_index.md)               | Non                           | Non |
| [Helm](../helm_repository/_index.md)                   | Non                           | Non |
| [Debian](../debian_repository/_index.md)               | Non                           | Non |
| [Go](../go_proxy/_index.md)                            | Non                           | Non |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Non                           | Non |

## Suppression de paquets {#deleting-packages}

Lorsque les requêtes de paquets sont transférées vers un registre public, la suppression d'un paquet peut provoquer une [vulnérabilité de confusion de dépendances](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610).

Si un système tente d'extraire un paquet supprimé, la requête est transférée vers le registre public. Si un paquet portant le même nom et la même version se trouve dans le registre public, ce paquet est extrait à la place. Le paquet extrait du registre pourrait ne pas correspondre à vos attentes et pourrait être malveillant.

Pour réduire les risques de sécurité associés, avant de supprimer un paquet :

- Vérifiez que le paquet n'est pas activement utilisé.
- [Désactivez le transfert de requêtes](#forwarding-requests).

Pour supprimer des paquets, vous pouvez :

- [Supprimer des paquets dans l'interface utilisateur](reduce_package_registry_storage.md#delete-a-package).
- [Supprimer des paquets avec l'API](../../../api/packages.md#delete-a-project-package).

## Importation de paquets depuis d'autres dépôts {#importing-packages-from-other-repositories}

Vous pouvez utiliser les pipelines GitLab pour importer des paquets depuis d'autres dépôts, tels que Maven Central ou Artifactory, à l'aide de l'[outil d'importation de paquets](https://gitlab.com/gitlab-org/ci-cd/package-stage/pkgs_importer).

| Type de paquet                                           | Importateur disponible ? |
|--------------------------------------------------------|---------------------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | Oui                  |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | Oui                  |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | Oui                  |
| [npm](../npm_registry/_index.md)                       | Oui                  |
| [NuGet](../nuget_repository/_index.md)                 | Oui                  |
| [PyPI](../pypi_repository/_index.md)                   | Oui                  |
| [Paquets génériques](../generic_packages/_index.md)      | Non                   |
| [Terraform](../terraform_module_registry/_index.md)    | Non                   |
| [Composer](../composer_repository/_index.md)           | Non                   |
| [Conan 1](../conan_1_repository/_index.md)             | Non                   |
| [Conan 2](../conan_2_repository/_index.md)             | Non                   |
| [Helm](../helm_repository/_index.md)                   | Non                   |
| [Debian](../debian_repository/_index.md)               | Non                   |
| [Go](../go_proxy/_index.md)                            | Non                   |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Non                   |

## Autoriser ou empêcher les doublons {#allow-or-prevent-duplicates}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Par défaut, le registre de paquets GitLab autorise ou empêche les doublons selon le comportement par défaut du format de gestionnaire de paquets concerné.

| Type de paquet                                           | Doublons autorisés ? |
|--------------------------------------------------------|---------------------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | Oui (configurable)   |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | Oui (configurable)   |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | Oui (configurable)   |
| [npm](../npm_registry/_index.md)                       | Non                   |
| [NuGet](../nuget_repository/_index.md)                 | Oui                  |
| [PyPI](../pypi_repository/_index.md)                   | Non                   |
| [Paquets génériques](../generic_packages/_index.md)      | Oui (configurable)   |
| [Terraform](../terraform_module_registry/_index.md)    | Non                   |
| [Composer](../composer_repository/_index.md)           | Non                   |
| [Conan 1](../conan_1_repository/_index.md)             | Non                   |
| [Conan 2](../conan_2_repository/_index.md)             | Non                   |
| [Helm](../helm_repository/_index.md)                   | Oui                  |
| [Debian](../debian_repository/_index.md)               | Oui                  |
| [Go](../go_proxy/_index.md)                            | Non                   |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Oui                  |

## S'authentifier auprès du registre {#authenticate-with-the-registry}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

L'authentification dépend du gestionnaire de paquets que vous utilisez. Pour connaître les protocoles d'authentification pris en charge pour un type de paquet spécifique, consultez [Protocoles d'authentification](#authentication-protocols).

Pour la plupart des types de paquets, les jetons d'authentification suivants sont valides :

- [Jeton d'accès personnel](../../profile/personal_access_tokens.md)
- [Jeton de déploiement de projet](../../project/deploy_tokens/_index.md)
- [Jeton de déploiement de groupe](../../project/deploy_tokens/_index.md)
- [Jeton de job CI/CD](../../../ci/jobs/ci_job_token.md)

Le tableau suivant répertorie les jetons d'authentification pris en charge pour chaque gestionnaire de paquets :

| Type de paquet                                           | Jetons pris en charge                                                       |
|--------------------------------------------------------|------------------------------------------------------------------------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [npm](../npm_registry/_index.md)                       | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [NuGet](../nuget_repository/_index.md)                 | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [PyPI](../pypi_repository/_index.md)                   | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [Paquets génériques](../generic_packages/_index.md)      | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [Terraform](../terraform_module_registry/_index.md)    | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [Composer](../composer_repository/_index.md)           | Accès personnel, jetons de job, déploiement (projet ou groupe), accès projet |
| [Conan 1](../conan_1_repository/_index.md)                 | Accès personnel, jetons de job, accès projet                            |
| [Conan 2](../conan_2_repository/_index.md)                 | Accès personnel, jetons de job, accès projet                            |
| [Helm](../helm_repository/_index.md)                   | Accès personnel, jetons de job, déploiement (projet ou groupe)                 |
| [Debian](../debian_repository/_index.md)               | Accès personnel, jetons de job, déploiement (projet ou groupe)                 |
| [Go](../go_proxy/_index.md)                            | Accès personnel, jetons de job, accès projet                            |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Accès personnel, jetons de job, déploiement (projet ou groupe)                 |

> [!note]
> Lorsque vous configurez l'authentification auprès du registre de paquets :
>
> - Si le paramètre de projet **Registre de paquets** est [désactivé](_index.md#turn-off-the-package-registry), vous recevez une erreur `403 Forbidden` lorsque vous interagissez avec le registre de paquets, même si vous disposez du rôle Propriétaire.
> - Si [l'autorisation externe](../../../administration/settings/external_authorization.md) est activée, vous ne pouvez pas accéder au registre de paquets avec un jeton de déploiement.
> - Si votre organisation utilise l'authentification à deux facteurs (2FA), vous devez utiliser un jeton d'accès personnel avec la portée définie sur `api`.
> - Si vous publiez un paquet à l'aide de pipelines CI/CD, vous devez utiliser un jeton de job CI/CD.

### Protocoles d'authentification {#authentication-protocols}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les protocoles d'authentification suivants sont pris en charge :

| Type de paquet                                           | Protocoles d'authentification pris en charge                                    |
|--------------------------------------------------------|-------------------------------------------------------------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | En-têtes, authentification de base, OAuth                                  |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | En-têtes, authentification de base, OAuth                                  |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | Authentification de base ([extraction](#pulling-packages) uniquement)          |
| [npm](../npm_registry/_index.md)                       | OAuth                                                       |
| [NuGet](../nuget_repository/_index.md)                 | Authentification de base                                                  |
| [PyPI](../pypi_repository/_index.md)                   | Authentification de base                                                  |
| [Paquets génériques](../generic_packages/_index.md)      | Authentification de base                                                  |
| [Terraform](../terraform_module_registry/_index.md)    | Jeton                                                       |
| [Composer](../composer_repository/_index.md)           | OAuth                                                       |
| [Conan 1](../conan_1_repository/_index.md)                 | OAuth, authentification de base                                           |
| [Conan 2](../conan_2_repository/_index.md)                 | OAuth, authentification de base                                           |
| [Helm](../helm_repository/_index.md)                   | Authentification de base                                                  |
| [Debian](../debian_repository/_index.md)               | Authentification de base                                                  |
| [Go](../go_proxy/_index.md)                            | Authentification de base                                                  |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | Jeton                                                       |

## Types de hachage pris en charge {#supported-hash-types}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les valeurs de hachage permettent de s'assurer que vous utilisez le bon paquet. Vous pouvez consulter ces valeurs dans l'interface utilisateur ou via l'[API](../../../api/packages.md).

Le registre de paquets prend en charge les types de hachage suivants :

| Type de paquet                                           | Hachages pris en charge                 |
|--------------------------------------------------------|----------------------------------|
| [Maven (avec `mvn`)](../maven_repository/_index.md)    | MD5, SHA1                        |
| [Maven (avec `gradle`)](../maven_repository/_index.md) | MD5, SHA1                        |
| [Maven (avec `sbt`)](../maven_repository/_index.md)    | MD5, SHA1                        |
| [npm](../npm_registry/_index.md)                       | SHA1                             |
| [NuGet](../nuget_repository/_index.md)                 | non applicable                   |
| [PyPI](../pypi_repository/_index.md)                   | MD5, SHA256                      |
| [Paquets génériques](../generic_packages/_index.md)      | SHA256                           |
| [Composer](../composer_repository/_index.md)           | non applicable                   |
| [Conan 1](../conan_1_repository/_index.md)             | MD5, SHA1                        |
| [Conan 2](../conan_2_repository/_index.md)             | MD5, SHA1                        |
| [Helm](../helm_repository/_index.md)                   | non applicable                   |
| [Debian](../debian_repository/_index.md)               | MD5, SHA1, SHA256                |
| [Go](../go_proxy/_index.md)                            | MD5, SHA1, SHA256                |
| [Gemmes Ruby](../rubygems_registry/_index.md)            | MD5, SHA1, SHA256 (gemspec uniquement) |
