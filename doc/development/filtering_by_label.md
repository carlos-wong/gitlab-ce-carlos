# Filtering by label

## Introduction

GitLab has [labels](../user/project/labels.md) that can be assigned to issues,
merge requests, and epics. Labels on those objects are a many-to-many relation
through the polymorphic `label_links` table.

To filter these objects by multiple labels - for instance, 'all open
issues with the label ~Plan and the label ~backend' - we generate a
query containing a `GROUP BY` clause. In a simple form, this looks like:

```sql
SELECT
    issues.*
FROM
    issues
    INNER JOIN label_links ON label_links.target_id = issues.id
        AND label_links.target_type = 'Issue'
    INNER JOIN labels ON labels.id = label_links.label_id
WHERE
    issues.project_id = 13083
    AND (issues.state IN ('opened'))
    AND labels.title IN ('Plan',
        'backend')
GROUP BY
    issues.id
HAVING (COUNT(DISTINCT labels.title) = 2)
ORDER BY
    issues.updated_at DESC,
    issues.id DESC
LIMIT 20 OFFSET 0
```

In particular, note that:

1. We `GROUP BY issues.id` so that we can ...
1. Use the `HAVING (COUNT(DISTINCT labels.title) = 2)` condition to ensure that
   all matched issues have both labels.

This is more complicated than is ideal. It makes the query construction more
prone to errors (such as
[issue #15557](https://gitlab.com/gitlab-org/gitlab-foss/issues/15557)).

## Attempt A: WHERE EXISTS

### Attempt A1: use multiple subqueries with WHERE EXISTS

In [issue #37137](https://gitlab.com/gitlab-org/gitlab-foss/issues/37137)
and its associated [merge request](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/14022),
we tried to replace the `GROUP BY` with multiple uses of `WHERE EXISTS`. For the
example above, this would give:

```sql
WHERE (EXISTS (
        SELECT
            TRUE
        FROM
            label_links
            INNER JOIN labels ON labels.id = label_links.label_id
        WHERE
            labels.title = 'Plan'
            AND target_type = 'Issue'
            AND target_id = issues.id))
AND (EXISTS (
        SELECT
            TRUE
        FROM
            label_links
            INNER JOIN labels ON labels.id = label_links.label_id
        WHERE
            labels.title = 'backend'
            AND target_type = 'Issue'
            AND target_id = issues.id))
```

While this worked without schema changes, and did improve readability somewhat,
it did not improve query performance.

## Attempt B: Denormalize using an array column

Having [removed MySQL support in GitLab 12.1](https://about.gitlab.com/blog/2019/06/27/removing-mysql-support/),
using [Postgres's arrays](https://www.postgresql.org/docs/9.6/arrays.html) became more
tractable as we didn't have to support two databases. We discussed denormalizing
the `label_links` table for querying in
[issue #49651](https://gitlab.com/gitlab-org/gitlab-foss/issues/49651),
with two options: label IDs and titles.

We can think of both of those as array columns on `issues`, `merge_requests`,
and `epics`: `issues.label_ids` would be an array column of label IDs, and
`issues.label_titles` would be an array of label titles.

These array columns can be complemented with [GIN
indexes](https://www.postgresql.org/docs/9.6/gin-intro.html) to improve
matching.

### Attempt B1: store label IDs for each object

This has some strong advantages over titles:

1. Unless a label is deleted, or a project is moved, we never need to
   bulk-update the denormalized column.
1. It uses less storage than the titles.

Unfortunately, our application design makes this hard. If we were able to query
just by label ID easily, we wouldn't need the `INNER JOIN labels` in the initial
query at the start of this document. GitLab allows users to filter by label
title across projects and even across groups, so a filter by the label ~Plan may
include labels with multiple distinct IDs.

We do not want users to have to know about the different IDs, which means that
given this data set:

| Project | ~Plan label ID | ~backend label ID |
| ------- | -------------- | ----------------- |
| A       | 11             | 12                |
| B       | 21             | 22                |
| C       | 31             | 32                |

We would need something like:

```sql
WHERE
    label_ids @> ARRAY[11, 12]
    OR label_ids @> ARRAY[21, 22]
    OR label_ids @> ARRAY[31, 32]
```

This can get even more complicated when we consider that in some cases, there
might be two ~backend labels - with different IDs - that could apply to the same
object, so the number of combinations would balloon further.

### Attempt B2: store label titles for each object

From the perspective of updating the labelable object, this is the worst
option. We have to bulk update the objects when:

1. The objects are moved from one project to another.
1. The project is moved from one group to another.
1. The label is renamed.
1. The label is deleted.

It also uses much more storage. Querying is simple, though:

```sql
WHERE
    label_titles @> ARRAY['Plan', 'backend']
```

And our [tests in issue #49651](https://gitlab.com/gitlab-org/gitlab-foss/issues/49651#note_188777346)
showed that this could be fast.

However, at present, the disadvantages outweigh the advantages.

## Conclusion

We have yet to find a method that is demonstratably better than the current
method, when considering:

1. Query performance.
1. Readability.
1. Ease of maintaining schema consistency.
