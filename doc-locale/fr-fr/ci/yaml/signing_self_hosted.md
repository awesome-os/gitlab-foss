---
stage: Software Supply Chain Security
group: Pipeline Security
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
description: "Signez des artefacts CI/CD et des images de conteneur avec une pile Sigstore auto-hébergée, notamment la configuration de Fulcio et la résolution des problèmes."
title: Signer des artefacts et des images de conteneur avec Sigstore auto-hébergé
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

Si vous exécutez GitLab Self-Managed, vous ne pouvez pas utiliser le [service Sigstore](signing_examples.md) public pour signer vos artefacts CI/CD et vos images de conteneur. Le service ne fait confiance qu'aux pipelines GitLab.com, et non aux pipelines de votre propre instance. Vous pouvez à la place connecter votre propre infrastructure Sigstore (Fulcio, Rekor et un journal de transparence des certificats) à votre instance GitLab, afin de signer et vérifier des artefacts avec Cosign sans dépendre de GitLab.com ni d'Internet.

Le fournisseur OpenID Connect (OIDC) de GitLab prouve votre identité, Cosign supprime la clé de signature immédiatement après son utilisation, et Rekor enregistre chaque événement de signature dans son journal de transparence.

Le certificat émis par Fulcio est intégré dans la signature, accompagné de détails précisant quel pipeline l'a créé, notamment le chemin du projet, le SHA du commit, la source du pipeline, l'environnement du runner et l'URL du job.

Prérequis :

- Accès à la configuration de votre infrastructure Sigstore (Fulcio, Rekor) et de vos runners GitLab CI/CD.
- Une pile Sigstore auto-hébergée fonctionnant dans votre réseau, comprenant Fulcio, Rekor et un journal de transparence des certificats. Le journal de transparence des certificats est obligatoire. Cosign vérifie un horodatage de certificat signé lors de la vérification. Ainsi, un Fulcio déployé sans journal de transparence des certificats émet des certificats que Cosign ne peut pas vérifier. Pour les instructions de déploiement, consultez :
  - [Guide d'installation du journal de transparence Sigstore](https://docs.sigstore.dev/logging/installation/) pour Rekor et son backend Trillian
  - [Dépôt Fulcio](https://github.com/sigstore/fulcio) pour Fulcio et le journal de transparence des certificats
- Si votre instance GitLab utilise HTTPS avec une autorité de certification privée, cette autorité de certification doit être approuvée à la fois par Fulcio et par vos runners CI/CD :
  - Le certificat de l'autorité de certification monté dans le conteneur Fulcio, avec `SSL_CERT_FILE` défini sur son chemin.
  - Le certificat de l'autorité de certification installé dans le magasin de confiance du système d'exploitation sur chaque runner.
- [Cosign](https://docs.sigstore.dev/cosign/system_config/installation/) version v2.x ou ultérieure installée sur vos runners CI/CD.
- Les fichiers de matériel de confiance de votre pile Sigstore, placés sur vos runners dans un emplacement partagé tel que `/etc/sigstore/` :
  - Certificat CA racine Fulcio (`fulcio-root.pem`)
  - Clé publique du journal de transparence Rekor (`rekor-pub.pem`)
  - Clé publique du journal de transparence des certificats (`ctfe-pub.pem`)

## Configurer Fulcio pour faire confiance à votre instance GitLab {#configure-fulcio-to-trust-your-gitlab-instance}

Configurez Fulcio pour qu'il fasse confiance à votre instance GitLab afin de pouvoir vérifier les jetons OIDC des jobs GitLab CI/CD lors de la signature sans clé. Fulcio mappe les revendications du jeton sur des champs du certificat de signature. Le fichier de configuration nécessite à la fois une section `oidc-issuers` et une section `ci-issuer-metadata`.

Pour configurer Fulcio :

1. Récupérez l'URL exacte de l'émetteur OIDC à l'aide de la commande suivante. Remplacez `https://gitlab.example.com` par l'URL de votre instance GitLab. Fulcio requiert une correspondance exacte. Le schéma et la présence ou l'absence d'une barre oblique finale ont tous deux leur importance.

   ```shell
   curl --silent "https://gitlab.example.com/.well-known/openid-configuration" | jq --raw-output .issuer
   ```

1. Créez un fichier de configuration OIDC Fulcio avec une entrée `oidc-issuers` pour votre instance GitLab. Remplacez `<gitlab_issuer_url>` par le résultat de l'étape précédente :

   ```yaml
   oidc-issuers:
     <gitlab_issuer_url>:
       issuer-url: <gitlab_issuer_url>
       client-id: sigstore
       type: ci-provider
       ci-provider: gitlab-pipeline
       contact: admin@example.com
       description: "GitLab Self-Managed OIDC"
   ```

1. Dans le même fichier, ajoutez une section `ci-issuer-metadata` avec les modèles de revendications GitLab, copiés depuis la [configuration Fulcio en amont](https://github.com/sigstore/fulcio/blob/main/config/identity/config.yaml). Remplacez `<gitlab_issuer_url>` par la même valeur que celle utilisée à l'étape précédente.

   Pour connaître la correspondance de chaque revendication, consultez la colonne GitLab de la page [correspondance des revendications de jetons OIDC avec les OID Fulcio](https://github.com/sigstore/fulcio/blob/main/docs/oid-info.md#mapping-oidc-token-claims-to-fulcio-oids).

   ```yaml
   ci-issuer-metadata:
     gitlab-pipeline:
       default-template-values:
         url: "<gitlab_issuer_url>"
         environment: ""
       extension-templates:
         build-signer-uri: "https://{{ .ci_config_ref_uri }}"
         build-signer-digest: "ci_config_sha"
         runner-environment: "runner_environment"
         source-repository-uri: "{{ .url }}/{{ .project_path }}"
         source-repository-digest: "sha"
         source-repository-ref: >-
           refs/{{if eq .ref_type "branch"}}heads/{{ else }}tags/{{end}}{{ .ref }}
         source-repository-identifier: "project_id"
         source-repository-owner-uri: "{{ .url }}/{{ .namespace_path }}"
         source-repository-owner-identifier: "namespace_id"
         build-config-uri: "https://{{ .ci_config_ref_uri }}"
         build-config-digest: "ci_config_sha"
         build-trigger: "pipeline_source"
         run-invocation-uri: >-
           {{ .url }}/{{ .project_path }}/-/jobs/{{ .job_id }}
         source-repository-visibility-at-signing: "project_visibility"
         deployment-environment: "environment"
       subject-alternative-name-template: "https://{{ .ci_config_ref_uri }}"
   ```

   > [!note]
   > Cette section est maintenue par le projet Sigstore, et non par GitLab. Vérifiez périodiquement le fichier en amont pour détecter les modifications, et mettez à jour votre copie en conséquence.

## Configurer Rekor pour conserver sa clé et son journal entre les redémarrages {#configure-rekor-to-keep-its-key-and-log-across-restarts}

Par défaut, Rekor génère une nouvelle clé de signature et crée un nouvel arbre de journal vide à chaque démarrage. Pour conserver les deux entre les redémarrages, configurez Rekor avec un signataire persistant et un identifiant d'arbre fixe.

Pour configurer Rekor :

1. Pendant que Rekor est en cours d'exécution, obtenez l'identifiant d'arbre de son journal actuel :

   ```shell
   curl --silent "http://<sigstore-host>:3000/api/v1/log" | jq --raw-output .treeID
   ```

1. Ajoutez ces indicateurs à la commande `rekor-server serve` qui démarre Rekor, puis redémarrez Rekor :

   ```plaintext
   --rekor_server.signer=<signer>
   --trillian_log_server.tlog_id=<tree_id>
   ```

   Remplacez :

   - `<signer>` par un URI de service de gestion de clés, tel que `hashivault://<key_name>` pour une clé de transit HashiCorp Vault. Pour Vault, définissez également les variables d'environnement `VAULT_ADDR` et `VAULT_TOKEN` pour Rekor. Rekor accepte également le chemin d'accès à un fichier de clé privée encodé en PEM. L'aide de la commande Rekor indique que les signataires basés sur des fichiers ne doivent être utilisés qu'à des fins de test.
   - `<tree_id>` par l'identifiant d'arbre de l'étape précédente.

1. Si vous avez modifié le signataire, reconstruisez le matériel de confiance avec la nouvelle clé publique Rekor. Pour les commandes, consultez [erreur : `not enough verified log entries from transparency log`](#error-not-enough-verified-log-entries-from-transparency-log).

> [!warning]
> Avec un signataire persistant et sans identifiant d'arbre, la signature continue de fonctionner après un redémarrage. Cependant, Rekor ne renvoie plus les entrées enregistrées avant le redémarrage, et les nouvelles entrées recommencent à l'index de journal `0`.

## Signer des artefacts et des images de conteneur {#sign-artifacts-and-container-images}

Utilisez le mot-clé `id_tokens` pour générer un jeton OIDC pour le job. Cosign présente ce jeton à Fulcio, qui émet un certificat de signature éphémère.

Cosign v3 utilise des fichiers de configuration de signature pour spécifier les points de terminaison de votre service Sigstore et le matériel de confiance. Générez ces fichiers une seule fois et distribuez-les aux runners, ou générez-les dans chaque job comme indiqué dans l'exemple suivant.

```yaml
sign-artifact:
  stage: sign
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  variables:
    COSIGN_YES: "true"
  script:
    - cosign signing-config create
        --fulcio="url=http://<sigstore-host>:5555,api-version=1,start-time=2024-01-01T00:00:00Z,operator=my-org"
        --rekor="url=http://<sigstore-host>:3000,api-version=1,start-time=2024-01-01T00:00:00Z,operator=my-org"
        --rekor-config="ANY"
        --oidc-provider="url=https://gitlab.example.com,api-version=1,start-time=2024-01-01T00:00:00Z,operator=my-org"
        --out signing-config.json
    - cosign trusted-root create
        --fulcio="url=http://<sigstore-host>:5555,certificate-chain=/etc/sigstore/fulcio-root.pem,start-time=2024-01-01T00:00:00Z"
        --rekor="url=http://<sigstore-host>:3000,public-key=/etc/sigstore/rekor-pub.pem,start-time=2024-01-01T00:00:00Z"
        --ctfe="url=http://<sigstore-host>:6962,public-key=/etc/sigstore/ctfe-pub.pem,start-time=2024-01-01T00:00:00Z"
        --out trusted-root.json
    - cosign sign-blob
        --signing-config=signing-config.json
        --trusted-root=trusted-root.json
        --oidc-client-id=sigstore
        --identity-token=$SIGSTORE_ID_TOKEN
        --bundle=artifact.bundle
        artifact.txt
```

La valeur `start-time` est l'heure la plus ancienne à laquelle le point de terminaison du service est considéré comme valide, telle que définie dans la [spécification protobuf Sigstore](https://github.com/sigstore/protobuf-specs). Utilisez la date à laquelle votre pile Sigstore a été déployée.

Remplacez `sigstore` dans `--oidc-client-id` par l'identifiant client configuré dans votre entrée d'émetteur OIDC Fulcio.

Utilisez la même URL d'émetteur pour `--oidc-provider` que celle que vous avez enregistrée dans la configuration `oidc-issuers` de Fulcio.

### Signer des images de conteneur {#sign-container-images}

Pour signer une image de conteneur, utilisez `cosign sign` avec la référence de l'image à la place du chemin de fichier. La configuration de signature est identique.

Le registre de conteneurs doit être accessible via HTTPS sur un nom d'hôte résolvable. Le registre publie un domaine d'authentification à sa propre URL externe. Cosign rejette un domaine dont l'hôte est une adresse privée ou link-local littérale. Une instance dont `registry_external_url` est une adresse IP brute peut signer des fichiers, mais ne peut pas signer des images de conteneur.

### Pour Cosign v2.x {#for-cosign-v2x}

Si vous utilisez Cosign v2.x, utilisez des indicateurs d'URL et des variables d'environnement à la place des fichiers de configuration :

```yaml
sign-artifact:
  stage: sign
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  variables:
    COSIGN_YES: "true"
    SIGSTORE_ROOT_FILE: /etc/sigstore/fulcio-root.pem
    SIGSTORE_REKOR_PUBLIC_KEY: /etc/sigstore/rekor-pub.pem
    SIGSTORE_CT_LOG_PUBLIC_KEY_FILE: /etc/sigstore/ctfe-pub.pem
  script:
    - cosign sign-blob
        --fulcio-url=http://<sigstore-host>:5555
        --rekor-url=http://<sigstore-host>:3000
        --oidc-issuer=https://gitlab.example.com
        --identity-token=$SIGSTORE_ID_TOKEN
        --output-signature=artifact.sig
        --output-certificate=artifact.crt
        artifact.txt
```

Pour les images de conteneur, utilisez Cosign v3 comme décrit dans [Signer des images de conteneur](#sign-container-images).

Cosign v2 écrit le certificat en PEM encodé en base64. Décodez-le avant de le transmettre à un autre outil.

Utilisez la même URL d'émetteur pour `--oidc-issuer` que celle que vous avez enregistrée dans la configuration `oidc-issuers` de Fulcio.

## Vérifier les signatures {#verify-signatures}

La vérification avec un bundle Cosign v3 utilise le matériel de confiance et l'identité du signataire attendu :

```shell
cosign verify-blob \
  --trusted-root=trusted-root.json \
  --bundle=artifact.bundle \
  --certificate-oidc-issuer=https://gitlab.example.com \
  --certificate-identity=https://gitlab.example.com/my-group/my-project//.gitlab-ci.yml@refs/heads/main \
  artifact.txt
```

La valeur `--certificate-identity` est le nom alternatif du sujet du certificat de signature ; elle est construite à partir du chemin de configuration CI/CD :

```plaintext
https://<CI_SERVER_HOST>/<CI_PROJECT_PATH>//.gitlab-ci.yml@<full ref>
```

Trois détails importants dans ce modèle :

- Le schéma est toujours `https://`, car le `subject-alternative-name-template` dans la configuration Fulcio le définit ainsi. Cela s'applique même lorsque votre instance est accessible via HTTP.
- La double barre oblique avant `.gitlab-ci.yml` est correcte. Le segment de chemin qui la précède correspond au projet, et le segment vide qui suit porte l'emplacement de configuration CI/CD par défaut.
- La référence complète est `refs/heads/<branch>` pour un pipeline de branche et `refs/tags/<tag>` pour un pipeline de tag.

Pour vérifier des artefacts signés avec Cosign v2, transmettez la signature détachée et le certificat :

```shell
cosign verify-blob \
  --signature=artifact.sig \
  --certificate=artifact.crt \
  --certificate-oidc-issuer=https://gitlab.example.com \
  --certificate-identity=https://gitlab.example.com/my-group/my-project//.gitlab-ci.yml@refs/heads/main \
  artifact.txt
```

## Sujets connexes {#related-topics}

- [Exemples de signature](signing_examples.md) pour GitLab.com avec l'instance Sigstore publique
- [Jetons d'identité OIDC CI/CD](../secrets/id_token_authentication.md)
- [Sigstore : composants personnalisés](https://docs.sigstore.dev/cosign/system_config/custom_components/)

## Dépannage {#troubleshooting}

Lors de la signature d'artefacts avec une infrastructure Sigstore auto-hébergée, vous pouvez rencontrer les problèmes suivants.

### Erreur : `metadata not found for ci provider gitlab-pipeline` {#error-metadata-not-found-for-ci-provider-gitlab-pipeline}

Cette erreur se produit lorsque la section `ci-issuer-metadata` est absente de votre configuration Fulcio.

Pour résoudre ce problème, ajoutez le bloc `ci-issuer-metadata` complet comme indiqué dans [configurer Fulcio pour faire confiance à votre instance GitLab](#configure-fulcio-to-trust-your-gitlab-instance).

### Erreur : `ctfe public key not found for payload` {#error-ctfe-public-key-not-found-for-payload}

Cette erreur se produit lorsque Cosign ne trouve pas la clé publique du journal de transparence des certificats pour votre pile auto-hébergée.

Pour résoudre ce problème, incluez `--ctfe` dans votre commande `cosign trusted-root create` pour Cosign v3, ou définissez la variable d'environnement `SIGSTORE_CT_LOG_PUBLIC_KEY_FILE` pour Cosign v2.

### Erreur : `not enough verified log entries from transparency log` {#error-not-enough-verified-log-entries-from-transparency-log}

Cette erreur se produit lorsque la clé publique Rekor dans `trusted-root.json` ne correspond plus à la clé utilisée par l'instance Rekor. Avec le signataire en mémoire par défaut, Rekor génère une nouvelle clé à chaque démarrage. Tout redémarrage invalide donc le matériel de confiance, et la signature échoue pour chaque job jusqu'à ce qu'il soit reconstruit.

Pour résoudre ce problème, lisez la clé actuelle depuis l'instance en cours d'exécution et régénérez la racine de confiance :

```shell
curl --silent --fail "http://<sigstore-host>:3000/api/v1/log/publicKey" --output /etc/sigstore/rekor-pub.pem
cosign trusted-root create \
  --fulcio="url=http://<sigstore-host>:5555,certificate-chain=/etc/sigstore/fulcio-root.pem,start-time=2024-01-01T00:00:00Z" \
  --rekor="url=http://<sigstore-host>:3000,public-key=/etc/sigstore/rekor-pub.pem,start-time=2024-01-01T00:00:00Z" \
  --ctfe="url=http://<sigstore-host>:6962,public-key=/etc/sigstore/ctfe-pub.pem,start-time=2024-01-01T00:00:00Z" \
  --out trusted-root.json
```

Distribuez le fichier `trusted-root.json` régénéré à chaque runner.

Pour éviter ce problème, configurez Rekor avec un signataire persistant, comme indiqué dans [configurer Rekor pour conserver sa clé et son journal entre les redémarrages](#configure-rekor-to-keep-its-key-and-log-across-restarts).

### Erreur : `failed to verify signed certificate timestamp` {#error-failed-to-verify-signed-certificate-timestamp}

Cette erreur se produit lorsque le certificat ne contient aucun horodatage de certificat signé, ce qui se produit lorsque Fulcio fonctionne sans journal de transparence des certificats. La signature réussit dans cette configuration, et seule la vérification échoue.

Pour résoudre ce problème, configurez Fulcio avec `--ct-log-url` pointant vers votre journal de transparence des certificats, et incluez `--ctfe` lorsque vous créez la racine de confiance.

### Erreur : `x509: certificate signed by unknown authority` {#error-x509-certificate-signed-by-unknown-authority}

Cette erreur se produit lorsque Fulcio ne peut pas valider le certificat TLS présenté par votre instance GitLab.

Pour résoudre ce problème, montez votre certificat d'autorité de certification privée dans le conteneur Fulcio et définissez `SSL_CERT_FILE` sur son chemin.

Le point de terminaison `/healthz` de Fulcio indique `SERVING` même lorsque l'initialisation du fournisseur OIDC a échoué. Utilisez le journal du conteneur pour confirmer que le fournisseur a bien été chargé.
