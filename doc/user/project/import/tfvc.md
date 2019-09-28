---
type: concepts
---

# Migrating from TFVC to Git

Team Foundation Server (TFS), renamed [Azure DevOps Server](https://azure.microsoft.com/en-us/services/devops/server/)
in 2019, is a set of tools developed by Microsoft which also includes
[Team Foundation Version Control](https://docs.microsoft.com/en-us/azure/devops/repos/tfvc/overview?view=azure-devops)
(TFVC), a centralized version control system similar to Git.

In this document, we focus on the TFVC to Git migration.

## TFVC vs Git

The main differences between TFVC and Git are:

- **Git is distributed:** While TFVC is centralized using a client-server architecture,
  Git is distributed. This translates to Git having a more flexible workflow since
  you work with a copy of the entire repository. This allows you to quickly
  switch branches or merge, for example, without needing to communicate with a remote server.
- **Storage:** Changes in a centralized version control system are per file (changeset),
  while in Git a committed file is stored in its entirety (snapshot). That means that it is
  very easy to revert or undo a whole change in Git.

For more information, see:

- Microsoft's [comparison of Git and TFVC](https://docs.microsoft.com/en-us/azure/devops/repos/tfvc/comparison-git-tfvc?view=azure-devops).
- The Wikipedia [comparison of version control software](https://en.wikipedia.org/wiki/Comparison_of_version_control_software).

## Why migrate

Advantages of migrating to Git/GitLab:

- **No licensing costs:** Git is open source, while TFVC is proprietary.
- **Shorter learning curve:** Git has a big community and a vast number of
  tutorials to get you started (see our [Git topic](../../../topics/git/index.md)).
- **Integration with modern tools:** After migrating to Git and GitLab, you will have
  an open source, end-to-end software development platform with built-in version
  control, issue tracking, code review, CI/CD, and more.

## How to migrate

The best option to migrate from TFVC to Git is to use the [`git-tfs`](https://github.com/git-tfs/git-tfs)
tool. Read the [Migrate TFS to Git](https://github.com/git-tfs/git-tfs/blob/master/doc/usecases/migrate_tfs_to_git.md)
guide for more details.
