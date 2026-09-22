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
enforces spec conformance for its pipeline; for anything deeper than that,
defer to `pr-review` rather than duplicating review criteria elsewhere.
