---
type: concepts
---

# DNS records overview

_Read this document for a brief overview of DNS records in the scope
of GitLab Pages, for beginners in web development._

A Domain Name System (DNS) web service routes visitors to websites
by translating domain names (such as `www.example.com`) into the
numeric IP addresses (such as `192.0.2.1`) that computers use to
connect to each other.

A DNS record is created to point a (sub)domain to a certain location,
which can be an IP address or another domain. In case you want to use
GitLab Pages with your own (sub)domain, you need to access your domain's
registrar control panel to add a DNS record pointing it back to your
GitLab Pages site.

Note that **how to** add DNS records depends on which server your domain
is hosted on. Every control panel has its own place to do it. If you are
not an admin of your domain, and don't have access to your registrar,
you'll need to ask for the technical support of your hosting service
to do it for you.

To help you out, we've gathered some instructions on how to do that
for the most popular hosting services:

- [Amazon](https://docs.aws.amazon.com/AmazonS3/latest/dev/website-hosting-custom-domain-walkthrough.html)
- [Bluehost](https://my.bluehost.com/cgi/help/559)
- [CloudFlare](https://support.cloudflare.com/hc/en-us/articles/200169096-How-do-I-add-A-records-)
- [cPanel](https://documentation.cpanel.net/display/84Docs/Edit+DNS+Zone)
- [DreamHost](https://help.dreamhost.com/hc/en-us/articles/215414867-How-do-I-add-custom-DNS-records-)
- [Go Daddy](https://www.godaddy.com/help/add-an-a-record-19238)
- [Hostgator](https://www.hostgator.com/help/article/changing-dns-records)
- [Inmotion hosting](https://my.bluehost.com/cgi/help/559)
- [Media Temple](https://mediatemple.net/community/products/dv/204403794/how-can-i-change-the-dns-records-for-my-domain)
- [Microsoft](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/bb727018(v=technet.10))

If your hosting service is not listed above, you can just try to
search the web for `how to add dns record on <my hosting service>`.

## `A` record

A DNS A record maps a host to an IPv4 IP address.
It points a root domain as `example.com` to the host's IP address as
`192.192.192.192`.

Example:

- `example.com` => `A` => `192.192.192.192`

## CNAME record

CNAME records define an alias for canonical name for your server (one defined
by an A record). It points a subdomain to another domain.

Example:

- `www` => `CNAME` => `example.com`

This way, visitors visiting `www.example.com` will be redirected to
`example.com`.

## MX record

MX records are used to define the mail exchanges that are used for the domain.
This helps email messages arrive at your mail server correctly.

Example:

- `MX` => `mail.example.com`

Then you can register emails for `users@mail.example.com`.

## TXT record

A `TXT` record can associate arbitrary text with a host or other name. A common
use is for site verification.

Example:

- `example.com`=> TXT => `"google-site-verification=6P08Ow5E-8Q0m6vQ7FMAqAYIDprkVV8fUf_7hZ4Qvc8"`

This way, you can verify the ownership for that domain name.

## All combined

You can have one DNS record or more than one combined:

- `example.com` => `A` => `192.192.192.192`
- `www` => `CNAME` => `example.com`
- `MX` => `mail.example.com`
- `example.com`=> TXT => `"google-site-verification=6P08Ow5E-8Q0m6vQ7FMAqAYIDprkVV8fUf_7hZ4Qvc8"`
