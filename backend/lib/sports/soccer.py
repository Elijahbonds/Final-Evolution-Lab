"""
soccer.py — SOCCER reference sport for the shared ball-physics core.

Models a PENALTY KICK: ball starts on the penalty spot (11 m from goal) and is
struck toward the goal. The physics core integrates the flight; this rule
adjudicates goal / miss / save, server-authoritative and deterministic.

Geometry (regulation, metres)
─────────────────────────────
  * Goal line at y = GOAL_Y (ball travels +y toward it).
  * Goal mouth: width GOAL_WIDTH centred on x=0, crossbar at z=GOAL_HEIGHT.
  * Penalty spot: (0, 0, 0), PENALTY_DISTANCE from the goal line.
  * A keeper covers a horizontal reach around a chosen dive position; if the
    ball's goal-line crossing point falls inside the keeper's covered zone the
    shot is SAVED, else GOAL (if within the frame) or MISS (outside the frame).

Determinism: the flight comes straight from `ball_physics.integrate`, whose only
randomness is the optional seeded wind. Keeper reach/position are explicit
inputs (or derived deterministically from a keeper_seed), so identical inputs
always produce the identical outcome.
"""
from __future__ import annotations

from typing import Dict, Optional

from lib.ball_physics import (
    AdjudicationRule,
    BallSpec,
    InitialConditions,
    Outcome,
    Trajectory,
    TrajectorySample,
    Vec3,
    _q,
)

# ── Regulation geometry (metres) ───────────────────────────────────────────
PENALTY_DISTANCE = 11.0
GOAL_Y = PENALTY_DISTANCE          # goal line distance from the spot (+y)
GOAL_WIDTH = 7.32                  # regulation goal width
GOAL_HEIGHT = 2.44                 # regulation crossbar height
HALF_WIDTH = GOAL_WIDTH / 2.0

# Keeper model: reach (m) either side of dive x, default dive to centre.
DEFAULT_KEEPER_REACH = 1.9


class SoccerRule(AdjudicationRule):
    sport = "soccer"

    # ── inputs → physics ────────────────────────────────────────────────────
    def build_initial_conditions(self, inputs: Dict[str, object]) -> InitialConditions:
        """Build launch conditions from a penalty-kick payload.

        Payload fields (all floats unless noted):
          speed          — strike speed (m/s), e.g. 25
          aim_x          — horizontal aim offset at the goal line (m; 0 = centre)
          aim_z          — target height at the goal line (m; e.g. 1.2)
          spin_rps       — sidespin (rev/s about the vertical axis); +curl left
          wind_seed      — optional int; seeds the ambient wind draw
        """
        speed = float(inputs.get("speed", 25.0))
        aim_x = float(inputs.get("aim_x", 0.0))
        aim_z = float(inputs.get("aim_z", 1.0))
        spin_rps = float(inputs.get("spin_rps", 0.0))
        wind_seed = inputs.get("wind_seed", None)
        wind_seed = int(wind_seed) if wind_seed is not None else None

        # Aim a straight-line launch from spot (0,0,0) to (aim_x, GOAL_Y, aim_z),
        # then scale to the requested strike speed. Drag/gravity/Magnus then bend
        # it — aim_x/aim_z are the *intended* target, not a guaranteed landing.
        dx, dy, dz = aim_x, GOAL_Y, aim_z
        dist = (dx * dx + dy * dy + dz * dz) ** 0.5
        ux, uy, uz = dx / dist, dy / dist, dz / dist
        velocity = Vec3(_q(ux * speed), _q(uy * speed), _q(uz * speed))

        # Sidespin about vertical (z) axis, rev/s → rad/s.
        spin = Vec3(0.0, 0.0, _q(spin_rps * 2.0 * 3.141592653589793))

        return InitialConditions(
            position=Vec3(0.0, 0.0, 0.0),
            velocity=velocity,
            spin=spin,
            wind_seed=wind_seed,
            ball=BallSpec(),        # size-5 football defaults
            max_time=4.0,
        )

    # ── stop the flight exactly at the goal line ────────────────────────────
    def stop_hook(self, inputs: Dict[str, object]):
        def _hook(prev: TrajectorySample, cur: TrajectorySample) -> bool:
            # Stop once the ball reaches/passes the goal-line plane y = GOAL_Y.
            return cur.position.y >= GOAL_Y
        return _hook

    # ── trajectory → verdict ────────────────────────────────────────────────
    def _goal_line_crossing(self, traj: Trajectory) -> Optional[Vec3]:
        """Exact (x,z) where the ball crosses y=GOAL_Y, linearly interpolated."""
        samples = traj.samples
        for i in range(1, len(samples)):
            a, b = samples[i - 1].position, samples[i].position
            if a.y < GOAL_Y <= b.y:
                span = b.y - a.y
                frac = (GOAL_Y - a.y) / span if span != 0 else 0.0
                return Vec3(
                    _q(a.x + (b.x - a.x) * frac),
                    GOAL_Y,
                    _q(a.z + (b.z - a.z) * frac),
                )
        # Never reached the line (fell short / stopped on ground before goal).
        return None

    def _keeper(self, inputs: Dict[str, object]) -> Dict[str, float]:
        """Deterministic keeper: explicit dive_x/reach, or derived from keeper_seed."""
        reach = float(inputs.get("keeper_reach", DEFAULT_KEEPER_REACH))
        if "keeper_dive_x" in inputs and inputs["keeper_dive_x"] is not None:
            dive_x = float(inputs["keeper_dive_x"])
        elif inputs.get("keeper_seed") is not None:
            import random
            rng = random.Random(int(inputs["keeper_seed"]))
            dive_x = _q(rng.uniform(-HALF_WIDTH, HALF_WIDTH))
        else:
            dive_x = 0.0  # stand centre
        return {"dive_x": dive_x, "reach": reach}

    def adjudicate(self, inputs: Dict[str, object], trajectory: Trajectory) -> Outcome:
        crossing = self._goal_line_crossing(trajectory)
        keeper = self._keeper(inputs)

        if crossing is None:
            return Outcome(
                sport=self.sport,
                outcome="miss",
                detail={"reason": "short", "keeper": keeper,
                        "stop_reason": trajectory.stop_reason},
                crossing=None,
            )

        within_posts = abs(crossing.x) <= HALF_WIDTH
        under_bar = 0.0 <= crossing.z <= GOAL_HEIGHT
        on_target = within_posts and under_bar

        cross_dict = {"x": crossing.x, "z": crossing.z, "y": GOAL_Y}

        if not on_target:
            reason = []
            if not within_posts:
                reason.append("wide")
            if crossing.z > GOAL_HEIGHT:
                reason.append("over")
            return Outcome(
                sport=self.sport,
                outcome="miss",
                detail={"reason": "+".join(reason) or "off_target", "keeper": keeper},
                crossing=cross_dict,
            )

        # On target: does the keeper reach it?
        saved = abs(crossing.x - keeper["dive_x"]) <= keeper["reach"]
        if saved:
            return Outcome(
                sport=self.sport,
                outcome="save",
                detail={"keeper": keeper,
                        "reach_gap": _q(abs(crossing.x - keeper["dive_x"]))},
                crossing=cross_dict,
            )
        return Outcome(
            sport=self.sport,
            outcome="goal",
            detail={"keeper": keeper,
                    "beat_keeper_by": _q(abs(crossing.x - keeper["dive_x"]) - keeper["reach"])},
            crossing=cross_dict,
        )
