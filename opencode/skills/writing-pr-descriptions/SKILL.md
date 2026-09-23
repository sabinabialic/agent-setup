---
name: writing-pr-descriptions
description: Use when preparing or updating pull request descriptions so maintainers get clear context, review guidance, testing steps, and stacked-PR ordering.
---

# Writing PR Descriptions

## Overview
PR descriptions should optimize for maintainer review speed, clarity, and confidence.
Write concise technical context, explicit review order, and concrete testing steps.

## When to Use
- Opening a new PR
- Rewriting a weak PR description
- Updating PR text after scope changes
- Shipping stacked PRs that must be reviewed in sequence

## Template Source Selection
- First, check for a repository template at `.github/pull_request_template.md`.
- If it exists, use it as the authoritative structure and preserve required sections (for example compliance/security checklists).
- If it does not exist, use this skill's fallback template section order:
  1. `## What & How 🛠️`
  2. `## Why 🤷`
  3. `## Review Guide 📖`
  4. `## Testing 🧪`
  5. `## Anything Else? 💭`

## Required Structure
Keep each section short and specific. Avoid generic statements.

## Section Guidance

### `What & How 🛠️`
- List the concrete changes.
- Explain implementation approach and boundaries touched.
- Mention alternatives only if they impacted decisions.
- Do not narrate AI workflow or planning mechanics.

### `Why 🤷`
- State the problem this PR solves now.
- Connect to reliability, correctness, maintainability, or feature goals.

### `Review Guide 📖`
- Provide a fast review path through files/components.
- Start with highest-signal files.
- Call out complicated or risky areas explicitly.
- If docs are included, clarify which are design-critical vs execution notes.

### `Testing 🧪`
- Use a checklist with runnable commands.
- Include setup steps before commands when needed.
- If known unrelated failures exist, state them clearly and scope them out.

### `Anything Else? 💭`
- List deferred work and why it is deferred.
- Link tracking artifacts (beads/Jira/follow-up PRs).

## Stacked PR Template
When PRs are stacked, always enumerate in merge order and highlight current PR:

```md
### Stacked PRs
In merge order:
1. #<base-pr>
2. 👉 #<this-pr> 👈
3. #<follow-up-pr>
```

If only two PRs are stacked, still enumerate both.

## Quality Bar
- Descriptions should be understandable without opening local notes.
- Maintainer should know where to start review in under 30 seconds.
- Testing section should be directly executable.
- No fluff, no internal process narration, no ambiguous scope.

## Common Mistakes
- Vague summaries that omit key approach requirements or non-obvious constraints.
- Missing review order for large diffs
- Testing sections without actual commands
- Not enumerating stacked PR dependencies
- Treating planning docs as more important than design/spec docs for reviewer alignment, specs and requirements matter more.
- Referencing JIRAs as inline-code, instead of simply STRIDE-1337
