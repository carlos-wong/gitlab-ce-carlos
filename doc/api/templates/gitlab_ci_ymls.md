---
type: reference
---

# GitLab CI YMLs API

In GitLab, there is an API endpoint available to work with CI YMLs. For more
information on CI/CD pipeline configuration in GitLab, see the
[configuration reference documentation](../../ci/yaml/README.md).

## List GitLab CI YML templates

Get all GitLab CI YML templates.

```plaintext
GET /templates/gitlab_ci_ymls
```

Example request:

```bash
curl https://gitlab.example.com/api/v4/templates/gitlab_ci_ymls
```

Example response:

```json
[
  {
    "key": "Android",
    "name": "Android"
  },
  {
    "key": "Android-Fastlane",
    "name": "Android-Fastlane"
  },
  {
    "key": "Auto-DevOps",
    "name": "Auto-DevOps"
  },
  {
    "key": "Bash",
    "name": "Bash"
  },
  {
    "key": "C++",
    "name": "C++"
  },
  {
    "key": "Chef",
    "name": "Chef"
  },
  {
    "key": "Clojure",
    "name": "Clojure"
  },
  {
    "key": "Code-Quality",
    "name": "Code-Quality"
  },
  {
    "key": "Crystal",
    "name": "Crystal"
  },
  {
    "key": "Django",
    "name": "Django"
  },
  {
    "key": "Docker",
    "name": "Docker"
  },
  {
    "key": "Elixir",
    "name": "Elixir"
  },
  {
    "key": "Go",
    "name": "Go"
  },
  {
    "key": "Gradle",
    "name": "Gradle"
  },
  {
    "key": "Grails",
    "name": "Grails"
  },
  {
    "key": "Julia",
    "name": "Julia"
  },
  {
    "key": "LaTeX",
    "name": "LaTeX"
  },
  {
    "key": "Laravel",
    "name": "Laravel"
  },
  {
    "key": "Maven",
    "name": "Maven"
  },
  {
    "key": "Mono",
    "name": "Mono"
  }
]
```

## Single GitLab CI YML template

Get a single GitLab CI YML template.

```plaintext
GET /templates/gitlab_ci_ymls/:key
```

| Attribute  | Type   | Required | Description                           |
| ---------- | ------ | -------- | ------------------------------------- |
| `key`      | string | yes      | The key of the GitLab CI YML template |

Example request:

```bash
curl https://gitlab.example.com/api/v4/templates/gitlab_ci_ymls/Ruby
```

Example response:

```json
{
  "name": "Ruby",
  "content": "# This file is a template, and might need editing before it works on your project.\n# Official language image. Look for the different tagged releases at:\n# https://hub.docker.com/r/library/ruby/tags/\nimage: \"ruby:2.5\"\n\n# Pick zero or more services to be used on all builds.\n# Only needed when using a docker container to run your tests in.\n# Check out: http://docs.gitlab.com/ce/ci/docker/using_docker_images.html#what-is-a-service\nservices:\n  - mysql:latest\n  - redis:latest\n  - postgres:latest\n\nvariables:\n  POSTGRES_DB: database_name\n\n# Cache gems in between builds\ncache:\n  paths:\n    - vendor/ruby\n\n# This is a basic example for a gem or script which doesn't use\n# services such as redis or postgres\nbefore_script:\n  - ruby -v  # Print out ruby version for debugging\n  # Uncomment next line if your rails app needs a JS runtime:\n  # - apt-get update -q && apt-get install nodejs -yqq\n  - bundle install -j $(nproc) --path vendor  # Install dependencies into ./vendor/ruby\n\n# Optional - Delete if not using `rubocop`\nrubocop:\n  script:\n    - rubocop\n\nrspec:\n  script:\n    - rspec spec\n\nrails:\n  variables:\n    DATABASE_URL: \"postgresql://postgres:postgres@postgres:5432/$POSTGRES_DB\"\n  script:\n    - rails db:migrate\n    - rails db:seed\n    - rails test\n\n# This deploy job uses a simple deploy flow to Heroku, other providers, e.g. AWS Elastic Beanstalk\n# are supported too: https://github.com/travis-ci/dpl\ndeploy:\n  type: deploy\n  environment: production\n  script:\n    - gem install dpl\n    - dpl --provider=heroku --app=$HEROKU_APP_NAME --api-key=$HEROKU_PRODUCTION_KEY\n"
}
```

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
