---
type: howto
---

# Cloud deployment

Interacting with a major cloud provider such as Amazon AWS may have become a much needed task that's
part of your delivery process. GitLab is making this process less painful by providing Docker images
that come with the needed libraries and tools pre-installed.
By referencing them in your CI/CD pipeline, you'll be able to interact with your chosen
cloud provider more easily.

## AWS

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/31167) in GitLab 12.6.

GitLab's AWS Docker image provides the [AWS Command Line Interface](https://aws.amazon.com/cli/),
which enables you to run `aws` commands. As part of your deployment strategy, you can run `aws` commands directly from
`.gitlab-ci.yml` by specifying [GitLab's AWS Docker image](https://gitlab.com/gitlab-org/cloud-deploy).

Some credentials are required to be able to run `aws` commands:

1. Sign up for [an AWS account](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-set-up.html) if you don't have one yet.
1. Log in onto the console and create [a new IAM user](https://console.aws.amazon.com/iam/home#/home).
1. Select your newly created user to access its details. Navigate to **Security credentials > Create a new access key**.

   NOTE: **Note:**
   A new **Access key ID** and **Secret access key** pair will be generated. Please take a note of them right away.

1. In your GitLab project, go to **Settings > CI / CD**. Set the Access key ID and Secret access key as [environment variables](../variables/README.md#gitlab-cicd-environment-variables), using the following variable names:

   | Env. variable name      | Value                    |
   |:------------------------|:-------------------------|
   | `AWS_ACCESS_KEY_ID`     | Your "Access key ID"     |
   | `AWS_SECRET_ACCESS_KEY` | Your "Secret access key" |

1. You can now use `aws` commands in the `.gitlab-ci.yml` file of this project:

   ```yml
   deploy:
     stage: deploy
     image: registry.gitlab.com/gitlab-org/cloud-deploy:latest # see the note below
     script:
       - aws s3 ...
       - aws create-deployment ...
   ```

   NOTE: **Note:**
   Please note that the image used in the example above
   (`registry.gitlab.com/gitlab-org/cloud-deploy:latest`) is hosted on the [GitLab
   Container Registry](../../user/packages/container_registry/index.md) and is
   ready to use. Alternatively, replace the image with another one hosted on [AWS ECR](#aws-ecr).

### AWS ECR

Instead of referencing an image hosted on the GitLab Registry, you are free to
reference any other image hosted on any third-party registry, such as
[Amazon Elastic Container Registry (ECR)](https://aws.amazon.com/ecr/).

To do so, please make sure to [push your image into your ECR
repository](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html)
before referencing it in your `.gitlab-ci.yml` file and replace the `image`
path to point to your ECR.
