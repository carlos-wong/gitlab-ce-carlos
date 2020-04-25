# GitLab Maven Repository **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/5811) in [GitLab Premium](https://about.gitlab.com/pricing/) 11.3.

With the GitLab [Maven](https://maven.apache.org) Repository, every
project can have its own space to store its Maven artifacts.

![GitLab Maven Repository](img/maven_package_view_v12_6.png)

## Enabling the Maven Repository

NOTE: **Note:**
This option is available only if your GitLab administrator has
[enabled support for the Maven repository](../../../administration/packages/index.md).**(PREMIUM ONLY)**

After the Packages feature is enabled, the Maven Repository will be available for
all new projects by default. To enable it for existing projects, or if you want
to disable it:

1. Navigate to your project's **Settings > General > Permissions**.
1. Find the Packages feature and enable or disable it.
1. Click on **Save changes** for the changes to take effect.

You should then be able to see the **Packages** section on the left sidebar.
Next, you must configure your project to authorize with the GitLab Maven
repository.

## Getting Started

This section will cover installing Maven and building a package. This is a
quickstart to help if you're new to building Maven packages. If you're already
using Maven and understand how to build your own packages, move onto the
[next section](#adding-the-gitlab-package-registry-as-a-maven-remote).

### Installing Maven

Follow the instructions at [maven.apache.org](https://maven.apache.org/install.html)
to download and install Maven for your local development environment. Once
installation is complete, verify you can use Maven in your terminal by running:

```shell
mvn --version
```

You should see something similar to the below printed in the output:

```shell
Apache Maven 3.6.1 (d66c9c0b3152b2e69ee9bac180bb8fcc8e6af555; 2019-04-04T20:00:29+01:00)
Maven home: /Users/<your_user>/apache-maven-3.6.1
Java version: 12.0.2, vendor: Oracle Corporation, runtime: /Library/Java/JavaVirtualMachines/jdk-12.0.2.jdk/Contents/Home
Default locale: en_GB, platform encoding: UTF-8
OS name: "mac os x", version: "10.15.2", arch: "x86_64", family: "mac"
```

### Creating a project

Understanding how to create a full Java project is outside the scope of this
guide but you can follow the steps below to create a new project that can be
published to the GitLab Package Registry.

Start by opening your terminal and creating a directory where you would like to
store the project in your environment. From inside the directory, you can run
the following Maven command to initalize a new package:

```shell
mvn archetype:generate -DgroupId=com.mycompany.mydepartment -DartifactId=my-project -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false
```

The arguments are as follows:

- `DgroupId`: A unique string that identifies your package. You should follow
the [Maven naming conventions](https://maven.apache.org/guides/mini/guide-naming-conventions.html).
- `DartifactId`: The name of the JAR, appended to the end of the `DgroupId`.
- `DarchetypeArtifactId`: The archetype used to create the intial structure of
the project.
- `DinteractiveMode`: Create the project using batch mode (optional).

After running the command, you should see the following message, indicating that
your project has been set up successfully:

```shell
...
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  3.429 s
[INFO] Finished at: 2020-01-28T11:47:04Z
[INFO] ------------------------------------------------------------------------
```

You should see a new directory where you ran this command matching your
`DartifactId` parameter (in this case it should be `my-project`).

## Adding the GitLab Package Registry as a Maven remote

The next step is to add the GitLab Package Registry as a Maven remote. If a
project is private or you want to upload Maven artifacts to GitLab,
credentials will need to be provided for authorization too. Support is available
for [personal access tokens](#authenticating-with-a-personal-access-token) and
[CI job tokens](#authenticating-with-a-ci-job-token) only.
[Deploy tokens](../../project/deploy_tokens/index.md) and regular username/password
credentials do not work.

### Authenticating with a personal access token

To authenticate with a [personal access token](../../profile/personal_access_tokens.md),
set the scope to `api` and add a corresponding section to your
[`settings.xml`](https://maven.apache.org/settings.html) file:

```xml
<settings>
  <servers>
    <server>
      <id>gitlab-maven</id>
      <configuration>
        <httpHeaders>
          <property>
            <name>Private-Token</name>
            <value>REPLACE_WITH_YOUR_PERSONAL_ACCESS_TOKEN</value>
          </property>
        </httpHeaders>
      </configuration>
    </server>
  </servers>
</settings>
```

You should now be able to upload Maven artifacts to your project.

### Authenticating with a CI job token

If you're using Maven with GitLab CI/CD, a CI job token can be used instead
of a personal access token.

To authenticate with a CI job token, add a corresponding section to your
[`settings.xml`](https://maven.apache.org/settings.html) file:

```xml
<settings>
  <servers>
    <server>
      <id>gitlab-maven</id>
      <configuration>
        <httpHeaders>
          <property>
            <name>Job-Token</name>
            <value>${env.CI_JOB_TOKEN}</value>
          </property>
        </httpHeaders>
      </configuration>
    </server>
  </servers>
</settings>
```

You can read more on
[how to create Maven packages using GitLab CI/CD](#creating-maven-packages-with-gitlab-cicd).

## Configuring your project to use the GitLab Maven repository URL

To download and upload packages from GitLab, you need a `repository` and
`distributionManagement` section in your `pom.xml` file. If you're following the
steps from above, then you'll need to add the following information to your
`my-project/pom.xml` file.

Depending on your workflow and the amount of Maven packages you have, there are
3 ways you can configure your project to use the GitLab endpoint for Maven packages:

- **Project level**: Useful when you have few Maven packages which are not under
  the same GitLab group.
- **Group level**: Useful when you have many Maven packages under the same GitLab
  group.
- **Instance level**: Useful when you have many Maven packages under different
  GitLab groups or on their own namespace.

NOTE: **Note:**
In all cases, you need a project specific URL for uploading a package in
the `distributionManagement` section.

### Project level Maven endpoint

The example below shows how the relevant `repository` section of your `pom.xml`
would look like:

```xml
<repositories>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </repository>
</repositories>
<distributionManagement>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </repository>
  <snapshotRepository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </snapshotRepository>
</distributionManagement>
```

The `id` must be the same with what you
[defined in `settings.xml`](#adding-the-gitlab-package-registry-as-a-maven-remote).

Replace `PROJECT_ID` with your project ID which can be found on the home page
of your project.

If you have a self-hosted GitLab installation, replace `gitlab.com` with your
domain name.

NOTE: **Note:**
For retrieving artifacts, you can use either the
[URL encoded](../../../api/README.md#namespaced-path-encoding) path of the project
(e.g., `group%2Fproject`) or the project's ID (e.g., `42`). However, only the
project's ID can be used for uploading.

### Group level Maven endpoint

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/8798) in GitLab Premium 11.7.

If you rely on many packages, it might be inefficient to include the `repository` section
with a unique URL for each package. Instead, you can use the group level endpoint for
all your Maven packages stored within one GitLab group. Only packages you have access to
will be available for download.

The group level endpoint works with any package names, which means the you
have the flexibility of naming compared to [instance level endpoint](#instance-level-maven-endpoint).
However, GitLab will not guarantee the uniqueness of the package names within
the group. You can have two projects with the same package name and package
version. As a result, GitLab will serve whichever one is more recent.

The example below shows how the relevant `repository` section of your `pom.xml`
would look like. You still need a project specific URL for uploading a package in
the `distributionManagement` section:

```xml
<repositories>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/groups/GROUP_ID/-/packages/maven</url>
  </repository>
</repositories>
<distributionManagement>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </repository>
  <snapshotRepository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </snapshotRepository>
</distributionManagement>
```

The `id` must be the same with what you
[defined in `settings.xml`](#adding-the-gitlab-package-registry-as-a-maven-remote).

Replace `my-group` with your group name and `PROJECT_ID` with your project ID
which can be found on the home page of your project.

If you have a self-hosted GitLab installation, replace `gitlab.com` with your
domain name.

NOTE: **Note:**
For retrieving artifacts, you can use either the
[URL encoded](../../../api/README.md#namespaced-path-encoding) path of the group
(e.g., `group%2Fsubgroup`) or the group's ID (e.g., `12`).

### Instance level Maven endpoint

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/8274) in GitLab Premium 11.7.

If you rely on many packages, it might be inefficient to include the `repository` section
with a unique URL for each package. Instead, you can use the instance level endpoint for
all maven packages stored in GitLab and the packages you have access to will be available
for download.

Note that **only packages that have the same path as the project** are exposed via
the instance level endpoint.

| Project | Package | Instance level endpoint available |
| ------- | ------- | --------------------------------- |
| `foo/bar`           | `foo/bar/1.0-SNAPSHOT`           | Yes |
| `gitlab-org/gitlab` | `foo/bar/1.0-SNAPSHOT`           | No  |
| `gitlab-org/gitlab` | `gitlab-org/gitlab/1.0-SNAPSHOT` | Yes |

The example below shows how the relevant `repository` section of your `pom.xml`
would look like. You still need a project specific URL for uploading a package in
the `distributionManagement` section:

```xml
<repositories>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/packages/maven</url>
  </repository>
</repositories>
<distributionManagement>
  <repository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </repository>
  <snapshotRepository>
    <id>gitlab-maven</id>
    <url>https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven</url>
  </snapshotRepository>
</distributionManagement>
```

The `id` must be the same with what you
[defined in `settings.xml`](#adding-the-gitlab-package-registry-as-a-maven-remote).

Replace `PROJECT_ID` with your project ID which can be found on the home page
of your project.

If you have a self-hosted GitLab installation, replace `gitlab.com` with your
domain name.

NOTE: **Note:**
For retrieving artifacts, you can use either the
[URL encoded](../../../api/README.md#namespaced-path-encoding) path of the project
(e.g., `group%2Fproject`) or the project's ID (e.g., `42`). However, only the
project's ID can be used for uploading.

## Uploading packages

Once you have set up the [remote and authentication](#adding-the-gitlab-package-registry-as-a-maven-remote)
and [configured your project](#configuring-your-project-to-use-the-gitlab-maven-repository-url),
test to upload a Maven artifact from a project of yours:

```shell
mvn deploy
```

If the deploy is successful, you should see the build success message again:

```shell
...
[INFO] BUILD SUCCESS
...
```

You should also see that the upload was uploaded to the correct registry:

```shell
Uploading to gitlab-maven: https://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven/com/mycompany/mydepartment/my-project/1.0-SNAPSHOT/my-project-1.0-20200128.120857-1.jar
```

You can then navigate to your project's **Packages** page and see the uploaded
artifacts or even delete them.

## Installing a package

Installing a package from the GitLab Package Registry requires that you set up
the [remote and authentication](#adding-the-gitlab-package-registry-as-a-maven-remote)
as above. Once this is completed, there are two ways for installaing a package.

### Install with `mvn install`

Add the dependency manually to your project `pom.xml` file. To add the example
created above, the XML would look like:

```xml
<dependency>
  <groupId>com.mycompany.mydepartment</groupId>
  <artifactId>my-project</artifactId>
  <version>1.0-SNAPSHOT</version>
</dependency>
```

Then, inside your project, run the following:

```shell
mvn install
```

Provided everything is set up correctly, you should see the dependency
downloaded from the GitLab Package Registry:

```shell
Downloading from gitlab-maven: http://gitlab.com/api/v4/projects/PROJECT_ID/packages/maven/com/mycompany/mydepartment/my-project/1.0-SNAPSHOT/my-project-1.0-20200128.120857-1.pom
```

### Install with `mvn dependency:get`

The second way to install packages is to use the Maven commands directly.
Inside your project directory, run:

```shell
mvn dependency:get -Dartifact=com.nickkipling.app:nick-test-app:1.1-SNAPSHOT
```

You should see the same downloading message confirming that the project was
retrieved from the GitLab Package Registry.

TIP: **Tip:**
Both the XML block and Maven command are readily copy and pastable from the
Package details page, allowing for quick and easy installation.

## Removing a package

In the packages view of your project page, you can delete packages by clicking
the red trash icons or by clicking the **Delete** button on the package details
page.

## Creating Maven packages with GitLab CI/CD

Once you have your repository configured to use the GitLab Maven Repository,
you can configure GitLab CI/CD to build new packages automatically. The example below
shows how to create a new package each time the `master` branch is updated:

1. Create a `ci_settings.xml` file that will serve as Maven's `settings.xml` file.
   Add the server section with the same id you defined in your `pom.xml` file.
   For example, in our case it's `gitlab-maven`:

   ```xml
   <settings xmlns="http://maven.apache.org/SETTINGS/1.1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd">
     <servers>
       <server>
         <id>gitlab-maven</id>
         <configuration>
           <httpHeaders>
             <property>
               <name>Job-Token</name>
               <value>${env.CI_JOB_TOKEN}</value>
             </property>
           </httpHeaders>
         </configuration>
       </server>
     </servers>
   </settings>
   ```

1. Make sure your `pom.xml` file includes the following:

   ```xml
   <repositories>
     <repository>
       <id>gitlab-maven</id>
       <url>https://gitlab.com/api/v4/projects/${env.CI_PROJECT_ID}/packages/maven</url>
     </repository>
   </repositories>
   <distributionManagement>
     <repository>
       <id>gitlab-maven</id>
       <url>https://gitlab.com/api/v4/projects/${env.CI_PROJECT_ID}/packages/maven</url>
     </repository>
     <snapshotRepository>
       <id>gitlab-maven</id>
       <url>https://gitlab.com/api/v4/projects/${env.CI_PROJECT_ID}/packages/maven</url>
     </snapshotRepository>
   </distributionManagement>
   ```

   TIP: **Tip:**
   You can either let Maven utilize the CI environment variables or hardcode your project's ID.

1. Add a `deploy` job to your `.gitlab-ci.yml` file:

   ```yaml
   deploy:
     image: maven:3.3.9-jdk-8
     script:
       - 'mvn deploy -s ci_settings.xml'
     only:
       - master
   ```

1. Push those files to your repository.

The next time the `deploy` job runs, it will copy `ci_settings.xml` to the
user's home location (in this case the user is `root` since it runs in a
Docker container), and Maven will utilize the configured CI
[environment variables](../../../ci/variables/README.md#predefined-environment-variables).

## Troubleshooting

### Useful Maven command line options

There's some [maven command line options](https://maven.apache.org/ref/current/maven-embedder/cli.html)
which maybe useful when doing tasks with GitLab CI.

- File transfer progress can make the CI logs hard to read.
  Option `-ntp,--no-transfer-progress` was added in
  [3.6.1](https://maven.apache.org/docs/3.6.1/release-notes.html#User_visible_Changes).
  Alternatively, look at `-B,--batch-mode`
  [or lower level logging changes.](https://stackoverflow.com/questions/21638697/disable-maven-download-progress-indication)

- Specify where to find the POM file (`-f,--file`):

   ```yaml
   package:
     script:
       - 'mvn --no-transfer-progress -f helloworld/pom.xml package'
   ```

- Specify where to find the user settings (`-s,--settings`) instead of
  [the default location](https://maven.apache.org/settings.html). There's also a `-gs,--global-settings` option:

   ```yaml
   package:
     script:
       - 'mvn -s settings/ci.xml package'
   ```

### Verifying your Maven settings

If you encounter issues within CI that relate to the `settings.xml` file, it might be useful
to add an additional script task or job to
[verify the effective settings](https://maven.apache.org/plugins/maven-help-plugin/effective-settings-mojo.html).

The help plugin can also provide
[system properties](https://maven.apache.org/plugins/maven-help-plugin/system-mojo.html), including environment variables:

```yaml
mvn-settings:
  script:
    - 'mvn help:effective-settings'

package:
  script:
    - 'mvn help:system'
    - 'mvn package'
```
