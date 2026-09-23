# Global Instructions

## Choosing an orchestration workflow

Two feature-building workflows exist. They are NOT interchangeable — pick by the
nature of the work, not by habit.

### Use `/ship` (deterministic autonomous pipeline)

Command: `/ship "<feature request>"` → planner → coder → tester → reviewer,
chained through `.pipeline/*.md` with a one-retry review loop.

Reach for `/ship` when ALL of these hold:
- The change is **bounded and well understood** — you could write the spec
  upfront without discovery.
- You want it **run autonomously**, walk-away, no back-and-forth.
- It touches a flow that already exists in the repo (a flag, an endpoint, a
  contained fix).

This is the **autonomy lane** — the same pipeline used for scheduled/CI runs.

### Use the `orchestrating-feature-implementation` skill (adaptive, conducted)

Reach for the superpowers orchestration skill when ANY of these hold:
- The feature is **large or ambiguous** and needs a discovery phase.
- Requirements may shift as you learn — you want blocking-question discipline
  and an evolving worklog.
- You want to **stay in the loop** and exercise judgment at phase gates.
- New subsystems, cross-cutting changes, or anything restructuring interfaces.

This is the **high-stakes feature lane** — you conduct, subagents execute.

### Downstream, not a competitor

`subagent-driven-development` / `executing-plans` run an already-written plan.
They come AFTER brainstorming → writing-plans, not instead of the two lanes
above.

### Quick decision

| Question | If yes |
|----------|--------|
| Can I fully spec this upfront and walk away? | `/ship` |
| Does this need discovery or my judgment mid-flight? | orchestration skill |
| Do I already have a written plan to execute? | subagent-driven-development |

When in doubt between `/ship` and the orchestration skill, take the heavier one
(the orchestration skill).

## Single source of truth for standards

Review standards live in the `pr-review` skill. The `/ship` reviewer agent
applies its full set of lenses (correctness, concurrency, scalability,
security/privacy, operational risk, maintainability) on top of spec
conformance; defer to `pr-review` rather than duplicating review criteria
elsewhere.

## Keep PR descriptions in sync with pushes

Whenever you push new commits to an **open** PR branch — a fixup, a review
response, a scope change, anything — update that PR's description in the
same action, before moving on. A description that describes yesterday's diff
is worse than no description.

- Check `git status`/`gh pr view` for an open PR on the current branch before
  pushing. If one exists, re-read the diff and revise the description with
  `gh pr edit <number> --body "..."` after the push lands.
- Use the `writing-pr-descriptions` skill for the structure and section
  guidance — the same template applies to updates, not just first drafts.
- This applies in both lanes: `/ship`'s `pr-writer` agent only runs once per
  pipeline invocation, so any push you make manually after that (or via a
  second `/ship` pass) still needs this sync step; the orchestration-skill
  lane always needs it since there is no dedicated PR-writer stage.
