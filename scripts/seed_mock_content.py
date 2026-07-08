#!/usr/bin/env python3
"""
seed_mock_content.py — Brain Brawl MOCK_CONTENT seeder (nexus/brainbrawl-demo).

Builds backend/content/brainbrawl_questions.json (~100 questions):

  1. Starter set pulled from the Open Trivia Database public API at build time
     (https://opentdb.com — free to use, CC BY-SA 4.0). No API key required.
  2. Original Final Evolution Lab questions (Deep Dive explainables with
     micro-lessons, multi-select partial-credit items, and singles), authored
     in this file and released under CC0-1.0.

Every question carries taxonomy/skill + difficulty + source + license fields.
Correct answers live ONLY in this server-side JSON — API routes strip them
before anything is shipped to a client (see backend/routers/brainbrawl.py).

Usage:
    python3 scripts/seed_mock_content.py            # fetch OpenTDB + originals
    python3 scripts/seed_mock_content.py --offline  # originals only (no network)

Deterministic: option order is shuffled once here with a per-question fixed
RNG, so the committed JSON (and every runtime consumer) is stable.

Attribution is recorded in infra/ASSET_ATTRIBUTION.md.
"""
import argparse
import hashlib
import html
import json
import random
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PATH = REPO_ROOT / "backend" / "content" / "brainbrawl_questions.json"

OPENTDB_URL = "https://opentdb.com/api.php?amount={amount}&type=multiple"
OPENTDB_BATCHES = [50, 30]          # 80 requested; de-dup may trim a few
OPENTDB_RATE_LIMIT_SECONDS = 5.5    # OpenTDB allows 1 request / 5 s per IP

# OpenTDB category -> FEL taxonomy category
_CATEGORY_MAP = {
    "General Knowledge": "general",
    "Science & Nature": "science",
    "Science: Computers": "technology",
    "Science: Gadgets": "technology",
    "Science: Mathematics": "mathematics",
    "Geography": "geography",
    "History": "history",
    "Politics": "civics",
    "Art": "art",
    "Animals": "science",
    "Vehicles": "technology",
    "Sports": "sport_history",
    "Celebrities": "pop_culture",
    "Mythology": "history",
}


def _fel_category(raw: str) -> str:
    if raw in _CATEGORY_MAP:
        return _CATEGORY_MAP[raw]
    if raw.startswith("Entertainment"):
        return "pop_culture"
    if raw.startswith("Science"):
        return "science"
    return "general"


def _mk_question(qid, prompt, options, answer_indices, qtype, category, skill,
                 difficulty, source, license_str, modes,
                 explanation=None, micro_lesson=None):
    q = {
        "id": qid,
        "type": qtype,                      # "single" | "multi"
        "prompt": prompt,
        "options": options,
        "answer": sorted(answer_indices),   # SERVER-SIDE ONLY — stripped by API
        "taxonomy": {"category": category, "skill": skill},
        "difficulty": difficulty,           # easy | medium | hard
        "modes": modes,                     # ["blitz"] and/or ["deep_dive"]
        "source": source,
        "license": license_str,
    }
    if explanation:
        q["explanation"] = explanation
    if micro_lesson:
        q["micro_lesson"] = micro_lesson
    return q


# ── OpenTDB fetch ───────────────────────────────────────────────────────────

def fetch_opentdb() -> list:
    """Fetch a starter set from OpenTDB. Returns [] on any network failure."""
    out, seen_prompts = [], set()
    for batch_i, amount in enumerate(OPENTDB_BATCHES):
        if batch_i > 0:
            time.sleep(OPENTDB_RATE_LIMIT_SECONDS)
        url = OPENTDB_URL.format(amount=amount)
        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
        except (urllib.error.URLError, OSError, ValueError) as exc:
            print(f"[warn] OpenTDB batch {batch_i} failed: {exc}", file=sys.stderr)
            continue
        if payload.get("response_code") != 0:
            print(f"[warn] OpenTDB response_code={payload.get('response_code')}",
                  file=sys.stderr)
            continue
        for item in payload.get("results", []):
            prompt = html.unescape(item["question"]).strip()
            if prompt in seen_prompts:
                continue
            seen_prompts.add(prompt)
            correct = html.unescape(item["correct_answer"]).strip()
            wrong = [html.unescape(w).strip() for w in item["incorrect_answers"]]
            options = [correct] + wrong
            # Deterministic per-question option shuffle (stable committed JSON).
            qid = "otdb_" + hashlib.sha1(prompt.encode("utf-8")).hexdigest()[:10]
            rng = random.Random(int(hashlib.sha1(qid.encode()).hexdigest()[:8], 16))
            rng.shuffle(options)
            out.append(_mk_question(
                qid=qid,
                prompt=prompt,
                options=options,
                answer_indices=[options.index(correct)],
                qtype="single",
                category=_fel_category(html.unescape(item["category"])),
                skill="recall",
                difficulty=item.get("difficulty", "medium"),
                source="Open Trivia Database (opentdb.com)",
                license_str="CC BY-SA 4.0",
                modes=["blitz"],
            ))
    return out


# ── Original FEL content (CC0-1.0) ─────────────────────────────────────────

def _lesson(title, body, takeaway):
    return {"title": title, "body": body, "takeaway": takeaway}


def original_questions() -> list:
    SRC = "Final Evolution Lab original"
    LIC = "CC0-1.0"
    qs = []

    # Deep Dive explainables — one question + micro-lesson payload each.
    deep = [
        ("fel_dd_001", "Why does lactic acid build-up occur during sprinting?",
         ["Muscles switch to anaerobic glycolysis when oxygen delivery lags demand",
          "Sweat glands release acid into the bloodstream",
          "The heart pumps blood away from muscles during effort",
          "Lungs stop absorbing oxygen at high speeds"], [0], "sport_science", "medium",
         "Sprinting demands ATP faster than aerobic metabolism can supply it, so muscles "
         "use anaerobic glycolysis, whose by-product (lactate + H+) accumulates and "
         "produces the classic burning sensation.",
         _lesson("Energy Systems 101",
                 "Your body has three fuel pathways: ATP-PC (0-10s bursts), anaerobic "
                 "glycolysis (10s-2min, produces lactate), and aerobic metabolism "
                 "(sustained efforts). Sprints outrun the aerobic system's delivery rate.",
                 "The burn is a fuel-supply gap, not damage — pacing and conditioning widen the gap you can tolerate.")),
        ("fel_dd_002", "Why do basketball players jump higher after a running approach than from standing?",
         ["The approach stores elastic energy and pre-loads the stretch-shortening cycle",
          "Air resistance is lower when moving",
          "Gravity briefly weakens for moving bodies",
          "Shoes grip better at speed"], [0], "sport_science", "medium",
         "A running approach lets tendons and muscles pre-stretch (eccentric load); the "
         "stretch-shortening cycle then releases stored elastic energy on top of "
         "concentric muscle force, adding centimeters to the jump.",
         _lesson("The Stretch-Shortening Cycle",
                 "Muscles and tendons behave like springs: a rapid pre-stretch followed by "
                 "immediate contraction produces more force than contraction alone. "
                 "Plyometric training targets exactly this cycle.",
                 "Train the spring, not just the motor — plyometrics convert speed into height.")),
        ("fel_dd_003", "Why is the sky blue during the day but red at sunset?",
         ["Shorter blue wavelengths scatter more; at sunset light crosses more atmosphere, leaving red",
          "The sun changes color through the day",
          "Ocean reflections color the sky",
          "Clouds filter out blue at dusk"], [0], "science", "medium",
         "Rayleigh scattering disperses short (blue) wavelengths most. At sunset, light "
         "travels a longer path through the atmosphere, scattering blue away entirely "
         "and leaving the longer red wavelengths.",
         _lesson("Rayleigh Scattering",
                 "Scattering intensity scales with 1/wavelength^4, so blue light scatters "
                 "roughly 5x more than red. Path length through the atmosphere decides "
                 "which wavelengths survive to your eye.",
                 "Same sunlight, different path length — geometry paints the sky.")),
        ("fel_dd_004", "Why does compound interest grow savings faster than simple interest?",
         ["Each period's interest is added to the principal and itself earns interest",
          "Banks pay higher base rates for compound accounts",
          "Compound interest is tax-free",
          "Simple interest stops after ten years"], [0], "financial_literacy", "easy",
         "Compound interest is exponential: interest earned is reinvested, so the base "
         "grows every period. Simple interest stays linear on the original principal.",
         _lesson("Exponential vs Linear Growth",
                 "At 7% compounded annually, money doubles in about 10 years (Rule of 72: "
                 "72 / rate = doubling time). Time in the market beats timing the market "
                 "because the exponent is time.",
                 "Start early: the exponent — time — is the most powerful variable you control.")),
        ("fel_dd_005", "Why can you feel sore two days AFTER a hard workout rather than immediately?",
         ["Micro-tears trigger an inflammatory repair response that peaks 24-72h later",
          "Lactic acid stays trapped in the muscle for two days",
          "The nervous system delays all pain by 48 hours",
          "Muscles only tear during sleep"], [0], "sport_science", "hard",
         "Delayed-onset muscle soreness (DOMS) comes from the inflammatory phase of "
         "repairing exercise-induced micro-damage — not lactate, which clears within "
         "an hour. The repair cascade peaks one to three days post-exercise.",
         _lesson("DOMS and Adaptation",
                 "Eccentric (lengthening) contractions cause the most micro-damage and the "
                 "most soreness — but also drive adaptation. Repeated-bout effect: the "
                 "same workout hurts less the second time.",
                 "Soreness is the repair bill, not the receipt for progress — track load, not pain.")),
        ("fel_dd_006", "Why do international flights heading east often arrive faster than the return leg?",
         ["Jet streams — high-altitude westerly winds — boost eastbound groundspeed",
          "Earth's rotation pushes planes eastward",
          "Airlines use faster planes going east",
          "Eastbound routes are always shorter"], [0], "geography", "medium",
         "Jet streams are narrow bands of strong westerly wind at cruise altitude. Flying "
         "east rides the tailwind; flying west fights a headwind, so the same route "
         "differs by an hour or more.",
         _lesson("Jet Streams",
                 "Jet streams form where cold and warm air masses meet, flowing west-to-east "
                 "at 100-200 km/h. Pilots route into them eastbound and around them westbound.",
                 "The atmosphere has highways — riding them beats fighting them.")),
        ("fel_dd_007", "Why does a curveball actually curve?",
         ["Spin creates a pressure differential across the ball (Magnus effect)",
          "The seams make the ball heavier on one side",
          "Gravity pulls spinning objects sideways",
          "Air humidity bends its path"], [0], "sport_science", "medium",
         "A spinning ball drags air around itself; air moves faster on one side and slower "
         "on the other, creating a pressure difference that pushes the ball sideways — "
         "the Magnus effect.",
         _lesson("The Magnus Effect",
                 "Topspin dives, backspin floats, sidespin curves. The same physics powers "
                 "soccer free kicks, tennis topspin, and golf slices.",
                 "Spin is steering — control the axis and you control the flight.")),
        ("fel_dd_008", "Why is sleep considered a performance enhancer for athletes?",
         ["Growth hormone release, memory consolidation, and tissue repair concentrate during sleep",
          "Sleep burns more calories than training",
          "Muscles only grow when the brain is off",
          "Dreams rehearse game strategy automatically"], [0], "sport_science", "easy",
         "Deep sleep drives the largest natural growth-hormone pulse of the day, motor "
         "learning consolidates during REM, and reaction time degrades measurably with "
         "sleep debt — sleep is when training becomes adaptation.",
         _lesson("Sleep as Training",
                 "Studies on basketball players extending sleep to 10h showed faster sprints "
                 "and +9% free-throw accuracy. Reaction time after 20h awake resembles "
                 "legal intoxication.",
                 "You don't get stronger in the gym — you get stronger in bed. Protect the hours.")),
        ("fel_dd_009", "Why does the moon show phases?",
         ["We see varying fractions of its sunlit half as it orbits Earth",
          "Earth's shadow covers part of the moon each night",
          "Clouds on the moon block reflected light",
          "The moon emits light that fades monthly"], [0], "science", "easy",
         "Half the moon is always sunlit. As the moon orbits Earth over ~29.5 days, we "
         "view that lit half from changing angles — from none (new) to all (full). "
         "Earth's shadow is only involved in eclipses, not phases.",
         _lesson("Phases vs Eclipses",
                 "Phases are geometry: sun-moon-Earth angles. A lunar eclipse (Earth's shadow "
                 "on the moon) needs perfect alignment and is rare; phases repeat monthly.",
                 "The moon never changes — your viewing angle does.")),
        ("fel_dd_010", "Why do muscles shake during a maximal-effort lift?",
         ["Motor units fire asynchronously as the nervous system recruits near its limit",
          "Blood sugar crashes instantly under load",
          "Muscle fibers snap and reconnect",
          "Oxygen is cut off to the arms"], [0], "sport_science", "hard",
         "Near maximal effort, the nervous system recruits nearly all motor units at high "
         "firing rates. Their activation is imperfectly synchronized, and fatigue makes "
         "firing irregular — visible as shaking.",
         _lesson("Motor Unit Recruitment",
                 "Strength gains in the first weeks of training are mostly neural: the brain "
                 "learns to recruit more units, faster and more synchronously, before "
                 "muscles grow at all.",
                 "Early strength is software updates; muscle growth is the hardware upgrade.")),
        ("fel_dd_011", "Why does ice float on water when most solids sink in their liquids?",
         ["Hydrogen bonding forms an open crystal lattice less dense than liquid water",
          "Ice contains trapped air bubbles",
          "Cold objects always rise",
          "Water pushes ice up magnetically"], [0], "science", "medium",
         "As water freezes, hydrogen bonds lock molecules into a hexagonal lattice with "
         "more empty space than the liquid — about 9% less dense, so it floats. This "
         "anomaly lets lakes freeze top-down and aquatic life survive winter.",
         _lesson("Water's Anomaly",
                 "Water is densest at 4°C, not at freezing. Lakes stratify: 4°C water sinks "
                 "to the bottom while ice caps the surface and insulates below.",
                 "One weird molecule property underwrites every frozen lake ecosystem on Earth.")),
        ("fel_dd_012", "Why is a diversified portfolio considered lower-risk than a single stock?",
         ["Uncorrelated losses offset: no single failure can sink the whole portfolio",
          "Diversified portfolios are government-insured",
          "More stocks always means more profit",
          "Brokers charge less for many holdings"], [0], "financial_literacy", "medium",
         "Diversification spreads exposure across assets whose prices don't move together. "
         "One company can go to zero; a broad basket effectively cannot, so the "
         "portfolio's variance falls without proportionally lowering expected return.",
         _lesson("Diversification",
                 "Risk has two parts: market risk (undiversifiable) and idiosyncratic risk "
                 "(company-specific). Diversification erases the second nearly for free — "
                 "the only free lunch in finance.",
                 "Never bet the season on one player — build a roster.")),
    ]
    for qid, prompt, options, ans, cat, diff, expl, lesson in deep:
        qs.append(_mk_question(qid, prompt, options, ans, "single", cat,
                               "explanation", diff, SRC, LIC,
                               ["deep_dive", "blitz"], expl, lesson))

    # Multi-select — exercises partial-credit scoring.
    multi = [
        ("fel_ms_001", "Select ALL macronutrients.",
         ["Protein", "Vitamin C", "Carbohydrates", "Fats", "Iron"], [0, 2, 3],
         "sport_science", "easy",
         "Protein, carbohydrates, and fats are macronutrients (needed in large amounts); "
         "vitamins and minerals are micronutrients."),
        ("fel_ms_002", "Select ALL planets with rings.",
         ["Jupiter", "Mars", "Saturn", "Uranus", "Neptune"], [0, 2, 3, 4],
         "science", "hard",
         "All four gas/ice giants have ring systems — Saturn's is simply the most visible."),
        ("fel_ms_003", "Select ALL sports played in the Summer Olympics (2024 program).",
         ["Skateboarding", "Ice hockey", "Surfing", "Curling", "Sport climbing"], [0, 2, 4],
         "sport_history", "medium",
         "Skateboarding, surfing, and sport climbing joined the Summer program in Tokyo "
         "2020; ice hockey and curling are Winter sports."),
        ("fel_ms_004", "Select ALL prime numbers.",
         ["21", "13", "27", "29", "33"], [1, 3],
         "mathematics", "medium",
         "13 and 29 are prime. 21=3x7, 27=3^3, 33=3x11."),
        ("fel_ms_005", "Select ALL fast-twitch dominant activities.",
         ["100m sprint", "Marathon", "Olympic weightlifting", "Channel swimming", "High jump"], [0, 2, 4],
         "sport_science", "medium",
         "Explosive, short-duration efforts rely on fast-twitch (Type II) fibers; "
         "endurance events rely on slow-twitch (Type I)."),
        ("fel_ms_006", "Select ALL renewable energy sources.",
         ["Solar", "Coal", "Wind", "Natural gas", "Hydroelectric"], [0, 2, 4],
         "science", "easy",
         "Solar, wind, and hydro replenish naturally; coal and natural gas are finite "
         "fossil fuels."),
    ]
    for qid, prompt, options, ans, cat, diff, expl in multi:
        qs.append(_mk_question(qid, prompt, options, ans, "multi", cat,
                               "analysis", diff, SRC, LIC, ["blitz"], expl))

    # Original singles — round out the blitz pool.
    singles = [
        ("fel_sg_001", "How many players from one team are on a volleyball court?",
         ["4", "5", "6", "7"], [2], "sport_history", "easy"),
        ("fel_sg_002", "Which unit measures electrical resistance?",
         ["Volt", "Ohm", "Watt", "Ampere"], [1], "science", "medium"),
        ("fel_sg_003", "What percentage of the human body is roughly water?",
         ["40%", "60%", "80%", "25%"], [1], "science", "easy"),
        ("fel_sg_004", "In golf, what is one stroke under par on a hole called?",
         ["Eagle", "Bogey", "Birdie", "Albatross"], [2], "sport_history", "easy"),
        ("fel_sg_005", "Which continent has the most countries?",
         ["Asia", "Europe", "Africa", "South America"], [2], "geography", "medium"),
        ("fel_sg_006", "What does APR stand for on a loan?",
         ["Annual Percentage Rate", "Average Payment Ratio", "Applied Principal Return",
          "Annual Payment Requirement"], [0], "financial_literacy", "easy"),
    ]
    for qid, prompt, options, ans, cat, diff in singles:
        qs.append(_mk_question(qid, prompt, options, ans, "single", cat,
                               "recall", diff, SRC, LIC, ["blitz"]))

    return qs


# ── Main ────────────────────────────────────────────────────────────────────

def content_hash(questions: list) -> str:
    canon = json.dumps(questions, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()[:16]


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed Brain Brawl MOCK_CONTENT JSON")
    parser.add_argument("--offline", action="store_true",
                        help="Skip OpenTDB fetch; write original questions only")
    args = parser.parse_args()

    originals = original_questions()
    fetched = [] if args.offline else fetch_opentdb()
    questions = originals + fetched
    # Stable order: originals first (they carry the deep-dive pool), then
    # fetched sorted by id so re-runs with identical content produce
    # byte-identical files.
    questions = originals + sorted(fetched, key=lambda q: q["id"])

    if not fetched and not args.offline:
        print("[warn] OpenTDB unreachable — output contains originals only "
              f"({len(originals)} questions). Re-run when online for the full set.",
              file=sys.stderr)

    doc = {
        "content_id": "brainbrawl_mock_content",
        "version": 1,
        "generated_by": "scripts/seed_mock_content.py",
        "question_count": len(questions),
        "content_hash": content_hash(questions),
        "sources": {
            "Open Trivia Database (opentdb.com)": {
                "license": "CC BY-SA 4.0",
                "url": "https://opentdb.com",
                "count": len(fetched),
            },
            "Final Evolution Lab original": {
                "license": "CC0-1.0",
                "count": len(originals),
            },
        },
        "questions": questions,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n",
                           encoding="utf-8")
    size_kb = OUTPUT_PATH.stat().st_size / 1024
    print(f"Wrote {len(questions)} questions ({len(fetched)} OpenTDB + "
          f"{len(originals)} original) -> {OUTPUT_PATH} ({size_kb:.0f} KB), "
          f"hash {doc['content_hash']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
