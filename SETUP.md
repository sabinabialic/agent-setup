# Setup — replicating this environment on a new machine

Reproduces my full opencode setup: model routing, skills, the `/ship`
pipeline, workflow instructions, and the GitHub MCP connector.

## 1. Prerequisites

Install these first:

- [opencode](https://opencode.ai) — the agent runtime
- [GitHub CLI](https://cli.github.com) (`gh`) — auth + git operations
- [Docker](https://www.docker.com) — optional, only for the GitHub MCP
  Docker-local fallback (see step 6)

## 2. Copy config into place

Everything under `opencode/` in this repo mirrors `~/.config/opencode/`.
Copy it across:

```sh
mkdir -p ~/.config/opencode
cp -R opencode/. ~/.config/opencode/
```

This installs:

- `opencode.jsonc` — model defaults, plugins, and the GitHub MCP server
- `AGENTS.md` — global instructions incl. the workflow decision rule
- `agent/` + `command/` — the `/ship` pipeline
- the skill folders (`pr-review`, `feature-implementation`, etc.)

## 3. Install plugin dependencies

`opencode.jsonc` declares three plugins that opencode fetches on startup:

- `@hashicorp/opencode-bob-gateway-plugin` — IBM/HashiCorp model gateway
- `superpowers` (from GitHub) — skills framework
- `opencode-firecrawl` — web fetch/crawl

No manual install needed; opencode resolves them on first launch. Ensure
network access to npm and GitHub.

## 4. Authenticate model providers

```sh
opencode auth login
```

Authenticate **github-copilot** (this is how Claude + GPT models are
reached). The `ibm-bob` gateway comes from the HashiCorp plugin and uses
company SSO/credentials.

Confirm available models:

```sh
opencode models | grep -E 'github-copilot|ibm-bob'
```

## 5. GitHub MCP connector — create and export the PAT

The `github` MCP server authenticates with a fine-grained PAT read from
the `GITHUB_MCP_PAT` environment variable (never hard-coded).

1. github.com → Settings → Developer settings → **Fine-grained personal
   access tokens** → Generate new token.
2. Grant **read** access to the repos/orgs you need: Contents, Issues,
   Pull requests, Actions.
3. If your org enforces SSO, authorize the token for that org.
4. Export it persistently:

   ```sh
   echo 'export GITHUB_MCP_PAT="github_pat_..."' >> ~/.zshrc
   source ~/.zshrc
   ```

5. Verify the token and that the hosted server is reachable (expect
   `200`):

   ```sh
   curl -sS -o /dev/null -w "%{http_code}\n" \
     -H "Authorization: Bearer $GITHUB_MCP_PAT" \
     -H "X-MCP-Readonly: true" \
     -X POST https://api.githubcopilot.com/mcp/ \
     -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   ```

   - `200` → good.
   - `401/403` → token needs SSO authorization, or the org disabled the
     hosted server → use the Docker-local fallback (step 6).

The connector is **read-only** by default (`X-MCP-Readonly: true`). To
allow writes (comments, PRs, merges), remove that header and grant the
PAT the matching write scopes.

## 6. GitHub MCP — Docker-local fallback (only if hosted is blocked)

If step 5 returns `401/403` because the hosted server is disabled, swap
the `github` block in `opencode.jsonc` for a local server:

```jsonc
"github": {
  "type": "local",
  "command": ["docker", "run", "-i", "--rm",
    "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
    "ghcr.io/github/github-mcp-server"],
  "enabled": true,
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_MCP_PAT}" }
}
```

## 7. Launch

Start opencode from a shell where `GITHUB_MCP_PAT` is exported (env vars
are read at launch). MCP tools load at startup and are available to
**new** sessions — an already-open session won't pick up a
newly-added connector.

Sanity checks:

- Log line `service=mcp key=github type=remote found` (no auth errors).
- In a fresh chat: "search my repos for X" should call a `github_*`
  tool instead of shelling out to `gh`.
- Run `/ship "<small change>"` to confirm the pipeline flows.

## Model routing reference

| Agent    | Model                              | Why                          |
|----------|------------------------------------|------------------------------|
| planner  | `github-copilot/claude-opus-4.8`   | Deep reasoning               |
| reviewer | `github-copilot/claude-opus-4.8-fast` | Judgment, lower latency   |
| coder    | `github-copilot/claude-sonnet-5` | Mechanical implementation    |
| tester   | `github-copilot/claude-sonnet-5` | Structured, bounded          |
| ship     | `github-copilot/claude-haiku-4.5`  | Pure coordination            |
| (default)| `github-copilot/claude-sonnet-5` | Interactive default          |
| (small)  | `github-copilot/claude-haiku-4.5`  | Titles, summaries, compaction |
