---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Running tests that require special setup

## Jenkins spec

The [`jenkins_build_status_spec`](https://gitlab.com/gitlab-org/gitlab/-/blob/163c8a8c814db26d11e104d1cb2dcf02eb567dbe/qa/qa/specs/features/ee/browser_ui/3_create/jenkins/jenkins_build_status_spec.rb) spins up a Jenkins instance in a Docker container based on an image stored in the [GitLab-QA container registry](https://gitlab.com/gitlab-org/gitlab-qa/container_registry).
The Docker image it uses is preconfigured with some base data and plugins.
The test then configures the GitLab plugin in Jenkins with a URL of the GitLab instance that are used
to run the tests. Unfortunately, the GitLab Jenkins plugin does not accept ports so `http://localhost:3000` would
not be accepted. Therefore, this requires us to run GitLab on port 80 or inside a Docker container.

To start a Docker container for GitLab based on the nightly image:

```shell
docker run \
  --publish 80:80 \
  --name gitlab \
  --hostname localhost \
  gitlab/gitlab-ee:nightly
```

To run the tests from the `/qa` directory:

```shell
WEBDRIVER_HEADLESS=false bin/qa Test::Instance::All http://localhost -- qa/specs/features/ee/browser_ui/3_create/jenkins/jenkins_build_status_spec.rb
```

The test automatically spins up a Docker container for Jenkins and tear down once the test completes.

However, if you need to run Jenkins manually outside of the tests, use this command:

```shell
docker run \
  --hostname localhost \
  --name jenkins-server \
  --env JENKINS_HOME=jenkins_home \
  --publish 8080:8080 \
  registry.gitlab.com/gitlab-org/gitlab-qa/jenkins-gitlab:version1
```

Jenkins is available on `http://localhost:8080`.

Administrator username is `admin` and password is `password`.

It is worth noting that this is not an orchestrated test. It is [tagged with the `:orchestrated` meta](https://gitlab.com/gitlab-org/gitlab/-/blob/163c8a8c814db26d11e104d1cb2dcf02eb567dbe/qa/qa/specs/features/ee/browser_ui/3_create/jenkins/jenkins_build_status_spec.rb#L5)
only to prevent it from running in the pipelines for live environments such as Staging.

### Troubleshooting

If Jenkins Docker container exits without providing any information in the logs, try increasing the memory used by
the Docker Engine.

## Gitaly Cluster tests

The tests tagged `:gitaly_ha` are orchestrated tests that can only be run against a set of Docker containers as configured and started by [the `Test::Integration::GitalyCluster` GitLab QA scenario](https://gitlab.com/gitlab-org/gitlab-qa/-/blob/master/docs/what_tests_can_be_run.md#testintegrationgitalycluster-ceeefull-image-address).

As described in the documentation about the scenario noted above, the following command runs the tests:

```shell
gitlab-qa Test::Integration::GitalyCluster EE
```

However, that removes the containers after it finishes running the tests. If you would like to do further testing, for example, if you would like to run a single test via a debugger, you can use [the `--no-tests` option](https://gitlab.com/gitlab-org/gitlab-qa#command-line-options) to make `gitlab-qa` skip running the tests, and to leave the containers running so that you can continue to use them.

```shell
gitlab-qa Test::Integration::GitalyCluster EE --no-tests
```

When all the containers are running, the output of the `docker ps` command shows which ports the GitLab container can be accessed on. For example:

```plaintext
CONTAINER ID   ...     PORTS                                    NAMES
d15d3386a0a8   ...     22/tcp, 443/tcp, 0.0.0.0:32772->80/tcp   gitlab-gitaly-cluster
```

That shows that the GitLab instance running in the `gitlab-gitaly-cluster` container can be reached via `http://localhost:32772`. However, Git operations like cloning and pushing are performed against the URL revealed via the UI as the clone URL. It uses the hostname configured for the GitLab instance, which in this case matches the Docker container name and network, `gitlab-gitaly-cluster.test`. Before you can run the tests you need to configure your computer to access the container via that address. One option is to [use Caddy server as described for running tests against GDK](https://gitlab.com/gitlab-org/gitlab-qa/-/blob/master/docs/run_qa_against_gdk.md#workarounds).

Another option is to use NGINX.

In both cases you must configure your machine to translate `gitlab-gitaly-cluster.test` into an appropriate IP address:

```shell
echo '127.0.0.1 gitlab-gitaly-cluster.test' | sudo tee -a /etc/hosts
```

Then install NGINX:

```shell
# on macOS
brew install nginx

# on Debian/Ubuntu
apt install nginx

# on Fedora
yum install nginx
```

Finally, configure NGINX to pass requests for `gitlab-gitaly-cluster.test` to the GitLab instance:

```plaintext
# On Debian/Ubuntu, in /etc/nginx/sites-enabled/gitlab-cluster
# On macOS, in /usr/local/etc/nginx/nginx.conf

server {
  server_name gitlab-gitaly-cluster.test;
  client_max_body_size 500m;

  location / {
    proxy_pass http://127.0.0.1:32772;
    proxy_set_header Host gitlab-gitaly-cluster.test;
  }
}
```

Restart NGINX for the configuration to take effect. For example:

```shell
# On Debian/Ubuntu
sudo systemctl restart nginx

# on macOS
sudo nginx -s reload
```

You could then run the tests from the `/qa` directory:

```shell
WEBDRIVER_HEADLESS=false bin/qa Test::Instance::All http://gitlab-gitaly-cluster.test -- --tag gitaly_cluster
```

Once you have finished testing you can stop and remove the Docker containers:

```shell
docker stop gitlab-gitaly-cluster praefect postgres gitaly3 gitaly2 gitaly1
docker rm gitlab-gitaly-cluster praefect postgres gitaly3 gitaly2 gitaly1
```

## Tests that require a runner

To execute tests that use a runner without errors, while creating the GitLab Docker instance the `--hostname` parameter in the Docker `run` command should be given a specific interface IP address or a non-loopback hostname accessible from the runner container. Having `localhost` (or `127.0.0.1`) as the GitLab hostname won't work (unless the GitLab Runner is created with the Docker network as `host`)

Examples of tests which require a runner:

- `qa/qa/specs/features/ee/browser_ui/13_secure/create_merge_request_with_secure_spec.rb`
- `qa/qa/specs/features/browser_ui/4_verify/runner/register_runner_spec.rb`

Example:

```shell
docker run \ 
  --detach \
  --hostname interface_ip_address \
  --publish 80:80 \
  --name gitlab \
  --restart always \
  --volume ~/ee_volume/config:/etc/gitlab \
  --volume ~/ee_volume/logs:/var/log/gitlab \
  --volume ~/ee_volume/data:/var/opt/gitlab \
  --shm-size 256m \
  gitlab/gitlab-ee:latest
```

Where `interface_ip_address` is your local network's interface IP, which you can find with the `ifconfig` command.
The same would apply to GDK running with the instance address as `localhost` too.

## Geo tests

Geo end-to-end tests can run locally against a [Geo GDK setup](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/geo.md) or on Geo spun up in Docker containers.

### Using Geo GDK

Run from the [`qa/` directory](https://gitlab.com/gitlab-org/gitlab/-/blob/f7272b77e80215c39d1ffeaed27794c220dbe03f/qa) with both GDK Geo primary and Geo secondary instances running:

```shell
WEBDRIVER_HEADLESS=false bundle exec bin/qa QA::EE::Scenario::Test::Geo --primary-address http://localhost:3001 --secondary-address http://localhost:3002 --without-setup
```

### Using Geo in Docker

You can use [GitLab-QA Orchestrator](https://gitlab.com/gitlab-org/gitlab-qa) to orchestrate two GitLab containers and configure them as a Geo setup.

Geo requires an EE license. To visit the Geo sites in your browser, you need a reverse proxy server (for example, [NGINX](https://www.nginx.com/)).

1. Export your EE license

   ```shell
   export EE_LICENSE=$(cat <path/to/your/gitlab_license>)
   ```

1. Optional. Pull the GitLab image

   This step is optional because pulling the Docker image is part of the [`Test::Integration::Geo` orchestrated scenario](https://gitlab.com/gitlab-org/gitlab-qa/-/blob/d8c5c40607c2be0eda58bbca1b9f534b00889a0b/lib/gitlab/qa/scenario/test/integration/geo.rb). However, it's easier to monitor the download progress if you pull the image first, and the scenario skips this step after checking that the image is up to date.

   ```shell
   # For the most recent nightly image
   docker pull gitlab/gitlab-ee:nightly

   # For a specific release
   docker pull gitlab/gitlab-ee:13.0.10-ee.0

   # For a specific image
   docker pull registry.gitlab.com/gitlab-org/build/omnibus-gitlab-mirror/gitlab-ee:examplesha123456789
   ```

1. Run the [`Test::Integration::Geo` orchestrated scenario](https://gitlab.com/gitlab-org/gitlab-qa/-/blob/d8c5c40607c2be0eda58bbca1b9f534b00889a0b/lib/gitlab/qa/scenario/test/integration/geo.rb) with the `--no-teardown` option to build the GitLab containers, configure the Geo setup, and run Geo end-to-end tests. Running the tests after the Geo setup is complete is optional; the containers keep running after you stop the tests.

   ```shell
   # Using the most recent nightly image
   gitlab-qa Test::Integration::Geo EE --no-teardown

   # Using a specific GitLab release
   gitlab-qa Test::Integration::Geo EE:13.0.10-ee.0 --no-teardown

   # Using a full image address
   GITLAB_QA_ACCESS_TOKEN=your-token-here gitlab-qa Test::Integration::Geo registry.gitlab.com/gitlab-org/build/omnibus-gitlab-mirror/gitlab-ee:examplesha123456789 --no-teardown
    ```

   You can use the `--no-tests` option to build the containers only, and then run the [`EE::Scenario::Test::Geo` scenario](https://gitlab.com/gitlab-org/gitlab/-/blob/f7272b77e80215c39d1ffeaed27794c220dbe03f/qa/qa/ee/scenario/test/geo.rb) from your GDK to complete setup and run tests. However, there might be configuration issues if your GDK and the containers are based on different GitLab versions. With the `--no-teardown` option, GitLab-QA uses the same GitLab version for the GitLab containers and the GitLab QA container used to configure the Geo setup.

1. To visit the Geo sites in your browser, proxy requests to the hostnames used inside the containers. NGINX is used as the reverse proxy server for this example.

   _Map the hostnames to the local IP in `/etc/hosts` file on your machine:_

   ```plaintext
   127.0.0.1 gitlab-primary.geo gitlab-secondary.geo
   ```

   _Note the assigned ports:_

   ```shell
   $ docker port gitlab-primary

   80/tcp -> 0.0.0.0:32768

   $ docker port gitlab-secondary

   80/tcp -> 0.0.0.0:32769
   ```

   _Configure the reverse proxy server with the assigned ports in `nginx.conf` file (usually found in `/usr/local/etc/nginx` on a Mac):_

   ```plaintext
   server {
     server_name gitlab-primary.geo;
     location / {
       proxy_pass http://localhost:32768; # Change port to your assigned port
       proxy_set_header Host gitlab-primary.geo;
     }
   }

   server {
     server_name gitlab-secondary.geo;
     location / {
       proxy_pass http://localhost:32769; # Change port to your assigned port
       proxy_set_header Host gitlab-secondary.geo;
     }
   }
   ```

   _Start or reload the reverse proxy server:_

   ```shell
   sudo nginx
   # or
   sudo nginx -s reload
   ```

1. To run end-to-end tests from your local GDK, run the [`EE::Scenario::Test::Geo` scenario](https://gitlab.com/gitlab-org/gitlab/-/blob/f7272b77e80215c39d1ffeaed27794c220dbe03f/qa/qa/ee/scenario/test/geo.rb) from the [`gitlab/qa/` directory](https://gitlab.com/gitlab-org/gitlab/-/blob/f7272b77e80215c39d1ffeaed27794c220dbe03f/qa). Include `--without-setup` to skip the Geo configuration steps.

   ```shell
   QA_DEBUG=true GITLAB_QA_ACCESS_TOKEN=[add token here] GITLAB_QA_ADMIN_ACCESS_TOKEN=[add token here] bundle exec bin/qa QA::EE::Scenario::Test::Geo \
   --primary-address http://gitlab-primary.geo \
   --secondary-address http://gitlab-secondary.geo \
   --without-setup
   ```

   If the containers need to be configured first (for example, if you used the `--no-tests` option in the previous step), run the `QA::EE::Scenario::Test::Geo scenario` as shown below to first do the Geo configuration steps, and then run Geo end-to-end tests. Make sure that `EE_LICENSE` is (still) defined in your shell session.

   ```shell
   QA_DEBUG=true bundle exec bin/qa QA::EE::Scenario::Test::Geo \
   --primary-address http://gitlab-primary.geo \
   --primary-name gitlab-primary \
   --secondary-address http://gitlab-secondary.geo \
   --secondary-name gitlab-secondary
   ```

1. Stop and remove containers

   ```shell
   docker stop gitlab-primary gitlab-secondary
   docker rm gitlab-primary gitlab-secondary
   ```

#### Notes

- You can find the full image address from a pipeline by [following these instructions](https://about.gitlab.com/handbook/engineering/quality/quality-engineering/tips-and-tricks/#running-gitlab-qa-pipeline-against-a-specific-gitlab-release). You might be prompted to set the `GITLAB_QA_ACCESS_TOKEN` variable if you specify the full image address.
- You can increase the wait time for replication by setting `GEO_MAX_FILE_REPLICATION_TIME` and `GEO_MAX_DB_REPLICATION_TIME`. The default is 120 seconds.
- To save time during tests, create a Personal Access Token with API access on the Geo primary node, and pass that value in as `GITLAB_QA_ACCESS_TOKEN` and `GITLAB_QA_ADMIN_ACCESS_TOKEN`.

## LDAP Tests

Tests that are tagged with `:ldap_tls` and `:ldap_no_tls` meta are orchestrated tests where the sign-in happens via LDAP.

These tests spin up a Docker container [(`osixia/openldap`)](https://hub.docker.com/r/osixia/openldap) running an instance of [OpenLDAP](https://www.openldap.org/).
The container uses fixtures [checked into the GitLab-QA repository](https://gitlab.com/gitlab-org/gitlab-qa/-/tree/9ffb9ad3be847a9054967d792d6772a74220fb42/fixtures/ldap) to create
base data such as users and groups including the administrator group. The password for [all users](https://gitlab.com/gitlab-org/gitlab-qa/-/blob/9ffb9ad3be847a9054967d792d6772a74220fb42/fixtures/ldap/2_add_users.ldif) including [the `tanuki` user](https://gitlab.com/gitlab-org/gitlab-qa/-/blob/9ffb9ad3be847a9054967d792d6772a74220fb42/fixtures/ldap/tanuki.ldif) is `password`.

A GitLab instance is also created in a Docker container based on our [LDAP setup](../../../administration/auth/ldap/index.md) documentation.

Tests that are tagged `:ldap_tls` enable TLS on GitLab using the certificate [checked into the GitLab-QA repository](https://gitlab.com/gitlab-org/gitlab-qa/-/tree/9ffb9ad3be847a9054967d792d6772a74220fb42/tls_certificates/gitlab).

The certificate was generated with OpenSSL using this command:

```shell
openssl req -x509 -newkey rsa:4096 -keyout gitlab.test.key -out gitlab.test.crt -days 3650 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=GitLab/OU=Org/CN=gitlab.test"
```

The OpenLDAP container also uses its [auto-generated TLS certificates](https://github.com/osixia/docker-openldap#use-auto-generated-certificate).

### Running LDAP tests with TLS enabled

To run the LDAP tests on your local with TLS enabled, follow these steps:

1. Include the following entry in your `/etc/hosts` file:

   `127.0.0.1    gitlab.test`

   You can then run tests against GitLab in a Docker container on `https://gitlab.test`. The TLS certificate [checked into the GitLab-QA repository](https://gitlab.com/gitlab-org/gitlab-qa/-/tree/9ffb9ad3be847a9054967d792d6772a74220fb42/tls_certificates/gitlab) is configured for this domain.
1. Run the OpenLDAP container with TLS enabled. Change the path to [`gitlab-qa/fixtures/ldap`](https://gitlab.com/gitlab-org/gitlab-qa/-/tree/9ffb9ad3be847a9054967d792d6772a74220fb42/fixtures/ldap) directory to your local checkout path:

   ```shell
   docker network create test && docker run --name ldap-server --net test --hostname ldap-server.test --volume /path/to/gitlab-qa/fixtures/ldap:/container/service/slapd/assets/config/bootstrap/ldif/custom:Z --env LDAP_TLS_CRT_FILENAME="ldap-server.test.crt" --env LDAP_TLS_KEY_FILENAME="ldap-server.test.key" --env LDAP_TLS_ENFORCE="true" --env LDAP_TLS_VERIFY_CLIENT="never" osixia/openldap:latest --copy-service
   ```

1. Run the GitLab container with TLS enabled. Change the path to [`gitlab-qa/tls_certificates/gitlab`](https://gitlab.com/gitlab-org/gitlab-qa/-/tree/9ffb9ad3be847a9054967d792d6772a74220fb42/tls_certificates/gitlab) directory to your local checkout path:

   ```shell
   sudo docker run \
      --hostname gitlab.test \
      --net test \
      --publish 443:443 --publish 80:80 --publish 22:22 \
      --name gitlab \
      --volume /path/to/gitlab-qa/tls_certificates/gitlab:/etc/gitlab/ssl \
      --env GITLAB_OMNIBUS_CONFIG="gitlab_rails['ldap_enabled'] = true; gitlab_rails['ldap_servers'] = {\"main\"=>{\"label\"=>\"LDAP\", \"host\"=>\"ldap-server.test\", \"port\"=>636, \"uid\"=>\"uid\", \"bind_dn\"=>\"cn=admin,dc=example,dc=org\", \"password\"=>\"admin\", \"encryption\"=>\"simple_tls\", \"verify_certificates\"=>false, \"base\"=>\"dc=example,dc=org\", \"user_filter\"=>\"\", \"group_base\"=>\"ou=Global Groups,dc=example,dc=org\", \"admin_group\"=>\"AdminGroup\", \"external_groups\"=>\"\", \"sync_ssh_keys\"=>false}}; letsencrypt['enable'] = false; external_url 'https://gitlab.test'; gitlab_rails['ldap_sync_worker_cron'] = '* * * * *'; gitlab_rails['ldap_group_sync_worker_cron'] = '* * * * *'; " \
      gitlab/gitlab-ee:latest
   ```

1. Run an LDAP test from [`gitlab/qa`](https://gitlab.com/gitlab-org/gitlab/-/tree/d5447ebb5f99d4c72780681ddf4dc25b0738acba/qa) directory:

   ```shell
   GITLAB_LDAP_USERNAME="tanuki" GITLAB_LDAP_PASSWORD="password" QA_DEBUG=true WEBDRIVER_HEADLESS=false bin/qa Test::Instance::All https://gitlab.test qa/specs/features/browser_ui/1_manage/login/log_into_gitlab_via_ldap_spec.rb
   ```

### Running LDAP tests with TLS disabled

To run the LDAP tests on your local with TLS disabled, follow these steps:

1. Run OpenLDAP container with TLS disabled. Change the path to [`gitlab-qa/fixtures/ldap`](https://gitlab.com/gitlab-org/gitlab-qa/-/tree/9ffb9ad3be847a9054967d792d6772a74220fb42/fixtures/ldap) directory to your local checkout path:

   ```shell
   docker network create test && docker run --net test --publish 389:389 --publish 636:636 --name ldap-server --hostname ldap-server.test --volume /path/to/gitlab-qa/fixtures/ldap:/container/service/slapd/assets/config/bootstrap/ldif/custom:Z --env LDAP_TLS="false" osixia/openldap:latest --copy-service
   ```

1. Run the GitLab container:

  ```shell
  sudo docker run \
    --hostname localhost \
    --net test \
    --publish 443:443 --publish 80:80 --publish 22:22 \
    --name gitlab \
    --env GITLAB_OMNIBUS_CONFIG="gitlab_rails['ldap_enabled'] = true; gitlab_rails['ldap_servers'] = {\"main\"=>{\"label\"=>\"LDAP\", \"host\"=>\"ldap-server.test\", \"port\"=>389, \"uid\"=>\"uid\", \"bind_dn\"=>\"cn=admin,dc=example,dc=org\", \"password\"=>\"admin\", \"encryption\"=>\"plain\", \"verify_certificates\"=>false, \"base\"=>\"dc=example,dc=org\", \"user_filter\"=>\"\", \"group_base\"=>\"ou=Global Groups,dc=example,dc=org\", \"admin_group\"=>\"AdminGroup\", \"external_groups\"=>\"\", \"sync_ssh_keys\"=>false}}; gitlab_rails['ldap_sync_worker_cron'] = '* * * * *'; gitlab_rails['ldap_group_sync_worker_cron'] = '* * * * *'; " \
  gitlab/gitlab-ee:latest
  ```

1. Run an LDAP test from [`gitlab/qa`](https://gitlab.com/gitlab-org/gitlab/-/tree/d5447ebb5f99d4c72780681ddf4dc25b0738acba/qa) directory:

   ```shell
   GITLAB_LDAP_USERNAME="tanuki" GITLAB_LDAP_PASSWORD="password" QA_DEBUG=true WEBDRIVER_HEADLESS=false bin/qa Test::Instance::All http://localhost qa/specs/features/browser_ui/1_manage/login/log_into_gitlab_via_ldap_spec.rb
   ```

## Guide to the mobile suite

### What are mobile tests

Tests that are tagged with `:mobile` can be run against specified mobile devices using cloud emulator/simulator services.

### How to run mobile tests with Sauce Labs

Running directly against an environment like staging is not recommended because Sauce Labs test logs expose credentials. Therefore, it is best practice and the default to use a tunnel.

For tunnel installation instructions, read [Sauce Connect Proxy Installation](https://docs.saucelabs.com/secure-connections/sauce-connect/installation/index.html). To start the tunnel, after following the installation above, copy the run command in Sauce Labs > Tunnels (must be logged in to Sauce Labs with the credentials found in 1Password) and run in terminal.

NOTE:
It is highly recommended to use `GITLAB_QA_ACCESS_TOKEN` to speed up tests and reduce flakiness.

`QA_REMOTE_MOBILE_DEVICE_NAME` can be any device name listed in [Supported browsers and devices](https://saucelabs.com/platform/supported-browsers-devices) under Emulators/simulators and the latest versions of Android or iOS. `QA_BROWSER` must be set to `safari` for iOS devices and `chrome` for Android devices.

1. To test against a local instance with a tunnel running, in `gitlab/qa` run:

```shell
$ QA_BROWSER="safari" \
  QA_REMOTE_MOBILE_DEVICE_NAME="iPhone 12 Simulator" \
  QA_REMOTE_GRID="ondemand.saucelabs.com:80" \
  QA_REMOTE_GRID_USERNAME="gitlab-sl" \
  QA_REMOTE_GRID_ACCESS_KEY="<found in Sauce Lab account>" \
  GITLAB_QA_ACCESS_TOKEN="<token>" \
  bundle exec bin/qa Test::Instance::All http://<local_ip>:3000 -- <relative_spec_path>
```

Results can be watched in real time while logged into Sauce Labs under AUTOMATED > Test Results.

### How to add an existing test to the mobile suite

The main reason a test might fail when adding the `:mobile` tag is navigation differences in desktop vs mobile layouts, therefore the test needs to be updated to use mobile navigation when running mobile tests.

If an existing method needs to be changed or a new one created, a new mobile page object should be created in `qa/qa/mobile/page/` and it should be prepended in the original page object by adding:

```ruby
prepend Mobile::Page::NewPageObject if Runtime::Env.mobile_layout?
```

For example to change an existing method when running mobile tests:

New mobile page object:

```ruby
module QA
  module Mobile
    module Page
      module Project
        module Show
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              prepend QA::Mobile::Page::Main::Menu

              view 'app/assets/javascripts/nav/components/top_nav_new_dropdown.vue' do
                element :new_issue_mobile_button
              end
            end
          end

          def go_to_new_issue
            open_mobile_new_dropdown

            click_element(:new_issue_mobile_button)
          end
        end
      end
    end
  end
end
```

Original page object prepending the new mobile if there's a mobile layout:

```ruby
module QA
  module Page
    module Project
      class Show < Page::Base
        prepend Mobile::Page::Project::Show if Runtime::Env.mobile_layout?

        view 'app/views/layouts/header/_new_dropdown.html.haml' do
          element :new_menu_toggle
        end

        view 'app/helpers/nav/new_dropdown_helper.rb' do
          element :new_issue_link
        end

        def go_to_new_issue
          click_element(:new_menu_toggle)
          click_element(:new_issue_link)
        end
      end
    end
  end
end
```

When running mobile tests for phone layouts, both `remote_mobile_device_name` and `mobile_layout` are `true` but when using a tablet layout, only `remote_mobile_device_name` is true. This is because phone layouts have more menus closed by default such as how both tablets and phones have the left nav closed but unlike phone layouts, tablets have the regular top navigation bar, not the mobile one. So in the case where the navigation being edited needs to be used in tablet layouts as well, use `remote_mobile_device_name` instead of `mobile_layout?` when prepending so it will use it if it's a tablet layout as well.
