---
stage: Enablement
group: Infrastructure
info: Any user with at least the Maintainer role can merge updates to this content. For details, see <https://docs.gitlab.com/development/development_processes/#development-guidelines-review>.
title: Feature Categorization
---

Each Sidekiq worker, Batched Background migrations, controller action, [test example](../testing_guide/best_practices.md#feature-category-metadata) or API endpoint
must declare a `feature_category` attribute. This attribute maps each
of these to a [feature category](https://handbook.gitlab.com/handbook/product/categories/). This
is done for error budgeting, alert routing, and team attribution.

The list of feature categories can be found in the file `config/feature_categories.yml`.
This file is generated from the
[`stages.yml`](https://gitlab.com/gitlab-com/www-gitlab-com/blob/master/data/stages.yml)
data file used in the GitLab Handbook and other GitLab resources.

## Updating `config/feature_categories.yml`

Occasionally new features will be added to GitLab stages, groups, and
product categories. When this occurs, you can automatically update
`config/feature_categories.yml` by running
`scripts/update-feature-categories`. This script will fetch and parse
[`stages.yml`](https://gitlab.com/gitlab-com/www-gitlab-com/blob/master/data/stages.yml)
and generate a new version of the file, which needs to be committed to
the repository.

The [Observability](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/production-engineering/observability/) team
currently maintains the `feature_categories.yml` file. They will automatically be
notified on Slack when the file becomes outdated.

## Gemfile

For each Ruby gem dependency we should specify which feature category requires
this dependency. This should clarify ownership and we can delegate upgrading
to the respective group owning the feature.

### Tooling feature category

For Developer Experience internal tooling we use `feature_category: :tooling`.
For example, `knapsack` and `gitlab-crystalball` are both used to run RSpec test
suites in CI and they don't belong to any product groups.

### Test platform feature category

Gems that relate to end-to-end test infrastructure are maintained by the [Development Experience](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/developer-experience/) section. We use the `feature_category: :test_platform` label.
For example, `capybara` is defined in both `Gemfile` and `qa/Gemfile` to run tests involving UI. They don't belong to a specific product group.

### Rails platform feature category

Rails core framework gems are primarily maintained by
Backend Maintainers.
For example, `rails`, and `zeitwerk` should be defined as `:rails_platform`.

### Shared feature category

> [!warning]
> The `:shared` feature category is no longer supported for gems.

As part of efforts to provide good maintenance of gems, all gems must
use a specific feature category.
If you are uncertain about the ownership of a gem, please reach out to the
[`#backend_maintainers`](https://app.slack.com/client/E03N1RJJX7C/CJHPLRTRD) channel for help.

## Sidekiq workers

The declaration uses the `feature_category` class method, as shown below.

```ruby
class SomeScheduledTaskWorker
  include ApplicationWorker

  # Declares that this worker is part of the
  # `continuous_integration` feature category
  feature_category :continuous_integration

  # ...
end
```

The feature categories specified using `feature_category` should be
defined in
[`config/feature_categories.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/feature_categories.yml). If
not, the specs will fail.

### Excluding Sidekiq workers from feature categorization

A few Sidekiq workers, that are used across all features, cannot be mapped to a
single category. These should be declared as such using the
`feature_category :not_owned`
declaration, as shown below:

```ruby
class SomeCrossCuttingConcernWorker
  include ApplicationWorker

  # Declares that this worker does not map to a feature category
  feature_category :not_owned # rubocop:disable Gitlab/AvoidFeatureCategoryNotOwned

  # ...
end
```

When possible, workers marked as "not owned" use their caller's
category (worker or HTTP endpoint) in metrics and logs.
For instance, `ReactiveCachingWorker` can have multiple feature
categories in metrics and logs.

## Batched background migrations

Long-running migrations (as per the [time limits guidelines](../migration_style_guide.md#how-long-a-migration-should-take))
are pulled out as [batched background migrations](../database/batched_background_migrations.md).
They should define a `feature_category`, like this:

```ruby
# Filename: lib/gitlab/background_migration/my_background_migration_job.rb

class MyBackgroundMigrationJob < BatchedMigrationJob
  feature_category :gitaly

  #...
end
```

> [!note]
> [`RuboCop::Cop::BackgroundMigration::FeatureCategory`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/rubocop/cop/background_migration/feature_category.rb) cop ensures a valid `feature_category` is defined.

## Rails controllers

Specifying feature categories on controller actions can be done using
the `feature_category` class method.

A feature category can be specified on an entire controller
using:

```ruby
class Boards::ListsController < ApplicationController
  feature_category :kanban_boards
end
```

The feature category can be limited to a list of actions using the
second argument:

```ruby
class DashboardController < ApplicationController
  feature_category :team_planning, [:issues, :issues_calendar]
  feature_category :code_review_workflow, [:merge_requests]
end
```

These forms cannot be mixed: if a controller has more than one category,
every single action must be listed.

### Excluding controller actions from feature categorization

In the rare case an action cannot be tied to a feature category this
can be done using the `not_owned` feature category.

```ruby
class Admin::LogsController < ApplicationController
  feature_category :not_owned
end
```

### Ensuring feature categories are valid

The `spec/controllers/every_controller_spec.rb` will iterate over all
defined routes, and check the controller to see if a category is
assigned to all actions.

The spec also validates if the used feature categories are known, and if
the actions used in configuration still exist as routes.

## API endpoints

For the [GraphQL API](../../api/graphql/_index.md), see [GraphQL types and fields](#graphql-types-and-fields).

Grape API endpoints can use the `feature_category` class method, like
[Rails controllers](#rails-controllers) do:

```ruby
module API
  class Issues < ::API::Base
    feature_category :team_planning
  end
end
```

The second argument can be used to specify feature categories for
specific routes:

```ruby
module API
  class Users < ::API::Base
    feature_category :user_profile, ['/users/:id/custom_attributes', '/users/:id/custom_attributes/:key']
  end
end
```

Or the feature category can be specified in the action itself:

```ruby
module API
  class Users < ::API::Base
    get ':id', feature_category: :user_profile do
    end
  end
end
```

As with Rails controllers, an API class must specify the category for
every single action unless the same category is used for every action
within that class.

## GraphQL types and fields

GraphQL requests are categorized as `not_owned`, unless the GitLab frontend sends a feature category with the request.
Feature categories declared on GraphQL types and fields are not used in metrics or logs.

To record which feature category owns part of the GraphQL schema, use the `feature_category` class method
on a type, interface, resolver, or mutation:

```ruby
module Types
  class IssueType < BaseObject
    graphql_name 'Issue'
    feature_category :team_planning
  end
end
```

Subclasses inherit the feature category of their parent class and can declare their own.

To set the feature category of a single field, pass `feature_category:` to `field`:

```ruby
field :pipelines, Types::Ci::PipelineType.connection_type,
  null: true,
  description: 'Pipelines of the project.',
  feature_category: :continuous_integration
```

### Which feature category a field uses

A field uses the first feature category declared in this order:

1. The `feature_category:` argument of the field.
1. The resolver or mutation of the field, including a category inherited from a parent class.
1. The type that defines the field, including a category inherited from a parent class,
   or the interface that defines the field.

If none of these declare a feature category, the field has no feature category.

### Feature category checks

`spec/graphql/every_graphql_field_spec.rb` checks every field in the GraphQL schema.
For each field, the spec checks the feature categories declared on the field, its resolver or mutation,
and the type or interface that defines it.
The spec fails if any of these feature categories is not in `config/feature_categories.yml`.
The `not_owned` feature category is allowed.

## RSpec Examples

You must set feature category metadata for each RSpec example. This information is used for flaky test
issues to identify the group that owns the feature.

The `feature_category` should be a value from [`config/feature_categories.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/feature_categories.yml).

The `feature_category` metadata can be set:

- [In the top-level `RSpec.describe` blocks](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/104274/diffs#6bd01173381e873f3e1b6c55d33cdaa3d897156b_5_5).
- [In `describe` blocks](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/104274/diffs#a520db2677a30e7f1f5593584f69c49031b894b9_12_12).

Consider splitting the file in the case there are multiple feature categories identified in the same file.

Example:

 ```ruby
 RSpec.describe Admin::Geo::SettingsController, :geo, feature_category: :geo_replication do
 ```

For examples that don't have a `feature_category` set we add a warning when running them in local environment.

To disable the warning use `RSPEC_WARN_MISSING_FEATURE_CATEGORY=false` when running RSpec tests:

```shell
RSPEC_WARN_MISSING_FEATURE_CATEGORY=false bin/rspec spec/<test_file>
```

Additionally, we flag the offenses via `RSpec/FeatureCategory` RuboCop rule.

### Tooling feature category

For Engineering Productivity internal tooling we use `feature_category: :tooling`.

For example in [`spec/tooling/danger/specs_spec.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/spec/tooling/danger/specs_spec.rb#L12).

### Shared feature category

> [!warning]
> The `:shared` feature category is no longer supported for tests.

As part of efforts to [streamline automating flaky and quarantined tests](https://gitlab.com/groups/gitlab-org/quality/-/work_items/195), all specs must use a specific feature category. If you are uncertain about the ownership of a spec, please reach out to the [`#g_test_governance`](https://app.slack.com/client/T02592416/C064M4S0FU5) team for help. For migrating existing tests with `shared` ownership, please see [this issue](https://gitlab.com/gitlab-org/quality/quality-engineering/team-tasks/-/issues/3997) for details.

### Admin section

Adding feature categories is equally important when adding new parts to the Admin section. Historically, Admin sections were often marked as `not_owned` in the code. Now
you must ensure each new addition to the Admin section is properly annotated using `feature_category` notation.
