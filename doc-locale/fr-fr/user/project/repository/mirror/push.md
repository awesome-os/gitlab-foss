---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Créez un miroir push pour recevoir passivement les modifications d'un dépôt amont."
title: Mise en miroir push
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Un _miroir push_ est un dépôt aval qui [met en miroir](_index.md) les commits effectués dans le dépôt amont. Les miroirs push reçoivent passivement des copies des commits effectués dans le dépôt amont. Pour éviter que le miroir ne diverge du dépôt amont, n'effectuez pas de push de commits directement vers le miroir aval. Effectuez plutôt des pushs de commits vers le dépôt amont.

Alors que [la mise en miroir pull](pull.md) récupère périodiquement les mises à jour depuis le dépôt amont, les miroirs push ne reçoivent des modifications que dans les cas suivants :

- Des commits sont poussés vers le dépôt GitLab amont.
- Un administrateur [force la mise à jour du miroir](_index.md#force-an-update).

Lorsque vous poussez une modification vers le dépôt amont, le miroir push la reçoit en cinq minutes, ou en une minute si le paramètre **Only mirror protected branches** est activé.

Lorsqu'une branche est fusionnée dans la branche par défaut et supprimée dans le projet source, elle est supprimée du miroir distant lors du push suivant. Les branches comportant des modifications non fusionnées sont conservées. Si une branche diverge, la section **Dépôts miroirs** affiche une erreur.

[Le mode silencieux GitLab](../../../../administration/silent_mode/_index.md) désactive les pushs vers les miroirs distants et les pulls depuis ceux-ci.

## Limites des miroirs push {#push-mirror-limits}

Chaque projet peut avoir un maximum de 10 miroirs push activés. Pour plus d'informations, voir [nombre maximum de miroirs push de projet](../../../../administration/instance_limits.md#maximum-number-of-project-push-mirrors).

## Configurer la mise en miroir push {#configure-push-mirroring}

Prérequis :

- Votre dépôt GitLab et le dépôt distant utilisent le même format d'objet. Vous ne pouvez pas effectuer de mise en miroir entre des dépôts SHA-1 et SHA-256.

Pour configurer la mise en miroir push pour un projet existant :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Dépôt**.
1. Développez **Dépôts miroirs**.
1. Saisissez une URL de dépôt.
1. Dans la liste déroulante **Sens du miroir**, sélectionnez **Push**.
1. Sélectionnez une **Méthode d'authentification**. Pour plus d'informations, voir [méthodes d'authentification pour les miroirs](_index.md#authentication-methods-for-mirrors).
1. Sélectionnez **Only mirror protected branches**, si nécessaire.
1. Sélectionnez **Conserver les références divergentes**, si vous le souhaitez.
1. Pour enregistrer la configuration, sélectionnez **Dépôt miroir**.

### Configurer les miroirs push via l'API {#configure-push-mirrors-through-the-api}

Vous pouvez également créer et modifier des miroirs push de projet via l'[API des miroirs distants](../../../../api/remote_mirrors.md).

## Conserver les références divergentes {#keep-divergent-refs}

Par défaut, si une référence (branche ou tag) sur le miroir distant (aval) diverge du dépôt local, le dépôt amont écrase toutes les modifications sur le dépôt distant :

1. Un dépôt met en miroir les branches `main` et `develop` vers un dépôt distant.
1. Un nouveau commit est ajouté à `develop` sur le miroir distant.
1. Le push suivant met à jour le miroir distant pour qu'il corresponde au dépôt amont.
1. Le nouveau commit ajouté à `develop` sur le miroir distant est perdu.

Si **Conserver les références divergentes** est sélectionné, les modifications sont gérées différemment :

1. Les mises à jour de la branche `develop` sur le miroir distant sont ignorées.
1. La branche `develop` sur le miroir distant conserve le commit qui n'existe pas dans le dépôt amont. Toutes les références qui existent dans le miroir distant mais pas dans le dépôt amont sont laissées intactes.
1. La mise à jour est marquée comme ayant échoué.

Après avoir créé un miroir, vous pouvez uniquement modifier la valeur de **Conserver les références divergentes** via l'[API des miroirs distants](../../../../api/remote_mirrors.md).

## Configurer un miroir push de GitLab vers GitHub {#set-up-a-push-mirror-from-gitlab-to-github}

Lorsque vous poussez des commits de GitLab vers GitHub, GitHub détermine l'attribution des commits en fonction des adresses e-mail. Si l'adresse e-mail du commit correspond à une adresse e-mail vérifiée sur un compte utilisateur GitHub, GitHub attribue le commit à cet utilisateur. Dans le cas contraire, le commit apparaît comme non attribué, avec uniquement le nom et l'adresse e-mail issus des métadonnées du commit.

Prérequis :

- Un [jeton d'accès personnel à granularité fine](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#fine-grained-personal-access-tokens) GitHub avec des autorisations de lecture et d'écriture pour le [contenu du dépôt](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens?apiVersion=2022-11-28#repository-permissions-for-contents). Si votre dépôt contient un répertoire `.github/workflows`, vous devez également accorder un accès en lecture et en écriture pour les [workflows](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens?apiVersion=2022-11-28#repository-permissions-for-workflows). Pour un accès plus granulaire, configurez votre jeton pour qu'il s'applique uniquement au dépôt spécifique.

Pour configurer le miroir :

1. Pour **URL du dépôt Git**, saisissez l'URL au format suivant :

   ```plaintext
   https://github.com/GROUP/PROJECT.git
   ```

   - `GROUP` : le groupe sur GitHub.
   - `PROJECT` : le projet sur GitHub.

1. Pour **Nom d'utilisateur**, saisissez le nom d'utilisateur du propriétaire du jeton d'accès personnel.
1. Pour **Mot de passe**, saisissez votre jeton d'accès personnel GitHub.
1. Sélectionnez **Dépôt miroir**.

Le dépôt mis en miroir est répertorié. Par exemple :

```plaintext
https://*****:*****@github.com/<your_github_group>/<your_github_project>.git
```

Le push du dépôt est effectué peu après. Pour forcer un push, sélectionnez **Mettre à jour maintenant** ({{< icon name="retry" >}}).

## Configurer un miroir push de GitLab vers AWS CodeCommit {#set-up-a-push-mirror-from-gitlab-to-aws-codecommit}

La mise en miroir push AWS CodeCommit est la meilleure façon de connecter les dépôts GitLab à AWS CodePipeline. GitLab n'est pas encore pris en charge en tant que fournisseur de gestion du code source (SCM). Chaque nouveau pipeline AWS CodePipeline nécessite une configuration d'infrastructure AWS importante. Il nécessite également un pipeline individuel par branche.

Si AWS CodeDeploy est la dernière étape d'un CodePipeline, vous pouvez combiner ces outils pour créer un déploiement :

- Pipelines CI/CD GitLab.
- L'interface de ligne de commande AWS dans le dernier job de `.gitlab-ci.yml` pour déployer vers CodeDeploy.

Pour configurer un miroir de GitLab vers AWS CodeCommit :

1. Dans la console AWS IAM, créez un utilisateur IAM.
1. Ajoutez les autorisations de moindre privilège suivantes pour la mise en miroir du dépôt en tant que **politique intégrée**.

   Les noms de ressources Amazon (ARN) doivent inclure explicitement la région et le compte. Cette politique IAM accorde des privilèges d'accès à la mise en miroir pour deux exemples de dépôts. Ces autorisations ont été testées et correspondent au minimum (moindre privilège) requis pour la mise en miroir :

   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "MinimumGitLabPushMirroringPermissions",
               "Effect": "Allow",
               "Action": [
                   "codecommit:GitPull",
                   "codecommit:GitPush"
               ],
               "Resource": [
                 "arn:aws:codecommit:us-east-1:111111111111:MyDestinationRepo",
                 "arn:aws:codecommit:us-east-1:111111111111:MyDemo*"
               ]
           }
       ]
   }
   ```

1. Une fois l'utilisateur créé, sélectionnez le nom d'utilisateur AWS IAM.
1. Sélectionnez l'onglet **Security credentials**.
1. Sous **HTTPS Git credentials for AWS CodeCommit**, sélectionnez **Generate credentials**.

   > [!note]
   > Cet identifiant utilisateur Git et ce mot de passe sont spécifiques à la communication avec CodeCommit. Ne les confondez pas avec l'identifiant utilisateur IAM ou les clés AWS de cet utilisateur.

1. Copiez ou téléchargez l'identifiant utilisateur Git HTTPS spécial et le mot de passe.
1. Dans la console AWS CodeCommit, créez un nouveau dépôt à mettre en miroir depuis votre dépôt GitLab.
1. Ouvrez votre nouveau dépôt, dans le coin supérieur droit, sélectionnez **Code** > **Clone HTTPS** (et non **Clone HTTPS (GRC)**).
1. Dans GitLab, ouvrez le dépôt à mettre en miroir push.
1. Sélectionnez **Paramètres** > **Dépôt**, puis développez **Dépôts miroirs**.
1. Renseignez le champ **URL du dépôt Git** en utilisant ce format, en remplaçant `<aws-region>` par votre région AWS et `<your_codecommit_repo>` par le nom de votre dépôt dans CodeCommit :

   ```plaintext
   https://git-codecommit.<aws-region>.amazonaws.com/v1/repos/<your_codecommit_repo>
   ```

1. Pour **Méthode d'authentification**, sélectionnez **Nom d'utilisateur et mot de passe**.
1. Pour **Nom d'utilisateur**, saisissez l'**identifiant utilisateur Git HTTPS spécial** AWS.
1. Pour **Mot de passe**, saisissez le mot de passe spécial de l'identifiant utilisateur Git IAM pour le clonage, créé précédemment dans AWS.
1. Laissez l'option **Only mirror protected branches** pour CodeCommit. Elle effectue des pushs plus fréquemment (de toutes les cinq minutes à toutes les minutes).

   CodePipeline nécessite des configurations de pipeline individuelles pour les branches nommées pour lesquelles vous souhaitez disposer d'une configuration AWS CI. Les branches de fonctionnalité avec des noms dynamiques n'étant pas prises en charge, la configuration de **Only mirror protected branches** ne pose pas de problème de flexibilité avec l'intégration CodePipeline. Vous devez également protéger toutes les branches nommées pour lesquelles vous souhaitez créer des CodePipelines.

1. Sélectionnez **Dépôt miroir**. Le dépôt mis en miroir devrait apparaître :

   ```plaintext
   https://*****:*****@git-codecommit.<aws-region>.amazonaws.com/v1/repos/<your_codecommit_repo>
   ```

Pour tester la mise en miroir en forçant un push, sélectionnez **Mettre à jour maintenant** (les flèches en demi-cercle). Si **Dernière mise à jour réussie** affiche une date, vous avez correctement configuré la mise en miroir. Si la configuration ne fonctionne pas correctement, un tag `error` rouge apparaît et affiche le message d'erreur en texte de survol.

## Configurer un miroir push vers une autre instance GitLab avec la 2FA activée {#set-up-a-push-mirror-to-another-gitlab-instance-with-2fa-activated}

1. Sur l'instance GitLab de destination, créez un [jeton d'accès personnel](../../../profile/personal_access_tokens.md) avec la portée `write_repository`.
1. Sur l'instance GitLab source :
   1. Saisissez l'**URL du dépôt Git** au format suivant : `https://<destination host>/<your_gitlab_group_or_name>/<your_gitlab_project>.git`.
   1. Saisissez le **Nom d'utilisateur** `oauth2`.
   1. Saisissez le **Mot de passe**. Utilisez le jeton d'accès personnel GitLab créé sur l'instance GitLab de destination.
   1. Sélectionnez **Dépôt miroir**.

## Sujets connexes {#related-topics}

- [Dépannage](troubleshooting.md) de la mise en miroir de dépôts.
- [API des miroirs distants](../../../../api/remote_mirrors.md)
