# Workflow labels

To allow for asynchronous issue handling, we use [milestones][milestones-page]
and [labels][labels-page]. Leads and product managers handle most of the
scheduling into milestones. Labelling is a task for everyone.

Most issues will have labels for at least one of the following:

- Type: ~feature, ~bug, ~customer, etc.
- Subject: ~wiki, ~"container registry", ~ldap, ~api, ~frontend, etc.
- Team: ~Plan, ~Manage, ~Quality, etc.
- Stage: ~"devops:plan", ~"devops:create", etc.
- Release Scoping: ~Deliverable, ~Stretch, ~"Next Patch Release"
- Priority: ~P1, ~P2, ~P3, ~P4
- Severity: ~S1, ~S2, ~S3, ~S4

All labels, their meaning and priority are defined on the
[labels page][labels-page].

If you come across an issue that has none of these, and you're allowed to set
labels, you can _always_ add the team and type, and often also the subject.

[milestones-page]: https://gitlab.com/groups/gitlab-org/-/milestones

## Type labels

Type labels are very important. They define what kind of issue this is. Every
issue should have one or more.

Examples of type labels are ~feature, ~bug, ~customer, ~security,
and ~direction.

A number of type labels have a priority assigned to them, which automatically
makes them float to the top, depending on their importance.

Type labels are always lowercase, and can have any color, besides blue (which is
already reserved for subject labels).

The descriptions on the [labels page][labels-page] explain what falls under each type label.

## Subject labels

Subject labels are labels that define what area or feature of GitLab this issue
hits. They are not always necessary, but very convenient.

Examples of subject labels are ~wiki, ~ldap, ~api,
~issues, ~"merge requests", ~labels, and ~"container registry".

If you are an expert in a particular area, it makes it easier to find issues to
work on. You can also subscribe to those labels to receive an email each time an
issue is labeled with a subject label corresponding to your expertise.

Subject labels are always all-lowercase.

## Team labels

Team labels specify what team is responsible for this issue.
Assigning a team label makes sure issues get the attention of the appropriate
people.

The current team labels are:

- ~Configure
- ~Create
- ~Distribution
- ~Documentation
- ~Geo
- ~Gitaly
- ~Manage
- ~Monitor
- ~Plan
- ~Quality
- ~Release
- ~Secure
- ~UX
- ~Verify

The descriptions on the [labels page][labels-page] explain what falls under the
responsibility of each team.

Within those team labels, we also have the ~backend and ~frontend labels to
indicate if an issue needs backend work, frontend work, or both.

Team labels are always capitalized so that they show up as the first label for
any issue.

## Stage labels

Stage labels specify which [DevOps stage][devops-stages] the issue belongs to.

The current stage labels are:

- ~"devops:manage"
- ~"devops:plan"
- ~"devops:create"
- ~"devops:verify"
- ~"devops:package"
- ~"devops:release"
- ~"devops:configure"
- ~"devops:monitor"
- ~"devops:secure"

These labels should be mutually exclusive. If an issue belongs to multiple
stages, the most relevant should be used.

They differ from the [Team labels](#team-labels) because teams may work on
issues outside their stage.

Normally there is a 1:1 relationship between Stage labels and Team labels, but
any issue can be picked up by any team, depending on current priorities.
So, an issue labeled ~"devops:create" may be scheduled by the ~Plan team, for
example. In such cases, it's usual to include both team labels so each team can
be aware of the progress.

The Stage labels are used to generate the [direction pages][direction-pages] automatically.

[devops-stages]: https://about.gitlab.com/direction/#devops-stages
[direction-pages]: https://about.gitlab.com/direction/

## Release Scoping labels

Release Scoping labels help us clearly communicate expectations of the work for the
release. There are three levels of Release Scoping labels:

- ~Deliverable: Issues that are expected to be delivered in the current
  milestone.
- ~Stretch: Issues that are a stretch goal for delivering in the current
  milestone. If these issues are not done in the current release, they will
  strongly be considered for the next release.
- ~"Next Patch Release": Issues to put in the next patch release. Work on these
  first, and add the "Pick Into X" label to the merge request, along with the
  appropriate milestone.

Each issue scheduled for the current milestone should be labeled ~Deliverable
or ~"Stretch". Any open issue for a previous milestone should be labeled
~"Next Patch Release", or otherwise rescheduled to a different milestone.

### Priority labels

Priority labels help us define the time a ~bug fix should be completed. Priority determines how quickly the defect turnaround time must be.
If there are multiple defects, the priority decides which defect has to be fixed immediately versus later.
This label documents the planned timeline & urgency which is used to measure against our actual SLA on delivering ~bug fixes.

| Label | Meaning         | Defect SLA (applies only to ~bug and ~security defects)                                                    |
|-------|-----------------|----------------------------------------------------------------------------|
| ~P1   | Urgent Priority | The current release + potentially immediate hotfix to GitLab.com (30 days) |
| ~P2   | High Priority   | The next release (60 days)                                                 |
| ~P3   | Medium Priority | Within the next 3 releases (approx one quarter or 90 days)                 |
| ~P4   | Low Priority    | Anything outside the next 3 releases (more than one quarter or 120 days)   |

If an issue seems to fall between two priority labels, assign it to the higher-
priority label.

## Severity labels

Severity labels help us clearly communicate the impact of a ~bug on users.

| Label | Meaning           | Impact on Functionality                               | Example |
|-------|-------------------|-------------------------------------------------------|---------|
| ~S1   | Blocker           | Outage, broken feature with no workaround             | Unable to create an issue. Data corruption/loss. Security breach. |
| ~S2   | Critical Severity | Broken Feature, workaround too complex & unacceptable | Can push commits, but only via the command line. |
| ~S3   | Major Severity    | Broken Feature, workaround acceptable                 | Can create merge requests only from the Merge Requests page, not through the Issue. |
| ~S4   | Low Severity      | Functionality inconvenience or cosmetic issue         | Label colors are incorrect / not being displayed. |

If an issue seems to fall between two severity labels, even taking the
[severity impact guidance](#severity-impact-guidance) into account, assign
it to the higher-severity label.

### Severity impact guidance

Severity levels can be applied further depending on the facet of the impact; e.g. Affected customers, GitLab.com availability, performance and etc. The below is a guideline.

| Severity | Affected Customers/Users                                            | GitLab.com Availability                            |  Performance Degradation     |
|----------|---------------------------------------------------------------------|----------------------------------------------------|------------------------------|
| ~S1      | >50% users affected (possible company extinction level event)       | Significant impact on all of GitLab.com            |                              |
| ~S2      | Many users or multiple paid customers affected (but not apocalyptic)| Significant impact on large portions of GitLab.com | Degradation is guaranteed to occur in the near future |
| ~S3      | A few users or a single paid customer affected                      | Limited impact on important portions of GitLab.com | Degradation is likely to occur in the near future     |
| ~S4      | No paid users/customer affected, or expected to in the near future  | Minor impact on GitLab.com                         | Degradation _may_ occur but it's not likely           |

## Label for community contributors

Issues that are beneficial to our users, 'nice to haves', that we currently do
not have the capacity for or want to give the priority to, are labeled as
~"Accepting merge requests", so the community can make a contribution.

Community contributors can submit merge requests for any issue they want, but
the ~"Accepting merge requests" label has a special meaning. It points to
changes that:

1. We already agreed on,
1. Are well-defined,
1. Are likely to get accepted by a maintainer.

We want to avoid a situation when a contributor picks an
~"Accepting merge requests" issue and then their merge request gets closed,
because we realize that it does not fit our vision, or we want to solve it in a
different way.

We add the ~"Accepting merge requests" label to:

- Low priority ~bug issues (i.e. we do not add it to the bugs that we want to
  solve in the ~"Next Patch Release")
- Small ~feature
- Small ~"technical debt" issues

After adding the ~"Accepting merge requests" label, we try to estimate the
[weight](#issue-weight) of the issue. We use issue weight to let contributors
know how difficult the issue is. Additionally:

- We advertise [`Accepting merge requests` issues with weight < 5][up-for-grabs]
  as suitable for people that have never contributed to GitLab before on the
  [Up For Grabs campaign](http://up-for-grabs.net)
- We encourage people that have never contributed to any open source project to
  look for [`Accepting merge requests` issues with a weight of 1][firt-timers]

If you've decided that you would like to work on an issue, please @-mention
the [appropriate product manager](https://about.gitlab.com/handbook/product/#who-to-talk-to-for-what)
as soon as possible. The product manager will then pull in appropriate GitLab team
members to further discuss scope, design, and technical considerations. This will
ensure that your contribution is aligned with the GitLab product and minimize
any rework and delay in getting it merged into master.

GitLab team members who apply the ~"Accepting merge requests" label to an issue
should update the issue description with a responsible product manager, inviting
any potential community contributor to @-mention per above.

[up-for-grabs]: https://gitlab.com/groups/gitlab-org/-/issues?state=opened&label_name[]=Accepting+merge+requests&assignee_id=0&sort=weight
[firt-timers]: https://gitlab.com/groups/gitlab-org/-/issues?state=opened&label_name[]=Accepting+merge+requests&assignee_id=0&sort=weight&weight=1

## Issue triaging

Our issue triage policies are [described in our handbook]. You are very welcome
to help the GitLab team triage issues. We also organize [issue bash events] once
every quarter.

The most important thing is making sure valid issues receive feedback from the
development team. Therefore the priority is mentioning developers that can help
on those issues. Please select someone with relevant experience from the
[GitLab team][team]. If there is nobody mentioned with that expertise look in
the commit history for the affected files to find someone.

We also use [GitLab Triage] to automate some triaging policies. This is
currently set up as a [scheduled pipeline] running on [quality/triage-ops]
project.

[described in our handbook]: https://about.gitlab.com/handbook/engineering/issue-triage/
[issue bash events]: https://gitlab.com/gitlab-org/gitlab-ce/issues/17815
[GitLab Triage]: https://gitlab.com/gitlab-org/gitlab-triage
[scheduled pipeline]: https://gitlab.com/gitlab-org/quality/triage-ops/pipeline_schedules/10512/edit
[quality/triage-ops]: https://gitlab.com/gitlab-org/quality/triage-ops
[team]: https://about.gitlab.com/team/

## Feature proposals

To create a feature proposal for CE, open an issue on the
[issue tracker of CE][ce-tracker].

For feature proposals for EE, open an issue on the
[issue tracker of EE][ee-tracker].

In order to help track the feature proposals, we have created a
[`feature`][fl] label. For the time being, users that are not members
of the project cannot add labels. You can instead ask one of the [core team]
members to add the label ~feature to the issue or add the following
code snippet right after your description in a new line: `~feature`.

Please keep feature proposals as small and simple as possible, complex ones
might be edited to make them small and simple.

Please submit Feature Proposals using the ['Feature Proposal' issue template](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/.gitlab/issue_templates/Feature%20proposal.md) provided on the issue tracker.

For changes in the interface, it is helpful to include a mockup. Issues that add to, or change, the interface should
be given the ~"UX" label. This will allow the UX team to provide input and guidance. You may
need to ask one of the [core team] members to add the label, if you do not have permissions to do it by yourself.

If you want to create something yourself, consider opening an issue first to
discuss whether it is interesting to include this in GitLab.

[fl]: https://gitlab.com/gitlab-org/gitlab-ce/issues?label_name=feature

## Issue tracker guidelines

**[Search the issue tracker][ce-tracker]** for similar entries before
submitting your own, there's a good chance somebody else had the same issue or
feature proposal. Show your support with an award emoji and/or join the
discussion.

Please submit bugs using the ['Bug' issue template](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/.gitlab/issue_templates/Bug.md) provided on the issue tracker.
The text in the parenthesis is there to help you with what to include. Omit it
when submitting the actual issue. You can copy-paste it and then edit as you
see fit.

## Issue weight

Issue weight allows us to get an idea of the amount of work required to solve
one or multiple issues. This makes it possible to schedule work more accurately.

You are encouraged to set the weight of any issue. Following the guidelines
below will make it easy to manage this, without unnecessary overhead.

1. Set weight for any issue at the earliest possible convenience
1. If you don't agree with a set weight, discuss with other developers until
   consensus is reached about the weight
1. Issue weights are an abstract measurement of complexity of the issue. Do not
   relate issue weight directly to time. This is called [anchoring](https://en.wikipedia.org/wiki/Anchoring)
   and something you want to avoid.
1. Something that has a weight of 1 (or no weight) is really small and simple.
   Something that is 9 is rewriting a large fundamental part of GitLab,
   which might lead to many hard problems to solve. Changing some text in GitLab
   is probably 1, adding a new Git Hook maybe 4 or 5, big features 7-9.
1. If something is very large, it should probably be split up in multiple
   issues or chunks. You can simply not set the weight of a parent issue and set
   weights to children issues.

## Regression issues

Every monthly release has a corresponding issue on the CE issue tracker to keep
track of functionality broken by that release and any fixes that need to be
included in a patch release (see [8.3 Regressions] as an example).

As outlined in the issue description, the intended workflow is to post one note
with a reference to an issue describing the regression, and then to update that
note with a reference to the merge request that fixes it as it becomes available.

If you're a contributor who doesn't have the required permissions to update
other users' notes, please post a new note with a reference to both the issue
and the merge request.

The release manager will [update the notes] in the regression issue as fixes are
addressed.

[8.3 Regressions]: https://gitlab.com/gitlab-org/gitlab-ce/issues/4127
[update the notes]: https://gitlab.com/gitlab-org/release-tools/blob/master/doc/pro-tips.md#update-the-regression-issue

## Technical and UX debt

In order to track things that can be improved in GitLab's codebase,
we use the ~"technical debt" label in [GitLab's issue tracker][ce-tracker].
For user experience improvements, we use the ~"UX debt" label.

These labels should be added to issues that describe things that can be improved,
shortcuts that have been taken, features that need additional attention, and all
other things that have been left behind due to high velocity of development.
For example, code that needs refactoring should use the ~"technical debt" label,
user experience refinements should use the ~"UX debt" label.

Everyone can create an issue, though you may need to ask for adding a specific
label, if you do not have permissions to do it by yourself. Additional labels
can be combined with these labels, to make it easier to schedule
the improvements for a release.

Issues tagged with these labels have the same priority like issues
that describe a new feature to be introduced in GitLab, and should be scheduled
for a release by the appropriate person.

Make sure to mention the merge request that the ~"technical debt" issue or
~"UX debt" issue is associated with in the description of the issue.

## Technical debt in follow-up issues

It's common to discover technical debt during development of a new feature. In
the spirit of "minimum viable change", resolution is often deferred to a
follow-up issue. However, this cannot be used as an excuse to merge poor-quality
code that would otherwise not pass review, or to overlook trivial matters that
don't deserve the be scheduled independently, and would be best resolved in the
original merge request - or not tracked at all!

The overheads of scheduling, and rate of change in the GitLab codebase, mean
that the cost of a trivial technical debt issue can quickly exceed the value of
tracking it. This generally means we should resolve these in the original merge
request - or simply not create a follow-up issue at all.

For example, a typo in a comment that is being copied between files is worth
fixing in the same MR, but not worth creating a follow-up issue for. Renaming a
method that is used in many places to make its intent slightly clearer may be
worth fixing, but it should not happen in the same MR, and is generally not
worth the overhead of having an issue of its own. These issues would invariably
be labelled `~P4 ~S4` if we were to create them.

More severe technical debt can have implications for development velocity. If
it isn't addressed in a timely manner, the codebase becomes needlessly difficult
to change, new features become difficult to add, and regressions abound.

Discoveries of this kind of technical debt should be treated seriously, and
while resolution in a follow-up issue may be appropriate, maintainers should
generally obtain a scheduling commitment from the author of the original MR, or
the engineering or product manager for the relevant area. This may take the form
of appropriate Priority / Severity labels on the issue, or an explicit milestone
and assignee.

The maintainer must always agree before an outstanding discussion is resolved in
this manner, and will be the one to create the issue. The title and description
should be of the same quality as those created
[in the usual manner](#technical-and-ux-debt) - in particular, the issue title
**must not** begin with `Follow-up`! The creating maintainer should also expect
to be involved in some capacity when work begins on the follow-up issue.

## Stewardship

For issues related to the open source stewardship of GitLab,
there is the ~"stewardship" label.

This label is to be used for issues in which the stewardship of GitLab
is a topic of discussion. For instance if GitLab Inc. is planning to add
features from GitLab EE to GitLab CE, related issues would be labelled with
~"stewardship".

A recent example of this was the issue for
[bringing the time tracking API to GitLab CE][time-tracking-issue].

[time-tracking-issue]: https://gitlab.com/gitlab-org/gitlab-ce/issues/25517#note_20019084

---

[Return to Contributing documentation](index.md)

[labels-page]: https://gitlab.com/gitlab-org/gitlab-ce/labels
[ce-tracker]: https://gitlab.com/gitlab-org/gitlab-ce/issues
[ee-tracker]: https://gitlab.com/gitlab-org/gitlab-ee/issues
