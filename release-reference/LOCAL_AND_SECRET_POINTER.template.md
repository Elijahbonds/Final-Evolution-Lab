# Local paths & secrets (template)

**Copy this file to `LOCAL_AND_SECRET_POINTER.md`** in the same folder and fill in values. Add `LOCAL_AND_SECRET_POINTER.md` to `.gitignore` if it contains secrets (recommended).

```gitignore
# suggested line in repo root .gitignore:
superapp-reference/LOCAL_AND_SECRET_POINTER.md
```

## Fill in

| Key | Your value |
|-----|------------|
| Mac UE project root | e.g. `~/Developer/FinalEvolutionLab57` |
| `.uproject` path | full path |
| UE engine root | e.g. `/Users/Shared/Epic Games/UE_5.7` |
| Apple Team ID | 10 letters |
| App Store Connect app name / bundle ID | |
| Superapp org / API base (if any) | |
| Default backend URL for device builds | |

## Why this file exists

Agents reading **only Git** cannot see your **disk layout** or **ASC** identifiers. This optional local file makes Superapp/Windsurf **non-blind** on your machine without committing secrets.
