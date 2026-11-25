---
stage: Security Risk Management
group: Pipeline Security
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Pare-feu des dépendances
description: "Bloquez les paquets dont les licences ne sont pas autorisées, présentant un risque élevé de vulnérabilité ou contenant du code malveillant avant qu'un gestionnaire de paquets ne les installe."
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed
- Statut : version bêta

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/groups/gitlab-org/-/epics/22189) dans GitLab 19.0 en tant que [version expérimentale](../../../policy/development_stages_support.md).
- Passage à la [version bêta](../../../policy/development_stages_support.md) dans GitLab 19.5. Disponible dans les éditions Premium et Ultimate sur GitLab.com et GitLab Self-Managed. La prise en charge de GitLab Dedicated est prévue pour la disponibilité générale.

{{< /history >}}

> [!warning]
> Le pare-feu de dépendances est en [version bêta](../../../policy/development_stages_support.md). Le comportement, le schéma de politique et les écosystèmes pris en charge peuvent changer entre les releases. Testez les politiques en mode `warn` avant de les appliquer.

Utilisez le pare-feu de dépendances pour contrôler les paquets que vos développeurs et vos jobs CI/CD installent. Une politique de pare-feu de dépendances évalue chaque paquet par rapport aux règles que vous définissez pour les licences, le risque de vulnérabilité et le code malveillant. Lorsqu'un paquet correspond à une règle de refus, le pare-feu refuse le téléchargement et enregistre la décision.

## Fonctionnement du pare-feu de dépendances {#how-does-dependency-firewall-work}

Vous exécutez votre gestionnaire de paquets via la [CLI GitLab](../../../editor_extensions/gitlab_cli/_index.md) avec `glab dependency-firewall`, ou son alias abrégé `glab df`. Chaque paquet est évalué au moment où le gestionnaire de paquets le résout, avant qu'il n'atteigne votre machine :

1. Votre gestionnaire de paquets demande un paquet à partir du registre qu'il est déjà configuré pour utiliser, tel que npmjs.com, PyPI, Maven Central ou RubyGems.org.
1. La CLI intercepte la requête via un proxy d'inspection local et demande à GitLab d'évaluer le nom et la version du paquet par rapport aux politiques qui s'appliquent à votre projet.
1. GitLab renvoie l'un des trois résultats possibles. Un paquet autorisé est récupéré normalement. Un paquet averti est récupéré et signalé. Un paquet bloqué est refusé et le gestionnaire de paquets reçoit une réponse `403 Forbidden`.

GitLab n'héberge ni ne met en miroir les paquets qu'il évalue. Vous n'avez donc pas à déplacer vos dépendances dans le registre de paquets GitLab ni à modifier la configuration de registre que votre projet utilise déjà.

## Écosystèmes pris en charge {#supported-ecosystems}

| Écosystème | Gestionnaires de paquets |
|-----------|------------------|
| Java      | Maven, Gradle |
| Node.js   | npm, pnpm, Yarn |
| Python    | pip, `uv`, Poetry, pipenv, twine |
| Ruby      | `gem`, Bundler |

Les paquets appartenant à d'autres écosystèmes sont récupérés sans évaluation.

## Restrictions {#restrictions}

- Seul le trafic proxy de `glab df` est évalué. Un gestionnaire de paquets exécuté seul, tel que `npm install` sans le préfixe, n'atteint pas le pare-feu. Pour faire du pare-feu la seule voie d'accès à un registre, consultez [Empêcher le contournement du pare-feu](#prevent-bypassing-the-firewall).
- Les politiques sont évaluées par rapport au nom du paquet, à la version et à l'écosystème. Le pare-feu résout les licences, les vulnérabilités et les données de paquets malveillants à partir de la base de données de métadonnées des paquets et de la [base de données advisory GitLab](../gitlab_advisory_database/_index.md).
- Un paquet absent de la base de données de métadonnées des paquets est autorisé. Un résultat autorisé ne garantit pas que GitLab dispose de données de licence ou de vulnérabilité pour ce paquet.
- Un maximum de cinq politiques de pare-feu de dépendances est autorisé par projet de politique de sécurité. Cette limite est contrôlée par le paramètre d'application `dependency_firewall_policies_per_configuration_limit`.
- Le proxy local se connecte directement aux registres. Il n'utilise pas de proxy d'entreprise sortant, donc `glab df` ne peut pas atteindre les registres dans un réseau qui en requiert un.
- Les registres doivent utiliser HTTPS. Le proxy accepte uniquement le trafic HTTPS et refuse les requêtes `http://` en texte clair.
- Les paquets déjà présents dans le cache d'un gestionnaire de paquets ne sont pas réévalués. Maven lit depuis `~/.m2/repository/`, npm depuis `node_modules/` et Bundler depuis `vendor/bundle/`. Le pare-feu est évalué uniquement lorsque le gestionnaire de paquets récupère un paquet via le réseau.

## Prérequis {#prerequisites}

Pour utiliser le pare-feu de dépendances :

- Votre espace de nommage doit avoir accès à l'édition Premium ou Ultimate.
- Un [projet de politique de sécurité](../policies/enforcement/security_policy_projects.md) doit être lié au projet ou à l'un de ses groupes parents.
- Le pare-feu de dépendances doit être activé. Consultez [Activer le pare-feu de dépendances](#turn-on-the-dependency-firewall).
- Les développeurs doivent avoir la CLI GitLab installée et authentifiée auprès de votre instance GitLab.
- Les développeurs et les utilisateurs qui exécutent des jobs CI/CD doivent avoir au minimum le rôle Reporter sur le projet.

## Activer le pare-feu de dépendances {#turn-on-the-dependency-firewall}

Sur GitLab.com, le pare-feu est activé pour chaque groupe principal. Sur GitLab Self-Managed, il est activé une seule fois pour l'ensemble de l'instance.

### Sur GitLab.com {#on-gitlabcom}

Prérequis :

- Vous devez avoir le rôle Propriétaire pour le groupe principal.

Pour activer le pare-feu de dépendances :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe.
1. Sélectionnez **Paramètres** > **Sécuriser**.
1. Activez le bouton bascule **Activer le pare-feu de dépendances**.

Ce paramètre est disponible uniquement pour les groupes principaux. Les sous-groupes et les projets héritent du paramètre de leur groupe principal.

### Sur GitLab Self-Managed {#on-gitlab-self-managed}

Prérequis :

- Vous devez être administrateur.

Pour activer le pare-feu de dépendances :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Sélectionnez **Paramètres** > **Sécurité et conformité**.
1. Développez **Pare-feu de dépendances**.
1. Cochez la case **Activer le pare-feu de dépendances**.
1. Sélectionnez **Enregistrer les modifications**.

Le paramètre s'applique à tous les projets de l'instance. Il n'existe pas de bouton bascule par groupe.

Pour désactiver le pare-feu, répétez les étapes correspondant à votre offre et désactivez le paramètre. Les politiques existantes sont conservées, mais le pare-feu cesse d'évaluer les paquets.

## Empêcher le contournement du pare-feu {#prevent-bypassing-the-firewall}

Le pare-feu évalue uniquement le trafic que `glab df` peut voir. Un gestionnaire de paquets exécuté seul installe tout ce qu'il résout, tout comme un agent de codage IA qui appelle un gestionnaire de paquets pour vous. Ni l'un ni l'autre n'atteint le pare-feu, donc ni l'un ni l'autre ne voit de blocage. De plus, les paquets peuvent être mis en cache, comme mentionné ci-dessus.

Pour combler cette lacune, appliquez le pare-feu au niveau du point de sortie réseau plutôt que de compter sur chaque appelant pour mémoriser le préfixe.

La CLI ajoute l'en-tête suivant à chaque requête qu'elle transmet à un registre, y compris les requêtes de métadonnées et d'index, ainsi que les requêtes concernant les paquets autorisés et avertis :

```plaintext
X-Gitlab-Dependency-Firewall: allowed
```

Configurez votre proxy ou passerelle de sortie pour autoriser le trafic HTTPS vers les registres de paquets uniquement lorsque cet en-tête est présent. Un gestionnaire de paquets qui s'exécute en dehors de `glab df` n'envoie pas cet en-tête, de sorte que la requête est refusée à la frontière réseau plutôt que de réussir silencieusement.

Ce contrôle nécessite :

- Un point de contrôle de sortie qui inspecte le trafic HTTPS. L'en-tête circule à l'intérieur de la session TLS que la CLI ouvre vers le registre. Une passerelle qui ne voit que l'hôte de destination ne peut donc pas le lire.
- Une règle pour chaque nom d'hôte de registre utilisé par vos équipes, comme `registry.npmjs.org`, `pypi.org`, `files.pythonhosted.org`, `repo.maven.apache.org` et `rubygems.org`.

L'en-tête est défini par la CLI, ce qui en fait un garde-fou plutôt qu'une frontière. Il arrête un gestionnaire de paquets ou un agent qui ne connaît pas l'en-tête. Un appelant qui définit lui-même l'en-tête atteint tout de même le registre.

L'en-tête ne prouve pas non plus qu'une politique a évalué la requête. La CLI l'ajoute même lorsque le pare-feu n'évalue pas le projet, par exemple lorsque le pare-feu est désactivé ou que le projet est introuvable. L'en-tête indique uniquement que la requête est passée par `glab df`. La CLI ne transmet jamais les paquets bloqués.

Certaines configurations envoient également du trafic en contournant la CLI. Par exemple, un paramètre `http_proxy:` dans un fichier `gemrc` a la priorité sur les paramètres de proxy que la CLI applique pour `gem` et `bundle`, de sorte que ce trafic n'est pas inspecté. RubyGems lit le fichier `gemrc` système, `~/.gemrc`, et le fichier désigné par la variable `GEMRC`. Il ne lit pas ces fichiers depuis le dépôt. Un fichier de projet commité ne peut donc pas provoquer ce problème, contrairement à une image CI ou à une machine de développeur.

## Tarification pendant la version bêta {#pricing-during-beta}

Le pare-feu de dépendances est gratuit pendant la version bêta. Lors de la disponibilité générale, il devient une fonctionnalité payante, facturée via les [GitLab Credits](../../../subscriptions/gitlab_credits.md). Vous devez accepter avant d'être facturé, et GitLab vous en avertit avant que cela ne se produise.

## Créer une politique de pare-feu de dépendances {#create-a-dependency-firewall-policy}

Les politiques de pare-feu de dépendances sont stockées dans le fichier `.gitlab/security-policies/policy.yml` d'un [projet de politique de sécurité](../policies/enforcement/security_policy_projects.md). Créez une politique dans l'éditeur de politiques ou commitez directement dans ce fichier.

La création de politiques au niveau du groupe signifie que la politique s'applique à chaque projet du groupe, ainsi qu'à ses sous-groupes. La création d'une politique au niveau du projet signifie que la politique s'applique uniquement à ce projet.

Prérequis :

- Par défaut, seuls les propriétaires de groupes, sous-groupes ou projets disposent des [permissions](../../permissions.md#project-application-security) requises pour créer ou attribuer un projet de politique de sécurité. Vous pouvez également créer un rôle personnalisé avec la permission de [gérer les liens de politique de sécurité](../../custom_roles/abilities.md#security-policy-management).

Pour créer une politique de pare-feu de dépendances :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre projet.
1. Sélectionnez **Sécurisation** > **Politiques**.
1. Sélectionnez **Nouvelle politique**.
1. Dans **Politique de pare-feu de dépendances**, sélectionnez **Sélectionner la politique**.
1. Remplissez les champs. Pour connaître la signification de chaque champ, consultez [Schéma de politique](#policy-schema).
1. Sélectionnez **Configurer avec une requête de fusion**.
1. Examinez et fusionnez la merge request.

Une fois la merge request fusionnée, la politique prend effet lors de la prochaine évaluation.

### Modes de l'éditeur {#editor-modes}

L'éditeur de politiques s'ouvre en mode règle, un formulaire qui crée la politique pour vous. Le mode règle couvre le nom, la description, la portée, le mode d'application et les règles. Les paramètres de contournement se trouvent sous **Paramètres avancés**.

Pour écrire la politique en YAML, sélectionnez **Mode YAML**. Utilisez le mode YAML pour copier une politique entre des projets ou pour utiliser un champ que le mode règle n'affiche pas.

Vous pouvez basculer entre les deux modes à tout moment. Si le YAML contient une erreur, le mode règle est désactivé jusqu'à ce que vous la corrigiez. Pour plus d'informations, consultez [Éditeur de politiques](../policies/_index.md#policy-editor).

### Schéma de politique {#policy-schema}

Une politique de pare-feu de dépendances possède les champs de niveau supérieur suivants.

| Champ              | Type    | Obligatoire | Description |
|--------------------|---------|----------|-------------|
| `name`             | Chaîne  | oui      | Nom de la politique. 255 caractères maximum. |
| `description`      | Chaîne  | non       | Description plus détaillée de la politique. |
| `enabled`          | Booléen | oui      | Indique si la politique est évaluée. Définissez sur `false` pour désactiver la politique sans la supprimer. |
| `enforcement_type` | Chaîne  | oui      | L'une des valeurs `enforced` ou `warn`. Consultez [Modes d'application](#enforcement-modes). |
| `rules`            | Tableau   | oui      | Une ou plusieurs règles. Consultez [Types de règles](#rule-types). |
| `bypass_settings`  | objet  | non       | Utilisateurs et jetons d'accès qui contournent la politique. Consultez [Paramètres de contournement](#bypass-settings). |
| `policy_scope`     | objet  | non       | Groupes et projets auxquels la politique s'applique. Consultez [Portée de la politique](#policy-scope). |

### Modes d'application {#enforcement-modes}

Le champ `enforcement_type` contrôle ce qui se passe lorsqu'une règle correspond :

- `enforced` : le pare-feu refuse le paquet. Le gestionnaire de paquets reçoit une réponse `403 Forbidden` et le paquet n'est pas installé.
- `warn` : le pare-feu récupère le paquet et le signale dans le résumé d'exécution. Utilisez ce mode pour tester une politique avant de l'appliquer.

Lorsqu'aucune règle d'une politique active ne correspond à un paquet, le pare-feu l'autorise.

### Types de règles {#rule-types}

Une politique doit contenir au moins une règle. Chaque règle possède un champ `type` qui est l'une des valeurs suivantes : `license`, `risk_severity` ou `malicious`. En mode règle, sélectionnez le type dans **Choisir un type de règle**.

> [!note]
> Le mode règle propose également un type de règle **Vulnérabilité**. Il est déprécié et sera supprimé. Utilisez plutôt **Gravité du risque**, qui compte les vulnérabilités par gravité plutôt que de correspondre à un seuil de gravité unique.

#### Règles de licence {#license-rules}

Les règles de licence correspondent aux paquets par leur nom de licence SPDX. Utilisez `denied` pour bloquer les paquets qui déclarent l'une des licences répertoriées. Utilisez `allowed` pour bloquer les paquets qui déclarent une licence absente de la liste. Les deux clés sont mutuellement exclusives.

```yaml
rules:
  - type: license
    denied:
      - name: GNU General Public License v3.0 only
      - name: GNU Affero General Public License v3.0 only
```

```yaml
rules:
  - type: license
    allowed:
      - name: MIT License
      - name: Apache License 2.0
```

#### Règles de gravité du risque {#risk-severity-rules}

Les règles de gravité du risque correspondent aux paquets selon le nombre de vulnérabilités connues qu'ils présentent à chaque niveau de gravité. Chaque entrée associe une `severity` à un `threshold`, qui correspond au nombre maximal de vulnérabilités autorisées à cette gravité. Un paquet est refusé lorsqu'il présente un nombre de vulnérabilités supérieur à ce nombre.

Un `threshold` de `0` n'en autorise aucune, ce qui refuse un paquet présentant même une seule vulnérabilité à cette gravité. Un `threshold` de `2` en autorise deux et refuse le troisième.

Les gravités sont `critical`, `high`, `medium` et `low`. Répertoriez chaque gravité au maximum une fois. Seul `denied` est pris en charge.

La règle suivante bloque tout paquet présentant une vulnérabilité critique, plus de deux vulnérabilités de gravité haute ou plus de dix vulnérabilités de gravité moyenne :

```yaml
rules:
  - type: risk_severity
    denied:
      - severity: critical
        threshold: 0
      - severity: high
        threshold: 2
      - severity: medium
        threshold: 10
```

Les vulnérabilités de gravité inconnue ne sont jamais comptabilisées.

#### Règles de paquets malveillants {#malicious-package-rules}

Les règles de paquets malveillants bloquent les paquets signalés par le flux de données de paquets malveillants de GitLab. Seul `denied` est pris en charge, et l'entrée unique doit être `is_malicious: true`.

```yaml
rules:
  - type: malicious
    denied:
      - is_malicious: true
```

### Exceptions de règles {#rule-exceptions}

Chaque règle prend en charge un tableau `exceptions` facultatif. Une entrée d'exception est soit une URL de paquet (PURL), soit un identifiant de vulnérabilité tel qu'un CVE. Une exception correspondante supprime le paquet ou la vulnérabilité de l'évaluation de cette règle.

Utilisez les exceptions PURL pour exempter les paquets internes d'une règle de licence ou de paquets malveillants. Le PURL peut inclure ou omettre une version. Lorsque la version est omise, l'exception s'applique à toutes les versions du paquet.

```yaml
rules:
  - type: license
    denied:
      - name: GNU General Public License v3.0 only
    exceptions:
      - purl: pkg:npm/my-internal-lib
      - purl: pkg:npm/another-lib@1.2.3
```

Utilisez les exceptions d'ID pour exempter des CVE spécifiques d'une règle de gravité du risque. Une vulnérabilité exemptée n'est pas comptabilisée dans le calcul des seuils.

```yaml
rules:
  - type: risk_severity
    denied:
      - severity: high
        threshold: 0
    exceptions:
      - id: CVE-2024-12345
```

### Paramètres de contournement {#bypass-settings}

Les paramètres de contournement permettent à des utilisateurs ou des jetons d'accès spécifiques d'ignorer une politique. Une requête effectuée par un utilisateur répertorié, ou avec un jeton d'accès répertorié, est autorisée et la raison du contournement est enregistrée.

```yaml
bypass_settings:
  users:
    - id: 1234
  access_tokens:
    - id: 5678
```

Pour trouver un ID d'utilisateur, consultez le profil de l'utilisateur et ajoutez `.json` à l'URL. Pour trouver un ID de jeton d'accès, consultez la liste des jetons d'accès du projet ou du groupe.

Utilisez les paramètres de contournement pour les comptes de service qui doivent installer des paquets internes, ou pour un accès d'urgence lors d'un incident.

### Portée de la politique {#policy-scope}

Par défaut, une politique de pare-feu de dépendances s'applique à chaque projet sur lequel elle est appliquée. Utilisez `policy_scope` pour restreindre cette portée à un ensemble spécifique de groupes ou de projets, ou pour exclure des projets d'un déploiement plus large.

`policy_scope` accepte deux clés, `groups` et `projects`. Chaque clé accepte une liste `including`, une liste `excluding`, ou les deux.

Dans tous les cas, chaque entrée est un objet avec un `id`.

| Champ                | Type  | Description |
|----------------------|-------|-------------|
| `groups.including`   | Tableau | Groupes auxquels la politique s'applique. |
| `groups.excluding`   | Tableau | Groupes auxquels la politique ne s'applique pas. |
| `projects.including` | Tableau | Projets auxquels la politique s'applique. |
| `projects.excluding` | Tableau | Projets auxquels la politique ne s'applique pas. Un `type` de `personal` ou `archived` exclut tous les projets personnels ou archivés. |

Par exemple, la portée suivante applique la politique à deux groupes, mais exclut un projet et tous les projets archivés dans ces groupes :

```yaml
policy_scope:
  groups:
    including:
      - id: 100
      - id: 101
  projects:
    excluding:
      - id: 555
      - type: archived
```

Lorsque `policy_scope` est omis, la politique s'applique à chaque projet dans la cible d'application du projet de politique de sécurité.

> [!note]
> Le paramètre `policy_scope` du pare-feu de dépendances prend uniquement en charge `groups` et `projects`. Les frameworks de conformité et les attributs de sécurité ne sont pas pris en charge.

### Exemple de politique {#example-policy}

La politique suivante :

- bloque les licences copyleft
- bloque les paquets présentant des vulnérabilités critiques
- ou plus de deux vulnérabilités de gravité haute
- bloque les paquets malveillants
- et exempte une bibliothèque interne et un CVE connu comme faux positif.

```yaml
---
dependency_firewall_policy:
  - name: Restrict copyleft licenses and high-risk packages
    description: Blocks copyleft-licensed packages, high-risk packages, and malicious packages.
    enabled: true
    enforcement_type: enforced
    rules:
      - type: license
        denied:
          - name: GNU General Public License v3.0 only
          - name: GNU Affero General Public License v3.0 only
        exceptions:
          - purl: pkg:npm/my-internal-lib
      - type: risk_severity
        denied:
          - severity: critical
            threshold: 0
          - severity: high
            threshold: 2
        exceptions:
          - id: CVE-2024-12345
      - type: malicious
        denied:
          - is_malicious: true
    bypass_settings:
      users:
        - id: 1234
    policy_scope:
      projects:
        excluding:
          - type: archived
```

## Modifier une politique de pare-feu de dépendances {#edit-a-dependency-firewall-policy}

Pour modifier une politique de pare-feu de dépendances :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre projet.
1. Sélectionnez **Sécurisation** > **Politiques**.
1. Dans la ligne de la politique, sélectionnez **Modifier**.
1. Modifiez la politique.
1. Sélectionnez **Configurer avec une requête de fusion**.
1. Examinez et fusionnez la merge request.

La politique mise à jour prend effet lors de la prochaine évaluation après la fusion de la merge request.

## Afficher l'activité du pare-feu de dépendances {#view-dependency-firewall-activity}

Le tableau de bord du pare-feu de dépendances affiche ce que le pare-feu a bloqué et averti, ainsi que les règles de politique actives.

Prérequis :

- Le pare-feu de dépendances doit être activé.
- Vous devez avoir la permission de lire les politiques de sécurité pour le groupe ou le projet.

Pour afficher le tableau de bord :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre groupe ou votre projet.
1. Sélectionnez **Sécuriser** > **Pare-feu de dépendances**.

Le tableau de bord comprend deux cartes récapitulatives et un tableau :

- **Toute l'activité** comptabilise les paquets bloqués, les paquets avertis et le nombre total de déclenchements sur la période sélectionnée.
- **Règles de politique actives** comptabilise les règles activées, réparties selon le nombre de blocages et d'avertissements.
- **Politiques** répertorie chaque règle active avec son nom de politique, son type de règle, son mode, son statut, son nombre de déclenchements, ainsi que la date et l'auteur de la dernière modification.

Sélectionnez **7 derniers jours** ou **30 derniers jours** pour modifier la période. La valeur par défaut correspond aux sept derniers jours.

### Événements d'audit {#audit-events}

Chaque évaluation produit également un événement d'audit limité au projet. Pour afficher les événements d'audit :

1. Dans la barre supérieure, sélectionnez **Rechercher ou accéder à**, puis recherchez votre projet.
1. Sélectionnez **Sécuriser** > **Événements d'audit**.

Les types d'événements d'audit suivants sont enregistrés :

| Type d'événement                    | Enregistré lorsque |
|-------------------------------|---------------|
| `dependency_firewall_allowed` | Le pare-feu autorise le paquet, notamment via un contournement ou une exception. |
| `dependency_firewall_warned`  | Une politique `warn` correspond au paquet. |
| `dependency_firewall_blocked` | Une politique `enforced` correspond au paquet. |

Chaque événement enregistre le paquet, l'opération, le nom de la politique et la règle qui a correspondu. Pour plus d'informations, consultez [Types d'événements d'audit](../../compliance/audit_event_types.md#dependency-firewall).
