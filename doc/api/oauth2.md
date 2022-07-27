---
type: reference, howto
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# OAuth 2.0 identity provider API **(FREE)**

GitLab provides an API to allow third-party services to access GitLab resources on a user's behalf
with the [OAuth2](https://oauth.net/2/) protocol.

To configure GitLab for this, see
[Configure GitLab as an OAuth 2.0 authentication identity provider](../integration/oauth_provider.md).

This functionality is based on the [doorkeeper Ruby gem](https://github.com/doorkeeper-gem/doorkeeper).

## Cross-origin resource sharing

> CORS preflight request support [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/364680) in GitLab 15.1.

Many `/oauth` endpoints support cross-origin resource sharing (CORS). From GitLab 15.1, the following endpoints also
support [CORS preflight requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS):

- `/oauth/revoke`
- `/oauth/token`
- `/oauth/userinfo`

In addition to the headers listed for [simple requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#simple_requests),
only the `Authorization` header can be used for preflight requests. For example, the `X-Requested-With` header
can't be used for preflight requests.

## Supported OAuth 2.0 flows

GitLab supports the following authorization flows:

- **Authorization code with [Proof Key for Code Exchange (PKCE)](https://tools.ietf.org/html/rfc7636):**
  Most secure. Without PKCE, you'd have to include client secrets on mobile clients,
  and is recommended for both client and server apps.
- **Authorization code:** Secure and common flow. Recommended option for secure
  server-side apps.
- **Resource owner password credentials:** To be used **only** for securely
  hosted, first-party services. GitLab recommends against use of this flow.

The draft specification for [OAuth 2.1](https://oauth.net/2.1/) specifically omits both the
Implicit grant and Resource Owner Password Credentials flows.

Refer to the [OAuth RFC](https://tools.ietf.org/html/rfc6749) to find out
how all those flows work and pick the right one for your use case.

Authorization code (with or without PKCE) flow requires `application` to be
registered first via the `/profile/applications` page in your user's account.
During registration, by enabling proper scopes, you can limit the range of
resources which the `application` can access. Upon creation, you obtain the
`application` credentials: _Application ID_ and _Client Secret_. The _Client Secret_
**must be kept secure**. It is also advantageous to keep the _Application ID_
secret when your application architecture allows.

For a list of scopes in GitLab, see [the provider documentation](../integration/oauth_provider.md#authorized-applications).

### Prevent CSRF attacks

To [protect redirect-based flows](https://tools.ietf.org/id/draft-ietf-oauth-security-topics-13.html#rec_redirect),
the OAuth specification recommends the use of "One-time use CSRF tokens carried in the state
parameter, which are securely bound to the user agent", with each request to the
`/oauth/authorize` endpoint. This can prevent
[CSRF attacks](https://wiki.owasp.org/index.php/Cross-Site_Request_Forgery_(CSRF)).

### Use HTTPS in production

For production, please use HTTPS for your `redirect_uri`.
For development, GitLab allows insecure HTTP redirect URIs.

As OAuth 2.0 bases its security entirely on the transport layer, you should not use unprotected
URIs. For more information, see the [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749#section-3.1.2.1)
and the [OAuth 2.0 Threat Model RFC](https://tools.ietf.org/html/rfc6819#section-4.4.2.1).

In the following sections you can find detailed instructions on how to obtain
authorization with each flow.

### Authorization code with Proof Key for Code Exchange (PKCE)

The [PKCE RFC](https://tools.ietf.org/html/rfc7636#section-1.1) includes a
detailed flow description, from authorization request through access token.
The following steps describe our implementation of the flow.

The Authorization code with PKCE flow, PKCE for short, makes it possible to securely perform
the OAuth exchange of client credentials for access tokens on public clients without
requiring access to the _Client Secret_ at all. This makes the PKCE flow advantageous
for single page JavaScript applications or other client side apps where keeping secrets
from the user is a technical impossibility.

Before starting the flow, generate the `STATE`, the `CODE_VERIFIER` and the `CODE_CHALLENGE`.

- The `STATE` a value that can't be predicted used by the client to maintain
  state between the request and callback. It should also be used as a CSRF token.
- The `CODE_VERIFIER` is a random string, between 43 and 128 characters in length,
  which use the characters `A-Z`, `a-z`, `0-9`, `-`, `.`, `_`, and `~`.
- The `CODE_CHALLENGE` is an URL-safe base64-encoded string of the SHA256 hash of the
  `CODE_VERIFIER`
  - The SHA256 hash must be in binary format before encoding.
  - In Ruby, you can set that up with `Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false)`.
  - For reference, a `CODE_VERIFIER` string of `ks02i3jdikdo2k0dkfodf3m39rjfjsdk0wk349rj3jrhf` when hashed
    and encoded using the Ruby snippet above produces a `CODE_CHALLENGE` string
    of `2i0WFA-0AerkjQm4X4oDEhqA17QIAKNjXpagHBXmO_U`.

1. Request authorization code. To do that, you should redirect the user to the
   `/oauth/authorize` page with the following query parameters:

   ```plaintext
   https://gitlab.example.com/oauth/authorize?client_id=APP_ID&redirect_uri=REDIRECT_URI&response_type=code&state=STATE&scope=REQUESTED_SCOPES&code_challenge=CODE_CHALLENGE&code_challenge_method=S256
   ```

   This page asks the user to approve the request from the app to access their
   account based on the scopes specified in `REQUESTED_SCOPES`. The user is then
   redirected back to the specified `REDIRECT_URI`. The [scope parameter](../integration/oauth_provider.md#authorized-applications)
   is a space-separated list of scopes associated with the user.
   For example,`scope=read_user+profile` requests the `read_user` and `profile` scopes.
   The redirect includes the authorization `code`, for example:

   ```plaintext
   https://example.com/oauth/redirect?code=1234567890&state=STATE
   ```

1. With the authorization `code` returned from the previous request (denoted as
   `RETURNED_CODE` in the following example), you can request an `access_token`, with
   any HTTP client. The following example uses Ruby's `rest-client`:

   ```ruby
   parameters = 'client_id=APP_ID&code=RETURNED_CODE&grant_type=authorization_code&redirect_uri=REDIRECT_URI&code_verifier=CODE_VERIFIER'
   RestClient.post 'https://gitlab.example.com/oauth/token', parameters
   ```

   Example response:

   ```json
   {
    "access_token": "de6780bc506a0446309bd9362820ba8aed28aa506c71eedbe1c5c4f9dd350e54",
    "token_type": "bearer",
    "expires_in": 7200,
    "refresh_token": "8257e65c97202ed1726cf9571600918f3bffb2544b26e00a61df9897668c33a1",
    "created_at": 1607635748
   }
   ```

1. To retrieve a new `access_token`, use the `refresh_token` parameter. Refresh tokens may
   be used even after the `access_token` itself expires. This request:
   - Invalidates the existing `access_token` and `refresh_token`.
   - Sends new tokens in the response.

   ```ruby
     parameters = 'client_id=APP_ID&refresh_token=REFRESH_TOKEN&grant_type=refresh_token&redirect_uri=REDIRECT_URI&code_verifier=CODE_VERIFIER'
     RestClient.post 'https://gitlab.example.com/oauth/token', parameters
   ```

   Example response:

   ```json
   {
     "access_token": "c97d1fe52119f38c7f67f0a14db68d60caa35ddc86fd12401718b649dcfa9c68",
     "token_type": "bearer",
     "expires_in": 7200,
     "refresh_token": "803c1fd487fec35562c205dac93e9d8e08f9d3652a24079d704df3039df1158f",
     "created_at": 1628711391
   }
   ```

NOTE:
The `redirect_uri` must match the `redirect_uri` used in the original
authorization request.

You can now make requests to the API with the access token.

### Authorization code flow

NOTE:
Check the [RFC spec](https://tools.ietf.org/html/rfc6749#section-4.1) for a
detailed flow description.

The authorization code flow is essentially the same as
[authorization code flow with PKCE](#authorization-code-with-proof-key-for-code-exchange-pkce),

Before starting the flow, generate the `STATE`. It is a value that can't be predicted
used by the client to maintain state between the request and callback. It should also
be used as a CSRF token.

1. Request authorization code. To do that, you should redirect the user to the
   `/oauth/authorize` page with the following query parameters:

   ```plaintext
   https://gitlab.example.com/oauth/authorize?client_id=APP_ID&redirect_uri=REDIRECT_URI&response_type=code&state=STATE&scope=REQUESTED_SCOPES
   ```

   This page asks the user to approve the request from the app to access their
   account based on the scopes specified in `REQUESTED_SCOPES`. The user is then
   redirected back to the specified `REDIRECT_URI`. The [scope parameter](../integration/oauth_provider.md#authorized-applications)
   is a space-separated list of scopes associated with the user.
   For example,`scope=read_user+profile` requests the `read_user` and `profile` scopes.
   The redirect includes the authorization `code`, for example:

   ```plaintext
   https://example.com/oauth/redirect?code=1234567890&state=STATE
   ```

1. With the authorization `code` returned from the previous request (shown as
   `RETURNED_CODE` in the following example), you can request an `access_token`, with
   any HTTP client. The following example uses Ruby's `rest-client`:

   ```ruby
   parameters = 'client_id=APP_ID&client_secret=APP_SECRET&code=RETURNED_CODE&grant_type=authorization_code&redirect_uri=REDIRECT_URI'
   RestClient.post 'https://gitlab.example.com/oauth/token', parameters
   ```

   Example response:

   ```json
   {
    "access_token": "de6780bc506a0446309bd9362820ba8aed28aa506c71eedbe1c5c4f9dd350e54",
    "token_type": "bearer",
    "expires_in": 7200,
    "refresh_token": "8257e65c97202ed1726cf9571600918f3bffb2544b26e00a61df9897668c33a1",
    "created_at": 1607635748
   }
   ```

1. To retrieve a new `access_token`, use the `refresh_token` parameter. Refresh tokens may
   be used even after the `access_token` itself expires. This request:
   - Invalidates the existing `access_token` and `refresh_token`.
   - Sends new tokens in the response.

   ```ruby
     parameters = 'client_id=APP_ID&client_secret=APP_SECRET&refresh_token=REFRESH_TOKEN&grant_type=refresh_token&redirect_uri=REDIRECT_URI'
     RestClient.post 'https://gitlab.example.com/oauth/token', parameters
   ```

   Example response:

   ```json
   {
     "access_token": "c97d1fe52119f38c7f67f0a14db68d60caa35ddc86fd12401718b649dcfa9c68",
     "token_type": "bearer",
     "expires_in": 7200,
     "refresh_token": "803c1fd487fec35562c205dac93e9d8e08f9d3652a24079d704df3039df1158f",
     "created_at": 1628711391
   }
   ```

NOTE:
The `redirect_uri` must match the `redirect_uri` used in the original
authorization request.

You can now make requests to the API with the access token returned.

### Resource owner password credentials flow

NOTE:
Check the [RFC spec](https://tools.ietf.org/html/rfc6749#section-4.3) for a
detailed flow description.

NOTE:
The Resource Owner Password Credentials is disabled for users with [two-factor
authentication](../user/profile/account/two_factor_authentication.md) turned on.
These users can access the API using [personal access tokens](../user/profile/personal_access_tokens.md)
instead.

In this flow, a token is requested in exchange for the resource owner credentials
(username and password).

The credentials should only be used when:

- There is a high degree of trust between the resource owner and the client. For
  example, the client is part of the device operating system or a highly
  privileged application.
- Other authorization grant types are not available (such as an authorization code).

WARNING:
Never store the user's credentials and only use this grant type when your client
is deployed to a trusted environment, in 99% of cases
[personal access tokens](../user/profile/personal_access_tokens.md) are a better
choice.

Even though this grant type requires direct client access to the resource owner
credentials, the resource owner credentials are used for a single request and
are exchanged for an access token. This grant type can eliminate the need for
the client to store the resource owner credentials for future use, by exchanging
the credentials with a long-lived access token or refresh token.

To request an access token, you must make a POST request to `/oauth/token` with
the following parameters:

```json
{
  "grant_type"    : "password",
  "username"      : "user@example.com",
  "password"      : "secret"
}
```

Example cURL request:

```shell
echo 'grant_type=password&username=<your_username>&password=<your_password>' > auth.txt
curl --data "@auth.txt" --request POST "https://gitlab.example.com/oauth/token"
```

You can also use this grant flow with registered OAuth applications, by using
HTTP Basic Authentication with the application's `client_id` and `client_secret`:

```shell
echo 'grant_type=password&username=<your_username>&password=<your_password>' > auth.txt
curl --data "@auth.txt" --user client_id:client_secret \
     --request POST "https://gitlab.example.com/oauth/token"
```

Then, you receive a response containing the access token:

```json
{
  "access_token": "1f0af717251950dbd4d73154fdf0a474a5c5119adad999683f5b450c460726aa",
  "token_type": "bearer",
  "expires_in": 7200
}
```

By default, the scope of the access token is `api`, which provides complete read/write access.

For testing, you can use the `oauth2` Ruby gem:

```ruby
client = OAuth2::Client.new('the_client_id', 'the_client_secret', :site => "https://example.com")
access_token = client.password.get_token('user@example.com', 'secret')
puts access_token.token
```

<!--- start_remove The following content will be removed on remove_date: '2022-08-22' -->

### Implicit grant flow (removed)

Implicit grant flow is inherently insecure and the IETF has removed it in [OAuth 2.1](https://oauth.net/2.1/).
It is [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/288516) in GitLab 14.0 and is
[removed](https://gitlab.com/gitlab-org/gitlab/-/issues/344609) in GitLab 15.0.

We recommend that you use [Authorization code with PKCE](#authorization-code-with-proof-key-for-code-exchange-pkce)
instead.

Unlike the authorization code flow, the client receives an `access token`
immediately as a result of the authorization request. The flow does not use the
client secret or the authorization code, as the application
code and storage is accessible on client browsers and mobile devices.

To request the access token, you should redirect the user to the
`/oauth/authorize` endpoint using `token` response type:

```plaintext
https://gitlab.example.com/oauth/authorize?client_id=APP_ID&redirect_uri=REDIRECT_URI&response_type=token&state=YOUR_UNIQUE_STATE_HASH&scope=REQUESTED_SCOPES
```

This prompts the user to approve the applications access to their account
based on the scopes specified in `REQUESTED_SCOPES` and then redirect back to
the `REDIRECT_URI` you provided. The [scope parameter](../integration/oauth_provider.md#authorized-applications)
   is a space-separated list of scopes you want to have access to (for example, `scope=read_user+profile`
would request `read_user` and `profile` scopes). The redirect
includes a fragment with `access_token` as well as token details in GET
parameters, for example:

```plaintext
https://example.com/oauth/redirect#access_token=ABCDExyz123&state=YOUR_UNIQUE_STATE_HASH&token_type=bearer&expires_in=3600
```

<!--- end_remove -->

## Access GitLab API with `access token`

The `access token` allows you to make requests to the API on behalf of a user.
You can pass the token either as GET parameter:

```plaintext
GET https://gitlab.example.com/api/v4/user?access_token=OAUTH-TOKEN
```

or you can put the token to the Authorization header:

```shell
curl --header "Authorization: Bearer OAUTH-TOKEN" "https://gitlab.example.com/api/v4/user"
```

## Access Git over HTTPS with `access token`

A token with [scope](../integration/oauth_provider.md#authorized-applications)
`read_repository` or `write_repository` can access Git over HTTPS. Use the token as the password.
The username must be `oauth2`, not your username.

## Retrieve the token information

To verify the details of a token, use the `token/info` endpoint provided by the
Doorkeeper gem. For more information, see
[`/oauth/token/info`](https://github.com/doorkeeper-gem/doorkeeper/wiki/API-endpoint-descriptions-and-examples#get----oauthtokeninfo).

You must supply the access token, either:

- As a parameter:

   ```plaintext
   GET https://gitlab.example.com/oauth/token/info?access_token=<OAUTH-TOKEN>
   ```

- In the Authorization header:

   ```shell
   curl --header "Authorization: Bearer <OAUTH-TOKEN>" "https://gitlab.example.com/oauth/token/info"
   ```

The following is an example response:

```json
{
    "resource_owner_id": 1,
    "scope": ["api"],
    "expires_in": null,
    "application": {"uid": "1cb242f495280beb4291e64bee2a17f330902e499882fe8e1e2aa875519cab33"},
    "created_at": 1575890427
}
```

### Deprecated fields

The fields `scopes` and `expires_in_seconds` are included in the response.

These fields are aliases for `scope` and `expires_in` respectively, and have been included to
prevent breaking changes introduced in [doorkeeper 5.0.2](https://github.com/doorkeeper-gem/doorkeeper/wiki/Migration-from-old-versions#from-4x-to-5x).

Don't rely on these fields as they are slated for removal in a later release.

## Revoke a token

To revoke a token, use the `revoke` endpoint. The API returns a 200 response code and an empty
JSON hash to indicate success.

```ruby
parameters = 'client_id=APP_ID&client_secret=APP_SECRET&token=TOKEN'
RestClient.post 'https://gitlab.example.com/oauth/revoke', parameters
```

## OAuth 2.0 tokens and GitLab registries

Standard OAuth 2.0 tokens support different degrees of access to GitLab
registries, as they:

- Do not allow users to authenticate to:
  - The GitLab [Container registry](../user/packages/container_registry/index.md#authenticate-with-the-container-registry).
  - Packages listed in the GitLab [Package registry](../user/packages/package_registry/index.md).
- Allow users to get, list, and delete registries through
  the [Container registry API](container_registry.md).
