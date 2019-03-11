---
description: 'Writing styles, markup, formatting, and other standards for GitLab Documentation.'
---

# Documentation Style Guide

The documentation style guide defines the markup structure used in
GitLab documentation. Check the
[documentation guidelines](index.md) for general development instructions.

See the GitLab handbook for the [writing style guidelines](https://about.gitlab.com/handbook/communication/#writing-style-guidelines).

For programmatic help adhering to the guidelines, see [linting](index.md#linting).

## Files

- [Directory structure](index.md#location-and-naming-documents): place the docs
  in the correct location.
- [Documentation files](index.md#documentation-files): name the files accordingly.

DANGER: **Attention:**
**Do not** use capital letters, spaces, or special chars in file names,
branch names, directory names, headings, or in anything that generates a path.

NOTE: **Note:**
**Do not** create new `README.md` files, name them `index.md` instead. There's
a test that will fail if it spots a new `README.md` file.

### Markdown

The [documentation website](https://docs.gitlab.com) had its markdown engine migrated from [Redcarpet to GitLab Kramdown](https://gitlab.com/gitlab-com/gitlab-docs/merge_requests/108)
in October 2018.

The [`gitlab-kramdown`](https://gitlab.com/gitlab-org/gitlab_kramdown)
gem will support all [GFM markup](../../user/markdown.md) in the future. For now,
use regular markdown markup, following the rules on this style guide. For a complete
Kramdown reference, check the [GitLab Markdown Kramdown Guide](https://about.gitlab.com/handbook/product/technical-writing/markdown-guide/).
Use Kramdown markup wisely: do not overuse its specific markup (e.g., `{:.class}`) as it will not render properly in
[`/help`](index.md#gitlab-help).

## Content

These guidelines help toward the goal of having every user's search of documentation
yield a useful result, and ensuring content is helpful and easy to consume.

- What to include:
  - Any and all helpful information, processes, and tips for implementing,
  using, and troubleshooting GitLab features. [The documentation is the single source of truth](https://about.gitlab.com/handbook/documentation/#documentation-as-single-source-of-truth-ssot)
  for this information.
  - 'Risky' or niche problem-solving steps. There is no reason to withhold these or
  store them elsewhere; simply include them along with the rest of the docs including all necessary
  detail, such as specific warnings and caveats about potential ramifications.
  - Any content types/sources, if relevant to users or admins. You can freely
  include presentations, videos, etc.; no matter who it was originally written for,
  if it is helpful to any of our audiences, we can include it. If an outside source
  that's under copyright, rephrase, or summarize and link out; do not copy and paste.
  - All applicable subsections as described on the [structure and template](structure.md) page,
  with files organized in the [correct directory](index.md#documentation-directory-structure).
- To ensure discoverability, link to each doc from its higher-level index page and other related pages.
- When referencing other GitLab products and features, link to their
  respective docs; when referencing third-party products or technologies,
  link out to their external sites, documentation, and resources.
- Do not duplicate information.
- Structure content in alphabetical order in tables, lists, etc., unless there is
  a logical reason not to (for example, when mirroring the UI or an ordered sequence).

## Language

- Use inclusive language and avoid jargon, as well as uncommon
  words. The docs should be clear and easy to understand.
- Write in the 3rd person (use "we", "you", "us", "one", instead of "I" or "me").
- Be clear, concise, and stick to the goal of the doc.
- Write in US English.
- Capitalize "G" and "L" in GitLab.
- Use title case when referring to [features](https://about.gitlab.com/features/) or
  [products](https://about.gitlab.com/pricing/) (e.g., GitLab Runner, Geo,
  Issue Boards, GitLab Core, Git, Prometheus, Kubernetes, etc), and methods or methodologies
  (e.g., Continuous Integration, Continuous Deployment, Scrum, Agile, etc). Note that
  some features are also objects (e.g. "GitLab's Merge Requests support X." and "Create a new merge request for Z.").

## Text

- Split up long lines (wrap text), this makes it much easier to review and edit. Only
  double line breaks are shown as a full line break by creating new paragraphs.
  80-100 characters is the recommended line length.
- Use sentence case for titles, headings, labels, menu items, and buttons.
- Jump a line between different markups (e.g., after every paragraph, header, list, etc). Example:

    ```md
    ## Header

    Paragraph.

    - List item 1
    - List item 2
    ```

### Tables overlapping the ToC

By default, all tables have a width of 100% on docs.gitlab.com.
In a few cases, the table will overlap the table of contents (ToC).
For these cases, add an entry to the document's frontmatter to
render them displaying block. This will make sure the table
is displayed behind the ToC, scrolling horizontally:

```md
---
table_display_block: true
---
```

## Emphasis

- Use double asterisks (`**`) to mark a word or text in bold (`**bold**`).
- Use underscore (`_`) for text in italics (`_italic_`).
- Use greater than (`>`) for blockquotes.

## Punctuation

Check the general punctuation rules for the GitLab documentation on the table below.
Check specific punctuation rules for [list items](#list-items) below.

| Rule | Example |
| ---- | ------- |
| Always end full sentences with a period. | _For a complete overview, read through this document._|
| Always add a space after a period when beginning a new sentence | _For a complete overview, check this doc. For other references, check out this guide._ |
| Do not use double spaces. | --- |
| Do not use tabs for indentation. Use spaces instead. You can configure your code editor to output spaces instead of tabs when pressing the tab key. | --- |
| Use serial commas ("Oxford commas") before the final 'and/or' in a list. | _You can create new issues, merge requests, and milestones._ |
| Always add a space before and after dashes when using it in a sentence (for replacing a comma, for example). | _You should try this - or not._ |
| Always use lowercase after a colon. | _Related Issues: a way to create a relationship between issues._ |

## List items

- Always start list items with a capital letter.
- Always leave a blank line before and after a list.
- Begin a line with spaces (not tabs) to denote a subitem.
- To nest subitems, indent them with two spaces.
- To nest code blocks, indent them with four spaces.
- Only use ordered lists when their items describe a sequence of steps to follow.

**Markup:**

- Use dashes (`-`) for unordered lists instead of asterisks (`*`).
- Use the number one (`1`) for each item in an ordered list.
  When rendered, the list items will appear with sequential numbering.

**Punctuation:**

- Do not add commas (`,`) or semicolons (`;`) to the end of a list item.
- Only add periods to the end of a list item if the item consists of a complete sentence. The [definition of full sentence](https://www2.le.ac.uk/offices/ld/resources/writing/grammar/grammar-guides/sentence) is: _"a complete sentence always contains a verb, expresses a complete idea, and makes sense standing alone"_.
- Be consistent throughout the list: if the majority of the items do not end in a period, do not end any of the items in a period, even if they consist of a complete sentence. The opposite is also valid: if the majority of the items end with a period, end all with a period.
- Separate list items from explanatory text with a colon (`:`). For example:

    ```md
    The list is as follows:

    - First item: this explains the first item.
    - Second item: this explains the second item.
    ```

**Examples:**

Do:

- First list item
- Second list item
- Third list item

Don't:

- First list item
- Second list item
- Third list item.

Do:

- Let's say this is a complete sentence.
- Let's say this is also a complete sentence.
- Not a complete sentence.

Don't:

- Let's say this is a complete sentence.
- Let's say this is also a complete sentence.
- Not a complete sentence

## Quotes

Valid for markdown content only, not for frontmatter entries:

- Standard quotes: double quotes (`"`). Example: "This is wrapped in double quotes".
- Quote within a quote: double quotes (`"`) wrap single quotes (`'`). Example: "I am 'quoting' something within a quote".

For other punctuation rules, please refer to the
[GitLab UX guide](https://design.gitlab.com/content/punctuation/).

## Headings

- Add **only one H1** in each document, by adding `#` at the beginning of
  it (when using markdown). The `h1` will be the document `<title>`.
- Start with an `h2` (`##`), and respect the order `h2` > `h3` > `h4` > `h5` > `h6`.
  Never skip the hierarchy level, such as `h2` > `h4`
- Avoid putting numbers in headings. Numbers shift, hence documentation anchor
  links shift too, which eventually leads to dead links. If you think it is
  compelling to add numbers in headings, make sure to at least discuss it with
  someone in the Merge Request.
- [Avoid using symbols and special chars](https://gitlab.com/gitlab-com/gitlab-docs/issues/84)
  in headers. Whenever possible, they should be plain and short text.
- Avoid adding things that show ephemeral statuses. For example, if a feature is
  considered beta or experimental, put this info in a note, not in the heading.
- When introducing a new document, be careful for the headings to be
  grammatically and syntactically correct. Mention an [assigned technical writer (TW)](https://about.gitlab.com/handbook/product/categories/)
  for review.
  This is to ensure that no document with wrong heading is going
  live without an audit, thus preventing dead links and redirection issues when
  corrected.
- Leave exactly one new line after a heading.
- Do not use links in headings.
- Add the corresponding [product badge](#product-badges) according to the tier the feature belongs.

## Links

- Use inline link markdown markup `[Text](https://example.com)`.
  It's easier to read, review, and maintain. **Do not** use `[Text][identifier]`.
- To link to internal documentation, use relative links, not full URLs. Use `../` to
  navigate to high-level directories, and always add the file name `file.md` at the
  end of the link with the `.md` extension, not `.html`.
  Example: instead of `[text](../../merge_requests/)`, use
  `[text](../../merge_requests/index.md)` or, `[text](../../ci/README.md)`, or,
  for anchor links, `[text](../../ci/README.md#examples)`.
  Using the markdown extension is necessary for the [`/help`](index.md#gitlab-help)
  section of GitLab.
- To link from CE to EE-only documentation, use the EE-only doc full URL.
- Use [meaningful anchor texts](https://www.futurehosting.com/blog/links-should-have-meaningful-anchor-text-heres-why/).
  E.g., instead of writing something like `Read more about GitLab Issue Boards [here](LINK)`,
  write `Read more about [GitLab Issue Boards](LINK)`.

### Links to confidential issues

Don't link directly to [confidential issues](../../user/project/issues/confidential_issues.md). These will fail for:

- Those without sufficient permissions.
- Automated link checkers.

Instead:

- Mention in the text that the information is contained in a confidential issue. This will reduce confusion.
- Provide a link in back ticks (`` ` ``) so that those with access to the issue can easily navigate to it.

Example:

```md
For more information, see the [confidential issue](https://docs.gitlab.com/ee/user/project/issues/confidential_issues.html) `https://gitlab.com/gitlab-org/gitlab-ce/issues/<issue_number>`.
```

### Unlinking emails

By default, all email addresses will render in an email tag on docs.gitlab.com.
To escape the code block and unlink email addresses, use two backticks:

```md
`` example@email.com ``
```

## Navigation

To indicate the steps of navigation through the UI:

- Use the exact word as shown in the UI, including any capital letters as-is.
- Use bold text for navigation items and the char "greater than" (`>`) as separator
  (e.g., `Navigate to your project's **Settings > CI/CD**` ).
- If there are any expandable menus, make sure to mention that the user
  needs to expand the tab to find the settings you're referring to (e.g., `Navigate to your project's **Settings > CI/CD** and expand **General pipelines**`).

## Images

- Place images in a separate directory named `img/` in the same directory where
  the `.md` document that you're working on is located. Always prepend their
  names with the name of the document that they will be included in. For
  example, if there is a document called `twitter.md`, then a valid image name
  could be `twitter_login_screen.png`.
- Images should have a specific, non-generic name that will differentiate and describe them properly.
- Keep all file names in lower case.
- Consider using PNG images instead of JPEG.
- Compress all images with <https://tinypng.com/> or similar tool.
- Compress gifs with <https://ezgif.com/optimize> or similar tool.
- Images should be used (only when necessary) to _illustrate_ the description
  of a process, not to _replace_ it.
- Max image size: 100KB (gifs included).
- The GitLab docs do not support videos yet.

Inside the document:

- The Markdown way of using an image inside a document is:
  `![Proper description what the image is about](img/document_image_title.png)`
- Always use a proper description for what the image is about. That way, when a
  browser fails to show the image, this text will be used as an alternative
  description.
- If there are consecutive images with little text between them, always add
  three dashes (`---`) between the image and the text to create a horizontal
  line for better clarity.
- If a heading is placed right after an image, always add three dashes (`---`)
  between the image and the heading.

### Remove image shadow

All images displayed on docs.gitlab.com have a box shadow by default.
To remove the box shadow, use the image class `.image-noshadow` applied
directly to an HTML `img` tag:

```html
<img src="path/to/image.jpg" alt="Alt text (required)" class="image-noshadow">
```

## Code blocks

- Always wrap code added to a sentence in inline code blocks (``` ` ```).
  E.g., `.gitlab-ci.yml`, `git add .`, `CODEOWNERS`, `only: master`.
  File names, commands, entries, and anything that refers to code should be added to code blocks.
  To make things easier for the user, always add a full code block for things that can be
  useful to copy and paste, as they can easily do it with the button on code blocks.
- For regular code blocks, always use a highlighting class corresponding to the
  language for better readability. Examples:

  ````md
  ```ruby
  Ruby code
  ```

  ```js
  JavaScript code
  ```

  ```md
  Markdown code
  ```

  ```text
  Code for which no specific highlighting class is available.
  ```
  ````

- To display raw markdown instead of rendered markdown, use four backticks on their own lines around the
  markdown to display. See [example](https://gitlab.com/gitlab-org/gitlab-ce/blob/8c1991b9bb7e3b8d606481fdea316d633cfa5eb7/doc/development/documentation/styleguide.md#L275-287).
- For a complete reference on code blocks, check the [Kramdown guide](https://about.gitlab.com/handbook/product/technical-writing/markdown-guide/#code-blocks).

## Alert boxes

Whenever you want to call the attention to a particular sentence,
use the following markup for highlighting.

_Note that the alert boxes only work for one paragraph only. Multiple paragraphs,
lists, headers, etc will not render correctly. For multiple lines, use blockquotes instead._

### Note

```md
NOTE: **Note:**
This is something to note.
```

How it renders in docs.gitlab.com:

NOTE: **Note:**
This is something to note.

### Tip

```md
TIP: **Tip:**
This is a tip.
```

How it renders in docs.gitlab.com:

TIP: **Tip:**
This is a tip.

### Caution

```md
CAUTION: **Caution:**
This is something to be cautious about.
```

How it renders in docs.gitlab.com:

CAUTION: **Caution:**
This is something to be cautious about.

### Danger

```md
DANGER: **Danger:**
This is a breaking change, a bug, or something very important to note.
```

How it renders in docs.gitlab.com:

DANGER: **Danger:**
This is a breaking change, a bug, or something very important to note.

## Blockquotes

For highlighting a text within a blue blockquote, use this format:

```md
> This is a blockquote.
```

which renders in docs.gitlab.com to:

> This is a blockquote.

If the text spans across multiple lines it's OK to split the line.

For multiple paragraphs, use the symbol `>` before every line:

```md
> This is the first paragraph.
>
> This is the second paragraph.
>
> - This is a list item
> - Second item in the list
>
> ### This is an `h3`
```

Which renders to:

> This is the first paragraph.
>
> This is the second paragraph.
>
> - This is a list item
> - Second item in the list
>
> ### This is an `h3`
>{:.no_toc}

## Terms

To maintain consistency through GitLab documentation, the following guides documentation authors
on agreed styles and usage of terms.

### Describing UI elements

The following are styles to follow when describing UI elements on a screen:

- For elements with a visible label, use that label in bold with matching case. For example, `the **Cancel** button`.
- For elements with a tooltip or hover label, use that label in bold with matching case. For example, `the **Add status emoji** button`.

### Verbs for UI elements

The following are recommended verbs for specific uses.

| Recommended | Used for                   | Alternatives               |
|:------------|:---------------------------|:---------------------------|
| "click"     | buttons, links, menu items | "hit", "press", "select"   |
| "check"     | checkboxes                 | "enable", "click", "press" |
| "select"    | dropdowns                  | "pick"                     |
| "expand"    | expandable sections        | "open"                     |

### Other Verbs

| Recommended | Used for                        | Alternatives       |
|:------------|:--------------------------------|:-------------------|
| "go"        | making a browser go to location | "navigate", "open" |

## GitLab versions and tiers

- Every piece of documentation that comes with a new feature should declare the
  GitLab version that feature got introduced. Right below the heading add a
  blockquote:

    ```md
    > Introduced in GitLab 8.3.
    ```

- Whenever possible, every feature should have a link to the issue, MR or epic
  (in that order) that introduced it. The above quote would be then transformed to:

    ```md
    > [Introduced](<link-to-issue>) in GitLab 8.3.
    ```

- If the feature is only available in GitLab Enterprise Edition, don't forget to mention
  the [paid tier](https://about.gitlab.com/handbook/marketing/product-marketing/#tiers)
  the feature is available in:

    ```md
    > [Introduced](<link-to-issue>) in [GitLab Starter](https://about.gitlab.com/pricing/) 10.3.
    ```

### Early versions of EE

If the feature was created before GitLab 9.2 (before [different EE tiers were introduced](https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/1851)):

- Declare it as "Introduced in GitLab Enterprise Edition X.Y".
- Note which tier the feature is available in.

For example:

```md
> [Introduced](<link-to-issue>) in GitLab Enterprise Edition 9.0. Available in [GitLab Premium](https://about.gitlab.com/pricing/).
```

## Product badges

When a feature is available in EE-only tiers, add the corresponding tier according to the
feature availability:

- For GitLab Starter and GitLab.com Bronze: `**[STARTER]**`.
- For GitLab Premium and GitLab.com Silver: `**[PREMIUM]**`.
- For GitLab Ultimate and GitLab.com Gold: `**[ULTIMATE]**`.
- For GitLab Core and GitLab.com Free: `**[CORE]**`.

To exclude GitLab.com tiers (when the feature is not available in GitLab.com), add the
keyword "only":

- For GitLab Core: `**[CORE ONLY]**`.
- For GitLab Starter: `**[STARTER ONLY]**`.
- For GitLab Premium: `**[PREMIUM ONLY]**`.
- For GitLab Ultimate: `**[ULTIMATE ONLY]**`.

The tier should be ideally added to headers, so that the full badge will be displayed.
However, it can be also mentioned from paragraphs, list items, and table cells. For these cases,
the tier mention will be represented by an orange question mark that will show the tiers on hover.

For example:

- `**[STARTER]**` renders as **[STARTER]**
- `**[STARTER ONLY]**` renders as **[STARTER ONLY]**

The absence of tiers' mentions mean that the feature is available in GitLab Core,
GitLab.com Free, and all higher tiers.

### How it works

Introduced by [!244](https://gitlab.com/gitlab-com/gitlab-docs/merge_requests/244),
the special markup `**[STARTER]**` will generate a `span` element to trigger the
badges and tooltips (`<span class="badge-trigger starter">`). When the keyword
"only" is added, the corresponding GitLab.com badge will not be displayed.

## Specific sections

Certain styles should be applied to specific sections. Styles for specific sections are outlined below.

### GitLab Restart

There are many cases that a restart/reconfigure of GitLab is required. To
avoid duplication, link to the special document that can be found in
[`doc/administration/restart_gitlab.md`][doc-restart]. Usually the text will
read like:

```md
Save the file and [reconfigure GitLab](../../administration/restart_gitlab.md)
for the changes to take effect.
```

If the document you are editing resides in a place other than the GitLab CE/EE
`doc/` directory, instead of the relative link, use the full path:
`http://docs.gitlab.com/ce/administration/restart_gitlab.html`.
Replace `reconfigure` with `restart` where appropriate.

### Installation guide

**Ruby:**
In [step 2 of the installation guide](../../install/installation.md#2-ruby),
we install Ruby from source. Whenever there is a new version that needs to
be updated, remember to change it throughout the codeblock and also replace
the sha256sum (it can be found in the [downloads page][ruby-dl] of the Ruby
website).

[ruby-dl]: https://www.ruby-lang.org/en/downloads/ "Ruby download website"

### Configuration documentation for source and Omnibus installations

GitLab currently officially supports two installation methods: installations
from source and Omnibus packages installations.

Whenever there is a setting that is configurable for both installation methods,
prefer to document it in the CE docs to avoid duplication.

Configuration settings include:

1. Settings that touch configuration files in `config/`.
1. NGINX settings and settings in `lib/support/` in general.

When there is a list of steps to perform, usually that entails editing the
configuration file and reconfiguring/restarting GitLab. In such case, follow
the style below as a guide:

```md
**For Omnibus installations**

1. Edit `/etc/gitlab/gitlab.rb`:

    ```ruby
    external_url "https://gitlab.example.com"
    ```

1. Save the file and [reconfigure] GitLab for the changes to take effect.

---

**For installations from source**

1. Edit `config/gitlab.yml`:

    ```yaml
    gitlab:
      host: "gitlab.example.com"
    ```

1. Save the file and [restart] GitLab for the changes to take effect.


[reconfigure]: path/to/administration/restart_gitlab.md#omnibus-gitlab-reconfigure
[restart]: path/to/administration/restart_gitlab.md#installations-from-source
```

In this case:

- Before each step list the installation method is declared in bold.
- Three dashes (`---`) are used to create a horizontal line and separate the
  two methods.
- The code blocks are indented one or more spaces under the list item to render
  correctly.
- Different highlighting languages are used for each config in the code block.
- The [GitLab Restart](#gitlab-restart) section is used to explain a required restart/reconfigure of GitLab.

## API

Here is a list of must-have items. Use them in the exact order that appears
on this document. Further explanation is given below.

- Every method must have the REST API request. For example:

    ```
    GET /projects/:id/repository/branches
    ```

- Every method must have a detailed
  [description of the parameters](#method-description).
- Every method must have a cURL example.
- Every method must have a response body (in JSON format).

### API topic template

The following can be used as a template to get started:

````md
## Descriptive title

One or two sentence description of what endpoint does.

```text
METHOD /endpoint
```

| Attribute   | Type     | Required | Description           |
|:------------|:---------|:---------|:----------------------|
| `attribute` | datatype | yes/no   | Detailed description. |
| `attribute` | datatype | yes/no   | Detailed description. |

Example request:

```sh
curl --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/endpoint?parameters'
```

Example response:

```json
[
  {
  }
]
```
````

### Fake tokens

There may be times where a token is needed to demonstrate an API call using
cURL or a variable used in CI. It is strongly advised not to use real
tokens in documentation even if the probability of a token being exploited is
low.

You can use the following fake tokens as examples.

| Token type            | Token value                                                        |
|:----------------------|:-------------------------------------------------------------------|
| Private user token    | `<your_access_token>`                                             |
| Personal access token | `n671WNGecHugsdEDPsyo`                                             |
| Application ID        | `2fcb195768c39e9a94cec2c2e32c59c0aad7a3365c10892e8116b5d83d4096b6` |
| Application secret    | `04f294d1eaca42b8692017b426d53bbc8fe75f827734f0260710b83a556082df` |
| CI/CD variable        | `Li8j-mLUVA3eZYjPfd_H`                                             |
| Specific Runner token | `yrnZW46BrtBFqM7xDzE7dddd`                                         |
| Shared Runner token   | `6Vk7ZsosqQyfreAxXTZr`                                             |
| Trigger token         | `be20d8dcc028677c931e04f3871a9b`                                   |
| Webhook secret token  | `6XhDroRcYPM5by_h-HLY`                                             |
| Health check token    | `Tu7BgjR9qeZTEyRzGG2P`                                             |
| Request profile token | `7VgpS4Ax5utVD2esNstz`                                             |

### Method description

Use the following table headers to describe the methods. Attributes should
always be in code blocks using backticks (``` ` ```).

```md
| Attribute | Type | Required | Description |
|:----------|:-----|:---------|:------------|
```

Rendered example:

| Attribute | Type   | Required | Description         |
|:----------|:-------|:---------|:--------------------|
| `user`    | string | yes      | The GitLab username |

### cURL commands

- Use `https://gitlab.example.com/api/v4/` as an endpoint.
- Wherever needed use this personal access token: `<your_access_token>`.
- Always put the request first. `GET` is the default so you don't have to
  include it.
- Use double quotes to the URL when it includes additional parameters.
- Prefer to use examples using the personal access token and don't pass data of
  username and password.

| Methods                                    | Description                                           |
|:-------------------------------------------|:------------------------------------------------------|
| `-H "PRIVATE-TOKEN: <your_access_token>"`  | Use this method as is, whenever authentication needed |
| `-X POST`                                  | Use this method when creating new objects             |
| `-X PUT`                                   | Use this method when updating existing objects        |
| `-X DELETE`                                | Use this method when removing existing objects        |

### cURL Examples

Below is a set of [cURL][] examples that you can use in the API documentation.

#### Simple cURL command

Get the details of a group:

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/groups/gitlab-org
```

#### cURL example with parameters passed in the URL

Create a new project under the authenticated user's namespace:

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects?name=foo"
```

#### Post data using cURL's --data

Instead of using `-X POST` and appending the parameters to the URI, you can use
cURL's `--data` option. The example below will create a new project `foo` under
the authenticated user's namespace.

```bash
curl --data "name=foo" --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects"
```

#### Post data using JSON content

> **Note:** In this example we create a new group. Watch carefully the single
and double quotes.

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --header "Content-Type: application/json" --data '{"path": "my-group", "name": "My group"}' https://gitlab.example.com/api/v4/groups
```

#### Post data using form-data

Instead of using JSON or urlencode you can use multipart/form-data which
properly handles data encoding:

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --form "title=ssh-key" --form "key=ssh-rsa AAAAB3NzaC1yc2EA..." https://gitlab.example.com/api/v4/users/25/keys
```

The above example is run by and administrator and will add an SSH public key
titled ssh-key to user's account which has an id of 25.

#### Escape special characters

Spaces or slashes (`/`) may sometimes result to errors, thus it is recommended
to escape them when possible. In the example below we create a new issue which
contains spaces in its title. Observe how spaces are escaped using the `%20`
ASCII code.

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/42/issues?title=Hello%20Dude"
```

Use `%2F` for slashes (`/`).

#### Pass arrays to API calls

The GitLab API sometimes accepts arrays of strings or integers. For example, to
restrict the sign-up e-mail domains of a GitLab instance to `*.example.com` and
`example.net`, you would do something like this:

```bash
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" --data "domain_whitelist[]=*.example.com" --data "domain_whitelist[]=example.net" https://gitlab.example.com/api/v4/application/settings
```

[cURL]: http://curl.haxx.se/ "cURL website"
[single spaces]: http://www.slate.com/articles/technology/technology/2011/01/space_invaders.html
[gfm]: http://docs.gitlab.com/ce/user/markdown.html#newlines "GitLab flavored markdown documentation"
[ce-1242]: https://gitlab.com/gitlab-org/gitlab-ce/issues/1242
[doc-restart]: ../../administration/restart_gitlab.md "GitLab restart documentation"
