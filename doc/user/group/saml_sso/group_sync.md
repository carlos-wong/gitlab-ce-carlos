---
type: reference, howto
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# SAML Group Sync **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/363084) for self-managed instances in GitLab 15.1.

WARNING:
Changing Group Sync configuration can remove users from the mapped GitLab group.
Removal happens if there is any mismatch between the group names and the list of `groups` in the SAML response.
If changes must be made, ensure either the SAML response includes the `groups` attribute
and the `AttributeValue` value matches the **SAML Group Name** in GitLab,
or that all groups are removed from GitLab to disable Group Sync.

<i class="fa fa-youtube-play youtube" aria-hidden="true"></i>
For a demo of Group Sync using Azure, see [Demo: SAML Group Sync](https://youtu.be/Iqvo2tJfXjg).

## Configure SAML Group Sync

To configure SAML Group Sync:

- For GitLab self-managed:
  1. Configure the [SAML OmniAuth Provider](../../../integration/saml.md).
  1. Ensure your SAML identity provider sends an attribute statement with the same name as the value of the `groups_attribute` setting.
- For GitLab.com:
  1. See [SAML SSO for GitLab.com groups](index.md).
  1. Ensure your SAML identity provider sends an attribute statement named `Groups` or `groups`. 

NOTE:
The value for `Groups` or `groups` in the SAML response can be either the group name or the group ID.

```xml
<saml:AttributeStatement>
  <saml:Attribute Name="Groups">
    <saml:AttributeValue xsi:type="xs:string">Developers</saml:AttributeValue>
    <saml:AttributeValue xsi:type="xs:string">Product Managers</saml:AttributeValue>
  </saml:Attribute>
</saml:AttributeStatement>
```

Other attribute names such as `http://schemas.microsoft.com/ws/2008/06/identity/claims/groups`
are not accepted as a source of groups.
See the [SAML troubleshooting page](../../../administration/troubleshooting/group_saml_scim.md)
for examples on configuring the required attribute name in the SAML identity provider's settings.

## Configure SAML Group Links

When SAML is enabled, users with the Maintainer or Owner role
see a new menu item in group **Settings > SAML Group Links**. You can configure one or more **SAML Group Links** to map
a SAML identity provider group name to a GitLab role. This can be done for a top-level group or any subgroup.

To link the SAML groups:

1. In **SAML Group Name**, enter the value of the relevant `saml:AttributeValue`.
1. Choose the role in **Access Level**.
1. Select **Save**.
1. Repeat to add additional group links if required.

![SAML Group Links](img/saml_group_links_v13_9.png)

If a user is a member of multiple SAML groups mapped to the same GitLab group,
the user gets the highest role from the groups. For example, if one group
is linked as Guest and another Maintainer, a user in both groups gets the Maintainer
role.

Users granted:

- A higher role with Group Sync are displayed as having
  [direct membership](../../project/members/#display-direct-members) of the group.
- A lower or the same role with Group Sync are displayed as having
  [inherited membership](../../project/members/#display-inherited-members) of the group.

### Automatic member removal

After a group sync, for GitLab subgroups, users who are not members of a mapped SAML
group are removed from the group.

FLAG:
In [GitLab 15.1 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/364144), on GitLab.com, users in the top-level
group are assigned the [default membership role](index.md#role) rather than removed. This setting is enabled with the
`saml_group_sync_retain_default_membership` feature flag and can be configured by GitLab.com administrators only.

For example, in the following diagram:

- Alex Garcia signs into GitLab and is removed from GitLab Group C because they don't belong
  to SAML Group C.
- Sidney Jones belongs to SAML Group C, but is not added to GitLab Group C because they have
  not yet signed in.

```mermaid
graph TB
   subgraph SAML users
      SAMLUserA[Sidney Jones]
      SAMLUserB[Zhang Wei]
      SAMLUserC[Alex Garcia]
      SAMLUserD[Charlie Smith]
   end

   subgraph SAML groups
      SAMLGroupA["Group A"] --> SAMLGroupB["Group B"]
      SAMLGroupA --> SAMLGroupC["Group C"]
      SAMLGroupA --> SAMLGroupD["Group D"]
   end

   SAMLGroupB --> |Member|SAMLUserA
   SAMLGroupB --> |Member|SAMLUserB

   SAMLGroupC --> |Member|SAMLUserA
   SAMLGroupC --> |Member|SAMLUserB

   SAMLGroupD --> |Member|SAMLUserD
   SAMLGroupD --> |Member|SAMLUserC
```

```mermaid
graph TB
    subgraph GitLab users
      GitLabUserA[Sidney Jones]
      GitLabUserB[Zhang Wei]
      GitLabUserC[Alex Garcia]
      GitLabUserD[Charlie Smith]
    end

   subgraph GitLab groups
      GitLabGroupA["Group A (SAML configured)"] --> GitLabGroupB["Group B (SAML Group Link not configured)"]
      GitLabGroupA --> GitLabGroupC["Group C (SAML Group Link configured)"]
      GitLabGroupA --> GitLabGroupD["Group D (SAML Group Link configured)"]
   end

   GitLabGroupB --> |Member|GitLabUserA

   GitLabGroupC --> |Member|GitLabUserB
   GitLabGroupC --> |Member|GitLabUserC

   GitLabGroupD --> |Member|GitLabUserC
   GitLabGroupD --> |Member|GitLabUserD
```

```mermaid
graph TB
   subgraph GitLab users
      GitLabUserA[Sidney Jones]
      GitLabUserB[Zhang Wei]
      GitLabUserC[Alex Garcia]
      GitLabUserD[Charlie Smith]
   end

   subgraph GitLab groups after Alex Garcia signs in
      GitLabGroupA[Group A]
      GitLabGroupA["Group A (SAML configured)"] --> GitLabGroupB["Group B (SAML Group Link not configured)"]
      GitLabGroupA --> GitLabGroupC["Group C (SAML Group Link configured)"]
      GitLabGroupA --> GitLabGroupD["Group D (SAML Group Link configured)"]
   end

   GitLabGroupB --> |Member|GitLabUserA
   GitLabGroupC --> |Member|GitLabUserB
   GitLabGroupD --> |Member|GitLabUserC
   GitLabGroupD --> |Member|GitLabUserD
```
