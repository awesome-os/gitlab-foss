---
stage: Tutorial
group: Tutorial
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Passez de GitLab Duo Pro ou Enterprise à la GitLab Duo Agent Platform.
title: Transition vers la GitLab Duo Agent Platform
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Lorsque vous effectuez la transition de GitLab Duo (non agentique) vers l'Agent Platform, vous accédez à plusieurs assistants (appelés agents) tout au long du cycle de vie du développement logiciel.

Pour faire passer votre instance à l'Agent Platform, effectuez les étapes suivantes :

1. Configurer votre environnement
1. Valider votre configuration
1. Configurer les paramètres de l'Agent Platform
1. Valider l'utilisation

## Fonctionnalités disponibles après la transition {#features-available-after-transition}

Le tableau suivant répertorie les fonctionnalités non agentiques de GitLab Duo et la version agentique à laquelle vos utilisateurs peuvent accéder après être passés à l'Agent Platform. Pour obtenir la liste complète des fonctionnalités de l'Agent Platform, consultez [Fonctionnalités généralement disponibles](../../../user/duo_agent_platform/_index.md#generally-available-features) et [Fonctionnalités en version bêta et expérimentale](../../../user/duo_agent_platform/_index.md#beta-and-experimental-features-that-dont-consume-credits).

| Fonctionnalité non agentique | Agent Platform |
|---------------------|----------------|
| GitLab Duo Non-Agentic Chat | [Chat agentique](../../../user/gitlab_duo_chat/agentic_chat.md) <br /> Répondez à des questions complexes, et créez ou modifiez des fichiers de manière autonome. Se connecte aux agents Planificateur et Security Analyst. Le résumé de merge request, le résumé des discussions, la refactorisation du code et la génération de tests font désormais partie d'Agentic Chat. |
| GitLab Duo Code Review | [Flow Code Review](../../../user/duo_agent_platform/flows/foundational_flows/code_review/_index.md)[^runner-configured-execute]  <br /> Automatisez les tâches de revue de code et appliquez les normes de codage au sein de votre équipe. |
| Analyse de cause racine | [Flow Fix CI/CD Pipeline](../../../ci/pipelines/fix_pipeline.md)[^runner-configured-execute] <br /> Diagnostiquez et corrigez automatiquement les pipelines CI/CD en échec. |
| Explication et résolution des vulnérabilités | [Flow de résolution des vulnérabilités SAST](../../../user/duo_agent_platform/flows/foundational_flows/agentic_sast_vulnerability_resolution.md)[^runner-configured-execute] <br /> Générez automatiquement des correctifs et des étapes de remédiation pour les vulnérabilités SAST. |

[^runner-configured-execute]: nécessite un runner [configuré pour exécuter des flows](#set-up-your-environment). Si vous ne configurez pas de runner, après la transition vers l'Agent Platform, ces fonctionnalités apparaissent comme indisponibles pour les utilisateurs qui en dépendaient dans GitLab Duo (non agentique).

## Avant de commencer {#before-you-begin}

Vous devez disposer de GitLab 19.0 ou d'une version ultérieure.

## Configurer votre environnement {#set-up-your-environment}

Contrairement à GitLab Duo (non agentique), l'Agent Platform exécute des flows sur des runners et utilise des comptes de service pour créer des commits et des pipelines. Cela nécessite une configuration que les fonctionnalités non agentiques n'avaient pas.

Pour configurer votre environnement pour l'Agent Platform :

1. [Configurez votre instance](_index.md).
1. [Configurez votre réseau](_index.md#allow-outbound-connections-from-the-gitlab-instance-to-gitlab-duo) pour autoriser les connexions sortantes depuis votre instance GitLab.
1. [Configurez les runners d'instance ou de groupe](../../../user/duo_agent_platform/flows/execution/_index.md#configure-runners-to-execute-flows) pour utiliser les flows. Les flows qui utilisent CI/CD sont exécutés sur des runners. Agentic Chat ne nécessite pas de runners.
1. [Autorisez les connexions](_index.md#allow-connections-from-the-runner) depuis le runner vers votre instance GitLab.
1. Si vous disposez d'une licence en ligne, [synchronisez vos données d'abonnement](../../../subscriptions/manage_subscription.md#manually-synchronize-subscription-data).

## Valider votre configuration {#validate-your-configuration}

Après avoir configuré votre environnement, exécutez les vérifications de diagnostic suivantes :

- [Contrôle de santé GitLab Duo](_index.md#run-a-health-check-for-gitlab-duo)
- [Script de diagnostic de configuration](../../../user/duo_agent_platform/troubleshooting.md#run-the-configuration-diagnostic-script)

## Configurer les paramètres de l'Agent Platform {#configure-agent-platform-settings}

Après avoir configuré votre environnement, configurez les paramètres suivants :

1. [Activez l'Agent Platform](../../../user/duo_agent_platform/turn_on_off.md#turn-gitlab-duo-agent-platform-on-or-off).
1. [Activez les flows par défaut](../../../user/duo_agent_platform/flows/foundational_flows/_index.md).
1. [Configurez les règles de push](../../../user/duo_agent_platform/troubleshooting.md#configure-push-rules-to-allow-a-service-account) pour le compte de service utilisé par les flows par défaut.
1. [Définissez un espace de nommage GitLab Duo par défaut](../../../user/profile/preferences.md#set-a-default-gitlab-duo-namespace).
1. Facultatif. Pour plus de cohérence et pour contrôler les coûts, [sélectionnez un modèle pour une fonctionnalité](../../../user/duo_agent_platform/model_selection.md#select-a-model-for-a-feature) afin que tous les utilisateurs utilisent ce modèle. Si vous n'êtes pas sûr du modèle qui convient à vos besoins, consultez [Sélectionner le bon modèle](../../../user/duo_agent_platform/model_selection.md#select-a-model-for-a-feature).

## Valider l'utilisation {#validate-usage}

Avant de déployer l'Agent Platform auprès de la majorité de vos utilisateurs, demandez à un petit groupe d'utilisateurs de confirmer les résultats suivants :

- Ils peuvent accéder à Agentic Chat et l'utiliser dans l'interface de GitLab.
- Ils peuvent authentifier l'Agent Platform dans leur IDE.
- Ils peuvent exécuter le flow Code Review sur une merge request de test.
- Ils peuvent exécuter d'autres flows par défaut disponibles dans votre abonnement.

Une fois que ces utilisateurs ont exécuté quelques flows, vous devez également vérifier le [tableau de bord des crédits](../../../subscriptions/gitlab_credits_dashboard.md) pour confirmer l'utilisation des crédits.

## Facturation {#billing}

Après avoir modifié votre abonnement de GitLab Duo Pro ou Enterprise vers la facturation à l'usage, vous êtes facturé en fonction de [l'utilisation des crédits](../../../subscriptions/gitlab_credits.md) plutôt que des sièges.

Pour suivre l'utilisation des crédits de votre équipe et définir des plafonds d'utilisation, utilisez le [tableau de bord des crédits](../../../subscriptions/gitlab_credits_dashboard.md).

## Problèmes courants lors de la transition {#common-issues-during-transition}

Lorsque vous effectuez pour la première fois la transition de votre instance vers l'Agent Platform, vous pouvez rencontrer les problèmes suivants.

| Problème | Cause probable | Résolution |
|---------|--------------|------------|
| Les flows ne sont pas visibles dans l'interface | GitLab Duo ou l'exécution des flows n'est pas activé, le groupe ne dispose pas des autorisations pour utiliser les flows, ou le flow n'est pas activé au niveau du projet. | [Les flows ne sont pas visibles dans l'interface](../../../user/duo_agent_platform/troubleshooting.md#flows-not-visible-in-the-ui) |
| Les flows ne s'exécutent pas car aucun runner ne récupère le job | Aucun runner ne possède le tag `gitlab--duo`, ou les runners ne sont pas configurés pour les flows. | [Configurer des runners](../../../user/duo_agent_platform/flows/execution/_index.md#configure-runners-to-execute-flows) |
| La session est bloquée dans l'état `created` | Les règles de push bloquent le compte de service. L'adresse e-mail de l'auteur du commit ou le préfixe de branche `duo/feature/` n'est pas autorisé. | [Configurer des règles de push pour autoriser un compte de service](../../../user/duo_agent_platform/troubleshooting.md#configure-push-rules-to-allow-a-service-account) |
| `Error in creating workload: Insufficient permissions to create a new pipeline` | Le compte de service du flow par défaut a été configuré avant que le projet importé ou issu d'un modèle n'existe. | [Autorisations insuffisantes pour créer un nouveau pipeline pour les projets importés](../../../user/duo_agent_platform/troubleshooting.md#insufficient-permissions-to-create-a-new-pipeline-for-imported-projects) |
| Un flow par défaut est activé mais ne fait rien | Le compte de service n'a pas été créé, ou un verrou d'appartenance au groupe l'empêche d'être ajouté aux projets. | [Compte de service du flow par défaut non créé](../../../user/duo_agent_platform/troubleshooting.md#foundational-flow-service-account-not-created) et [Appartenance au groupe verrouillée](../../../user/duo_agent_platform/troubleshooting.md#group-membership-locked) |
| L'Agent Platform est désactivé, ou `Something went wrong while requesting a review from GitLab Duo` | L'utilisateur appartient à plusieurs espaces de nommage GitLab Duo et aucun espace de nommage par défaut n'est défini. | [Espace de nommage GitLab Duo par défaut non défini](../../../user/duo_agent_platform/troubleshooting.md#default-gitlab-duo-namespace-not-set) |
| `Your request was valid but Workflow failed to complete it` | Le dépôt ne contient aucun commit, le flow ne peut donc pas trouver de branche par défaut. | [Erreur : Your request was valid but Workflow failed to complete it](../../../user/duo_agent_platform/troubleshooting.md#error-your-request-was-valid-but-workflow-failed-to-complete-it) |
| `SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)` | Sur GitLab Self-Managed avec une autorité de certification (CA) personnalisée ou auto-signée, le renforcement du bac à sable bloque l'injection de la CA du runner lors de `git clone`. | [Erreur : SSL certificate OpenSSL verify result](../../../user/duo_agent_platform/troubleshooting.md#error-ssl-certificate-openssl-verify-result-unable-to-get-local-issuer-certificate-20) |
| Toutes les fonctionnalités GitLab Duo échouent pour tous les utilisateurs immédiatement après la transition | Le mode silencieux est activé, ce qui empêche GitLab d'atteindre la passerelle d'IA. | [Désactiver le mode silencieux](../../silent_mode/_index.md#turn-off-silent-mode) |
| Le test réseau du contrôle de santé échoue, ou les fonctionnalités GitLab Duo sont indisponibles après la transition | Le trafic HTTPS sortant vers `cloud.gitlab.com`, `customers.gitlab.com` ou `duo-workflow-svc.runway.gitlab.net` est bloqué par un pare-feu ou un proxy. | [Autoriser les connexions sortantes depuis l'instance GitLab vers GitLab Duo](_index.md#allow-outbound-connections-from-the-gitlab-instance-to-gitlab-duo) |
| Les fonctionnalités de l'Agent Platform sont indisponibles pour tous les utilisateurs immédiatement après la conversion | Les conditions de facturation à l'usage n'ont pas été acceptées, ou aucun crédit n'est disponible dans le pool. | [Crédits à la demande](../../../subscriptions/gitlab_credits.md#on-demand-credits) |

## Sujets connexes {#related-topics}

- [GitLab Duo Agent Platform](_index.md)
- [Dépannage de la GitLab Duo Agent Platform](../../../user/duo_agent_platform/troubleshooting.md)
- [Plafonds d'utilisation](../../../subscriptions/gitlab_credits_dashboard.md#usage-caps)
- [Modèles auto-hébergés](../../gitlab_duo_self_hosted/_index.md)
- [GitLab University : GitLab Duo Agent Platform for administrators](https://university.gitlab.com/learning-paths/gitlab-duo-agent-platform-for-admins)
- [GitLab University : GitLab Duo Agent Platform setup](https://university.gitlab.com/courses/gitlab-duo-agent-platform-setup)
- [GitLab University : Moving from GitLab Duo Pro or Enterprise to the Agent Platform](https://university.gitlab.com/courses/gitlab-duo-agent-platform-setup)
