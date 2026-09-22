# agent-setup

A collection of tools and skills that I use in my development process.

## Skills

opencode skills under `opencode/<name>/SKILL.md`, loaded automatically when a
task matches their trigger. See [opencode/skills.md](opencode/skills.md) for details on
each:

- **pr-review** — staff-level, evidence-based review of a branch/PR diff
- **writing-pr-descriptions** — PR descriptions optimized for review speed
- **push-lock** — git-native lock to serialize concurrent agent pushes
- **feature-implementation** — conductor + worklog orchestration for delegated feature work

## Superpowers

[superpowers](https://github.com/obra/superpowers/tree/main)

## Stop Slop

[stop-slop](https://github.com/hardikpandya/stop-slop/tree/main)

## Ship pipeline

A four-stage build pipeline under `opencode/agent` and `opencode/command`, chained by the `/ship` command. Each stage hands off to the next through a shared `.pipeline/` folder.

- **planner** (opus) — turns a feature request into a detailed spec: exact file paths, function signatures, and edge cases → `.pipeline/spec.md`
- **coder** (sonnet) — implements exactly what the spec says → `.pipeline/changes.md`
- **tester** (sonnet) — writes and runs tests for the spec's edge cases and happy path, no redundant tests → `.pipeline/tests.md`
- **reviewer** (sonnet, read-only) — reads spec, changes, and diff and returns a PASS/FAIL verdict → `.pipeline/review.md`
- **ship** — orchestrator that chains the stages and auto-loops once on a FAIL verdict

Install by copying `opencode/agent` and `opencode/command` into `~/.config/opencode`, then run `/ship <feature request>`.
