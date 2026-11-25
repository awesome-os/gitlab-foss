---
stage: none
group: Documentation Guidelines
info: For assistance with this Style Guide page, see <https://handbook.gitlab.com/handbook/marketing/product-and-technical-marketing/technical-writing/#assignments-to-other-projects-and-subjects>.
description: Learn how documentation review apps work.
title: Documentation review apps
---

GitLab team members can deploy a [review app](../../ci/review_apps/_index.md) for merge requests with documentation
changes. The review app lets you preview how your changes appear on the [GitLab Docs site](https://docs.gitlab.com) before merging.

Review app deployments are available for these projects:

| Project                                                                          | Configuration file |
|:---------------------------------------------------------------------------------|:-------------------|
| [GitLab](https://gitlab.com/gitlab-org/gitlab)                                   | [`.gitlab/ci/includes/review-docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/.gitlab/ci/includes/review-docs.gitlab-ci.yml) |
| [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab)                   | [`gitlab-ci-config/review-docs.yml`](https://gitlab.com/gitlab-org/omnibus-gitlab/-/blob/master/gitlab-ci-config/review-docs.yml) |
| [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-runner)                     | [`.gitlab/ci/docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/gitlab-runner/-/blob/main/.gitlab/ci/docs.gitlab-ci.yml) |
| [GitLab Charts](https://gitlab.com/gitlab-org/charts/gitlab)                     | [`.gitlab/ci/review-docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/charts/gitlab/-/blob/master/.gitlab/ci/review-docs.gitlab-ci.yml) |
| [GitLab Operator](https://gitlab.com/gitlab-org/cloud-native/gitlab-operator)    | [`.gitlab/ci/includes/review-docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/cloud-native/gitlab-operator/-/blob/master/.gitlab/ci/includes/review-docs.gitlab-ci.yml) |
| [GitLab CLI (glab)](https://gitlab.com/gitlab-org/cli)                           | [`.gitlab/ci/review-docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/cli/-/blob/main/.gitlab/ci/review-docs.gitlab-ci.yml) |
| [Artifact Registry](https://gitlab.com/gitlab-org/ops/artifact-registry)         | [`.gitlab/ci/review-docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/ops/artifact-registry/-/blob/main/.gitlab/ci/review-docs.gitlab-ci.yml) |
| [Orbit](https://gitlab.com/gitlab-org/orbit/knowledge-graph)                     | [`.gitlab/ci/review-docs.yml`](https://gitlab.com/gitlab-org/orbit/knowledge-graph/-/blob/main/.gitlab/ci/review-docs.yml) |
| [Patch release notes](https://gitlab.com/gitlab-org/release/patch-release-blogs) | [`.gitlab/ci/review-docs.gitlab-ci.yml`](https://gitlab.com/gitlab-org/release/patch-release-blogs/-/blob/main/.gitlab/ci/review-docs.gitlab-ci.yml) |

## Deploy a review app

You can deploy a review app by manually triggering the deploy job in your merge request.
The deploy and cleanup job names depend on the project:

- Artifact Registry: `docs:review-deploy` and `docs:review-cleanup`
- Patch release notes: `docs:review:deploy` and `docs:review:cleanup`
- All other projects: `review-docs-deploy` and `review-docs-cleanup`

The deploy job creates a preview of your documentation changes using the Hugo static site generation from
the [`docs-gitlab-com`](https://gitlab.com/gitlab-org/technical-writing/docs-gitlab-com) project.

Prerequisites:

- You must have the Developer role for the project.

External contributors cannot run this job. If you're an external contributor,
ask a GitLab team member to run it for you.

To deploy a review app:

1. From your merge request, [manually run](../../ci/jobs/job_control.md#run-a-manual-job) the deploy job.
   This job triggers a [multi-project pipeline](../../ci/pipelines/downstream_pipelines.md#multi-project-pipelines)
   that builds and deploys the documentation site with your changes.
1. When the pipeline finishes, select **View app** to open the review app in your browser.

The cleanup job is triggered automatically on merge. This job deletes
the review app.

## How documentation review apps work

Documentation review apps follow this process:

1. You manually run the deploy job in a merge request.
1. The job downloads (if outside of `gitlab` project) and runs the
   [`scripts/trigger-build.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/scripts/trigger-build.rb) script with
   the `docs deploy` flag, which triggers a pipeline in the `gitlab-org/technical-writing/docs-gitlab-com`
   project.

   The `DOCS_BRANCH` environment variable determines which branch of the
   `gitlab-org/technical-writing/docs-gitlab-com` project to use. If not set, the `main` branch is used.
1. After the documentation preview site is built, it is [deployed in parallel to other review apps](../../user/project/pages/_index.md#parallel-deployments).

## Troubleshooting

When working with review apps, you might encounter the following issues.

### Error: `401 Unauthorized` in documentation review app deployment jobs

You might get an error in a review app deployment job that states:

```plaintext
Server responded with code 401, message: 401 Unauthorized.
```

This issue occurs when the `DOCS_PROJECT_API_TOKEN` has either expired or been revoked and must be
[regenerated](https://gitlab.com/gitlab-org/technical-writing/docs-gitlab-com/-/blob/main/doc/maintenance.md?ref_type=heads#review-app-tokens).

These conditions result in the deployment job for the documentation review app being unable to query the downstream project for
the status of the downstream pipeline.

To resolve this issue, contact the [Technical Writing team](https://handbook.gitlab.com/handbook/marketing/product-and-technical-marketing/technical-writing/#contact-us).
For more information on documentation review app tokens,
see [GitLab docs site maintenance](https://gitlab.com/gitlab-org/technical-writing/docs-gitlab-com/-/blob/main/doc/maintenance.md).
