---
stage: Tenant Scale
group: Organizations
info: For assistance with this tutorial, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments-to-other-projects-and-subjects>.
title: 'Tutoriel : configurer votre organisation'
description: "Configuration, paramétrage, intégration et structure organisationnelle."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

<!-- vale gitlab_base.FutureTense = NO -->

Ce tutoriel vous apprendra à configurer et à gérer l'organisation GitLab de votre entreprise en :

- Créant des groupes, des sous-groupes et des projets
- Attribuant différents rôles aux membres du groupe dans ces groupes, sous-groupes et projets

Dans ce tutoriel, vous êtes l'administrateur informatique d'une petite entreprise de logiciels. Cette entreprise utilise GitLab et est divisée en départements marketing, commercial et développement.

Vous avez déjà configuré les organisations marketing et commerciale. Dans ce tutoriel, vous allez configurer l'organisation de développement logiciel. Cette organisation compte les employés permanents suivants :

- Un administrateur informatique : vous.
- Un chef de produit : Alex Smith.
- Un responsable ingénierie : Blake Wang.
- Trois développeurs logiciels : Charlie Devi, Devon Ivanov et Evan Kim.
- Un designer UX : Frankie Ali.
- Un rédacteur technique : Grayson Garcia.
- Un stratège de contenu contractuel : Hunter Silva.

Vous allez créer :

- L'organisation de développement logiciel.
- Des groupes, des sous-groupes et des projets pour gérer le travail.
- Des utilisateurs à ajouter aux groupes et projets, et à qui attribuer des rôles.
- Un projet dans l'organisation pour un travail spécifique, et l'ajout d'utilisateurs à ce projet.

## Avant de commencer {#before-you-begin}

- Assurez-vous de disposer d'un accès administrateur à GitLab Self-Managed.

## Créer le groupe parent de l'organisation et les sous-groupes {#create-the-organization-parent-group-and-subgroups}

Tout d'abord, vous allez créer un groupe appelé Développement. Le groupe Développement servira de groupe parent pour l'ensemble de l'organisation de développement logiciel.

Pour créer le groupe Développement :

1. Ouvrez GitLab Self-Managed.
1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau groupe**.
1. Sélectionnez **Créer un groupe**.
1. Dans **Nom du groupe**, saisissez `Development`.
1. Sous **URL du groupe**, saisissez `development-group`. Un message indiquant « Group path is available » s'affiche. L'URL du groupe est utilisée pour l'espace de nommage. Un espace de nommage offre un emplacement pour organiser vos projets associés.
1. Sous **Niveau de visibilité**, sélectionnez **Privé**. Ainsi, tous les sous-groupes de ce groupe doivent également être privés.
1. Sous **Qui utilisera ce groupe ?**, sélectionnez **Mon entreprise ou mon équipe**.
1. Dans la liste déroulante **À quoi vous servira ce groupe ?**, sélectionnez **Je souhaite stocker mon code**.
1. N'invitez pas encore de membres GitLab ou d'autres utilisateurs à rejoindre le groupe.
1. Sélectionnez **Créer un groupe**.

Vous avez créé le groupe parent de votre organisation. Ensuite, vous allez créer des sous-groupes.

## Créer les sous-groupes de l'organisation {#create-the-organization-subgroups}

Pour ce tutoriel, nous supposons que le Développement est organisé selon les domaines de travail suivants :

- Gestion de produit
- Ingénierie
- Expérience utilisateur
  - Conception UX
  - Rédaction technique

Vous allez maintenant créer des sous-groupes pour refléter cette structure organisationnelle.

Les sous-groupes et les projets doivent avoir des paramètres de visibilité au moins aussi restrictifs que ceux de leur groupe parent. Par exemple, vous ne pouvez pas avoir un groupe parent privé et un sous-groupe public.

Pour créer les sous-groupes de votre organisation :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Voir tous mes groupes**.
1. Sélectionnez **Développement**. Un label **Propriétaire** doit apparaître à côté du nom du groupe, car vous disposez du rôle Propriétaire.
1. Sur la page de présentation du groupe parent, sélectionnez **Créer un sous-groupe**.
1. Dans **Nom du sous-groupe**, saisissez `Product Management`.
1. Le **Slug du sous-groupe** est automatiquement complété avec **product-management**. Ne modifiez pas ce champ.
1. Pour **Niveau de visibilité**, vous ne pouvez sélectionner que **Privé**, car le groupe parent, Développement, est également privé.
1. Sélectionnez **Créer un sous-groupe**.
1. Répétez ces étapes pour les sous-groupes suivants :
   - `Engineering`
   - `User Experience`

Ensuite, créez les sous-groupes Conception UX et Rédaction technique. Ces sous-groupes seront imbriqués sous le sous-groupe Expérience utilisateur :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**.
1. Sélectionnez **Voir tous mes groupes**.
1. Sélectionnez **Développement**.
1. Sous l'onglet **Sous‐groupes et projets**, sélectionnez **Expérience utilisateur**.
1. Sur la page de présentation de **Expérience utilisateur**, sélectionnez **Créer un sous-groupe**.
1. Dans **Nom du sous-groupe**, saisissez `UX Design`.
1. Sélectionnez **Créer un sous-groupe**.
1. Répétez ces étapes pour le sous-groupe Rédaction technique.

Vous avez maintenant créé les sous-groupes de votre organisation. Ensuite, vous allez créer des utilisateurs pour l'organisation.

## Créer les utilisateurs de votre organisation {#create-the-users-for-your-organization}

Vous allez maintenant créer manuellement les utilisateurs de votre organisation. Ces utilisateurs sont des utilisateurs de test. Pour créer le premier utilisateur de test, Alex Smith :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Vue d'ensemble** > **Utilisateurs**.
1. Sélectionnez **Nouvel utilisateur**.
1. Renseignez les champs obligatoires :
   - **Nom** : `Alex Smith`
   - **Nom d'utilisateur** : `alexsmith`
   - **Courriel** : `alexsmith@example.com`
   - Laissez tous les autres champs tels quels.
1. Sélectionnez **Créer un utilisateur**.

Pour les utilisateurs réels, un lien de réinitialisation est envoyé à l'adresse e-mail de l'utilisateur, et cet utilisateur est contraint de définir son mot de passe lors de sa première connexion. Cependant, comme cet utilisateur est un utilisateur de test avec une adresse e-mail fictive, vous devez définir le mot de passe de l'utilisateur sans recourir à la confirmation par e-mail.

### Définir le mot de passe de l'utilisateur de test {#set-the-test-users-password}

Après avoir créé l'utilisateur, vous serez redirigé vers la page de présentation de l'utilisateur. Vous pouvez également, dans la barre latérale gauche, sélectionner **Utilisateurs** et rechercher l'utilisateur.

Après avoir sélectionné l'utilisateur :

1. Sélectionner **Éditer**.
1. Renseignez les champs **Mot de passe** et **Confirmation du mot de passe**.
1. Sélectionnez **Enregistrer les modifications**.

Vous avez créé le premier utilisateur de test. Répétez maintenant ces étapes pour les autres utilisateurs :

| Nom             | Nom d'utilisateur        | E-mail |
|------------------|-----------------|-------|
| `Blake Wang`     | `blakewang`     | `blakewang@example.com` |
| `Charlie Devi`   | `charliedevi`   | `charliedevi@example.com` |
| `Devon Ivanov`   | `devonivanov`   | `devonivanov@example.com` |
| `Evan Kim`       | `evankim`       | `evankim@example.com` |
| `Frankie Ali`    | `frankieali`    | `frankieali@example.com` |
| `Grayson Garcia` | `graysongarcia` | `graysongarcia@example.com` |
| `Hunter Silva`   | `huntersilva`   | `huntersilva@example.com` |

Vous avez créé les utilisateurs de votre organisation. Ensuite, vous allez ajouter ces utilisateurs aux différents groupes et sous-groupes.

## Ajouter des utilisateurs au groupe et aux sous-groupes {#add-users-to-the-group-and-subgroups}

Vous pouvez accorder aux utilisateurs l'accès à tous les projets d'un groupe en les ajoutant à ce groupe.

Tout d'abord, vous allez ajouter tous les utilisateurs au groupe parent, Développement.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe **Développement**.
1. Sélectionnez **Gérer** > **Membres**.
1. Sélectionnez **Inviter des membres**.
1. Dans la liste déroulante **Nom d'utilisateur, nom ou adresse e-mail**, sélectionnez `Alex Smith`.
1. Dans la liste déroulante **Sélectionner le rôle maximal**, sélectionnez **Propriétaire**.
1. Laissez le champ **Date d'expiration de l'accès** vide.
1. Sélectionnez **Inviter**.
1. Répétez ce processus pour les utilisateurs suivants :

   | Utilisateur           | Rôle       | Date d'expiration de l'accès |
   |----------------|------------|------------------------|
   | Blake Wang     | Chargé de maintenance | Laisser vide            |
   | Charlie Devi   | Développeur  | Laisser vide            |
   | Devon Ivanov   | Développeur  | Laisser vide            |
   | Evan Kim       | Développeur  | Laisser vide            |
   | Frankie Ali    | Rapporteur   | Laisser vide            |
   | Grayson Garcia | Rapporteur   | Laisser vide            |
   | Hunter Silva   | Invité      | `2025-12-31`           |

   Vous pouvez inviter plusieurs utilisateurs en même temps s'ils ont le même rôle et la même date d'expiration d'accès.

### Vérifier que tout est correctement configuré {#confirm-that-everything-is-set-up-correctly}

Sur la page **Membres du groupe** du groupe Développement et de tous les sous-groupes, vérifiez l'appartenance à ces groupes.

- La **Source** est l'origine de l'appartenance de l'utilisateur à ce groupe. Les membres ajoutés sont des membres directs, car vous les avez ajoutés directement au groupe.
- Le **Rôle** correspond au niveau d'accès le plus élevé que les membres ajoutés sont autorisés à avoir dans ce groupe. Vous pouvez sélectionner le rôle pour modifier les rôles des membres ajoutés dans ce groupe.

Tous les utilisateurs que vous avez ajoutés en tant que membres du groupe parent sont également membres de tous les sous-groupes avec le même rôle.

#### Filtrer un sous-groupe par type d'appartenance {#filter-a-subgroup-on-membership-type}

Vous pouvez filtrer un sous-groupe pour afficher les utilisateurs qui sont membres directs de ce sous-groupe et ceux qui ont hérité leur appartenance à ce sous-groupe depuis le groupe parent.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe **Développement**.
1. Sélectionnez le sous-groupe **Expérience utilisateur**.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sur la page **Membres**, sélectionnez le champ **Filtrer les membres**.
1. Sélectionnez **Appartenance**, puis sélectionnez **Indirect** et appuyez sur <kbd>Return</kbd>.

Vous ne voyez désormais que les membres du sous-groupe Expérience utilisateur qui ont hérité leur appartenance à ce sous-groupe. Vous pouvez vérifier les membres hérités en consultant la colonne **Source** de chaque membre. Elle doit indiquer : `Inherited from Development`.

Vous souhaitez que chaque utilisateur soit uniquement membre du sous-groupe associé à son rôle dans votre organisation. Vous décidez de retirer les utilisateurs des groupes et des sous-groupes.

## Retirer des utilisateurs des groupes et des sous-groupes {#remove-users-from-the-groups-and-subgroups}

Vous ne pouvez pas retirer les membres des sous-groupes directement. Vous pouvez uniquement les retirer du groupe parent.

Revenez au groupe parent et retirez tous les membres sauf Alex Smith :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe parent.
1. Sélectionnez **Gérer** > **Membres**.
1. Sur la ligne du membre que vous souhaitez retirer, sélectionnez l'ellipse verticale ({{< icon name="ellipsis_v" >}}), puis sélectionnez **Supprimer le membre**.
1. Dans la boîte de dialogue de confirmation **Supprimer le membre**, cochez la case **Supprimer également l'appartenance des utilisateurs directs des projets et sous-groupes**.
1. Sélectionnez **Supprimer le membre**.

Le groupe parent et les sous-groupes ne comptent désormais qu'un seul membre, qui dispose du rôle Propriétaire.

Ensuite, vous allez ajouter des utilisateurs directement aux sous-groupes.

## Ajouter des utilisateurs aux sous-groupes {#add-users-to-the-subgroups}

Vous allez maintenant ajouter des utilisateurs directement aux différents sous-groupes.

### Ajouter des utilisateurs au sous-groupe Gestion de produit {#add-users-to-the-product-management-subgroup}

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe **Développement**.
1. Sélectionnez le sous-groupe **Product Management**.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.

En dehors de vous, Alex est le seul membre de ce sous-groupe et est un membre direct, ce qui est correct. Cependant, vous estimez qu'ils devraient avoir le rôle Chargé de maintenance plutôt que le rôle Propriétaire.

#### Modifier le rôle d'un utilisateur dans le sous-groupe {#change-user-role-in-the-subgroup}

Vous ne pouvez pas modifier directement leur rôle sur la page des membres. Pour modifier leur rôle dans le sous-groupe, invitez-les dans le sous-groupe en tant que Chargé de maintenance.

1. Sélectionnez **Inviter des membres**.
1. Renseignez les champs pour le chef de produit, Alex Smith.
   - Attribuez à Alex le rôle **Chargé de maintenance**.
   - Laissez le champ **Date d'expiration de l'accès** vide.
1. Sélectionnez **Inviter**.

Le message suivant s'affiche :

```plaintext
The following member couldn't be invited
Review the invite errors and try again:
- Alex Smith: Access level should be greater than or equal to Owner inherited membership from group Development
```

> [!note]
> Vous ne pouvez pas attribuer à Alex un rôle de sous-groupe avec un niveau d'accès inférieur à son rôle pour le groupe parent du sous-groupe, car il dispose d'une appartenance héritée du groupe parent.

Vous décidez de conserver Alex en tant que Propriétaire dans ce sous-groupe, car cela est approprié compte tenu de son rôle au sein de l'organisation. Sélectionnez **Annuler** pour annuler cette invitation.

Le sous-groupe Gestion de produit dispose des membres et des rôles appropriés. Ensuite, vous allez ajouter des utilisateurs au sous-groupe Ingénierie.

### Ajouter des utilisateurs au sous-groupe Ingénierie {#add-users-to-the-engineering-subgroup}

Vous allez maintenant inviter des utilisateurs dans le sous-groupe Ingénierie.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe **Développement**.
1. Sélectionnez le sous-groupe **Ingénierie**.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**. Les seuls membres sont vous et Alex. Les deux membres ont le rôle Propriétaire, qui est un rôle hérité.
1. Sélectionnez **Inviter des membres**.
1. Renseignez les champs pour les membres suivants :

   | Utilisateur         | Rôle       | Date d'expiration de l'accès |
   |--------------|------------|------------------------|
   | Blake Wang   | Chargé de maintenance | Laisser vide            |
   | Charlie Devi | Développeur  | Laisser vide            |
   | Devon Ivanov | Développeur  | Laisser vide            |
   | Evan Kim     | Développeur  | Laisser vide            |

1. Sélectionnez **Inviter**.

   Blake Wang a le rôle Chargé de maintenance dans ce sous-groupe, conformément à ses responsabilités en tant que responsable ingénierie. Les trois développeurs ont tous le rôle Développeur, qui est un rôle direct.
1. Vous pouvez modifier leurs rôles directement sur la page des membres de ce sous-groupe. Sous **Rôle**, sélectionnez `Maintainer` pour changer le rôle de Blake Wang en Propriétaire pour ce sous-groupe.
1. Revenez à la page des membres du groupe Développement. Vous constatez que les membres du sous-groupe Ingénierie ne sont pas membres du groupe parent.

En ajoutant les utilisateurs directement aux groupes et sous-groupes dont ils doivent être membres, vous évitez que des utilisateurs soient membres de groupes inutilement. Vous pouvez ainsi contrôler l'accès aux différents groupes et projets de manière plus précise.

## Ajouter des utilisateurs au sous-groupe Expérience utilisateur {#add-users-to-the-user-experience-subgroup}

Le sous-groupe Expérience utilisateur comprend deux sous-groupes imbriqués supplémentaires :

- Conception UX
- Rédaction technique

En termes d'utilisateurs, Conception UX doit uniquement inclure Frankie Ali et Hunter Silva, et Rédaction technique doit uniquement inclure Grayson Garcia.

Si vous ajoutez les trois utilisateurs au sous-groupe Expérience utilisateur, ils seront tous inclus dans les deux sous-groupes imbriqués en raison des autorisations héritées.

Par conséquent, vous allez ajouter ces utilisateurs directement au sous-groupe imbriqué approprié plutôt qu'au sous-groupe Expérience utilisateur.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe **Développement**.
1. Sélectionnez le sous-groupe **Expérience utilisateur**, puis le sous-groupe **Conception UX**.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**. Vous et Alex Smith êtes les seuls membres. Il s'agit de rôles hérités.
1. Sélectionnez **Inviter des membres**.
1. Renseignez les champs et sélectionnez **Inviter** pour les membres suivants :

   | Utilisateur         | Rôle       | Date d'expiration de l'accès |
   |--------------|------------|------------------------|
   | Frankie Ali  | Chargé de maintenance | Laisser vide            |
   | Hunter Silva | Invité      | `2025-12-31`           |

1. Répétez l'opération pour le sous-groupe **Rédaction technique** :

   | Utilisateur           | Rôle       | Date d'expiration de l'accès |
   |----------------|------------|------------------------|
   | Grayson Garcia | Chargé de maintenance | Laisser vide            |

Vous avez ajouté les utilisateurs à leurs sous-groupes imbriqués appropriés. Vous décidez que Grayson Garcia doit également faire partie du sous-groupe **Expérience utilisateur**.

### Ajouter des utilisateurs à d'autres sous-groupes {#add-users-to-other-subgroups}

Vous pouvez ajouter Grayson au sous-groupe **Expérience utilisateur** avec un rôle spécifique, tout en conservant son rôle pour le sous-groupe **Rédaction technique**.

1. Accédez au sous-groupe **Expérience utilisateur**.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**. Vous et Alex Smith êtes les seuls membres. Il s'agit de rôles hérités.
1. Sélectionnez **Inviter des membres**.
1. Invitez Grayson Garcia en tant que Développeur, un rôle avec un niveau d'autorisations inférieur à son rôle Chargé de maintenance pour le sous-groupe **Rédaction technique**.

Attribuer le rôle Développeur à Grayson signifie qu'il ne dispose pas d'un niveau d'autorisations inutilement élevé dans le sous-groupe Expérience utilisateur.

Cependant, en raison des autorisations héritées, l'ajout de Grayson Garcia au sous-groupe Expérience utilisateur l'ajoute également au sous-groupe imbriqué Conception UX en tant que Développeur.

> [!note]
> Soyez attentif aux autorisations héritées pour les groupes et les sous-groupes. Ajoutez les utilisateurs à un nombre minimal de groupes et de sous-groupes. Cette approche minimise le risque d'ajouter par inadvertance un utilisateur à un groupe dont il n'a pas besoin d'être membre.

1. Accédez à la page des membres du sous-groupe Expérience utilisateur.
1. Ajoutez Frankie Ali et Hunter Silva en tant que **Rapporteurs**. Attribuez à Hunter la même date d'expiration.
1. Accédez au sous-groupe imbriqué Rédaction technique.

Frankie Ali et Hunter Silva sont désormais membres du sous-groupe Rédaction technique en raison des autorisations héritées.

Vous avez correctement configuré votre organisation avec des groupes, des sous-groupes et des membres.

Ensuite, vous allez créer un projet dans l'un des groupes pour que les membres puissent y travailler.

## Créer un projet {#create-a-project}

Supposons maintenant que vous ayez un travail sur lequel certains membres de votre organisation doivent collaborer. Ce travail concerne l'ensemble de l'organisation. Pour organiser ce travail, vous allez créer un projet dans le groupe parent Développement et y ajouter différents utilisateurs.

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le groupe **Développement**.
1. Dans le coin supérieur droit, sélectionnez **Créer un nouveau** ({{< icon name="plus" >}}) et **Nouveau projet/dépôt**.
1. Sélectionnez **Créer un projet vide**.
1. Saisissez les détails du projet :
   - Dans le champ **Nom du projet**, saisissez `Release 2.0` comme nom de votre projet.
   - Laissez le champ **Identifiant « slug » du projet** tel quel, car il est basé sur le nom du projet.
   - Pour modifier les droits de consultation et d'accès au projet pour les utilisateurs, vous pouvez modifier le **Niveau de visibilité**. Étant donné que le groupe parent est privé, le projet ne peut être que **Privé** lui aussi.
   - Pour créer un fichier `README` afin que le dépôt Git soit initialisé, dispose d'une branche par défaut et puisse être cloné, cochez la case **Initialiser le dépôt avec un README**.
   - Pour analyser le code source du projet à la recherche de vulnérabilités de sécurité connues, cochez la case **Activer les tests statiques de sécurité des applications (SAST)**.
   - Pour analyser le code source à la recherche de secrets et d'identifiants afin de prévenir les accès non autorisés, cochez la case **Activer la détection de secret**.
1. Sélectionnez **Créer le projet**.

Vous avez maintenant créé un projet dans le groupe parent.

Dans ce projet, accédez à **Gérer** > **Membres**.

Les membres existants du groupe parent (vous et Alex) sont déjà membres de ce projet. Lorsque votre projet appartient à un groupe, les membres du projet héritent de leur rôle du groupe.

D'autres utilisateurs doivent faire partie de ce projet. Vous allez maintenant ajouter des utilisateurs directement au projet.

## Ajouter des utilisateurs au projet et au groupe parent {#add-users-to-the-project-and-parent-group}

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à** et trouvez le projet **Release 2.0**.
1. Dans la barre latérale gauche, sélectionnez **Gérer** > **Membres**.
1. Sélectionnez **Inviter des membres**. Invitez les utilisateurs suivants :

   | Utilisateur           | Rôle       | Date d'expiration de l'accès |
   |----------------|------------|------------------------|
   | Charlie Devi   | Chargé de maintenance | Laisser vide            |
   | Frankie Ali    | Chargé de maintenance | Laisser vide            |
   | Grayson Garcia | Chargé de maintenance | Laisser vide            |

1. Sélectionnez **Inviter**.
1. Comme vous avez ajouté ces utilisateurs directement au projet, vous pouvez modifier leurs rôles sur la page des membres du projet si nécessaire. Modifiez le rôle de Grayson Garcia en **Développeur** pour tester cette fonctionnalité.
1. Accédez à la page des membres du groupe parent Développement. Les utilisateurs que vous venez d'ajouter au projet n'y figurent pas, bien que le projet appartienne au groupe parent.
1. Ajoutez les mêmes utilisateurs directement au groupe parent avec les rôles **Invité**. Vous pouvez modifier leur rôle directement sur cette page. Modifiez le rôle de Frankie en **Rapporteur**.
1. Revenez à la page des membres du projet Release 2.0. Les rôles des membres dans le projet sont toujours 2 Chargés de maintenance et 1 Développeur.

Vous avez correctement ajouté trois utilisateurs, membres de sous-groupes, à un projet dans le groupe parent, et vous leur avez attribué des rôles spécifiques dans le projet et dans le groupe parent.
