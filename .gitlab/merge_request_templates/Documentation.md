## What does this MR do?

<!-- Briefly describe what this MR is about. -->

## Related issues

<!-- Link related issues below. -->

## Author's checklist

- [ ] Optional. Consider taking [the GitLab Technical Writing Fundamentals course](https://gitlab.edcast.com/pathways/ECL-02528ee2-c334-4e16-abf3-e9d8b8260de4).
- [ ] Follow the:
  - [Documentation process](https://docs.gitlab.com/ee/development/documentation/workflow.html).
  - [Documentation guidelines](https://docs.gitlab.com/ee/development/documentation/).
  - [Style Guide](https://docs.gitlab.com/ee/development/documentation/styleguide/).
- [ ] If you're adding or changing the main heading of the page (H1), ensure that the [product tier badge](https://docs.gitlab.com/ee/development/documentation/styleguide/index.html#product-tier-badges) is added.
- [ ] If you are a GitLab team member, [request a review](https://docs.gitlab.com/ee/development/code_review.html#dogfooding-the-attention-request-feature) based on:
    - The documentation page's [metadata](https://docs.gitlab.com/ee/development/documentation/#metadata).
    - The [associated Technical Writer](https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments).

If you are a GitLab team member and only adding documentation, do not add any of the following labels:

- `~"frontend"`
- `~"backend"`
- `~"type::bug"`
- `~"database"`

These labels cause the MR to be added to code verification QA issues.

## Reviewer's checklist

Documentation-related MRs should be reviewed by a Technical Writer for a non-blocking review, based on [Documentation Guidelines](https://docs.gitlab.com/ee/development/documentation/) and the [Style Guide](https://docs.gitlab.com/ee/development/documentation/styleguide/).

- [ ] If the content requires it, ensure the information is reviewed by a subject matter expert.
- Technical writer review items:
  - [ ] Ensure docs metadata is present and up-to-date.
  - [ ] Ensure the appropriate [labels](https://about.gitlab.com/handbook/engineering/ux/technical-writing/workflow/#labels) are added to this MR.
  - [ ] Ensure a release milestone is set.
  - If relevant to this MR, ensure [content topic type](https://docs.gitlab.com/ee/development/documentation/structure.html) principles are in use, including:
    - [ ] The headings should be something you'd do a Google search for. Instead of `Default behavior`, say something like `Default behavior when you close an issue`.
    - [ ] The headings (other than the page title) should be active. Instead of `Configuring GDK`, say something like `Configure GDK`.
    - [ ] Any task steps should be written as a numbered list.
    - If the content still needs to be edited for topic types, you can create a follow-up issue with the ~"docs-technical-debt" label.
- [ ] Review by assigned maintainer, who can always request/require the reviews above. Maintainer's review can occur before or after a technical writer review.

/label ~documentation ~"type::maintenance" ~"docs::improvement"
/assign me
