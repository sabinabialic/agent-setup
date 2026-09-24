# agent-setup

A collection of tools and skills that I use in my development process.

To replicate this whole setup on a new machine, follow [SETUP.md](SETUP.md).

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

A five-stage build pipeline under `opencode/agent` and `opencode/command`, chained by the `/ship` command. Each stage hands off to the next through a shared `.pipeline/` folder. Artifacts are organized in per-feature subfolders: `.pipeline/<YYYY-MM-DD>-<feature-slug>/` (e.g. `.pipeline/2026-09-24-add-dark-mode/`). Multiple runs in a day remain separate; same-day reruns overwrite only their own subfolder.

- **planner** (opus) — turns a feature request into a detailed spec: exact file paths, function signatures, and edge cases → `.pipeline/<YYYY-MM-DD>-<slug>/spec.md`
- **coder** (sonnet) — implements exactly what the spec says → `.pipeline/<YYYY-MM-DD>-<slug>/changes.md`
- **tester** (sonnet) — writes and runs tests for the spec's edge cases and happy path, no redundant tests → `.pipeline/<YYYY-MM-DD>-<slug>/tests.md`
- **reviewer** (opus-fast, read-only) — reads spec, changes, and diff and returns a PASS/FAIL verdict → `.pipeline/<YYYY-MM-DD>-<slug>/review.md`
- **pr-writer** (haiku) — creates branch, commits changes, pushes to origin, and opens a draft PR → `.pipeline/<YYYY-MM-DD>-<slug>/pr.md`
- **ship** (haiku) — orchestrator that chains the stages and auto-loops once on a FAIL verdict

Install by copying `opencode/agent` and `opencode/command` into `~/.config/opencode`, then run `/ship <feature request>`.

## Choosing a workflow

`/ship` and `feature-implementation` are not interchangeable. The decision rule
for which to use — plus how `subagent-driven-development` fits downstream — lives
in [opencode/AGENTS.md](opencode/AGENTS.md), which opencode auto-loads as global
instructions when copied to `~/.config/opencode/AGENTS.md`.
