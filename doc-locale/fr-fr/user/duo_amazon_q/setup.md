---
stage: AI Platform
group: AI Model Services
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Configurer et gérer GitLab Duo avec Amazon Q sur une instance GitLab Self-Managed à l'aide de l'intégration AWS."
title: Configurer GitLab Duo avec Amazon Q
---

{{< details >}}

- Édition : GitLab Ultimate
- Module d'extension : GitLab Duo avec Amazon Q
- Offre : GitLab Self-Managed

{{< /details >}}

{{< history >}}

- Introduit en tant que [version expérimentale](../../policy/development_stages_support.md#experiment) dans GitLab 17.7 [avec un feature flag](../../administration/feature_flags/_index.md) nommé `amazon_q_integration`. Fonctionnalité désactivée par défaut.
- Suppression du feature flag `amazon_q_integration` dans GitLab 17.8.
- Généralement disponible dans GitLab 17.11.

{{< /history >}}

> [!note]
> GitLab Duo avec Amazon Q ne peut pas être combiné avec d'autres modules complémentaires GitLab Duo.

Pour obtenir un abonnement à GitLab Duo avec Amazon Q, contactez votre responsable de compte.

Pour demander un essai, [remplissez ce formulaire](https://about.gitlab.com/partners/technology-partners/aws/#form).

Pour configurer GitLab Duo avec Amazon Q sur GitLab Self-Managed, suivez les étapes ci-dessous.

## Configurer GitLab Duo avec Amazon Q {#set-up-gitlab-duo-with-amazon-q}

Pour configurer GitLab Duo avec Amazon Q, vous devez :

- [Remplir les prérequis](#prerequisites)
- [Créer un profil dans la console Amazon Q Developer](#create-a-profile-in-the-amazon-q-developer-console)
- [Créer un fournisseur d'identité](#create-an-iam-identity-provider)
- [Créer un rôle IAM](#create-an-iam-role)
- [Modifier le rôle](#edit-the-role)
- [Saisir l'ARN dans GitLab et activer Amazon Q](#enter-the-arn-in-gitlab-and-enable-amazon-q)
- [Autoriser les administrateurs à utiliser des clés gérées par le client](#allow-administrators-to-use-customer-managed-keys)

### Prérequis {#prerequisites}

- Vous devez disposer de GitLab Self-Managed :
  - Sur GitLab 17.11 ou une version ultérieure.
  - Amazon Q utilise les API REST de l'instance GitLab pour lire et écrire des données lors de l'exécution des actions demandées, et doit pouvoir accéder à votre URL HTTPS ([le certificat SSL ne doit pas être auto-signé](https://docs.gitlab.com/omnibus/settings/ssl/)).
  - L'instance doit autoriser l'accès réseau entrant depuis les services Amazon Q qui proviennent des adresses IP suivantes, en utilisant TCP/TLS sur le port configuré pour votre instance. Il s'agit par défaut du [port 443](../../administration/package_information/defaults.md#ports).
    - `34.228.181.128`
    - `44.219.176.187`
    - `54.226.244.221`
  - Avec un abonnement Ultimate synchronisé avec GitLab et le module complémentaire GitLab Duo avec Amazon Q.

### Créer un profil dans la console Amazon Q Developer {#create-a-profile-in-the-amazon-q-developer-console}

Créez un profil Amazon Q Developer.

1. Ouvrez la [console Amazon Q Developer](https://us-east-1.console.aws.amazon.com/amazonq/developer/home#/gitlab).
1. Sélectionnez **Amazon Q Developer dans GitLab**.
1. Sélectionnez **Commencer**.
1. Pour **Nom du profil**, saisissez un nom de profil unique pour votre région. Par exemple, `QDevProfile-us-east-1`.
1. Facultatif. Pour **Description du profil (facultatif)**, saisissez une description.
1. Sélectionnez **Créer**.

### Créer un fournisseur d'identité IAM {#create-an-iam-identity-provider}

Créez un fournisseur d'identité IAM. Tout d'abord, récupérez certaines valeurs depuis GitLab.

Prérequis :

- Vous devez être administrateur.

1. Connectez-vous à GitLab.
1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **GitLab Duo avec Amazon Q**.
1. Sélectionnez **Voir les paramètres de configuration**.
1. À l'étape 1, copiez l'URL du fournisseur et l'audience. Vous en aurez besoin à l'étape suivante.

À présent, créez un fournisseur d'identité AWS :

1. Connectez-vous à la [console AWS IAM](https://console.aws.amazon.com/iam).
1. Sélectionnez **Gestion des accès** > **Fournisseurs d’identité**.
1. Sélectionnez **Ajouter un fournisseur**.
1. Pour **Type de fournisseur**, sélectionnez **OpenID Connect**.
1. Pour **URL du fournisseur**, saisissez la valeur provenant de GitLab.
1. Pour **Audience**, saisissez la valeur provenant de GitLab.
1. Sélectionnez **Ajouter un fournisseur**.

### Créer un rôle IAM {#create-an-iam-role}

Ensuite, vous devez créer un rôle IAM qui approuve le fournisseur d'identité IAM et peut accéder à Amazon Q.

> [!note]
> Une fois le rôle IAM configuré, vous ne pouvez plus modifier le compte AWS associé au rôle.

1. Dans la console AWS IAM, sélectionnez **Gestion des accès** > **Rôles** > **Créer un rôle**.
1. Sélectionnez **Identité Web**.
1. Pour **Identité Web**, sélectionnez l'URL du fournisseur que vous avez saisie précédemment.
1. Pour **Audience**, sélectionnez la valeur d'audience que vous avez saisie précédemment.
1. Sélectionnez **Suivant**.
1. Sur la page **Ajouter des autorisations** :
   - Pour utiliser une stratégie gérée, pour **Stratégies d’autorisation**, recherchez et sélectionnez `GitLabDuoWithAmazonQPermissionsPolicy`.
   - Pour créer une stratégie en ligne, ignorez **Stratégies d’autorisation** en sélectionnant **Suivant**. Vous créerez une stratégie ultérieurement.
1. Sélectionnez **Suivant**.
1. Nommez le rôle, par exemple `QDeveloperAccess`.
1. Vérifiez que la stratégie d'approbation est correcte. Elle devrait ressembler à ceci :

   ```json
   {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Principal": {
                "Federated": "arn:aws:iam::<AWS_Account_ID>:oidc-provider/auth.token.gitlab.com/cc/oidc/<Instance_ID>"
            },
            "Condition": {
                "StringEquals": {
                    "auth.token.gitlab.com/cc/oidc/<Instance_ID>:aud": "gitlab-cc-<Instance_ID>"
                },

            }
         }
      ]
   }
   ```

1. Sélectionnez **Créer un rôle**.

### Créer une stratégie en ligne (facultatif) {#create-an-inline-policy-optional}

Pour créer une stratégie en ligne plutôt que d'utiliser une stratégie gérée :

1. Sélectionnez **Autorisations** > **Ajouter des autorisations** > **Créer une stratégie intégrée**.
1. Sélectionnez **JSON** et collez le code suivant dans l'éditeur :

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "GitLabDuoUsagePermissions",
         "Effect": "Allow",
         "Action": [
           "q:SendEvent",
           "q:CreateAuthGrant",
           "q:UpdateAuthGrant",
           "q:GenerateCodeRecommendations",
           "q:SendMessage",
           "q:ListPlugins",
           "q:VerifyOAuthAppConnection"
         ],
         "Resource": "*"
       },
       {
         "Sid": "GitLabDuoManagementPermissions",
         "Effect": "Allow",
         "Action": [
           "q:CreateOAuthAppConnection",
           "q:DeleteOAuthAppConnection"
         ],
         "Resource": "*"
       },
       {
         "Sid": "GitLabDuoPluginPermissions",
         "Effect": "Allow",
         "Action": [
           "q:CreatePlugin",
           "q:DeletePlugin",
           "q:GetPlugin"
         ],
         "Resource": "arn:aws:qdeveloper:*:*:plugin/GitLabDuoWithAmazonQ/*"
       }
     ]
   }
   ```

1. Sélectionnez **Actions** > **Optimiser pour la lisibilité** pour permettre à AWS de formater et d'analyser le JSON.
1. Sélectionnez **Suivant**.
1. Nommez la stratégie `gitlab-duo-amazon-q-policy` et sélectionnez **Créer une stratégie**.

### Modifier le rôle {#edit-the-role}

À présent, modifiez le rôle :

1. Recherchez le rôle que vous venez de créer et sélectionnez-le.
1. Modifiez la durée de session à 12 heures. La commande `AssumeRoleWithWebIdentity` échouera dans la passerelle d'IA si la session n'est pas définie sur 12 heures ou plus.

   1. Dans le champ **Rechercher de rôles**, saisissez le nom de votre rôle IAM, puis choisissez le nom du rôle.
   1. Dans **Résumé**, choisissez **Modifier** pour modifier la durée de session.
   1. Choisissez la liste déroulante **Durée maximale de session**, puis choisissez **12 heures**.
   1. Choisissez **Enregistrer les modifications**.

1. Copiez l'ARN affiché sur la page. Il devrait ressembler à ceci :

   ```plaintext
   arn:aws:iam::123456789:role/QDeveloperAccess
   ```

### Saisir l'ARN dans GitLab et activer Amazon Q {#enter-the-arn-in-gitlab-and-enable-amazon-q}

À présent, saisissez l'ARN dans GitLab et déterminez quels groupes et projets peuvent accéder à la fonctionnalité.

Prérequis :

- Vous devez être administrateur GitLab.

Pour terminer la configuration de GitLab Duo avec Amazon Q :

1. Connectez-vous à GitLab.
1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **GitLab Duo avec Amazon Q**.
1. Sélectionnez **Voir les paramètres de configuration**.
1. Sous **ARN du rôle IAM**, collez l'ARN.
1. Pour déterminer quels groupes et projets peuvent utiliser GitLab Duo avec Amazon Q, choisissez une option :
   - Pour l'activer pour l'instance, mais permettre aux groupes et projets de le désactiver, sélectionnez **Activé(e) par défaut**.
     - Facultatif. Pour configurer Amazon Q afin qu'il révise automatiquement le code dans les merge requests, sélectionnez **Demander à Amazon Q de réviser automatiquement le code dans les requêtes de fusion**.
   - Pour le désactiver pour l'instance, mais permettre aux groupes et projets de l'activer, sélectionnez **Désactivé(e) par défaut**.
   - Pour le désactiver pour l'instance et empêcher les groupes ou projets de l'activer, sélectionnez **Toujours désactivée**.

1. Sélectionnez **Enregistrer les modifications**.

Lors de l'enregistrement, une API doit contacter la passerelle d'IA pour créer une application OAuth sur Amazon Q.

Pour confirmer que l'opération a réussi :

- Dans le journal de la console Amazon CloudWatch, vérifiez la présence d'un code de statut `204`. Pour plus d'informations, consultez [What is Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html) ?
- Dans GitLab, une notification indiquant `Amazon Q settings have been saved` est affichée.
- Dans GitLab, dans la barre latérale gauche, sélectionnez **Applications**. L'application OAuth Amazon Q est affichée.

## Autoriser les administrateurs à utiliser des clés gérées par le client {#allow-administrators-to-use-customer-managed-keys}

Si vous êtes administrateur, vous pouvez utiliser le service AWS Key Management Service (AWS KMS) et les clés gérées par le client (CMK) pour chiffrer les données client.

Mettez à jour la stratégie de rôle pour accorder l'autorisation d'utiliser des CMK lorsque vous créez votre stratégie de clé sur un rôle configuré dans la console KMS.

La clé de condition `kms:ViaService` limite l'utilisation d'une clé KMS aux demandes provenant de services AWS spécifiés. De plus, elle est utilisée pour refuser l'autorisation d'utiliser une clé KMS lorsque la demande provient de services particuliers. Avec la clé de condition, vous pouvez limiter qui peut utiliser une CMK pour chiffrer ou déchiffrer du contenu.

```json
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Sid": "Sid0",
         "Effect": "Allow",
         "Principal": {
            "AWS": "arn:aws:iam::<awsAccountId>:role/<rolename>"
         },
         "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:GenerateDataKeyWithoutPlaintext",
            "kms:ReEncryptFrom",
            "kms:ReEncryptTo"
         ],
         "Resource": "*",
         "Condition": {
            "StringEquals": {
                "kms:ViaService": [
                    "q.<region>.amazonaws.com"
                ]
            }
        }
      }
   ]
}
```

Pour plus d'informations, consultez [`kms:ViaService` dans le guide du développeur AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html#conditions-kms-via-service).

## Configurer GitLab pour utiliser la passerelle d'IA hébergée par AWS {#configure-gitlab-to-use-aws-hosted-ai-gateway}

Vous pouvez configurer GitLab pour utiliser la passerelle d'IA hébergée sur AWS.

> [!warning]
> Les commandes qui modifient des données peuvent causer des dommages si elles ne sont pas exécutées correctement ou dans les bonnes conditions. Exécutez toujours les commandes dans un environnement de test en premier et disposez d'une instance de sauvegarde prête à être restaurée.

1. Démarrez une [session de console Rails](../../administration/operations/rails_console.md#starting-a-rails-console-session). Par exemple, pour les installations qui utilisent le package Linux, exécutez :

   ```shell
   sudo gitlab-rails console
   ```

1. Pour afficher l'URL de service actuellement attribuée, exécutez :

   ```ruby
   ApplicationSetting.current.ai_gateway_url
   ```

1. Pour mettre à jour l'URL de service, exécutez :

   ```ruby
   ApplicationSetting.current.update!(ai_gateway_url: "https://cloud.gitlab.com/aws/ai")
   ```

## Désactiver GitLab Duo avec Amazon Q {#turn-off-gitlab-duo-with-amazon-q}

Vous pouvez désactiver GitLab Duo avec Amazon Q pour l'instance, le groupe ou le projet.

### Désactiver pour l'instance {#turn-off-for-the-instance}

Prérequis :

- Vous devez être administrateur.

Pour désactiver GitLab Duo avec Amazon Q pour l'instance :

1. Connectez-vous à GitLab.
1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **GitLab Duo avec Amazon Q**.
1. Sélectionnez **Voir les paramètres de configuration**.
1. Sélectionnez **Toujours désactivée**.
1. Sélectionnez **Enregistrer les modifications**.

### Désactiver pour un groupe {#turn-off-for-a-group}

Prérequis :

- Vous devez disposer du rôle Propriétaire pour un groupe.

Pour désactiver GitLab Duo avec Amazon Q pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Amazon Q**.
1. Choisissez une option :
   - Pour le désactiver pour le groupe, mais permettre à d'autres groupes ou projets de l'activer, sélectionnez **Désactivé(e) par défaut**.
   - Pour le désactiver pour le groupe et empêcher d'autres groupes ou projets de l'activer, sélectionnez **Toujours désactivée**.
1. Sélectionnez **Enregistrer les modifications**.

### Désactiver pour un projet {#turn-off-for-a-project}

Prérequis :

- Vous devez disposer du rôle Propriétaire pour un projet.

Pour désactiver GitLab Duo avec Amazon Q pour un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Visibilité, fonctionnalités du projet, autorisations**.
1. Sous **Amazon Q**, désactivez le bouton bascule.
1. Sélectionnez **Enregistrer les modifications**.

## Dépannage {#troubleshooting}

Si vous rencontrez des problèmes de connexion entre GitLab et Amazon Q, vérifiez que votre installation GitLab satisfait [tous les prérequis](#prerequisites).

Vous pourriez également rencontrer le problème suivant.

### Discordance d'UUID de l'instance GitLab {#gitlab-instance-uuid-mismatch}

Vous pourriez rencontrer une erreur `GitLab instance UUID mismatch` lorsque vous déconnectez Amazon Q, ou une erreur `Cannot obtain OIDC token` lorsque vous effectuez un contrôle de santé. Par exemple :

```plaintext
Authentication with the AI gateway services failed: AI Gateway returned code 500: {"detail":"Cannot obtain OIDC token"}
Amazon Q connectivity check failed: Cannot obtain OIDC token
```

Ces erreurs se produisent généralement dans les cas suivants :

- L'instance GitLab a été restaurée depuis une sauvegarde.
- L'instance GitLab a été migrée vers une nouvelle infrastructure.
- L'UUID de l'instance GitLab a changé pour toute autre raison.

Pour confirmer qu'une discordance d'UUID est la cause principale, procédez aux étapes de validation suivantes.

#### Valider {#validate}

1. Connectez-vous à l'instance EC2 sur laquelle GitLab est hébergé.
1. Accédez à la console Rails.
1. Obtenez l'UUID actuel : `Gitlab::CurrentSettings.current_application_settings.uuid`
1. Obtenez le jeton JWT :

   ```ruby
   token = CloudConnector::Tokens.get(unit_primitive: :agent_quick_actions, resource: :instance)
   JWT.decode(token, false, nil)
   ```

Le problème est apparent lorsqu'une discordance d'UUID existe entre le champ `sub` à l'étape 3 et le champ `gitlab_instance_uuid` de l'étape 4.

Pour résoudre ce problème, suivez les étapes ci-dessous.

1. Supprimez toutes les licences actives.
1. Supprimez tous les achats de modules complémentaires d'abonnement :

   Ouvrez la console Rails et exécutez :

   ```ruby
   GitlabSubscriptions::AddOnPurchase.all.destroy_all
   ```

1. Effectuez la réinitialisation de l'UUID de l'instance. Dans la console Rails, exécutez :

   ```ruby
   ApplicationSetting.update!(uuid: SecureRandom.uuid)
   ```

1. Appliquez la licence active.
1. Attendez environ une minute et synchronisez la licence. Cette action force la régénération du jeton du connecteur cloud. (Sans cette étape, une discordance d'en-tête se produit.)
1. Mettez à jour le fournisseur d'identité (IdP) et le rôle IAM avec le nouvel UUID.
1. Choisissez une prochaine étape :
   - Continuez à utiliser la configuration existante en mettant à jour le fournisseur d'identité et le rôle IAM existants avec le nouvel UUID, et continuez à utiliser GitLab Duo avec Amazon Q.
   - Désengagement :
     1. Désengagez-vous de GitLab Duo avec Amazon Q.
     1. Configurez une nouvelle connexion si vous le souhaitez.

Une fois cette opération terminée, le problème de discordance d'UUID devrait être résolu et GitLab Duo avec Amazon Q devrait fonctionner correctement avec la nouvelle configuration.
