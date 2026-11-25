---
stage: Tutorials
group: Tutorials
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : modifier un fichier avec l''éditeur web'
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les fichiers d'un [projet](../../user/project/organize_work_with_projects.md) peuvent être modifiés par les membres de l'équipe disposant d'un [accès approprié](../../user/project/members/_index.md).

Découvrez comment modifier un fichier individuel directement dans l'interface de GitLab à l'aide du simple Web Editor.

## Sélectionnez le fichier que vous souhaitez modifier {#select-the-file-you-wish-to-edit}

Tout d'abord, accédez à la page d'accueil du projet pour obtenir la liste des fichiers qu'il contient.

![Liste des fichiers sur la page d'accueil du projet. Elle montre un projet nommé « Company Handbook » avec des fichiers dont les noms ressemblent à « break-room.md ».](img/project_file_listing_v18_9.png)

Sélectionnez n'importe quel fichier pour afficher ses détails.

![Le fichier « break-room.md » est affiché en détail. Son contenu présente des équipements tels que des jeux de cartes, des jeux vidéo et un billard.](img/file_in_detail_v18_9.png)

## Modifier le fichier {#edit-the-file}

Sélectionnez la liste déroulante **Modifier**, puis sélectionnez **Modifier le fichier unique**.

![Le bouton Modifier se développe pour afficher les options de la liste déroulante : « Open in Web IDE » et « Edit Single File ».](img/edit_dropdown_v18_9.png)

Dans l'éditeur, apportez les modifications nécessaires au fichier.

![Le fichier réapparaît dans un champ de texte modifiable, permettant à l'utilisateur d'en modifier le contenu.](img/edit_file_v18_9.png)

## Validez vos modifications et créez une merge request {#commit-your-changes-and-create-a-merge-request}

Il est possible de committer (enregistrer) vos modifications directement dans le fichier. Toutefois, cette pratique n'est pas recommandée pour la plupart des équipes, car il est conseillé de faire réviser vos modifications par un membre de l'équipe au préalable. Dans cette étape, vous allez créer une branche et une merge request avec les nouvelles modifications.

Une fois vos modifications terminées :

1. Sélectionnez **Valider les modifications**.
1. Renseignez le champ **message de validation** avec une description de vos modifications.
1. Sous **Branche**, sélectionnez **Valider dans une nouvelle branche**.
1. Sous **Valider dans une nouvelle branche**, saisissez un nom pour votre nouvelle branche ou conservez celui généré automatiquement.
1. Assurez-vous que **Créer une requête de fusion pour cette modification** est sélectionné.

![Le formulaire de validation des modifications avec des valeurs d'exemple. Le message de validation est « Remove mention of the ping-pong table », « commit to a new branch » est sélectionné et la branche est nommée « ping-pong-table-removal ».](img/commit_changes_v18_9.png)

Enfin, sélectionnez **Valider les modifications** pour committer vos modifications dans la nouvelle branche. Le formulaire de la nouvelle merge request s'affiche. Pour créer la requête, procédez comme suit :

1. Définissez le champ **Intitulé** avec un résumé approprié des modifications.
1. Ajoutez plus de détails sur vos modifications dans le champ **Description**.
1. Définissez la **Personne assignée** sur vous-même.
1. Si vous savez qui doit réviser vos modifications, définissez le **Relecteur**.
1. Facultatif. Définissez le [jalon](../../user/project/milestones/_index.md) de votre merge request.
1. Facultatif. Définissez des labels pour votre merge request afin de mieux la catégoriser.
1. Sélectionnez **Créer une requête de fusion** pour créer votre merge request.

![Le formulaire de la nouvelle merge request, affichant le titre défini comme « Remove mention of the ping-pong table » et la description comme « This merge request removes the ping-pong table from the break room page since we no longer have one. »](img/merge_request_v18_9.png)

Vos modifications se trouvent désormais dans une merge request et sont prêtes à être révisées par un autre contributeur.

## Étapes suivantes {#next-steps}

Vous pouvez ensuite :

- Réviser la merge request d'une autre personne
- [Créer un ticket dans votre projet existant](../create_issue_in_existing_project/_index.md)
