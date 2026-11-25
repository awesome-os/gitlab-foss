---
stage: Plan
group: Portfolio Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Gestion des exigences
description: "Critères d'acceptation, rapports de tests des exigences et importation CSV."
---

{{< details >}}

- Édition : GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Grâce aux exigences, vous pouvez définir des critères permettant de vérifier vos produits. Elles peuvent être basées sur les utilisateurs, les parties prenantes, le système, les logiciels ou tout autre élément que vous jugez important à consigner.

Une exigence est un artefact dans GitLab qui décrit le comportement spécifique de votre produit. Les exigences sont pérennes et ne disparaissent pas à moins d'être effacées manuellement.

Si une norme industrielle exige que votre application dispose d'une certaine fonctionnalité ou d'un certain comportement, vous pouvez [créer une exigence](#create-a-requirement) pour en tenir compte. Lorsqu'une fonctionnalité n'est plus nécessaire, vous pouvez [archiver l'exigence associée](#archive-a-requirement).

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une vue d'ensemble, consultez [Requirements Management](https://www.youtube.com/watch?v=uSS7oUNSEoU).
<!-- Video published on 2020-04-09 -->

<i class="fa-youtube-play" aria-hidden="true"></i> Pour une présentation plus approfondie, consultez [GitLab Requirements Traceability Walkthrough](https://youtu.be/VIiuTQYFVa0).
<!-- Video published on 2020-02-12 -->

![La vue de liste des exigences avec des onglets affichant les exigences ouvertes, archivées et toutes les exigences.](img/requirements_list_v13_5.png)

## Créer une exigence {#create-a-requirement}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum, passant de Rapporteur à Planificateur dans GitLab 17.7.

{{< /history >}}

Une liste paginée des exigences est disponible dans chaque projet, et vous pouvez y créer une nouvelle exigence.

Prérequis :

- Vous devez disposer du rôle Planificateur, Rapporteur, Développeur, Mainteneur ou Propriétaire.

Pour créer une exigence :

1. Dans un projet, accédez à **Forfait** > **Exigences**.
1. Sélectionnez **Nouvelle exigence**.
1. Saisissez un titre et une description, puis sélectionnez **Nouvelle exigence**.

![Le formulaire d'exigence dans un panneau latéral droit, où vous saisissez un titre et une description.](img/requirement_create_v13_5.png)

La nouvelle exigence créée apparaît en haut de la liste, celle-ci étant triée par date de création, dans l'ordre décroissant.

## Afficher une exigence {#view-a-requirement}

Vous pouvez afficher une exigence depuis la liste en la sélectionnant.

![Exemple d'une exigence sélectionnée](img/requirement_view_v13_5.png)

Pour modifier une exigence lors de sa consultation, sélectionnez l'icône **Modifier** ({{< icon name="pencil" >}}) à côté du titre de l'exigence.

## Modifier une exigence {#edit-a-requirement}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum, passant de Rapporteur à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez modifier une exigence depuis la page de liste des exigences.

Prérequis :

- Vous devez disposer du rôle Planificateur, Rapporteur, Développeur, Mainteneur ou Propriétaire, ou être l'auteur ou le responsable de l'exigence.

Pour modifier une exigence :

1. Dans la liste des exigences, sélectionnez l'icône **Modifier** ({{< icon name="pencil" >}}).
1. Mettez à jour le titre et la description dans le champ de saisie de texte. Vous pouvez également marquer une exigence comme satisfaite dans le formulaire de modification en utilisant la case à cocher **Satisfait**.
1. Sélectionnez **Enregistrer les modifications**.

## Archiver une exigence {#archive-a-requirement}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum, passant de Rapporteur à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez archiver une exigence ouverte depuis l'onglet **Ouvrir**.

Prérequis :

- Vous devez disposer du rôle Planificateur, Rapporteur, Développeur, Mainteneur ou Propriétaire, ou être l'auteur ou le responsable de l'exigence.

Pour archiver une exigence, sélectionnez **Archiver** ({{< icon name="archive" >}}).

Dès qu'une exigence est archivée, elle n'apparaît plus dans l'onglet **Ouvrir**.

## Rouvrir une exigence {#reopen-a-requirement}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum, passant de Rapporteur à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez afficher la liste des exigences archivées dans l'onglet **Archivées**.

Prérequis :

- Vous devez disposer du rôle Planificateur, Rapporteur, Développeur, Mainteneur ou Propriétaire, ou être l'auteur ou le responsable de l'exigence.

![La vue de liste des exigences archivées.](img/requirements_archived_list_view_v13_1.png)

Pour rouvrir une exigence archivée, sélectionnez **Rouvrir**.

Dès qu'une exigence est rouverte, elle n'apparaît plus dans l'onglet **Archivées**.

## Rechercher une exigence {#search-for-a-requirement}

Vous pouvez rechercher une exigence depuis la page de liste des exigences selon les critères suivants :

- Titre
- Nom d'utilisateur de l'auteur
- Statut (satisfait, échoué ou manquant)

Pour rechercher une exigence :

1. Dans un projet, accédez à **Forfait** > **Exigences** > **Liste**.
1. Sélectionnez le champ **Rechercher ou filtrer les résultats**. Une liste déroulante apparaît.
1. Sélectionnez l'auteur ou le statut de l'exigence dans la liste déroulante, ou saisissez du texte brut pour rechercher par titre d'exigence.
1. Appuyez sur <kbd>Entrée</kbd> sur votre clavier pour filtrer la liste.

Vous pouvez également trier la liste des exigences par :

- Date de création
- Date de mise à jour

## Autoriser la satisfaction des exigences depuis un job CI {#allow-requirements-to-be-satisfied-from-a-ci-job}

GitLab prend désormais en charge les [rapports de tests des exigences](../../../ci/yaml/artifacts_reports.md#artifactsreportsrequirements). Vous pouvez ajouter un job à votre pipeline CI qui, lorsqu'il est déclenché, marque toutes les exigences existantes comme Satisfait (vous pouvez manuellement satisfaire une exigence dans le formulaire de modification [modifier une exigence](#edit-a-requirement)).

### Ajouter le job manuel au CI {#add-the-manual-job-to-ci}

Pour configurer votre CI afin de marquer les exigences comme Satisfait lorsque le job manuel est déclenché, ajoutez le code ci-dessous à votre fichier `.gitlab-ci.yml`.

```yaml
requirements_confirmation:
  when: manual
  allow_failure: false
  script:
    - mkdir tmp
    - echo "{\"*\":\"passed\"}" > tmp/requirements.json
  artifacts:
    reports:
      requirements: tmp/requirements.json
```

Cette définition ajoute un job déclenché manuellement (`when: manual`) au pipeline CI. Il est bloquant (`allow_failure: false`), mais c'est à vous de choisir les conditions de déclenchement du job CI. Vous pouvez également utiliser n'importe quel job CI existant pour marquer toutes les exigences comme satisfaites, à condition que l'artefact `requirements.json` soit généré et téléversé par le job CI.

Lorsque vous déclenchez manuellement ce job, le fichier `requirements.json` contenant `{"*":"passed"}` est téléversé en tant qu'artefact sur le serveur. Côté serveur, le rapport d'exigences est vérifié pour l'enregistrement « tout réussi » (`{"*":"passed"}`), et en cas de succès, il marque toutes les exigences ouvertes existantes comme Satisfait.

#### Spécification des exigences individuelles {#specifying-individual-requirements}

Il est possible de spécifier des exigences individuelles et leurs statuts.

Si les exigences suivantes existent :

- `REQ-1` (avec IID `1`)
- `REQ-2` (avec IID `2`)
- `REQ-3` (avec IID `3`)

Il est possible de spécifier que la première exigence a réussi et que la seconde a échoué. Les valeurs valides sont « passed » et « failed ». En omettant l'IID d'une exigence (dans ce cas l'IID `3` de `REQ-3`), aucun résultat n'est enregistré.

```yaml
requirements_confirmation:
  when: manual
  allow_failure: false
  script:
    - mkdir tmp
    - echo "{\"1\":\"passed\", \"2\":\"failed\"}" > tmp/requirements.json
  artifacts:
    reports:
      requirements: tmp/requirements.json
```

### Ajouter le job manuel au CI de manière conditionnelle {#add-the-manual-job-to-ci-conditionally}

Pour configurer votre CI afin d'inclure le job manuel uniquement lorsqu'il existe des exigences ouvertes, ajoutez une règle qui vérifie la variable CI/CD `CI_HAS_OPEN_REQUIREMENTS`.

```yaml
requirements_confirmation:
  rules:
    - if: '$CI_HAS_OPEN_REQUIREMENTS == "true"'
      when: manual
    - when: never
  allow_failure: false
  script:
    - mkdir tmp
    - echo "{\"*\":\"passed\"}" > tmp/requirements.json
  artifacts:
    reports:
      requirements: tmp/requirements.json
```

Étant donné que les exigences et les [cas de test](../../../ci/test_cases/_index.md) sont en cours de [migration vers les éléments de travail](https://gitlab.com/groups/gitlab-org/-/epics/5171), si vous avez activé les éléments de travail dans un projet, vous devez remplacer `requirements` dans la configuration précédente par `requirements_v2` :

```yaml
      requirements_v2: tmp/requirements.json
```

## Importer des exigences depuis un fichier CSV {#import-requirements-from-a-csv-file}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum, passant de Rapporteur à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous devez disposer du rôle Planificateur, Rapporteur, Développeur, Mainteneur ou Propriétaire.

Vous pouvez importer des exigences dans un projet en téléversant un [fichier CSV](https://en.wikipedia.org/wiki/Comma-separated_values) avec les colonnes `title` et `description`.

Après l'importation, l'utilisateur ayant téléversé le fichier CSV est défini comme l'auteur des exigences importées.

### Importer le fichier {#import-the-file}

Avant d'importer votre fichier :

- Envisagez d'importer un fichier de test contenant seulement quelques exigences. Il n'existe aucun moyen d'annuler une importation volumineuse sans utiliser l'API GitLab.
- Assurez-vous que votre fichier CSV respecte les exigences relatives au [format de fichier](#imported-csv-file-format).

Pour importer des exigences :

1. Dans un projet, accédez à **Forfait** > **Exigences**.
   - Pour un projet avec des exigences, dans le coin supérieur droit, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Importer des exigences** ({{< icon name="import" >}}).
   - Pour un projet sans exigences, au milieu de la page, sélectionnez **Importer un fichier CSV**.
1. Sélectionnez le fichier, puis sélectionnez **Importer des exigences**.

Le fichier est traité en arrière-plan et un e-mail de notification vous est envoyé une fois l'importation terminée.

### Format du fichier CSV importé {#imported-csv-file-format}

Lors de l'importation d'exigences depuis un fichier CSV, celui-ci doit être formaté d'une certaine manière :

- **Ligne d'en-tête** : les fichiers CSV doivent inclure les en-têtes suivants : `title` et `description`. Les en-têtes ne sont pas sensibles à la casse.
- **Colonnes** : les données des colonnes autres que `title` et `description` ne sont pas importées.
- **Séparateurs** : le séparateur de colonnes est automatiquement détecté à partir de la ligne d'en-tête. Les caractères séparateurs pris en charge sont : les virgules (`,`), les points-virgules (`;`) et les tabulations (`\t`). Le séparateur de ligne peut être `CRLF` ou `LF`.
- **Caractère guillemet double** : le caractère guillemet double (`"`) est utilisé pour délimiter les champs, permettant l'utilisation du séparateur de colonnes dans un champ (voir la troisième ligne dans les exemples de données CSV ci-dessous). Pour insérer un guillemet double (`"`) dans un champ délimité, utilisez deux guillemets doubles consécutifs (`""`).
- **Lignes de données** : sous la ligne d'en-tête, les lignes suivantes doivent respecter le même ordre de colonnes. Le texte du titre est obligatoire, tandis que la description est facultative et peut être laissée vide.

Exemple de données CSV :

```plaintext
title,description
My Requirement Title,My Requirement Description
Another Title,"A description, with a comma"
"One More Title","One More Description"
```

### Taille du fichier {#file-size}

La limite dépend de la valeur de configuration Taille maximale des pièces jointes pour l'instance GitLab.

Pour GitLab.com, elle est définie à 10 Mo.

## Exporter les exigences vers un fichier CSV {#export-requirements-to-a-csv-file}

{{< history >}}

- [Modification](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/169256) du rôle utilisateur minimum, passant de Rapporteur à Planificateur dans GitLab 17.7.

{{< /history >}}

Vous pouvez exporter les exigences GitLab vers un [fichier CSV](https://en.wikipedia.org/wiki/Comma-separated_values) envoyé à votre adresse e-mail de notification par défaut en tant que pièce jointe.

En exportant les exigences, vous et votre équipe pouvez les importer dans un autre outil ou les partager avec vos clients. L'exportation des exigences peut faciliter la collaboration avec les systèmes de niveau supérieur, ainsi que les tâches d'audit et de conformité réglementaire.

Prérequis :

- Vous devez disposer du rôle Planificateur, Rapporteur, Développeur, Mainteneur ou Propriétaire.

Pour exporter les exigences :

1. Dans un projet, accédez à **Forfait** > **Exigences**.
1. Dans le coin supérieur droit, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Exporter au format CSV** ({{< icon name="export" >}}).

   Une boîte de dialogue de confirmation apparaît.

1. Sous **Options d'exportation avancées**, sélectionnez les champs à exporter.

   Tous les champs sont sélectionnés par défaut. Pour exclure un champ de l'exportation, décochez la case correspondante.

1. Sélectionnez **Exporter les exigences**. Le fichier CSV exporté est envoyé à l'adresse e-mail associée à votre compte.

### Format du fichier CSV exporté {#exported-csv-file-format}

<!-- vale gitlab_base.Spelling = NO -->

Vous pouvez prévisualiser le fichier CSV exporté dans un tableur, tel que Microsoft Excel, OpenOffice Calc ou Google Sheets.

<!-- vale gitlab_base.Spelling = YES -->

Le fichier CSV exporté contient les en-têtes suivants :

- ID de l'exigence
- Titre
- Description
- Auteur
- Nom d'utilisateur de l'auteur
- Date de création (UTC)
- État
- Statut mis à jour le (UTC)
