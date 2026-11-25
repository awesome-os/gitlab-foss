---
stage: GitLab Delivery
group: Operate
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Mettre à niveau les instances de package Linux
description: Mettre à niveau une instance monoplateforme basée sur un package Linux.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

Les instructions pour mettre à niveau une instance de package Linux dépendent de si vous disposez d'une instance GitLab à nœud unique ou à plusieurs nœuds. Pour mettre à niveau une instance GitLab avec package Linux à plusieurs nœuds, consultez :

- [Mettre à niveau une instance multi-nœuds avec temps d'arrêt](../with_downtime.md).
- [Mettre à niveau une instance multi-nœuds sans temps d'arrêt](../zero_downtime.md).

Pour mettre à niveau une instance GitLab avec package Linux à nœud unique, suivez les informations de cette page.

> [!note]
> Si vous hébergez la documentation du produit, vous pouvez également [la mettre à niveau vers une version ultérieure](../../administration/docs_self_host.md#upgrade-the-product-documentation-to-a-later-version).

## Prérequis {#prerequisites}

Avant de mettre à niveau une instance GitLab avec package Linux à nœud unique :

- Vous devez [lire les informations requises et effectuer les étapes requises](../plan_your_upgrade.md).
- Si nécessaire, mettez à niveau vers un [système d'exploitation pris en charge](../../install/package/_index.md).
- Lors de la mise à niveau du système d'exploitation, si votre version de `glibc` change, vous devez suivre la procédure de [mise à niveau des systèmes d'exploitation pour PostgreSQL](../../administration/postgresql/upgrading_os.md) afin d'éviter la corruption des index.
- Assurez-vous que PostgreSQL, Redis et Gitaly sont en cours d'exécution.

La base de données GitLab est sauvegardée avant l'installation d'une nouvelle version de GitLab. Vous pouvez ignorer cette sauvegarde automatique de la base de données en créant un fichier vide à l'emplacement `/etc/gitlab/skip-auto-backup` :

```shell
sudo touch /etc/gitlab/skip-auto-backup
```

Néanmoins, vous devez maintenir une [sauvegarde](../../administration/backup_restore/_index.md) complète et à jour par vos propres moyens.

## Mettre à niveau une instance de package Linux à nœud unique {#upgrade-a-single-node-linux-package-instance}

Pour mettre à niveau une instance de package Linux à nœud unique :

1. Envisagez d'[activer le mode de maintenance](../../administration/maintenance_mode/_index.md) pendant la mise à niveau.
1. Mettez en pause les [pipelines CI/CD et les jobs en cours d'exécution](../plan_your_upgrade.md#pause-cicd-pipelines-and-jobs).
1. [Mettez à niveau GitLab Runner](https://docs.gitlab.com/runner/install/) vers la même version que votre version GitLab cible.
1. [Mettez à niveau GitLab avec le package Linux](#upgrade-with-the-linux-package).

Après la mise à niveau :

1. Réactivez les [pipelines CI/CD et les jobs en cours d'exécution](../plan_your_upgrade.md#pause-cicd-pipelines-and-jobs).
1. Si activé, [désactivez le mode de maintenance](../../administration/maintenance_mode/_index.md#disable-maintenance-mode).
1. Exécutez les [vérifications de l'état de la mise à niveau](../plan_your_upgrade.md#run-upgrade-health-checks).

## Mise à niveau avec le package Linux {#upgrade-with-the-linux-package}

Pour mettre à niveau GitLab s'exécutant sur un nœud unique, ou mettre à niveau un nœud faisant partie d'une instance GitLab multi-nœuds, effectuez la mise à niveau en utilisant l'une des méthodes suivantes :

- [Utilisation des dépôts officiels](#upgrade-with-the-official-repositories-recommended).
- [Utilisation d'un package téléchargé](#upgrade-with-a-downloaded-package).

### Mise à niveau avec les dépôts officiels (recommandé) {#upgrade-with-the-official-repositories-recommended}

Tous les packages GitLab sont publiés sur le [serveur de packages](https://packages.gitlab.com/ui/browse/gitlab) GitLab.

| Dépôt                                                                                       | Description |
|:-------------------------------------------------------------------------------------------------|:------------|
| [`gitlab/gitlab-ce`](https://packages.gitlab.com/ui/browse/gitlab/gitlab-ce)                     | Package allégé qui contient uniquement les fonctionnalités de la Community Edition. |
| [`gitlab/gitlab-ee`](https://packages.gitlab.com/ui/browse/gitlab/gitlab-ee)                     | Package GitLab complet qui contient toutes les fonctionnalités de la Community Edition et de l'Enterprise Edition. |
| [`gitlab/nightly-builds`](https://packages.gitlab.com/ui/browse/gitlab/nightly-builds)           | Builds nocturnes. |
| [`gitlab/nightly-fips-builds`](https://packages.gitlab.com/ui/browse/gitlab/nightly-fips-builds) | Builds nocturnes conformes aux exigences FIPS. |
| [`gitlab/gitlab-fips`](https://packages.gitlab.com/ui/browse/gitlab/gitlab-fips)                 | Builds conformes aux exigences FIPS. |

Par défaut, les gestionnaires de packages des distributions Linux installent la dernière version disponible d'un package. Vous ne pouvez pas effectuer une mise à niveau directement vers la dernière version majeure de GitLab si votre [chemin de mise à niveau](../upgrade_paths.md) nécessite plusieurs étapes intermédiaires. Si votre chemin de mise à niveau inclut plusieurs versions, vous devez spécifier la version exacte du package GitLab à chaque mise à niveau.

Si votre chemin de mise à niveau ne comporte aucune étape intermédiaire, vous pouvez effectuer une mise à niveau directement vers la dernière version.

{{< tabs >}}

{{< tab title="Ubuntu/Debian" >}}

```shell
# GitLab Enterprise Edition (specific version)
sudo apt update && sudo apt install gitlab-ee=<version>-ee.0

# GitLab Community Edition (specific version)
sudo apt update && sudo apt install gitlab-ce=<version>-ce.0

# GitLab Enterprise Edition (latest version)
sudo apt update && sudo apt install gitlab-ee

# GitLab Community Edition (latest version)
sudo apt update && sudo apt install gitlab-ce
```

{{< /tab >}}

{{< tab title="Amazon Linux 2" >}}

```shell
# GitLab Enterprise Edition (specific version)
sudo yum install gitlab-ee-<version>-ee.0.amazon2

# GitLab Community Edition (specific version)
sudo yum install gitlab-ce-<version>-ce.0.amazon2

# GitLab Enterprise Edition (latest version)
sudo yum install gitlab-ee

# GitLab Community Edition (latest version)
sudo yum install gitlab-ce
```

{{< /tab >}}

{{< tab title="RHEL/Oracle Linux/AlmaLinux 8/9" >}}

```shell
# GitLab Enterprise Edition (specific version)
sudo dnf install gitlab-ee-<version>-ee.0.el9

# GitLab Enterprise Edition (specific version)
sudo dnf install gitlab-ee-<version>-ee.0.el8

# GitLab Community Edition (specific version)
sudo dnf install gitlab-ce-<version>-ce.0.el9

# GitLab Community Edition (specific version)
sudo dnf install gitlab-ce-<version>-ce.0.el8

# GitLab Enterprise Edition (latest version)
sudo dnf upgrade gitlab-ee

# GitLab Community Edition (latest version)
sudo dnf upgrade gitlab-ce
```

{{< /tab >}}

{{< tab title="Amazon Linux 2023" >}}

```shell
# GitLab Enterprise Edition (specific version)
sudo dnf install gitlab-ee-<version>-ee.0.amazon2023

# GitLab Community Edition (specific version)
sudo dnf install gitlab-ce-<version>-ce.0.amazon2023

# GitLab Enterprise Edition (latest version)
sudo dnf upgrade gitlab-ee

# GitLab Community Edition (latest version)
sudo dnf upgrade gitlab-ce
```

{{< /tab >}}

{{< tab title="OpenSUSE Leap 15.5" >}}

```shell
# GitLab Enterprise Edition (specific version)
sudo zypper install gitlab-ee=<version>-ee.sles15

# GitLab Community Edition (specific version)
sudo zypper install gitlab-ce=<version>-ce.sles15

# GitLab Enterprise Edition (latest version)
sudo zypper install gitlab-ee

# GitLab Community Edition (latest version)
sudo zypper install gitlab-ce
```

{{< /tab >}}

{{< tab title="SUSE Enterprise Server 12.2/12.5" >}}

```shell
# GitLab Enterprise Edition (specific version)
sudo zypper install gitlab-ee=<version>-ee.0.sles12

# GitLab Community Edition (specific version)
sudo zypper install gitlab-ce=<version>-ce.0.sles12

# GitLab Enterprise Edition (latest version)
sudo zypper install gitlab-ee

# GitLab Community Edition (latest version)
sudo zypper install gitlab-ce
```

{{< /tab >}}

{{< /tabs >}}

### Pré-télécharger un package depuis le dépôt officiel {#pre-download-a-package-from-the-official-repository}

Pour réduire le temps d'installation lors des mises à niveau ou vérifier qu'un package est accessible, vous pouvez le télécharger depuis le dépôt officiel et l'installer ultérieurement :

{{< tabs >}}

{{< tab title="Ubuntu/Debian" >}}

```shell
# GitLab Enterprise Edition
sudo apt-get install --download-only gitlab-ee=<version>-ee.0
sudo apt-get install /var/cache/apt/archives/gitlab-ee_<version>-ee.0_amd64.deb

# GitLab Community Edition
sudo apt-get install --download-only gitlab-ce=<version>-ce.0
sudo apt-get install /var/cache/apt/archives/gitlab-ce_<version>-ce.0_amd64.deb
```

{{< /tab >}}

{{< tab title="Amazon Linux 2" >}}

```shell
# GitLab Enterprise Edition
sudo yumdownloader gitlab-ee-<version>-ee.0.amazon2
sudo yum install ./gitlab-ee-<version>-ee.0.amazon2.x86_64.rpm

# GitLab Community Edition
sudo yumdownloader gitlab-ce-<version>-ce.0.amazon2
sudo yum install ./gitlab-ce-<version>-ce.0.amazon2.x86_64.rpm
```

{{< /tab >}}

{{< tab title="RHEL/Oracle Linux/AlmaLinux 8/9" >}}

```shell
# GitLab Enterprise Edition (el9)
sudo dnf download gitlab-ee-<version>-ee.0.el9
sudo dnf install ./gitlab-ee-<version>-ee.0.el9.x86_64.rpm

# GitLab Enterprise Edition (el8)
sudo dnf download gitlab-ee-<version>-ee.0.el8
sudo dnf install ./gitlab-ee-<version>-ee.0.el8.x86_64.rpm

# GitLab Community Edition (el9)
sudo dnf download gitlab-ce-<version>-ce.0.el9
sudo dnf install ./gitlab-ce-<version>-ce.0.el9.x86_64.rpm

# GitLab Community Edition (el8)
sudo dnf download gitlab-ce-<version>-ce.0.el8
sudo dnf install ./gitlab-ce-<version>-ce.0.el8.x86_64.rpm
```

{{< /tab >}}

{{< tab title="Amazon Linux 2023" >}}

```shell
# GitLab Enterprise Edition
sudo dnf download gitlab-ee-<version>-ee.0.amazon2023
sudo dnf install ./gitlab-ee-<version>-ee.0.amazon2023.x86_64.rpm

# GitLab Community Edition
sudo dnf download gitlab-ce-<version>-ce.0.amazon2023
sudo dnf install ./gitlab-ce-<version>-ce.0.amazon2023.x86_64.rpm
```

{{< /tab >}}

{{< tab title="OpenSUSE Leap 15.5" >}}

```shell
# GitLab Enterprise Edition
sudo zypper install --download-only gitlab-ee-<version>-ee.0.sles15.x86_64
sudo zypper install /var/cache/zypp/packages/gitlab_gitlab-ee/Packages/g/gitlab-ee-<version>-ee.sles15.x86_64.rpm

# GitLab Community Edition
sudo zypper install --download-only gitlab-ce-<version>-ce.0.sles15.x86_64
sudo zypper install /var/cache/zypp/packages/gitlab_gitlab-ce/Packages/g/gitlab-ce-<version>-ce.sles15.x86_64.rpm
```

{{< /tab >}}

{{< tab title="SUSE Enterprise Server 12.2/12.5" >}}

```shell
# GitLab Enterprise Edition
sudo zypper install --download-only gitlab-ee-<version>-ee.0.sles12.x86_64
sudo zypper install /var/cache/zypp/packages/gitlab_gitlab-ee/Packages/g/gitlab-ee-<version>-ee.0.sles12.x86_64.rpm

# GitLab Community Edition
sudo zypper install --download-only gitlab-ce-<version>-ce.0.sles12.x86_64
sudo zypper install /var/cache/zypp/packages/gitlab_gitlab-ce/Packages/g/gitlab-ce-<version>-ce.0.sles12.x86_64.rpm
```

{{< /tab >}}

{{< /tabs >}}

### Mise à niveau avec un package téléchargé {#upgrade-with-a-downloaded-package}

Si vous ne souhaitez pas utiliser les dépôts officiels, vous pouvez télécharger le package et l'installer manuellement. Cette méthode peut être utilisée pour installer GitLab pour la première fois ou pour le mettre à niveau.

Pour télécharger et installer ou mettre à niveau GitLab :

1. Accédez au [dépôt officiel](#upgrade-with-the-official-repositories-recommended) de votre package.
1. Filtrez la liste en recherchant la version que vous souhaitez installer. Par exemple, `18.4.1`. Plusieurs packages peuvent exister pour une même version, un pour chaque distribution et architecture prise en charge. Étant donné que certains fichiers sont pertinents pour plusieurs distributions, un label apparaît à côté du nom de fichier pour indiquer la distribution concernée.
1. Trouvez la version du package que vous souhaitez installer et sélectionnez le nom du fichier dans la liste.
1. Dans le coin supérieur droit, sélectionnez **Téléchargement**.
1. Une fois le package téléchargé, installez-le en utilisant l'une des commandes suivantes et en remplaçant `<package_name>` par le nom du package téléchargé :

   {{< tabs >}}

   {{< tab title="Ubuntu/Debian" >}}

   ```shell
   dpkg -i <package_name>
   ```

   {{< /tab >}}

   {{< tab title="Amazon Linux 2" >}}

   ```shell
   rpm -Uvh <package_name>
   ```

   {{< /tab >}}

   {{< tab title="RHEL/Oracle Linux/AlmaLinux 8/9 et Amazon Linux 2023" >}}

   ```shell
   dnf install <package_name>
   ```

   {{< /tab >}}

   {{< tab title="SUSE et OpenSUSE" >}}

   ```shell
   zypper install <package_name>
   ```

   {{< /tab >}}

   {{< /tabs >}}
