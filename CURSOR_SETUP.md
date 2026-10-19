# Cursor Setup

This is the Cursor equivalent of the OpenCode setup. It preserves the workflow
standards, review discipline, GitHub MCP connection, and `/ship` artifacts
without GitHub Copilot.

## 1. Prerequisites

- [Cursor](https://cursor.com/downloads)
- [GitHub CLI](https://cli.github.com) (`gh`) authenticated for the repositories
  you work in
- Node.js, used by the local GitHub MCP server

## 2. Install the project template

Copy the template into the root of each repository where you want these rules
and commands available:

```sh
cp -R cursor/.cursor /path/to/repository/
```

The copied `.cursor/` directory contains project rules, skills, the `/ship`
command, and an environment-backed GitHub MCP definition. Commit it when the
setup should be shared with a repository team.

## 3. Configure models without Copilot

In Cursor Settings, enable the Claude and OpenAI models your Cursor plan or
organization makes available. Use a strong Claude or GPT model for planning and
review, and a capable coding model for implementation and testing. Select the
model per chat or agent run; Cursor does not assign a repository model per
pipeline stage.

Claude Enterprise and ChatGPT Enterprise web subscriptions are not generally
interchangeable with API credentials or Cursor model access. Ask the respective
enterprise administrators to provision Cursor access, approved provider API
credentials, or an approved gateway if the desired models do not appear in
Cursor. Do not configure GitHub Copilot for this setup.

| Work | Model class |
|------|-------------|
| Planning and final review | strongest available Claude or GPT reasoning model |
| Implementation and tests | capable Claude Sonnet or GPT Codex model |
| Small summaries and coordination | fastest approved Claude or GPT model |

## 4. Configure GitHub MCP

Create a fine-grained GitHub PAT with read access to the repositories you need,
including Contents, Issues, Pull requests, and Actions. If the organization
requires SSO, authorize the token for that organization.

Export it before launching Cursor:

```sh
export GITHUB_MCP_PAT="github_pat_..."
```

For persistence on macOS with zsh, add that export to `~/.zshrc`. Restart
Cursor after changing the environment so its MCP process receives the value.

`cursor/.cursor/mcp.json` starts the GitHub MCP server locally over stdio and
passes the token only as `GITHUB_PERSONAL_ACCESS_TOKEN`. Verify the server in
Cursor Settings > Tools & MCP, then start a fresh agent chat and ask it to
search a repository.

## 5. Use the workflows

Use `/ship <feature request>` for a bounded change that can be fully specified
up front and run autonomously. It creates `.pipeline/<YYYY-MM-DD>-<slug>/`
artifacts, plans, implements, tests, reviews, retries once on a failed review,
and only opens a draft PR after a passing verdict.

For a large or ambiguous feature, use Cursor Plan Mode first. Follow the
`workflow` rule: keep a worklog in `docs/worklogs/<feature-slug>.md`, resolve
blocking ambiguity before affected implementation, and review every iteration.

The Cursor agent performs the pipeline stages in a single run. If your Cursor
plan provides background agents, use read-only background agents for discovery
or an independent review only; never assign overlapping edits.

## 6. Sanity check

1. Open a project containing the copied `.cursor/` directory in Cursor.
2. Confirm the rules and skills appear in Cursor's project configuration.
3. Confirm the GitHub MCP server is connected.
4. Run `/ship "<small contained change>"` using an approved implementation
   model.

Pipeline files are intentionally excluded from commits by the command. Add
`.pipeline/` to a repository's `.gitignore` if it is not already ignored.
