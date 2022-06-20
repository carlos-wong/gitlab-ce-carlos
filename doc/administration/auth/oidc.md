---
type: reference
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# OpenID Connect OmniAuth provider **(FREE SELF)**

GitLab can use [OpenID Connect](https://openid.net/specs/openid-connect-core-1_0.html) as an OmniAuth provider.

To enable the OpenID Connect OmniAuth provider, you must register your application with an OpenID Connect provider.
The OpenID Connect provides you with a client's details and secret for you to use.

1. On your GitLab server, open the configuration file.

   For Omnibus GitLab:

   ```shell
   sudo editor /etc/gitlab/gitlab.rb
   ```

   For installations from source:

   ```shell
   cd /home/git/gitlab
   sudo -u git -H editor config/gitlab.yml
   ```

   See [Configure initial settings](../../integration/omniauth.md#configure-initial-settings) for initial settings.

1. Add the provider configuration.

   For Omnibus GitLab:

   ```ruby
   gitlab_rails['omniauth_providers'] = [
     {
       name: "openid_connect",
       label: "Provider name", # optional label for login button, defaults to "Openid Connect"
       icon: "<custom_provider_icon>",
       args: {
         name: "openid_connect",
         scope: ["openid","profile","email"],
         response_type: "code",
         issuer: "<your_oidc_url>",
         discovery: true,
         client_auth_method: "query",
         uid_field: "<uid_field>",
         send_scope_to_token_endpoint: "false",
         client_options: {
           identifier: "<your_oidc_client_id>",
           secret: "<your_oidc_client_secret>",
           redirect_uri: "<your_gitlab_url>/users/auth/openid_connect/callback"
         }
       }
     }
   ]
   ```

   For installation from source:

   ```yaml
     - { name: 'openid_connect',
         label: 'Provider name', # optional label for login button, defaults to "Openid Connect"
         icon: '<custom_provider_icon>',
         args: {
           name: 'openid_connect',
           scope: ['openid','profile','email'],
           response_type: 'code',
           issuer: '<your_oidc_url>',
           discovery: true,
           client_auth_method: 'query',
           uid_field: '<uid_field>',
           send_scope_to_token_endpoint: false,
           client_options: {
             identifier: '<your_oidc_client_id>',
             secret: '<your_oidc_client_secret>',
             redirect_uri: '<your_gitlab_url>/users/auth/openid_connect/callback'
           }
         }
       }
   ```

   NOTE:
   For more information on each configuration option refer to the [OmniAuth OpenID Connect usage documentation](https://github.com/m0n9oose/omniauth_openid_connect#usage)
   and the [OpenID Connect Core 1.0 specification](https://openid.net/specs/openid-connect-core-1_0.html).

1. For the configuration above, change the values for the provider to match your OpenID Connect client setup. Use the following as a guide:
   - `<your_oidc_label>` is the label that appears on the login page.
   - `<custom_provider_icon>` (optional) is the icon that appears on the login page. Icons for the major social login platforms are built-in into GitLab,
     but can be overridden by specifying this parameter. Both local paths and absolute URLs are accepted.
   - `<your_oidc_url>` (optional) is the URL that points to the OpenID Connect provider. For example, `https://example.com/auth/realms/your-realm`.
     If this value is not provided, the URL is constructed from the `client_options` in the following format: `<client_options.scheme>://<client_options.host>:<client_options.port>`.
   - If `discovery` is set to `true`, the OpenID Connect provider attempts to auto discover the client options using `<your_oidc_url>/.well-known/openid-configuration`. Defaults to `false`.
   - `client_auth_method` (optional) specifies the method used for authenticating the client with the OpenID Connect provider.
     - Supported values are:
       - `basic` - HTTP Basic Authentication
       - `jwt_bearer` - JWT based authentication (private key and client secret signing)
       - `mtls` - Mutual TLS or X.509 certificate validation
       - Any other value POSTs the client ID and secret in the request body
     - If not specified, defaults to `basic`.
   - `<uid_field>` (optional) is the field name from the `user_info.raw_attributes` that defines the value for `uid`. For example, `preferred_username`.
     If this value is not provided or the field with the configured value is missing from the `user_info.raw_attributes` details, the `uid` uses the `sub` field.
   - `send_scope_to_token_endpoint` is `true` by default. In other words, the `scope` parameter is normally included in requests to the token endpoint.
     However, if your OpenID Connect provider does not accept the `scope` parameter in such requests, set this to `false`.
   - `client_options` are the OpenID Connect client-specific options. Specifically:
     - `identifier` is the client identifier as configured in the OpenID Connect service provider.
     - `secret` is the client secret as configured in the OpenID Connect service provider.
     - `redirect_uri` is the GitLab URL to redirect the user to after successful login. For example, `http://example.com/users/auth/openid_connect/callback`.
     - `end_session_endpoint` (optional) is the URL to the endpoint that end the session (logout). Can be provided if auto-discovery disabled or unsuccessful.
     - The following `client_options` are optional unless auto-discovery is disabled or unsuccessful:
       - `authorization_endpoint` is the URL to the endpoint that authorizes the end user.
       - `token_endpoint` is the URL to the endpoint that provides Access Token.
       - `userinfo_endpoint` is the URL to the endpoint that provides the user information.
       - `jwks_uri` is the URL to the endpoint where the Token signer publishes its keys.

1. Save the configuration file.
1. [Reconfigure](../restart_gitlab.md#omnibus-gitlab-reconfigure) or [restart GitLab](../restart_gitlab.md#installations-from-source)
   for the changes to take effect if you installed GitLab via Omnibus or from source respectively.

On the sign in page, there should now be an OpenID Connect icon below the regular sign in form.
Click the icon to begin the authentication process. The OpenID Connect provider asks the user to
sign in and authorize the GitLab application (if confirmation required by the client). If everything goes well, the user
is redirected to GitLab and signed in.

## Example configurations

The following configurations illustrate how to set up OpenID with
different providers with Omnibus GitLab.

### Google

See the [Google documentation](https://developers.google.com/identity/protocols/oauth2/openid-connect)
for more details:

```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: "openid_connect",
    label: "Google OpenID", # optional label for login button, defaults to "Openid Connect"
    args: {
      name: "openid_connect",
      scope: ["openid", "profile", "email"],
      response_type: "code",
      issuer: "https://accounts.google.com",
      client_auth_method: "query",
      discovery: true,
      uid_field: "preferred_username",
      client_options: {
        identifier: "<YOUR PROJECT CLIENT ID>",
        secret: "<YOUR PROJECT CLIENT SECRET>",
        redirect_uri: "https://example.com/users/auth/openid_connect/callback",
       }
     }
  }
]
```

### Microsoft Azure

The OpenID Connect (OIDC) protocol for Microsoft Azure uses the [Microsoft identity platform (v2) endpoints](https://docs.microsoft.com/en-us/azure/active-directory/azuread-dev/azure-ad-endpoint-comparison).
To get started, sign in to the [Azure Portal](https://portal.azure.com). For your app, you need the
following information:

- A tenant ID. You may already have one. For more information, review the
  [Microsoft Azure Tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-create-new-tenant) documentation.
- A client ID and a client secret. Follow the instructions in the
  [Microsoft Quickstart Register an Application](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) documentation
  to obtain the tenant ID, client ID, and client secret for your app.

Example Omnibus configuration block:

```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: "openid_connect",
    label: "Azure OIDC", # optional label for login button, defaults to "Openid Connect"
    args: {
      name: "openid_connect",
      scope: ["openid", "profile", "email"],
      response_type: "code",
      issuer:  "https://login.microsoftonline.com/<YOUR-TENANT-ID>/v2.0",
      client_auth_method: "query",
      discovery: true,
      uid_field: "preferred_username",
      client_options: {
        identifier: "<YOUR APP CLIENT ID>",
        secret: "<YOUR APP CLIENT SECRET>",
        redirect_uri: "https://gitlab.example.com/users/auth/openid_connect/callback"
      }
    }
  }
]
```

Microsoft has documented how its platform works with [the OIDC protocol](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc).

### Microsoft Azure Active Directory B2C

While GitLab works with [Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/overview), it requires special
configuration to work. To get started, sign in to the [Azure Portal](https://portal.azure.com).
For your app, you need the following information from Azure:

- A tenant ID. You may already have one. For more information, review the
  [Microsoft Azure Tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-create-new-tenant) documentation.
- A client ID and a client secret. Follow the instructions in the
  [Microsoft tutorial](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-register-applications?tabs=app-reg-ga) documentation to obtain the
  client ID and client secret for your app.
- The user flow or policy name. Follow the instructions in the [Microsoft tutorial](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-user-flows?pivots=b2c-user-flow).

If your GitLab domain is `gitlab.example.com`, ensure the app has the following `Redirect URI`:

`https://gitlab.example.com/users/auth/openid_connect/callback`

In addition, ensure that [ID tokens are enabled](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-register-applications?tabs=app-reg-ga#enable-id-token-implicit-grant).

Add the following API permissions to the app:

- `openid`
- `offline_access`

#### Configure custom policies

Azure B2C [offers two ways of defining the business logic for logging in a user](https://docs.microsoft.com/en-us/azure/active-directory-b2c/user-flow-overview):

- [User flows](https://docs.microsoft.com/en-us/azure/active-directory-b2c/user-flow-overview#user-flows)
- [Custom policies](https://docs.microsoft.com/en-us/azure/active-directory-b2c/user-flow-overview#custom-policies)

While cumbersome to configure, custom policies are required because
standard Azure B2C user flows [do not send the OpenID `email` claim](https://github.com/MicrosoftDocs/azure-docs/issues/16566). In
other words, they do not work with the [`allow_single_sign_on` or `auto_link_user` parameters](../../integration/omniauth.md#configure-initial-settings).
With a standard Azure B2C policy, GitLab cannot create a new account or
link to an existing one with an email address.

Carefully follow the instructions for [creating a custom policy](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-user-flows?pivots=b2c-custom-policy).

The Microsoft instructions use `SocialAndLocalAccounts` in the [custom policy starter pack](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-user-flows?pivots=b2c-custom-policy#custom-policy-starter-pack),
but `LocalAccounts` works for authenticating against local, Active Directory accounts. Before you follow the instructions to [upload the polices](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-user-flows?pivots=b2c-custom-policy#upload-the-policies), do the following:

1. To export the `email` claim, modify the `SignUpOrSignin.xml`. Replace the following line:

   ```xml
   <OutputClaim ClaimTypeReferenceId="email" />
   ```

   with:

   ```xml
   <OutputClaim ClaimTypeReferenceId="signInNames.emailAddress" PartnerClaimType="email" />
   ```

1. For OIDC discovery to work with B2C, the policy must be configured with an issuer compatible with the [OIDC
   specification](https://openid.net/specs/openid-connect-discovery-1_0.html#rfc.section.4.3).
   See the [token compatibility settings](https://docs.microsoft.com/en-us/azure/active-directory-b2c/configure-tokens?pivots=b2c-custom-policy#token-compatibility-settings).
   In `TrustFrameworkBase.xml` under `JwtIssuer`, set `IssuanceClaimPattern` to `AuthorityWithTfp`:

   ```xml
   <ClaimsProvider>
     <DisplayName>Token Issuer</DisplayName>
     <TechnicalProfiles>
       <TechnicalProfile Id="JwtIssuer">
         <DisplayName>JWT Issuer</DisplayName>
         <Protocol Name="None" />
         <OutputTokenFormat>JWT</OutputTokenFormat>
         <Metadata>
           <Item Key="IssuanceClaimPattern">AuthorityWithTfp</Item>
           ...
   ```

1. Now [upload the policy](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-user-flows?pivots=b2c-custom-policy#upload-the-policies). Overwrite
   the existing files if you are updating an existing policy.

1. Determine the issuer URL using the sign-in policy. The issuer URL is in the form:

   ```markdown
   https://<YOUR-DOMAIN>/tfp/<YOUR-TENANT-ID>/<YOUR-SIGN-IN-POLICY-NAME>/v2.0/
   ```

   The policy name is lowercased in the URL. For example, `B2C_1A_signup_signin`
   policy appears as `b2c_1a_signup_sigin`.

The trailing forward slash is required.

1. Verify the operation of the OIDC discovery URL and issuer URL, append `.well-known/openid-configuration`
   to the issuer URL:

   ```markdown
   https://<YOUR-DOMAIN>/tfp/<YOUR-TENANT-ID>/<YOUR-SIGN-IN-POLICY-NAME>/v2.0/.well-known/openid-configuration
   ```

   For example, if `domain` is `example.b2clogin.com` and tenant ID is
   `fc40c736-476c-4da1-b489-ee48cee84386`, you can use `curl` and `jq` to extract the issuer:

   ```shell
   $ curl --silent "https://example.b2clogin.com/tfp/fc40c736-476c-4da1-b489-ee48cee84386/b2c_1a_signup_signin/v2.0/.well-known/openid-configuration" | jq .issuer
   "https://example.b2clogin.com/tfp/fc40c736-476c-4da1-b489-ee48cee84386/b2c_1a_signup_signin/v2.0/"
   ```

1. Configure the issuer URL with the custom policy used for `signup_signin`. For example, this is
   the Omnibus configuration with a custom policy for `b2c_1a_signup_signin`:

   ```ruby
   gitlab_rails['omniauth_providers'] = [
   {
     name: "openid_connect",
     label: "Azure B2C OIDC", # optional label for login button, defaults to "Openid Connect"
     args: {
       name: "openid_connect",
       scope: ["openid"],
       response_mode: "query",
       response_type: "id_token",
       issuer:  "https://<YOUR-DOMAIN>/tfp/<YOUR-TENANT-ID>/b2c_1a_signup_signin/v2.0/",
       client_auth_method: "query",
       discovery: true,
       send_scope_to_token_endpoint: true,
       client_options: {
         identifier: "<YOUR APP CLIENT ID>",
         secret: "<YOUR APP CLIENT SECRET>",
         redirect_uri: "https://gitlab.example.com/users/auth/openid_connect/callback"
       }
     }
   }]
   ```

#### Troubleshooting Azure B2C

- Ensure all occurrences of `yourtenant.onmicrosoft.com`, `ProxyIdentityExperienceFrameworkAppId`, and `IdentityExperienceFrameworkAppId` match your B2C tenant hostname and
  the respective client IDs in the XML policy files.
- Add `https://jwt.ms` as a redirect URI to the app, and use the [custom policy tester](https://docs.microsoft.com/en-us/azure/active-directory-b2c/tutorial-create-user-flows?pivots=b2c-custom-policy#test-the-custom-policy).
  Make sure the payload includes `email` that matches the user's email access.
- After you enable the custom policy, users might see "Invalid username or password" after they try to sign in. This might be a configuration
  issue with the `IdentityExperienceFramework` app. See [this Microsoft comment](https://docs.microsoft.com/en-us/answers/questions/50355/unable-to-sign-on-using-custom-policy.html?childToView=122370#comment-122370)
  that suggests checking that the app manifest contains these settings:

  - `"accessTokenAcceptedVersion": null`
  - `"signInAudience": "AzureADMyOrg"`

This configuration corresponds with the `Supported account types` setting used when
  creating the `IdentityExperienceFramework` app.

#### Keycloak

GitLab works with OpenID providers that use HTTPS. Although a Keycloak
server can be set up using HTTP, GitLab can only communicate
with a Keycloak server that uses HTTPS.

We highly recommend configuring Keycloak to use public key encryption algorithms (for example,
RSA256, RSA512, and so on) instead of symmetric key encryption algorithms (for example, HS256 or HS358) to
sign tokens. Public key encryption algorithms are:

- Easier to configure.
- More secure because leaking the private key has severe security consequences.

The signature algorithm can be configured in the Keycloak administration console under
**Realm Settings > Tokens > Default Signature Algorithm**.

Example Omnibus configuration block:

```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: "openid_connect",
    label: "Keycloak", # optional label for login button, defaults to "Openid Connect"
    args: {
      name: "openid_connect",
      scope: ["openid", "profile", "email"],
      response_type: "code",
      issuer:  "https://keycloak.example.com/auth/realms/myrealm",
      client_auth_method: "query",
      discovery: true,
      uid_field: "preferred_username",
      client_options: {
        identifier: "<YOUR CLIENT ID>",
        secret: "<YOUR CLIENT SECRET>",
        redirect_uri: "https://gitlab.example.com/users/auth/openid_connect/callback"
      }
    }
  }
]
```

##### Configure Keycloak with a symmetric key algorithm

> Introduced in GitLab 14.2.

WARNING:
The instructions below are included for completeness, but symmetric key
encryption should only be used when absolutely necessary.

To use symmetric key encryption:

1. Extract the secret key from the Keycloak database. Keycloak doesn't expose this value in the Web
   interface. The client secret seen in the Web interface is the OAuth2 client secret, which is
   different from the secret used to sign JSON Web Tokens.

   For example, if you're using PostgreSQL as the backend database for Keycloak, log in to the
   database console and extract the key via this SQL query:

   ```sql
   $ psql -U keycloak
   psql (13.3 (Debian 13.3-1.pgdg100+1))
   Type "help" for help.

   keycloak=# SELECT c.name, value FROM component_config CC INNER JOIN component C ON(CC.component_id = C.id) WHERE C.realm_id = 'master' and provider_id = 'hmac-generated' AND CC.name = 'secret';
   -[ RECORD 1 ]---------------------------------------------------------------------------------
   name  | hmac-generated
   value | lo6cqjD6Ika8pk7qc3fpFx9ysrhf7E62-sqGc8drp3XW-wr93zru8PFsQokHZZuJJbaUXvmiOftCZM3C4KW3-g
   -[ RECORD 2 ]---------------------------------------------------------------------------------
   name  | fallback-HS384
   value | UfVqmIs--U61UYsRH-NYBH3_mlluLONpg_zN7CXEwkJcO9xdRNlzZfmfDLPtf2xSTMvqu08R2VhLr-8G-oZ47A
   ```

   In this example, there are two private keys: one for HS256 (`hmac-generated`), and another for
   HS384 (`fallback-HS384`). We use the first `value` to configure GitLab.

1. Convert `value` to standard base64. As [discussed in the post](https://keycloak.discourse.group/t/invalid-signature-with-hs256-token/3228/9),
   `value` is encoded in ["Base 64 Encoding with URL and Filename Safe Alphabet" in RFC 4648](https://datatracker.ietf.org/doc/html/rfc4648#section-5).
   This needs to be converted to [standard base64 as defined in RFC 2045](https://datatracker.ietf.org/doc/html/rfc2045).
   The following Ruby script does this:

   ```ruby
   require 'base64'

   value = "lo6cqjD6Ika8pk7qc3fpFx9ysrhf7E62-sqGc8drp3XW-wr93zru8PFsQokHZZuJJbaUXvmiOftCZM3C4KW3-g"
   Base64.encode64(Base64.urlsafe_decode64(value))
   ```

   This results in the following value:

   ```markdown
   lo6cqjD6Ika8pk7qc3fpFx9ysrhf7E62+sqGc8drp3XW+wr93zru8PFsQokH\nZZuJJbaUXvmiOftCZM3C4KW3+g==\n
   ```

1. Specify this base64-encoded secret in `jwt_secret_base64`. For example:

   ```ruby
   gitlab_rails['omniauth_providers'] = [
     {
       name: "openid_connect",
       label: "Keycloak", # optional label for login button, defaults to "Openid Connect"
       args: {
         name: "openid_connect",
         scope: ["openid", "profile", "email"],
         response_type: "code",
         issuer:  "https://keycloak.example.com/auth/realms/myrealm",
         client_auth_method: "query",
         discovery: true,
         uid_field: "preferred_username",
         jwt_secret_base64: "<YOUR BASE64-ENCODED SECRET>",
         client_options: {
           identifier: "<YOUR CLIENT ID>",
           secret: "<YOUR CLIENT SECRET>",
           redirect_uri: "https://gitlab.example.com/users/auth/openid_connect/callback"
         }
       }
     }
   ]
   ```

If after reconfiguring, you see the error `JSON::JWS::VerificationFailed` error message, this means
the incorrect secret was specified.

#### Casdoor

GitLab works with OpenID providers that use HTTPS. To connect to GitLab using OpenID with Casdoor, use HTTPS instead of HTTP.

For your app, complete the following steps on Casdoor:

1. Get a client ID and a client secret.
1. Add your GitLab redirect URL. For example, if your GitLab domain is `gitlab.example.com`, ensure the Casdoor app has the following
   `Redirect URI`: `https://gitlab.example.com/users/auth/openid_connect/callback`.

See the [Casdoor documentation](https://casdoor.org/docs/integration/gitlab/) for more details.

Example Omnibus GitLab configuration (file path: `/etc/gitlab/gitlab.rb`):

```ruby
gitlab_rails['omniauth_providers'] = [
    {
        name: "openid_connect",
        label: "Casdoor", # optional label for login button, defaults to "Openid Connect"
        args: {
            name: "openid_connect",
            scope: ["openid", "profile", "email"],
            response_type: "code",
            issuer:  "https://<CASDOOR_HOSTNAME>",
            client_auth_method: "query",
            discovery: true,
            uid_field: "sub",
            client_options: {
                identifier: "<YOUR CLIENT ID>",
                secret: "<YOUR CLIENT SECRET>",
                redirect_uri: "https://gitlab.example.com/users/auth/openid_connect/callback"
            }
        }
    }
]
```

Example installations from source configuration (file path: `config/gitlab.yml`):

```yaml
  - { name: 'openid_connect',
      label: 'Casdoor', # optional label for login button, defaults to "Openid Connect"
      args: {
        name: 'openid_connect',
        scope: ['openid','profile','email'],
        response_type: 'code',
        issuer: 'https://<CASDOOR_HOSTNAME>',
        discovery: true,
        client_auth_method: 'query',
        uid_field: 'sub',
        client_options: {
          identifier: '<YOUR CLIENT ID>',
          secret: '<YOUR CLIENT SECRET>',
          redirect_uri: 'https://gitlab.example.com/users/auth/openid_connect/callback'
        }
      }
    }
```

## General troubleshooting

If you're having trouble, here are some tips:

1. Ensure `discovery` is set to `true`. Setting it to `false` requires
   specifying all the URLs and keys required to make OpenID work.

1. Check your system clock to ensure the time is synchronized properly.

1. As mentioned in [the
   documentation](https://github.com/m0n9oose/omniauth_openid_connect),
   make sure `issuer` corresponds to the base URL of the Discovery URL. For
   example, `https://accounts.google.com` is used for the URL
   `https://accounts.google.com/.well-known/openid-configuration`.

1. The OpenID Connect client uses HTTP Basic Authentication to send the
   OAuth2 access token if `client_auth_method` is not defined or if set to `basic`.
   If you are seeing 401 errors upon retrieving the `userinfo` endpoint, you may
   want to check your OpenID Web server configuration. For example, for
   [`oauth2-server-php`](https://github.com/bshaffer/oauth2-server-php), you
   may need to [add a configuration parameter to
   Apache](https://github.com/bshaffer/oauth2-server-php/issues/926#issuecomment-387502778).
