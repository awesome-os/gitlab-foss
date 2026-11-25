---
stage: Package
group: Container Registry
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Réduire le stockage du registre de conteneurs
description: "Conseils pour surveiller et réduire l'utilisation du stockage pour les registres de conteneurs GitLab."
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

Les registres de conteneurs peuvent croître en taille au fil du temps si vous ne gérez pas votre utilisation du registre. Par exemple, si vous ajoutez un grand nombre d'images ou de tags :

- La récupération de la liste des tags ou images disponibles devient plus lente.
- Ils occupent une grande quantité d'espace de stockage sur le serveur.

Vous devez supprimer les images et les tags inutiles et configurer une [stratégie de nettoyage du registre de conteneurs](#cleanup-policy) pour gérer automatiquement l'utilisation de votre registre de conteneurs.

## Afficher l'utilisation du registre de conteneurs {#view-container-registry-usage}

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate

{{< /details >}}

Affichez les données d'utilisation du stockage pour vos dépôts de registre de conteneurs.

### Pour un projet {#for-a-project}

Prérequis :

- Pour les instances GitLab Self-Managed, un administrateur doit [activer la base de données de métadonnées du registre de conteneurs](../../../administration/packages/container_registry_metadata_database.md).
- Vous devez disposer du rôle Chargé de maintenance ou Propriétaire pour le projet, ou du rôle Propriétaire pour l'espace de nommage.

Pour afficher l'utilisation du stockage pour un projet :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Effectuez l'une des opérations suivantes :
   - Pour afficher l'utilisation totale du stockage, sélectionnez **Paramètres** > **Quotas d'utilisation**. Sous **Entités de l'espace de nommage**, sélectionnez **Registre de conteneurs** pour afficher les dépôts individuels.
   - Pour afficher l'utilisation du stockage par dépôt directement, sélectionnez **Déployer** > **Registre de conteneurs**.

Vous pouvez également utiliser :

- Utilisez l'API Projects pour obtenir le stockage total du registre de conteneurs pour un projet. Pour plus d'informations, consultez [Obtenir un seul projet](../../../api/projects.md#retrieve-a-project).
- Utilisez l'API du registre de conteneurs pour obtenir des données de taille pour un dépôt spécifique. Pour plus d'informations, consultez [Récupérer les détails d'un seul dépôt](../../../api/container_registry.md#retrieve-details-of-a-single-repository).

### Pour un groupe {#for-a-group}

Prérequis :

- Pour les instances GitLab Self-Managed, un administrateur doit [activer la base de données de métadonnées du registre de conteneurs](../../../administration/packages/container_registry_metadata_database.md).
- Vous devez avoir le rôle Propriétaire pour le groupe.

Pour afficher l'utilisation du stockage pour un groupe :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Quotas d'utilisation**.
1. Sélectionnez l'onglet **Stockage**.

Vous pouvez également utiliser l'[API Groups](../../../api/groups.md#list-all-groups) pour obtenir le stockage total du registre de conteneurs pour tous les projets d'un groupe.

### Mises à jour des données de stockage {#storage-data-updates}

Une fois la base de données de métadonnées activée :

- Pour les nouvelles images de conteneurs, les données de taille sont disponibles immédiatement après le push.
- Pour les images de conteneurs existantes, les données de taille sont calculées en arrière-plan et peuvent prendre jusqu'à 24 heures.

Les mises à jour des données de stockage se produisent :

- Immédiatement lorsque vous effectuez un push ou supprimez des images de conteneurs.
- En temps réel lorsque vous :
  - Affichez les tags d'image du dépôt dans l'interface utilisateur.
  - Utilisez l'API du registre de conteneurs pour [récupérer les détails d'un seul dépôt](../../../api/container_registry.md#retrieve-details-of-a-single-repository).
- Lorsque vous effectuez un push ou supprimez des tags dans le dépôt de conteneurs d'un projet.
- Toutes les 5 minutes pour les groupes.

> [!note]
> Pour les instances GitLab Self-Managed, les données de stockage deviennent disponibles après qu'un administrateur active la base de données de métadonnées. Sur GitLab.com, la base de données de métadonnées est activée par défaut.

## Calcul de l'utilisation du registre de conteneurs {#how-container-registry-usage-is-calculated}

Les couches d'images stockées dans le registre de conteneurs sont dédupliquées au niveau de l'espace de nommage racine.

Une image n'est comptée qu'une seule fois si :

- Vous taguez la même image plusieurs fois dans le même dépôt.
- Vous taguez la même image dans des dépôts distincts sous le même espace de nommage racine.

Une couche d'image n'est comptée qu'une seule fois si :

- Vous partagez la couche d'image entre plusieurs images dans le même dépôt de conteneurs, projet ou groupe.
- Vous partagez la couche d'image entre différents dépôts.

Seules les couches référencées par des images taguées sont prises en compte. Les images sans tag et les couches référencées exclusivement par elles sont soumises à la [collecte des déchets en ligne](delete_container_registry_images.md#garbage-collection). Les couches d'images sans tag sont automatiquement supprimées après 24 heures si elles restent non référencées pendant cette période.

Les couches d'images sont stockées sur le backend de stockage dans le format original (généralement compressé). Cela signifie que la taille mesurée pour une couche d'image donnée doit correspondre à la taille affichée dans le [manifeste d'image](https://github.com/opencontainers/image-spec/blob/main/manifest.md#example-image-manifest) correspondant.

L'utilisation de l'espace de nommage est actualisée quelques minutes après qu'un tag est poussé ou supprimé depuis n'importe quel dépôt de conteneurs sous l'espace de nommage.

### Actualisation différée {#delayed-refresh}

Il n'est pas possible de calculer l'utilisation du registre de conteneurs avec une précision maximale en temps réel pour les espaces de nommage extrêmement grands (environ 1 % des espaces de nommage). Pour permettre aux mainteneurs de ces espaces de nommage de voir leur utilisation, il existe un mécanisme de repli différé. Consultez l'[epic 9413](https://gitlab.com/groups/gitlab-org/-/epics/9413) pour plus de détails.

Si l'utilisation d'un espace de nommage ne peut pas être calculée avec précision, GitLab recourt à la méthode différée. Dans la méthode différée, la taille d'utilisation affichée est la somme de toutes les couches d'images uniques dans l'espace de nommage. Les couches d'images sans tag ne sont pas ignorées. Par conséquent, la taille d'utilisation affichée peut ne pas changer de manière significative après la suppression de tags. Au lieu de cela, la valeur de taille ne change que lorsque :

- Un [processus de collecte des déchets](delete_container_registry_images.md#garbage-collection) automatisé s'exécute et supprime les couches d'images sans tag. Après qu'un utilisateur supprime un tag, une exécution de collecte des déchets est planifiée pour démarrer 24 heures plus tard. Au cours de cette exécution, les images précédemment taguées sont analysées et leurs couches supprimées si elles ne sont pas référencées par d'autres images taguées. Si des couches sont supprimées, l'utilisation de l'espace de nommage est mise à jour.
- L'utilisation du registre de l'espace de nommage diminue suffisamment pour que GitLab puisse la mesurer avec une précision maximale. À mesure que l'utilisation des espaces de nommage diminue, la mesure passe automatiquement du mode différé au mode de mesure précise. Il n'existe aucun endroit dans l'interface utilisateur pour déterminer quelle méthode de mesure est utilisée, mais l'[issue 386468](https://gitlab.com/gitlab-org/gitlab/-/issues/386468) propose d'améliorer cela.

## Stratégie de nettoyage {#cleanup-policy}

La stratégie de nettoyage est un job planifié que vous pouvez utiliser pour supprimer des tags du registre de conteneurs. Pour le projet dans lequel elle est définie, les tags correspondant au modèle regex sont supprimés. Les couches et images sous-jacentes sont conservées.

Pour supprimer les couches et images sous-jacentes qui ne sont associées à aucun tag, les administrateurs peuvent utiliser la [collecte des déchets](../../../administration/packages/container_registry.md#removing-untagged-manifests-and-unreferenced-layers) avec le commutateur `-m`.

### Activer la stratégie de nettoyage {#enable-the-cleanup-policy}

> [!warning]
> Pour des raisons de performance, les stratégies de nettoyage activées sont automatiquement désactivées pour les projets qui ne possèdent pas d'image de conteneur.

### Fonctionnement de la stratégie de nettoyage {#how-the-cleanup-policy-works}

La stratégie de nettoyage collecte tous les tags dans le registre de conteneurs et exclut des tags jusqu'à ce qu'il ne reste que les tags que vous souhaitez supprimer.

La stratégie de nettoyage recherche des images en fonction du nom du tag. La prise en charge de la correspondance de chemin complet est suivie dans l'issue [281071](https://gitlab.com/gitlab-org/gitlab/-/issues/281071).

La stratégie de nettoyage :

1. Collecte tous les tags d'un dépôt donné dans une liste.
1. Exclut le tag nommé `latest`.
1. Évalue le `name_regex` (tags à expirer), en excluant les noms ne correspondant pas.
1. Exclut tous les tags correspondant à la valeur `name_regex_keep` (tags à conserver).
1. Exclut tous les tags qui n'ont pas de manifeste (ne faisant pas partie des options dans l'interface utilisateur).
1. Trie les tags restants par `created_date`.
1. Exclut les N tags basés sur la valeur `keep_n` (nombre de tags à conserver).
1. Exclut les tags plus récents que la valeur `older_than` (intervalle d'expiration).
1. Exclut les [tags protégés](protected_container_tags.md).
1. Exclut les [tags immuables](immutable_container_tags.md).
1. Supprime les tags restants dans la liste du registre de conteneurs.

> [!warning]
> Sur GitLab.com, le temps d'exécution de la stratégie de nettoyage est limité. Certains tags peuvent rester dans le registre de conteneurs après l'exécution de la stratégie. Lors de la prochaine exécution de la stratégie, les tags restants sont inclus. Plusieurs exécutions peuvent être nécessaires pour supprimer tous les tags.
>
> Les instances GitLab Self-Managed prennent en charge les registres de conteneurs tiers conformes à la spécification [Docker Registry HTTP API V2](https://distribution.github.io/distribution/spec/api/). Cependant, cette spécification n'inclut pas d'opération de suppression de tag. Par conséquent, GitLab utilise une solution de contournement pour supprimer des tags lors des interactions avec des registres de conteneurs tiers. Reportez-vous à l'issue [15737](https://gitlab.com/gitlab-org/gitlab/-/issues/15737) pour plus d'informations. En raison de possibles variations d'implémentation, cette solution de contournement n'est pas garantie de fonctionner de manière prévisible avec tous les registres tiers. Si vous utilisez le registre de conteneurs GitLab, cette solution de contournement n'est pas nécessaire car GitLab a implémenté une opération spéciale de suppression de tag. Dans ce cas, vous pouvez vous attendre à ce que les stratégies de nettoyage soient cohérentes et prévisibles.

#### Exemple de workflow de stratégie de nettoyage {#example-cleanup-policy-workflow}

L'interaction entre les règles de conservation et de suppression pour la stratégie de nettoyage peut être complexe. Par exemple, avec un projet ayant cette configuration de stratégie de nettoyage :

- **Conserver les plus récents** : 1 tag par nom d'image.
- **Conserver les tags correspondant à** : `production-.*`
- **Supprimer les tags antérieurs à** : 7 jours.
- **Supprimer les tags correspondant à** : `.*`.

Et un dépôt de conteneurs avec ces tags :

- `latest`, publié il y a 2 heures.
- `production-v44`, publié il y a 3 jours.
- `production-v43`, publié il y a 6 jours.
- `production-v42`, publié il y a 11 jours.
- `dev-v44`, publié il y a 2 jours.
- `dev-v43`, publié il y a 5 jours.
- `dev-v42`, publié il y a 10 jours.
- `v44`, publié hier.
- `v43`, publié il y a 12 jours.
- `v42`, publié il y a 20 jours.

Dans cet exemple, les tags qui seraient supprimés lors de la prochaine exécution de nettoyage sont `dev-v42`, `v43` et `v42`. Vous pouvez interpréter les règles comme s'appliquant avec cette priorité :

1. Les règles de conservation ont la priorité la plus élevée. Les tags doivent être conservés lorsqu'ils correspondent à une règle.
   - Le tag `latest` doit être conservé, car les tags `latest` sont toujours conservés.
   - Les tags `production-v44`, `production-v43` et `production-v42` doivent être conservés, car ils correspondent à la règle **Conserver les tags correspondant à**.
   - Le tag `v44` doit être conservé car il est le plus récent, correspondant à la règle **Conserver les plus récents**.
1. Les règles de suppression ont une priorité inférieure, et les tags ne sont supprimés que si toutes les règles correspondent. Pour les tags ne correspondant à aucune règle de conservation (`dev-v44`, `dev-v43`, `dev-v42`, `v43` et `v42`) :
   - `dev-v44` et `dev-v43` ne correspondent pas à la règle **Supprimer les tags antérieurs à**, et sont conservés.
   - `dev-v42`, `v43` et `v42` correspondent à la fois aux règles **Supprimer les tags antérieurs à** et **Supprimer les tags correspondant à**, donc ces trois tags peuvent être supprimés.

### Créer une stratégie de nettoyage {#create-a-cleanup-policy}

Vous pouvez créer une stratégie de nettoyage dans [l'API](#use-the-cleanup-policy-api) ou dans l'interface utilisateur.

Pour créer une stratégie de nettoyage dans l'interface utilisateur :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Paquets et registres**.
1. Développez **Registre de conteneurs**.
1. Sous **Stratégies de nettoyage du registre de conteneurs**, sélectionnez **Configurer les règles de nettoyage**.
1. Remplissez les champs :

   | Champ                      | Description |
   |----------------------------|-------------|
   | **Activer/désactiver**                 | Activer ou désactiver la stratégie. |
   | **Lancer le nettoyage**            | La fréquence d'exécution de la stratégie. |
   | **Conserver les plus récents**   | Le nombre de tags à toujours conserver pour chaque image. |
   | **Conserver les tags correspondant à**     | Un modèle regex qui détermine les tags à conserver. Le tag `latest` est toujours conservé. Pour tous les tags, utilisez `.*`. Consultez d'autres [exemples de modèles regex](#regex-pattern-examples). |
   | **Supprimer les tags antérieurs à** | Supprime uniquement les tags antérieurs à X jours. Vous devriez commencer avec un nombre élevé afin que seules les images les plus anciennes soient supprimées lors des premiers nettoyages. Après avoir surveillé les ressources utilisées par les workers de nettoyage en arrière-plan, le nombre de jours peut être réduit progressivement. |
   | **Supprimer les tags correspondant à**   | Un modèle regex qui détermine les tags à supprimer. Cette valeur ne peut pas être vide. Vous devriez commencer avec un regex relativement spécifique afin que seules quelques images soient supprimées lors des premiers nettoyages. Après avoir surveillé les ressources utilisées par les workers de nettoyage en arrière-plan, ajustez le regex pour qu'il soit plus générique, jusqu'à `.*` pour correspondre à tous les tags. Pour plus d'informations, consultez les [exemples de modèles regex](#regex-pattern-examples). |

   > [!note]
   > Les modèles regex de conservation et de suppression sont automatiquement entourés des ancres `\A` et `\Z`, vous n'avez donc pas besoin de les inclure. Cependant, assurez-vous d'en tenir compte lors du choix et du test de vos modèles regex.

1. Sélectionnez **Enregistrer**.

La stratégie s'exécute selon l'intervalle planifié que vous avez sélectionné.

> [!note]
> Si vous modifiez la stratégie et sélectionnez **Enregistrer** à nouveau, l'intervalle est réinitialisé.

### Exemples de modèles regex {#regex-pattern-examples}

Les stratégies de nettoyage utilisent des modèles regex pour déterminer quels tags doivent être conservés ou supprimés, à la fois dans l'interface utilisateur et dans l'API.

GitLab utilise la [syntaxe RE2](https://github.com/google/re2/wiki/Syntax) pour les expressions régulières dans la stratégie de nettoyage.

Voici quelques exemples de modèles regex que vous pouvez utiliser :

- Correspond à tous les tags :

  ```plaintext
  .*
  ```

  Ce modèle est la valeur par défaut pour le regex d'expiration.

- Correspond aux tags qui commencent par `v` :

  ```plaintext
  v.+
  ```

- Correspond uniquement au tag nommé `main` :

  ```plaintext
  main
  ```

- Correspond aux tags nommés ou commençant par `release` :

  ```plaintext
  release.*
  ```

- Correspond aux tags qui commencent par `v`, sont nommés `main`, ou commencent par `release` :

  ```plaintext
  (?:v.+|main|release.*)
  ```

### Définir des limites de nettoyage pour préserver les ressources {#set-cleanup-limits-to-conserve-resources}

{{< details >}}

- Offre : GitLab Self-Managed

{{< /details >}}

Les stratégies de nettoyage sont exécutées en tant que processus d'arrière-plan. Selon le nombre de tags à supprimer, le processus peut prendre un certain temps.

Vous pouvez utiliser les paramètres d'application suivants pour éviter l'épuisement des ressources du serveur :

| Paramètre d'application | Type | Description |
|---------|------|-------------|
| `container_registry_expiration_policies_worker_capacity` | Entier | Le nombre maximum de workers de nettoyage s'exécutant simultanément. Par défaut à `4`. Définissez cette valeur à `0` pour supprimer tous les workers et arrêter l'exécution des stratégies de nettoyage. Commencez avec un nombre faible et augmentez-le après avoir surveillé les ressources utilisées par les workers d'arrière-plan. |
| `container_registry_delete_tags_service_timeout` | Entier | Le temps maximum (en secondes) que le processus de nettoyage peut prendre pour supprimer un lot de tags. Par défaut à `250`. |
| `container_registry_cleanup_tags_service_max_list_size` | Entier | Le nombre maximum de tags pouvant être supprimés en une seule exécution. Par défaut à `200`. Les tags supplémentaires doivent être supprimés lors d'une autre exécution. Commencez avec un nombre faible et augmentez-le après avoir vérifié que les images de conteneurs sont correctement supprimées. |
| `container_registry_expiration_policies_caching` | Booléen | La mise en cache de l'horodatage de création des tags lors de l'exécution des stratégies. Par défaut à `true`. Les horodatages mis en cache sont stockés dans Redis. |

Prérequis :

- Disposer d'un accès administrateur.

Vous pouvez modifier ces paramètres dans la [console Rails](../../../administration/operations/rails_console.md#starting-a-rails-console-session). Par exemple :

```ruby
ApplicationSetting.last.update(container_registry_expiration_policies_worker_capacity: 3)
```

Pour modifier ces paramètres dans la zone **Admin** :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **CI/CD**.
1. Développez **Registre de conteneurs**.

### Utiliser l'API de stratégie de nettoyage {#use-the-cleanup-policy-api}

Vous pouvez définir, mettre à jour et désactiver les stratégies de nettoyage à l'aide de l'API GitLab.

Exemples :

- Sélectionner tous les tags, conserver au moins 1 tag par image, nettoyer tout tag de plus de 14 jours, exécuter une fois par mois, conserver toutes les images portant le nom `main`, et la stratégie est activée :

  ```shell
  curl --fail-with-body --request PUT --header 'Content-Type: application/json;charset=UTF-8'
       --header "PRIVATE-TOKEN: <your_access_token>" \
       --data-binary '{"container_expiration_policy_attributes":{"cadence":"1month","enabled":true,"keep_n":1,"older_than":"14d","name_regex":".*","name_regex_keep":".*-main"}}' \
       "https://gitlab.example.com/api/v4/projects/2"
  ```

Les valeurs valides pour `cadence` lors de l'utilisation de l'API sont :

- `1d` (tous les jours)
- `7d` (toutes les semaines)
- `14d` (toutes les deux semaines)
- `1month` (tous les mois)
- `3month` (tous les trimestres)

Les valeurs valides pour `keep_n` (nombre de tags conservés par nom d'image) lors de l'utilisation de l'API sont :

- `1`
- `5`
- `10`
- `25`
- `50`
- `100`

Les valeurs valides pour `older_than` (jours avant la suppression automatique des tags) lors de l'utilisation de l'API sont :

- `1d`
- `3d`
- `7d`
- `14d`
- `30d`
- `60d`
- `90d`
- `180d`
- `365d`
- `730d`
- `1095d`

Consultez la documentation de l'API pour plus de détails : [API d'édition de projet](../../../api/projects.md#update-a-project).

### Utilisation avec des registres de conteneurs externes {#use-with-external-container-registries}

Lors de l'utilisation d'un [registre de conteneurs externe](../../../administration/packages/container_registry.md#use-an-external-container-registry-with-gitlab-as-an-auth-endpoint), l'exécution d'une stratégie de nettoyage sur un projet peut présenter des risques de performance. Si un projet exécute une stratégie pour supprimer des milliers de tags, les jobs d'arrière-plan GitLab peuvent être saturés ou échouer complètement.

## Autres options de réduction du stockage du registre de conteneurs {#more-container-registry-storage-reduction-options}

Voici d'autres options que vous pouvez utiliser pour réduire le stockage du registre de conteneurs utilisé par votre projet :

- Utilisez l'[interface utilisateur GitLab](delete_container_registry_images.md#use-the-gitlab-ui) pour supprimer des tags d'images individuels ou l'intégralité du dépôt contenant tous les tags.
- Utilisez l'API pour [supprimer des tags d'images individuels](../../../api/container_registry.md#delete-a-registry-repository-tag).
- Utilisez l'API pour [supprimer l'intégralité du dépôt du registre de conteneurs contenant tous les tags](../../../api/container_registry.md#delete-registry-repository).
- Utilisez l'API pour [supprimer des tags de dépôt de registre en masse](../../../api/container_registry.md#delete-registry-repository-tags-in-bulk).

## Dépannage {#troubleshooting}

### La taille de stockage n'est pas disponible {#storage-size-is-not-available}

Si vous ne pouvez pas voir les informations sur la taille de stockage du registre de conteneurs :

1. Demandez à un administrateur de vérifier que [la base de données de métadonnées est correctement configurée](../../../administration/packages/container_registry_metadata_database.md).
1. Vérifiez que le backend de stockage du registre est correctement configuré et accessible.
1. Vérifiez les journaux du registre pour détecter les erreurs liées au stockage :

   ```shell
   sudo gitlab-ctl tail registry
   ```

### `Something went wrong while updating the cleanup policy.` {#something-went-wrong-while-updating-the-cleanup-policy}

Si vous voyez ce message d'erreur, vérifiez les modèles regex pour vous assurer qu'ils sont valides.

Vous pouvez les tester avec le [testeur regex regex101](https://regex101.com/) en utilisant la variante `Golang`. Consultez quelques [exemples de modèles regex](#regex-pattern-examples) courants.

### La stratégie de nettoyage ne supprime aucun tag {#the-cleanup-policy-doesnt-delete-any-tags}

Plusieurs raisons peuvent expliquer cela :

- Si vous utilisez GitLab Self-Managed et que vous avez plus de 1000 tags dans un dépôt de conteneurs, vous pourriez rencontrer un [problème d'expiration du jeton du registre de conteneurs](https://gitlab.com/gitlab-org/gitlab/-/issues/288814), avec `error authorizing context: invalid token` dans les journaux.

  Pour résoudre ce problème, deux solutions de contournement sont disponibles :

  - Vous pouvez [définir des limites pour la stratégie de nettoyage](#set-cleanup-limits-to-conserve-resources). Cela limite le temps d'exécution du nettoyage et évite l'erreur de jeton expiré.

  - [Prolongez le délai d'expiration](../../../administration/packages/container_registry.md#increase-token-duration) des jetons d'authentification du registre de conteneurs. La valeur par défaut est de 5 minutes.

Vous pouvez également générer une liste de tags à supprimer et utiliser cette liste pour supprimer les tags. Pour créer la liste et supprimer les tags :

1. Exécutez le script shell suivant. La commande juste avant la boucle `for` garantit que `list_o_tags.out` est toujours réinitialisé au démarrage de la boucle. Après l'exécution de cette commande, tous les noms de tags sont écrits dans le fichier `list_o_tags.out` :

   ```shell
   # Get a list of all tags in a certain container repository while considering [pagination](../../../api/rest/_index.md#pagination)
   echo -n "" > list_o_tags.out; for i in {1..N}; do curl --fail-with-body --header 'PRIVATE-TOKEN: <PAT>' "https://gitlab.example.com/api/v4/projects/<Project_id>/registry/repositories/<container_repo_id>/tags?per_page=100&page=${i}" | jq '.[].name' | sed 's:^.\(.*\).$:\1:' >> list_o_tags.out; done
   ```

   Si vous avez accès à la console Rails, vous pouvez saisir les commandes suivantes pour récupérer une liste de tags filtrée par date :

   ```shell
   output = File.open( "/tmp/list_o_tags.out","w" )
   Project.find(<Project_id>).container_repositories.find(<container_repo_id>).tags.each do |tag|
     output << tag.name + "\n" if tag.created_at < 1.month.ago
   end;nil
   output.close
   ```

   Cet ensemble de commandes crée un fichier `/tmp/list_o_tags.out` répertoriant tous les tags avec une date `created_at` antérieure à un mois.

1. Supprimez les tags que vous souhaitez conserver du fichier `list_o_tags.out`. Par exemple, vous pouvez utiliser `sed` pour analyser le fichier et supprimer les tags.

   {{< tabs >}}

   {{< tab title="Linux" >}}

   ```shell
   # Remove the `latest` tag from the file
   sed -i '/latest/d' list_o_tags.out

   # Remove the first N tags from the file
   sed -i '1,Nd' list_o_tags.out

   # Remove the tags starting with `Av` from the file
   sed -i '/^Av/d' list_o_tags.out

   # Remove the tags ending with `_v3` from the file
   sed -i '/_v3$/d' list_o_tags.out
   ```

   {{< /tab >}}

   {{< tab title="macOS" >}}

   ```shell
   # Remove the `latest` tag from the file
   sed -i .bak '/latest/d' list_o_tags.out

   # Remove the first N tags from the file
   sed -i .bak '1,Nd' list_o_tags.out

   # Remove the tags starting with `Av` from the file
   sed -i .bak '/^Av/d' list_o_tags.out

   # Remove the tags ending with `_v3` from the file
   sed -i .bak '/_v3$/d' list_o_tags.out
   ```

   {{< /tab >}}

   {{< /tabs >}}

1. Vérifiez le fichier `list_o_tags.out` pour vous assurer qu'il ne contient que les tags que vous souhaitez supprimer.

1. Exécutez ce script shell pour supprimer les tags dans le fichier `list_o_tags.out` :

   ```shell
   # loop over list_o_tags.out to delete a single tag at a time
   while read -r LINE || [[ -n $LINE ]]; do echo ${LINE}; curl --fail-with-body --request DELETE --header 'PRIVATE-TOKEN: <PAT>' "https://gitlab.example.com/api/v4/projects/<Project_id>/registry/repositories/<container_repo_id>/tags/${LINE}"; sleep 0.1; echo; done < list_o_tags.out > delete.logs
   ```
