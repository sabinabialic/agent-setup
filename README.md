# agent-setup

A collection of tools and skills that I use in my development process.

To replicate the OpenCode setup on a new machine, follow [SETUP.md](SETUP.md).
For the equivalent Cursor setup without GitHub Copilot, follow
[CURSOR_SETUP.md](CURSOR_SETUP.md). For Claude Code, follow
[CLAUDE_SETUP.md](CLAUDE_SETUP.md).

## Skills

opencode skills under `opencode/skills/<name>/SKILL.md`, loaded automatically when a
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

`/ship <feature request>` takes a bounded change from request to draft PR. Agents do the judgment work. A small script, `ship-gate.sh`, handles git isolation, scope checks, check runs, and publication, so those steps don't depend on prompt wording.

The sequence is: isolate → short plan → code and tests → independent verification → review → scripted publication.

| Stage | Who (model) | Produces in `RUN` |
|---|---|---|
| Isolate | `ship-gate.sh init` | a `ship/<slug>` branch and a clean worktree (`WT`) from the PR base, plus `run.env` and `request.md` |
| Plan | **planner** (opus) | `spec.md` (acceptance criteria, existing code to extend, minimal approach, allowed files, non-goals, validation, size estimate), `allowed-files.txt`, `checks.txt` |
| Code | **coder** (sonnet) | the change and its focused regression tests in `WT`, plus `changes.md` |
| Verify | **tester** (sonnet) | evidence for each acceptance criterion, tests that were missing, and `tests.md`; `ship-gate.sh verify` writes `checks.tsv` |
| Review | **reviewer** (opus, read-only) | a verdict on the exact `candidate.patch`, which the orchestrator writes to `review.md` |
| Publish | **pr-writer** (sonnet), then `ship-gate.sh publish` | `pr-title.txt`, `commit-msg.txt`, and `pr-body.md`; the script then commits, pushes, opens the draft PR, and writes `pr.md` |
| Orchestrate | **ship** (haiku) in OpenCode; the `/ship` command in Claude Code | — |

`RUN` is `.pipeline/<YYYY-MM-DD>-<slug>/`, and the worktree lives at `RUN/worktree`. A same-day rerun of the same request replaces only its own run folder. Add `.pipeline/` to each repository's `.gitignore`.

What the script enforces:

- **Isolation.** `init` stops if the checkout has uncommitted changes. It fetches the base (the default branch, or `--base <branch>` when the work builds on an existing branch), records its commit, and creates the branch and worktree there. Nothing is stashed automatically.
- **Scope.** After every editing stage, `scope` lists every changed path, including new untracked files, and checks it against `allowed-files.txt`. More than 5 code files or 400 changed code lines prints a warning. Only code counts toward these limits: tests, docs (`*.md`, `docs/`, and similar), and config or data files (JSON, YAML, TOML, lockfiles, and similar) are reported separately. The coder must explain the size and the reviewer judges it; the warning never fails the run.
- **Checks tied to the candidate.** `verify` runs `checks.txt` in the worktree and records each exit status against the candidate patch's SHA-256. Skipped checks must have a reason. A check that creates files fails verification.
- **Publication.** `gate` and `publish` require: every path in scope, required checks passed on this exact candidate, and a recorded `VERDICT: PASS` for this exact candidate. `publish` stages the explicit file list instead of using `git add -A`, and confirms that both the staged patch and the commit hash to the reviewed candidate before it pushes.

A FAIL verdict gets one repair round. Each blocking issue is tagged with its owner, and only that owner is re-dispatched: production defects go to the coder, defective tests to the tester, and scope problems to the planner.

Each run writes `metrics.json` (code, test, and docs/config lines and files, unexpected files, retries, size warnings, runtime, outcome) and appends a row to `.pipeline/runs.tsv` so runs can be compared.

Thresholds and file classification can be tuned with environment variables: `SHIP_WARN_CODE_FILES`, `SHIP_WARN_CODE_LINES`, `SHIP_TEST_REGEX`, `SHIP_DOC_REGEX`, `SHIP_CONFIG_REGEX`, and `SHIP_DIRTY_EXCLUDE`. A file that matches the test pattern counts as a test even if it is JSON or Markdown. The defaults are at the top of the script.

Install for OpenCode by copying `opencode/` into `~/.config/opencode` (see [SETUP.md](SETUP.md)). For Claude Code, the stages live in `claude/agents` and the orchestrator in `claude/commands/ship.md`, because Claude Code subagents cannot dispatch other subagents; copy `claude/` into `~/.claude` (see [CLAUDE_SETUP.md](CLAUDE_SETUP.md)). The Cursor command runs every stage in one agent and uses `.cursor/scripts/ship-gate.sh` (see [CURSOR_SETUP.md](CURSOR_SETUP.md)).

The gate script has three identical copies: `opencode/scripts/`, `claude/scripts/`, and `cursor/.cursor/scripts/`. The shared agent text is also duplicated between `opencode/agent/` and `claude/agents/`. Edit the OpenCode copy, sync the others, and run:

```sh
bash tests/ship-gate.test.sh
```

The test fails if the copies drift, and it exercises the gates in a throwaway repository.

## Choosing a workflow

`/ship` and `feature-implementation` are not interchangeable. The decision rule
for which to use — plus how `subagent-driven-development` fits downstream — lives
in [opencode/AGENTS.md](opencode/AGENTS.md), which opencode auto-loads as global
instructions when copied to `~/.config/opencode/AGENTS.md`.
