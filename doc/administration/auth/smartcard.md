---
type: reference
---

# Smartcard authentication **(PREMIUM ONLY)**

GitLab supports authentication using smartcards.

## Authentication methods

GitLab supports two authentication methods:

- X.509 certificates with local databases.
- LDAP servers.

### Authentication against a local database with X.509 certificates

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/726) in
[GitLab Premium](https://about.gitlab.com/pricing/) 11.6 as an experimental
feature. Smartcard authentication against local databases may change or be
removed completely in future releases.

Smartcards with X.509 certificates can be used to authenticate with GitLab.

To use a smartcard with an X.509 certificate to authenticate against a local
database with GitLab, `CN` and `emailAddress` must be defined in the
certificate. For example:

```text
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 12856475246677808609 (0xb26b601ecdd555e1)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: O=Random Corp Ltd, CN=Random Corp
        Validity
            Not Before: Oct 30 12:00:00 2018 GMT
            Not After : Oct 30 12:00:00 2019 GMT
        Subject: CN=Gitlab User, emailAddress=gitlab-user@example.com
```

### Authentication against a local database with X.509 certificates and SAN extensions **(PREMIUM ONLY)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/8605) in [GitLab Premium](https://about.gitlab.com/pricing/) 12.3.

Smartcards with X.509 certificates using SAN extensions can be used to authenticate
with GitLab.

NOTE: **Note:**
This is an experimental feature. Smartcard authentication against local databases may
change or be removed completely in future releases.

To use a smartcard with an X.509 certificate to authenticate against a local
database with GitLab, at least one of the `subjectAltName` (SAN) extensions
need to define the user identity (`email`) within the GitLab instance (`URI`).

`URI`: needs to match `Gitlab.config.host.gitlab`.

For example:

```text
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 12856475246677808609 (0xb26b601ecdd555e1)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: O=Random Corp Ltd, CN=Random Corp
        Validity
            Not Before: Oct 30 12:00:00 2018 GMT
            Not After : Oct 30 12:00:00 2019 GMT
        ...
        X509v3 extensions:
            X509v3 Key Usage:
                Key Encipherment, Data Encipherment
            X509v3 Extended Key Usage:
                TLS Web Server Authentication
            X509v3 Subject Alternative Name:
                email:gitlab-user@example.com, URI:http://gitlab.example.com/
```

### Authentication against an LDAP server

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/7693) in
[GitLab Premium](https://about.gitlab.com/pricing/) 11.8 as an experimental
feature. Smartcard authentication against an LDAP server may change or be
removed completely in future releases.

GitLab implements a standard way of certificate matching following
[RFC4523](https://tools.ietf.org/html/rfc4523). It uses the
`certificateExactMatch` certificate matching rule against the `userCertificate`
attribute. As a prerequisite, you must use an LDAP server that:

- Supports the `certificateExactMatch` matching rule.
- Has the certificate stored in the `userCertificate` attribute.

## Configure GitLab for smartcard authentication

**For Omnibus installations**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['smartcard_enabled'] = true
   gitlab_rails['smartcard_ca_file'] = "/etc/ssl/certs/CA.pem"
   gitlab_rails['smartcard_client_certificate_required_port'] = 3444
   ```

1. Save the file and [reconfigure](../restart_gitlab.md#omnibus-gitlab-reconfigure)
   GitLab for the changes to take effect.

---

**For installations from source**

1. Configure NGINX to request a client side certificate

   In NGINX configuration, an **additional** server context must be defined with
   the same configuration except:

   - The additional NGINX server context must be configured to run on a different
     port:

     ```
     listen *:3444 ssl;
     ```

   - The additional NGINX server context must be configured to require the client
     side certificate:

     ```
     ssl_verify_depth 2;
     ssl_client_certificate /etc/ssl/certs/CA.pem;
     ssl_verify_client on;
     ```

   - The additional NGINX server context must be configured to forward the client
     side certificate:

     ```
     proxy_set_header    X-SSL-Client-Certificate    $ssl_client_escaped_cert;
     ```

   For example, the following is an example server context in an NGINX
   configuration file (eg. in `/etc/nginx/sites-available/gitlab-ssl`):

   ```
   server {
       listen *:3444 ssl;

       # certificate for configuring SSL
       ssl_certificate /path/to/example.com.crt;
       ssl_certificate_key /path/to/example.com.key;

       ssl_verify_depth 2;
       # CA certificate for client side certificate verification
       ssl_client_certificate /etc/ssl/certs/CA.pem;
       ssl_verify_client on;

       location / {
           proxy_set_header    Host                        $http_host;
           proxy_set_header    X-Real-IP                   $remote_addr;
           proxy_set_header    X-Forwarded-For             $proxy_add_x_forwarded_for;
           proxy_set_header    X-Forwarded-Proto           $scheme;
           proxy_set_header    Upgrade                     $http_upgrade;
           proxy_set_header    Connection                  $connection_upgrade;

           proxy_set_header    X-SSL-Client-Certificate    $ssl_client_escaped_cert;

           proxy_read_timeout 300;

           proxy_pass http://gitlab-workhorse;
       }
   }
   ```

1. Edit `config/gitlab.yml`:

   ```yaml
   ## Smartcard authentication settings
   smartcard:
     # Allow smartcard authentication
     enabled: true

     # Path to a file containing a CA certificate
     ca_file: '/etc/ssl/certs/CA.pem'

     # Port where the client side certificate is requested by NGINX
     client_certificate_required_port: 3444
   ```

1. Save the file and [restart](../restart_gitlab.md#installations-from-source)
   GitLab for the changes to take effect.

### Additional steps when using SAN extensions

**For Omnibus installations**

1. Add to `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['smartcard_san_extensions'] = true
   ```

1. Save the file and [reconfigure](../restart_gitlab.md#omnibus-gitlab-reconfigure)
   GitLab for the changes to take effect.

**For installations from source**

1. Add the `san_extensions` line to config/gitlab.yml` within the smartcard section:

   ```yaml
   smartcard:
      enabled: true
      ca_file: '/etc/ssl/certs/CA.pem'
      client_certificate_required_port: 3444

      # Enable the use of SAN extensions to match users with certificates
      san_extensions: true
   ```

1. Save the file and [restart](../restart_gitlab.md#installations-from-source)
   GitLab for the changes to take effect.

### Additional steps when authenticating against an LDAP server

**For Omnibus installations**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['ldap_servers'] = YAML.load <<-EOS
   main:
     # snip...
     # Enable smartcard authentication against the LDAP server. Valid values
     # are "false", "optional", and "required".
     smartcard_auth: optional
   EOS
   ```

1. Save the file and [reconfigure](../restart_gitlab.md#omnibus-gitlab-reconfigure)
   GitLab for the changes to take effect.

**For installations from source**

1. Edit `config/gitlab.yml`:

   ```yaml
   production:
     ldap:
       servers:
         main:
           # snip...
           # Enable smartcard authentication against the LDAP server. Valid values
           # are "false", "optional", and "required".
           smartcard_auth: optional
   ```

1. Save the file and [restart](../restart_gitlab.md#installations-from-source)
   GitLab for the changes to take effect.

### Require browser session with smartcard sign-in for Git access

**For Omnibus installations**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['smartcard_required_for_git_access'] = true
   ```

1. Save the file and [reconfigure](../restart_gitlab.md#omnibus-gitlab-reconfigure)
   GitLab for the changes to take effect.

**For installations from source**

1. Edit `config/gitlab.yml`:

   ```yaml
   ## Smartcard authentication settings
   smartcard:
     # snip...
     # Browser session with smartcard sign-in is required for Git access
     required_for_git_access: true
   ```

1. Save the file and [restart](../restart_gitlab.md#installations-from-source)
   GitLab for the changes to take effect.

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
