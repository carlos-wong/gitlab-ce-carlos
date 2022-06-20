---
type: reference, howto
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Restrict allowed SSH key technologies and minimum length **(FREE SELF)**

`ssh-keygen` allows users to create RSA keys with as few as 768 bits, which
falls well below recommendations from certain standards groups (such as the US
NIST). Some organizations deploying GitLab need to enforce minimum key
strength, either to satisfy internal security policy or for regulatory
compliance.

Similarly, certain standards groups recommend using RSA, ECDSA, ED25519,
ECDSA_SK, or ED25519_SK over the older DSA, and administrators may need to
limit the allowed SSH key algorithms.

GitLab allows you to restrict the allowed SSH key technology as well as specify
the minimum key length for each technology:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General** (`/admin/application_settings/general`).
1. Expand the **Visibility and access controls** section:

   ![SSH keys restriction admin settings](img/ssh_keys_restrictions_settings.png)

If a restriction is imposed on any key type, users cannot upload new SSH keys that don't meet the
requirement. Any existing keys that don't meet it are disabled but not removed and users cannot
pull or push code using them.

An icon is visible to the user of a restricted key in the SSH keys section of their profile:

![Restricted SSH key icon](img/ssh_keys_restricted_key_icon.png)

Hovering over this icon tells you why the key is restricted.

## Default settings

By default, the GitLab.com and self-managed settings for the
[supported key types](../user/ssh.md#supported-ssh-key-types) are:

- RSA SSH keys are allowed.
- DSA SSH keys are forbidden ([since GitLab 11.0](https://about.gitlab.com/releases/2018/06/22/gitlab-11-0-released/#support-for-dsa-ssh-keys)).
- ECDSA SSH keys are allowed.
- ED25519 SSH keys are allowed.
- ECDSA_SK SSH keys are allowed (GitLab 14.8 and later).
- ED25519_SK SSH keys are allowed (GitLab 14.8 and later).

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
