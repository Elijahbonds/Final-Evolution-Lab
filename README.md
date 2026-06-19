# Final Evolution Lab

Final Evolution Lab is an athlete operating system that combines system scans, game-mode launches, AI coaching, Bio-Fuel nutrition, education tracks, social/community features, and sovereign performance telemetry.

## Runnable in this Linux workspace

| Area | Path | Command |
|---|---|---|
| React web app | `frontend/` | `npm start` |
| Production web build | `frontend/` | `npm run build` |
| FastAPI backend | `backend/` | `uvicorn server:app --host 0.0.0.0 --port 8000` |
| Static game registry smoke test | repo root | `python3 scripts/smoke_test_modes.py` |

Copy `frontend/.env.example` and `backend/.env.example` before local runs.

## Native/toolchain-limited areas

- `FinalEvolutionLab/` is the iOS SwiftUI shell and requires Xcode/macOS plus local Firebase credentials.
- `UnrealIntegration/` contains UE 5.7 C++ drop-in files that must be copied into the full Unreal game project before compiling.
- `UnrealStarter/BasketballGame/` is a config/registry mirror, not a complete `.uproject`.

## Quality gates

Recommended checks before shipping branch changes:

```bash
python3 scripts/smoke_test_modes.py
python -m py_compile backend/server.py backend/core.py backend/routers/biofuel.py
cd frontend && npm run build
```

Backend integration tests under `backend/tests/` expect a running backend, MongoDB, and seeded auth/session data.
