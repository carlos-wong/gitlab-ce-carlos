# Application limits development

This document provides a development guide for contributors to add application
limits to GitLab.

## Documentation

First of all, you have to gather information and decide which are the different
limits that will be set for the different GitLab tiers. You also need to
coordinate with others to [document](../administration/instance_limits.md)
and communicate those limits.

There is a guide about [introducing application
limits](https://about.gitlab.com/handbook/product/#introducing-application-limits).

## Development

### Insert database plan limits

In the `plan_limits` table, you have to create a new column and insert the
limit values. It's recommended to create separate migration script files.

1. Add new column to the `plan_limits` table with non-null default value 0, eg:

   ```ruby
   add_column(:plan_limits, :project_hooks, :integer, default: 0, null: false)
   ```

   NOTE: **Note:** Plan limits entries set to `0` mean that limits are not
   enabled.

1. Insert plan limits values into the database using
   `create_or_update_plan_limit` migration helper, eg:

   ```ruby
   def up
     return unless Gitlab.com?

     create_or_update_plan_limit('project_hooks', 'free', 100)
     create_or_update_plan_limit('project_hooks', 'bronze', 100)
     create_or_update_plan_limit('project_hooks', 'silver', 100)
     create_or_update_plan_limit('project_hooks', 'gold', 100)
   end

   def down
     return unless Gitlab.com?

     create_or_update_plan_limit('project_hooks', 'free', 0)
     create_or_update_plan_limit('project_hooks', 'bronze', 0)
     create_or_update_plan_limit('project_hooks', 'silver', 0)
     create_or_update_plan_limit('project_hooks', 'gold', 0)
   end
   ```

NOTE: **Note:** Some plans exist only on GitLab.com. You can check if the
migration is running on GitLab.com with `Gitlab.com?`.

### Plan limits validation

#### Get current limit

Access to the current limit can be done through the project or the namespace,
eg:

```ruby
project.actual_limits.project_hooks
```

#### Check current limit

There is one method `PlanLimits#exceeded?` to check if the current limit is
being exceeded. You can use either an `ActiveRecord` object or an `Integer`.

Ensures that the count of the records does not exceed the defined limit, eg:

```ruby
project.actual_limits.exceeded?(:project_hooks, ProjectHook.where(project: project))
```

Ensures that the number does not exceed the defined limit, eg:

```ruby
project.actual_limits.exceeded?(:project_hooks, 10)
```

#### `Limitable` concern

The [`Limitable` concern](https://gitlab.com/gitlab-org/gitlab/blob/master/ee/app/models/concerns/ee/limitable.rb)
can be used to validate that a model does not exceed the limits. It ensures
that the count of the records for the current model does not exceed the defined
limit.

NOTE: **Note:** You must specify the limit scope of the object being validated
and the limit name if it's different from the pluralized model name.

```ruby
class ProjectHook
  include Limitable

  self.limit_name = 'project_hooks' # Optional as ProjectHook corresponds with project_hooks
  self.limit_scope = :project
end
```

To test the model, you can include the shared examples.

```ruby
it_behaves_like 'includes Limitable concern' do
  subject { build(:project_hook, project: create(:project)) }
end
```

### Subscription Plans

Self-managed:

- `default` - Everyone

GitLab.com:

- `free` - Everyone
- `bronze`- Namespaces with a Bronze subscription
- `silver` - Namespaces with a Silver subscription
- `gold` - Namespaces with a Gold subscription

NOTE: **Note:** The test environment doesn't have any plans.
