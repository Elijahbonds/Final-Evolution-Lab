"""
FEL defaults for DeepMotion ProcessParams — smooth, grounded output for Unreal import.

- Physics simulation: sim = 1
- Smoothing: pose_filtering_strength = 1.0 (SDK field; maps to "advanced AI" smoothing product language)
- Root at origin: root_at_origin = True (pairs with IK Retargeter + Motion Warping in engine)
- Foot locking: foot_locking_mode = grounding when supported

If the SDK exposes `advanced_ai_filter`, it is set via _apply_optional_sdk_fields().
"""
from __future__ import annotations

from typing import Any


def _apply_optional_sdk_fields(p: Any) -> None:
    for name in ("advanced_ai_filter", "advancedAiFilter"):
        if hasattr(p, name):
            setattr(p, name, 1.0)


def build_fel_process_params(
    *,
    formats: list[str],
    model_id: str | None = None,
    track_face: int = 1,
    track_hand: int = 1,
    foot_locking_mode: str = "grounding",
) -> Any:
    from dm.animate3d import ProcessParams

    kwargs: dict[str, Any] = {
        "formats": formats,
        "track_face": track_face,
        "track_hand": track_hand,
        "sim": 1,
        "pose_filtering_strength": 1.0,
        "root_at_origin": True,
        "foot_locking_mode": foot_locking_mode,
    }
    if model_id:
        kwargs["model_id"] = model_id

    try:
        p = ProcessParams(**kwargs)
    except TypeError:
        kwargs.pop("foot_locking_mode", None)
        try:
            p = ProcessParams(**kwargs)
        except TypeError:
            kwargs.pop("root_at_origin", None)
            try:
                p = ProcessParams(**kwargs)
            except TypeError:
                kwargs.pop("pose_filtering_strength", None)
                try:
                    p = ProcessParams(**kwargs)
                except TypeError:
                    kwargs.pop("sim", None)
                    p = ProcessParams(**kwargs)

    _apply_optional_sdk_fields(p)
    return p
