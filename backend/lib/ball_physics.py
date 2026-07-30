"""
ball_physics.py — Shared DETERMINISTIC ball-trajectory engine (Nexus AAA).

The authoritative, server-side physics core shared by every ball sport
(soccer/baseball/tennis/...). Given initial conditions (position, velocity,
spin) plus an OPTIONAL seeded wind draw, it integrates the flight in fixed
timesteps to an exact, reproducible path.

Determinism contract
─────────────────────
  * No wall-clock, no ambient RNG. The ONLY source of variability is an
    explicit integer `wind_seed`; identical (initial conditions + wind_seed)
    always produce a byte-identical path (same float bit patterns).
  * Fixed timestep semi-implicit Euler integration (order-independent, no
    adaptive stepping) so replays reproduce exactly across machines.
  * All physics constants are module-level and part of the contract.

Per-sport seam
──────────────
The physics core knows nothing about goals, bases, courts, or lines. Each
sport supplies an `AdjudicationRule` (see `Adjudicator`) that consumes the
trajectory produced here and returns an `Outcome`. The core integrates; the
rule judges. New sports plug in by registering a rule — the engine, endpoint
plumbing, replay round-trip, and determinism guarantees are inherited for free.

Reference sport (soccer) lives in `lib/sports/soccer.py`.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

# ── Physics constants (part of the determinism contract) ───────────────────
GRAVITY = 9.80665            # m/s^2, standard gravity
AIR_DENSITY = 1.225          # kg/m^3, sea-level
DEFAULT_DT = 0.005           # s, fixed integration timestep (200 Hz)
MAX_STEPS = 20000            # hard cap so a bad input can never spin forever

# Wind draw bounds (m/s per axis). A seeded wind is a small constant vector
# added to the ambient air velocity for the whole flight.
_WIND_MAX = 4.0


def _q(x: float) -> float:
    """Quantize to a fixed grid so accumulated float noise is identical across
    platforms/compilers. 1e-9 m / (m/s) resolution — far below any physical
    tolerance but enough to pin the low bits of the mantissa."""
    return round(x, 9) + 0.0  # +0.0 normalizes -0.0 -> 0.0


@dataclass(frozen=True)
class Vec3:
    x: float
    y: float
    z: float  # z is the vertical (up) axis

    def __add__(self, o: "Vec3") -> "Vec3":
        return Vec3(self.x + o.x, self.y + o.y, self.z + o.z)

    def __sub__(self, o: "Vec3") -> "Vec3":
        return Vec3(self.x - o.x, self.y - o.y, self.z - o.z)

    def scale(self, s: float) -> "Vec3":
        return Vec3(self.x * s, self.y * s, self.z * s)

    def dot(self, o: "Vec3") -> float:
        return self.x * o.x + self.y * o.y + self.z * o.z

    def cross(self, o: "Vec3") -> "Vec3":
        return Vec3(
            self.y * o.z - self.z * o.y,
            self.z * o.x - self.x * o.z,
            self.x * o.y - self.y * o.x,
        )

    def norm(self) -> float:
        return math.sqrt(self.dot(self))

    def as_tuple(self) -> Tuple[float, float, float]:
        return (self.x, self.y, self.z)

    def quantized(self) -> "Vec3":
        return Vec3(_q(self.x), _q(self.y), _q(self.z))


@dataclass(frozen=True)
class BallSpec:
    """Physical properties of the ball. Defaults ~ a size-5 football."""
    mass: float = 0.43            # kg
    radius: float = 0.11          # m
    drag_coeff: float = 0.25      # dimensionless
    magnus_coeff: float = 0.22    # lift coefficient scale for spin (Magnus)

    @property
    def area(self) -> float:
        return math.pi * self.radius * self.radius


@dataclass(frozen=True)
class InitialConditions:
    """Everything needed to launch a shot. Pure data, JSON-round-trippable."""
    position: Vec3                 # m
    velocity: Vec3                 # m/s
    spin: Vec3 = field(default_factory=lambda: Vec3(0.0, 0.0, 0.0))  # rad/s (angular velocity)
    wind_seed: Optional[int] = None
    ball: BallSpec = field(default_factory=BallSpec)
    dt: float = DEFAULT_DT
    max_time: float = 8.0          # s, stop integrating after this even if airborne


@dataclass
class TrajectorySample:
    t: float
    position: Vec3
    velocity: Vec3

    def as_dict(self) -> Dict[str, object]:
        return {
            "t": _q(self.t),
            "p": list(self.position.quantized().as_tuple()),
            "v": list(self.velocity.quantized().as_tuple()),
        }


@dataclass
class Trajectory:
    """The exact integrated path. `samples` is the authoritative record."""
    samples: List[TrajectorySample]
    wind: Vec3
    dt: float
    stop_reason: str               # "ground" | "max_time" | "max_steps" | "boundary_stop"

    @property
    def final(self) -> TrajectorySample:
        return self.samples[-1]

    def positions(self) -> List[Vec3]:
        return [s.position for s in self.samples]

    def as_dict(self) -> Dict[str, object]:
        return {
            "wind": list(self.wind.quantized().as_tuple()),
            "dt": _q(self.dt),
            "stop_reason": self.stop_reason,
            "sample_count": len(self.samples),
            "samples": [s.as_dict() for s in self.samples],
        }

    def path_hash(self) -> str:
        """A stable digest of the whole path — the determinism fingerprint."""
        import hashlib
        h = hashlib.sha256()
        for s in self.samples:
            h.update(repr(s.as_dict()).encode())
        h.update(self.stop_reason.encode())
        return h.hexdigest()


def draw_wind(wind_seed: Optional[int]) -> Vec3:
    """The ONLY stochastic element. A seeded, bounded horizontal wind vector.

    `wind_seed=None` → zero wind (fully deterministic no-wind flight).
    A given integer seed always yields the same wind vector.
    """
    if wind_seed is None:
        return Vec3(0.0, 0.0, 0.0)
    rng = random.Random(wind_seed)
    wx = rng.uniform(-_WIND_MAX, _WIND_MAX)
    wy = rng.uniform(-_WIND_MAX, _WIND_MAX)
    # Vertical gust is intentionally small so wind can't loft the ball absurdly.
    wz = rng.uniform(-_WIND_MAX * 0.15, _WIND_MAX * 0.15)
    return Vec3(_q(wx), _q(wy), _q(wz))


# Optional per-step callback: a sport can ask the integrator to stop early when
# the ball crosses a plane of interest (e.g. the goal mouth). Kept out of the
# core so the physics stays sport-agnostic.
class BoundaryStop(Exception):
    """Raised by an integration hook to stop the flight (e.g. crossed goal line)."""


def integrate(
    ic: InitialConditions,
    *,
    stop_hook=None,
) -> Trajectory:
    """Fixed-timestep semi-implicit Euler integration of the ball flight.

    Deterministic: identical `ic` (including `wind_seed`) → byte-identical path.

    Forces modelled:
      * gravity
      * quadratic aerodynamic drag against air (air = -wind vector)
      * Magnus lift from spin: F = C * rho * A * r * (omega x v_rel)

    `stop_hook(prev_sample, sample)` may return True to end the flight early
    (used by sports to snapshot the exact goal-line crossing). It runs AFTER
    each committed step and never mutates state, so determinism is preserved.
    """
    dt = ic.dt
    ball = ic.ball
    wind = draw_wind(ic.wind_seed)

    pos = ic.position
    vel = ic.velocity
    spin = ic.spin

    # Precompute constant scalar factors.
    k_drag = 0.5 * AIR_DENSITY * ball.drag_coeff * ball.area / ball.mass
    k_magnus = ball.magnus_coeff * AIR_DENSITY * ball.area * ball.radius / ball.mass

    samples: List[TrajectorySample] = [
        TrajectorySample(t=0.0, position=pos.quantized(), velocity=vel.quantized())
    ]
    stop_reason = "max_time"
    t = 0.0
    steps = 0
    n_max = min(MAX_STEPS, int(ic.max_time / dt) + 2)

    while steps < n_max:
        # Relative air velocity (ball through the wind field).
        v_rel = vel - wind
        speed = v_rel.norm()

        # Drag: opposes v_rel, quadratic in speed.
        if speed > 0.0:
            drag = v_rel.scale(-k_drag * speed)
        else:
            drag = Vec3(0.0, 0.0, 0.0)

        # Magnus: omega x v_rel.
        magnus = spin.cross(v_rel).scale(k_magnus)

        gravity = Vec3(0.0, 0.0, -GRAVITY)
        accel = gravity + drag + magnus

        # Semi-implicit Euler: update velocity, then position with new velocity.
        new_vel = Vec3(
            _q(vel.x + accel.x * dt),
            _q(vel.y + accel.y * dt),
            _q(vel.z + accel.z * dt),
        )
        new_pos = Vec3(
            _q(pos.x + new_vel.x * dt),
            _q(pos.y + new_vel.y * dt),
            _q(pos.z + new_vel.z * dt),
        )

        # Ground contact: interpolate the exact z=0 crossing for an exact stop.
        if new_pos.z <= 0.0 and pos.z > 0.0:
            frac = pos.z / (pos.z - new_pos.z) if (pos.z - new_pos.z) != 0 else 0.0
            hit = Vec3(
                _q(pos.x + (new_pos.x - pos.x) * frac),
                _q(pos.y + (new_pos.y - pos.y) * frac),
                0.0,
            )
            t = _q(t + dt * frac)
            samples.append(TrajectorySample(t=t, position=hit, velocity=new_vel))
            stop_reason = "ground"
            break

        t = _q(t + dt)
        pos, vel = new_pos, new_vel
        prev = samples[-1]
        sample = TrajectorySample(t=t, position=pos, velocity=vel)
        samples.append(sample)
        steps += 1

        if stop_hook is not None and stop_hook(prev, sample):
            stop_reason = "boundary_stop"
            break

        if t >= ic.max_time:
            stop_reason = "max_time"
            break
    else:
        stop_reason = "max_steps"

    return Trajectory(samples=samples, wind=wind, dt=dt, stop_reason=stop_reason)


# ═══════════════════════════════════════════════════════════════════════════
# Event-adjudication seam (pluggable per sport)
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class Outcome:
    """The adjudicated result of a shot. `outcome` is the sport's verdict
    (e.g. "goal" | "miss" | "save" for soccer); `detail` carries structured
    sport-specific fields; `crossing` is the exact point/velocity at the
    boundary of interest when one exists."""
    sport: str
    outcome: str
    detail: Dict[str, object] = field(default_factory=dict)
    crossing: Optional[Dict[str, object]] = None

    def as_dict(self) -> Dict[str, object]:
        return {
            "sport": self.sport,
            "outcome": self.outcome,
            "detail": self.detail,
            "crossing": self.crossing,
        }


class AdjudicationRule:
    """Per-sport rule seam.

    A sport implements two things:
      * `build_initial_conditions(inputs)` — translate a sport-specific input
        payload (validated dict) into physics `InitialConditions`. This is the
        ONLY place sport units/geometry meet the core.
      * `adjudicate(inputs, trajectory)` — consume the integrated trajectory
        and return an `Outcome`. May inspect any sample; may also have been
        given a `stop_hook` via `stop_hook(inputs)` to end the flight at the
        boundary of interest.

    `stop_hook(inputs)` is optional; return None for a full flight.

    Because every rule shares the same deterministic core + Outcome shape,
    adding baseball/tennis is: implement one AdjudicationRule subclass, register
    it, and reuse the endpoint + replay round-trip unchanged.
    """
    sport: str = "abstract"

    def build_initial_conditions(self, inputs: Dict[str, object]) -> InitialConditions:
        raise NotImplementedError

    def stop_hook(self, inputs: Dict[str, object]):  # -> Optional[callable]
        return None

    def adjudicate(self, inputs: Dict[str, object], trajectory: Trajectory) -> Outcome:
        raise NotImplementedError


class Adjudicator:
    """Registry + one-call resolve. This is the shared driver every sport uses."""

    def __init__(self) -> None:
        self._rules: Dict[str, AdjudicationRule] = {}

    def register(self, rule: AdjudicationRule) -> None:
        self._rules[rule.sport] = rule

    def rule(self, sport: str) -> AdjudicationRule:
        if sport not in self._rules:
            raise KeyError(f"No adjudication rule registered for sport '{sport}'. "
                           f"Registered: {sorted(self._rules)}")
        return self._rules[sport]

    def resolve(self, sport: str, inputs: Dict[str, object]) -> Tuple[Trajectory, Outcome]:
        """Deterministic end-to-end resolve: inputs → trajectory → outcome.

        Same sport + inputs (+ any wind_seed inside inputs) → identical
        trajectory path hash and identical outcome, every time.
        """
        rule = self.rule(sport)
        ic = rule.build_initial_conditions(inputs)
        hook = rule.stop_hook(inputs)
        traj = integrate(ic, stop_hook=hook)
        outcome = rule.adjudicate(inputs, traj)
        return traj, outcome


# Global registry. Sports self-register on import (see lib/sports/__init__.py).
REGISTRY = Adjudicator()
