---
type: reference
---

# Push Options

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/15643) in GitLab 11.7.

GitLab supports using [Git push options](https://git-scm.com/docs/git-push#Documentation/git-push.txt--oltoptiongt)
to perform various actions at the same time as pushing changes.

Currently, there are push options available for:

- [Skipping CI jobs](#push-options-for-gitlab-cicd)
- [Merge requests](#push-options-for-merge-requests)

NOTE: **Note:**
Git push options are only available with Git 2.10 or newer.

For Git versions 2.10 to 2.17 use `--push-option`:

```shell
git push --push-option=<push_option>
```

For version 2.18 and later, you can use the above format, or the shorter `-o`:

```shell
git push -o <push_option>
```

## Push options for GitLab CI/CD

If the `ci.skip` push option is used, the commit will be pushed, but no [CI pipeline](../../ci/pipelines.md)
will be created.

| Push option | Description |
| ----------- | ----------- |
| `ci.skip`   | Do not create a CI pipeline for the latest push. |

For example:

```shell
git push -o ci.skip
```

## Push options for merge requests

You can use Git push options to perform certain actions for merge requests at the same
time as pushing changes:

| Push option                                  | Description                                                                                                     | Introduced in version |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------- |
| `merge_request.create`                       | Create a new merge request for the pushed branch.                                                               | [11.10](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/26752) |
| `merge_request.target=<branch_name>`         | Set the target of the merge request to a particular branch.                                                     | [11.10](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/26752) |
| `merge_request.merge_when_pipeline_succeeds` | Set the merge request to [merge when its pipeline succeeds](merge_requests/merge_when_pipeline_succeeds.md).    | [11.10](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/26752) |
| `merge_request.remove_source_branch`         | Set the merge request to remove the source branch when it's merged.                                             | [12.2](https://gitlab.com/gitlab-org/gitlab-foss/issues/64320)          |
| `merge_request.title="<title>"`              | Set the title of the merge request. Ex: `git push -o merge_request.title="The title I want"`.                   | [12.2](https://gitlab.com/gitlab-org/gitlab-foss/issues/64320)          |
| `merge_request.description="<description>"`  | Set the description of the merge request. Ex: `git push -o merge_request.description="The description I want"`. | [12.2](https://gitlab.com/gitlab-org/gitlab-foss/issues/64320)          |
| `merge_request.label="<label>"`              | Add labels to the merge request. If the label does not exist, it will be created. For example, for two labels: `git push -o merge_request.label="label1" -o merge_request.label="label2"`. | [12.3](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/31831) |
| `merge_request.unlabel="<label>"`            | Remove labels from the merge request. For example, for two labels: `git push -o merge_request.unlabel="label1" -o merge_request.unlabel="label2"`. | [12.3](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/31831) |

If you use a push option that requires text with spaces in it, you need to enclose it
in quotes (`"`). You can omit the quotes if there are no spaces. Some examples:

```shell
git push -o merge_request.label="Label with spaces"
git push -o merge_request.label=Label-with-no-spaces
```

You can combine push options to accomplish multiple tasks at once, by using
multiple `-o` (or `--push-option`) flags. For example, if you want to create a new
merge request, and target a branch named `my-target-branch`:

```shell
git push -o merge_request.create -o merge_request.target=my-target-branch
```
