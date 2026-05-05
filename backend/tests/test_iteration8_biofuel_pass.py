"""
Iteration 8 backend tests:
- DB indexes (education_progress unique compound, brain_brawl_launches TTL)
- /api/sovereign/handshake/verify
- /api/system-scan/pass/{user_id}.png + /api/system-scan/pass-meta/{user_id}
- /api/biofuel/* — recipes (public), today/cues/log/scan/instacart/doordash (auth)
- system-scan/unified biofuel block, sovereign/status biofuel block
"""
import base64
import io
import os
import time

import pytest
import requests
from PIL import Image
from pymongo import MongoClient

BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "").rstrip("/")
if not BASE_URL:
    # fallback to frontend/.env
    with open("/app/frontend/.env") as f:
        for line in f:
            if line.startswith("REACT_APP_BACKEND_URL="):
                BASE_URL = line.split("=", 1)[1].strip().rstrip("/")
                break

MONGO_URL = "mongodb://localhost:27017"
DB_NAME = "test_database"

SESSION = "sess_1777957943281"
USER_ID = "test-fel-os-1777957943281"

TIMEOUT = 35  # vision can take 5-15s


def hdr(token=SESSION):
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


# ============ DB INDEXES ============
class TestMongoIndexes:
    @pytest.fixture(scope="class")
    def db(self):
        client = MongoClient(MONGO_URL)
        return client[DB_NAME]

    def test_education_progress_unique_compound_index(self, db):
        idxs = db.education_progress.index_information()
        unique_compound = [
            v for v in idxs.values()
            if v.get("unique") and v["key"] == [("user_id", 1), ("track_id", 1)]
        ]
        assert unique_compound, f"unique (user_id,track_id) index missing. Found: {idxs}"

    def test_brain_brawl_launches_ttl_index(self, db):
        idxs = db.brain_brawl_launches.index_information()
        ttl = [v for v in idxs.values() if v.get("expireAfterSeconds") == 86400]
        assert ttl, f"24h TTL index missing on brain_brawl_launches. Found: {idxs}"
        # field should be launched_at_ts
        assert any("launched_at_ts" in [k for k, _ in v["key"]] for v in ttl), \
            "TTL index not on launched_at_ts field"


# ============ SOVEREIGN HANDSHAKE VERIFY ============
class TestSovereignHandshake:
    def test_verify_returns_expected_payload(self):
        r = requests.get(f"{BASE_URL}/api/sovereign/handshake/verify", timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert d["ok"] is True
        assert d["expected_ws_url"] == "wss://finalevolutiongroup.com/ws/sovereign"
        assert d["encryption"] == "AES-256-GCM"
        assert d["mode"] == "production"
        assert d["device_target"] == "iPhone16,2"


# ============ FEL OS PASS IMAGE ============
class TestFelOsPass:
    def test_pass_png_returns_valid_image(self):
        r = requests.get(f"{BASE_URL}/api/system-scan/pass/{USER_ID}.png", timeout=15)
        assert r.status_code == 200
        assert r.headers["content-type"].startswith("image/png")
        img = Image.open(io.BytesIO(r.content))
        assert img.size == (1200, 630), f"Unexpected size: {img.size}"

    def test_pass_meta_returns_share_payload(self):
        r = requests.get(f"{BASE_URL}/api/system-scan/pass-meta/{USER_ID}", timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert "share_text" in d and len(d["share_text"]) > 0
        assert d["og_image_url_path"] == f"/api/system-scan/pass/{USER_ID}.png"
        assert "name" in d or "user_id" in d

    def test_pass_png_404_unknown_user(self):
        r = requests.get(f"{BASE_URL}/api/system-scan/pass/no-such-user-zzz.png", timeout=10)
        assert r.status_code == 404


# ============ BIOFUEL — PUBLIC ENDPOINTS ============
class TestBiofuelPublic:
    def test_recipes_list_with_5_intents_5_recipes(self):
        r = requests.get(f"{BASE_URL}/api/biofuel/recipes", timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert len(d["intents"]) == 5
        assert len(d["recipes"]) == 5
        for rec in d["recipes"]:
            assert "viz_palette" in rec

    def test_recipes_filtered_by_intent(self):
        r = requests.get(f"{BASE_URL}/api/biofuel/recipes?intent=post_dunk_recovery", timeout=10)
        assert r.status_code == 200
        recs = r.json()["recipes"]
        assert len(recs) >= 1
        assert all(rec["intent"] == "post_dunk_recovery" for rec in recs)

    def test_recipe_detail_post_dunk_bowl(self):
        r = requests.get(f"{BASE_URL}/api/biofuel/recipes/recipe_post_dunk_bowl", timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert len(d["ingredients"]) == 9
        assert len(d["steps"]) == 4
        assert "macros" in d
        assert "micros" in d


# ============ BIOFUEL — AUTH GATING ============
class TestBiofuelAuthGating:
    @pytest.mark.parametrize("path,method,body", [
        ("/api/biofuel/today", "GET", None),
        ("/api/biofuel/cues", "GET", None),
        ("/api/biofuel/scan", "POST", {"image_base64": "x", "model": "gemini-2.5-flash"}),
        ("/api/biofuel/log", "POST", {"label": "x", "calories": 0, "protein_g": 0, "carbs_g": 0, "fats_g": 0}),
        ("/api/biofuel/instacart-cart", "POST", {"recipe_id": "recipe_post_dunk_bowl"}),
        ("/api/biofuel/doordash-search", "POST", {}),
    ])
    def test_auth_required(self, path, method, body):
        url = f"{BASE_URL}{path}"
        if method == "GET":
            r = requests.get(url, timeout=10)
        else:
            r = requests.post(url, json=body, timeout=10)
        assert r.status_code in (401, 403), f"{path} returned {r.status_code}, expected 401/403"


# ============ BIOFUEL — AUTHENTICATED FLOWS ============
class TestBiofuelAuthenticated:
    def test_today_returns_target_consumed_pct(self):
        r = requests.get(f"{BASE_URL}/api/biofuel/today", headers=hdr(), timeout=10)
        assert r.status_code == 200
        d = r.json()
        for k in ("target", "consumed", "pct", "intent", "intent_label"):
            assert k in d
        for mk in ("calories", "protein_g", "carbs_g", "fats_g"):
            assert mk in d["target"]

    def test_cues_supportive_tone(self):
        r = requests.get(f"{BASE_URL}/api/biofuel/cues", headers=hdr(), timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert d["tone"] == "supportive"
        assert isinstance(d["cues"], list)

    def test_log_appends_and_today_reflects(self):
        # snapshot
        before = requests.get(f"{BASE_URL}/api/biofuel/today", headers=hdr(), timeout=10).json()
        prev_cal = before["consumed"]["calories"]

        body = {"label": "TEST_quickbar", "calories": 220, "protein_g": 18, "carbs_g": 26, "fats_g": 7}
        r = requests.post(f"{BASE_URL}/api/biofuel/log", headers=hdr(), json=body, timeout=10)
        assert r.status_code == 200
        assert r.json()["ok"] is True

        after = requests.get(f"{BASE_URL}/api/biofuel/today", headers=hdr(), timeout=10).json()
        assert after["consumed"]["calories"] == prev_cal + 220
        # pct sanity
        target_cal = after["target"]["calories"]
        if target_cal:
            expected_pct = min(100, round(100 * after["consumed"]["calories"] / target_cal))
            assert after["pct"]["calories"] == expected_pct

    def test_scan_invalid_model_400(self):
        r = requests.post(f"{BASE_URL}/api/biofuel/scan", headers=hdr(),
                          json={"image_base64": "abc", "model": "gpt-3"}, timeout=10)
        assert r.status_code == 400

    @pytest.fixture(scope="class")
    def real_food_b64(self):
        # Real food photo (Unsplash chicken bowl)
        url = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400"
        r = requests.get(url, timeout=20)
        assert r.status_code == 200
        return base64.b64encode(r.content).decode()

    @pytest.mark.parametrize("model", ["gemini-2.5-flash", "gpt-5.2"])
    def test_scan_real_food_image(self, real_food_b64, model):
        r = requests.post(
            f"{BASE_URL}/api/biofuel/scan", headers=hdr(),
            json={"image_base64": real_food_b64, "model": model}, timeout=TIMEOUT,
        )
        if r.status_code == 502:
            pytest.skip(f"Vision provider error for {model}: {r.text[:200]}")
        assert r.status_code == 200, f"{model}: {r.status_code} — {r.text[:300]}"
        d = r.json()
        for k in ("scan_id", "model", "label", "calories", "protein_g", "carbs_g",
                  "fats_g", "micros", "athletic_intent", "nutri_shards_awarded", "scanned_at"):
            assert k in d, f"missing key {k}"
        assert d["model"] == model
        assert d["nutri_shards_awarded"] == 12

    def test_instacart_cart_valid_recipe(self):
        r = requests.post(f"{BASE_URL}/api/biofuel/instacart-cart", headers=hdr(),
                          json={"recipe_id": "recipe_post_dunk_bowl"}, timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert d["deep_link"].startswith("https://www.instacart.com/store/s?k=")
        assert isinstance(d["items"], list) and len(d["items"]) > 0

    def test_instacart_cart_unknown_recipe_404(self):
        r = requests.post(f"{BASE_URL}/api/biofuel/instacart-cart", headers=hdr(),
                          json={"recipe_id": "no_such_recipe"}, timeout=10)
        assert r.status_code == 404

    def test_doordash_search_macro_filtered(self):
        r = requests.post(f"{BASE_URL}/api/biofuel/doordash-search", headers=hdr(),
                          json={"intent": "post_dunk_recovery"}, timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert isinstance(d["matches"], list) and len(d["matches"]) > 0
        for m in d["matches"]:
            assert m["deep_link"].startswith("https://www.doordash.com/search/store/?query=")


# ============ UNIFIED + SOVEREIGN STATUS ============
class TestUnifiedAndStatus:
    def test_system_scan_unified_includes_biofuel(self):
        r = requests.get(f"{BASE_URL}/api/system-scan/unified", headers=hdr(), timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert "biofuel" in d
        bf = d["biofuel"]
        for k in ("intent", "target", "consumed", "pct"):
            assert k in bf, f"biofuel.{k} missing"

    def test_sovereign_status_includes_biofuel_block(self):
        r = requests.get(f"{BASE_URL}/api/sovereign/status", timeout=10)
        assert r.status_code == 200
        d = r.json()
        assert "biofuel" in d, f"biofuel block missing. keys: {list(d.keys())}"
        bf = d["biofuel"]
        assert bf.get("registered") is True
        assert bf.get("tone") == "supportive"
        assert set(bf.get("models", [])) == {"gemini-2.5-flash", "gpt-5.2"}
        assert len(bf.get("intents", [])) == 5
