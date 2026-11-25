---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Intégration d'OpenTofu dans les merge requests"
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

La collaboration autour des modifications d'Infrastructure as Code (IaC) nécessite que les modifications du code et les changements d'infrastructure attendus soient vérifiés et approuvés. GitLab fournit une solution pour faciliter la collaboration autour des modifications du code OpenTofu et de leurs effets attendus, en utilisant les pages de merge request. Ainsi, les utilisateurs n'ont pas à créer des outils personnalisés ni à dépendre de solutions tierces pour rationaliser leurs workflows IaC.

## Afficher les informations du plan OpenTofu dans une merge request {#output-opentofu-plan-information-into-a-merge-request}

En utilisant l'[artefact de rapport GitLab Terraform/OpenTofu](../../../ci/yaml/artifacts_reports.md#artifactsreportsterraform), vous pouvez exposer les détails des exécutions de `tofu plan` directement dans un widget de merge request, ce qui vous permet de consulter des statistiques sur les ressources qu'OpenTofu crée, modifie ou supprime.

> [!warning]
> Comme tout autre artefact de job, les données du plan OpenTofu sont visibles par toute personne disposant du rôle Invité sur le dépôt. Ni OpenTofu ni GitLab ne chiffrent le fichier de plan par défaut. Si vos fichiers OpenTofu `plan.json` ou `plan.cache` contiennent des données sensibles telles que des mots de passe, des jetons d'accès ou des certificats, vous devez chiffrer la sortie du plan ou modifier les paramètres de visibilité du projet. Vous devez également désactiver les [pipelines publics](../../../ci/pipelines/settings.md#change-pipeline-visibility-for-non-project-members-in-public-projects) et définir le [flag public de l'artefact sur false](../../../ci/yaml/_index.md#artifactspublic) (`public: false`). Ce paramètre garantit que les artefacts sont accessibles uniquement aux administrateurs GitLab et aux membres du projet disposant du rôle Reporter, Developer, Maintainer ou Owner.

## Configurer les artefacts de rapport OpenTofu {#configure-opentofu-report-artifacts}

GitLab [s'intègre à OpenTofu](_index.md#quickstart-an-opentofu-project-in-pipelines) via le composant CI/CD OpenTofu. Ce composant utilise l'état OpenTofu géré par GitLab pour afficher les modifications OpenTofu dans les merge requests.

### Configurer automatiquement les artefacts de rapport OpenTofu {#automatically-configure-opentofu-report-artifacts}

Vous devez utiliser le [composant CI/CD OpenTofu](https://gitlab.com/components/opentofu), qui configure automatiquement les artefacts de rapport OpenTofu dans les jobs `plan`.

### Configurer manuellement les artefacts de rapport OpenTofu {#manually-configure-opentofu-report-artifacts}

Pour une configuration rapide, vous devez personnaliser l'image prébuildée et utiliser l'assistant `gitlab-tofu`.

Pour configurer manuellement un artefact de rapport GitLab OpenTofu :

1. Définissez des variables réutilisables pour référencer ces fichiers à plusieurs reprises :

   ```yaml
   variables:
     PLAN: plan.cache
     PLAN_JSON: plan.json
   ```

1. Installez `jq`, un [processeur JSON en ligne de commande léger et flexible](https://stedolan.github.io/jq/).
1. Créez un alias pour une commande `jq` spécifique qui analyse les informations que vous souhaitez extraire de la sortie de `tofu plan` :

   ```yaml
   before_script:
     - apk --no-cache add jq
     - alias convert_report="jq -r '([.resource_changes[]?.change.actions?]|flatten)|{\"create\":(map(select(.==\"create\"))|length),\"update\":(map(select(.==\"update\"))|length),\"delete\":(map(select(.==\"delete\"))|length)}'"
   ```

   > [!note]
   > Dans les distributions qui utilisent Bash (par exemple, Ubuntu), les instructions `alias` ne sont pas développées en mode non interactif. Si vos pipelines échouent avec l'erreur `convert_report: command not found`, l'expansion des alias peut être activée explicitement en ajoutant une commande `shopt` à votre script :

   ```yaml
   before_script:
     - shopt -s expand_aliases
     - alias convert_report="jq -r '([.resource_changes[]?.change.actions?]|flatten)|{\"create\":(map(select(.==\"create\"))|length),\"update\":(map(select(.==\"update\"))|length),\"delete\":(map(select(.==\"delete\"))|length)}'"
   ```

1. Définissez un `script` qui exécute `tofu plan` et `tofu show`. Ces commandes redirigent la sortie et convertissent les éléments pertinents dans une variable de stockage `PLAN_JSON`. Ce JSON est utilisé pour créer un [artefact de rapport GitLab OpenTofu](../../../ci/yaml/artifacts_reports.md#artifactsreportsterraform). Le rapport OpenTofu obtient un fichier OpenTofu `tfplan.json`. Le rapport de plan OpenTofu collecté est téléversé dans GitLab en tant qu'artefact et est affiché dans les merge requests.

   ```yaml
   plan:
     stage: build
     script:
       - terraform plan -out=$PLAN
       - terraform show -json $PLAN | convert_report > $PLAN_JSON
     artifacts:
       reports:
         terraform: $PLAN_JSON
   ```

1. Exécutez le pipeline pour afficher le widget dans la merge request, comme suit :

   ![widget Terraform de merge request](img/terraform_plan_widget_v13_2.png)

   > [!note]
   > Le nombre maximum de modifications signalées par le widget est de 999 999 pour chaque action. Cette limitation concerne uniquement l'affichage ; les plans qui modifient un nombre plus élevé de ressources peuvent être appliqués comme prévu.

1. Dans le widget, sélectionnez **Afficher le journal complet** pour accéder à la sortie du plan présente dans les logs du pipeline :

   ![Logs du plan Terraform](img/terraform_plan_log_v13_0.png)
