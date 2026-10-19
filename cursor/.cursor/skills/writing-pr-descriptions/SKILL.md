---
name: writing-pr-descriptions
description: Use when opening or updating a pull request description.
---

# Writing PR Descriptions

First use `.github/pull_request_template.md` when it exists. Otherwise use:
`What & How`, `Why`, `Review Guide`, `Testing`, and `Anything Else?`.

Keep every section concise and specific. Explain the concrete implementation
and why it matters. Give reviewers a highest-signal-first reading order. List
actual runnable test commands and relevant setup. State deferred work clearly;
do not narrate planning or AI workflow.

After every push to an open PR, rebuild the description from the current diff
and update it with `gh pr edit <number> --body "<body>"`. Do not append a
changelog note to stale text. For stacked PRs, enumerate them in merge order and
highlight the current PR.
