---
stage: Developer Experience
group: API Platform
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: OpenAPI
description: "Explorez l'API REST GitLab à l'aide de la spécification OpenAPI 3.0"
---

GitLab documente son API REST à l'aide de la [spécification OpenAPI 3.0](https://spec.openapis.org/oas/v3.0.3) (anciennement appelée Swagger), un format standard et indépendant de la plateforme pour décrire les API RESTful. Le code de l'API est l'unique source de vérité pour l'API REST. La spécification OpenAPI est générée automatiquement directement à partir du code de l'API et est étroitement liée à son implémentation, ce qui garantit que la documentation est toujours exacte et à jour.

Pour obtenir des informations générales sur les API GitLab, consultez [Étendre avec GitLab](../_index.md).

## Fichier de spécification OpenAPI {#openapi-specification-file}

La spécification OpenAPI 3.0 brute est disponible dans le monodépôt GitLab :

- **Fichier :** [`doc/api/openapi/openapi_v3.yaml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/doc/api/openapi/openapi_v3.yaml)
- **Format :** OpenAPI 3.0 (YAML)

> [!note]
> La spécification OpenAPI 2.0 (`openapi_v2.yaml`) est obsolète et ne reçoit plus de mises à jour. Utilisez plutôt la spécification OpenAPI 3.0 (`openapi_v3.yaml`).

## Documentation interactive de l'API REST {#interactive-rest-api-documentation}

L'API REST est entièrement documentée à l'aide de la spécification OpenAPI 3.0. Vous pouvez parcourir et tester chaque endpoint de manière interactive dans la [documentation de l'API REST](https://api.gitlab.com/rest/).

La documentation est rendue à l'aide de [Scalar](https://scalar.com/), un outil de référence d'API open source. Elle est générée automatiquement à partir de la spécification OpenAPI dans le code source de GitLab, de sorte qu'elle reflète toujours l'état actuel de l'API.

### Ajouter des identifiants d'autorisation {#add-authorization-credentials}

Certains endpoints nécessitent une authentification. GitLab prend en charge l'authentification avec des identifiants HTTP Bearer ou OAuth 2.0.

Pour ajouter des identifiants d'autorisation :

1. Accédez à la [documentation de l'API REST](https://api.gitlab.com/rest/).
1. Dans le panneau **Authentification** à droite, sélectionnez une méthode d'authentification dans la liste déroulante.
1. Saisissez vos identifiants :
   - Pour `http`, saisissez votre [jeton d'accès personnel](../../user/profile/personal_access_tokens.md).
   - Pour `oauth2`, utilisez le flux de code d'autorisation avec GitLab comme fournisseur d'identité.
1. Sélectionnez **Autoriser**.

Vos identifiants sont réutilisés automatiquement pour toutes les requêtes suivantes au cours de la session.

### Envoyer une requête en direct {#send-a-live-request}

Utilisez l'outil de requête interactive pour envoyer des requêtes en direct à GitLab.

Pour envoyer une requête en direct :

1. Accédez à la [documentation de l'API REST](https://api.gitlab.com/rest/).
1. Développez une opération.
1. Sélectionnez **Tester la requête**.
1. Saisissez les paramètres obligatoires ou facultatifs.
1. Sélectionnez **Envoyer**.

L'outil affiche la commande `curl`, l'URL complète de la requête et la réponse du serveur.
