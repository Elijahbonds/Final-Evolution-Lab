# OpenClaw + this repo

**What “integration” means here**

- **Cursor’s AI (Composer / chat)** and **OpenClaw** are different runtimes. This chat cannot call your installed `openclaw` CLI unless you add an **MCP server** or other bridge that Cursor exposes—and that is optional, local setup.
- **OpenClaw** shines when it runs **in your terminal** (or daemon) with this repo open: same files, same git, same goals.

**Practical alignment (no special plugin required)**

1. **Point OpenClaw at this workspace**  
   `cd /path/to/final-evolution-lab` (or your clone path) before tasks so paths in prompts resolve.

2. **Give it the same ground truth as Cursor**  
   Paste or `@`-reference for big tasks:
   - `UNREAL_ONLY.md` — Unreal-first stack
   - `UnrealStarter/README.md` — drop-in C++ / Python
   - `FINAL_EVOLUTION_LAB_CONTEXT.md` — product + legacy Swift note

3. **Optional: OpenClaw skills for Cursor CLI**  
   If you use the ecosystem that wires OpenClaw to **Cursor Agent CLI**, install skills from their catalog (e.g. search for `cursor-agent` on [OpenClaw skills / playbooks](https://playbooks.com))—versions and names change, so follow the current `openclaw skill add …` docs from [openclaw.ai](https://openclaw.ai).

4. **Daemon / onboarding**  
   After `openclaw onboard --install-daemon`, follow OpenClaw’s own docs for **gateway**, **skills**, and **workspace** defaults so new sessions inherit this repo.

**What not to expect**

- This repository does **not** ship a proprietary Claw ↔ Cursor bridge binary.
- **I (the assistant in Cursor)** do not automatically see OpenClaw’s session history unless you paste it or sync via a configured MCP.

---

## Troubleshooting (`openclaw doctor`)

**`Config validation failed: models.providers.google.baseUrl: expected string, received undefined`**  
Doctor may move your Gemini API key under `models.providers.google.apiKey` but the schema still requires an explicit **`baseUrl`** string. In `~/.openclaw/config.json` (or the path `openclaw config path` prints), ensure:

```json
"models": {
  "providers": {
    "google": {
      "apiKey": "YOUR_KEY",
      "baseUrl": "https://generativelanguage.googleapis.com/v1beta"
    }
  }
}
```

Adjust only if you use a proxy or newer OpenClaw docs specify a different host. See [Model providers](https://docs.openclaw.ai/concepts/model-providers).

**`imsg not found` / iMessage channel**  
Optional. Install or enable the `imsg` helper OpenClaw expects, or disable the iMessage channel in config if you do not use it.

**`channels.imessage.groupPolicy` allowlist + empty `groupAllowFrom`**  
Either add sender IDs to `groupAllowFrom`, or set `groupPolicy` to `"open"` if that matches your security model.

**“Not a git checkout”**  
Update with `openclaw update` via npm/pnpm, or clone OpenClaw from Git if you develop on source.

**`Control UI assets not found` / `pnpm ui:build` / `vite: command not found`**  
From the OpenClaw repo root (`~/openclaw`): ensure Node is on `PATH`, then install **including devDependencies** (Vite lives there), then build:

```bash
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"   # adjust if your Node path differs
export NODE_ENV=development
pnpm install
pnpm ui:build
```

If `pnpm` is missing: `corepack enable && corepack prepare pnpm@latest --activate`. Artifacts land under `dist/control-ui/`.

---

*Add MCP or skill pins here if you standardize them for the team.*
