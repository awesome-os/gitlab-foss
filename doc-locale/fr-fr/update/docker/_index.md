---
stage: GitLab Delivery
group: Operate
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Mettre à niveau des instances Docker
description: Mettre à niveau une instance Docker à nœud unique.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

Mettez à niveau une instance Docker vers une version ultérieure de GitLab.

## Prérequis {#prerequisites}

Avant de mettre à niveau une instance Docker, vous devez d'abord [lire les informations requises et effectuer les étapes nécessaires](../plan_your_upgrade.md).

## Mettre à niveau une instance Docker {#upgrade-a-docker-based-instance}

Pour mettre à niveau une instance Docker :

1. Envisagez d'[activer le mode maintenance](../../administration/maintenance_mode/_index.md) pendant la mise à niveau.
1. Mettez en pause les [pipelines CI/CD et jobs en cours d'exécution](../plan_your_upgrade.md#pause-cicd-pipelines-and-jobs).
1. [Mettez à niveau GitLab Runner](https://docs.gitlab.com/runner/install/) vers la même version que votre version cible de GitLab.
1. Mettez à niveau GitLab lui-même en utilisant l'une des méthodes suivantes :
   - [Avec Docker Engine](#upgrade-with-docker-engine).
   - [Avec Docker Compose](#upgrade-with-docker-compose).

Après la mise à niveau :

1. Réactivez les [pipelines CI/CD et jobs en cours d'exécution](../plan_your_upgrade.md#pause-cicd-pipelines-and-jobs).
1. Si activé, [désactivez le mode maintenance](../../administration/maintenance_mode/_index.md#disable-maintenance-mode).
1. Exécutez les [vérifications d'intégrité de la mise à niveau](../plan_your_upgrade.md#run-upgrade-health-checks).

### Mise à niveau avec Docker Engine {#upgrade-with-docker-engine}

Pour mettre à niveau une instance GitLab qui a été [installée avec Docker Engine](../../install/docker/installation.md#install-gitlab-by-using-docker-engine) :

1. Créez une [sauvegarde](../../install/docker/backup.md). Au minimum, sauvegardez [la base de données](../../install/docker/backup.md#create-a-database-backup) et le fichier de secrets GitLab.
1. Arrêtez le conteneur en cours d'exécution :

   ```shell
   sudo docker stop gitlab
   ```

1. Supprimez le conteneur existant :

   ```shell
   sudo docker rm gitlab
   ```

1. Extrayez la nouvelle image :

   {{< tabs >}}

   {{< tab title="GitLab Enterprise Edition" >}}

   ```shell
   sudo docker pull gitlab/gitlab-ee:<version>-ee.0
   ```

   {{< /tab >}}

   {{< tab title="GitLab Community Edition" >}}

   ```shell
   sudo docker pull gitlab/gitlab-ce:<version>-ce.0
   ```

   {{< /tab >}}

   {{< /tabs >}}

1. Assurez-vous que la variable d'environnement `GITLAB_HOME` est [définie](../../install/docker/installation.md#create-a-directory-for-the-volumes) :

   ```shell
   echo $GITLAB_HOME
   ```

1. Recréez le conteneur avec les options [précédemment spécifiées](../../install/docker/installation.md#install-gitlab-by-using-docker-engine) :

   ```shell
   sudo docker run --detach \
   --hostname gitlab.example.com \
   --publish 443:443 --publish 80:80 --publish 22:22 \
   --name gitlab \
   --restart always \
   --volume $GITLAB_HOME/config:/etc/gitlab \
   --volume $GITLAB_HOME/logs:/var/log/gitlab \
   --volume $GITLAB_HOME/data:/var/opt/gitlab \
   --shm-size 256m \
   gitlab/gitlab-ee:<version>-ee.0
   ```

Au premier démarrage, GitLab se reconfigure et se met à niveau automatiquement.

### Mise à niveau avec Docker Compose {#upgrade-with-docker-compose}

Pour mettre à niveau une instance GitLab qui a été [installée avec Docker Compose](../../install/docker/installation.md#install-gitlab-by-using-docker-compose) :

1. Créez une [sauvegarde](../../install/docker/backup.md). Au minimum, sauvegardez [la base de données](../../install/docker/backup.md#create-a-database-backup) et le fichier de secrets GitLab.
1. Modifiez `docker-compose.yml` et changez la version à extraire.
1. Téléchargez la dernière release et mettez à niveau votre instance GitLab :

   ```shell
   docker compose pull
   docker compose up -d
   ```
