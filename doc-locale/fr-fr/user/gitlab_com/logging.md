---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Logs sur GitLab.com
description: Comment GitLab.com crée des logs et comment effacer les job logs.
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com

{{< /details >}}

Informations sur les logs de GitLab.com.

## Comment GitLab.com crée des logs {#how-gitlabcom-creates-logs}

[Fluentd](https://gitlab.com/gitlab-com/runbooks/tree/master/logging/doc#fluentd) analyse les logs GitLab, puis les envoie à :

- [Stackdriver Logging](https://gitlab.com/gitlab-com/runbooks/tree/master/logging/doc#stackdriver), qui stocke les logs à long terme dans Google Cold Storage (GCS).
- [Cloud Pub/Sub](https://gitlab.com/gitlab-com/runbooks/tree/master/logging/doc#cloud-pubsub), qui transfère les logs vers un [cluster Elastic](https://gitlab.com/gitlab-com/runbooks/tree/master/logging/doc#elastic) à l'aide de [`pubsubbeat`](https://gitlab.com/gitlab-com/runbooks/tree/master/logging/doc#pubsubbeat-vms).

Pour plus d'informations, consultez les runbooks GitLab pour :

- Une [liste détaillée de ce qui est enregistré dans les logs](https://gitlab.com/gitlab-com/runbooks/-/tree/master/docs/logging#what-are-we-logging).
- Les [politiques de rétention des logs](https://gitlab.com/gitlab-com/runbooks/-/tree/master/docs/logging#retention) actuelles.
- Un [schéma de l'infrastructure de logging GitLab](https://gitlab.com/gitlab-com/runbooks/-/tree/master/docs/logging#logging-infrastructure-overview).

## Effacer les job logs CI/CD {#erase-cicd-job-logs}

Par défaut, GitLab ne fait pas expirer les job logs CI/CD. Les job logs sont conservés indéfiniment et ne peuvent pas être configurés pour expirer sur GitLab.com. Vous pouvez effacer les job logs de l'une des manières suivantes :

- [Utilisation de l'API Jobs](../../api/jobs.md#erase-a-job).
- [Suppression du pipeline](../../ci/pipelines/_index.md#delete-a-pipeline) auquel appartient le job.
