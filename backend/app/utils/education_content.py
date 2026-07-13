"""Static education track content (ported from legacy backend/routers/education_tracks.py).

Content is first-party seed data: 4 tracks (common_core, stem, kinesiology,
brain_brawl) with auto-graded quizzes and the kinesiology final assessment.
Pure helpers here have no DB or framework dependencies.
"""
from __future__ import annotations

import random
from typing import Any, Dict, List

PASS_THRESHOLD = 0.75
CERT_FINAL_THRESHOLD = 0.80
KINESIOLOGY_PRQ_GATE = 80.0
BIO_DIGITAL_REQUIRED_MODULES = [
    "skeletal_basics", "muscular_chains", "kinetic_chain_pillars", "neural_priming"
]
# Only these IDs may ever be marked complete (blocks arbitrary client IDs).
BIO_DIGITAL_ALLOWED_MODULES = frozenset(BIO_DIGITAL_REQUIRED_MODULES)
BIO_DIGITAL_RECEIPT_TTL_HOURS = 4
KIN_FINAL_COOLDOWN_SEC = 300
KIN_FINAL_SESSION_TTL_HOURS = 2

# ============================================================
# SEED CONTENT — track lessons + quizzes
# ============================================================

TRACKS: Dict[str, Dict[str, Any]] = {
    "common_core": {
        "track_id": "common_core",
        "title": "Common Core Pathway",
        "subtitle": "Athlete Academic Readiness — ELA · Math · Science · Civics",
        "description": "College-prep grounding aligned to NCAA eligibility. Scholarship-grade reading, math reasoning, lab science, and U.S. civics for the next-gen athlete.",
        "category": "academic",
        "level": "9–12",
        "icon": "BookOpen",
        "color": "emerald",
        "lessons": [
            {
                "id": "cc_ela_1", "title": "Argumentative Reading & Rhetoric",
                "summary": "Decode authorial intent, evidence, and counter-claim construction in non-fiction sport journalism.",
                "duration_min": 22,
                "minimum_study_seconds": 45,
                "content_blocks": [
                    {"type": "text", "heading": "Why this matters", "body": "Scholarship committees and NCAA pathways reward claims backed by evidence—not vibes. Sport journalism is a practical training ground for spotting weak reasoning."},
                    {"type": "bullets", "heading": "Work through", "items": ["Underline the author’s central claim.", "Circle evidence vs. opinion.", "Note where a counter-claim would strengthen the argument."]},
                ],
                "resources": [
                    {"label": "NCAA academic readiness", "url": "https://www.ncaa.org/sports/2014/11/10/academic_standards.aspx"},
                ],
                "quiz": [
                    {"q": "A claim supported only by a single anecdote is best described as:", "options": ["Empirical", "Anecdotal", "Statistical", "Axiomatic"], "correct": 1},
                    {"q": "An author's purpose to refute a prior idea is most often signaled by:", "options": ["However / Conversely", "In addition", "For example", "First"], "correct": 0},
                    {"q": "Which is strongest evidence in a scholarship essay?", "options": ["Personal opinion", "Cited longitudinal study", "Single quote", "Hashtag trend"], "correct": 1},
                    {"q": "A counter-claim should be:", "options": ["Ignored", "Acknowledged & rebutted", "Mocked", "Repeated verbatim"], "correct": 1},
                ],
            },
            {
                "id": "cc_math_1", "title": "Algebraic Reasoning for Performance",
                "summary": "Linear models, rates of change, and slope as 'velocity of progress'. Modeling jump-height growth over weeks.",
                "duration_min": 25,
                "quiz": [
                    {"q": "If your vertical jump grows 0.4 in/week from 24 in, what is it at week 8?", "options": ["27.0 in", "27.2 in", "26.8 in", "28.0 in"], "correct": 1},
                    {"q": "Slope in y = mx + b represents:", "options": ["Y-intercept", "Rate of change", "Constant", "Domain"], "correct": 1},
                    {"q": "Solve: 3(x − 4) = 18", "options": ["x = 6", "x = 10", "x = 4", "x = 14"], "correct": 1},
                    {"q": "A function is best described by:", "options": ["One input → many outputs", "One input → one output", "Random map", "No mapping"], "correct": 1},
                ],
            },
            {
                "id": "cc_sci_1", "title": "Scientific Method in Training",
                "summary": "Hypothesis, control group, p-value intuition, and why anecdote ≠ data.",
                "duration_min": 18,
                "quiz": [
                    {"q": "Which is a testable hypothesis?", "options": ["Athletes are better", "Plyometrics increase vertical by ≥2 in over 6 weeks", "Sports are fun", "Basketball wins"], "correct": 1},
                    {"q": "A control group is used to:", "options": ["Win the study", "Isolate the variable", "Pad the numbers", "Replace data"], "correct": 1},
                    {"q": "Sample size matters because:", "options": ["Larger is more impressive", "Reduces sampling error", "Gets more sponsors", "Looks scientific"], "correct": 1},
                    {"q": "Correlation implies:", "options": ["Causation", "Association — not necessarily causation", "Random noise", "Nothing"], "correct": 1},
                ],
            },
            {
                "id": "cc_civ_1", "title": "U.S. Civics & NCAA Eligibility",
                "summary": "Constitutional rights, NCAA D1/D2 academic baselines, and contract literacy for NIL athletes.",
                "duration_min": 20,
                "quiz": [
                    {"q": "Which amendment covers free speech?", "options": ["1st", "2nd", "5th", "14th"], "correct": 0},
                    {"q": "Minimum NCAA D1 core GPA (sliding scale baseline):", "options": ["1.8", "2.3", "2.7", "3.5"], "correct": 1},
                    {"q": "NIL stands for:", "options": ["National Indoor League", "Name, Image, Likeness", "New Interscholastic League", "None"], "correct": 1},
                    {"q": "A binding contract requires:", "options": ["Just signature", "Offer + acceptance + consideration", "A logo", "Verbal nod only"], "correct": 1},
                ],
            },
            {
                "id": "cc_ess_1", "title": "Scholarship Essay Architecture",
                "summary": "Hook → thesis → body (claim, evidence, warrant) → reflection → call to action.",
                "duration_min": 24,
                "quiz": [
                    {"q": "Best opening for a scholarship essay:", "options": ["I think...", "Concrete sensory scene", "Definition from dictionary", "Sport stats only"], "correct": 1},
                    {"q": "A thesis should be:", "options": ["Vague", "Specific & arguable", "A question", "A quote"], "correct": 1},
                    {"q": "Reflection adds:", "options": ["Word count", "Insight & growth", "Filler", "Apologies"], "correct": 1},
                    {"q": "Active voice is preferred because:", "options": ["It's longer", "It's direct & accountable", "It's poetic", "It's required"], "correct": 1},
                ],
            },
            {
                "id": "cc_test_1", "title": "Standardized Test Strategy",
                "summary": "SAT/ACT pacing, elimination, and reading anchors. Test-day cognitive primer.",
                "duration_min": 22,
                "quiz": [
                    {"q": "On SAT Reading, you should:", "options": ["Read all then answer", "Anchor question, scan passage", "Skip every 3rd", "Guess all"], "correct": 1},
                    {"q": "If unsure, eliminate:", "options": ["Best 2", "Worst 2 first", "Random", "All"], "correct": 1},
                    {"q": "Time per ACT Math question (avg):", "options": ["30 sec", "1 min", "2 min", "5 min"], "correct": 1},
                    {"q": "Best night-before strategy:", "options": ["Cram all night", "Light review + sleep ≥7h", "Caffeine binge", "Skip breakfast"], "correct": 1},
                ],
            },
        ],
    },

    "stem": {
        "track_id": "stem",
        "title": "STEM in Sports Science",
        "subtitle": "Physics · Analytics · Nutrition · Sports Tech",
        "description": "Quantitative principles of human performance — from kinematics to data pipelines and applied nutrition.",
        "category": "stem",
        "level": "Intermediate",
        "icon": "Atom",
        "color": "cyan",
        "lessons": [
            {
                "id": "stem_phys_1", "title": "Kinematics of the Vertical Jump",
                "summary": "Impulse-momentum, hang time, and why takeoff velocity > arm swing.",
                "duration_min": 20,
                "quiz": [
                    {"q": "Hang time of a 36-in vertical (≈0.91m): closest to", "options": ["0.4 s", "0.86 s", "1.4 s", "2.0 s"], "correct": 1},
                    {"q": "Impulse equals:", "options": ["F·d", "F·t", "m·a", "P·V"], "correct": 1},
                    {"q": "Greater takeoff velocity primarily comes from:", "options": ["Arm swing", "Ground reaction force × time", "Shouting", "Pre-jump hop"], "correct": 1},
                    {"q": "g (gravity) ≈", "options": ["5.8 m/s²", "9.8 m/s²", "11.2 m/s²", "32 m/s²"], "correct": 1},
                ],
            },
            {
                "id": "stem_an_1", "title": "Sports Analytics 101",
                "summary": "Possessions, true shooting %, and signal vs. noise in small samples.",
                "duration_min": 22,
                "quiz": [
                    {"q": "True Shooting % accounts for:", "options": ["FG only", "FG + 3PT + FT efficiency", "Steals", "Assists"], "correct": 1},
                    {"q": "Per-100 possessions normalizes:", "options": ["Player size", "Pace", "Salary", "Team logos"], "correct": 1},
                    {"q": "Small sample sizes are prone to:", "options": ["Truth", "Variance/noise", "Bias-free signal", "Always wrong"], "correct": 1},
                    {"q": "Plus/Minus is best paired with:", "options": ["Nothing", "On/Off splits & lineup data", "Highlight reels", "Twitter polls"], "correct": 1},
                ],
            },
            {
                "id": "stem_nut_1", "title": "Sports Nutrition — Macros & Timing",
                "summary": "Protein synthesis windows, carb timing for glycogen, and hydration math.",
                "duration_min": 18,
                "quiz": [
                    {"q": "Daily protein for hypertrophy (per kg BW):", "options": ["0.4–0.6 g", "1.6–2.2 g", "3.5–4.5 g", "6+ g"], "correct": 1},
                    {"q": "Post-training carbs replenish:", "options": ["Hemoglobin", "Glycogen", "Calcium", "Cortisol"], "correct": 1},
                    {"q": "Mild dehydration (~2% BW) reduces performance by ≈", "options": ["0%", "10–20%", "50%", "Improves it"], "correct": 1},
                    {"q": "Best pre-game meal timing:", "options": ["5 min before", "3–4 hr before", "Right at tipoff", "Skip"], "correct": 1},
                ],
            },
            {
                "id": "stem_tech_1", "title": "Wearables & Telemetry Pipelines",
                "summary": "IMU, GPS, optical-tracking — and how they reach FEL's Vault Hub.",
                "duration_min": 20,
                "quiz": [
                    {"q": "IMU stands for:", "options": ["Inertial Measurement Unit", "Internal Motion Util", "Indoor Mapping Util", "Internet Move Unit"], "correct": 0},
                    {"q": "GPS error in dense arenas is best mitigated by:", "options": ["Higher gain antenna", "UWB / optical fusion", "Slower play", "Bigger satellites"], "correct": 1},
                    {"q": "Telemetry frames in FEL stream over:", "options": ["FTP", "WebSocket", "Bluetooth print", "USB tether"], "correct": 1},
                    {"q": "Sample rate for vertical-jump capture should be at least:", "options": ["1 Hz", "30 Hz", "200+ Hz", "Doesn't matter"], "correct": 2},
                ],
            },
            {
                "id": "stem_data_1", "title": "Data Hygiene for Athletes",
                "summary": "Outliers, normalization, and personal-data privacy.",
                "duration_min": 18,
                "quiz": [
                    {"q": "An outlier should usually be:", "options": ["Deleted silently", "Investigated, not erased", "Doubled", "Hidden"], "correct": 1},
                    {"q": "Z-score normalization shifts data to:", "options": ["mean=0, sd=1", "mean=1, sd=0", "min=0, max=100", "median=0"], "correct": 0},
                    {"q": "Vault data means:", "options": ["Cloud only", "Athlete-owned & local-first", "Public domain", "Sold to ads"], "correct": 1},
                    {"q": "PII includes:", "options": ["Score totals", "Email + biometric ID", "Team logo", "Game time"], "correct": 1},
                ],
            },
            {
                "id": "stem_eng_1", "title": "Engineering the Game Engine",
                "summary": "How UE5 ticks, frame budgets, and why 90 FPS is the integrity threshold.",
                "duration_min": 20,
                "quiz": [
                    {"q": "UE5 tick refers to:", "options": ["Audio cue", "Per-frame update", "Network only", "Asset import"], "correct": 1},
                    {"q": "Frame budget at 90 FPS ≈", "options": ["33 ms", "16.6 ms", "11.1 ms", "5 ms"], "correct": 2},
                    {"q": "Nanite primarily optimizes:", "options": ["Audio", "Geometry detail streaming", "Net code", "AI"], "correct": 1},
                    {"q": "Lumen handles:", "options": ["Lighting/GI", "Physics", "Save files", "Input"], "correct": 0},
                ],
            },
        ],
    },

    "kinesiology": {
        "track_id": "kinesiology",
        "title": "Applied Kinesiology Certificate",
        "subtitle": "Bio-Digital Mastery · Movement · Injury Prevention · Performance",
        "description": "FEL's flagship certification. Pairs the Bio-Digital Anatomy overlays with periodized programming and clinical-grade movement screens. PRQ ≥ 80 + final assessment ≥ 80% required.",
        "category": "certificate",
        "level": "Advanced",
        "icon": "Award",
        "color": "amber",
        "is_certificate": True,
        "lessons": [
            {
                "id": "kin_bio_1", "title": "Skeletal Basics & Joint Architecture",
                "summary": "Synovial joint classes, range of motion, and force transmission through bone.",
                "duration_min": 22,
                "quiz": [
                    {"q": "Hinge joint example:", "options": ["Hip", "Elbow", "Shoulder", "Wrist"], "correct": 1},
                    {"q": "Cancellous bone is:", "options": ["Solid cortex", "Spongy trabecular", "Cartilage", "Tendon"], "correct": 1},
                    {"q": "Synovial fluid:", "options": ["Compresses bone", "Lubricates joint", "Builds muscle", "Breaks ligament"], "correct": 1},
                    {"q": "ROM stands for:", "options": ["Rate of Motion", "Range of Motion", "Roll-out method", "Rotator order"], "correct": 1},
                ],
            },
            {
                "id": "kin_mus_1", "title": "Muscular Chains & Force Production",
                "summary": "Posterior chain, anterior chain, and how the kinetic sequence delivers a dunk.",
                "duration_min": 24,
                "quiz": [
                    {"q": "Posterior chain primarily includes:", "options": ["Quads, abs", "Glutes, hams, erectors", "Pecs, biceps", "Forearms"], "correct": 1},
                    {"q": "A muscle's prime mover is the:", "options": ["Antagonist", "Agonist", "Synergist", "Stabilizer"], "correct": 1},
                    {"q": "Type II fibers are best for:", "options": ["Endurance", "Power/speed", "Posture", "Digestion"], "correct": 1},
                    {"q": "Eccentric contractions:", "options": ["Shorten", "Lengthen under load", "Stay same", "No tension"], "correct": 1},
                ],
            },
            {
                "id": "kin_ms_1", "title": "Movement Screens — FMS & Beyond",
                "summary": "Functional Movement Screen scoring, asymmetries, and red flags.",
                "duration_min": 22,
                "quiz": [
                    {"q": "Asymmetry between sides ≥ 1 point flags:", "options": ["Genius", "Risk", "Strength", "Skill"], "correct": 1},
                    {"q": "Deep squat tests:", "options": ["Just hips", "Total-body mobility & control", "Cardio", "Reflex"], "correct": 1},
                    {"q": "An overhead reach reveals:", "options": ["Hand size", "Thoracic mobility", "Foot arch", "BP"], "correct": 1},
                    {"q": "FMS score 0 means:", "options": ["Perfect", "Pain present — refer out", "Average", "Recovery"], "correct": 1},
                ],
            },
            {
                "id": "kin_inj_1", "title": "Injury Prevention — Knee, Ankle, Shoulder",
                "summary": "ACL risk factors, ankle-mobility ladder, scapular control. Load management 101.",
                "duration_min": 24,
                "quiz": [
                    {"q": "ACL risk rises with:", "options": ["Knee valgus on landing", "Triple flexion", "Symmetric squat", "Glute strength"], "correct": 0},
                    {"q": "Ankle mobility limits:", "options": ["Wrist flexion", "Squat depth & deceleration", "Vision", "VO2"], "correct": 1},
                    {"q": "Acute:Chronic workload ratio safe band:", "options": ["≥2.0", "0.8–1.3", "<0.5", "Doesn't matter"], "correct": 1},
                    {"q": "Scapular control protects:", "options": ["Knee", "Shoulder/rotator cuff", "Liver", "Calf"], "correct": 1},
                ],
            },
            {
                "id": "kin_per_1", "title": "Periodization — Building a Microcycle",
                "summary": "Linear vs. block, deload weeks, and sequencing strength + plyometrics.",
                "duration_min": 22,
                "quiz": [
                    {"q": "A deload week typically reduces:", "options": ["Sleep", "Volume by ~40–50%", "Calories", "Fluids"], "correct": 1},
                    {"q": "Block periodization stacks:", "options": ["Random sessions", "Concentrated phases", "All maxes", "Cardio only"], "correct": 1},
                    {"q": "CNS-heavy work is best:", "options": ["At week-end", "Early in microcycle when fresh", "After max sets", "Skipped"], "correct": 1},
                    {"q": "Tapering before competition:", "options": ["Adds volume", "Reduces volume, holds intensity", "Removes intensity", "Cuts sleep"], "correct": 1},
                ],
            },
            {
                "id": "kin_neu_1", "title": "Neural Priming & Reaction Time",
                "summary": "How CNS warm-ups elevate motor-unit recruitment without fatigue.",
                "duration_min": 20,
                "quiz": [
                    {"q": "PAP stands for:", "options": ["Pre-Activation Plyo", "Post-Activation Potentiation", "Power Amp Phase", "Pre-Aerobic Push"], "correct": 1},
                    {"q": "Optimal reactive priming volume:", "options": ["1 set, low intensity", "Heavy fatigue sets", "Long jog", "Static stretch only"], "correct": 0},
                    {"q": "Reaction time improves with:", "options": ["Random repetition only", "Specificity + sleep", "Caffeine alone", "Heavy deload"], "correct": 1},
                    {"q": "Motor units recruit:", "options": ["Largest first", "Smallest → largest (size principle)", "Random", "Only when tired"], "correct": 1},
                ],
            },
            {
                "id": "kin_rec_1", "title": "Recovery — Sleep, HRV & Cold/Heat",
                "summary": "Why sleep is the #1 anabolic, and what HRV trends actually mean.",
                "duration_min": 20,
                "quiz": [
                    {"q": "Adolescent athletes need sleep ≈", "options": ["4 h", "6 h", "8–10 h", "12+ h"], "correct": 2},
                    {"q": "HRV typically rises with:", "options": ["Overtraining", "Recovery & parasympathetic tone", "Caffeine binge", "Dehydration"], "correct": 1},
                    {"q": "Cold immersion post-strength may blunt:", "options": ["Aerobic gain", "Hypertrophy adaptations", "Tendon healing", "Mood"], "correct": 1},
                    {"q": "Sauna heat acclimation can boost:", "options": ["Plasma volume & endurance", "Muscle size only", "Joint pain", "Reaction time only"], "correct": 0},
                ],
            },
            {
                "id": "kin_eth_1", "title": "Ethics & Scope of Practice",
                "summary": "What kinesiology can claim — and where to refer (PT, MD, RD, sport psych).",
                "duration_min": 18,
                "quiz": [
                    {"q": "If pain is sharp & localized, refer to:", "options": ["Strength coach", "Licensed PT/MD", "Marketing", "Yourself only"], "correct": 1},
                    {"q": "Diagnose injury:", "options": ["Always", "Only licensed clinicians", "DM your friends", "Use AI alone"], "correct": 1},
                    {"q": "Best practice with minors:", "options": ["No consent needed", "Informed parental consent", "Just verbal nod", "Skip ethics"], "correct": 1},
                    {"q": "Confidential health data should be:", "options": ["Posted publicly", "Stored securely; need-to-know", "Sold", "Deleted always"], "correct": 1},
                ],
            },
        ],
        "final_assessment": {
            "id": "kin_final",
            "title": "Applied Kinesiology — Final Assessment",
            "questions": [
                {"q": "Knee valgus on landing increases risk to:", "options": ["Wrist", "ACL", "Liver", "Earlobe"], "correct": 1},
                {"q": "Best post-training nutrient stack:", "options": ["Pure fat", "Protein + carbs", "Plain water only", "Sugar bomb"], "correct": 1},
                {"q": "Periodization deload reduces:", "options": ["Sleep", "Volume ~40–50%", "Hydration", "Sport"], "correct": 1},
                {"q": "Sample rate ≥200 Hz is needed for:", "options": ["Sleep tracking", "Jump-takeoff capture", "Step count", "Steps/day"], "correct": 1},
                {"q": "FMS score of 0 indicates:", "options": ["Elite", "Pain — refer out", "Recovery", "Average"], "correct": 1},
                {"q": "Vault data means athlete data is:", "options": ["Sold", "Athlete-owned, local-first", "Public", "Lost"], "correct": 1},
                {"q": "Type II muscle fibers favor:", "options": ["Marathon", "Power & speed", "Posture", "Digestion"], "correct": 1},
                {"q": "Acute:Chronic workload safe band:", "options": ["0.5–0.7", "0.8–1.3", "1.5–2.5", "≥3.0"], "correct": 1},
                {"q": "Adolescent athlete sleep target:", "options": ["6 h", "8–10 h", "12+ h", "4 h"], "correct": 1},
                {"q": "Scope of practice — diagnose injury:", "options": ["Anyone", "Licensed clinician only", "AI", "Coach"], "correct": 1},
            ],
        },
    },

    "brain_brawl": {
        "track_id": "brain_brawl",
        "title": "Brain Brawl Arena",
        "subtitle": "Cognitive Combat — Reaction · Pattern · Decision",
        "description": "Cognitive arena played in the FEL UE5 binary. The web layer exposes briefings, cooldowns, and PRQ feedback. Live gameplay launches via finalevolution:// deep link.",
        "category": "cognitive",
        "level": "Adaptive",
        "icon": "Brain",
        "color": "fuchsia",
        "ue5_deep_link": "finalevolution://brain-brawl/launch",
        "ue5_mode_id": "brain_brawl_arena",
        "lessons": [
            {
                "id": "bb_brief_1", "title": "Combat Briefing — Reaction Drills",
                "summary": "Stimulus-response chains under load. Light-board, choice-RT, and Go/No-Go.",
                "duration_min": 8,
                "quiz": [
                    {"q": "Choice RT is slower than simple RT because:", "options": ["More decision processing", "Lights are dimmer", "Hand is far", "Random"], "correct": 0},
                    {"q": "Go/No-Go trains:", "options": ["Inhibition control", "Vertical jump", "Hydration", "Vision color"], "correct": 0},
                    {"q": "Better RT correlates with:", "options": ["Sleep & priming", "Caffeine ONLY", "Random luck", "Crowd size"], "correct": 0},
                ],
            },
            {
                "id": "bb_brief_2", "title": "Combat Briefing — Pattern Recognition",
                "summary": "Detect motion sequences, screen reads, and offensive trees in 250–400 ms.",
                "duration_min": 8,
                "quiz": [
                    {"q": "Pattern recognition relies on:", "options": ["Long-term memory chunks", "Random guess", "Closed eyes", "Single rep"], "correct": 0},
                    {"q": "Elite read times trend toward:", "options": ["1.5 s", "0.25–0.4 s", "5 s", "10 s"], "correct": 1},
                    {"q": "Best practice for chunking plays:", "options": ["Spaced repetition", "Cram the night before", "Skip film", "Memorize colors"], "correct": 0},
                ],
            },
            {
                "id": "bb_brief_3", "title": "Combat Briefing — Decision Under Load",
                "summary": "Heart-rate spikes degrade frontal-cortex bandwidth. Practice selective attention under fatigue.",
                "duration_min": 8,
                "quiz": [
                    {"q": "Cognitive bandwidth under HR>180:", "options": ["Increases", "Narrows", "Stays same", "Goes infinite"], "correct": 1},
                    {"q": "Selective attention filters:", "options": ["All input", "Irrelevant cues", "Coach voice only", "Music only"], "correct": 1},
                    {"q": "Cooling down before decisions helps because:", "options": ["Lowers HR & re-opens cortex", "Hydrates spine", "Lengthens muscle", "Loud crowd"], "correct": 0},
                ],
            },
            {
                "id": "bb_brief_4", "title": "Combat Briefing — Stress Inoculation",
                "summary": "Controlled exposure to crowd noise, score deficit, and shot-clock pressure.",
                "duration_min": 8,
                "quiz": [
                    {"q": "Stress inoculation is:", "options": ["Avoiding stress", "Graded exposure to build tolerance", "Single max test", "Caffeine only"], "correct": 1},
                    {"q": "A pre-shot routine reduces:", "options": ["Decision noise", "Audience size", "Score", "Sleep"], "correct": 0},
                    {"q": "Box breathing pattern:", "options": ["4-4-4-4", "8-1-8-1", "Random", "10-0-10-0"], "correct": 0},
                ],
            },
        ],
    },
}


def _track_or_404(track_id: str) -> Dict[str, Any]:
    if track_id not in TRACKS:
        raise HTTPException(status_code=404, detail=f"Track '{track_id}' not found")
    return TRACKS[track_id]


def _public_track_summary(track: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "track_id": track["track_id"],
        "title": track["title"],
        "subtitle": track["subtitle"],
        "description": track["description"],
        "category": track["category"],
        "level": track["level"],
        "icon": track["icon"],
        "color": track["color"],
        "lesson_count": len(track["lessons"]),
        "is_certificate": track.get("is_certificate", False),
        "ue5_deep_link": track.get("ue5_deep_link"),
    }


def _strip_correct(quiz: List[Dict]) -> List[Dict]:
    return [{"q": q["q"], "options": q["options"]} for q in quiz]


def _shuffle_kin_final_questions(fa_questions: List[Dict[str, Any]]):
    """Randomize question order and per-question option order (EDU-08)."""
    order = list(range(len(fa_questions)))
    random.shuffle(order)
    display: List[Dict[str, Any]] = []
    meta: List[Dict[str, Any]] = []
    for slot, orig_i in enumerate(order):
        q = fa_questions[orig_i]
        pair = list(enumerate(q["options"]))
        random.shuffle(pair)
        opts = [t[1] for t in pair]
        correct_new = next(nj for nj, (oj, _) in enumerate(pair) if oj == q["correct"])
        display.append({"index": slot, "q": q["q"], "options": opts})
        meta.append({"correct_index": correct_new})
    return display, meta
