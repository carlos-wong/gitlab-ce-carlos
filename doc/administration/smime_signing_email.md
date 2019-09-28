# Signing outgoing email with S/MIME

Notification emails sent by Gitlab can be signed with S/MIME for improved
security.

> **Note:**
Please be aware that S/MIME certificates and TLS/SSL certificates are not the
same and are used for different purposes: TLS creates a secure channel, whereas
S/MIME signs and/or encrypts the message itself

## Enable S/MIME signing

This setting must be explicitly enabled and a single pair of key and certificate
files must be provided:

- Both files must be PEM-encoded.
- The key file must be unencrypted so that GitLab can read it without user
  intervention.
- Only RSA keys are supported.

NOTE: **Note:** Be mindful of the access levels for your private keys and visibility to
third parties.

**For Omnibus installations:**

1. Edit `/etc/gitlab/gitlab.rb` and adapt the file paths:

   ```ruby
   gitlab_rails['gitlab_email_smime_enabled'] = true
   gitlab_rails['gitlab_email_smime_key_file'] = '/etc/gitlab/ssl/gitlab_smime.key'
   gitlab_rails['gitlab_email_smime_cert_file'] = '/etc/gitlab/ssl/gitlab_smime.crt'
   ```

1. Save the file and [reconfigure GitLab](restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

NOTE: **Note:** The key needs to be readable by the GitLab system user (`git` by default).

**For installations from source:**

1. Edit `config/gitlab.yml`:

   ```yaml
   email_smime:
     # Uncomment and set to true if you need to enable email S/MIME signing (default: false)
     enabled: true
     # S/MIME private key file in PEM format, unencrypted
     # Default is '.gitlab_smime_key' relative to Rails.root (i.e. root of the GitLab app).
     key_file: /etc/pki/smime/private/gitlab.key
     # S/MIME public certificate key in PEM format, will be attached to signed messages
     # Default is '.gitlab_smime_cert' relative to Rails.root (i.e. root of the GitLab app).
     cert_file: /etc/pki/smime/certs/gitlab.crt
   ```

1. Save the file and [restart GitLab](restart_gitlab.md#installations-from-source) for the changes to take effect.

NOTE: **Note:** The key needs to be readable by the GitLab system user (`git` by default).

### How to convert S/MIME PKCS#12 / PFX format to PEM encoding

Typically S/MIME certificates are handled in binary PKCS#12 format (`.pfx` or `.p12`
extensions), which contain the following in a single encrypted file:

- Public certificate
- Intermediate certificates (if any)
- Private key

In order to export the required files in PEM encoding from the PKCS#12 file,
the `openssl` command can be used:

```bash
#-- Extract private key in PEM encoding (no password, unencrypted)
$ openssl pkcs12 -in gitlab.p12 -nocerts -nodes -out gitlab.key

#-- Extract certificates in PEM encoding (full certs chain including CA)
$ openssl pkcs12 -in gitlab.p12 -nokeys -out gitlab.crt
```
