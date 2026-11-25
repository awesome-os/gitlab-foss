---
stage: Security Risk Management
group: Security Policies
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Tutoriel : configurer une politique d'exécution de pipeline"
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Ce tutoriel vous montre comment créer et configurer une [politique d'exécution de pipeline](../../user/application_security/policies/pipeline_execution_policies.md) avec la stratégie `inject_policy`. Vous pouvez utiliser ces politiques pour vous assurer que les pipelines requis sont toujours exécutés dans les projets auxquels la politique est liée.

Dans ce tutoriel, vous pouvez créer une politique d'exécution de pipeline, la lier à un projet de test et vérifier que le pipeline s'exécute.

Pour configurer une politique d'exécution de pipeline, vous devez :

1. [Créer un projet de test](#create-a-test-project).
1. [Créer un fichier de configuration CI/CD](#create-a-cicd-configuration-file).
1. [Ajouter une politique d'exécution de pipeline](#add-a-pipeline-execution-policy).
1. [Tester la politique d'exécution de pipeline](#test-the-pipeline-execution-policy).

## Avant de commencer {#before-you-begin}

Pour suivre ce tutoriel, vous avez besoin :

- Des autorisations pour créer des projets dans un groupe existant.
- Des autorisations pour créer des politiques de sécurité et y établir des liens.

## Créer un projet de test {#create-a-test-project}

Pour commencer, créez un projet de test auquel appliquer votre politique d'exécution de pipeline :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Nouveau projet**.
1. Sélectionnez **Créer un projet vide**.
1. Remplissez les champs.
   - **Nom du projet** : `my-pipeline-execution-policy`.
   - Cochez la case **Activer les tests statiques de sécurité des applications (SAST)**.
1. Sélectionnez **Créer le projet**.

## Créer un fichier de configuration CI/CD {#create-a-cicd-configuration-file}

Ensuite, créez le fichier de configuration CI/CD que vous souhaitez que votre politique d'exécution de pipeline applique :

1. Dans la barre latérale gauche, sélectionnez **Code** > **Dépôt**.
1. Dans la liste déroulante **Ajouter** (+), sélectionnez **Nouveau fichier**.
1. Dans le champ **Nom du fichier**, saisissez `pipeline-config.yml`.
1. Dans le contenu du fichier, copiez ce qui suit :

   ```yaml
   ---
   # This file defines the CI/CD jobs that will be
   # enforced by the pipeline execution policy
   enforced-security-scan:
     stage: .pipeline-policy-pre
     script:
       - echo "Running enforced security scan from pipeline execution policy"
       - echo "This job cannot be skipped by developers"
       - echo "Checking for security vulnerabilities..."
       - echo "Security scan completed successfully"
     rules:
       - when: always

   enforced-test-job:
     stage: test
     script:
       - echo "Running enforced test job in test stage"
       - echo "Creating test stage if it doesn't exist"
       - echo "Performing mandatory testing requirements..."
       - echo "Enforced tests completed successfully"
     rules:
       - when: always

   enforced-compliance-check:
     stage: .pipeline-policy-post
     script:
       - echo "Running enforced compliance check"
       - echo "Verifying pipeline compliance requirements"
       - echo "Compliance check passed"
     rules:
       - when: always
   ```

1. Dans le champ **Message de commit**, saisissez `Add pipeline execution policy configuration`.
1. Sélectionnez **Valider les modifications**.

## Ajouter une politique d'exécution de pipeline {#add-a-pipeline-execution-policy}

Ensuite, ajoutez une politique d'exécution de pipeline à votre projet de test :

1. Sélectionnez **Sécurisation** > **Politiques**.
1. Sélectionnez **Nouvelle politique**.
1. Dans **Politique d'exécution de pipeline**, sélectionnez **Sélectionner la politique**.
1. Remplissez les champs.
   - **Nom** : `Enforce Security and Compliance Jobs`
   - **Description** : `Enforces required security and compliance jobs across all pipelines`
   - **État de la politique** : **Activé**

1. Définissez **Actions** comme suit :

   ![Actions de la politique d'exécution de pipeline](img/pipeline_execution_policy_actions_v18_7.png)
1. Sélectionnez **Configurer avec une requête de fusion**.
1. Examinez le YAML de politique généré dans l'onglet **Modifications** de la merge request. La politique devrait ressembler à ceci :

   ```yaml
   ---
   pipeline_execution_policy:
   - name: Enforce Security and Compliance Jobs
     description: Enforces required security and compliance jobs across all pipelines
     enabled: true
     pipeline_config_strategy: inject_policy
     content:
       include:
       - project: [group]/my-pipeline-execution-policy
         file: pipeline-config.yml
     skip_ci:
       - allowed: false
   ```

1. Accédez à l'onglet **Vue d'ensemble** et sélectionnez **Fusionner**. Cette étape crée un nouveau projet appelé `My Pipeline Execution Policy - Security Policy Project`. Les projets de politique de sécurité sont utilisés pour stocker les politiques de sécurité afin que la même politique puisse être appliquée à plusieurs projets.
1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le projet `my-pipeline-execution-policy`.
1. Sélectionnez **Sécurisation** > **Politiques**.

   Vous pouvez voir la liste des politiques ajoutées lors des étapes précédentes.

## Tester la politique d'exécution de pipeline {#test-the-pipeline-execution-policy}

Testez maintenant votre politique d'exécution de pipeline en créant une merge request :

1. Dans la barre latérale gauche, sélectionnez **Code** > **Dépôt**.
1. Dans la liste déroulante **Ajouter** (+), sélectionnez **Nouveau fichier**.
1. Dans le champ **Nom du fichier**, saisissez `test-file.txt`.
1. Dans le contenu du fichier, ajoutez :

   ```plaintext
   This is a test file to trigger the pipeline execution policy.
   ```

1. Dans le champ **Message de commit**, saisissez `Add test file to trigger pipeline`.
1. Dans le champ **Branche cible**, saisissez `test-policy-branch`.
1. Sélectionnez **Valider les modifications**.
1. Lorsque la page de merge request s'ouvre, sélectionnez **Créer une requête de fusion**.

   Attendez que le pipeline se termine. Cette opération peut prendre quelques minutes.
1. Dans la merge request, sélectionnez l'onglet **Pipelines** et sélectionnez le pipeline créé.

   Vous devriez voir les jobs appliqués s'exécuter :
   - `enforced-security-scan` dans l'étape `.pipeline-policy-pre` (s'exécute en premier)
   - `enforced-test-job` dans l'étape `test` (injecté par la politique)
   - `enforced-compliance-check` dans l'étape `.pipeline-policy-post` (s'exécute en dernier)

1. Sélectionnez le job `enforced-security-scan` pour afficher ses logs et confirmer qu'il a exécuté l'analyse de sécurité telle que définie dans la politique.

La politique d'exécution de pipeline a correctement appliqué les jobs requis, garantissant leur exécution indépendamment de ce que le développeur inclut dans le fichier `.gitlab-ci.yml` de son projet.

Vous savez maintenant comment configurer et utiliser les politiques d'exécution de pipeline pour imposer l'utilisation des jobs CI/CD requis dans les projets de votre organisation !

## Étapes suivantes {#next-steps}

- En savoir plus sur les [stratégies de configuration des politiques d'exécution de pipeline](../../user/application_security/policies/pipeline_execution_policies.md#pipeline-configuration-strategies).
- Explorer les [exemples avancés de politique d'exécution de pipeline](../../user/application_security/policies/pipeline_execution_policies.md#examples).
