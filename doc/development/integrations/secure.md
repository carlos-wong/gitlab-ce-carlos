# Security scanner integration

Integrating a security scanner into GitLab consists of providing end users
with a [CI job definition](../../ci/yaml/README.md#introduction)
they can add to their CI configuration files, to scan their GitLab projects.
The scanning job is usually based on a [Docker image](https://docs.docker.com/)
that contains the scanner and all its dependencies in a self-contained environment.
This page documents requirements and guidelines for writing CI jobs implementing a security scanner,
as well as requirements and guidelines for the Docker image itself.

## Job definition

### Name

For consistency, scanning jobs should be named after the scanner, in lower case.
The job name is suffixed after the type of scanning:
`_dependency_scanning`,  `_container_scanning`, `_dast`, and `_sast`.
For instance, the dependency scanning job based on the "MySec" scanner would be named `mysec_dependency_scanning`.

### Image

The [`image`](../../ci/yaml/README.md#image) keyword is used to specify
the [Docker image](../../ci/docker/using_docker_images.md#what-is-an-image)
containing the security scanner.

### Script

The [`script`](../../ci/yaml/README.md#script) keyword
is used to specify the command that the job runs.
Because the `script` cannot be left empty, it must be set to the command that performs the scan.
It is not possible to rely on the predefined `ENTRYPOINT` and `CMD` of the Docker image
to perform the scan automatically, without passing any command.

The [`before_script`](../../ci/yaml/README.md#before_script-and-after_script)
should not be used in the job definition because users may rely on this to prepare their projects before performing the scan.
For instance, it is common practice to use `before_script` to install system libraries
a particular project needs before performing SAST or Dependency Scanning.

Similarly, [`after_script`](../../ci/yaml/README.md#before_script-and-after_script)
should not not be used in the job definition, because it may be overridden by users.

### Stage

For consistency, scanning jobs should belong to the `test` stage when possible.
The [`stage`](../../ci/yaml/README.md#stage) keyword can be omitted because `test` is the default value.

### Fail-safe

To be aligned with the [GitLab Security paradigm](https://about.gitlab.com/direction/secure/#security-paradigm),
scanning jobs should not block the pipeline when they fail,
so the [`allow_failure`](../../ci/yaml/README.md#allow_failure) parameter should be set to `true`.

### Artifacts

Scanning jobs must declare a report that corresponds to the type of scanning they perform,
using the [`artifacts:reports`](../../ci/yaml/README.md#artifactsreports) keyword.
Valid reports are: `dependency_scanning`, `container_scanning`, `dast`, and `sast`.

For example, here is the definition of a SAST job that generates a file named `gl-sast-report.json`,
and uploads it as a SAST report:

```yaml
mysec_dependency_scanning:
  image: registry.gitlab.com/secure/mysec
  artifacts:
    reports:
      sast: gl-sast-report.json
```

`gl-sast-report.json` is an example file path. See [the Output file section](#output-file) for more details.
It is processed as a SAST report because it is declared as such in the job definition.

### Rules

Scanning jobs should be skipped unless the corresponding feature is listed
in the `GITLAB_FEATURES` variable (comma-separated list of values).
So Dependency Scanning, Container Scanning, SAST, and DAST should be skipped
unless `GITLAB_FEATURES` contains `dependency_scanning`, `container_scanning`, `sast`, and `dast`, respectively.
See [GitLab CI/CD predefined variables](../../ci/variables/predefined_variables.md).

Also, scanning jobs should be skipped when the corresponding variable prefixed with `_DISABLED` is present.
See `DEPENDENCY_SCANNING_DISABLED`, `CONTAINER_SCANNING_DISABLED`, `SAST_DISABLED`, and `DAST_DISABLED`
in [Auto DevOps documentation](../../topics/autodevops/index.md#disable-jobs).

Finally, SAST and Dependency Scanning job definitions should use
`CI_PROJECT_REPOSITORY_LANGUAGES` (comma-separated list of values)
in order to skip the job when the language or technology is not supported.
Language detection currently relies on the [`linguist`](https://github.com/github/linguist) Ruby gem.
See [GitLab CI/CD prefined variables](../../ci/variables/predefined_variables.md#variables-reference).

For instance, here is how to skip the Dependency Scanning job `mysec_dependency_scanning`
unless the project repository contains Java source code,
and the `dependency_scanning` feature is enabled:

```yaml
mysec_dependency_scanning:
  except:
    variables:
      - $DEPENDENCY_SCANNING_DISABLED
  only:
    variables:
      - $GITLAB_FEATURES =~ /\bdependency_scanning\b/ &&
        $CI_PROJECT_REPOSITORY_LANGUAGES =~ /\bjava\b/
```

The [`only/except`](../../ci/yaml/README.md#onlyexcept-basic) keywords
as well as the new [`rules`](../../ci/yaml/README.md#rules) keyword
make possible to trigger the job depending on the branch, or when some particular file changes.
Such rules should be defined by users based on their needs,
and should not be predefined in the job definition of the scanner.

## Docker image

The Docker image is a self-contained environment that combines
the scanner with all the libraries and tools it depends on.

### Image size

Depending on the CI infrastructure,
the CI may have to fetch the Docker image every time the job runs.
To make the scanning job run fast, and to avoid wasting bandwidth,
it is important to make Docker images as small as possible,
ideally smaller than 50 MB.

If the scanner requires a fully functional Linux environment,
it is recommended to use a [Debian](https://www.debian.org/intro/about) "slim" distribution or [Alpine Linux](https://www.alpinelinux.org/).
If possible, it is recommended to build the image from scratch, using the `FROM scratch` instruction,
and to compile the scanner with all the libraries it needs.
[Multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/)
might also help with keeping the image small.

### Image tag

As documented in the [Docker Official Images](https://github.com/docker-library/official-images#tags-and-aliases) project,
it is strongly encouraged that version number tags be given aliases which allows the user to easily refer to the "most recent" release of a particular series.
See also [Docker Tagging: Best practices for tagging and versioning docker images](https://docs.microsoft.com/en-us/archive/blogs/stevelasker/docker-tagging-best-practices-for-tagging-and-versioning-docker-images).

## Command line

A scanner is a command line tool that takes environment variables as inputs,
and generates a file that is uploaded as a report (based on the job definition).
It also generates text output on the standard output and standard error streams, and exits with a status code.

### Variables

All CI variables are passed to the scanner as environment variables.
The scanned project is described by the [predefined CI variables](../../ci/variables/README.md).

#### SAST, Dependency Scanning

SAST and Dependency Scanning scanners must scan the files in the project directory, given by the `CI_PROJECT_DIR` variable.

#### Container Scanning

In order to be consistent with the official Container Scanning for GitLab,
scanners must scan the Docker image whose name and tag are given by
`CI_APPLICATION_REPOSITORY` and `CI_APPLICATION_TAG`, respectively.

If not provided, `CI_APPLICATION_REPOSITORY` should default to
`$CI_REGISTRY_IMAGE/$CI_COMMIT_REF_SLUG`, which is a combination of predefined CI variables.
`CI_APPLICATION_TAG` should default to `CI_COMMIT_SHA`.

The scanner should sign in the Docker registry
using the variables `DOCKER_USER` and `DOCKER_PASSWORD`.
If these are not defined, then the scanner should use
`CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD` as default values.

#### Configuration files

While scanners may use `CI_PROJECT_DIR` to load specific configuration files,
it is recommended to expose configuration as environment variables, not files.

### Output file

Like any artifact uploaded to the GitLab CI,
the Secure report generated by the scanner must be written in the project directory,
given by the `CI_PROJECT_DIR` environment variable.

It is recommended to name the output file after the type of scanning, and to use `gl-` as a prefix.
Since all Secure reports are JSON files, it is recommended to use `.json` as a file extension.
For instance, a suggested file name for a Dependency Scanning report is `gl-dependency-scanning.json`.

The [`artifacts:reports`](../../ci/yaml/README.md#artifactsreports) keyword
of the job definition must be consistent with the file path where the Security report is written.
For instance, if a Dependency Scanning analyzer writes its report to the CI project directory,
and if this report file name is `depscan.json`,
then `artifacts:reports:dependency_scanning` must be set to `depscan.json`.

### Exit code

Following the POSIX exit code standard, the scanner will exit with 0 for success and any number from 1 to 255 for anything else.
Success also includes the case when vulnerabilities are found.

### Logging

The scanner should log error messages and warnings so that users can easily investigate
misconfiguration and integration issues by looking at the log of the CI scanning job.

Scanners may use [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
to colorize the messages they write to the Unix standard output and standard error streams.
We recommend using red to report errors, yellow for warnings, and green for notices.
Also, we recommend prefixing error messages with `[ERRO]`, warnings with `[WARN]`, and notices with `[INFO]`.

## Report

The report is a JSON document that combines vulnerabilities with possible remediations.

This documentation gives an overview of the report JSON format,
as well as recommendations and examples to help integrators set its fields.
The format is extensively described in the documentation of
[SAST](../../user/application_security/sast/index.md#reports-json-format),
[Dependency Scanning](../../user/application_security/dependency_scanning/index.md#reports-json-format),
and [Container Scanning](../../user/application_security/container_scanning/index.md#reports-json-format).

The DAST variant of the report JSON format is not documented at the moment.

### Version

The documentation of
[SAST](../../user/application_security/sast/index.md#reports-json-format),
[Dependency Scanning](../../user/application_security/dependency_scanning/index.md#reports-json-format),
and [Container Scanning](../../user/application_security/container_scanning/index.md#reports-json-format)
describes the Secure report format version.

### Vulnerabilities

The `vulnerabilities` field of the report is an array of vulnerability objects.

#### Category

The value of the `category` field matches the report type:
`dependency_scanning`, `container_scanning`, `sast`, and  `dast`.

#### Scanner

The `scanner` field is an object that embeds a human-readable `name` and a technical `id`.
The `id` should not collide with any other scanner another integrator would provide.

#### Name, message, and description

The `name` and `message` fields contain a short description of the vulnerability,
whereas the `description` field provides more details.

The `name` is context-free and contains no information on where the vulnerability has been found,
whereas the `message` may repeat the location.

For instance, a `message` for a vulnerability
reported by Dependency Scanning gives information on the vulnerable dependency,
which is redundant with the `location` field of the vulnerability.
The `name` field is preferred but the `message` field is used
when the context/location cannot be removed from the title of the vulnerability.

To illustrate, here is an example vulnerability object reported by a Dependency Scanning scanner,
and where the `message` repeats the `location` field:

```json
{
    "location": {
        "dependency": {
            "package": {
            "name": "debug"
          }
        }
    },
    "name": "Regular Expression Denial of Service",
    "message": "Regular Expression Denial of Service in debug",
    "description": "The debug module is vulnerable to regular expression denial of service
        when untrusted user input is passed into the `o` formatter.
        It takes around 50k characters to block for 2 seconds making this a low severity issue."
}
```
  
The `description` might explain how the vulnerability works or give context about the exploit.
It should not repeat the other fields of the vulnerability object.
In particular, the `description` should not repeat the `location` (what is affected)
or the `solution` (how to mitigate the risk).

There is a proposal to remove either the `name` or the `message`, to remove ambiguities.
See [issue #36779](https://gitlab.com/gitlab-org/gitlab/issues/36779).

#### Solution

The `solution` field may contain instructions users should follow to fix the vulnerability or to mitigate the risk.
It is intended for users whereas the `remediations` objects are processed automatically by GitLab.

#### Identifiers

The `identifiers` array describes the vulnerability flaw that has been detected.
An identifier object has a `type` and a `value`;
these technical fields are used to tell if two identifiers are the same.
It also has a `name` and a `url`;
these fields are used to display the identifier in the user interface.

It is recommended to reuse the identifiers the GitLab scanners already define:

| Identifier | Type | Example value |
|------------|------|---------------|
| [CVE](https://cve.mitre.org/cve/) | `cve` | CVE-2019-10086 |
| [CWE](https://cwe.mitre.org/data/index.html) | `cwe` | CWE-1026 |
| [OSVD](https://cve.mitre.org/data/refs/refmap/source-OSVDB.html) | `osvdb` | OSVDB-113928 |
| [USN](https://usn.ubuntu.com/) | `usn` | USN-4234-1 |
| [WASC](http://projects.webappsec.org/Threat-Classification-Reference-Grid)  | `wasc` | WASC-19 |
| [RHSA](https://access.redhat.com/errata) | `rhsa` | RHSA-2020:0111 |
| [ELSA](https://linux.oracle.com/security/) | `elsa` | ELSA-2020-0085 |

The generic identifiers listed above are defined in the [common library](https://gitlab.com/gitlab-org/security-products/analyzers/common);
this library is shared by the analyzers maintained by GitLab,
and this is where you can [contribute](https://gitlab.com/gitlab-org/security-products/analyzers/common/blob/master/issue/identifier.go) new generic identifiers.
Analyzers may also produce vendor-specific or product-specific identifiers;
these do not belong to the [common library](https://gitlab.com/gitlab-org/security-products/analyzers/common).

The first item of the `identifiers` array is called the primary identifier.
The primary identifier is particularly important, because it is used to
[track vulnerabilities](#tracking-merging-vulnerabilities)
as new commits are pushed to the repository.

Identifiers are used to [merge duplicate vulnerabilities](#tracking-merging-vulnerabilities)
reported for the same commit, except for `CWE` and `WASC`.

### Location

The `location` indicates where the vulnerability has been detected.
The format of the location depends on the type of scanning.

Internally GitLab extracts some attributes of the `location` to generate the **location fingerprint**,
which is used to [track vulnerabilities](#tracking-merging-vulnerabilities)
as new commits are pushed to the repository.
The attributes used to generate the location fingerprint also depend on the type of scanning.

#### Dependency Scanning

The `location` of a Dependency Scanning vulnerability is composed of a `dependency` and a `file`.
The `dependency` object describes the affected `package` and the dependency `version`.
`package` embeds the `name` of the affected library/module.
`file` is the path of the dependency file that declares the affected dependency.

For instance, here is the `location` object for a vulnerability affecting
version `4.0.11` of npm package [`handlebars`](https://www.npmjs.com/package/handlebars):

```json
{
    "file": "client/package.json",
    "dependency": {
        "package": {
            "name": "handlebars"
        },
        "version": "4.0.11"
    }
}
```

This affected dependency is listed in `client/package.json`,
a dependency file processed by npm or yarn.

The location fingerprint of a Dependency Scanning vulnerability
combines the `file` and the package `name`,
so these attributes are mandatory.
All other attributes are optional.

#### Container Scanning

Similar to Dependency Scanning,
the `location` of a Container Scanning vulnerability has a `dependency` and a `file`.
It also has an `operating_system` field.

For instance, here is the `location` object for a vulnerability affecting
version `2.50.3-2+deb9u1` of Debian package `glib2.0`:

```json
{
    "dependency": {
        "package": {
            "name": "glib2.0"
        },
    },
    "version": "2.50.3-2+deb9u1",
    "operating_system": "debian:9",
    "image": "registry.gitlab.com/example/app:latest"
}
```

The affected package is found when scanning the Docker image `registry.gitlab.com/example/app:latest`.
The Docker image is based on `debian:9` (Debian Stretch).

The location fingerprint of a Container Scanning vulnerability
combines the `operating_system` and the package `name`,
so these attributes are mandatory.
The `image` is also mandatory.
All other attributes are optional.

#### SAST

The `location` of a SAST vulnerability must have a `file` and a `start_line` field,
giving the path of the affected file, and the affected line number, respectively.
It may also have an `end_line`, a `class`, and a `method`.

For instance, here is the `location` object for a security flaw found
at line `41` of `src/main/java/com/gitlab/example/App.java`,
in the the `generateSecretToken` method of the `com.gitlab.security_products.tests.App` Java class:

```json
{
    "file": "src/main/java/com/gitlab/example/App.java",
    "start_line": 41,
    "end_line": 41,
    "class": "com.gitlab.security_products.tests.App",
    "method": "generateSecretToken1"
}
```

The location fingerprint of a SAST vulnerability
combines `file`, `start_line`, and `end_line`,
so these attributes are mandatory.
All other attributes are optional.

### Tracking, merging vulnerabilities

Users may give feedback on a vulnerability:

- they may dismiss a vulnerability if it does not apply to their projects
- or they may create an issue for a vulnerability, if there is a possible threat

GitLab tracks vulnerabilities so that user feedback is not lost
when new Git commits are pushed to the repository.
Vulnerabilities are tracked using a combination of three attributes:

- [Report type](#category)
- [Location fingerprint](#location)
- [Primary identifier](#identifiers)

Right now, GitLab cannot track a vulnerability if its location changes
as new Git commits are pushed, and this results in user feedback being lost.
For instance, user feedback on a SAST vulnerability is lost
if the affected file is renamed or the affected line moves down.
This is addressed in [issue #7586](https://gitlab.com/gitlab-org/gitlab/issues/7586).

In some cases, the multiple scans executed in the same CI pipeline result in duplicates
that are automatically merged using the vulnerability location and identifiers.
Two vulnerabilities are considered to be the same if they share the same [location fingerprint](#location)
and at least one [identifier](#identifiers). Two identifiers are the same if they share the same `type` and `id`.
CWE and WASC identifiers are not considered because they describe categories of vulnerability flaws,
but not specific security flaws.

#### Severity and confidence

The `severity` field describes how much the vulnerability impacts the software,
whereas the `confidence` field describes how reliable the assessment of the vulnerability is.
The severity is used to sort the vulnerabilities in the security dashboard.

The severity ranges from `Info` to `Critical`, but it can also be `Unknown`.
Valid values are: `Unknown`, `Info`, `Low`, `Medium`, `High`, or `Critical`

The confidence ranges from `Low` to `Confirmed`, but it can also be `Unknown`,
`Experimental` or even `Ignore` if the vulnerability is to be ignored.
Valid values are: `Ignore`, `Unknown`, `Experimental`, `Low`, `Medium`, `High`, or `Confirmed`

### Remediations

The `remediations` field of the report is an array of remediation objects.
Each remediation describes a patch that can be applied to automatically fix
a set of vulnerabilities.

Currently, remediations rely on a deprecated field named `cve` to reference vulnerabilities,
so it is recommended not to use them until a new format has been defined.
See [issue #36777](https://gitlab.com/gitlab-org/gitlab/issues/36777).
