---
stage: Data Access
group: Database Health
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Paramétrer l'autovacuum PostgreSQL"
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

Utilisez cette page pour paramétrer l'autovacuum PostgreSQL et résoudre les problèmes courants liés à l'autovacuum.

## Fonctionnement de l'autovacuum {#how-autovacuum-works}

PostgreSQL utilise le [contrôle de concurrence multiversion (MVCC)](https://www.postgresql.org/docs/current/mvcc-intro.html). Lorsque vous mettez à jour ou supprimez une ligne, PostgreSQL ne supprime pas immédiatement l'ancienne version de la ligne. PostgreSQL marque plutôt l'ancienne version comme morte et la conserve jusqu'à ce qu'aucune transaction en cours ne puisse encore la voir. L'autovacuum est le processus en arrière-plan qui supprime ces anciennes versions de lignes, également appelées tuples morts. Il récupère l'espace qu'ils occupent, met à jour les statistiques du planificateur et maintient la carte de visibilité.

L'autovacuum est essentiel pour la santé de la base de données. Sans lui, les lignes mortes s'accumulent sous forme de gonflement de table et d'index. Le gonflement ralentit les requêtes, gaspille de l'espace disque et alourdit les sauvegardes et les opérations de maintenance. L'autovacuum prévient également le [retour à zéro des ID de transaction](https://www.postgresql.org/docs/current/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND), qui empêche la base de données d'accepter des écritures.

### Quand l'autovacuum s'exécute {#when-autovacuum-runs}

L'autovacuum vérifie périodiquement chaque table et exécute un vacuum lorsque le nombre de tuples morts dépasse ce seuil :

```plaintext
autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor × number_of_live_tuples
```

Par défaut, PostgreSQL définit `autovacuum_vacuum_scale_factor` à `0.2`. PostgreSQL effectue ensuite un vacuum sur une table uniquement après que 20 % de ses lignes sont mortes. Pour les grandes tables, 20 % représente un grand nombre de tuples morts. Une table se gonfle alors pendant longtemps avant que l'autovacuum n'intervienne. Pour réduire ce délai, les installations du package Linux GitLab abaissent `autovacuum_vacuum_scale_factor` à `0.02` (2 %) par défaut. Les tables les plus grandes ou les plus fréquemment mises à jour peuvent encore nécessiter une valeur par table inférieure. Voir [Paramétrer les grandes tables individuellement](#tune-large-tables-individually).

## Paramètres recommandés pour l'autovacuum {#recommended-autovacuum-settings}

Les installations du package Linux GitLab livrent des valeurs par défaut d'autovacuum adaptées à la plupart des charges de travail. Modifiez ces paramètres lorsque la [surveillance](#monitor-autovacuum) indique que l'autovacuum ne parvient pas à traiter les tuples morts. L'objectif est de permettre à l'autovacuum de récupérer les tuples morts aussi vite que votre charge de travail en crée, sans priver la base de données d'E/S.

Les modifications ayant le plus grand impact consistent généralement à augmenter `autovacuum_vacuum_cost_limit`, à augmenter `autovacuum_max_workers` et à abaisser le facteur d'échelle sur les tables les plus grandes. Traitez les valeurs de cette section comme des points de départ et validez-les par rapport à votre propre charge de travail.

### Paramètres à l'échelle du cluster {#cluster-wide-settings}

Pour les installations du package Linux GitLab, définissez les valeurs à l'échelle du cluster dans `/etc/gitlab/gitlab.rb`, puis exécutez `sudo gitlab-ctl reconfigure`.

```ruby
postgresql['autovacuum_max_workers'] = "<value>"
postgresql['autovacuum_vacuum_cost_limit'] = "<value>"
postgresql['autovacuum_vacuum_cost_delay'] = "<value>"
postgresql['maintenance_work_mem'] = "<value>"
```

Pour une [instance PostgreSQL externe](external.md), définissez les mêmes paramètres dans `postgresql.conf` à la place, puis rechargez PostgreSQL :

```ini
autovacuum_max_workers = <value>
autovacuum_vacuum_cost_limit = <value>
autovacuum_vacuum_cost_delay = <value>
maintenance_work_mem = <value>
autovacuum_work_mem = <value>
```

Rechargez PostgreSQL avec `SELECT pg_reload_conf();` ou en rechargeant le service. Pour les deux types d'installation, les paramètres tels que `autovacuum_max_workers` nécessitent un redémarrage complet de PostgreSQL. Un rechargement ou une reconfiguration ne suffit pas.

Les paramètres suivants ont le plus grand effet sur la capacité de l'autovacuum à suivre le rythme :

| Paramètre                          | Valeur recommandée           | Description                                                                                                                                                                                                                                                                                                                                                 |
|----------------------------------|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `autovacuum_max_workers`         | Environ 25 % du nombre de vCPU | Nombre maximal de processus d'autovacuum s'exécutant simultanément. La valeur par défaut est souvent trop faible pour les hôtes de base de données volumineux à plusieurs cœurs. Chaque worker ajoute une charge en mémoire et en E/S.                                                                                                                                                                                  |
| `autovacuum_vacuum_scale_factor` | `0.01` à `0.02`            | Fraction des lignes d'une table qui doivent être mortes avant que l'autovacuum ne s'exécute. GitLab abaisse la valeur par défaut de PostgreSQL à `0.02`. Abaissez-la davantage pour les tables volumineuses et fréquemment mises à jour. Voir [Paramétrer les grandes tables individuellement](#tune-large-tables-individually).                                                                                                          |
| `autovacuum_vacuum_cost_limit`   | 800 pour SSD                 | Coût d'E/S que l'autovacuum accumule avant de se mettre en pause. Lorsque la valeur est `-1`, il hérite de la valeur de `vacuum_cost_limit`. Cette valeur est bien en dessous du débit des stockages modernes sur SSD. Définissez-la explicitement. L'augmenter est souvent la modification ayant le plus grand impact.                                                                                                         |
| `autovacuum_vacuum_cost_delay`   | 2 ms                        | Durée pendant laquelle l'autovacuum se met en pause après avoir atteint la limite de coût. Abaissez-la pour rendre l'autovacuum plus agressif. Ne la définissez jamais à `0`. Voir [Paramètres à éviter](#settings-to-avoid).                                                                                                                                                                                      |
| `maintenance_work_mem`           | 1 Go à 2 Go                | Mémoire pour les opérations de maintenance telles que la création d'index. Chaque worker d'autovacuum utilise également cette quantité pour suivre les tuples morts lorsque `autovacuum_work_mem` est `-1`. Une valeur faible oblige un worker à parcourir les index à plusieurs reprises sur les grandes tables. Dimensionnez-la en fonction de la RAM disponible et du nombre de workers.                                                                   |
| `autovacuum_work_mem`            | 512 Mo                      | Mémoire utilisée par chaque worker d'autovacuum pour suivre les tuples morts. Lorsque la valeur est `-1`, les workers héritent de `maintenance_work_mem`. La mémoire totale de l'autovacuum évolue alors avec le nombre de workers. PostgreSQL 17 a supprimé la limite de 1 Go sur cette mémoire. Limitez-la explicitement lorsque vous augmentez le nombre de workers. Les installations du package Linux ne peuvent pas définir ce paramètre dans `gitlab.rb`. |
| `autovacuum_naptime`             | Quelques secondes (optionnel)    | Durée pendant laquelle l'autovacuum attend entre les vérifications d'une base de données. Abaissez-la pour les bases de données à rotation rapide afin que l'autovacuum réponde plus vite.                                                                                                                                                                                                                                  |

### Paramétrer les grandes tables individuellement {#tune-large-tables-individually}

Les tables les plus grandes peuvent se gonfler même avec un facteur d'échelle faible à l'échelle du cluster. Pour ces tables, définissez un facteur d'échelle ou un seuil par table plus faible directement dans PostgreSQL. Un facteur d'échelle autour de `0.01` (1 %) est courant pour les tables très volumineuses et fréquemment mises à jour :

```sql
ALTER TABLE <table_name> SET (autovacuum_vacuum_scale_factor = 0.01);
```

Les paramètres par table remplacent les valeurs à l'échelle du cluster uniquement pour cette table. Utilisez la [surveillance](#monitor-autovacuum) pour identifier les tables qui prennent du retard, et testez les modifications dans un environnement hors production d'abord.

### Paramètres à éviter {#settings-to-avoid}

> [!warning]
> Ne désactivez pas l'autovacuum (`autovacuum = off`). Sans autovacuum, les tuples morts s'accumulent. La base de données évolue alors vers un retour à zéro des ID de transaction. Le retour à zéro empêche la base de données d'accepter des écritures.

Évitez ces configurations :

- `autovacuum_vacuum_cost_delay = 0` supprime la limitation des E/S. L'autovacuum s'exécute alors sans pause et peut saturer les E/S disque. Les requêtes ralentissent.
- Le facteur d'échelle par défaut sur les tables les plus grandes. Ces tables sont alors soumises au vacuum trop rarement. Définissez plutôt une valeur par table plus faible.
- Se fier à l'héritage de `-1` pour `autovacuum_vacuum_cost_limit`. La valeur effective se trouve alors dans un autre paramètre, où vous pouvez la négliger. Définissez-la explicitement.

## Surveiller l'autovacuum {#monitor-autovacuum}

### Page de diagnostic de la base de données {#database-diagnostics-page}

{{< history >}}

- Activité de nettoyage de type VACUUM [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/239928) dans GitLab 19.2.
- Paramètres et résultats de l'autovacuum [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/242428) dans GitLab 19.4.
- Les remplacements par table et le risque lié au facteur d'échelle [introduits](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/245561) dans GitLab 19.5.

{{< /history >}}

La page de diagnostic de la base de données affiche l'activité de nettoyage de type VACUUM et les paramètres d'autovacuum pour chaque base de données.

Prérequis :

- Vous devez disposer d'un accès administrateur.

Pour afficher la page :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Surveillance** > **Diagnostic de la base de données**.

Deux sections de la page concernent l'autovacuum. Chaque section comporte une carte pour chaque base de données dans l'installation.

La section **Informations relatives à l'opération de nettoyage de type VACUUM** contient le panneau **Activité de nettoyage de type VACUUM**. Ce panneau comporte une ligne pour chaque vacuum en cours d'exécution. Les colonnes sont : Table, Type, En cours d'exécution depuis, Phase, Heap analysé, Index traités, Tuples morts, Passes d'index et Durée de délai. Une ligne peut porter ces badges :

- **Anti-retour à zéro des ID de transaction** : le vacuum empêche le retour à zéro des ID de transaction. Ce vacuum ne s'annule pas automatiquement. Ne le terminez pas. Si vous le faites, la base de données peut s'arrêter pour protéger les données.
- **Longue durée** : le vacuum s'exécute depuis plus de 6 heures. Les grandes tables peuvent prendre aussi longtemps, mais un vacuum qui ne se termine jamais peut être bloqué ou privé de ressources.
- **Pression mémoire** : le vacuum a nécessité plus d'une passe d'index. Le stockage de tuples morts s'est rempli avant la fin de l'analyse du heap. Augmentez `maintenance_work_mem` ou `autovacuum_work_mem`.

La section **Configuration de l'autovacuum** contient ces panneaux :

- **Paramètres effectifs** : les paramètres d'autovacuum que la base de données utilise réellement, lus depuis `pg_settings`. Une colonne **Statut** signale chaque mauvaise configuration détectée par les vérifications. Lorsque `autovacuum_vacuum_cost_limit` est `-1`, le panneau affiche également la limite effective héritée de `vacuum_cost_limit`.
- **Remplacements par table** : tables qui définissent un paramètre d'autovacuum dans leurs paramètres de stockage. Le panneau affiche la taille, le nombre de lignes estimé et les remplacements de chaque table. Une table qui désactive l'autovacuum porte un badge **Autovacuum désactivé**. Le panneau liste jusqu'à 50 tables, avec en premier les tables qui désactivent l'autovacuum. Le panneau est masqué lorsqu'aucune table n'a de remplacements.
- **Risque lié au facteur d'échelle** : grandes tables dont le facteur d'échelle en vigueur est encore élevé. Le panneau est masqué lorsque la vérification ne trouve aucune table de ce type.

Certains résultats concernent une table, et non un paramètre unique. Ces résultats apparaissent sous forme d'alertes au-dessus des panneaux. Pour les conditions derrière chaque résultat, voir [Résultats de l'autovacuum](#autovacuum-findings).

> [!note]
> Le panneau **Activité de nettoyage de type VACUUM** nécessite PostgreSQL 17 ou une version ultérieure. Sur les versions antérieures, le panneau est vide. La colonne Durée de délai nécessite PostgreSQL 18 ou une version ultérieure. Les colonnes Type et En cours d'exécution depuis, ainsi que le badge **Anti-retour à zéro des ID de transaction**, nécessitent un rôle de base de données capable de lire l'activité des autres backends. Accordez au rôle l'appartenance à `pg_monitor`. Sans cette appartenance, les colonnes de progression fonctionnent toujours, mais les champs Type, En cours d'exécution depuis et Anti-retour à zéro des ID de transaction affichent `Not available`.

Les deux sections lisent depuis la base de données primaire, car l'autovacuum ne s'y exécute que là.

### Générer des diagnostics sur la console {#report-diagnostics-on-the-console}

{{< history >}}

- [Introduction](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/251254) dans GitLab 19.4.
- Tâches pour une vérification unique [introduites](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/251735) dans GitLab 19.4.
- Menu supprimé pour une vérification unique [modifié](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/257133) dans GitLab 19.5.
- Vérification des statistiques du planificateur [introduite](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/265314) dans GitLab 19.6.

{{< /history >}}

Utilisez la tâche Rake lorsque vous n'avez pas accès à l'interface utilisateur, ou lorsque vous souhaitez obtenir le rapport depuis un script.

Pour les installations de paquets Linux :

```shell
sudo gitlab-rake gitlab:db:diagnostics
```

Par défaut, la tâche génère un rapport sur chaque base de données. Pour sélectionner des bases de données, passez leurs noms :

```shell
sudo gitlab-rake "gitlab:db:diagnostics[main,ci]"
```

Pour exécuter une seule vérification, utilisez sa propre tâche. Les tâches acceptent les mêmes noms de base de données :

```shell
sudo gitlab-rake "gitlab:db:diagnostics:autovacuum_settings[main,ci]"
sudo gitlab-rake "gitlab:db:diagnostics:planner_statistics[main,ci]"
```

Le rapport imprime d'abord un résumé, puis une section pour chaque vérification. La section **Paramètres d'autovacuum** liste les résultats, les paramètres effectifs, les remplacements par table et les risques liés au facteur d'échelle pour chaque base de données.

La section **Statistiques du planificateur** liste les tables de 10 Mio ou plus que PostgreSQL n'a jamais analysées ou soumises au vacuum, ainsi que les tables partitionnées dont les statistiques sont plus anciennes que deux fois leur intervalle attendu. Les statistiques sont manquantes après une mise à niveau majeure de PostgreSQL avant PostgreSQL 18, et l'autovacuum n'analyse jamais une table partitionnée. Après une restauration, la section ne signale que les tables partitionnées : la construction des index enregistre un nombre de lignes pour les autres tables restaurées, bien qu'elles n'aient pas non plus de statistiques de colonnes. Voir [Résultats des statistiques du planificateur](#planner-statistics-findings).

La tâche se termine avec le statut `1` lorsqu'elle trouve une erreur, de sorte qu'un job de surveillance peut utiliser le code de sortie.

Dans un terminal, la tâche affiche un menu pour ouvrir chaque section lorsqu'elle exécute plus d'une vérification. Lorsqu'elle exécute une seule vérification, ou lorsque vous redirigez ou canalisez la sortie, la tâche imprime le rapport complet.

> [!note]
> La tâche Rake n'affiche pas l'activité de nettoyage de type VACUUM. L'activité de nettoyage de type VACUUM est disponible uniquement sur la [page de diagnostic de la base de données](#database-diagnostics-page).

### Résultats de l'autovacuum {#autovacuum-findings}

La page de diagnostic de la base de données et la tâche Rake utilisent les mêmes vérifications. Toutes deux signalent les mêmes résultats. Les cinq premiers résultats concernent chacun un paramètre et apparaissent dans la colonne **Statut** du panneau **Paramètres effectifs**. Les deux derniers concernent des tables et apparaissent sous forme d'alertes.

| Résultat             | Paramètre                          | Gravité | Signalé lorsque                                                                                                                                                                                                                                                                                                                                             | Action                                                                                                                                                                                                                  |
|---------------------|----------------------------------|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Désactivé            | `autovacuum`                     | Erreur    | `autovacuum` est `off`. Les tuples morts ne sont jamais récupérés automatiquement. Cela présente un risque de gonflement et éventuellement de retour à zéro des ID de transaction.                                                                                                                                                                                                                          | Activez l'autovacuum. Voir [Paramètres à éviter](#settings-to-avoid).                                                                                                                                                        |
| Limitation désactivée | `autovacuum_vacuum_cost_delay`   | Erreur    | Le délai de coût est `0`. L'autovacuum s'exécute alors à pleine vitesse. Cela peut provoquer des rafales d'écriture et un décalage de réplication.                                                                                                                                                                                                                                               | Définissez un délai non nul. Voir [Paramètres à éviter](#settings-to-avoid).                                                                                                                                                      |
| Faible                 | `autovacuum_max_workers`         | Avertissement  | Moins de trois workers sont configurés. Cela peut être insuffisant pour une base de données volumineuse ou décomposée.                                                                                                                                                                                                                                                          | Augmentez le nombre de workers. Voir [Paramètres à l'échelle du cluster](#cluster-wide-settings).                                                                                                                                            |
| Faible                 | `autovacuum_vacuum_cost_limit`   | Avertissement  | La limite effective est `200` ou moins. Cette limite est probablement trop faible pour le stockage moderne. La vérification utilise la valeur héritée de `vacuum_cost_limit` lorsque le paramètre est `-1`. Les installations du package Linux livrent `-1` par défaut. La valeur par défaut de PostgreSQL pour `vacuum_cost_limit` est `200`. Ce résultat apparaît donc sur une installation par défaut du package Linux. | Définissez la limite explicitement. Voir [Paramètres à l'échelle du cluster](#cluster-wide-settings).                                                                                                                                          |
| Hérité           | `autovacuum_work_mem`            | Avertissement  | Le paramètre est `-1`. Chaque worker hérite de `maintenance_work_mem`.                                                                                                                                                                                                                                                                                         | Définissez-le explicitement pour limiter la mémoire utilisée par chaque worker. Les installations du package Linux ne peuvent pas définir ce paramètre dans `gitlab.rb` ; réglez plutôt `maintenance_work_mem`. Voir [Paramètres à l'échelle du cluster](#cluster-wide-settings). |
| Tables désactivées     | `autovacuum_enabled` par table   | Erreur    | Une ou plusieurs tables définissent `autovacuum_enabled = false` dans leurs paramètres de stockage. Leurs tuples morts ne sont jamais récupérés automatiquement. Le panneau **Remplacements par table** signale chaque table concernée.                                                                                                                                                            | Réactivez l'autovacuum pour chaque table avec `ALTER TABLE <table_name> RESET (autovacuum_enabled);`.                                                                                                                     |
| Risque lié au facteur d'échelle   | `autovacuum_vacuum_scale_factor` | Avertissement  | Le facteur d'échelle à l'échelle du cluster est `0.1` ou plus, et l'une des 20 plus grandes tables fait 10 Gio ou plus avec un facteur d'échelle en vigueur de `0.1` ou plus. Les installations du package Linux livrent `0.02`. Ce résultat apparaît donc principalement sur les instances PostgreSQL externes qui conservent la valeur par défaut de PostgreSQL de `0.2`.                                             | Abaissez le facteur d'échelle à l'échelle du cluster, ou définissez une valeur par table sur les tables listées. Voir [Paramétrer les grandes tables individuellement](#tune-large-tables-individually).                                                              |

Le facteur d'échelle en vigueur est le remplacement par table lorsqu'il est défini, sinon la valeur à l'échelle du cluster. Un `autovacuum_vacuum_threshold` par table n'exempte pas une table. La vérification ignore les tables dont l'autovacuum est désactivé.

> [!note]
> Les vérifications ne signalent que les mauvaises configurations évidentes. Les vérifications utilisent également des seuils inférieurs aux valeurs figurant dans [Paramètres recommandés pour l'autovacuum](#recommended-autovacuum-settings). Un paramètre peut passer les vérifications et être encore trop faible pour votre charge de travail. Par exemple, trois workers d'autovacuum passent la vérification, mais c'est faible pour un hôte disposant de nombreux vCPU.

### Résultats des statistiques du planificateur {#planner-statistics-findings}

La tâche Rake signale deux résultats. Les deux concernent des tables de 10 Mio ou plus, mesurées par la taille du heap sans les index.

| Résultat            | Gravité | Signalé lorsque                                                                                                                                                                                                                                                                                                           | Action                                                                                                                                                                                                                                                                                             |
|--------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Statistiques manquantes | Erreur    | PostgreSQL n'a jamais analysé ni soumis au vacuum une table, ou n'a jamais analysé une table partitionnée, et ne dispose donc d'aucune statistique pour planifier les requêtes la concernant. C'est l'état après une mise à niveau majeure de PostgreSQL avant PostgreSQL 18. La vérification examine les 100 tables les plus grandes de ce type et en liste jusqu'à 50 ; lorsque les 100 font 10 Mio ou plus, le résultat indique « au moins 100 ». | Exécutez `ANALYZE` sur chaque table dans une session avec `statement_timeout` défini à `0`. `ANALYZE` sur une table partitionnée couvre également ses partitions. Lorsque le résultat indique « au moins 100 », exécutez `ANALYZE` sans nom de table pour couvrir l'ensemble de la base de données.                                                 |
| Statistiques obsolètes   | Avertissement  | Une table partitionnée a été analysée pour la dernière fois il y a plus de deux fois son intervalle attendu. La colonne **Intervalle** affiche cet intervalle : la planification selon laquelle GitLab analyse la table, ou une semaine pour une table partitionnée que GitLab n'analyse pas lui-même.                                                                           | Exécutez `ANALYZE` sur la table dans une session avec `statement_timeout` défini à `0`. Pour une table que GitLab analyse selon un planning, vérifiez également que le job cron `postgres_dynamic_partitions_manager` s'exécute.                                                                                                   |

### Vérifier les tuples morts et l'âge de gel {#check-dead-tuples-and-freeze-age}

Ni la page de diagnostic de la base de données ni la tâche Rake ne signalent les tuples morts par table ni l'âge de gel. Interrogez plutôt la base de données pour obtenir ces informations. Sur les installations du package Linux, connectez-vous avec :

```shell
sudo gitlab-psql
```

Pour trouver les tables ayant le plus de tuples morts, et quand l'autovacuum les a traitées pour la dernière fois :

```sql
SELECT schemaname, relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 20;
```

Un compteur `n_dead_tup` en hausse, avec `last_autovacuum` ancien ou vide, signifie que l'autovacuum ne parvient pas à suivre cette table. Voir [L'autovacuum ne parvient pas à suivre une table](#autovacuum-cannot-keep-up-with-a-table).

Pour trouver l'âge de gel de chaque table :

```sql
SELECT n.nspname AS schema_name, c.relname AS table_name, age(c.relfrozenxid) AS xid_age
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY xid_age DESC
LIMIT 20;
```

`xid_age` compte les transactions qui se sont exécutées après que PostgreSQL a gelé la table pour la dernière fois. Comparez-le à `autovacuum_freeze_max_age`. Le panneau **Paramètres effectifs** signale cette valeur. Lorsqu'une table dépasse cette valeur, PostgreSQL lance un autovacuum anti-retour à zéro sur celle-ci. Un âge de gel qui continue d'augmenter signifie que l'autovacuum ne parvient pas à geler les lignes assez vite. Voir [Le retour à zéro des ID de transaction est imminent](#transaction-id-wraparound-is-approaching).

## Résoudre les problèmes courants {#troubleshoot-common-issues}

### L'autovacuum ne parvient pas à suivre une table {#autovacuum-cannot-keep-up-with-a-table}

Une table accumule des tuples morts plus vite que l'autovacuum ne les supprime. Le nombre de tuples morts continue d'augmenter, la table se gonfle et les requêtes la concernant ralentissent. Ce problème a deux causes courantes :

- Un taux de modifications élevé. Une migration de base de données, ou un point de terminaison qui met souvent à jour des lignes, crée des tuples morts plus vite que l'autovacuum ne les supprime.
- Une table occupée qui utilise les paramètres à l'échelle du cluster. Les tables volumineuses et fréquemment mises à jour ont souvent besoin de leurs propres paramètres d'autovacuum.

Pour identifier les tables qui prennent du retard, vérifiez le nombre de tuples morts et le moment où l'autovacuum s'est exécuté pour la dernière fois pour chaque table. Voir [Surveiller l'autovacuum](#monitor-autovacuum). Pour résoudre le problème :

- Définissez un facteur d'échelle ou un seuil par table plus faible. Pour plus d'informations, voir [Paramétrer les grandes tables individuellement](#tune-large-tables-individually).
- Augmentez `autovacuum_vacuum_cost_limit` et `autovacuum_max_workers`. Pour plus d'informations, voir [Paramètres recommandés pour l'autovacuum](#recommended-autovacuum-settings).
- Si une migration ou un changement d'application est la source de la rotation, mettez-la en pause ou revenez en arrière.

### Le retour à zéro des ID de transaction est imminent {#transaction-id-wraparound-is-approaching}

PostgreSQL attribue un ID (XID) à chaque transaction. À mesure que le XID non gelé le plus ancien vieillit, PostgreSQL exécute des autovacuums anti-retour à zéro pour geler les anciennes lignes. Si ces vacuums ne peuvent pas se terminer, la base de données finit par cesser d'accepter des écritures pour protéger vos données.

Pour surveiller ce risque, contrôlez l'âge de gel de chaque base de données et table. Voir [Surveiller l'autovacuum](#monitor-autovacuum). Un âge de gel en hausse signifie que l'autovacuum ne gèle pas les lignes assez vite.

Pour y remédier, assurez-vous que l'autovacuum s'exécute et n'est pas bloqué. Voir [L'autovacuum ne parvient pas à suivre une table](#autovacuum-cannot-keep-up-with-a-table). Si la base de données a déjà cessé d'accepter des écritures, suivez les étapes de récupération dans [La base de données n'accepte pas les commandes pour éviter la perte de données due au retour à zéro](../troubleshooting/postgresql.md#database-is-not-accepting-commands-to-avoid-wraparound-data-loss).

### L'autovacuum utilise trop de ressources {#autovacuum-uses-too-many-resources}

L'autovacuum génère un trafic d'E/S qui peut ralentir d'autres requêtes. PostgreSQL régule ce trafic avec un délai basé sur le coût. Le délai est réparti entre tous les workers d'autovacuum en cours d'exécution. L'impact total sur les E/S reste alors à peu près le même quel que soit le nombre de workers en cours d'exécution.

Pour réduire l'effet sur les autres requêtes, augmentez `autovacuum_vacuum_cost_delay` afin que les workers se mettent en pause plus souvent. Un délai plus élevé ralentit le vacuum. Équilibrez-le par rapport au besoin de suivre le rythme des tuples morts. Ne définissez jamais le délai à `0`. Cela supprime entièrement la limitation. Pour plus d'informations, voir [Paramètres à éviter](#settings-to-avoid).
