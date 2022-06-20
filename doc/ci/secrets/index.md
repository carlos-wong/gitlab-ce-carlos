---
stage: Verify
group: Pipeline Authoring
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: concepts, howto
---

# Using external secrets in CI **(FREE)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/218746) in GitLab 13.4 and GitLab Runner 13.4.
> - `file` setting [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/250695) in GitLab 14.1 and GitLab Runner 14.1.
> - `VAULT_NAMESPACE` setting [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/255619) in GitLab 14.9 and GitLab Runner 14.9.

Secrets represent sensitive information your CI job needs to complete work. This
sensitive information can be items like API tokens, database credentials, or private keys.
Secrets are sourced from your secrets provider.

Unlike CI/CD variables, which are always presented to a job, secrets must be explicitly
required by a job. Read [GitLab CI/CD pipeline configuration reference](../yaml/index.md#secrets)
for more information about the syntax.

GitLab has selected [Vault by HashiCorp](https://www.vaultproject.io) as the
first supported provider, and [KV-V2](https://www.vaultproject.io/docs/secrets/kv/kv-v2)
as the first supported secrets engine.

GitLab authenticates using Vault's
[JSON Web Token (JWT) authentication method](https://www.vaultproject.io/docs/auth/jwt#jwt-authentication), using
the [JSON Web Token](https://gitlab.com/gitlab-org/gitlab/-/issues/207125) (`CI_JOB_JWT`)
introduced in GitLab 12.10.

You must [configure your Vault server](#configure-your-vault-server) before you
can use [use Vault secrets in a CI job](#use-vault-secrets-in-a-ci-job).

The flow for using GitLab with HashiCorp Vault
is summarized by this diagram:

![Flow between GitLab and HashiCorp](../img/gitlab_vault_workflow_v13_4.png "How GitLab CI_JOB_JWT works with HashiCorp Vault")

1. Configure your vault and secrets.
1. Generate your JWT and provide it to your CI job.
1. Runner contacts HashiCorp Vault and authenticates using the JWT.
1. HashiCorp Vault verifies the JWT.
1. HashiCorp Vault checks the bounded claims and attaches policies.
1. HashiCorp Vault returns the token.
1. Runner reads secrets from the HashiCorp Vault.

NOTE:
Read the [Authenticating and Reading Secrets With HashiCorp Vault](../examples/authenticating-with-hashicorp-vault/index.md)
tutorial for a version of this feature. It's available to all
subscription levels, supports writing secrets to and deleting secrets from Vault,
and supports multiple secrets engines.

## Configure your Vault server

To configure your Vault server:

1. Ensure your Vault server is running on version 1.2.0 or higher.
1. Enable the authentication method by running these commands. They provide your Vault
   server the [JSON Web Key Set](https://tools.ietf.org/html/rfc7517) (JWKS) endpoint for your GitLab instance, so Vault
   can fetch the public signing key and verify the JSON Web Token (JWT) when authenticating:

   ```shell
   $ vault auth enable jwt

   $ vault write auth/jwt/config \
     jwks_url="https://gitlab.example.com/-/jwks" \
     bound_issuer="gitlab.example.com"
   ```

1. Configure policies on your Vault server to grant or forbid access to certain
   paths and operations. This example grants read access to the set of secrets
   required by your production environment:

   ```shell
   vault policy write myproject-production - <<EOF
   # Read-only permission on 'ops/data/production/*' path

   path "ops/data/production/*" {
     capabilities = [ "read" ]
   }
   EOF
   ```

1. Configure roles on your Vault server, restricting roles to a project or namespace,
   as described in [Configure Vault server roles](#configure-vault-server-roles) on this page.
1. [Create the following CI/CD variables](../variables/index.md#custom-cicd-variables)
   to provide details about your Vault server:
   - `VAULT_SERVER_URL` - The URL of your Vault server, such as `https://vault.example.com:8200`.
     Required.
   - `VAULT_AUTH_ROLE` - Optional. The role to use when attempting to authenticate.
     If no role is specified, Vault uses the [default role](https://www.vaultproject.io/api/auth/jwt#default_role)
     specified when the authentication method was configured.
   - `VAULT_AUTH_PATH` - Optional. The path where the authentication method is mounted, default is `jwt`.
   - `VAULT_NAMESPACE` - Optional. The [Vault Enterprise namespace](https://www.vaultproject.io/docs/enterprise/namespaces) to use for reading secrets and authentication.
     If no namespace is specified, Vault uses the `root` ("`/`") namespace.
     The setting is ignored by Vault Open Source.

   NOTE:
   Support for providing these values in the user interface [is tracked in this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/218677).

## Use Vault secrets in a CI job **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/28321) in GitLab 13.4 and GitLab Runner 13.4.

After [configuring your Vault server](#configure-your-vault-server), you can use
the secrets stored in Vault by defining them with the `vault` keyword:

```yaml
secrets:
  DATABASE_PASSWORD:
    vault: production/db/password@ops  # translates to secret `ops/data/production/db`, field `password`
```

In this example:

- `production/db` - The secret.
- `password` The field.
- `ops` - The path where the secrets engine is mounted.

After GitLab fetches the secret from Vault, the value is saved in a temporary file.
The path to this file is stored in a CI/CD variable named `DATABASE_PASSWORD`,
similar to [variables of type `file`](../variables/index.md#cicd-variable-types).

To overwrite the default behavior, set the `file` option explicitly:

```yaml
secrets:
  DATABASE_PASSWORD:
    vault: production/db/password@ops
    file: false
```

In this example, the secret value is put directly in the `DATABASE_PASSWORD` variable
instead of pointing to a file that holds it.

For more information about the supported syntax, read the
[`.gitlab-ci.yml` reference](../yaml/index.md#secretsvault).

## Configure Vault server roles

When a CI job attempts to authenticate, it specifies a role. You can use roles to group
different policies together. If authentication is successful, these policies are
attached to the resulting Vault token.

[Bound claims](https://www.vaultproject.io/docs/auth/jwt#bound-claims) are predefined
values that are matched to the JWT's claims. With bounded claims, you can restrict access
to specific GitLab users, specific projects, or even jobs running for specific Git
references. You can have as many bounded claims you need, but they must *all* match
for authentication to be successful.

Combining bounded claims with GitLab features like [user roles](../../user/permissions.md)
and [protected branches](../../user/project/protected_branches.md), you can tailor
these rules to fit your specific use case. In this example, authentication is allowed
only for jobs running for protected tags with names matching the pattern used for
production releases:

```shell
$ vault write auth/jwt/role/myproject-production - <<EOF
{
  "role_type": "jwt",
  "policies": ["myproject-production"],
  "token_explicit_max_ttl": 60,
  "user_claim": "user_email",
  "bound_claims_type": "glob",
  "bound_claims": {
    "project_id": "42",
    "ref_protected": "true",
    "ref_type": "tag",
    "ref": "auto-deploy-*"
  }
}
EOF
```

WARNING:
Always restrict your roles to a project or namespace by using one of the provided
claims like `project_id` or `namespace_id`. Without these restrictions, any JWT
generated by this GitLab instance may be allowed to authenticate using this role.

For a full list of `CI_JOB_JWT` claims, read the
[How it works](../examples/authenticating-with-hashicorp-vault/index.md#how-it-works) section of the
[Authenticating and Reading Secrets With HashiCorp Vault](../examples/authenticating-with-hashicorp-vault/index.md) tutorial.

You can also specify some attributes for the resulting Vault tokens, such as time-to-live,
IP address range, and number of uses. The full list of options is available in
[Vault's documentation on creating roles](https://www.vaultproject.io/api/auth/jwt#create-role)
for the JSON web token method.

## Using a self-signed Vault server

When the Vault server is using a self-signed certificate, you will see the following error in the job logs:

```plaintext
ERROR: Job failed (system failure): resolving secrets: initializing Vault service: preparing authenticated client: checking Vault server health: Get https://vault.example.com:8000/v1/sys/health?drsecondarycode=299&performancestandbycode=299&sealedcode=299&standbycode=299&uninitcode=299: x509: certificate signed by unknown authority
```

You have two options to solve this error:

- Add the self-signed certificate to the GitLab Runner server's CA store.
  If you deployed GitLab Runner using the [Helm chart](https://docs.gitlab.com/runner/install/kubernetes.html), you will have to create your own GitLab Runner image.
- Use the `VAULT_CACERT` environment variable to configure GitLab Runner to trust the certificate:
  - If you are using systemd to manage GitLab Runner, see [how to add an environment variable for GitLab Runner](https://docs.gitlab.com/runner/configuration/init.html#setting-custom-environment-variables).
  - If you deployed GitLab Runner using the [Helm chart](https://docs.gitlab.com/runner/install/kubernetes.html):
    1. [Provide a custom certificate for accessing GitLab](https://docs.gitlab.com/runner/install/kubernetes.html#providing-a-custom-certificate-for-accessing-gitlab), and make sure to add the certificate for the Vault server instead of the certificate for GitLab. If your GitLab instance is also using a self-signed certificate, you should be able to add both in the same `Secret`.
    1. Add the following lines in your `values.yaml` file:

       ```yaml
       ## Replace both the <SECRET_NAME> and the <VAULT_CERTIFICATE>
       ## with the actual values you used to create the secret

       certsSecretName: <SECRET_NAME>

       envVars:
         - name: VAULT_CACERT
           value: "/home/gitlab-runner/.gitlab-runner/certs/<VAULT_CERTIFICATE>"
       ```
