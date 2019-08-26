# Guidelines for implementing Enterprise Edition features

- **Write the code and the tests.**: As with any code, EE features should have
  good test coverage to prevent regressions.
- **Write documentation.**: Add documentation to the `doc/` directory. Describe
  the feature and include screenshots, if applicable.
- **Submit a MR to the `www-gitlab-com` project.**: Add the new feature to the
  [EE features list](https://about.gitlab.com/features/).

## Act as CE when unlicensed

Since the implementation of [GitLab CE features to work with unlicensed EE instance][ee-as-ce]
GitLab Enterprise Edition should work like GitLab Community Edition
when no license is active. So EE features always should be guarded by
`project.feature_available?` or `group.feature_available?` (or
`License.feature_available?` if it is a system-wide feature).

CE specs should remain untouched as much as possible and extra specs
should be added for EE. Licensed features can be stubbed using the
spec helper `stub_licensed_features` in `EE::LicenseHelpers`.

You can force Webpack to act as CE by either deleting the `ee/` directory or by
setting the [`IS_GITLAB_EE` environment variable](https://gitlab.com/gitlab-org/gitlab-ee/blob/master/config/helpers/is_ee_env.js)
to something that evaluates as `false`. The same works for running tests
(for example `IS_GITLAB_EE=0 yarn jest`).

[ee-as-ce]: https://gitlab.com/gitlab-org/gitlab-ee/issues/2500

## Separation of EE code

We want a [single code base][] eventually, but before we reach the goal,
we still need to merge changes from GitLab CE to EE. To help us get there,
we should make sure that we no longer edit CE files in place in order to
implement EE features.

Instead, all EE code should be put inside the `ee/` top-level directory. The
rest of the code should be as close to the CE files as possible.

[single code base]: https://gitlab.com/gitlab-org/gitlab-ee/issues/2952#note_41016454

### EE-specific comments

When complete separation can't be achieved with the `ee/` directory, you can wrap
code in EE specific comments to designate the difference from CE/EE and add
some context for someone resolving a conflict.

```rb
# EE-specific start
stub_licensed_features(variable_environment_scope: true)
# EE specific end
```

```haml
-# EE-specific start
= render 'ci/variables/environment_scope', form_field: form_field, variable: variable
-# EE-specific end
```

EE-specific comments should not be backported to CE.

**Note:** This is only meant as a workaround, we should follow up and
resolve this soon.

### Detection of EE-only files

For each commit (except on `master`), the `ee-files-location-check` CI job tries
to detect if there are any new files that are EE-only. If any file is detected,
the job fails with an explanation of why and what to do to make it pass.

Basically, the fix is simple: `git mv <file> ee/<file>`.

#### How to name your branches?

For any EE branch, the job will try to detect its CE counterpart by removing any
`ee-` prefix or `-ee` suffix from the EE branch name, and matching the last
branch that contains it.

For instance, from the EE branch `new-shiny-feature-ee` (or
`ee-new-shiny-feature`), the job would find the corresponding CE branches:

- `new-shiny-feature`
- `ce-new-shiny-feature`
- `new-shiny-feature-ce`
- `my-super-new-shiny-feature-in-ce`

#### Whitelist some EE-only files that cannot be moved to `ee/`

The `ee-files-location-check` CI job provides a whitelist of files or folders
that cannot or should not be moved to `ee/`. Feel free to open an issue to
discuss adding a new file/folder to this whitelist.

For instance, it was decided that moving EE-only files from `qa/` to `ee/qa/`
would make it difficult to build the `gitLab-{ce,ee}-qa` Docker images and it
was [not worth the complexity].

[not worth the complexity]: https://gitlab.com/gitlab-org/gitlab-ee/issues/4997#note_59764702

### EE-only features

If the feature being developed is not present in any form in CE, we don't
need to put the codes under `EE` namespace. For example, an EE model could
go into: `ee/app/models/awesome.rb` using `Awesome` as the class name. This
is applied not only to models. Here's a list of other examples:

- `ee/app/controllers/foos_controller.rb`
- `ee/app/finders/foos_finder.rb`
- `ee/app/helpers/foos_helper.rb`
- `ee/app/mailers/foos_mailer.rb`
- `ee/app/models/foo.rb`
- `ee/app/policies/foo_policy.rb`
- `ee/app/serializers/foo_entity.rb`
- `ee/app/serializers/foo_serializer.rb`
- `ee/app/services/foo/create_service.rb`
- `ee/app/validators/foo_attr_validator.rb`
- `ee/app/workers/foo_worker.rb`
- `ee/app/views/foo.html.haml`
- `ee/app/views/foo/_bar.html.haml`

This works because for every path that are present in CE's eager-load/auto-load
paths, we add the same `ee/`-prepended path in [`config/application.rb`].
This also applies to views.

[`config/application.rb`]: https://gitlab.com/gitlab-org/gitlab-ee/blob/925d3d4ebc7a2c72964ce97623ae41b8af12538d/config/application.rb#L42-52

### EE features based on CE features

For features that build on existing CE features, write a module in the `EE`
namespace and inject it in the CE class, on the last line of the file that the
class resides in. This makes conflicts less likely to happen during CE to EE
merges because only one line is added to the CE class - the line that injects
the module. For example, to prepend a module into the `User` class you would use
the following approach:

```ruby
class User < ActiveRecord::Base
  # ... lots of code here ...
end

User.prepend_if_ee('EE::User')
```

Do not use methods such as `prepend`, `extend`, and `include`. Instead, use
`prepend_if_ee`, `extend_if_ee`, or `include_if_ee`. These methods take a
_String_ containing the full module name as the argument, not the module itself.

Since the module would require an `EE` namespace, the file should also be
put in an `ee/` sub-directory. For example, we want to extend the user model
in EE, so we have a module called `::EE::User` put inside
`ee/app/models/ee/user.rb`.

This is also not just applied to models. Here's a list of other examples:

- `ee/app/controllers/ee/foos_controller.rb`
- `ee/app/finders/ee/foos_finder.rb`
- `ee/app/helpers/ee/foos_helper.rb`
- `ee/app/mailers/ee/foos_mailer.rb`
- `ee/app/models/ee/foo.rb`
- `ee/app/policies/ee/foo_policy.rb`
- `ee/app/serializers/ee/foo_entity.rb`
- `ee/app/serializers/ee/foo_serializer.rb`
- `ee/app/services/ee/foo/create_service.rb`
- `ee/app/validators/ee/foo_attr_validator.rb`
- `ee/app/workers/ee/foo_worker.rb`

#### Overriding CE methods

To override a method present in the CE codebase, use `prepend`. It
lets you override a method in a class with a method from a module, while
still having access the class's implementation with `super`.

There are a few gotchas with it:

- you should always [`extend ::Gitlab::Utils::Override`](utilities.md#overridehttpsgitlabcomgitlab-orggitlab-ceblobmasterlibgitlabutilsoverriderb) and use `override` to
  guard the "overrider" method to ensure that if the method gets renamed in
  CE, the EE override won't be silently forgotten.
- when the "overrider" would add a line in the middle of the CE
  implementation, you should refactor the CE method and split it in
  smaller methods. Or create a "hook" method that is empty in CE,
  and with the EE-specific implementation in EE.
- when the original implementation contains a guard clause (e.g.
  `return unless condition`), we cannot easily extend the behaviour by
  overriding the method, because we can't know when the overridden method
  (i.e. calling `super` in the overriding method) would want to stop early.
  In this case, we shouldn't just override it, but update the original method
  to make it call the other method we want to extend, like a [template method
  pattern](https://en.wikipedia.org/wiki/Template_method_pattern).
  For example, given this base:

  ```ruby
    class Base
      def execute
        return unless enabled?

        # ...
        # ...
      end
    end
  ```

  Instead of just overriding `Base#execute`, we should update it and extract
  the behaviour into another method:

  ```ruby
    class Base
      def execute
        return unless enabled?

        do_something
      end

      private

      def do_something
        # ...
        # ...
      end
    end
  ```

  Then we're free to override that `do_something` without worrying about the
  guards:

  ```ruby
    module EE::Base
      extend ::Gitlab::Utils::Override

      override :do_something
      def do_something
        # Follow the above pattern to call super and extend it
      end
    end
  ```

  This would require updating CE first, or make sure this is back ported to CE.

When prepending, place them in the `ee/` specific sub-directory, and
wrap class or module in `module EE` to avoid naming conflicts.

For example to override the CE implementation of
`ApplicationController#after_sign_out_path_for`:

```ruby
def after_sign_out_path_for(resource)
  current_application_settings.after_sign_out_path.presence || new_user_session_path
end
```

Instead of modifying the method in place, you should add `prepend` to
the existing file:

```ruby
class ApplicationController < ActionController::Base
  # ...

  def after_sign_out_path_for(resource)
    current_application_settings.after_sign_out_path.presence || new_user_session_path
  end

  # ...
end

ApplicationController.prepend_if_ee('EE::ApplicationController')
```

And create a new file in the `ee/` sub-directory with the altered
implementation:

```ruby
module EE
  module ApplicationController
    extend ::Gitlab::Utils::Override

    override :after_sign_out_path_for
    def after_sign_out_path_for(resource)
      if Gitlab::Geo.secondary?
        Gitlab::Geo.primary_node.oauth_logout_url(@geo_logout_state)
      else
        super
      end
    end
  end
end
```

##### Overriding CE class methods

The same applies to class methods, except we want to use
`ActiveSupport::Concern` and put `extend ::Gitlab::Utils::Override`
within the block of `class_methods`. Here's an example:

```ruby
module EE
  module Groups
    module GroupMembersController
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :admin_not_required_endpoints
        def admin_not_required_endpoints
          super.concat(%i[update override])
        end
      end
    end
  end
end
```

#### Use self-descriptive wrapper methods

When it's not possible/logical to modify the implementation of a
method. Wrap it in a self-descriptive method and use that method.

For example, in CE only an `admin` is allowed to access all private
projects/groups, but in EE also an `auditor` has full private
access. It would be incorrect to override the implementation of
`User#admin?`, so instead add a method `full_private_access?` to
`app/models/users.rb`. The implementation in CE will be:

```ruby
def full_private_access?
  admin?
end
```

In EE, the implementation `ee/app/models/ee/users.rb` would be:

```ruby
override :full_private_access?
def full_private_access?
  super || auditor?
end
```

In `lib/gitlab/visibility_level.rb` this method is used to return the
allowed visibility levels:

```ruby
def levels_for_user(user = nil)
  if user.full_private_access?
    [PRIVATE, INTERNAL, PUBLIC]
  elsif # ...
end
```

See [CE MR][ce-mr-full-private] and [EE MR][ee-mr-full-private] for
full implementation details.

[ce-mr-full-private]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/12373
[ee-mr-full-private]: https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/2199

### Code in `config/routes`

When we add `draw :admin` in `config/routes.rb`, the application will try to
load the file located in `config/routes/admin.rb`, and also try to load the
file located in `ee/config/routes/admin.rb`.

In EE, it should at least load one file, at most two files. If it cannot find
any files, an error will be raised. In CE, since we don't know if there will
be an EE route, it will not raise any errors even if it cannot find anything.

This means if we want to extend a particular CE route file, just add the same
file located in `ee/config/routes`. If we want to add an EE only route, we
could still put `draw :ee_only` in both CE and EE, and add
`ee/config/routes/ee_only.rb` in EE, similar to `render_if_exists`.

### Code in `app/controllers/`

In controllers, the most common type of conflict is with `before_action` that
has a list of actions in CE but EE adds some actions to that list.

The same problem often occurs for `params.require` / `params.permit` calls.

**Mitigations**

Separate CE and EE actions/keywords. For instance for `params.require` in
`ProjectsController`:

```ruby
def project_params
  params.require(:project).permit(project_params_attributes)
end

# Always returns an array of symbols, created however best fits the use case.
# It _should_ be sorted alphabetically.
def project_params_attributes
  %i[
    description
    name
    path
  ]
end

```

In the `EE::ProjectsController` module:

```ruby
def project_params_attributes
  super + project_params_attributes_ee
end

def project_params_attributes_ee
  %i[
    approvals_before_merge
    approver_group_ids
    approver_ids
    ...
  ]
end
```

### Code in `app/models/`

EE-specific models should `extend EE::Model`.

For example, if EE has a specific `Tanuki` model, you would
place it in `ee/app/models/ee/tanuki.rb`.

### Code in `app/views/`

It's a very frequent problem that EE is adding some specific view code in a CE
view. For instance the approval code in the project's settings page.

**Mitigations**

Blocks of code that are EE-specific should be moved to partials. This
avoids conflicts with big chunks of HAML code that are not fun to
resolve when you add the indentation to the equation.

EE-specific views should be placed in `ee/app/views/`, using extra
sub-directories if appropriate.

#### Using `render_if_exists`

Instead of using regular `render`, we should use `render_if_exists`, which
will not render anything if it cannot find the specific partial. We use this
so that we could put `render_if_exists` in CE, keeping code the same between
CE and EE.

The advantages of this:

- Minimal code difference between CE and EE.
- Very clear hints about where we're extending EE views while reading CE codes.

The disadvantage of this:

- Slightly more work while developing EE features, because now we need to
  port `render_if_exists` to CE.
- If we have typos in the partial name, it would be silently ignored.

##### Caveats

The `render_if_exists` view path argument must be relative to `app/views/` and `ee/app/views`.
Resolving an EE template path that is relative to the CE view path will not work.

```haml
- # app/views/projects/index.html.haml

= render_if_exists 'button' # Will not render `ee/app/views/projects/_button` and will quietly fail
= render_if_exists 'projects/button' # Will render `ee/app/views/projects/_button`
```

#### Using `render_ce`

For `render` and `render_if_exists`, they search for the EE partial first,
and then CE partial. They would only render a particular partial, not all
partials with the same name. We could take the advantage of this, so that
the same partial path (e.g. `shared/issuable/form/default_templates`) could
be referring to the CE partial in CE (i.e.
`app/views/shared/issuable/form/_default_templates.html.haml`), while EE
partial in EE (i.e.
`ee/app/views/shared/issuable/form/_default_templates.html.haml`). This way,
we could show different things between CE and EE.

However sometimes we would also want to reuse the CE partial in EE partial
because we might just want to add something to the existing CE partial. We
could workaround this by adding another partial with a different name, but it
would be tedious to do so.

In this case, we could as well just use `render_ce` which would ignore any EE
partials. One example would be
`ee/app/views/shared/issuable/form/_default_templates.html.haml`:

``` haml
- if @project.feature_available?(:issuable_default_templates)
  = render_ce 'shared/issuable/form/default_templates'
- elsif show_promotions?
  = render 'shared/promotions/promote_issue_templates'
```

In the above example, we can't use
`render 'shared/issuable/form/default_templates'` because it would find the
same EE partial, causing infinite recursion. Instead, we could use `render_ce`
so it ignores any partials in `ee/` and then it would render the CE partial
(i.e. `app/views/shared/issuable/form/_default_templates.html.haml`)
for the same path (i.e. `shared/issuable/form/default_templates`). This way
we could easily wrap around the CE partial.

### Code in `lib/`

Place EE-specific logic in the top-level `EE` module namespace. Namespace the
class beneath the `EE` module just as you would normally.

For example, if CE has LDAP classes in `lib/gitlab/ldap/` then you would place
EE-specific LDAP classes in `ee/lib/ee/gitlab/ldap`.

### Code in `lib/api/`

It can be very tricky to extend EE features by a single line of `prepend_if_ee`,
and for each different [Grape](https://github.com/ruby-grape/grape) feature, we
might need different strategies to extend it. To apply different strategies
easily, we would use `extend ActiveSupport::Concern` in the EE module.

Put the EE module files following
[EE features based on CE features](#ee-features-based-on-ce-features).

#### EE API routes

For EE API routes, we put them in a `prepended` block:

```ruby
module EE
  module API
    module MergeRequests
      extend ActiveSupport::Concern

      prepended do
        params do
          requires :id, type: String, desc: 'The ID of a project'
        end
        resource :projects, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          # ...
        end
      end
    end
  end
end
```

Note that due to namespace differences, we need to use the full qualifier for some
constants.

#### EE params

We can define `params` and utilize `use` in another `params` definition to
include params defined in EE. However, we need to define the "interface" first
in CE in order for EE to override it. We don't have to do this in other places
due to `prepend_if_ee`, but Grape is complex internally and we couldn't easily
do that, so we'll follow regular object-oriented practices that we define the
interface first here.

For example, suppose we have a few more optional params for EE. We can move the
params out of the `Grape::API` class to a helper module, so we can inject it
before it would be used in the class.

```ruby
module API
  class Projects < Grape::API
    helpers Helpers::ProjectsHelpers
  end
end
```

Given this CE API `params`:

```ruby
module API
  module Helpers
    module ProjectsHelpers
      extend ActiveSupport::Concern
      extend Grape::API::Helpers

      params :optional_project_params_ce do
        # CE specific params go here...
      end

      params :optional_project_params_ee do
      end

      params :optional_project_params do
        use :optional_project_params_ce
        use :optional_project_params_ee
      end
    end
  end
end

API::Helpers::ProjectsHelpers.prepend_if_ee('EE::API::Helpers::ProjectsHelpers')
```

We could override it in EE module:

```ruby
module EE
  module API
    module Helpers
      module ProjectsHelpers
        extend ActiveSupport::Concern

        prepended do
          params :optional_project_params_ee do
            # EE specific params go here...
          end
        end
      end
    end
  end
end
```

#### EE helpers

To make it easy for an EE module to override the CE helpers, we need to define
those helpers we want to extend first. Try to do that immediately after the
class definition to make it easy and clear:

```ruby
module API
  class JobArtifacts < Grape::API
    # EE::API::JobArtifacts would override the following helpers
    helpers do
      def authorize_download_artifacts!
        authorize_read_builds!
      end
    end
  end
end

API::JobArtifacts.prepend_if_ee('EE::API::JobArtifacts')
```

And then we can follow regular object-oriented practices to override it:

```ruby
module EE
  module API
    module JobArtifacts
      extend ActiveSupport::Concern

      prepended do
        helpers do
          def authorize_download_artifacts!
            super
            check_cross_project_pipelines_feature!
          end
        end
      end
    end
  end
end
```

#### EE-specific behaviour

Sometimes we need EE-specific behaviour in some of the APIs. Normally we could
use EE methods to override CE methods, however API routes are not methods and
therefore can't be simply overridden. We need to extract them into a standalone
method, or introduce some "hooks" where we could inject behavior in the CE
route. Something like this:

```ruby
module API
  class MergeRequests < Grape::API
    helpers do
      # EE::API::MergeRequests would override the following helpers
      def update_merge_request_ee(merge_request)
      end
    end

    put ':id/merge_requests/:merge_request_iid/merge' do
      merge_request = find_project_merge_request(params[:merge_request_iid])

      # ...

      update_merge_request_ee(merge_request)

      # ...
    end
  end
end

API::MergeRequests.prepend_if_ee('EE::API::MergeRequests')
```

Note that `update_merge_request_ee` doesn't do anything in CE, but
then we could override it in EE:

```ruby
module EE
  module API
    module MergeRequests
      extend ActiveSupport::Concern

      prepended do
        helpers do
          def update_merge_request_ee(merge_request)
            # ...
          end
        end
      end
    end
  end
end
```

#### EE `route_setting`

It's very hard to extend this in an EE module, and this is simply storing
some meta-data for a particular route. Given that, we could simply leave the
EE `route_setting` in CE as it won't hurt and we are just not going to use
those meta-data in CE.

We could revisit this policy when we're using `route_setting` more and whether
or not we really need to extend it from EE. For now we're not using it much.

#### Utilizing class methods for setting up EE-specific data

Sometimes we need to use different arguments for a particular API route, and we
can't easily extend it with an EE module because Grape has different context in
different blocks. In order to overcome this, we need to move the data to a class
method that resides in a separate module or class. This allows us to extend that
module or class before its data is used, without having to place a
`prepend_if_ee` in the middle of CE code.

For example, in one place we need to pass an extra argument to
`at_least_one_of` so that the API could consider an EE-only argument as the
least argument. We would approach this as follows:

```ruby
# api/merge_requests/parameters.rb
module API
  class MergeRequests < Grape::API
    module Parameters
      def self.update_params_at_least_one_of
        %i[
          assignee_id
          description
        ]
      end
    end
  end
end

API::MergeRequests::Parameters.prepend_if_ee('EE::API::MergeRequests::Parameters')

# api/merge_requests.rb
module API
  class MergeRequests < Grape::API
    params do
      at_least_one_of(*Parameters.update_params_at_least_one_of)
    end
  end
end
```

And then we could easily extend that argument in the EE class method:

```ruby
module EE
  module API
    module MergeRequests
      module Parameters
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :update_params_at_least_one_of
          def update_params_at_least_one_of
            super.push(*%i[
              squash
            ])
          end
        end
      end
    end
  end
end
```

It could be annoying if we need this for a lot of routes, but it might be the
simplest solution right now.

This approach can also be used when models define validations that depend on
class methods. For example:

```ruby
# app/models/identity.rb
class Identity < ActiveRecord::Base
  def self.uniqueness_scope
    [:provider]
  end

  prepend_if_ee('EE::Identity')

  validates :extern_uid,
    allow_blank: true,
    uniqueness: { scope: uniqueness_scope, case_sensitive: false }
end

# ee/app/models/ee/identity.rb
module EE
  module Identity
    extend ActiveSupport::Concern

    class_methods do
      extend ::Gitlab::Utils::Override

      def uniqueness_scope
        [*super, :saml_provider_id]
      end
    end
  end
end
```

Instead of taking this approach, we would refactor our code into the following:

```ruby
# ee/app/models/ee/identity/uniqueness_scopes.rb
module EE
  module Identity
    module UniquenessScopes
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        def uniqueness_scope
          [*super, :saml_provider_id]
        end
      end
    end
  end
end

# app/models/identity/uniqueness_scopes.rb
class Identity < ActiveRecord::Base
  module UniquenessScopes
    def self.uniqueness_scope
      [:provider]
    end
  end
end

Identity::UniquenessScopes.prepend_if_ee('EE::Identity::UniquenessScopes')

# app/models/identity.rb
class Identity < ActiveRecord::Base
  validates :extern_uid,
    allow_blank: true,
    uniqueness: { scope: Identity::UniquenessScopes.scopes, case_sensitive: false }
end
```

### Code in `spec/`

When you're testing EE-only features, avoid adding examples to the
existing CE specs. Also do no change existing CE examples, since they
should remain working as-is when EE is running without a license.

Instead place EE specs in the `ee/spec` folder.

### Code in `spec/factories`

Use `FactoryBot.modify` to extend factories already defined in CE.

Note that you cannot define new factories (even nested ones) inside the `FactoryBot.modify` block. You can do so in a
separate `FactoryBot.define` block as shown in the example below:

```ruby
# ee/spec/factories/notes.rb
FactoryBot.modify do
  factory :note do
    trait :on_epic do
      noteable { create(:epic) }
      project nil
    end
  end
end

FactoryBot.define do
  factory :note_on_epic, parent: :note, traits: [:on_epic]
end
```

## JavaScript code in `assets/javascripts/`

To separate EE-specific JS-files we should also move the files into an `ee` folder.

For example there can be an
`app/assets/javascripts/protected_branches/protected_branches_bundle.js` and an
EE counterpart
`ee/app/assets/javascripts/protected_branches/protected_branches_bundle.js`.
The corresponding import statement would then look like this:

```javascript
// app/assets/javascripts/protected_branches/protected_branches_bundle.js
import bundle from '~/protected_branches/protected_branches_bundle.js';

// ee/app/assets/javascripts/protected_branches/protected_branches_bundle.js
// (only works in EE)
import bundle from 'ee/protected_branches/protected_branches_bundle.js';

// in CE: app/assets/javascripts/protected_branches/protected_branches_bundle.js
// in EE: ee/app/assets/javascripts/protected_branches/protected_branches_bundle.js
import bundle from 'ee_else_ce/protected_branches/protected_branches_bundle.js';
```

See the frontend guide [performance section](fe_guide/performance.md) for
information on managing page-specific javascript within EE.

## Vue code in `assets/javascript`

### script tag

#### Child Component only used in EE

To separate Vue template differences we should [async import the components](https://vuejs.org/v2/guide/components-dynamic-async.html#Async-Components).

Doing this allows for us to load the correct component in EE whilst in CE
we can load a empty component that renders nothing. This code **should**
exist in the CE repository as well as the EE repository.

```html
<script>
export default {
  components: {
    EEComponent: () => import('ee_component/components/test.vue'),
  },
};
</script>

<template>
  <div>
    <ee-component />
  </div>
</template>
```

#### For JS code that is EE only, like props, computed properties, methods, etc, we will keep the current approach

- Since we [can't async load a mixin](https://github.com/vuejs/vue-loader/issues/418#issuecomment-254032223) we will use the [`ee_else_ce`](../development/ee_features.md#javascript-code-in-assetsjavascripts) alias we already have for webpack.
  - This means all the EE specific props, computed properties, methods, etc that are EE only should be in a mixin in the `ee/` folder and we need to create a CE counterpart of the mixin

##### Example:

```javascript
import mixin from 'ee_else_ce/path/mixin';

{
    mixins: [mixin]
}
```

- Computed Properties/methods and getters only used in the child import still need a counterpart in CE

- For store modules, we will need a CE counterpart too.
- You can see an MR with an example [here](https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/9762)

#### `template` tag

- **EE Child components**
  - Since we are using the async loading to check which component to load, we'd still use the component's name, check [this example](#child-component-only-used-in-ee).

- **EE extra HTML**
  - For the templates that have extra HTML in EE we should move it into a new component and use the `ee_else_ce` dynamic import

### Non Vue Files

For regular JS files, the approach is similar.

1. We will keep using the [`ee_else_ce`](../development/ee_features.md#javascript-code-in-assetsjavascripts) helper, this means that EE only code should be inside the `ee/` folder.
   1. An EE file should be created with the EE only code, and it should extend the CE counterpart.
   1. For code inside functions that can't be extended, the code should be moved into a new file and we should use `ee_else_ce` helper:

#### Example:

```javascript
  import eeCode from 'ee_else_ce/ee_code';

  function test() {
    const test = 'a';

    eeCode();

    return test;
  }
```

## SCSS code in `assets/stylesheets`

To separate EE-specific styles in SCSS files, if a component you're adding styles for
is limited to only EE, it is better to have a separate SCSS file in appropriate directory
within `app/assets/stylesheets`.
See [backporting changes](#backporting-changes-from-ee-to-ce) for instructions on how to merge changes safely.

In some cases, this is not entirely possible or creating dedicated SCSS file is an overkill,
e.g. a text style of some component is different for EE. In such cases,
styles are usually kept in stylesheet that is common for both CE and EE, and it is wise
to isolate such ruleset from rest of CE rules (along with adding comment describing the same)
to avoid conflicts during CE to EE merge.

### Bad

```scss
.section-body {
  .section-title {
    background: $gl-header-color;
  }

  &.ee-section-body {
    .section-title {
      background: $gl-header-color-cyan;
    }
  }
}
```

### Good

```scss
.section-body {
  .section-title {
    background: $gl-header-color;
  }
}

// EE-specific start
.section-body.ee-section-body {
  .section-title {
    background: $gl-header-color-cyan;
  }
}
// EE-specific end
```

## Backporting changes from EE to CE

Until the work completed to merge the ce and ee codebases, which is tracked on [epic &802](https://gitlab.com/groups/gitlab-org/-/epics/802), there exists times in which some changes for EE require specific changes to the CE
code base.  Examples of backports include the following:

- Features intended or originally built for EE that are later decided to move to CE
- Sometimes some code in CE may impact the EE feature

Here is a workflow to make sure those changes end up backported safely into CE too.

(This approach does not refer to changes introduced via [csslab](https://gitlab.com/gitlab-org/csslab/).)

1. **Make your changes in the EE branch.** If possible, keep a separated commit (to be squashed) to help backporting and review.
1. **Open merge request to EE project.**
1. **Apply the changes you made to CE files in a branch of the CE project.** (Tip: Use `patch` with the diff from your commit in EE branch)
1. **Open merge request to CE project**, referring it's a backport of EE changes and link to MR open in EE.
1. Once EE MR is merged, the MR towards CE can be merged. **But not before**.

**Note:** regarding SCSS, make sure the files living outside `/ee/` don't diverge between CE and EE projects.

## gitlab-svgs

Conflicts in `app/assets/images/icons.json` or `app/assets/images/icons.svg` can
be resolved simply by regenerating those assets with
[`yarn run svg`](https://gitlab.com/gitlab-org/gitlab-svgs).
