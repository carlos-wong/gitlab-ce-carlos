# Static Application Security Testing (SAST) **[ULTIMATE]**

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/3775)
in [GitLab Ultimate](https://about.gitlab.com/pricing/) 10.3.

NOTE: **4 of the top 6 attacks were application based.**
Download our whitepaper,
["A Seismic Shift in Application Security"](https://about.gitlab.com/resources/whitepaper-seismic-shift-application-security/)
to learn how to protect your organization.

## Overview

If you are using [GitLab CI/CD](../../../ci/README.md), you can analyze your source code for known
vulnerabilities using Static Application Security Testing (SAST).

You can take advantage of SAST by either [including the CI job](#configuring-sast) in
your existing `.gitlab-ci.yml` file or by implicitly using
[Auto SAST](../../../topics/autodevops/index.md#auto-sast-ultimate)
that is provided by [Auto DevOps](../../../topics/autodevops/index.md).

GitLab checks the SAST report, compares the found vulnerabilities between the
source and target branches, and shows the information right on the merge request.

![SAST Widget](img/sast.png)

The results are sorted by the priority of the vulnerability:

1. Critical
1. High
1. Medium
1. Low
1. Unknown
1. Everything else

## Use cases

- Your code has a potentially dangerous attribute in a class, or unsafe code
  that can lead to unintended code execution.
- Your application is vulnerable to cross-site scripting (XSS) attacks that can
  be leveraged to unauthorized access to session data.

## Requirements

To run a SAST job, you need GitLab Runner with the
[`docker`](https://docs.gitlab.com/runner/executors/docker.html#use-docker-in-docker-with-privileged-mode) or
[`kubernetes`](https://docs.gitlab.com/runner/install/kubernetes.html#running-privileged-containers-for-the-runners)
executor running in privileged mode. If you're using the shared Runners on GitLab.com,
this is enabled by default.

## Supported languages and frameworks

The following table shows which languages, package managers and frameworks are supported and which tools are used.

| Language (package managers) / framework                                     | Scan tool                                                                              | Introduced in GitLab Version |
|-----------------------------------------------------------------------------|----------------------------------------------------------------------------------------|------------------------------|
| .NET                                                                        | [Security Code Scan](https://security-code-scan.github.io)                             | 11.0                         |
| Any                                                                         | [Gitleaks](https://github.com/zricethezav/gitleaks) and [TruffleHog](https://github.com/dxa4481/truffleHog) | 11.9 |
| C/C++                                                                       | [Flawfinder](https://www.dwheeler.com/flawfinder/)                                     | 10.7                         |
| Elixir (Phoenix)                                                            | [Sobelow](https://github.com/nccgroup/sobelow)                                         | 11.10                        |
| Go                                                                          | [Gosec](https://github.com/securego/gosec)                                             | 10.7                         |
| Groovy ([Ant](https://ant.apache.org/), [Gradle](https://gradle.org/), [Maven](https://maven.apache.org/) and [SBT](https://www.scala-sbt.org/)) | [SpotBugs](https://spotbugs.github.io/) with the [find-sec-bugs](https://find-sec-bugs.github.io/) plugin | 11.3 (Gradle) & 11.9 (Ant, Maven, SBT) |
| Java ([Ant](https://ant.apache.org/), [Gradle](https://gradle.org/), [Maven](https://maven.apache.org/) and [SBT](https://www.scala-sbt.org/)) | [SpotBugs](https://spotbugs.github.io/) with the [find-sec-bugs](https://find-sec-bugs.github.io/) plugin | 10.6 (Maven), 10.8 (Gradle) & 11.9 (Ant, SBT) |
| Javascript                                                                  | [ESLint security plugin](https://github.com/nodesecurity/eslint-plugin-security)       | 11.8                         |
| Node.js                                                                     | [NodeJsScan](https://github.com/ajinabraham/NodeJsScan)                                | 11.1                         |
| PHP                                                                         | [phpcs-security-audit](https://github.com/FloeDesignTechnologies/phpcs-security-audit) | 10.8                         |
| Python ([pip](https://pip.pypa.io/en/stable/))                              | [bandit](https://github.com/PyCQA/bandit)                                              | 10.3                         |
| Ruby on Rails                                                               | [brakeman](https://brakemanscanner.org)                                                | 10.3                         |
| Scala ([Ant](https://ant.apache.org/), [Gradle](https://gradle.org/), [Maven](https://maven.apache.org/) and [SBT](https://www.scala-sbt.org/)) | [SpotBugs](https://spotbugs.github.io/) with the [find-sec-bugs](https://find-sec-bugs.github.io/) plugin | 11.0 (SBT) & 11.9 (Ant, Gradle, Maven) |
| Typescript                                                                  | [TSLint config security](https://github.com/webschik/tslint-config-security/)          | 11.9                         |

NOTE: **Note:**
The Java analyzers can also be used for variants like the
[Gradle wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html),
[Grails](https://grails.org/) and the [Maven wrapper](https://github.com/takari/maven-wrapper).

## Configuring SAST

To enable SAST in your project, define a job in your `.gitlab-ci.yml` file that generates the
[SAST report artifact](../../../ci/yaml/README.md#artifactsreportssast-ultimate).

This can be done in two ways:

- For GitLab 11.9 and later, including the provided `SAST.gitlab-ci.yml` template (recommended).
- Manually specifying the job definition. Not recommended unless using GitLab
  11.8 and earlier.

### Including the provided template

NOTE: **Note:**
The CI/CD SAST template is supported on GitLab 11.9 and later versions.
For earlier versions, use the [manual job definition](#manual-job-definition-for-gitlab-115-and-later).

A CI/CD [SAST template](https://gitlab.com/gitlab-org/gitlab-ee/blob/master/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml)
with the default SAST job definition is provided as a part of your GitLab
installation which you can [include](../../../ci/yaml/README.md#includetemplate)
in your `.gitlab-ci.yml` file.

To enable SAST using the provided template, add the following to your `.gitlab-ci.yml`
file:

```yaml
include:
  template: SAST.gitlab-ci.yml
```

The included template will create a `sast` job in your CI/CD pipeline and scan
your project's source code for possible vulnerabilities.

The report will be saved as a
[SAST report artifact](../../../ci/yaml/README.md#artifactsreportssast-ultimate)
that you can later download and analyze. Due to implementation limitations, we
always take the latest SAST artifact available. Behind the scenes, the
[GitLab SAST Docker image](https://gitlab.com/gitlab-org/security-products/sast)
is used to detect the languages/frameworks and in turn runs the matching scan tools.

#### Customizing the SAST settings

The SAST settings can be changed through environment variables by using the
[`variables`](../../../ci/yaml/README.md#variables) parameter in `.gitlab-ci.yml`.
These variables are documented in the
[SAST tool documentation](https://gitlab.com/gitlab-org/security-products/sast#settings).

In the following example, we include the SAST template and at the same time we
set the `SAST_GOSEC_LEVEL` variable to `2`:

```yaml
include:
  template: SAST.gitlab-ci.yml

variables:
  SAST_GOSEC_LEVEL: 2
```

Because the template is [evaluated before](../../../ci/yaml/README.md#include)
the pipeline configuration, the last mention of the variable will take precedence.

#### Overriding the SAST template

If you want to override the job definition (for example, change properties like
`variables` or `dependencies`), you need to declare a `sast` job after the
template inclusion and specify any additional keys under it. For example:

```yaml
include:
  template: SAST.gitlab-ci.yml

sast:
  variables:
    CI_DEBUG_TRACE: "true"
```

### Manual job definition for GitLab 11.5 and later

For GitLab 11.5 and GitLab Runner 11.5 and later, the following `sast`
job can be added:

```yaml
sast:
  stage: test
  image: docker:stable
  variables:
    DOCKER_DRIVER: overlay2
  allow_failure: true
  services:
    - docker:stable-dind
  script:
    - export SAST_VERSION=${SP_VERSION:-$(echo "$CI_SERVER_VERSION" | sed 's/^\([0-9]*\)\.\([0-9]*\).*/\1-\2-stable/')}
    - |
      docker run \
        --env SAST_ANALYZER_IMAGES \
        --env SAST_ANALYZER_IMAGE_PREFIX \
        --env SAST_ANALYZER_IMAGE_TAG \
        --env SAST_DEFAULT_ANALYZERS \
        --env SAST_EXCLUDED_PATHS \
        --env SAST_BANDIT_EXCLUDED_PATHS \
        --env SAST_BRAKEMAN_LEVEL \
        --env SAST_GOSEC_LEVEL \
        --env SAST_FLAWFINDER_LEVEL \
        --env SAST_DOCKER_CLIENT_NEGOTIATION_TIMEOUT \
        --env SAST_PULL_ANALYZER_IMAGE_TIMEOUT \
        --env SAST_RUN_ANALYZER_TIMEOUT \
        --volume "$PWD:/code" \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        "registry.gitlab.com/gitlab-org/security-products/sast:$SAST_VERSION" /app/bin/run /code
  dependencies: []
  artifacts:
    reports:
      sast: gl-sast-report.json
```

You can supply many other [settings variables](https://gitlab.com/gitlab-org/security-products/sast#settings)
via `docker run --env` to customize your job execution.

### Manual job definition for GitLab 11.4 and earlier (deprecated)

CAUTION: **Deprecated:**
Before GitLab 11.5, the SAST job and artifact had to be named specifically
to automatically extract report data and show it in the merge request widget.
While these old job definitions are still maintained, they have been deprecated
and may be removed in the next major release, GitLab 12.0. You are strongly
advised to update your current `.gitlab-ci.yml` configuration to reflect that change.

For GitLab 11.4 and earlier, the SAST job should look like:

```yaml
sast:
  image: docker:stable
  variables:
    DOCKER_DRIVER: overlay2
  allow_failure: true
  services:
    - docker:stable-dind
  script:
    - export SAST_VERSION=${SP_VERSION:-$(echo "$CI_SERVER_VERSION" | sed 's/^\([0-9]*\)\.\([0-9]*\).*/\1-\2-stable/')}
    - docker run
        --env SAST_CONFIDENCE_LEVEL="${SAST_CONFIDENCE_LEVEL:-3}"
        --volume "$PWD:/code"
        --volume /var/run/docker.sock:/var/run/docker.sock
        "registry.gitlab.com/gitlab-org/security-products/sast:$SAST_VERSION" /app/bin/run /code
  artifacts:
    paths: [gl-sast-report.json]
```

## Reports JSON format

CAUTION: **Caution:**
The JSON report artifacts are not a public API of SAST and their format may change in the future.

The SAST tool emits a JSON report report file. Here is an example of the report structure with all important parts of
it highlighted:

```json-doc
{
  "version": "2.0",
  "vulnerabilities": [
    {
      "category": "sast",
      "name": "Predictable pseudorandom number generator",
      "message": "Predictable pseudorandom number generator",
      "description": "The use of java.util.Random is predictable",
      "cve": "818bf5dacb291e15d9e6dc3c5ac32178:PREDICTABLE_RANDOM",
      "severity": "Medium",
      "confidence": "Medium",
      "scanner": {
        "id": "find_sec_bugs",
        "name": "Find Security Bugs"
      },
      "location": {
        "file": "groovy/src/main/groovy/com/gitlab/security_products/tests/App.groovy",
        "start_line": 47,
        "end_line": 47,
        "class": "com.gitlab.security_products.tests.App",
        "method": "generateSecretToken2",
        "dependency": {
          "package": {}
        }
      },
      "identifiers": [
        {
          "type": "find_sec_bugs_type",
          "name": "Find Security Bugs-PREDICTABLE_RANDOM",
          "value": "PREDICTABLE_RANDOM",
          "url": "https://find-sec-bugs.github.io/bugs.htm#PREDICTABLE_RANDOM"
        },
        {
          "type": "cwe",
          "name": "CWE-330",
          "value": "330",
          "url": "https://cwe.mitre.org/data/definitions/330.html"
        }
      ]
    },   
    {
      "category": "sast",
      "message": "Probable insecure usage of temp file/directory.",
      "cve": "python/hardcoded/hardcoded-tmp.py:4ad6d4c40a8c263fc265f3384724014e0a4f8dd6200af83e51ff120420038031:B108",
      "severity": "Medium",
      "confidence": "Medium",
      "scanner": {
        "id": "bandit",
        "name": "Bandit"
      },
      "location": {
        "file": "python/hardcoded/hardcoded-tmp.py",
        "start_line": 10,
        "end_line": 10,
        "dependency": {
          "package": {}
        }
      },
      "identifiers": [
        {
          "type": "bandit_test_id",
          "name": "Bandit Test ID B108",
          "value": "B108",
          "url": "https://docs.openstack.org/bandit/latest/plugins/b108_hardcoded_tmp_directory.html"
        }
      ]
    },    
  ],
  "remediations": []
}
```

Here is the description of the report file structure nodes and their meaning. All fields are mandatory to be present in
the report JSON unless stated otherwise. Presence of optional fields depends on the underlying analyzers being used.

| Report JSON node                        | Function |
|-----------------------------------------|----------|
| `version`                               | Report syntax version used to generate this JSON. |
| `vulnerabilities`                       | Array of vulnerability objects. |
| `vulnerabilities[].category`            | Where this vulnerability belongs (SAST, Dependency Scanning etc.). For SAST, it will always be `sast`. |
| `vulnerabilities[].name`                | Name of the vulnerability, this must not include the occurrence's specific information. Optional. |
| `vulnerabilities[].message`             | A short text that describes the vulnerability, it may include the occurrence's specific information. Optional. |
| `vulnerabilities[].description`         | A long text that describes the vulnerability. Optional. |
| `vulnerabilities[].cve`                 | A fingerprint string value that represents a concrete occurrence of the vulnerability. Is used to determine whether two vulnerability occurrences are same or different. May not be 100% accurate. **This is NOT a [CVE](https://cve.mitre.org/)**. |
| `vulnerabilities[].severity`            | How much the vulnerability impacts the software. Possible values: `Undefined` (an analyzer has not provided this info), `Info`, `Unknown`, `Low`, `Medium`, `High`, `Critical`. |
| `vulnerabilities[].confidence`          | How reliable the vulnerability's assessment is. Possible values: `Undefined` (an analyzer has not provided this info), `Ignore`, `Unknown`, `Experimental`, `Low`, `Medium`, `High`, `Confirmed`. |
| `vulnerabilities[].solution`            | Explanation of how to fix the vulnerability. Optional. |
| `vulnerabilities[].scanner`             | A node that describes the analyzer used to find this vulnerability. |
| `vulnerabilities[].scanner.id`          | Id of the scanner as a snake_case string. |
| `vulnerabilities[].scanner.name`        | Name of the scanner, for display purposes. |
| `vulnerabilities[].location`            | A node that tells where the vulnerability is located. | 
| `vulnerabilities[].location.file`       | Path to the file where the vulnerability is located. Optional. |
| `vulnerabilities[].location.start_line` | The first line of the code affected by the vulnerability. Optional. |
| `vulnerabilities[].location.end_line`   | The last line of the code affected by the vulnerability. Optional. |
| `vulnerabilities[].location.class`      | If specified, provides the name of the class where the vulnerability is located. Optional. |
| `vulnerabilities[].location.method`     | If specified, provides the name of the method where the vulnerability is located. Optional. |
| `vulnerabilities[].identifiers`         | An ordered array of references that identify a vulnerability on internal or external DBs. |
| `vulnerabilities[].identifiers[].type`  | Type of the identifier. Possible values: common identifier types (among `cve`, `cwe`, `osvdb`, and `usn`) or analyzer-dependent ones (e.g., `bandit_test_id` for [Bandit analyzer](https://wiki.openstack.org/wiki/Security/Projects/Bandit)). |
| `vulnerabilities[].identifiers[].name`  | Name of the identifier for display purposes. |
| `vulnerabilities[].identifiers[].value` | Value of the identifier for matching purposes. |
| `vulnerabilities[].identifiers[].url`   | URL to identifier's documentation. Optional. | 

## Secret detection

GitLab is also able to detect secrets and credentials that have been unintentionally pushed to the repository.
For example, an API key that allows write access to third-party deployment environments.

This check is performed by a specific analyzer during the `sast` job. It runs regardless of the programming
language of your app, and you don't need to change anything to your
CI/CD configuration file to turn it on. Results are available in the SAST report.

GitLab currently includes [Gitleaks](https://github.com/zricethezav/gitleaks) and [TruffleHog](https://github.com/dxa4481/truffleHog) checks.

## Security report under pipelines

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/3776)
in [GitLab Ultimate](https://about.gitlab.com/pricing) 10.6.

Visit any pipeline page which has a `sast` job and you will be able to see
the security report tab with the listed vulnerabilities (if any).

![Security Report](img/security_report.png)

## Security Dashboard

The Security Dashboard is a good place to get an overview of all the security
vulnerabilities in your groups and projects. Read more about the
[Security Dashboard](../security_dashboard/index.md).

## Interacting with the vulnerabilities

Once a vulnerability is found, you can interact with it. Read more on how to
[interact with the vulnerabilities](../index.md#interacting-with-the-vulnerabilities).
