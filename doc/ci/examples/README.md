---
comments: false
---

# GitLab CI/CD Examples

Examples are a useful way of understanding how to implement GitLab CI/CD for your specific use case.

Examples are available in several forms. As a collection of:

- `.gitlab-ci.yml` [template files](https://gitlab.com/gitlab-org/gitlab-ce/tree/master/lib/gitlab/ci/templates) maintained in GitLab. When you create a new file via the UI,
  GitLab will give you the option to choose one of these templates. This will allow you to quickly bootstrap your project for CI/CD.
  If your favorite programming language or framework are missing, we would love your help by sending a merge request with a new `.gitlab-ci.yml` to this project.
- Repositories with [example projects](https://gitlab.com/gitlab-examples) for various languages. You can fork and adjust them to your own needs.
- Examples and [other resources](#other-resources) listed below.

## CI/CD examples

The following table lists examples for different use cases:

| Use case                                       | Resource                                                                                                             |
|:-----------------------------------------------|:---------------------------------------------------------------------------------------------------------------------|
| Browser performance testing                    | [Browser Performance Testing with the Sitespeed.io container](browser_performance.md).                               |
| Clojure                                        | [Test a Clojure application with GitLab CI/CD](test-clojure-application.md).                                         |
| Code quality analysis                          | [Analyze your project's Code Quality](code_quality.md). **[STARTER]**                                                |
| Container scanning                             | [Container Scanning with GitLab CI/CD](container_scanning.md).                                                       |
| Dependency scanning                            | [Dependency Scanning with GitLab CI/CD](dependency_scanning.md). **[ULTIMATE]**                                      |
| Deployment with `dpl`                          | [Using `dpl` as deployment tool](deployment/README.md).                                                              |
| Dynamic application<br>security testing (DAST) | [Dynamic Application Security Testing with GitLab CI/CD](dast.md) **[ULTIMATE]**                                     |
| Elixir                                         | [Testing a Phoenix application with GitLab CI/CD](test_phoenix_app_with_gitlab_ci_cd/index.md).                      |
| Game development                               | [DevOps and Game Dev with GitLab CI/CD](devops_and_game_dev_with_gitlab_ci_cd/index.md).                             |
| GitLab Pages                                   | See the [GitLab Pages](../../user/project/pages/index.md) documentation for a complete example.                      |
| Java                                           | [Deploy a Spring Boot application to Cloud Foundry with GitLab CI/CD](deploy_spring_boot_to_cloud_foundry/index.md). |
| JUnit                                          | [JUnit test reports](../junit_test_reports.md).                                                                      |
| License management                             | [Dependencies license management with GitLab CI/CD](license_management.md) **[ULTIMATE]**                            |
| Maven                                          | [How to deploy Maven projects to Artifactory with GitLab CI/CD](artifactory_and_gitlab/index.md).                    |
| PHP                                            | [Testing PHP projects](php.md).                                                                                      |
| PHP                                            | [Running Composer and NPM scripts with deployment via SCP in GitLab CI/CD](deployment/composer-npm-deploy.md).       |
| PHP                                            | [Test and deploy Laravel applications with GitLab CI/CD and Envoy](laravel_with_gitlab_and_envoy/index.md).          |
| Python                                         | [Test and deploy a Python application with GitLab CI/CD](test-and-deploy-python-application-to-heroku.md).           |
| Ruby                                           | [Test and deploy a Ruby application with GitLab CI/CD](test-and-deploy-ruby-application-to-heroku.md).               |
| Scala                                          | [Test and deploy a Scala application to Heroku](test-scala-application.md).                                          |
| Static application<br>security testing (SAST)  | [Static Application Security Testing with GitLab CI/CD](sast.md) **[ULTIMATE]**                                      |
| Testing                                        | [End-to-end testing with GitLab CI/CD and WebdriverIO](end_to_end_testing_webdriverio/index.md).                     |

### Contributing examples

Contributions are welcome! You can help your favorite programming
language users and GitLab by sending a merge request with a guide for that language.
You may want to apply for the [GitLab Community Writers Program](https://about.gitlab.com/community-writers/)
to get paid for writing complete articles for GitLab.

### Adding templates to your GitLab installation **[PREMIUM ONLY]**

If you want to have customized examples and templates for your own self-managed GitLab instance available to your team, your GitLab administrator can [designate an instance template repository](https://docs.gitlab.com/ee/user/admin_area/settings/instance_template_repository.html) that contains examples and templates specific to your enterprise.

## Other resources

This section provides further resources to help you get familiar with different aspects of GitLab CI/CD.

NOTE: **Note:**
These resources may no longer reflect the current state of GitLab CI/CD.

### CI/CD in the cloud

For examples of setting up GitLab CI/CD for cloud-based environments, see:

- [How to set up multi-account AWS SAM deployments with GitLab CI](https://about.gitlab.com/2019/02/04/multi-account-aws-sam-deployments-with-gitlab-ci/)
- [How to autoscale continuous deployment with GitLab Runner on DigitalOcean](https://about.gitlab.com/2018/06/19/autoscale-continuous-deployment-gitlab-runner-digital-ocean/)
- [How to create a CI/CD pipeline with Auto Deploy to Kubernetes using GitLab and Helm](https://about.gitlab.com/2017/09/21/how-to-create-ci-cd-pipeline-with-autodeploy-to-kubernetes-using-gitlab-and-helm/)

### Customer stories

For some customer experiences with GitLab CI/CD, see:

- [How Verizon Connect reduced datacenter deploys from 30 days to under 8 hours with GitLab](https://about.gitlab.com/2019/02/14/verizon-customer-story/)
- [How Wag! cut their release process from 40 minutes to just 6](https://about.gitlab.com/2019/01/16/wag-labs-blog-post/)
- [How Jaguar Land Rover embraced CI to speed up their software lifecycle](https://about.gitlab.com/2018/07/23/chris-hill-devops-enterprise-summit-talk/)

### Getting started

For some examples to help get you started, see:

- [GitLab CI/CD's 2018 highlights](https://about.gitlab.com/2019/01/21/gitlab-ci-cd-features-improvements/)
- [A beginner's guide to continuous integration](https://about.gitlab.com/2018/01/22/a-beginners-guide-to-continuous-integration/)
- [Making CI easier with GitLab](https://about.gitlab.com/2017/07/13/making-ci-easier-with-gitlab/)

### Implementing GitLab CI/CD

For examples of others who have implemented GitLab CI/CD, see:

- [How to streamline interactions between multiple repositories with multi-project pipelines](https://about.gitlab.com/2018/10/31/use-multiproject-pipelines-with-gitlab-cicd/)
- [How we used GitLab CI to build GitLab faster](https://about.gitlab.com/2018/05/02/using-gitlab-ci-to-build-gitlab-faster/)
- [Test all the things in GitLab CI with Docker by example](https://about.gitlab.com/2018/02/05/test-all-the-things-gitlab-ci-docker-examples/)
- [A Craftsman looks at continuous integration](https://about.gitlab.com/2018/01/17/craftsman-looks-at-continuous-integration/)
- [Go tools and GitLab: How to do continuous integration like a boss](https://about.gitlab.com/2017/11/27/go-tools-and-gitlab-how-to-do-continuous-integration-like-a-boss/)
- [GitBot – automating boring Git operations with CI](https://about.gitlab.com/2017/11/02/automating-boring-git-operations-gitlab-ci/)
- [How to use GitLab CI for Vue.js](https://about.gitlab.com/2017/09/12/vuejs-app-gitlab/)
- Video: [GitLab CI/CD Deep Dive](https://youtu.be/pBe4t1CD8Fc?t=195)
- [Dockerizing GitLab Review Apps](https://about.gitlab.com/2017/07/11/dockerizing-review-apps/)
- [Fast and natural continuous integration with GitLab CI](https://about.gitlab.com/2017/05/22/fast-and-natural-continuous-integration-with-gitlab-ci/)
- [Demo: CI/CD with GitLab in action](https://about.gitlab.com/2017/03/13/ci-cd-demo/)

### Integrating GitLab CI/CD with other systems

To see how you can integrate GitLab CI/CD with third-party systems, see:

- [Streamline and shorten error remediation with Sentry’s new GitLab integration](https://about.gitlab.com/2019/01/25/sentry-integration-blog-post/)
- [How to simplify your smart home configuration with GitLab CI/CD](https://about.gitlab.com/2018/08/02/using-the-gitlab-ci-slash-cd-for-smart-home-configuration-management/)
- [Demo: GitLab + Jira + Jenkins](https://about.gitlab.com/2018/07/30/gitlab-workflow-with-jira-jenkins/)
- [Introducing Auto Breakfast from GitLab (sort of)](https://about.gitlab.com/2018/06/29/introducing-auto-breakfast-from-gitlab/)

### Mobile development

For help with using GitLab CI/CD for mobile application development, see:

- [How to publish Android apps to the Google Play Store with GitLab and fastlane](https://about.gitlab.com/2019/01/28/android-publishing-with-gitlab-and-fastlane/)
- [Setting up GitLab CI for Android projects](https://about.gitlab.com/2018/10/24/setting-up-gitlab-ci-for-android-projects/)
- [Working with YAML in GitLab CI from the Android perspective](https://about.gitlab.com/2017/11/20/working-with-yaml-gitlab-ci-android/)
- [How to use GitLab CI and MacStadium to build your macOS or iOS projects](https://about.gitlab.com/2017/05/15/how-to-use-macstadium-and-gitlab-ci-to-build-your-macos-or-ios-projects/)
- [Setting up GitLab CI for iOS projects](https://about.gitlab.com/2016/03/10/setting-up-gitlab-ci-for-ios-projects/)
