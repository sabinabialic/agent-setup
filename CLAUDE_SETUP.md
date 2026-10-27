# Claude Code Setup

This is the Claude Code equivalent of the OpenCode setup. It installs the same
skills, the `/ship` pipeline, and the workflow instructions as user-level
Claude Code configuration, so they are available in every repository.

## 1. Prerequisites

- [Claude Code](https://claude.com/claude-code) (CLI or the Code tab of the
  Claude desktop app)
- [GitHub CLI](https://cli.github.com) (`gh`) authenticated for the repositories
  you work in — the `pr-writer` stage uses it to open draft PRs

## 2. Copy config into place

Everything under `claude/` in this repo mirrors `~/.claude/`. Copy it across:

```sh
mkdir -p ~/.claude
cp -R claude/. ~/.claude/
```

This installs:

- `CLAUDE.md` — global instructions incl. the workflow decision rule
- `agents/` — the `/ship` stage subagents (`planner`, `coder`, `tester`,
  `reviewer`, `pr-writer`)
- `commands/ship.md` — the `/ship` orchestrator
- `skills/` — `pr-review`, `writing-pr-descriptions`, `push-lock`, `stop-slop`,
  `orchestrating-feature-implementation`

New skills, agents, and commands load in sessions started after the copy.

## 3. How `/ship` differs from OpenCode

Claude Code subagents cannot launch other subagents, so there is no `ship`
agent. The orchestrator lives in the `/ship` command and runs in your main
session, dispatching each stage with the Agent tool. Stage models use Claude
Code's aliases, which track the latest model in each family:

| Agent     | Model    | Tools                                  |
|-----------|----------|----------------------------------------|
| planner   | `opus`   | Read, Grep, Glob, Write (no shell)     |
| coder     | `sonnet` | all                                    |
| tester    | `sonnet` | all                                    |
| reviewer  | `opus`   | Read, Grep, Glob, Skill (read-only)    |
| pr-writer | `sonnet` | Read, Grep, Glob, Write, Bash, Skill   |
| (/ship)   | session model | coordination only                 |

## 4. Superpowers (optional)

`CLAUDE.md` refers to `subagent-driven-development` and `executing-plans`,
which come from [superpowers](https://github.com/obra/superpowers). Install it
from the official marketplace at user scope:

```sh
claude plugin install superpowers@claude-plugins-official --scope user
```

## 5. GitHub MCP (optional)

Create the read-only fine-grained PAT described in [SETUP.md](SETUP.md#5-github-mcp-connector--create-and-export-the-pat),
export it as `GITHUB_MCP_PAT`, then register the server at user scope:

```sh
claude mcp add github --scope user \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_MCP_PAT" \
  -- npx -y @modelcontextprotocol/server-github
```

This writes the token value into `~/.claude.json`. Re-run the command after
rotating the PAT.

## 6. Sanity check

1. Start a new Claude Code session in any repository.
2. Run `/agents` and confirm the five pipeline agents appear under user agents.
3. Type `/ship` and confirm it autocompletes with the `<feature request>` hint.
4. Ask "review this branch" and confirm the `pr-review` skill loads.
5. Run `/ship "<small contained change>"` to confirm the pipeline flows.

Pipeline files are intentionally excluded from commits by `pr-writer`. Add
`.pipeline/` to a repository's `.gitignore` if it is not already ignored.
