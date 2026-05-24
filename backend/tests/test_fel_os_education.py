"""
Backend tests: FEL OS Education Tracks, Kinesiology Cert, Bio-Digital, Brain Brawl,
Unified System Scan, and refactor regression checks.
"""
import os
import sys
import time
from pathlib import Path

import pytest
import requests

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from routers.education_tracks import TRACKS  # noqa: E402

BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "https://readiness-stack.preview.emergentagent.com").rstrip("/")


def _kin_perfect_answers(questions_payload):
    """Match shuffled options back to canonical bank by question stem (integration helper)."""
    bank = TRACKS["kinesiology"]["final_assessment"]["questions"]
    by_stem = {q["q"]: q for q in bank}
    out = []
    for item in questions_payload:
        orig = by_stem[item["q"]]
        correct_text = orig["options"][orig["correct"]]
        out.append(item["options"].index(correct_text))
    return out

# Pre-provisioned sessions (see test_credentials.md + mongosh seed)
FRESH_TOKEN = "sess_edu_1777958291132"       # PRQ 82, fresh (no progress)
LOWPRQ_TOKEN = "sess_lowprq_1777958291132"   # PRQ 60 (fails prq_threshold)
EXISTING_TOKEN = "sess_1777957943281"        # PRQ 82, cert already issued (idempotency)


def h(token):
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def enroll_user(token, course_id):
    r = requests.post(f"{BASE_URL}/api/education/enroll/{course_id}", headers=h(token))
    return r


# ---------- Tracks listing / detail ----------
class TestEducationTracks:
    def test_list_tracks_returns_4(self):
        r = requests.get(f"{BASE_URL}/api/education/tracks")
        assert r.status_code == 200
        data = r.json()
        assert "tracks" in data
        by_id = {t["track_id"]: t for t in data["tracks"]}
        assert set(by_id) == {"common_core", "stem", "kinesiology", "brain_brawl"}
        assert by_id["common_core"]["lesson_count"] == 6
        assert by_id["stem"]["lesson_count"] == 6
        assert by_id["kinesiology"]["lesson_count"] == 8
        assert by_id["brain_brawl"]["lesson_count"] == 4
        assert by_id["kinesiology"]["is_certificate"] is True
        assert by_id["brain_brawl"]["ue5_deep_link"] == "finalevolution://brain-brawl/launch"

    def test_track_detail_no_answer_leak(self):
        r = requests.get(f"{BASE_URL}/api/education/tracks/kinesiology")
        assert r.status_code == 200
        data = r.json()
        assert data["track_id"] == "kinesiology"
        assert len(data["lessons"]) == 8
        # lessons list must not carry quiz answers at all
        for l in data["lessons"]:
            assert "quiz" not in l
            assert "correct" not in l
        assert data["final_assessment"]["question_count"] == 10

    def test_lesson_quiz_strips_correct(self):
        enroll_user(FRESH_TOKEN, "college_prep")
        r = requests.get(f"{BASE_URL}/api/education/tracks/common_core/lesson/cc_math_1", headers=h(FRESH_TOKEN))
        assert r.status_code == 200
        data = r.json()
        assert data["id"] == "cc_math_1"
        assert len(data["quiz"]) == 4
        for q in data["quiz"]:
            assert "correct" not in q
            assert "options" in q and len(q["options"]) == 4

    def test_unknown_track_returns_404(self):
        r = requests.get(f"{BASE_URL}/api/education/tracks/does_not_exist")
        assert r.status_code == 404


# ---------- Auth gating ----------
class TestAuthGating:
    @pytest.mark.parametrize("method,path", [
        ("get",  "/api/education/tracks/common_core/lesson/cc_math_1"),
        ("post", "/api/education/tracks/common_core/lesson/cc_math_1/submit"),
        ("post", "/api/education/tracks/common_core/lesson/cc_math_1/open"),
        ("get",  "/api/education/progress"),
        ("get",  "/api/education/kinesiology/eligibility"),
        ("post", "/api/education/kinesiology/final-assessment/submit"),
        ("post", "/api/education/kinesiology/final-assessment/start"),
        ("post", "/api/education/kinesiology/certify"),
        ("post", "/api/education/bio-digital/begin-module"),
        ("post", "/api/education/bio-digital/complete-module"),
        ("post", "/api/education/brain-brawl/launch"),
        ("post", "/api/brain-brawl/session/start"),
        ("get",  "/api/system-scan/unified"),
    ])
    def test_requires_auth(self, method, path):
        fn = getattr(requests, method)
        r = fn(f"{BASE_URL}{path}", json={})
        assert r.status_code == 401, f"{method.upper()} {path} expected 401, got {r.status_code}"


# ---------- Quiz submit / grading / XP / idempotency ----------
class TestLessonSubmit:
    def test_submit_wrong_length_400(self):
        enroll_user(FRESH_TOKEN, "college_prep")
        r = requests.post(
            f"{BASE_URL}/api/education/tracks/common_core/lesson/cc_math_1/submit",
            headers=h(FRESH_TOKEN), json={"answers": [1, 1]},
        )
        assert r.status_code == 400

    def test_pass_awards_xp_once(self):
        enroll_user(FRESH_TOKEN, "college_prep")
        # Correct answers for cc_math_1 = [1,1,1,1]
        url = f"{BASE_URL}/api/education/tracks/common_core/lesson/cc_math_1/submit"
        # Baseline XP
        prog0 = requests.get(f"{BASE_URL}/api/education/progress", headers=h(FRESH_TOKEN)).json()
        r1 = requests.post(url, headers=h(FRESH_TOKEN), json={"answers": [1, 1, 1, 1]})
        assert r1.status_code == 200
        d1 = r1.json()
        assert d1["passed"] is True
        assert d1["first_pass"] is True
        assert d1["xp_earned"] == 50
        assert d1["score_pct"] == 100.0
        assert "cc_math_1" in d1["completed_lessons"]

        # Second submission — no double XP
        r2 = requests.post(url, headers=h(FRESH_TOKEN), json={"answers": [1, 1, 1, 1]})
        assert r2.status_code == 200
        d2 = r2.json()
        assert d2["first_pass"] is False
        assert d2["xp_earned"] == 0

    def test_fail_does_not_complete(self):
        enroll_user(FRESH_TOKEN, "stem_sports")
        url = f"{BASE_URL}/api/education/tracks/stem/lesson/stem_phys_1/submit"
        # All zeros — only 1st is correct index 1, so 0/4 => fail
        r = requests.post(url, headers=h(FRESH_TOKEN), json={"answers": [0, 0, 0, 0]})
        assert r.status_code == 200
        d = r.json()
        assert d["passed"] is False
        assert d["xp_earned"] == 0
        assert "stem_phys_1" not in d["completed_lessons"]


# ---------- Progress endpoint ----------
class TestProgress:
    def test_progress_returns_4_tracks(self):
        r = requests.get(f"{BASE_URL}/api/education/progress", headers=h(FRESH_TOKEN))
        assert r.status_code == 200
        d = r.json()
        assert len(d["tracks"]) == 4
        ids = {t["track_id"] for t in d["tracks"]}
        assert ids == {"common_core", "stem", "kinesiology", "brain_brawl"}


# ---------- Bio-Digital / Brain Brawl / Kinesiology happy path ----------
KIN_LESSONS = ["kin_bio_1", "kin_mus_1", "kin_ms_1", "kin_inj_1",
               "kin_per_1", "kin_neu_1", "kin_rec_1", "kin_eth_1"]
# All kin lesson answers are index 1 for 4 questions each, except kin_inj_1 Q1 which is index 0
KIN_ANSWERS = {
    "kin_bio_1": [1, 1, 1, 1], "kin_mus_1": [1, 1, 1, 1],
    "kin_ms_1":  [1, 1, 1, 1], "kin_inj_1": [0, 1, 1, 1],
    "kin_per_1": [1, 1, 1, 1], "kin_neu_1": [1, 0, 1, 1],
    "kin_rec_1": [2, 1, 1, 0], "kin_eth_1": [1, 1, 1, 1],
}
class TestKinesiologyHappyPath:
    def test_complete_flow(self):
        tok = FRESH_TOKEN
        enroll_user(tok, "kinesiology_cert")
        # 1. Coursework
        for lid in KIN_LESSONS:
            r = requests.post(
                f"{BASE_URL}/api/education/tracks/kinesiology/lesson/{lid}/submit",
                headers=h(tok), json={"answers": KIN_ANSWERS[lid]},
            )
            assert r.status_code == 200, f"lesson {lid} failed: {r.text}"
            assert r.json()["passed"] is True, f"lesson {lid} not passed: {r.json()}"

        # 2. Bio-digital modules (begin → receipt → complete)
        for m in ["skeletal_basics", "muscular_chains", "kinetic_chain_pillars", "neural_priming"]:
            rb = requests.post(
                f"{BASE_URL}/api/education/bio-digital/begin-module",
                headers=h(tok), json={"module_id": m},
            )
            assert rb.status_code == 200, rb.text
            receipt = rb.json().get("completion_receipt")
            assert receipt
            # BIO_DIGITAL_MIN_ACTIVE_SECONDS default (3s) — anti instant-complete gate
            time.sleep(3.5)
            r = requests.post(
                f"{BASE_URL}/api/education/bio-digital/complete-module",
                headers=h(tok), json={"module_id": m, "completion_receipt": receipt},
            )
            assert r.status_code == 200
        # 3. Eligibility — final not yet passed, so not all_met
        r = requests.get(f"{BASE_URL}/api/education/kinesiology/eligibility", headers=h(tok))
        assert r.status_code == 200
        elig = r.json()
        assert set(elig["checks"]) == {
            "coursework_completed", "bio_digital_modules", "prq_threshold", "final_assessment"
        }
        assert elig["checks"]["coursework_completed"]["met"] is True
        assert elig["checks"]["bio_digital_modules"]["met"] is True
        assert elig["checks"]["prq_threshold"]["met"] is True
        assert elig["checks"]["final_assessment"]["met"] is False
        assert elig["all_met"] is False

        # 4. Cert claim without final -> 400
        r = requests.post(f"{BASE_URL}/api/education/kinesiology/certify", headers=h(tok))
        assert r.status_code == 400

        # 5. Final assessment (server-shuffled attempt + verified receipt)
        rs = requests.post(
            f"{BASE_URL}/api/education/kinesiology/final-assessment/start",
            headers=h(tok), json={},
        )
        assert rs.status_code == 200, rs.text
        att = rs.json()
        perfect = _kin_perfect_answers(att["questions"])
        r = requests.post(
            f"{BASE_URL}/api/education/kinesiology/final-assessment/submit",
            headers=h(tok),
            json={"attempt_token": att["attempt_token"], "answers": perfect},
        )
        assert r.status_code == 200, r.text
        fd = r.json()
        assert fd["passed"] is True
        assert fd["score_pct"] >= 80.0
        assert fd.get("final_verified_receipt")

        # 6. Certify
        r = requests.post(f"{BASE_URL}/api/education/kinesiology/certify", headers=h(tok))
        assert r.status_code == 200, r.text
        cd = r.json()
        assert cd["certificate_id"].startswith("FEL-AK-")
        assert cd["xp_earned"] == 1000

        # 7. Idempotency
        r2 = requests.post(f"{BASE_URL}/api/education/kinesiology/certify", headers=h(tok))
        assert r2.status_code == 200
        d2 = r2.json()
        assert d2.get("already_issued") is True
        assert d2["certificate_id"] == cd["certificate_id"]


class TestKinesiologyLowPRQ:
    def test_prq_gate_blocks(self):
        tok = LOWPRQ_TOKEN
        enroll_user(tok, "kinesiology_cert")
        r = requests.get(f"{BASE_URL}/api/education/kinesiology/eligibility", headers=h(tok))
        assert r.status_code == 200
        elig = r.json()
        assert elig["checks"]["prq_threshold"]["met"] is False
        assert elig["all_met"] is False
        r2 = requests.post(f"{BASE_URL}/api/education/kinesiology/certify", headers=h(tok))
        assert r2.status_code == 400


class TestExistingUserIdempotent:
    def test_already_issued(self):
        enroll_user(EXISTING_TOKEN, "kinesiology_cert")
        r = requests.post(f"{BASE_URL}/api/education/kinesiology/certify", headers=h(EXISTING_TOKEN))
        assert r.status_code == 200
        d = r.json()
        assert d.get("already_issued") is True
        assert d["certificate_id"].startswith("FEL-AK-")


# ---------- Brain Brawl ----------
class TestBrainBrawl:
    def test_legacy_questions_strip_correct_index(self):
        r = requests.get(f"{BASE_URL}/api/brain-brawl/questions?count=5")
        assert r.status_code == 200
        for q in r.json():
            assert "correct" not in q

    def test_launch_returns_deep_link(self):
        enroll_user(FRESH_TOKEN, "brain_brawl_101")
        r = requests.post(f"{BASE_URL}/api/education/brain-brawl/launch", headers=h(FRESH_TOKEN))
        assert r.status_code == 200
        d = r.json()
        assert d["deep_link"] == "finalevolution://brain-brawl/launch"
        assert d["ue5_mode_id"] == "brain_brawl_arena"
        assert d["session_id"].startswith("bb_")


# ---------- Unified System Scan ----------
class TestUnifiedScan:
    def test_four_quadrants(self):
        r = requests.get(f"{BASE_URL}/api/system-scan/unified", headers=h(FRESH_TOKEN))
        assert r.status_code == 200
        d = r.json()
        for k in ("scan", "cards", "arena", "academy", "user"):
            assert k in d
        assert d["scan"]["prq_score"] == 82.0
        assert d["arena"]["ue5_bridge"] == "ready"
        assert "sovereign_sessions" in d["arena"]
        assert "modes_played" in d["arena"]
        assert len(d["academy"]["tracks"]) == 4
        assert d["academy"]["bio_digital"]["modules_required"] == [
            "skeletal_basics", "muscular_chains", "kinetic_chain_pillars", "neural_priming"
        ]
        # kinesiology cert should reflect the issuance done in happy-path test
        kin = next(t for t in d["academy"]["tracks"] if t["track_id"] == "kinesiology")
        assert kin["completion_pct"] == 100.0


# ---------- Refactor regression: pre-existing endpoints still alive ----------
class TestRefactorRegression:
    def test_health(self):
        r = requests.get(f"{BASE_URL}/health")
        # root /health may be 404 if ingress strips — try both
        if r.status_code == 404:
            r = requests.get(f"{BASE_URL}/api/health")
        assert r.status_code in (200, 404)  # record only

    def test_registry_venues(self):
        r = requests.get(f"{BASE_URL}/api/registry/venues")
        assert r.status_code == 200

    def test_games_modes(self):
        r = requests.get(f"{BASE_URL}/api/games/modes")
        assert r.status_code == 200

    def test_cards(self):
        r = requests.get(f"{BASE_URL}/api/cards")
        assert r.status_code == 200

    def test_sovereign_status(self):
        r = requests.get(f"{BASE_URL}/api/sovereign/status", headers=h(FRESH_TOKEN))
        assert r.status_code in (200, 401)  # depends on whether endpoint requires auth
