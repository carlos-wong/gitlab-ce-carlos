---
type: reference
---

# Troubleshooting SSL

This page contains a list of common SSL-related errors and scenarios that you may face while working with GitLab.
It should serve as an addition to the main SSL docs available here:

- [Omniibus SSL Configuration](https://docs.gitlab.com/omnibus/settings/ssl.html)
- [Self-signed certificates or custom Certification Authorities for GitLab Runner](https://docs.gitlab.com/runner/configuration/tls-self-signed.html)
- [Manually configuring HTTPS](https://docs.gitlab.com/omnibus/settings/nginx.html#manually-configuring-https)

## Using an internal CA certificate with GitLab

After configuring a GitLab instance with an internal CA certificate, you might not be able to access it via various CLI tools. You may see the following symptoms:

- `curl` fails:

  ```shell
  curl https://gitlab.domain.tld
  curl: (60) SSL certificate problem: unable to get local issuer certificate
  More details here: https://curl.haxx.se/docs/sslcerts.html
  ```

- Testing via the [rails console](https://docs.gitlab.com/omnibus/maintenance/#starting-a-rails-console-session) also fails:

  ```ruby
  uri = URI.parse("https://gitlab.domain.tld")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = 1
  response = http.request(Net::HTTP::Get.new(uri.request_uri))
  ...
  Traceback (most recent call last):
        1: from (irb):5
  OpenSSL::SSL::SSLError (SSL_connect returned=1 errno=0 state=error: certificate verify failed (unable to get local issuer certificate))
  ```

- The error `SSL certificate problem: unable to get local issuer certificate` is shown when setting up a [mirror](../../user/project/repository/repository_mirroring.md#repository-mirroring) from this GitLab instance.
- `openssl` works when specifying the path to the certificate:

  ```shell
  /opt/gitlab/embedded/bin/openssl s_client -CAfile /root/my-cert.crt -connect gitlab.domain.tld:443
  ```

If you have the problems listed above, add your certificate to `/etc/gitlab/trusted-certs` and run `sudo gitlab-ctl reconfigure`.

## Using GitLab Runner with a GitLab instance configured with internal CA certificate or self-signed certificate

Besides getting the errors mentioned in
[Using an internal CA certificate with GitLab](ssl.md#using-an-internal-ca-certificate-with-gitlab),
your CI pipelines may stuck stuck in `Pending` status. In the runner logs you may see the below error:

```shell
Dec  6 02:43:17 runner-host01 gitlab-runner[15131]: #033[0;33mWARNING: Checking for jobs... failed
#033[0;m  #033[0;33mrunner#033[0;m=Bfkz1fyb #033[0;33mstatus#033[0;m=couldn't execute POST against
https://gitlab.domain.tld/api/v4/jobs/request: Post https://gitlab.domain.tld/api/v4/jobs/request:
x509: certificate signed by unknown authority
```

If you face similar problem, add your certificate to `/etc/gitlab-runner/certs` and restart the runner via `gitlab-runner restart`.

## Mirroring a remote GitLab repository that uses a self-signed SSL certificate

**Scenario:** When configuring a local GitLab instance to [mirror a repository](../../user/project/repository/repository_mirroring.md) from a remote GitLab instance that uses a self-signed certificate, you may see the `SSL certificate problem: self signed certificate` error in the UI.

The cause of the issue can be confirmed by checking if:

- `curl` fails:

  ```shell
  $ curl https://gitlab.domain.tld
  curl: (60) SSL certificate problem: self signed certificate
  More details here: https://curl.haxx.se/docs/sslcerts.html
  ```

- Testing via the Rails console also fails:

  ```ruby
  uri = URI.parse("https://gitlab.domain.tld")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = 1
  response = http.request(Net::HTTP::Get.new(uri.request_uri))
  ...
  Traceback (most recent call last):
        1: from (irb):5
  OpenSSL::SSL::SSLError (SSL_connect returned=1 errno=0 state=error: certificate verify failed (unable to get local issuer certificate))
  ```

To fix this problem:

- Add the self-signed certificate from the remote GitLab instance to the `/etc/gitlab/trusted-certs` directory on the local GitLab instance and run `sudo gitlab-ctl reconfigure` as per the instructions for [installing custom public certificates](https://docs.gitlab.com/omnibus/settings/ssl.html#install-custom-public-certificates).
- If your local GitLab instance was installed using the Helm Charts, you can [add your self-signed certificate to your GitLab instance](https://docs.gitlab.com/runner/install/kubernetes.html#providing-a-custom-certificate-for-accessing-gitlab).

You may also get another error when trying to mirror a repository from a remote GitLab instance that uses a self-signed certificate:

```shell
2:Fetching remote upstream failed: fatal: unable to access &amp;#39;https://gitlab.domain.tld/root/test-repo/&amp;#39;:
SSL: unable to obtain common name from peer certificate
```

In this case, the problem can be related to the certificate itself:

- Double check that your self-signed certificate is not missing a common name. If it is then regenerate a valid certificate
- add it to `/etc/gitlab/trusted-certs` and run `sudo gitlab-ctl reconfigure`

## Unable to perform Git operations due to an internal or self-signed certificate

If your GitLab instance is using a self-signed certificate, or the certificate is signed by an internal certificate authority (CA), you might run into the following errors when attempting to perform Git operations:

```shell
$ git clone https://gitlab.domain.tld/group/project.git
Cloning into 'project'...
fatal: unable to access 'https://gitlab.domain.tld/group/project.git/': SSL certificate problem: self signed certificate
```

```shell
$ git clone https://gitlab.domain.tld/group/project.git
Cloning into 'project'...
fatal: unable to access 'https://gitlab.domain.tld/group/project.git/': server certificate verification failed. CAfile: /etc/ssl/certs/ca-certificates.crt CRLfile: none
```

To fix this problem:

- If possible, use SSH remotes for all Git operations. This is considered more secure and convenient to use.
- If you must use HTTPS remotes, you can try the following:
  - Copy the self signed certificate or the internal root CA certificate to a local directory (for example, `~/.ssl`) and configure Git to trust your certificate:

    ```shell
    git config --global http.sslCAInfo ~/.ssl/gitlab.domain.tld.crt
    ```

  - Disable SSL verification in your Git client. Note that this intended as a temporary measure as it could be considered a **security risk**.

    ```shell
    git config --global http.sslVerify false
    ```
