---
stage: Configure
group: Configure
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Troubleshooting the Terraform integration with GitLab

When you are using the integration with Terraform and GitLab, you might experience issues you need to troubleshoot.

## `gitlab_group_share_group` resources not detected when subgroup state is refreshed

The GitLab Terraform provider can fail to detect existing `gitlab_group_share_group` resources
due to the issue ["User with permissions cannot retrieve `share_with_groups` from the API"](https://gitlab.com/gitlab-org/gitlab/-/issues/328428).
This results in an error when running `terraform apply` because Terraform attempts to recreate an
existing resource.

For example, consider the following group/subgroup configuration:

```plaintext
parent-group
├── subgroup-A
└── subgroup-B
```

Where:

- User `user-1` creates `parent-group`, `subgroup-A`, and `subgroup-B`.
- `subgroup-A` is shared with `subgroup-B`.
- User `terraform-user` is member of `parent-group` with inherited `owner` access to both subgroups.

When the Terraform state is refreshed, the API query `GET /groups/:subgroup-A_id` issued by the provider does not return the
details of `subgroup-B` in the `shared_with_groups` array. This leads to the error.

To workaround this issue, make sure to apply one of the following conditions:

1. The `terraform-user` creates all subgroup resources.
1. Grant Maintainer or Owner role to the `terraform-user` user on `subgroup-B`.
1. The `terraform-user` inherited access to `subgroup-B` and `subgroup-B` contains at least one project.

### Invalid CI/CD syntax error when using the base template

You might encounter a CI/CD syntax error when using the Terraform templates:

- On GitLab 14.2 and later, using the `latest` template.
- On GitLab 15.0 and later, using any version of the template.

For example:

```yaml
include:
  # On 14.2 and later, when using either of the following:
  - template: Terraform/Base.latest.gitlab-ci.yml
  - template: Terraform.latest.gitlab-ci.yml
  # On 15.0 and later, the following templates have also been updated:
  - template: Terraform/Base.gitlab-ci.yml
  - template: Terraform.gitlab-ci.yml

my-terraform-job:
  extends: .apply
```

There are three different causes for the error:

- In the case of `.init`, the error occurs because the init stage and jobs [were removed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/71188) from the templates, since they are no longer required. To resolve the syntax error, you can safely remove any jobs extending `.init`.
- For all other jobs, the reason for the failure is that the base jobs have been [renamed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/67719): A `.terraform:` prefix has been added to every job name. For example, `.apply` became `.terraform:apply`. To fix this error, you can update the base job names. For example:

  ```diff
    my-terraform-job:
  -   extends: .apply
  +   extends: .terraform:apply
  ```

- In GitLab 15.0, templates use [`rules`](../../../ci/yaml/index.md#rules) syntax
  instead of [`only/except`](../../../ci/yaml/index.md#only--except).
  Ensure the syntax in your `.gitlab-ci.yml` file does not include both.

#### Use an older version of the template

Breaking changes can occur during major releases. If you encounter a breaking change or want to use an older version of a template, you can update your `.gitlab-ci.yml` to refer to an older one. For example:

```yaml
include:
  remote: https://gitlab.com/gitlab-org/configure/template-archive/-/raw/main/14-10/Terraform.gitlab-ci.yml
```

View the [template-archive](https://gitlab.com/gitlab-org/configure/template-archive) to see which templates are available.

## Troubleshooting Terraform state

### Unable to lock Terraform state files in CI jobs for `terraform apply` using a plan created in a previous job

When passing `-backend-config=` to `terraform init`, Terraform persists these values inside the plan
cache file. This includes the `password` value.

As a result, to create a plan and later use the same plan in another CI job, you might get the error
`Error: Error acquiring the state lock` errors when using `-backend-config=password=$CI_JOB_TOKEN`.
This happens because the value of `$CI_JOB_TOKEN` is only valid for the duration of the current job.

As a workaround, use [http backend configuration variables](https://www.terraform.io/docs/language/settings/backends/http.html#configuration-variables) in your CI job,
which is what happens behind the scenes when following the
[Get started using GitLab CI](terraform_state.md#initialize-a-terraform-state-as-a-backend-by-using-gitlab-cicd) instructions.

### Error: "address": required field is not set

By default, we set `TF_ADDRESS` to `${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}`.
If you don't set `TF_STATE_NAME` or `TF_ADDRESS` in your job, the job fails with the error message
`Error: "address": required field is not set`.

To resolve this, ensure that either `TF_ADDRESS` or `TF_STATE_NAME` is accessible in the
job that returned the error:

1. Configure the [CI/CD environment scope](../../../ci/variables/#add-a-cicd-variable-to-a-project) for the job.
1. Set the job's [environment](../../../ci/yaml/#environment), matching the environment scope from the previous step.

### Error refreshing state: HTTP remote state endpoint requires auth

To resolve this, ensure that:

- The access token you use has `api` scope.
- If you have set the `TF_HTTP_PASSWORD` CI/CD variable, make sure that you either:
  - Set the same value as `TF_PASSWORD`
  - Remove `TF_HTTP_PASSWORD` variable if your CI/CD job does not explicitly use it.
