# NEXUS Agent Tools

Sandboxed tool registry for `NEXUSAgentService` / `NexusAgentChatView` — Cursor-like NEXUS environment control with whitelisted actions only.

**Canonical repo:** `~/Final-Evolution-Lab`  
**Configure root:** Xcode scheme env `NEXUS_REPO_ROOT` (defaults to `/Users/elijahbonds/Final-Evolution-Lab`)  
**Cursor bridge:** `docs/NEXUS_CURSOR_BRIDGE.md`

## Implemented tools

| Tool | Purpose | Sandbox |
| --- | --- | --- |
| `list_modes` | Arena registry with sprint priority (P0 dunk, P1 karate endless) and release state | Read-only in-app metadata |
| `playtest` | MCP/Cursor alias → `launch_mode` | Valid registry ids only; preview modes gated by `Config.showPreviewGameModes` |
| `build_gate` | MCP/Cursor alias → `run_build_gate` | **macOS only** — whitelisted scripts |
| `agent_command` | Route whitelisted sub-tools (`read_file`, `creative_command`, …) | Registry in `Config/nexus_cursor_tool_registry.json` |
| `read_file` | Read repo text files for code/docs inspection | Repo-relative only; no `..`; max 256 KB; binary extensions blocked |
| `run_build_gate` | Preflight NEXUS CI locally | **macOS only** — `scripts/nexus_build_gate.sh` or `scripts/nexus_validate_production_modes.sh` |
| `launch_mode` | Navigate iOS app to `GamePlayView` for a `GameModeId` | Same as `playtest` |
| `creative_command` | `fel.creative.*` terrain edits | Whitelisted commands via C++ `VoxelCommandParser` / `NexusGameplayBridge` |
| `scan_to_generate` | Scan envelope → `fel.generate.arena_from_scan` | `ScanToGenerationBridge` when linked; otherwise simulated `ScanEnvelopeCommandMapper` plan |
| `open_ide_file` | Surface absolute path + `cursor://file/…` URI | Same path rules as `read_file`; pasteboard on iOS |

**MCP surface (Cursor):** `list_modes`, `playtest`, `build_gate`, `agent_command` — see `Config/nexus_cursor_tool_registry.json`.

## LLM backends

| Backend | Env | Notes |
| --- | --- | --- |
| **Local stub** (default) | — | Keyword + `/list`, `/read`, `/gate`, `/open` routing; embedded JSON `tool_call` blocks |
| **Gemini** | `NEXUS_AGENT_GEMINI_KEY` or `GEMINI_API_KEY` | REST `generateContent` with function declarations (Firebase AI Logic–compatible surface) |

System prompt enforces **NEXUS-only ship**, honest preview labeling, and engine (C++) vs app (Swift) separation — see `NEXUSAgentService.systemPrompt`.

## Security boundaries

1. **No arbitrary shell** — only two bash scripts; iOS returns blocked payload with manual command text.
2. **No writes** — tools are read-only or in-process C++ commands; action log append is best-effort when repo is writable from host.
3. **Path jail** — all file paths resolved under `NEXUS_REPO_ROOT`; absolute paths and traversal rejected.
4. **Creative whitelist** — `fel.creative.raise_terrain`, `lower_terrain`, `flatten_terrain`, `paint_terrain` only.
5. **Scan-to-generation** — `scan_to_generate` uses `ScanCaptureService.simulatedEnvelope()` or caller envelope; live path requires linked `NexusGameplayBridge`.
6. **Network** — Gemini backend only when explicitly selected; no tool performs HTTP except the optional planner.

## Example chat flows

### List sprint modes
```
User: list modes
Agent: [list_modes] → 19 modes, P0 basketball_dunk, P1 karate_endless highlighted
```

### Read ship pivot doc
```
User: read NEXUS_ONLY_PIVOT.md
Agent: [read_file] → full markdown content in tool payload
```

### Build gate (macOS host)
```
User: run build gate
Agent: [run_build_gate target=full_gate] → headless + full renderer ctest output
```

### Launch dunk contest
```
User: launch basketball_dunk
Agent: [launch_mode] → switches to Arena tab, presents GamePlayView
```

### Creative terrain
```
User: raise terrain at origin
Agent: [creative_command fel.creative.raise_terrain] → C++ voxel parser applied envelope
```

### Scan to generate (simulated)
```
User: scan to generate arena
Agent: [scan_to_generate use_simulated=true] → command_plan or ScanToGenerationBridge result
```

### Open source in IDE
```
User: open FinalEvolutionLab/Services/NexusGameplayEngine.swift
Agent: [open_ide_file] → cursor://file/… URI + pasteboard
```

## Swift files

| File | Role |
| --- | --- |
| `FinalEvolutionLab/Models/NEXUSAgentModels.swift` | Messages, tool enums, notifications |
| `FinalEvolutionLab/Services/NEXUSAgentService.swift` | Tool registry + sandbox execution + action log |
| `FinalEvolutionLab/Services/NEXUSCursorBridge.swift` | Shared Cursor URIs + registry load + MCP aliases |
| `FinalEvolutionLab/Services/NEXUSAgentLLMClient.swift` | Local stub + Gemini REST planner |
| `FinalEvolutionLab/Services/NEXUSAgentCoordinator.swift` | Chat orchestration |
| `FinalEvolutionLab/Services/ScanToGenerationBridge.swift` | `fel.generate.arena_from_scan` bridge |
| `FinalEvolutionLab/Models/ScanEnvelope.swift` | Envelope schema + test mapper |
| `FinalEvolutionLab/Views/NexusAgentChatView.swift` | SwiftUI chat UI (Agent tab) |
| `FinalEvolutionLabTests/NEXUSAgentServiceTests.swift` | Sandbox unit tests |
| `Config/nexus_cursor_tool_registry.json` | Shared tool metadata for Cursor MCP + in-app agent |

## Action log (auto-appended when repo is writable)

| Timestamp | Tool | Result | Arguments | Summary |
| --- | --- | --- | --- | --- |
| 2026-06-19T21:36:25Z | `list_modes` | PASS | {} | Listed 20 mode(s) |
| 2026-06-19T21:46:07Z | `list_modes` | PASS | {} | Listed 20 mode(s) |
| 2026-06-19T21:52:38Z | `list_modes` | PASS | {} | Listed 20 mode(s) |
| 2026-06-19T23:00:38Z | `list_modes` | PASS | {} | Listed 20 mode(s) |
| 2026-06-19T23:07:51Z | `list_modes` | PASS | {} | Listed 20 mode(s) |
| 2026-06-20T02:02:57Z | `list_modes` | PASS | {} | Listed 20 mode(s) |
