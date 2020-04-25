---
disqus_identifier: 'https://docs.gitlab.com/ee/workflow/workflow.html'
---

# Feature branch workflow

1. Clone project:

   ```shell
   git clone git@example.com:project-name.git
   ```

1. Create branch with your feature:

   ```shell
   git checkout -b $feature_name
   ```

1. Write code. Commit changes:

   ```shell
   git commit -am "My feature is ready"
   ```

1. Push your branch to GitLab:

   ```shell
   git push origin $feature_name
   ```

1. Review your code on commits page.

1. Create a merge request.

1. Your team lead will review the code &amp; merge it to the main branch.
