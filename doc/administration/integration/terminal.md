# Web terminals

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/7690)
in GitLab 8.15. Only project maintainers and owners can access web terminals.

With the introduction of the [Kubernetes integration](../../user/project/clusters/index.md),
GitLab gained the ability to store and use credentials for a Kubernetes cluster.
One of the things it uses these credentials for is providing access to
[web terminals](../../ci/environments.md#web-terminals) for environments.

## How it works

A detailed overview of the architecture of web terminals and how they work
can be found in [this document](https://gitlab.com/gitlab-org/gitlab-workhorse/blob/master/doc/channel.md).
In brief:

- GitLab relies on the user to provide their own Kubernetes credentials, and to
  appropriately label the pods they create when deploying.
- When a user navigates to the terminal page for an environment, they are served
  a JavaScript application that opens a WebSocket connection back to GitLab.
- The WebSocket is handled in [Workhorse](https://gitlab.com/gitlab-org/gitlab-workhorse),
   rather than the Rails application server.
- Workhorse queries Rails for connection details and user permissions. Rails
  queries Kubernetes for them in the background using [Sidekiq](../troubleshooting/sidekiq.md).
- Workhorse acts as a proxy server between the user's browser and the Kubernetes
  API, passing WebSocket frames between the two.
- Workhorse regularly polls Rails, terminating the WebSocket connection if the
  user no longer has permission to access the terminal, or if the connection
  details have changed.

## Security

GitLab and [GitLab Runner](https://docs.gitlab.com/runner/) take some
precautions to keep interactive web terminal data encrypted between them, and
everything protected with authorization guards. This is described in more
detail below.

- Interactive web terminals are completely disabled unless [`[session_server]`](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-session_server-section) is configured.
- Every time the runner starts, it will generate an `x509` certificate that will be used for a `wss` (Web Socket Secure) connection.
- For every created job, a random URL is generated which is discarded at the end of the job. This URL is used to establish a web socket connection. The URL for the session is in the format `(IP|HOST):PORT/session/$SOME_HASH`, where the `IP/HOST` and `PORT` are the configured [`listen_address`](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-session_server-section).
- Every session URL that is created has an authorization header that needs to be sent, to establish a `wss` connection.
- The session URL is not exposed to the users in any way. GitLab holds all the state internally and proxies accordingly.

## Enabling and disabling terminal support

NOTE: **Note:** AWS Elastic Load Balancers (ELBs) do not support web sockets.
AWS Application Load Balancers (ALBs) must be used if you want web terminals
to work. See [AWS Elastic Load Balancing Product Comparison](https://aws.amazon.com/elasticloadbalancing/features/#compare)
for more information.

As web terminals use WebSockets, every HTTP/HTTPS reverse proxy in front of
Workhorse needs to be configured to pass the `Connection` and `Upgrade` headers
through to the next one in the chain. If you installed GitLab using Omnibus, or
from source, starting with GitLab 8.15, this should be done by the default
configuration, so there's no need for you to do anything.

However, if you run a [load balancer](../high_availability/load_balancer.md) in
front of GitLab, you may need to make some changes to your configuration. These
guides document the necessary steps for a selection of popular reverse proxies:

- [Apache](https://httpd.apache.org/docs/2.4/mod/mod_proxy_wstunnel.html)
- [NGINX](https://www.nginx.com/blog/websocket-nginx/)
- [HAProxy](https://www.haproxy.com/blog/websockets-load-balancing-with-haproxy/)
- [Varnish](https://varnish-cache.org/docs/4.1/users-guide/vcl-example-websockets.html)

Workhorse won't let WebSocket requests through to non-WebSocket endpoints, so
it's safe to enable support for these headers globally. If you'd rather had a
narrower set of rules, you can restrict it to URLs ending with `/terminal.ws`
(although this may still have a few false positives).

If you installed from source, or have made any configuration changes to your
Omnibus installation before upgrading to 8.15, you may need to make some changes
to your configuration. See the [Upgrading Community Edition and Enterprise
Edition from source](../../update/upgrading_from_source.md#nginx-configuration)
document for more details.

If you'd like to disable web terminal support in GitLab, just stop passing
the `Connection` and `Upgrade` hop-by-hop headers in the *first* HTTP reverse
proxy in the chain. For most users, this will be the NGINX server bundled with
Omnibus GitLab, in which case, you need to:

- Find the `nginx['proxy_set_headers']` section of your `gitlab.rb` file
- Ensure the whole block is uncommented, and then comment out or remove the
  `Connection` and `Upgrade` lines.

For your own load balancer, just reverse the configuration changes recommended
by the above guides.

When these headers are not passed through, Workhorse will return a
`400 Bad Request` response to users attempting to use a web terminal. In turn,
they will receive a `Connection failed` message.

## Limiting WebSocket connection time

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/8413)
in GitLab 8.17.

Terminal sessions use long-lived connections; by default, these may last
forever. You can configure a maximum session time in the Admin Area of your
GitLab instance if you find this undesirable from a scalability or security
point of view.
