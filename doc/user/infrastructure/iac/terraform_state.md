---
stage: Configure
group: Configure
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# GitLab-managed Terraform state **(FREE)**

> [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/2673) in GitLab 13.0.

Terraform uses state files to store details about your infrastructure configuration.
With Terraform remote [backends](https://www.terraform.io/language/settings/backends),
you can store the state file in a remote and shared store.

GitLab provides a [Terraform HTTP backend](https://www.terraform.io/language/settings/backends/http)
to securely store your state files with minimal configuration.

In GitLab, you can:

- Version your Terraform state files.
- Encrypt the state file both in transit and at rest.
- Lock and unlock states.
- Remotely execute `terraform plan` and `terraform apply` commands.

WARNING:
**Disaster recovery planning**
Terraform state files are encrypted with the lockbox Ruby gem when they are at rest on disk and in object storage.
[To decrypt a state file, GitLab must be available](https://gitlab.com/gitlab-org/gitlab/-/issues/335739).
If it is offline, and you use GitLab to deploy infrastructure that GitLab requires (like virtual machines,
Kubernetes clusters, or network components), you cannot access the state file easily or decrypt it.
Additionally, if GitLab serves up Terraform modules or other dependencies that are required to bootstrap GitLab,
these will be inaccessible. To work around this issue, make other arrangements to host or back up these dependencies,
or consider using a separate GitLab instance with no shared points of failure.

## Prerequisites

For self-managed GitLab, before you can use GitLab for your Terraform state files:

- An administrator must [set up Terraform state storage](../../../administration/terraform_state.md).
- You must enable the **Infrastructure** menu for your project. Go to **Settings > General**,
  expand **Visibility, project features, permissions**, and under **Operations**, turn on the toggle.

## Initialize a Terraform state as a backend by using GitLab CI/CD

After you execute the `terraform init` command, you can use GitLab CI/CD
to run `terraform` commands.

Prerequisites:

- To lock, unlock, and write to the state by using `terraform apply`, you must have at least the Maintainer role.
- To read the state by using `terraform plan -lock=false`, you must have at least the Developer role.

WARNING:
Like any other job artifact, Terraform plan data is viewable by anyone with the Guest role on the repository.
Neither Terraform nor GitLab encrypts the plan file by default. If your Terraform plan
includes sensitive data, like passwords, access tokens, or certificates, you should
encrypt plan output or modify the project visibility settings.

To configure GitLab CI/CD as a backend:

1. In your Terraform project, in a `.tf` file like `backend.tf`,
   define the [HTTP backend](https://www.terraform.io/docs/language/settings/backends/http.html):

   ```hcl
   terraform {
     backend "http" {
     }
   }
   ```

1. In the root directory of your project repository, create a `.gitlab-ci.yml` file. Use
   [this file](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Terraform.gitlab-ci.yml)
   to populate it.

1. Push your project to GitLab. This action triggers a pipeline, which
   runs the `gitlab-terraform init`, `gitlab-terraform validate`, and
   `gitlab-terraform plan` commands.
1. Trigger the manual `terraform apply` job from the previous pipeline to provision the defined infrastructure.

The output from the above `terraform` commands should be viewable in the job logs.

## Access the state from your local machine

You can access the GitLab-managed Terraform state from your local machine.

WARNING:
On clustered deployments of GitLab, you should not use local storage.
A split state can occur across nodes, making subsequent Terraform executions
inconsistent. Instead, use a remote storage resource.

1. Ensure the Terraform state has been
   [initialized for CI/CD](#initialize-a-terraform-state-as-a-backend-by-using-gitlab-cicd).
1. Copy a pre-populated Terraform `init` command:

   1. On the top bar, select **Menu > Projects** and find your project.
   1. On the left sidebar, select **Infrastructure > Terraform**.
   1. Next to the environment you want to use, select **Actions**
      (**{ellipsis_v}**) and select **Copy Terraform init command**.

1. Open a terminal and run this command on your local machine.

## Migrate to a GitLab-managed Terraform state

Terraform supports copying the state when the backend changes or is
reconfigured. Use these actions to migrate from another backend to
GitLab-managed Terraform state.

You should use a local terminal to run the commands needed for migrating to GitLab-managed Terraform state.

The following example demonstrates how to change the state name. The same workflow is needed to migrate to GitLab-managed Terraform state from a different state storage backend.

## Use your GitLab backend as a remote data source

You can use a GitLab-managed Terraform state backend as a
[Terraform data source](https://www.terraform.io/language/state/remote-state-data).

1. In your `main.tf` or other relevant file, declare these variables. Leave the values empty.

   ```hcl
   variable "example_remote_state_address" {
     type = string
     description = "Gitlab remote state file address"
   }

   variable "example_username" {
     type = string
     description = "Gitlab username to query remote state"
   }

   variable "example_access_token" {
     type = string
     description = "GitLab access token to query remote state"
   }
   ```

1. To override the values from the previous step, create a file named `example.auto.tfvars`. This file should **not** be versioned in your project repository.

   ```plaintext
   example_remote_state_address = "https://gitlab.com/api/v4/projects/<TARGET-PROJECT-ID>/terraform/state/<TARGET-STATE-NAME>"
   example_username = "<GitLab username>"
   example_access_token = "<GitLab Personal Access Token>"
   ```

1. In a `.tf` file, define the data source by using [Terraform input variables](https://www.terraform.io/language/values/variables):

   ```hcl
   data "terraform_remote_state" "example" {
     backend = "http"

     config = {
       address = var.example_remote_state_address
       username = var.example_username
       password = var.example_access_token
     }
   }
   ```

   - **address**: The URL of the remote state backend you want to use as a data source.
     For example, `https://gitlab.com/api/v4/projects/<TARGET-PROJECT-ID>/terraform/state/<TARGET-STATE-NAME>`.
   - **username**: The username to authenticate with the data source. If you are using
     a [Personal Access Token](../../profile/personal_access_tokens.md) for
     authentication, this value is your GitLab username. If you are using GitLab CI/CD, this value is `'gitlab-ci-token'`.
   - **password**: The password to authenticate with the data source. If you are using a Personal Access Token for
     authentication, this value is the token value (the token must have the **API** scope).
     If you are using GitLab CI/CD, this value is the contents of the `${CI_JOB_TOKEN}` CI/CD variable.

Outputs from the data source can now be referenced in your Terraform resources
using `data.terraform_remote_state.example.outputs.<OUTPUT-NAME>`.

To read the Terraform state in the target project, you need at least the Developer role.

### Set up the initial backend

```shell
PROJECT_ID="<gitlab-project-id>"
TF_USERNAME="<gitlab-username>"
TF_PASSWORD="<gitlab-personal-access-token>"
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/old-state-name"

terraform init \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${TF_PASSWORD} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

```plaintext
Initializing the backend...

Successfully configured the backend "http"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
re-run this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

### Change the backend

Now that `terraform init` has created a `.terraform/` directory that knows where
the old state is, you can tell it about the new location:

```shell
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/new-state-name"

terraform init \
  -migrate-state \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${TF_PASSWORD} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

```plaintext
Initializing the backend...
Backend configuration changed!

Terraform has detected that the configuration specified for the backend
has changed. Terraform will now check for existing state in the backends.


Acquiring state lock. This may take a few moments...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "http" backend to the
  newly configured "http" backend. No existing state was found in the newly
  configured "http" backend. Do you want to copy this state to the new "http"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes


Successfully configured the backend "http"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

If you type `yes`, it copies your state from the old location to the new
location. You can then go back to running it in GitLab CI/CD.

## Manage Terraform state files

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/273592) in GitLab 13.8.

To view Terraform state files:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Infrastructure > Terraform**.

[An epic exists](https://gitlab.com/groups/gitlab-org/-/epics/4563) to track improvements to this UI.

### Manage individual Terraform state versions

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/207347) in GitLab 13.4.

Individual state versions can be managed using the GitLab REST API.

If you have at least the Developer role, you can retrieve state versions by using their serial number::

```shell
curl --header "Private-Token: <your_access_token>" "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/versions/<version-serial>"
```

If you have at least the Maintainer role, you can remove state versions by using their serial number:

```shell
curl --header "Private-Token: <your_access_token>" --request DELETE "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>/versions/<version-serial>"
```

### Remove a state file

If you have at least the Maintainer role, you can remove a state file.

1. On the left sidebar, select **Infrastructure > Terraform**.
1. In the **Actions** column, select **Actions** (**{ellipsis_v}**) and then **Remove state file and versions**.

### Remove a state file by using the API

You can remove a state file by making a request to the REST API. For example:

```shell
curl --header "Private-Token: <your_access_token>" --request DELETE "https://gitlab.example.com/api/v4/projects/<your_project_id>/terraform/state/<your_state_name>"
```

You can also use [the GraphQL API](../../../api/graphql/reference/index.md#mutationterraformstatedelete).

## Related topics

- [Troubleshooting GitLab-managed Terraform state](troubleshooting.md).
- To use GitLab and Terraform to deploy an AWS EC2 instance in a custom VPC,
  see [this sample project](https://gitlab.com/gitlab-org/configure/examples/gitlab-terraform-aws).
