# SAML SSO for GitLab.com Groups **[SILVER ONLY]**

> Introduced in [GitLab.com Silver](https://about.gitlab.com/pricing/) 11.0.

NOTE: **Note:**
This topic is for SAML on GitLab.com Silver tier and above. For SAML on self-managed GitLab instances, see [SAML OmniAuth Provider](../../../integration/saml.md).

Currently SAML on GitLab.com can be used to automatically add users to a group, and does not yet sign users into GitLab.com. Users should already have an account on the GitLab instance, or can create one when logging in for the first time.

User synchronization for GitLab.com is partially supported using [SCIM](scim_setup.md).

NOTE: **Note:**
SAML SSO for groups is used only as a convenient way to add users and does not sync users between providers without using SCIM. If a group is not using SCIM, group Owners will still need to manage user accounts, such as removing users when necessary.

## Configuring your Identity Provider

1. Navigate to the group and click **Settings > SAML SSO**.
1. Configure your SAML server using the **Assertion consumer service URL** and **Issuer**. See [your identity provider's documentation](#providers) for more details.
1. Configure the SAML response to include a NameID that uniquely identifies each user.
1. Configure required assertions using the [table below](#assertions).
1. Once the identity provider is set up, move on to [configuring GitLab](#configuring-gitlab).

![Issuer and callback for configuring SAML identity provider with GitLab.com](img/group_saml_configuration_information.png)

### SSO enforcement

SSO enforcement was:

- [Introduced in GitLab 11.8](https://gitlab.com/gitlab-org/gitlab-ee/issues/5291).
- [Improved upon in GitLab 11.11 with ongoing enforcement in the GitLab UI](https://gitlab.com/gitlab-org/gitlab-ee/issues/9255).

With this option enabled, users must use your group's GitLab single sign on URL to be added to the group or be added via SCIM. Users cannot be added manually, and may only access project/group resources via the UI by signing in through the SSO URL.

We intend to add a similar SSO requirement for [Git and API activity](https://gitlab.com/gitlab-org/gitlab-ee/issues/9152) in the future.

### NameID

GitLab.com uses the SAML NameID to identify users. The NameID element:

- Is a required field in the SAML response.
- Must be unique to each user.
- Must be a persistent value that will never change, such as a unique ID or username. Email could also be used as the NameID, but only if it can be guaranteed to never change.

### Assertions

| Field | Supported keys | Notes |
|-|----------------|-------------|
| Email | `email`, `mail` | (required) |
| Full Name | `name` |  |
| First Name | `first_name`, `firstname`, `firstName` |  |
| Last Name | `last_name`, `lastname`, `lastName` |  |

## Configuring GitLab

Once you've set up your identity provider to work with GitLab, you'll need to configure GitLab to use it for authentication:

1. Navigate to the group's **Settings > SAML SSO**.
1. Find the SSO URL from your Identity Provider and enter it the **Identity provider single sign on URL** field.
1. Find and enter the fingerprint for the SAML token signing certificate in the **Certificate** field.
1. Check the **Enable SAML authentication for this group** checkbox.
1. Click the **Save changes** button.

![Group SAML Settings for GitLab.com](img/group_saml_settings.png)

## Providers

| Provider | Documentation |
|----------|---------------|
| ADFS (Active Directory Federation Services) | [Create a Relying Party Trust](https://docs.microsoft.com/en-us/windows-server/identity/ad-fs/operations/create-a-relying-party-trust) |
| Azure | [Configuring single sign-on to applications](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-saas-custom-apps) |
| Auth0 | [Auth0 as Identity Provider](https://auth0.com/docs/protocols/saml/saml-idp-generic) |
| G Suite | [Set up your own custom SAML application](https://support.google.com/a/answer/6087519?hl=en) |
| JumpCloud | [Single Sign On (SSO) with GitLab](https://support.jumpcloud.com/customer/en/portal/articles/2810701-single-sign-on-sso-with-gitlab) |
| Okta | [Setting up a SAML application in Okta](https://developer.okta.com/standards/SAML/setting_up_a_saml_application_in_okta) |
| OneLogin | [Use the OneLogin SAML Test Connector](https://onelogin.service-now.com/support?id=kb_article&sys_id=93f95543db109700d5505eea4b96198f) |
| Ping Identity | [Add and configure a new SAML application](https://docs.pingidentity.com/bundle/p1_enterpriseConfigSsoSaml_cas/page/enableAppWithoutURL.html) |

## Unlinking accounts

Users can unlink SAML for a group from their profile page. This can be helpful if:

- You no longer want a group to be able to sign you in to GitLab.com.
- Your SAML NameID has changed and so GitLab can no longer find your user.

For example, to unlink the `MyOrg` account, the following **Disconnect** button will be available under **Profile > Accounts**:

![Unlink Group SAML](img/unlink_group_saml.png)

## Glossary

| Term | Description |
|------|-------------|
| Identity Provider | The service which manages your user identities such as ADFS, Okta, Onelogin or Ping Identity. |
| Service Provider | SAML considers GitLab to be a service provider. |
| Assertion | A piece of information about a user's identity, such as their name or role. Also know as claims or attributes. |
| SSO | Single Sign On. |
| Assertion consumer service URL | The callback on GitLab where users will be redirected after successfully authenticating with the identity provider. |
| Issuer | How GitLab identifies itself to the identity provider. Also known as a "Relying party trust identifier". |
| Certificate fingerprint | Used to confirm that communications over SAML are secure by checking that the server is signing communications with the correct certificate. Also known as a certificate thumbprint. |
