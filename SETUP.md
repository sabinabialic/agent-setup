# Setup — replicating this environment on a new machine

Reproduces the full opencode setup: direct Anthropic model routing, skills, the
`/ship` pipeline, workflow instructions, and the GitHub MCP connector. It does
not use GitHub Copilot.

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

`opencode.jsonc` declares two plugins that opencode fetches on startup:

- `superpowers` (from GitHub) — skills framework
- `opencode-firecrawl` — web fetch/crawl

No manual install needed; opencode resolves them on first launch. Ensure
network access to npm and GitHub.

## 4. Authenticate model providers

Start opencode and use `/connect`. Connect **Anthropic** with an
enterprise-approved Anthropic API key or authentication method. The configured
pipeline uses Anthropic models. You may also connect **OpenAI** with an
enterprise-approved OpenAI API key or authentication method for interactive
sessions or a future routing change.

An Anthropic Claude Enterprise or ChatGPT Enterprise chat subscription does not
automatically provide API access. Ask the relevant enterprise administrator for
an approved OpenCode authentication path, API key, or gateway. Do not select or
authenticate GitHub Copilot.

Confirm available models:

```sh
opencode models | grep -E 'anthropic|openai'
```

## 5. GitHub MCP connector — create and export the PAT

The `github` MCP server runs **locally over stdio** via `npx` (no Docker
required) and authenticates with a fine-grained PAT read from the
`GITHUB_MCP_PAT` environment variable (never hard-coded).

> Why local, not the hosted remote server? GitHub's hosted endpoint
> (`https://api.githubcopilot.com/mcp/`) now speaks Streamable HTTP only,
> but opencode's `remote` MCP client opens an SSE connection and gets a
> `400 SSE error`. The local npx server avoids the transport mismatch
> entirely.

1. github.com → Settings → Developer settings → **Fine-grained personal
   access tokens** → Generate new token.
2. Grant **read** access to the repos/orgs you need: Contents, Issues,
   Pull requests, Actions. Keeping the PAT read-only is what enforces
   read-only behavior — the server exposes write tools, but the API
   rejects them without write scopes.
3. If your org enforces SSO, authorize the token for that org.
4. Export it persistently:

   ```sh
   echo 'export GITHUB_MCP_PAT="github_pat_..."' >> ~/.zshrc
   source ~/.zshrc
   ```

5. Verify the token works against the GitHub API (expect `200`):

   ```sh
   curl -sS -o /dev/null -w "%{http_code}\n" \
     -H "Authorization: Bearer $GITHUB_MCP_PAT" \
     https://api.github.com/user
   ```

The config uses this `github` block (already in `opencode/opencode.jsonc`):

```jsonc
"github": {
  "type": "local",
  "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
  "enabled": true,
  "environment": { "GITHUB_PERSONAL_ACCESS_TOKEN": "{env:GITHUB_MCP_PAT}" }
}
```

## 6. Docker-local alternative (optional)

`@modelcontextprotocol/server-github` is functional but marked deprecated.
If you prefer GitHub's actively-maintained official server and have Docker
Desktop **running**, swap the `command`/`environment` for:

```jsonc
"github": {
  "type": "local",
  "command": ["docker", "run", "-i", "--rm",
    "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
    "ghcr.io/github/github-mcp-server"],
  "enabled": true,
  "environment": { "GITHUB_PERSONAL_ACCESS_TOKEN": "{env:GITHUB_MCP_PAT}" }
}
```

The tradeoff: Docker must be running whenever you launch opencode.

## 7. Launch

Start opencode from a shell where `GITHUB_MCP_PAT` is exported (env vars
are read at launch). MCP tools load at startup and are available to
**new** sessions — an already-open session won't pick up a
newly-added connector.

Sanity checks:

- Log line `service=mcp key=github type=local found` (no errors).
- In a fresh chat: "search my repos for X" should call a `github_*`
  tool instead of shelling out to `gh`.
- Run `/ship "<small change>"` to confirm the pipeline flows.

## Model routing reference

| Agent    | Model                              | Why                          |
|----------|------------------------------------|------------------------------|
| planner  | `anthropic/claude-opus-4-6` | Deep reasoning               |
| reviewer | `anthropic/claude-opus-4-6` | Independent final judgment   |
| coder    | `anthropic/claude-sonnet-4-6` | Mechanical implementation  |
| tester   | `anthropic/claude-sonnet-4-6` | Structured, bounded        |
| pr-writer| `anthropic/claude-sonnet-4-6` | PR mechanics and description |
| ship     | `anthropic/claude-haiku-4-5` | Pure coordination            |
| (default)| `anthropic/claude-sonnet-4-6` | Interactive default         |
| (small)  | `anthropic/claude-haiku-4-5` | Titles, summaries, compaction |
