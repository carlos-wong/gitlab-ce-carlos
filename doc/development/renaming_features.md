# Renaming features

Sometimes the business asks to change the name of a feature. Broadly speaking, there are 2 approaches to that task. They basically trade between immediate effort and future complexity/bug risk:

- Complete, rename everything in the repo.
  - Pros: does not increase code complexity.
  - Cons: more work to execute, and higher risk of immediate bugs.
- Façade, rename as little as possible; only the user-facing content like interfaces,
  documentation, error messages, etc.
  - Pros: less work to execute.
  - Cons: increases code complexity, creating higher risk of future bugs.

## When to choose the façade approach

The more of the following that are true, the more likely you should choose the façade approach:

- You are not confident the new name is permanent.
- The feature is susceptible to bugs (large, complex, needing refactor, etc).
- The renaming will be difficult to review (feature spans many lines/files/repos).
- The renaming will be disruptive in some way (database table renaming).

## Consider a façade-first approach

The façade approach is not necessarily a final step. It can (and possibly *should*) be treated as the first step, where later iterations will accomplish the complete rename.
