---
stage: Verify
group: Pipeline Execution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Mock CI
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

> [!note]
> Cette intégration est uniquement disponible dans un environnement de développement.

Pour configurer le serveur de service Mock CI, répondez aux endpoints suivants :

- `commit_status` : `#{project.namespace.path}/#{project.path}/status/#{sha}.json`
  - Faites en sorte que votre service renvoie `200 { status: ['failed'|'canceled'|'running'|'pending'|'success'|'success-with-warnings'|'skipped'|'not_found'] }`.
  - Si le service renvoie une erreur 404, il est interprété comme `pending`.
- `build_page` : `#{project.namespace.path}/#{project.path}/status/#{sha}`
  - Emplacement vers lequel le build est lié (qu'il soit implémenté ou non).

Pour un exemple de serveur Mock CI, consultez [`gitlab-org/gitlab-mock-ci-service`](https://gitlab.com/gitlab-org/gitlab-mock-ci-service).
