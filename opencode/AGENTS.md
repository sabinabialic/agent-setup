# Global Instructions

## Choosing a workflow

- `/ship "<request>"`: a bounded, well-understood change you could fully spec
  up front and run unattended, in a flow that already exists.
- `orchestrating-feature-implementation` skill: large or ambiguous work that
  needs discovery, your judgment at phase gates, or interface changes.
- `subagent-driven-development` / `executing-plans`: only to execute a plan
  that is already written.
- When unsure between `/ship` and the skill, use the skill. Its "Choosing This
  Workflow" section has the full decision rule.

## Review standards

Review standards live in the `pr-review` skill. The `/ship` reviewer applies
all of its lenses on top of the ship checks.

## Keep PR descriptions in sync with pushes

Before any push, check for an open PR on the branch (`gh pr view`). If one
exists, after the push lands, re-read the diff and rewrite the description in
the same action (`gh pr edit <number> --body "..."`), following the
`writing-pr-descriptions` skill. This applies to every push in every workflow,
including pushes after `/ship`'s pr-writer has run.
