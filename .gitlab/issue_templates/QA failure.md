<!---
Before opening a new QA failure issue, make sure to first search for it in the
QA failures board: https://gitlab.com/groups/gitlab-org/-/boards/1385578

The issue should have the following:

- The relative path of the failing spec file in the title, e.g. if the login
  test fails, include `qa/specs/features/browser_ui/1_manage/login/log_in_spec.rb` in the title.
  This is required so that existing issues can easily be found by searching for the spec file.
- If the issue is about multiple test failures, include the path for each failing spec file in the description.
- A link to the failing job.
- The stack trace from the job's logs in the "Stack trace" section below.
- A screenshot (if available), and HTML capture (if available), in the "Screenshot / HTML page" section below.
--->

### Summary



### Stack trace

```
PUT STACK TRACE HERE
```

### Screenshot / HTML page

<!--
Attach the screenshot and HTML snapshot of the page from the job's artifacts:
1. Download the job's artifacts and unarchive them.
1. Open the `gitlab-qa-run-2020-*/gitlab-{ce,ee}-qa-*/{,ee}/{api,browser_ui}/<path to failed test>` folder.
1. Select the `.png` and `.html` files that appears in the job logs (look for `HTML screenshot: /path/to/html/page.html` / `Image screenshot: `/path/to/html/page.png`).
1. Drag and drop them here.
-->

### Possible fixes


<!-- Default due date. -->
/due in 2 weeks

<!-- Base labels. -->
/label ~Quality ~QA ~bug ~S1

<!--
Choose the stage that appears in the test path, e.g. ~"devops::create" for
`qa/specs/features/browser_ui/3_create/web_ide/add_file_template_spec.rb`.
-->
/label ~devops::

<!--
Select a label for where the failure was found, e.g. if the failure occurred in
a nightly pipeline, select ~"found:nightly".
-->
/label ~found:

<!--
https://about.gitlab.com/handbook/engineering/quality/guidelines/#priorities:
- ~P1: Tests that are needed to verify fundamental GitLab functionality.
- ~P2: Tests that deal with external integrations which may take a longer time to debug and fix.
-->
/label ~P

<!-- Select the current milestone if ~P1 or the next milestone if ~P2. -->
/milestone %
