---
stage: Security Risk Management
group: Security Policies
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : configurer une politique d''exécution de scan'
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Ce tutoriel vous montre comment créer et appliquer une [politique d'exécution de scan](../../user/application_security/policies/scan_execution_policies.md). Ces politiques appliquent des outils de sécurité des applications dans le cadre du pipeline CI/CD. Dans ce tutoriel, vous créez une politique pour appliquer la détection des secrets dans le pipeline CI/CD de deux projets.

Dans ce tutoriel, vous allez :

- [Créer le projet A](#create-project-a).
- [Créer la politique d'exécution de scan](#create-the-scan-execution-policy).
- [Tester la politique d'exécution de scan avec le projet A](#test-the-scan-execution-policy-with-project-a).
- [Créer le projet B](#create-project-b).
- [Lier le projet B au projet de politique de sécurité](#link-project-b-to-the-security-policy-project).
- [Tester la politique d'exécution de scan avec le projet B](#test-the-scan-execution-policy-with-project-b).

## Avant de commencer {#before-you-begin}

- Vous devez disposer de l'autorisation de créer de nouveaux projets dans un groupe existant.

## Créer le projet A {#create-project-a}

Dans un workflow standard, vous disposez peut-être déjà d'un projet existant. Dans ce tutoriel, vous partez de zéro, donc la première étape consiste à créer un projet.

Pour créer le projet A :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Nouveau projet**.
1. Sélectionnez **Créer un projet vide**.
1. Remplissez les champs. Pour **Nom du projet**, saisissez `go-example-a`.
1. Sélectionnez **Créer le projet**.
1. Sélectionnez **Ajouter** ({{< icon name="plus" >}}) > **Nouveau fichier**.
1. Saisissez `helloworld.go` dans le nom du fichier.
1. Copiez et collez l'exemple de code Go suivant dans le fichier.

   ```go
   package main
   import "fmt"
   func main() {
       fmt.Println("Hello world")
   }
   ```

1. Sélectionnez **Valider les modifications**.

L'étape suivante consiste à créer une politique d'exécution de scan. Lors de la création de la première politique de sécurité, un projet de politique est créé. Le projet de politique stocke les politiques de sécurité créées dans tous les projets qui y sont liés. Maintenir les politiques séparées des projets qu'elles protègent rend votre configuration de sécurité réutilisable et plus facile à maintenir.

## Créer la politique d'exécution de scan {#create-the-scan-execution-policy}

Pour créer la politique d'exécution de scan :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et recherchez le projet `go-example-a`.
1. Accédez à **Sécuriser** > **Politiques**.
1. Sélectionnez **Nouvelle politique**.
1. Dans la section **Politique d'exécution d'analyses**, sélectionnez **Sélectionner la politique**.
1. Remplissez les champs.
   - **Nom** : appliquer la détection des secrets.
   - **État de la politique** : activée.
   - **Actions** : exécuter un scan de détection des secrets.
   - **Conditions** : se déclenche chaque fois qu'un pipeline s'exécute pour toutes les branches.
1. Sélectionnez **Configurer avec une requête de fusion**.

   Le projet de politique `go-example-a - Security project` est créé, ainsi qu'une merge request.
1. Facultatif. Examinez le YAML de politique généré dans l'onglet **Modifications** de la merge request.
1. Accédez à l'onglet **Vue d'ensemble** et sélectionnez **Fusionner**.
1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et recherchez le projet `go-example-a`.
1. Accédez à **Sécuriser** > **Politiques**.

Vous disposez désormais d'une politique d'exécution de scan qui exécute un scan de détection des secrets sur chaque merge request, pour toute branche. Testez la politique en créant une merge request dans le projet A.

## Tester la politique d'exécution de scan avec le projet A {#test-the-scan-execution-policy-with-project-a}

Pour tester la politique d'exécution de scan :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le projet nommé `go-example-a`.
1. Accédez à **Code** > **Dépôt**.
1. Sélectionnez le fichier `helloworld.go`.
1. Sélectionnez **Édition** > **Modifier un seul fichier**.
1. Ajoutez la ligne suivante immédiatement après la ligne `fmt.Println("hello world")` :

   ```plaintext
   var GitLabFeedToken = "feed_token=eFLISqaBym4EjAefkl58"
   ```

1. Dans le champ **Branche cible**, saisissez `feature-a`.
1. Sélectionnez **Valider les modifications**.
1. Lorsque la page de la merge request s'ouvre, sélectionnez **Créer une requête de fusion**.

   Vérifions si la politique d'exécution de scan a fonctionné. Rappelez-vous que nous avons spécifié que la détection des secrets doit s'exécuter chaque fois qu'un pipeline s'exécute, pour toute branche.
1. Dans la merge request qui vient d'être créée, accédez à l'onglet **Pipelines** et sélectionnez le pipeline créé.

   Vous pouvez voir ici qu'un job de détection des secrets s'est exécuté. Vérifions s'il a détecté le secret de test.
1. Sélectionnez le job de détection des secrets.

   Vers le bas du journal du job, la sortie suivante confirme que l'exemple de secret a été détecté.

   ```plaintext
   [INFO] [secrets] [2023-09-04T03:46:36Z] ▶ 3:46AM INF 1 commits scanned.
   [INFO] [secrets] [2023-09-04T03:46:36Z] ▶ 3:46AM INF scan completed in 60ms
   [INFO] [secrets] [2023-09-04T03:46:36Z] ▶ 3:46AM WRN leaks found: 1
   ```

Vous avez vu la politique fonctionner pour un projet. Créez un autre projet et appliquez la même politique.

## Créer le projet B {#create-project-b}

Pour créer le projet B :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Nouveau projet**.
1. Sélectionnez **Créer un projet vide**.
1. Remplissez les champs. Pour **Nom du projet**, saisissez `go-example-b`.
1. Sélectionnez **Créer le projet**.
1. Sélectionnez **Ajouter** ({{< icon name="plus" >}}) > **Nouveau fichier**.
1. Saisissez `helloworld.go` dans le nom du fichier.
1. Copiez et collez l'exemple de code Go suivant dans le fichier.

   ```go
   package main
   import "fmt"
   func main() {
       fmt.Println("Hello world")
   }
   ```

1. Sélectionnez **Valider les modifications**.

Maintenant que vous avez un autre projet, liez-le au même projet de politique.

## Lier le projet B au projet de politique de sécurité {#link-project-b-to-the-security-policy-project}

Pour lier le projet B au projet de politique de sécurité :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le projet `go-example-b`.
1. Accédez à **Sécuriser** > **Politiques**.
1. Sélectionnez **Modifier le projet de politique**.
1. Sélectionnez la liste déroulante, puis recherchez le projet de politique de sécurité créé au début de ce tutoriel.
1. Sélectionnez **Enregistrer**.

Le lien du projet B au même projet de politique a entraîné l'application de la même politique. Une politique d'exécution de scan exécute un scan de détection des secrets sur chaque merge request, pour toute branche. Testons la politique en créant une merge request dans le projet B.

## Tester la politique d'exécution de scan avec le projet B {#test-the-scan-execution-policy-with-project-b}

Pour tester la politique d'exécution de scan :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le projet `go-example-b`.
1. Accédez à **Code** > **Dépôt**.
1. Sélectionnez le fichier `helloworld.go`.
1. Sélectionnez **Édition** > **Modifier un seul fichier**.
1. Ajoutez la ligne suivante immédiatement après la ligne `fmt.Println("hello world")` :

   ```plaintext
   var AdobeClient = "4ab4b080d9ce4072a6be2629c399d653"
   ```

1. Dans le champ **Branche cible**, saisissez `feature-b`.
1. Sélectionnez **Valider les modifications**.
1. Lorsque la page de la merge request s'ouvre, sélectionnez **Créer une requête de fusion**.

   Vérifions si la politique d'exécution de scan a fonctionné. Rappelez-vous que nous avons spécifié que la détection des secrets doit s'exécuter chaque fois qu'un pipeline s'exécute, pour toute branche.
1. Dans la merge request qui vient d'être créée, accédez à l'onglet **Pipelines** et sélectionnez le pipeline créé.
1. Dans la merge request qui vient d'être créée, sélectionnez l'ID du pipeline.

   Vous pouvez voir ici qu'un job de détection des secrets s'est exécuté. Vérifions s'il a détecté le secret de test.
1. Sélectionnez le job de détection des secrets.

   Vers le bas du journal du job, la sortie suivante confirme que l'exemple de secret a été détecté.

   ```plaintext
   [INFO] [secrets] [2023-09-04T04:22:28Z] ▶ 4:22AM INF 1 commits scanned.
   [INFO] [secrets] [2023-09-04T04:22:28Z] ▶ 4:22AM INF scan completed in 58.2ms
   [INFO] [secrets] [2023-09-04T04:22:28Z] ▶ 4:22AM WRN leaks found: 1
   ```

Félicitations. Vous avez appris à créer une politique d'exécution de scan et à l'appliquer à des projets.
