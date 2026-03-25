# DeepMotion Animate 3D (REST + Python SDK)

Official **Animate 3D REST API** converts uploaded videos to 3D animations (FBX, BVH, GLB, etc.) without using the web portal alone. Use **HTTP Basic** auth or the **Python SDK** (`pip install dm-animate3d-api`).

## Authentication (REST)

The API uses **Basic** authentication. Build the header:

```http
Authorization: Basic Base64(<clientId>:<clientSecret>)
```

Example: Client ID `1a2b`, Client Secret `3c4d` → encode the string `1a2b:3c4d` in Base64 → `Authorization: Basic MWEyYjozYzRk`.

Credentials come from DeepMotion (support or sales). Do **not** commit them; use environment variables (see `deepmotion_animate3d.env.example`).

## Python SDK

- **Install:** `pip install -r scripts/requirements-animate3d.txt`  
- **Imports:** `from dm.animate3d import Animate3DClient, ProcessParams` (sync) or `AsyncAnimate3DClient` (async).  
- **Docs / source:** [dm-animate3d-api on PyPI](https://pypi.org/project/dm-animate3d-api/), [DeepMotion Animate 3D API](https://www.deepmotion.com/animate-3d-api).

## Repo integration

| Asset | Purpose |
|--------|--------|
| `scripts/deepmotion_animate3d_pipeline.py` | CLI: `balance`, `single` (one video → FBX/BVH), `multiperson` (detection + processing) |
| `scripts/deepmotion_process_params.py` | FEL defaults: `sim=1`, `pose_filtering_strength=1.0`, `root_at_origin=True`, foot locking |
| `scripts/deepmotion_animate3d_service.py` | Optional JSON queue poll → runs pipeline (background-friendly) |
| `scripts/requirements-animate3d.txt` | Pins the official SDK |
| `scripts/deepmotion_animate3d.env.example` | Env var names for Client ID / Secret |

**Unreal:** Import resulting FBX as `UAnimSequence` / montages; assign per `EFELJumpTimingBand` in `FFELSportNeuroConstants::JumpTimingTakeoffSequences` (`FELArenaRulesTypes.h`). Register **Academy** module montages on `UFELAcademyMocapCatalogSubsystem` (`mod1`…`mod12`). Use **`FFELAvatarRetargetPipeline`** for IK Retargeter soft refs. **Never** commit credentials from screenshots—use env vars and CI secrets only.

**Unreal C++ (REST parity):** `UFELDeepMotionSessionSubsystem` performs `GET {ApiHost}/session/auth` with `Authorization: Basic …` and stores the `dmsess` cookie for follow-up REST calls (upload/process) if you extend the bridge beyond the Python SDK.

## Experimental multi-person API

The SDK exposes:

- `prepare_multi_person_job` — person detection in the video  
- `start_multi_person_job` — run animation with a **list of character model IDs** (one per person, order must match your pipeline)

Use `python scripts/deepmotion_animate3d_pipeline.py multiperson --help` and the SDK’s `examples/sync_multiperson_usage.py` for full parameter details.
