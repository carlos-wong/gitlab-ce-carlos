---
type: concepts, howto
---

# Signing commits with x509

[x509](https://en.wikipedia.org/wiki/X.509) is a standard format for public key
certificates issued by a public or private Public Key Infrastructure (PKI).
Personal x509 certificates are used for authentication or signing purposes
such as SMIME, but Git also supports signing of commits and tags
with x509 certificates in a similar way as with [GPG](../gpg_signed_commits/index.md).
The main difference is the trust anchor which is the PKI for x509 certificates
instead of a web of trust with GPG.

## How GitLab handles x509

GitLab uses its own certificate store and therefore defines the trust chain.

For a commit to be *verified* by GitLab:

- The signing certificate email must match a verified email address used by the committer in GitLab.
- The Certificate Authority has to be trusted by the GitLab instance, see also
  [Omnibus install custom public certificates](https://docs.gitlab.com/omnibus/settings/ssl.html#install-custom-public-certificates).
- The signing time has to be within the time range of the [certificate validity](https://www.rfc-editor.org/rfc/rfc5280.html#section-4.1.2.5)
  which is usually up to three years.
- The signing time is equal or later then commit time.

NOTE: **Note:** There is no certificate revocation list check in place at the moment.

## Obtaining an x509 key pair

If your organization has Public Key Infrastructure (PKI), that PKI will provide
an S/MIME key.

If you do not have an S/MIME key pair from a PKI, you can either create your
own self-signed one, or purchase one. MozillaZine keeps a nice collection
of [S/MIME-capable signing authorities](http://kb.mozillazine.org/Getting_an_SMIME_certificate)
and some of them generate keys for free.

## Associating your x509 certificate with Git

To take advantage of X509 signing, you will need Git 2.19.0 or later. You can
check your Git version with:

```sh
git --version
```

If you have the correct version, you can proceed to configure Git.

### Linux

Configure Git to use your key for signing:

```sh
signingkey = $( gpgsm --list-secret-keys | egrep '(key usage|ID)' | grep -B 1 digitalSignature | awk '/ID/ {print $2}' )
git config --global user.signingkey $signingkey
git config --global gpg.format x509
```

### Windows and MacOS

Install [smimesign](https://github.com/github/smimesign) by downloading the
installer or via `brew install smimesign` on MacOS.

Get the ID of your certificate with `smimesign --list-keys` and set your
signingkey `git config --global user.signingkey ID`, then configure x509:

```sh
git config --global gpg.x509.program smimesign
git config --global gpg.format x509
```

## Signing commits

After you have [associated your x509 certificate with Git](#associating-your-x509-certificate-with-git) you
can start signing your commits:

1. Commit like you used to, the only difference is the addition of the `-S` flag:

   ```sh
   git commit -S -m "feat: x509 signed commits"
   ```

1. Push to GitLab and check that your commits [are verified](#verifying-commits).

If you don't want to type the `-S` flag every time you commit, you can tell Git
to sign your commits automatically:

```sh
git config --global commit.gpgsign true
```

## Verifying commits

To verify that a commit is signed, you can use the `--show-signature` flag:

```sh
git log --show-signature
```
