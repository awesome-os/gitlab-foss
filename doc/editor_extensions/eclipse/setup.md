---
stage: AI Clients
group: Developer Clients
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/marketing/product-and-technical-marketing/technical-writing/#assignments>
description: Connect and use GitLab Duo in Eclipse.
title: Install and set up GitLab for Eclipse
---

{{< details >}}

- Tier: [Free](../../subscriptions/gitlab_credits.md#for-the-free-tier), Premium, Ultimate
- Offering: GitLab.com, GitLab Self-Managed, GitLab Dedicated
- Status: Beta

{{< /details >}}

{{< history >}}

- [Changed](https://gitlab.com/gitlab-org/editor-extensions/gitlab-eclipse-plugin/-/issues/163) from experiment to beta in GitLab 17.11.
- Access to GitLab Duo Non-Agentic Chat removed for GitLab Duo Core customers on May 21, 2026 as part of GitLab 19.0, with a feature flag named `no_duo_classic_for_duo_core_users`. Enabled by default.

{{< /history >}}

> [!disclaimer]

## Install the GitLab for Eclipse plugin

Prerequisites:

- Eclipse 4.33 and later.
- GitLab version 16.8 or later.

To install GitLab for Eclipse:

1. Open your Eclipse IDE and your preferred web browser.
1. In your web browser, go to the page for the
   [GitLab for Eclipse plugin](https://marketplace.eclipse.org/content/gitlab-eclipse) in the Eclipse Marketplace.
1. On the plugin's page, select {{< external-ui text="Install" >}}, and drag your mouse over to your Eclipse IDE.
1. In the {{< external-ui text="Eclipse Marketplace" >}} window, select the {{< external-ui text="GitLab For Eclipse" >}} category.
1. Select {{< external-ui text="Confirm >" >}}, then select {{< external-ui text="Finish" >}}.
1. If the {{< external-ui text="Trust Authorities" >}} window appears, select the **`https://gitlab.com`** update site and select {{< external-ui text="Trust Selected" >}}.
1. Select {{< external-ui text="Restart Now" >}}.

If the Eclipse Marketplace is unavailable, follow the
[Eclipse installation instructions](https://help.eclipse.org/latest/index.jsp?topic=%2Forg.eclipse.platform.doc.user%2Ftasks%2Ftasks-124.htm)
for adding a new software site. For {{< external-ui text="Work with" >}}, use
`https://gitlab.com/gitlab-org/editor-extensions/gitlab-eclipse-plugin/-/releases/permalink/latest/downloads/`.

## Authenticate with GitLab

After you install the plugin, authenticate and connect it to your GitLab account.

Prerequisites:

- A [personal access token](../../user/profile/personal_access_tokens.md#create-a-personal-access-token) with the `api` scope.

To authenticate with GitLab:

1. In your IDE, open preferences:
   - For macOS, select {{< external-ui text="Eclipse" >}} > {{< external-ui text="Settings" >}}.
   - For Windows or Linux, select {{< external-ui text="Window" >}} > {{< external-ui text="Preferences" >}}.
1. In the left sidebar, select {{< external-ui text="GitLab Duo" >}}.
1. Under {{< external-ui text="Connection" >}}, enter the URL for your GitLab instance. For GitLab.com,
   use `https://gitlab.com`.
1. Under {{< external-ui text="Authentication" >}}, enter your personal access token.
   Your token is hidden and stored using Eclipse secure storage.
1. Select {{< external-ui text="Verify Setup" >}}.
1. Select {{< external-ui text="Apply and Close" >}}.

## Configure Code Suggestions

Prerequisites:

- You meet the [prerequisites](../../user/project/repository/code_suggestions/set_up.md#prerequisites) for Code Suggestions.
- You open an Eclipse project instead of a single file.

Code Suggestions is on by default. To verify:

1. In Eclipse, open your GitLab project.
1. In the Eclipse bottom toolbar, select the GitLab icon.
1. Check the status of {{< external-ui text="Code Suggestions" >}}.

To turn off Code Suggestions for a project:

1. In the Eclipse bottom toolbar, select the GitLab icon.
1. Select {{< external-ui text="Disable Code Suggestions" >}}.

To turn off Code Suggestions for a specific language:

1. In the Eclipse bottom toolbar, select the GitLab icon.
1. Select {{< external-ui text="Show Settings" >}}.
1. Under {{< external-ui text="Code Suggestions Enabled Languages" >}}, clear the checkbox for the language you want to turn off.

You can also [add support for more languages](../../user/project/repository/code_suggestions/supported_extensions.md#add-support-for-more-languages).
