---
stage: GitLab Delivery
group: Operate
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: Guide pour évaluer et planifier la taille de votre déploiement GitLab.
title: Évaluer et planifier la taille du déploiement
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

Évaluez la charge de travail de votre environnement GitLab et déterminez les exigences de déploiement appropriées avant l'installation, ou lors de l'évaluation d'un environnement existant pour vérifier s'il est correctement dimensionné.

## Caractérisation de la charge de travail {#workload-characterization}

Les environnements GitLab présentent des besoins en infrastructure très variés, même à des nombres d'utilisateurs ou des volumes de requêtes similaires. La combinaison des opérations Git, de l'activité CI/CD, de l'utilisation de l'API et de l'automatisation détermine quels composants sont mis sous pression et comment ils doivent évoluer.

Plutôt que de faire correspondre les environnements à un niveau de taille fixe, la caractérisation de la charge de travail décrit le profil d'un environnement. La caractérisation à laquelle vous aboutissez après avoir mesuré votre environnement guide les exigences au niveau des composants et les considérations de mise à l'échelle applicables.

| Caractérisation | Profil type |
|:-----------------|:----------------|
| Petite | Activité Git légère, automatisation minimale, faible concurrence CI/CD. |
| Moyen | Activité Git modérée, utilisation CI/CD standard, quelques automatisations. |
| Grande | CI/CD intensif, monodépôts actifs, automatisation API significative. |
| Très grande | Charges de travail intensives, intégrations étendues, concurrence élevée sur tous les composants. |

Ces caractérisations sont descriptives, non prescriptives. Ce sont des conclusions auxquelles vous aboutissez en mesurant votre environnement, non des catégories que vous sélectionnez à l'avance. De nombreux environnements ne correspondent pas clairement à une seule caractérisation. Un environnement avec une activité web et API légère mais des opérations Git intensives se distingue d'un environnement avec le profil inverse.

Pour les environnements petits et moyens, les conseils de cette page sont conçus pour être autonomes. Pour les environnements grands et très grands, la complexité opérationnelle justifie souvent de faire appel aux [Professional Services](https://about.gitlab.com/professional-services/), ou d'envisager [GitLab Dedicated](../subscriptions/gitlab_dedicated/_index.md) ou GitLab.com comme alternatives supprimant entièrement la charge opérationnelle.

## Considérations relatives à la charge de travail {#workload-considerations}

Certains schémas de charge de travail nécessitent plus que la méthodologie standard basée sur le RPS prise en compte par ce guide. Deux d'entre eux sont abordés plus loin, une fois que vous avez extrait vos métriques RPS : [les grands monodépôts et autres facteurs spécifiques à l'infrastructure](#assess-special-infrastructure-requirements), et [les schémas de charge de travail atypiques](#understanding-rps-composition-and-workload-patterns) tels que l'automatisation intensive, l'utilisation CI/CD ou l'analyse de sécurité.

GitLab Duo Agent Platform introduit ses propres considérations d'infrastructure au-delà du dimensionnement standard de la charge de travail. Consultez [la mise à l'échelle pour GitLab Duo Agent Platform](../administration/reference_architectures/_index.md#scaling-for-gitlab-duo-agent-platform) avant de dimensionner un environnement qui l'utilisera.

### Mise à l'échelle automatique {#autoscaling}

Rails (Puma) et Sidekiq sont sans état et prennent en charge les groupes de mise à l'échelle automatique. Dimensionnez ces composants pour la charge soutenue moyenne et laissez la mise à l'échelle automatique gérer les pics.

Gitaly est avec état et ne prend pas en charge la mise à l'échelle automatique. Dimensionnez les nœuds Gitaly pour la charge de pointe en utilisant les conseils ci-dessous.

Si la mise à l'échelle automatique est une exigence, un [déploiement cloud-native](../administration/reference_architectures/_index.md#cloud-native) est généralement préféré aux groupes de mise à l'échelle automatique basés sur des VM. Les composants qui doivent s'exécuter sur un seul nœud, comme les migrations de base de données et [Mailroom](../administration/incoming_email.md), sont gérés de manière plus fiable par Kubernetes que par des groupes de mise à l'échelle automatique basés sur des VM ; tenez compte de cette limitation avant de choisir la mise à l'échelle automatique basée sur des VM.

## Avant de commencer {#before-you-begin}

Ces instructions utilisent les métriques Prometheus pour évaluer votre environnement avec précision. Si votre environnement est simple, les [architectures de référence](../administration/reference_architectures/_index.md) peuvent fournir des conseils suffisants sans ce niveau d'analyse.

> [!note]
> Besoin de conseils d'experts ? Dimensionner correctement votre architecture est essentiel pour des performances optimales. Notre équipe des [Professional Services](https://about.gitlab.com/professional-services/) peut évaluer votre architecture spécifique et fournir des recommandations personnalisées pour l'optimisation des performances, de la stabilité et de la disponibilité.

Pour suivre cette documentation, vous devez avoir le monitoring Prometheus déployé avec l'instance GitLab. Prometheus fournit les métriques précises nécessaires à une évaluation correcte du dimensionnement.

Si vous n'avez pas encore configuré Prometheus :

1. Configurez le monitoring avec [Prometheus](../administration/monitoring/prometheus/_index.md). La documentation sur les architectures de référence fournit des informations détaillées sur la configuration de Prometheus pour chaque taille d'environnement. Pour GitLab cloud-native, vous pouvez utiliser le chart Helm [`kube-prometheus-stack`](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) pour configurer la collecte des métriques.
1. Collectez des données pendant 7 à 14 jours pour recueillir des schémas de données significatifs.
1. Lisez le reste de ces informations.

Si vous ne pouvez pas configurer le monitoring Prometheus :

- [Comparez les spécifications de l'environnement actuel](#analyze-current-environment-and-validate-recommendations) à l'architecture de référence la plus proche pour estimer le dimensionnement.
- Utilisez [GitLab RPS Analyzer](https://gitlab.com/gitlab-org/professional-services-automation/tools/utilities/gitlab-rps-analyzer#gitlab-rps-analyzer) pour évaluer la taille de l'architecture de référence à l'aide des journaux GitLabSOS ou KubeSOS. Notez cependant que cette méthode est moins fiable que les métriques.

En cas de migration depuis d'autres plateformes, les requêtes PromQL suivantes ne peuvent pas être appliquées sans métriques GitLab existantes. Cependant, la méthodologie d'évaluation générale reste valide :

1. Estimez l'architecture de référence la plus proche en fonction de la charge de travail attendue.
1. Identifiez les [charges de travail supplémentaires](../administration/reference_architectures/_index.md#additional-workloads) anticipées.
1. Évaluez le nombre de grands dépôts
1. Intégrez les projections de croissance.
1. Sélectionnez une architecture de référence avec une [marge appropriée](../administration/reference_architectures/_index.md#if-in-doubt-start-large-monitor-and-then-scale-down).

### Exécution de requêtes PromQL {#running-promql-queries}

L'exécution de requêtes PromQL dépend de la solution de monitoring que vous utilisez. Comme indiqué dans la [documentation sur le monitoring Prometheus](../administration/monitoring/prometheus/_index.md#how-prometheus-works), les données de monitoring sont accessibles soit en se connectant directement à Prometheus, soit en utilisant un outil de tableau de bord comme Grafana.

## Déterminer votre taille de référence {#determine-your-baseline-size}

Le nombre de requêtes par seconde (RPS) est la métrique principale pour dimensionner l'infrastructure GitLab. Les différents types de trafic (API, Web, opérations Git) sollicitent différents composants, c'est pourquoi chacun est analysé séparément pour trouver les véritables exigences de capacité.

### Extraire les métriques de trafic de pointe {#extract-peak-traffic-metrics}

Exécutez ces requêtes pour comprendre votre charge maximale. Ces requêtes vous montrent :

- Les pics absolus, qui correspondent au pic le plus élevé observé. Les pics absolus montrent les scénarios les plus défavorables.
- Les pics soutenus, qui correspondent au 95e percentile et sont considérés comme votre niveau « chargé » typique. Les pics soutenus révèlent les périodes de charge élevée typiques.

Si les pics absolus sont des anomalies rares, le dimensionnement pour la charge soutenue peut être approprié.

Ajustez les plages de temps dans les requêtes en fonction de la rétention (remplacez `[7d]` par `[30d]` si un historique plus long est disponible).

> [!note]
> Pour les environnements à forte activité, les requêtes `max_over_time` ou `quantile_over_time` peuvent expirer. Si cela se produit, supprimez la fonction d'agrégation externe et visualisez la requête interne avec un graphique. Par exemple, pour le pic de trafic API, utilisez :
>
> ```prometheus
> sum(rate(gitlab_transaction_duration_seconds_count{controller=~"Grape", action!~".*/internal/.*"}[1m]))
> ```
>
> Identifiez ensuite visuellement les valeurs de pointe à partir des résultats graphiques sur votre période de monitoring.

#### Interroger les pics absolus {#query-absolute-peaks}

Pour identifier le RPS maximum observé sur la période de temps spécifiée :

1. Exécutez ces requêtes :

   - Pic de trafic API, pour mesurer les requêtes API de pointe provenant de l'automatisation, des outils externes et des webhooks :

     ```prometheus
     max_over_time(
       sum(rate(gitlab_transaction_duration_seconds_count{controller=~"Grape", action!~".*/internal/.*", action!="POST /api/jobs/request"}[1m]))[7d:1m]
     )
     ```

   - Pic de trafic web, pour mesurer les interactions UI de pointe des utilisateurs dans les navigateurs :

     ```prometheus
     max_over_time(
       sum(rate(gitlab_transaction_duration_seconds_count{controller!~"Grape|HealthController|MetricsController|Repositories::GitHttpController|GraphqlController"}[1m]))[7d:1m]
     )
     ```

   - Pic de pull et de clone Git, pour mesurer les opérations de clone et de récupération de dépôt de pointe :

     ```prometheus
     max_over_time(
       (sum(rate(gitlab_transaction_duration_seconds_count{action="git_upload_pack"}[1m])) or vector(0) +
       sum(rate(gitaly_service_client_requests_total{grpc_method="SSHUploadPack"}[1m])) or vector(0))[7d:1m]
     )
     ```

   - Pic de push Git, pour mesurer les opérations de push de code de pointe :

     ```prometheus
     max_over_time(
       (sum(rate(gitlab_transaction_duration_seconds_count{action="git_receive_pack"}[1m])) or vector(0) +
       sum(rate(gitaly_service_client_requests_total{grpc_method="SSHReceivePack"}[1m])) or vector(0))[7d:1m]
     )
     ```

1. Enregistrez les résultats.

#### Interroger les pics soutenus {#query-sustained-peaks}

Pour identifier les niveaux de charge élevée typiques, en filtrant les pics rares :

1. Exécutez ces requêtes :

   - Pic soutenu API :

     ```prometheus
     quantile_over_time(0.95,
       sum(rate(gitlab_transaction_duration_seconds_count{controller=~"Grape", action!~".*/internal/.*", action!="POST /api/jobs/request"}[1m]))[7d:1m]
     )
     ```

   - Pic soutenu web :

     ```prometheus
     quantile_over_time(0.95,
       sum(rate(gitlab_transaction_duration_seconds_count{controller!~"Grape|HealthController|MetricsController|Repositories::GitHttpController|GraphqlController"}[1m]))[7d:1m]
     )
     ```

   - Pic soutenu de pull et de clone Git :

     ```prometheus
     quantile_over_time(0.95,
       (sum(rate(gitlab_transaction_duration_seconds_count{action="git_upload_pack"}[1m])) or vector(0) +
       sum(rate(gitaly_service_client_requests_total{grpc_method="SSHUploadPack"}[1m])) or vector(0))[7d:1m]
     )
     ```

   - Pic soutenu de push Git :

     ```prometheus
     quantile_over_time(0.95,
      (sum(rate(gitlab_transaction_duration_seconds_count{action="git_receive_pack"}[1m])) or vector(0) +
      sum(rate(gitaly_service_client_requests_total{grpc_method="SSHReceivePack"}[1m])) or vector(0))[7d:1m]
     )
     ```

1. Enregistrez les résultats.

### Mapper le trafic aux architectures de référence {#map-traffic-to-reference-architectures}

La façon dont vous mappez le trafic à une architecture de référence dépend de votre chemin de déploiement.

Package Linux (Omnibus) ou Cloud Native Hybrid :

1. Consultez les [architectures de référence disponibles](../administration/reference_architectures/_index.md#available-reference-architectures) pour voir quelle architecture de référence chaque type de trafic suggère.
1. Remplissez un tableau d'analyse. Utilisez le tableau suivant comme guide :

   | Type de trafic       | RPS de pointe | AR suggérée pour les pics     | RPS soutenu | AR suggérée pour le soutenu |
   |:-------------------|:---------|:----------------------|:--------------|:-----------------------|
   | API                | ________ | _____ (jusqu'à ___ RPS) | _____________ | _____ (jusqu'à ____ RPS) |
   | Web                | ________ | _____ (jusqu'à ___ RPS) | _____________ | _____ (jusqu'à ____ RPS) |
   | Pull et clone Git | ________ | _____ (jusqu'à ___ RPS) | _____________ | _____ (jusqu'à ____ RPS) |
   | Push Git           | ________ | _____ (jusqu'à ___ RPS) | _____________ | _____ (jusqu'à ____ RPS) |

1. Comparez toutes les architectures de référence dans la colonne **AR suggérée pour les pics** et sélectionnez la plus grande taille. Répétez l'opération pour la colonne **AR suggérée pour le soutenu**.
1. Documentez la référence :
   - AR de pic la plus grande suggérée.
   - AR soutenue la plus grande suggérée.

Cloud Native :

Les architectures Cloud Native sont dimensionnées par une seule plage RPS globale plutôt que par des cibles par type de trafic, car le trafic API représente généralement la grande majorité de la charge (voir [Répartition du RPS par type de requête](#rps-breakdown-by-request-type)).

1. Comparez votre RPS global de pointe et soutenu par rapport aux tailles disponibles :

   | Caractérisation | Taille Cloud Native                                  | RPS cible |
   |:------------------|:----------------------------------------------------|:-----------|
   | Petite             | [Petite (S)](../administration/reference_architectures/cloud_native.md#small-s)               | ≤ 100 RPS   |
   | Moyen            | [Moyenne (M)](../administration/reference_architectures/cloud_native.md#medium-m)             | ≤ 200 RPS   |
   | Grande             | [Grande (L)](../administration/reference_architectures/cloud_native.md#large-l)               | ≤ 500 RPS   |
   | Très grande       | [Très grande (XL)](../administration/reference_architectures/cloud_native.md#extra-large-xl) | ≤ 1 000 RPS  |

1. Documentez la référence :
   - Taille suggérée pour les pics.
   - Taille suggérée pour le soutenu.

### Choisir une architecture de référence {#choose-a-reference-architecture}

À ce stade, il existe deux tailles candidates : l'une basée sur les pics absolus, l'autre sur la charge soutenue.

Pour choisir une taille :

1. Si les pics et le soutenu suggèrent la même taille, utilisez cette taille.
1. Si les pics suggèrent une taille plus grande que le soutenu, calculez l'écart. Le RPS de pointe est-il dans les 10-15 % de la limite supérieure de la taille soutenue ?

Directives générales :

- Si le RPS de pointe dépasse la limite de la taille soutenue de moins de 10-15 %, la taille soutenue peut être envisagée avec un risque acceptable, car les architectures de référence disposent d'une marge intégrée.
- Au-delà de 15 %, commencez avec la taille basée sur les pics, puis surveillez et ajustez si les métriques permettent une réduction.

Exemples de package Linux / Cloud Native Hybrid :

- Le pic est de 110 RPS pour l'architecture 5 000 utilisateurs (jusqu'à 100 RPS) → 10 % de dépassement → l'architecture 5 000 utilisateurs devrait suffire.
- Le pic est de 150 RPS pour l'architecture 5 000 utilisateurs (jusqu'à 100 RPS) → 50 % de dépassement → utilisez l'architecture 10 000 utilisateurs (jusqu'à 200 RPS).
- Le pic est de 100 RPS (architecture 5 000 utilisateurs) mais le soutenu est de 50 RPS (architecture 3 000 utilisateurs, jusqu'à 60 RPS). Les graphiques RPS bruts montrent que les pics d'automatisation provoquent des pics tandis que la charge est inférieure à 50 RPS la plupart du temps. Évaluez s'il convient de commencer prudemment avec l'architecture 5 000 utilisateurs puis de réduire, ou de commencer avec l'architecture 3 000 utilisateurs avec une [mise à l'échelle spécifique à la charge de travail](#identify-component-adjustments) (risque plus élevé).

Exemple Cloud Native :

- Le pic est de 120 RPS (moyenne) mais le soutenu est de 80 RPS (petite). Évaluez s'il convient de commencer prudemment avec la taille moyenne puis de réduire, ou de commencer avec la petite taille avec une [mise à l'échelle spécifique à la charge de travail](#identify-component-adjustments) (risque plus élevé).

Pour les environnements inférieurs à 40 RPS et où la haute disponibilité (HA) est une exigence, consultez la [section haute disponibilité](../administration/reference_architectures/_index.md#high-availability-ha) pour déterminer si le passage à l'architecture 60 RPS / 3 000 utilisateurs avec des réductions supportées est nécessaire.

### Avant de continuer {#before-you-proceed}

Ayant complété cette section, vous avez établi la taille de votre architecture de référence de base. Cela constitue la fondation, mais les sections suivantes permettent de déterminer si une charge de travail spécifique nécessite des ajustements de composants au-delà de la configuration standard.

Avant de continuer, assurez-vous d'avoir documenté les informations recueillies dans cette section. Vous pouvez utiliser ce qui suit comme guide :

```markdown
Reference architecture assessment summary:

- Selected reference architecture: _____
- Justification based on _____ RPS [absolute/sustained]

| Traffic Type       | Peak RPS | Sustained RPS (95th) |
|:-------------------|:---------|:---------------------|
| API                | ________ | ____________________ |
| Web                | ________ | ____________________ |
| Git pull and clone | ________ | ____________________ |
| Git push           | ________ | ____________________ |

Highest RPS Peak timestamp for workload analysis: _____
```

## Comprendre la composition du RPS et les schémas de charge de travail {#understanding-rps-composition-and-workload-patterns}

Le RPS total est la métrique principale de dimensionnement, mais la composition de la charge de travail a un impact significatif sur les exigences en ressources des composants. Différents types de requêtes sollicitent différents composants avec des intensités variables.

### Répartition du RPS par type de requête {#rps-breakdown-by-request-type}

Les cibles RPS des architectures de référence supposent une composition de charge de travail typique basée sur des données de production :

- **Requêtes API** (~80 % du RPS total) - Automatisation, intégrations, webhooks et outils pilotés par API
- **Requêtes web** (~10 % du RPS total) - Interactions UI, navigation dans les pages et actions pilotées par les utilisateurs
- **Opérations Git** (~10 % du RPS total) - Clones et pulls de dépôts, avec des taux de push inférieurs

**Compositions atypiques** \- Environnements où un type de requête dépasse significativement les proportions typiques (peuvent nécessiter des ajustements spécifiques aux composants même dans les plages RPS cibles)

### Identification des schémas de charge de travail atypiques {#identifying-atypical-workload-patterns}

Utilisez les requêtes d'extraction RPS de la section [Extraire les métriques de trafic de pointe](#extract-peak-traffic-metrics) pour comprendre la composition de votre charge de travail. Comparez votre distribution aux schémas typiques :

**Charges de travail à dominante API** (API >90 % du RPS total) :

- Automatisation intensive, intégrations étendues ou outillage piloté par API
- Impact principal : Rails (Webservice), PostgreSQL, Gitaly
- À envisager : augmentation de la capacité Webservice/Rails, réplicas de lecture de base de données

**Charges de travail à dominante web** (Web >20 % du RPS total) :

- Grande base d'utilisateurs actifs avec une interaction UI intensive
- Impact principal : Rails (Webservice), PostgreSQL
- À envisager : augmentation de la capacité Webservice, optimisation de la base de données

**Charges de travail à dominante Git** (Git >15 % du RPS total ou taux de pull nettement supérieurs à la normale pour votre taille) :

- Grandes équipes avec des pulls fréquents, schémas de monodépôt ou workflows à forte utilisation CI/CD avec des clones de dépôts
- Impact principal : Gitaly, bande passante réseau
- À envisager : mise à l'échelle verticale de Gitaly, optimisation des dépôts, VM à réseau amélioré

### Approche d'évaluation {#assessment-approach}

1. Extrayez la répartition du RPS à l'aide des requêtes PromQL fournies
1. Calculez le pourcentage du total pour chaque type de requête
1. Déterminez si un type dépasse significativement les proportions typiques
1. Si atypique, consultez [Identifier les ajustements de composants](#identify-component-adjustments) pour les conseils de mise à l'échelle

> [!note]
> Les petites variations (différence de 5 à 10 RPS dans une catégorie quelconque) ne nécessitent pas de modifications d'architecture. Surveillez les métriques réelles de saturation des composants (CPU, mémoire, profondeurs de file d'attente) en production plutôt que de prendre des décisions basées uniquement sur des comparaisons RPS. Les composants dont l'utilisation soutenue est inférieure à 70 % disposent généralement d'une capacité suffisante, quelles que soient les variations mineures du RPS.

## Identifier les ajustements de composants {#identify-component-adjustments}

L'évaluation de la charge de travail identifie des schémas d'utilisation spécifiques qui nécessitent des ajustements de composants au-delà de l'architecture de référence de base. Alors que le RPS détermine la taille globale, les schémas de charge de travail en déterminent la forme. Deux environnements avec un RPS identique peuvent avoir des besoins en ressources très différents.

Différentes charges de travail sollicitent différentes parties de l'architecture GitLab :

- Les environnements à forte utilisation CI/CD traitant des milliers de jobs tout en maintenant un RPS modéré sollicitent Sidekiq et Gitaly.
- Les environnements avec une automatisation API intensive affichant un RPS élevé mais concentrant la charge sur la base de données et les couches Rails.

### Analyser les endpoints les plus sollicités lors des pics de charge {#analyze-top-endpoints-during-peak-load}

À l'aide de l'horodatage de pic de la section précédente, identifiez quels endpoints ont reçu le plus de trafic lors de la charge maximale.

> [!note]
> Si vos métriques RPS montrent un trafic constamment élevé pendant les heures creuses (>50 % du pic), cela suggère une automatisation intensive au-delà des schémas typiques. Par exemple, un trafic de pointe atteignant 100 RPS pendant les heures ouvrables mais maintenant 50+ RPS la nuit et le week-end indique une charge de travail automatisée significative. Tenez-en compte lors de l'[évaluation des ajustements de composants](#determine-component-adjustments).

1. Exécutez cette requête avec la visualisation activée (graphique à barres pour la distribution dans le temps, ou graphique en secteurs pour la distribution générale) :

   ```prometheus
   topk(20,
     sum by (controller, action) (
       rate(gitlab_transaction_duration_seconds_count{controller!~"HealthController|MetricsController", action!~".*/internal/.*"}[1m])
     )
   )
   ```

1. Examinez les résultats pour la distribution des endpoints les plus sollicités lors du pic absolu de RPS. Les résultats peuvent présenter :

   - Aucun schéma d'endpoint visible. Dans ce cas, continuez avec l'architecture de référence sélectionnée précédemment. Assurez-vous qu'un monitoring robuste est en place pour mesurer l'impact de tout changement de charge de travail.
   - Une majorité d'utilisation intensive de l'API pour le trafic non-Git. Dans ce cas, les webhooks et les appels API liés aux tickets, groupes et projets indiquent un schéma intensif pour la base de données.
   - Une majorité d'endpoints liés à Git ou à Sidekiq. Dans ce cas, les diffs de merge requests, les jobs de pipeline, les branches, les commits, les opérations sur les fichiers, les jobs CI/CD, l'analyse de sécurité et les opérations d'import indiquent un schéma intensif pour Sidekiq/Gitaly.

1. Enregistrez les conclusions :

   ```markdown
   Workload pattern identified:

   - [ ] Database-intensive
   - [ ] Sidekiq- or Gitaly-intensive
   - [ ] None detected
   ```

### Déterminer les ajustements de composants {#determine-component-adjustments}

Les indicateurs ci-dessus fournissent des signaux initiaux de charges de travail supplémentaires. Grâce à la marge intégrée dans les architectures de référence, ces charges de travail peuvent être gérées sans ajustements. Cependant, si des indicateurs forts existent et que des niveaux élevés d'automatisation sont connus, envisagez les ajustements suivants.

Sur la base du schéma de charge de travail identifié précédemment, différents composants nécessitent une mise à l'échelle :

| Type de charge de travail              | Quand appliquer                                                                                                                                                                                | Composants à mettre à l'échelle |
|:---------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------------|
| Intensive pour la base de données         | <ul><li>Utilisation intensive de l'API pour le trafic non-Git (webhooks, tickets, groupes et projets)</li><li>[Charges de travail d'automatisation ou d'intégration étendues](../administration/reference_architectures/_index.md#additional-workloads) connues</li></ul> | <ul><li>Augmenter les ressources Rails</li><li>[Mise à l'échelle de la base de données](#database-scaling)</li></ul> |
| Intensive pour Sidekiq/Gitaly\*\* | <ul><li>Opérations Git intensives, jobs CI/CD, analyse de sécurité, opérations d'import et hooks de serveur Git</li><li>Schémas d'utilisation à forte utilisation CI/CD connus</li></ul>                                      | <ul><li>Augmenter les spécifications Sidekiq</li><li>Mise à l'échelle verticale de Gitaly</li><li>[Mise à l'échelle de la base de données](#database-scaling)</li><li>Avancé : configurer des [classes de jobs](../administration/sidekiq/processing_specific_job_classes.md) spécifiques</li></ul> |

#### Conseils de mise à l'échelle {#scaling-guidance}

Les ajustements de ressources varient en fonction de l'intensité de la charge de travail et des métriques de saturation :

1. Commencez avec 1,25x à 1,5x les ressources actuelles.
1. Affinez en fonction des données de monitoring après implémentation.

Si vous planifiez de déployer GitLab cloud-native, les schémas de charge de travail identifiés dans cette évaluation ont des implications supplémentaires pour la configuration de Kubernetes :

- Trafic élevé pendant les heures creuses. Assurez-vous que les nombres minimaux de pods sont suffisants pour la charge de référence plutôt que de permettre la mise à l'échelle à zéro pendant les périodes calmes. Par exemple, avec 100 RPS pendant les heures ouvrables et un RPS constant de 50 la nuit dû à l'automatisation, la configuration du nombre minimal de pods doit être alignée avec la charge de référence en dehors des heures ouvrables.
- Pics de trafic rapides. Les paramètres HPA par défaut peuvent ne pas être suffisamment rapides pour mettre à l'échelle. Surveillez le comportement de mise à l'échelle des pods lors du déploiement initial pour éviter la mise en file d'attente des requêtes lors de ces transitions. Par exemple, un pic rapide de 50 à 200 RPS causé par une montée en charge des heures calmes vers les heures ouvrables ou un pic d'automatisation spécifique.

##### Mise à l'échelle de la base de données {#database-scaling}

La stratégie de mise à l'échelle de la base de données dépend des caractéristiques de la charge de travail et peut nécessiter plusieurs approches :

1. Mise à l'échelle verticale pour traiter les contraintes de capacité immédiates, qui :
   - Est requise pour les charges de travail intensives en écriture car les réplicas ne réduisent pas la charge du nœud principal.
   - Fournit une augmentation immédiate de la capacité pour les opérations de lecture et d'écriture.
1. [Équilibrage de charge de la base de données](../administration/postgresql/database_load_balancing.md) (recommandé) avec des réplicas de lecture, qui :
   - Est particulièrement bénéfique pour les charges de travail intensives en lecture (85 à 95 % de lectures).
   - Distribue le trafic de lecture sur plusieurs nœuds.
   - Peut être ajouté en combinaison avec la mise à l'échelle verticale.
1. Continuez la mise à l'échelle verticale si les performances en écriture restent un goulot d'étranglement.

Utilisez cette requête Prometheus pour identifier la distribution lecture/écriture :

```prometheus
# Percentage of READ operations
(
  (sum(rate(gitlab_transaction_db_count_total[5m])) - sum(rate(gitlab_transaction_db_write_count_total[5m]))) /
  sum(rate(gitlab_transaction_db_count_total[5m]))
) * 100
```

### Avant de continuer {#before-you-proceed-1}

Ayant complété cette section, vous avez identifié les schémas de charge de travail et déterminé les ajustements de composants nécessaires.

Avant de continuer, enregistrez l'évaluation complète de la charge de travail :

```markdown
Workload pattern identified:

- [ ] Database-intensive
- [ ] Sidekiq- or Gitaly-intensive
- [ ] None detected
- Component adjustments needed: _____
```

Dans la section suivante, vous évaluez les caractéristiques spéciales des données qui pourraient nécessiter des considérations d'infrastructure supplémentaires.

## Évaluer les exigences d'infrastructure spéciales {#assess-special-infrastructure-requirements}

Les caractéristiques des dépôts et les schémas d'utilisation du réseau peuvent avoir un impact significatif sur les performances de GitLab au-delà de ce que révèlent les métriques RPS.

Les grands monodépôts, les fichiers binaires étendus et les opérations intensives en réseau nécessitent des ajustements d'infrastructure que le dimensionnement standard ne prend pas en compte.

### Grands monodépôts {#large-monorepos}

Les grands monodépôts (plusieurs gigaoctets ou plus) changent fondamentalement la manière dont les opérations Git s'exécutent. Un seul clone d'un dépôt de 10 Go consomme plus de ressources que des centaines de clones de dépôts typiques.

Ces dépôts affectent non seulement Gitaly, mais aussi Rails, Sidekiq et la base de données selon la charge de travail.

Le processus de profilage se concentre sur l'identification des dépôts qui dépassent significativement les tailles typiques :

- Monodépôts moyens : 2 Go - 10 Go. Ceux-ci nécessitent des ajustements modestes.
- Grands monodépôts : >10 Go. Ceux-ci nécessitent des modifications d'infrastructure significatives.

Pour identifier la taille d'un dépôt :

1. Accédez aux [quotas d'utilisation](../user/storage_usage_quotas.md#view-storage) d'un projet.
1. Examinez le [type de stockage **Dépôt**](../user/project/repository/repository_size.md).
1. Calculez le nombre de projets avec des dépôts de plus de 2 Go et de plus de 10 Go.
1. Enregistrez les résultats :

   ```plaintext
   Number of medium monorepos (2GB - 10GB): _____
   Number of large monorepos (>10GB): _____
   ```

#### Ajustements d'infrastructure pour les monodépôts {#infrastructure-adjustments-for-monorepos}

Les grands dépôts nécessitent à la fois une mise à l'échelle verticale et des ajustements opérationnels. Ces dépôts affectent les performances sur l'ensemble de la pile, des opérations Git et de l'utilisation du CPU jusqu'à la consommation de mémoire et la bande passante réseau.

| Scénario                 | Ajustements de composants |
|:-------------------------|:----------------------|
| Plusieurs monodépôts moyens | <ul><li>Gitaly : spécifications x1,5-x2</li><li>Rails : spécifications x1,25-x1,5</li></ul> |
| Grands monodépôts          | <ul><li>Gitaly : spécifications x2-x4</li><li>Rails : spécifications x1,5-x2</li><li>Envisager le partitionnement du monodépôt vers un nœud Gitaly dédié</li></ul> |

Des stratégies d'optimisation supplémentaires pour les environnements à monodépôt sont documentées dans [Amélioration des performances des monodépôts](../user/project/repository/monorepos/_index.md), notamment Git LFS pour les fichiers binaires et le clonage superficiel.

### Charges de travail intensives en réseau {#network-heavy-workloads}

La saturation réseau cause des problèmes uniques souvent difficiles à diagnostiquer. Contrairement aux goulots d'étranglement CPU ou mémoire qui affectent des opérations spécifiques, la saturation réseau peut provoquer des délais d'expiration apparemment aléatoires sur toutes les fonctions GitLab.

Sources courantes de charge réseau :

- Utilisation intensive du registre de conteneurs (grandes images, pulls fréquents).
- Opérations LFS (fichiers binaires, ressources médias).
- Grands artefacts CI/CD (sorties de build, résultats de tests).
- Clones de monodépôts (notamment dans les pipelines CI/CD).

#### Mesurer l'utilisation du réseau {#measure-network-usage}

Calculez la consommation réseau de pointe et de référence pour identifier les goulots d'étranglement potentiels. Évaluez les deux pour distinguer les pics occasionnels (gérés par la capacité en rafale) du trafic élevé soutenu (nécessitant des VM à réseau amélioré).

1. Exécutez les requêtes suivantes :

   ```prometheus
   # Outbound traffic (Gbps) - top 10 nodes
   topk(10, sum by (instance) (rate(node_network_transmit_bytes_total{device!="lo"}[5m]) * 8 / 1000000000))


   # Inbound traffic (Gbps) - top 10 nodes
   topk(10, sum by (instance) (rate(node_network_receive_bytes_total{device!="lo"}[5m]) * 8 / 1000000000))

   ```

1. Enregistrez à la fois les pics et la référence typique observés sur votre période de monitoring :

   ```plaintext
   Peak outbound traffic: _____ Gbps (baseline: _____ Gbps)
   Peak inbound traffic: _____ Gbps (baseline: _____ Gbps)
   ```

#### Exigences de capacité réseau {#network-capacity-requirements}

Les seuils ci-dessous sont des directives approximatives uniquement. Les garanties de bande passante réseau réelles varient significativement selon le fournisseur cloud et le type de VM. Vérifiez toujours les spécifications réseau (limites de référence et en rafale) pour vos types d'instances spécifiques afin de vous assurer qu'elles correspondent à vos schémas de charge de travail.

Sur la base des mesures de trafic sortant et entrant :

| Charge réseau | Seuil | Pourquoi ce seuil                                                 | Action requise |
|:-------------|:----------|:-------------------------------------------------------------------|:----------------|
| Standard     | <1 Gbps   | Dans la bande passante de référence de la plupart des instances standard               | Instances standard suffisantes |
| Modérée     | 1-3 Gbps  | Peut dépasser la référence AWS mais dans les limites des instances standard GCP/Azure    | <ul><li>AWS : surveillez la limitation, une VM à réseau amélioré peut être nécessaire</li><li>GCP/Azure : instances standard généralement suffisantes</li></ul> |
| Élevé         | 3-10 Gbps | Dépasse la référence AWS. S'approche des limites de certaines instances standard | <ul><li>AWS : VM à réseau amélioré requises</li><li>GCP/Azure : vérifiez les spécifications de bande passante des instances</li></ul> |
| Très élevée    | >10 Gbps  | Dépasse les capacités de la plupart des instances standard                        | <ul><li>VM à réseau amélioré requises chez tous les fournisseurs</li><li>Pour les grands artefacts, désactivez le [téléchargement par proxy des objets](../administration/object_storage.md#proxy-download)</li></ul> |

### Avant de continuer {#before-you-proceed-2}

Avant de continuer, enregistrez l'évaluation complète du profilage des données :

```txt
Data Profile Summary:
- Medium monorepos (2GB-10GB): _____
- Large monorepos (>10GB): _____
- Gitaly adjustments needed: _____
- Rails adjustments needed: _____
- Peak outbound traffic: _____ Gbps (sustained baseline: _____ Gbps)
- Peak inbound traffic: _____ Gbps (sustained baseline: _____ Gbps)
- Network infrastructure changes: _____
```

## Analyser l'environnement actuel et valider les recommandations {#analyze-current-environment-and-validate-recommendations}

La compréhension de l'environnement existant fournit un contexte crucial pour les recommandations :

- Si l'environnement actuel gère la charge de travail sans problèmes de performances, il sert de validation précieuse pour les estimations de dimensionnement.
- En revanche, les environnements présentant des problèmes de performances nécessitent une analyse approfondie pour éviter de perpétuer un sous-dimensionnement.

### Documenter l'environnement actuel {#document-the-current-environment}

Collectez des données d'environnement complètes pour établir l'état actuel :

- Détails de l'architecture :
  - Type : haute disponibilité (HA) ou sans haute disponibilité (non-HA).
  - Méthode de déploiement : package Linux ou GitLab cloud-native.
- Spécifications des composants :
  - Nombre de nœuds et spécifications pour chaque composant.
  - Configurations personnalisées ou déviations.

### Identifier l'architecture de référence la plus proche {#identify-the-nearest-reference-architecture}

1. Comparez l'environnement actuel aux [architectures de référence disponibles](../administration/reference_architectures/_index.md). Tenez compte des éléments suivants :

   - Ressources de calcul totales par composant.
   - Distribution des nœuds et schéma d'architecture (HA vs non-HA).
   - Spécifications des composants par rapport aux tailles des architectures de référence.

1. Enregistrez vos conclusions :

   ```plaintext
   Nearest Reference Architecture: _____
   Custom configurations or deviations:
   - _____
   - _____
   ```

### Comparer l'environnement actuel à l'architecture recommandée {#compare-current-environment-to-recommended-architecture}

Comparez l'environnement actuel à l'architecture de référence recommandée que vous avez développée à partir des sections précédentes. Si l'environnement actuel :

- N'a pas de problèmes de performances et les ressources actuelles < AR recommandée :
  - Les recommandations sont conservatrices et offrent une marge pour l'avenir.
  - Procédez avec l'AR recommandée.
  - Surveillez après l'implémentation pour identifier les opportunités d'optimisation potentielles.
- N'a pas de problèmes de performances et les ressources actuelles ≈ AR recommandée :
  - Validation solide de votre évaluation du dimensionnement.
  - L'environnement actuel confirme que la taille recommandée est appropriée.
- N'a pas de problèmes de performances et les ressources actuelles > AR recommandée :
  - L'environnement actuel pourrait être sur-provisionné ou avoir des raisons valides pour des ressources supplémentaires qui doivent être analysées. Vérifiez l'[utilisation des ressources](../administration/monitoring/prometheus/_index.md#sample-prometheus-queries) CPU/mémoire sur Rails, Gitaly, la base de données et Sidekiq.

    Une faible utilisation (<40 %) suggère un sur-provisionnement. Une utilisation élevée peut indiquer des exigences de charge de travail spécifiques non capturées dans l'analyse RPS.
  - Examinez si les recommandations nécessitent un ajustement pour des exigences non découvertes.

Si l'environnement actuel présente des problèmes de performances :

- Utilisez les spécifications actuelles uniquement comme référence minimale. Les recommandations des sections précédentes doivent dépasser les spécifications actuelles.
- Si les recommandations sont significativement inférieures aux spécifications actuelles, examinez :
  - Les schémas de charge de travail non capturés dans l'évaluation.
  - Les goulots d'étranglement spécifiques aux composants nécessitant une mise à l'échelle ciblée.

### Avant de continuer {#before-you-proceed-3}

Ayant complété cette section, vous avez analysé l'environnement actuel et l'avez comparé aux recommandations.

Avant de continuer, enregistrez la comparaison complète de l'environnement :

```plaintext
Current Environment Analysis:
- Current RA (nearest): _____
- Recommended RA (from RPS and workload analysis): _____
- Resource comparison: [ ] Current < Recommended [ ] Current ≈ Recommended [ ] Current > Recommended
- Performance status: [ ] No issues [ ] Has issues
- Adjustments needed: _____
- Notes: _____
```

Dans la section suivante, vous évaluez les projections de croissance pour vous assurer que le dimensionnement reste approprié au fil du temps.

## Planifier la capacité future {#plan-for-future-capacity}

Les modifications d'infrastructure nécessitent un délai de préparation significatif pour l'approvisionnement, la migration et les tests. L'estimation de la croissance garantit que l'architecture recommandée reste viable tout au long de la période d'implémentation et au-delà.

Les tendances historiques combinées avec les plans d'affaires fournissent les projections de croissance les plus précises.

### Analyser les schémas de croissance historiques {#analyze-historical-growth-patterns}

Les schémas de croissance passés peuvent aider à prédire la trajectoire future mieux que les projections d'affaires :

1. Comparez le RPS actuel à celui des 6 à 12 mois précédents en utilisant les informations de [votre taille de référence](#determine-your-baseline-size).
1. Identifiez les tendances d'accélération ou de décélération de la croissance.

### Intégrer les facteurs de planification d'affaires {#incorporate-business-planning-factors}

Changements d'affaires attendus qui ont un impact sur les besoins en infrastructure :

- Expansion ou consolidation d'équipe.
- Nouveaux développements de projets.
- Activité de développement accrue sur les projets existants.

Évaluez si l'un de ces facteurs (ou d'autres changements organisationnels) pourrait affecter la charge sur l'environnement et nécessiter des ajustements d'infrastructure. Documentez les changements pertinents et leur calendrier prévu.

#### Déterminer la stratégie de marge de croissance {#determine-growth-buffer-strategy}

Sur la base des tendances historiques et des projections d'affaires, sélectionnez la stratégie d'adaptation à la croissance appropriée :

- Croissance stable ou minimale : continuez à surveiller. Les architectures de référence incluent une marge intégrée.
- Croissance modérée : planifiez une AR dimensionnée pour gérer le RPS futur projeté.
- Croissance significative anticipée : envisagez de dimensionner pour le RPS futur projeté plutôt que pour le RPS actuel.

### Avant de continuer {#before-you-proceed-4}

Ayant complété cette section, les projections de croissance sont intégrées dans la décision de dimensionnement.

Enregistrez l'analyse complète de la croissance :

```plaintext
Growth Assessment Summary:
- Historical RPS comparison: _____
- Business growth factors: _____
- Growth category: [ ] Stable/Minimal [ ] Moderate [ ] Significant
- Strategy: [ ] Current RA sufficient [ ] Size for projected growth
```

Dans la section suivante, vous compilez toutes les conclusions en recommandations d'architecture finales.

## Compiler les conclusions {#compile-findings}

Compilez les conclusions de toutes les sections précédentes pour déterminer l'architecture de référence optimale et les ajustements nécessaires.

### Déterminer l'architecture finale {#determine-final-architecture}

Rassemblez les résultats clés de chaque section pour former la décision de dimensionnement :

1. Commencez par l'architecture de référence identifiée sur la base de l'[analyse RPS](#determine-your-baseline-size).
1. Appliquez les ajustements de composants nécessaires en fonction des [schémas de charge de travail](#identify-component-adjustments) et des [caractéristiques des données](#assess-special-infrastructure-requirements). Ignorez cette étape si aucun schéma n'est identifié ou si la configuration standard est suffisante.
1. Validez par rapport à l'[état actuel](#analyze-current-environment-and-validate-recommendations). Si l'environnement actuel fonctionne bien mais dépasse les recommandations, documentez les raisons. S'il présente des problèmes de performances, assurez-vous que les recommandations dépassent les spécifications actuelles.
1. Intégrez la [croissance dans votre plan de capacité future](#plan-for-future-capacity). Déterminez si l'AR actuelle est suffisante ou si un dimensionnement pour la croissance projetée est nécessaire.

### Documenter la recommandation finale {#document-final-recommendation}

Sur la base de l'évaluation complète, enregistrez la recommandation d'architecture complète :

```plaintext
Final Architecture Recommendation
==================================

- Selected RA: [Size] based on [Absolute/Sustained] Peak RPS of [value]
- Component adjustments required:
  - [ ] No adjustments needed - standard RA configuration sufficient
  - [ ] Adjustments required:
      - Rails: _____
      - Sidekiq: _____
      - Database: _____
      - Gitaly: _____
      - Network considerations: □ Standard instances □ Network-optimized instances
- Selected RA is aligned with existing environment: [Yes/No/Not applicable]
- Growth accommodation: [Current RA sufficient / Sized up for growth]

Assessment Summary:
├── RPS Analysis
│   ├── Absolute Peak RPS: _____ → Baseline RA: _____
│   └── Sustained Peak RPS: _____ → Sustained RA: _____
├── Workload Type
│   └── Type: [ ] Database-Intensive [ ] Sidekiq-Intensive [ ] None
├── Data Profile
│   ├── Large repos (>2GB): _____ | Monorepos (>10GB): _____
│   └── Network: Peak _____ Gbps | Baseline _____ Gbps
├── Current State
│   ├── Nearest RA: _____
|   └── Discrepancies and customizations: _____
└── Growth
    ├── Growth projection: _____
    └── Growth buffer strategy: _____
```

Ayant complété toutes les sections, l'évaluation du dimensionnement est terminée. La recommandation finale comprend :

- La taille d'architecture de référence de base.
- Les ajustements spécifiques aux composants
- La stratégie d'adaptation à la croissance.

La surveillance régulière reste essentielle pour valider les hypothèses et ajuster l'infrastructure à mesure que les schémas de charge de travail évoluent.
