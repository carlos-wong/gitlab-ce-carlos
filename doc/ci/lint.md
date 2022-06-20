---
stage: Verify
group: Pipeline Authoring
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Validate GitLab CI/CD configuration **(FREE)**

Use the CI Lint tool to check the validity of GitLab CI/CD configuration.
You can validate the syntax from a `.gitlab-ci.yml` file or any other sample CI/CD configuration.
This tool checks for syntax and logic errors, and can simulate pipeline
creation to try to find more complicated configuration problems.

If you use the [pipeline editor](pipeline_editor/index.md), it verifies configuration
syntax automatically.

If you use VS Code, you can validate your CI/CD configuration with the
[GitLab Workflow VS Code extension](../user/project/repository/vscode.md).

## Check CI/CD syntax

The CI lint tool checks the syntax of GitLab CI/CD configuration, including
configuration added with the [`includes` keyword](yaml/index.md#include).

To check CI/CD configuration with the CI lint tool:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **CI/CD > Pipelines**.
1. In the top right, select **CI lint**.
1. Paste a copy of the CI/CD configuration you want to check into the text box.
1. Select **Validate**.

## Simulate a pipeline

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/229794) in GitLab 13.3.

You can simulate the creation of a GitLab CI/CD pipeline to find more complicated issues,
including problems with [`needs`](yaml/index.md#needs) and [`rules`](yaml/index.md#rules)
configuration. A simulation runs as a Git `push` event on the default branch.

Prerequisites:

- You must have [permissions](../user/permissions.md#project-members-permissions)
  to create pipelines on this branch to validate with a simulation.

To simulate a pipeline:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **CI/CD > Pipelines**.
1. In the top right, select **CI lint**.
1. Paste a copy of the CI/CD configuration you want to check into the text box.
1. Select **Simulate pipeline creation for the default branch**.
1. Select **Validate**.
