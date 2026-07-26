#!/bin/bash
# =============================================================================
# FEL macOS Migration Script — Final Evolution AI Coach
# Run from inside your macOS UE project root:
#   cd "/Users/elijahbonds/Documents/Unreal Projects/MyProject"
#   bash create_fel_migration.sh
# =============================================================================
set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== FEL Migration Target: $PROJECT_ROOT ==="

# ── Create Directories ──────────────────────────────────────────────────────
mkdir -p backend
mkdir -p FinalEvolutionLab/Models
mkdir -p FinalEvolutionLab/Services
mkdir -p FinalEvolutionLab/Physics
mkdir -p FinalEvolutionLab/Input
mkdir -p FinalEvolutionLab/Engines
mkdir -p infra/ue5_config
mkdir -p infra/ios
mkdir -p infra/fel_environment_layouts
mkdir -p UnrealIntegration/Source/FinalEvolutionLab
mkdir -p UnrealStarter/BasketballGame/Content/FEL/Config
mkdir -p UnrealStarter/BasketballGame/Config
mkdir -p frontend/src/hud
mkdir -p frontend/src/stores
mkdir -p frontend/src/hooks
echo "✓ Directories created"

# ── FILE 1: backend/FEL_ModeManager.production.json ─────────────────────────
cat > backend/FEL_ModeManager.production.json << 'HEREDOC'
{
  "cooked_runtime_note": "[FELPlayMap] in DefaultGame.ini is the cooked iOS runtime map path source of truth. /Game/FEL/Maps paths in this JSON are logical map/venue tokens used by the backend.",
  "mode_manager": {
    "total_modes": 19,
    "production_modes": 14,
    "mode_registry": {
      "basketball_h2h":  {"status": "production"},
      "basketball_dunk": {"status": "production"},
      "basketball_3v3":  {"status": "production"},
      "karate_h2h":      {"status": "production"},
      "karate_endless":  {"status": "production"},
      "baseball":        {"status": "production"},
      "football":        {"status": "production"},
      "soccer":          {"status": "production"},
      "golf":            {"status": "production"},
      "tennis":          {"status": "production"},
      "volleyball":      {"status": "production"},
      "gymnastics":      {"status": "production"},
      "brain_brawl":     {"status": "production"},
      "surfing":         {"status": "production"},
      "skateboarding":   {"status": "staging"},
      "snowboarding":    {"status": "staging"},
      "who_scene_it":    {"status": "preview"},
      "court_carnival":  {"status": "preview", "gamemode_class": "/Script/FEL.BP_CourtCarnival"},
      "market_browse":   {"type": "non-game-module"}
    }
  }
}
HEREDOC
echo "✓ FILE 1: backend/FEL_ModeManager.production.json"

# ── FILE 2: backend/ue_mode_maps.json ────────────────────────────────────────
cat > backend/ue_mode_maps.json << 'HEREDOC'
{
  "mode_to_unreal_map": {
    "basketball_h2h":  "Venice_Beach",
    "basketball_dunk": "Venice_Beach",
    "basketball_3v3":  "Venice_Beach",
    "karate_h2h":      "Dojo",
    "karate_endless":  "Dojo",
    "baseball":        "Baseball_Park",
    "football":        "Gridiron",
    "soccer":          "Soccer_Stadium",
    "golf":            "Links",
    "tennis":          "Tennis_Court",
    "volleyball":      "Sand_Court",
    "gymnastics":      "Training_Floor",
    "brain_brawl":     "Neuro_Arena",
    "surfing":         "Venice_Beach",
    "skateboarding":   "Skate_Park",
    "snowboarding":    "Mountain_Slope",
    "who_scene_it":    "Neuro_Arena",
    "court_carnival":  "Venice_Beach_Court",
    "market_browse":   "Vault_Shop"
  }
}
HEREDOC
echo "✓ FILE 2: backend/ue_mode_maps.json"

# ── FILE 3: infra/ue5_config/DefaultGame.ini ─────────────────────────────────
cat > infra/ue5_config/DefaultGame.ini << 'HEREDOC'
[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Game/FEL/Venues/VeniceBeach/VeniceBeach
GlobalDefaultGameMode=/Script/FEL.BP_FELGameMode

[FELPlayMap]
basketball_h2h=/Game/FEL/Venues/VeniceBeach/VeniceBeach
basketball_dunk=/Game/FEL/Venues/VeniceBeach/VeniceBeach
basketball_3v3=/Game/FEL/Venues/VeniceBeach/VeniceBeach
karate_h2h=/Game/FEL/Venues/Dojo/Dojo
karate_endless=/Game/FEL/Venues/Dojo/Dojo
baseball=/Game/FEL/Venues/BaseballPark/BaseballPark
football=/Game/FEL/Venues/Gridiron/Gridiron
soccer=/Game/FEL/Venues/SoccerStadium/SoccerStadium
golf=/Game/FEL/Venues/Links/Links
tennis=/Game/FEL/Venues/TennisCourt/TennisCourt
volleyball=/Game/FEL/Venues/SandCourt/SandCourt
gymnastics=/Game/FEL/Venues/TrainingFloor/TrainingFloor
brain_brawl=/Game/FEL/Venues/NeuroArena/NeuroArena
surfing=/Game/FEL/Venues/VeniceBeach/VeniceBeach
skateboarding=/Game/FEL/Venues/Skate_Park/Skate_Park
snowboarding=/Game/FEL/Venues/Mountain_Slope/Mountain_Slope
who_scene_it=/Game/FEL/Venues/NeuroArena/NeuroArena
court_carnival=/Game/FEL/Venues/VeniceBeach/VeniceBeach
market_browse=/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop
HEREDOC
echo "✓ FILE 3: infra/ue5_config/DefaultGame.ini"

# ── FILE 4: FinalEvolutionLab/Models/GameMode.swift ──────────────────────────
cat > FinalEvolutionLab/Models/GameMode.swift << 'HEREDOC'
import Foundation

enum FELModeStatus { case production, staging, preview }
enum InputScheme   { case dragTap, swipe, tap, tilt }

struct GameModeDescriptor {
    let id: GameModeId
    let displayName: String
    let prqWeight: Double
    let inputScheme: InputScheme
    let status: FELModeStatus
}

enum GameModeId: String, CaseIterable {
    case basketballH2H   = "basketball_h2h"
    case basketballDunk  = "basketball_dunk"
    case basketball3v3   = "basketball_3v3"
    case karateH2H       = "karate_h2h"
    case karateEndless   = "karate_endless"
    case baseball        = "baseball"
    case football        = "football"
    case soccer          = "soccer"
    case golf            = "golf"
    case tennis          = "tennis"
    case volleyball      = "volleyball"
    case gymnastics      = "gymnastics"
    case brainBrawl      = "brain_brawl"
    case surfing         = "surfing"
    case skateboarding   = "skateboarding"
    case snowboarding    = "snowboarding"
    case whoSceneIt      = "who_scene_it"
    case courtCarnival   = "court_carnival"
    case marketBrowse    = "market_browse"

    var inputScheme: InputScheme {
        switch self {
        case .whoSceneIt, .courtCarnival, .marketBrowse: return .dragTap
        case .golf, .tennis:                              return .swipe
        case .brainBrawl:                                 return .tap
        case .surfing, .snowboarding:                     return .tilt
        default:                                          return .swipe
        }
    }
}

struct GameModeRegistry {
    static let all: [GameModeDescriptor] = [
        .init(id: .basketballH2H,  displayName: "Basketball H2H",    prqWeight: 1.2, inputScheme: .swipe,   status: .production),
        .init(id: .basketballDunk, displayName: "Dunk Contest",       prqWeight: 1.1, inputScheme: .swipe,   status: .production),
        .init(id: .basketball3v3,  displayName: "3v3 Basketball",     prqWeight: 1.3, inputScheme: .swipe,   status: .production),
        .init(id: .karateH2H,      displayName: "Karate H2H",         prqWeight: 1.2, inputScheme: .swipe,   status: .production),
        .init(id: .karateEndless,  displayName: "Karate Endless",     prqWeight: 1.0, inputScheme: .swipe,   status: .production),
        .init(id: .baseball,       displayName: "Baseball",            prqWeight: 1.1, inputScheme: .swipe,   status: .production),
        .init(id: .football,       displayName: "Football",            prqWeight: 1.2, inputScheme: .swipe,   status: .production),
        .init(id: .soccer,         displayName: "Soccer",              prqWeight: 1.1, inputScheme: .swipe,   status: .production),
        .init(id: .golf,           displayName: "Golf",                prqWeight: 1.0, inputScheme: .swipe,   status: .production),
        .init(id: .tennis,         displayName: "Tennis",              prqWeight: 1.1, inputScheme: .swipe,   status: .production),
        .init(id: .volleyball,     displayName: "Volleyball",          prqWeight: 1.1, inputScheme: .swipe,   status: .production),
        .init(id: .gymnastics,     displayName: "Gymnastics",          prqWeight: 1.4, inputScheme: .swipe,   status: .production),
        .init(id: .brainBrawl,     displayName: "Brain Brawl",         prqWeight: 1.6, inputScheme: .tap,     status: .production),
        .init(id: .surfing,        displayName: "Surfing",             prqWeight: 1.0, inputScheme: .tilt,    status: .production),
        .init(id: .skateboarding,  displayName: "Skateboarding",       prqWeight: 0.9, inputScheme: .swipe,   status: .staging),
        .init(id: .snowboarding,   displayName: "Snowboarding",        prqWeight: 0.9, inputScheme: .tilt,    status: .staging),
        .init(id: .whoSceneIt,     displayName: "Who Scene It",        prqWeight: 1.3, inputScheme: .dragTap, status: .preview),
        .init(id: .courtCarnival,  displayName: "Court Carnival",      prqWeight: 1.2, inputScheme: .dragTap, status: .preview),
        .init(id: .marketBrowse,   displayName: "Market Browse",       prqWeight: 0.0, inputScheme: .dragTap, status: .preview),
    ]
}
HEREDOC
echo "✓ FILE 4: FinalEvolutionLab/Models/GameMode.swift"

# ── FILE 5: FinalEvolutionLab/Services/MentalResiliencyEngine.swift ──────────
cat > FinalEvolutionLab/Services/MentalResiliencyEngine.swift << 'HEREDOC'
import Foundation

enum FELFeatureFlags {
    static var enableNeurocognitiveEngine: Bool = false
}

struct HRVSample    { let timestamp: TimeInterval; let rrIntervalMs: Double }
struct TierAResult  { let arv: Double;         let modifier: Double }
struct TierBResult  { let esi: Double;         let modifier: Double }
struct TierCResult  { let pacingScore: Double; let modifier: Double }
struct MRIResult    { let mri: Double; let tierA: TierAResult; let tierB: TierBResult; let tierC: TierCResult }

struct SessionMetrics {
    let hrvSamples: [HRVSample]
    let contextSwitchCount: Int
    let errorCount: Int
    let inputLagSamples: [Double]
    let smartPauseCount: Int
    let forcedRecoveryCount: Int
    let totalPauseEvents: Int
}

class MentalResiliencyEngine {
    static let shared = MentalResiliencyEngine()

    func computeTierA(_ m: SessionMetrics) -> TierAResult {
        guard FELFeatureFlags.enableNeurocognitiveEngine else { return TierAResult(arv: 0.5, modifier: 1.0) }
        let rmssd = calcRMSSD(m.hrvSamples)
        let arv   = min(1.0, max(0.0, rmssd / 100.0))
        return TierAResult(arv: arv, modifier: 0.5 + arv * 1.0)
    }

    func computeTierB(_ m: SessionMetrics) -> TierBResult {
        guard FELFeatureFlags.enableNeurocognitiveEngine else { return TierBResult(esi: 50.0, modifier: 1.0) }
        let csf = min(100.0, Double(m.contextSwitchCount) * 5.0)
        let eef = min(100.0, Double(m.errorCount) * 10.0)
        let ild = m.inputLagSamples.isEmpty ? 0.0 : min(100.0, m.inputLagSamples.reduce(0,+) / Double(m.inputLagSamples.count))
        let esi = (csf + eef + ild) / 3.0
        return TierBResult(esi: esi, modifier: 0.8 + ((100.0 - esi) / 100.0) * 0.4)
    }

    func computeTierC(_ m: SessionMetrics) -> TierCResult {
        guard FELFeatureFlags.enableNeurocognitiveEngine else { return TierCResult(pacingScore: 50.0, modifier: 1.0) }
        let total = m.smartPauseCount + m.forcedRecoveryCount
        let ps    = total == 0 ? 50.0 : (Double(m.smartPauseCount) / Double(total)) * 100.0
        return TierCResult(pacingScore: ps, modifier: 0.85 + (ps / 100.0) * 0.30)
    }

    func calculateMRI(_ m: SessionMetrics) -> MRIResult {
        let a = computeTierA(m); let b = computeTierB(m); let c = computeTierC(m)
        return MRIResult(mri: a.arv * 0.40 + (100.0 - b.esi) * 0.35 + c.pacingScore * 0.25, tierA: a, tierB: b, tierC: c)
    }

    private func calcRMSSD(_ s: [HRVSample]) -> Double {
        guard s.count > 1 else { return 50.0 }
        var sum = 0.0
        for i in 1..<s.count { let d = s[i].rrIntervalMs - s[i-1].rrIntervalMs; sum += d * d }
        return sqrt(sum / Double(s.count - 1))
    }
}
HEREDOC
echo "✓ FILE 5: FinalEvolutionLab/Services/MentalResiliencyEngine.swift"

# ── FILE 6: backend/server.py ────────────────────────────────────────────────
cat > backend/server.py << 'HEREDOC'
from flask import Flask, request, jsonify
from pymongo import MongoClient, ASCENDING
import uuid, math, datetime

app = Flask(__name__)
client = MongoClient("mongodb://localhost:27017/")
db = client["fel_db"]

XP_CAP_PER_SESSION = 500
SHARD_BASE = {"win": 50, "draw": 25, "loss": 15}
MODE_PRQ_WEIGHTS = {
    "basketball_h2h":1.2,"basketball_dunk":1.1,"basketball_3v3":1.3,
    "karate_h2h":1.2,"karate_endless":1.0,"baseball":1.1,"football":1.2,
    "soccer":1.1,"golf":1.0,"tennis":1.1,"volleyball":1.1,
    "gymnastics":1.4,"brain_brawl":1.6,"surfing":1.0,
}

def _ensure_indexes():
    db.shard_transactions.create_index([("user_id",ASCENDING),("timestamp",ASCENDING)])
    db.neurocognitive_sessions.create_index([("user_id",ASCENDING),("created_at",ASCENDING)])

def _calculate_xp(score, outcome):
    return min(XP_CAP_PER_SESSION, int(score*0.5*{"win":1.5,"draw":1.0,"loss":0.5}.get(outcome,1.0)))

def _calculate_shards(outcome, combo=0, crit=0):
    return SHARD_BASE.get(outcome,15) + combo*2 + crit*5

def _calculate_prq_delta(mode_id, outcome, score, mri=1.0):
    w = MODE_PRQ_WEIGHTS.get(mode_id,1.0)
    base = {"win":10.0,"draw":5.0,"loss":-3.0}.get(outcome,0.0)
    return round(w * base * (math.log1p(score)/10.0) * mri, 4)

def _pacing_bonus(shards, pacing):
    return int(shards*1.05) if pacing >= 75 else shards

@app.route("/api/games/session", methods=["POST"])
def create_game_session():
    d = request.json
    xp     = _calculate_xp(d.get("score",0), d.get("outcome","loss"))
    shards = _pacing_bonus(_calculate_shards(d.get("outcome","loss"),d.get("combo_count",0),d.get("crit_count",0)), d.get("pacing_score",0))
    prq_delta = _calculate_prq_delta(d.get("mode_id",""), d.get("outcome","loss"), d.get("score",0), d.get("mri_score",1.0))
    sid = str(uuid.uuid4())
    db.shard_transactions.insert_one({"user_id":d.get("user_id","anon"),"session_id":sid,"shards_awarded":shards,"timestamp":datetime.datetime.utcnow()})
    return jsonify({"session_id":sid,"xp_awarded":xp,"xp_capped":xp==XP_CAP_PER_SESSION,"shards_awarded":shards,"prq_delta":prq_delta,"neurocognitive":{"mri_score":d.get("mri_score",1.0),"pacing_bonus_applied":d.get("pacing_score",0)>=75}})

@app.route("/api/modes/launch_stream_mode", methods=["POST"])
def launch_stream_mode():
    mode = request.json.get("mode_id")
    if mode in ["skateboarding","snowboarding","who_scene_it","court_carnival","market_browse"]:
        return jsonify({"error":f"Mode '{mode}' is not in production status."}), 403
    return jsonify({"status":"launched","mode_id":mode})

@app.route("/api/games/brain_brawl/submit", methods=["POST"])
def brain_brawl_submit():
    d = request.json; sid = str(uuid.uuid4())
    db.brain_brawl_sessions.insert_one({**d,"session_id":sid})
    db.game_sessions.insert_one({**d,"session_id":sid,"mode_id":"brain_brawl"})
    return jsonify({"session_id":sid,"status":"recorded"})

@app.route("/api/neurocognitive/session", methods=["POST"])
def neurocognitive_session():
    d = request.json; sid = str(uuid.uuid4())
    db.neurocognitive_sessions.insert_one({**d,"session_id":sid,"created_at":datetime.datetime.utcnow()})
    return jsonify({"session_id":sid,"status":"recorded"})

@app.route("/api/neurocognitive/history", methods=["GET"])
def neurocognitive_history():
    uid = request.args.get("user_id","anon")
    return jsonify({"history":list(db.neurocognitive_sessions.find({"user_id":uid},{"_id":0}).limit(50))})

@app.route("/api/neurocognitive/baseline", methods=["GET"])
def neurocognitive_baseline():
    uid = request.args.get("user_id","anon")
    rec = db.neurocognitive_sessions.find_one({"user_id":uid},sort=[("created_at",ASCENDING)])
    return jsonify({"baseline":rec or {}})

_ensure_indexes()
if __name__ == "__main__":
    app.run(debug=True, port=5000)
HEREDOC
echo "✓ FILE 6: backend/server.py"

# ── FILE 7: FELDeepLinkSubsystem.h ───────────────────────────────────
cat > UnrealIntegration/Source/FinalEvolutionLab/FELDeepLinkSubsystem.h << 'HEREDOC'
#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELDeepLinkSubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELDeepLinkSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()
public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    UFUNCTION(BlueprintCallable, Category="FEL|DeepLink") void HandleDeepLink(const FString& URL);
    UFUNCTION(BlueprintCallable, Category="FEL|DeepLink") void LaunchMode(const FString& ModeId);
    static const TMap<FString, FString>& GetModeToVenueMap();
};
HEREDOC
echo "✓ FILE 7: FELDeepLinkSubsystem.h"

# ── FILE 8: FELEmergentDeepLinkSubsystem.cpp ─────────────────────────────────
cat > UnrealIntegration/Source/FinalEvolutionLab/FELEmergentDeepLinkSubsystem.cpp << 'HEREDOC'
#include "FELDeepLinkSubsystem.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

void UFELDeepLinkSubsystem::Initialize(FSubsystemCollectionBase& Collection) { Super::Initialize(Collection); }

const TMap<FString, FString>& UFELDeepLinkSubsystem::GetModeToVenueMap() {
    static TMap<FString, FString> Map = {
        {"basketball_h2h",  "/Game/FEL/Venues/VeniceBeach/VeniceBeach"},
        {"basketball_dunk", "/Game/FEL/Venues/VeniceBeach/VeniceBeach"},
        {"basketball_3v3",  "/Game/FEL/Venues/VeniceBeach/VeniceBeach"},
        {"karate_h2h",      "/Game/FEL/Venues/Dojo/Dojo"},
        {"karate_endless",  "/Game/FEL/Venues/Dojo/Dojo"},
        {"baseball",        "/Game/FEL/Venues/BaseballPark/BaseballPark"},
        {"football",        "/Game/FEL/Venues/Gridiron/Gridiron"},
        {"soccer",          "/Game/FEL/Venues/SoccerStadium/SoccerStadium"},
        {"golf",            "/Game/FEL/Venues/Links/Links"},
        {"tennis",          "/Game/FEL/Venues/TennisCourt/TennisCourt"},
        {"volleyball",      "/Game/FEL/Venues/SandCourt/SandCourt"},
        {"gymnastics",      "/Game/FEL/Venues/TrainingFloor/TrainingFloor"},
        {"brain_brawl",     "/Game/FEL/Venues/NeuroArena/NeuroArena"},
        {"surfing",         "/Game/FEL/Venues/VeniceBeach/VeniceBeach"},
        {"skateboarding",   "/Game/FEL/Venues/Skate_Park/Skate_Park"},
        {"snowboarding",    "/Game/FEL/Venues/Mountain_Slope/Mountain_Slope"},
        {"who_scene_it",    "/Game/FEL/Venues/NeuroArena/NeuroArena"},
        {"court_carnival",  "/Game/FEL/Venues/VeniceBeach/VeniceBeach"},
        {"market_browse",   "/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop"},
    };
    return Map;
}

void UFELDeepLinkSubsystem::HandleDeepLink(const FString& URL) {
    FString Prefix = TEXT("fel://play/");
    if (URL.StartsWith(Prefix)) LaunchMode(URL.RightChop(Prefix.Len()));
}

void UFELDeepLinkSubsystem::LaunchMode(const FString& ModeId) {
    if (const FString* Path = GetModeToVenueMap().Find(ModeId))
        UGameplayStatics::OpenLevel(GetWorld(), FName(**Path));
}
HEREDOC
echo "✓ FILE 8: FELEmergentDeepLinkSubsystem.cpp"

# ── FILE 9: FELNeuroCognitiveSubsystem.h ─────────────────────────────────────
cat > UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.h << 'HEREDOC'
#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELNeuroCognitiveSubsystem.generated.h"

USTRUCT(BlueprintType)
struct FFELNeuroCogData {
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) float MRIScore = 50.f;
    UPROPERTY(BlueprintReadOnly) float ARV = 0.5f;
    UPROPERTY(BlueprintReadOnly) float ESI = 50.f;
    UPROPERTY(BlueprintReadOnly) float PacingScore = 50.f;
    UPROPERTY(BlueprintReadOnly) float ComboDecayModifier = 1.0f;
    UPROPERTY(BlueprintReadOnly) float PerfectGuardWindowModifier = 1.0f;
    UPROPERTY(BlueprintReadOnly) float QTEApexWindowModifier = 1.0f;
};

UCLASS()
class FINALEVOLUTIONLAB_API UFELNeuroCognitiveSubsystem : public UGameInstanceSubsystem {
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable, Category="FEL|Neuro") void UpdateFromBridgePayload(const FString& JsonString);
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetMRIScore() const { return Data.MRIScore; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetARV() const { return Data.ARV; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetESI() const { return Data.ESI; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetPacingScore() const { return Data.PacingScore; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetComboDecayModifier() const { return Data.ComboDecayModifier; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetPerfectGuardWindowModifier() const { return Data.PerfectGuardWindowModifier; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetQTEApexWindowModifier() const { return Data.QTEApexWindowModifier; }
private:
    FFELNeuroCogData Data;
    void RecalculateModifiers();
    float SafeGetFloat(const TSharedPtr<FJsonObject>& Obj, const FString& Key, float Default) const;
};
HEREDOC
echo "✓ FILE 9: FELNeuroCognitiveSubsystem.h"

# ── FILE 10: FELNeuroCognitiveSubsystem.cpp ───────────────────────────────────
cat > UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.cpp << 'HEREDOC'
#include "FELNeuroCognitiveSubsystem.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

float UFELNeuroCognitiveSubsystem::SafeGetFloat(const TSharedPtr<FJsonObject>& Obj, const FString& Key, float Default) const {
    double Val = 0.0;
    return (Obj.IsValid() && Obj->TryGetNumberField(Key, Val)) ? static_cast<float>(Val) : Default;
}

void UFELNeuroCognitiveSubsystem::UpdateFromBridgePayload(const FString& JsonString) {
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
    if (!FJsonSerializer::Deserialize(Reader, JsonObject) || !JsonObject.IsValid()) return;
    Data.MRIScore    = SafeGetFloat(JsonObject, TEXT("mri_score"),    50.f);
    Data.ARV         = SafeGetFloat(JsonObject, TEXT("arv"),           0.5f);
    Data.ESI         = SafeGetFloat(JsonObject, TEXT("esi"),          50.f);
    Data.PacingScore = SafeGetFloat(JsonObject, TEXT("pacing_score"), 50.f);
    RecalculateModifiers();
}

void UFELNeuroCognitiveSubsystem::RecalculateModifiers() {
    Data.ComboDecayModifier         = 0.6f + Data.ARV * 0.8f;
    Data.PerfectGuardWindowModifier = 0.8f + (Data.ESI / 100.f) * 0.4f;
    Data.QTEApexWindowModifier      = 0.85f + (Data.PacingScore / 100.f) * 0.30f;
}
HEREDOC
echo "✓ FILE 10: FELNeuroCognitiveSubsystem.cpp"

# ── FILE 11: ArenaSettings.json ───────────────────────────────────────────────
cat > UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json << 'HEREDOC'
{
  "arena_settings": {
    "basketball_h2h":  {"bScoringEnabled":true, "ballCount":1, "roundCount":2, "roundDurationSeconds":120},
    "basketball_dunk": {"bScoringEnabled":true, "ballCount":3, "roundCount":1, "roundDurationSeconds":60},
    "basketball_3v3":  {"bScoringEnabled":true, "ballCount":1, "roundCount":4, "roundDurationSeconds":180},
    "karate_h2h":      {"bScoringEnabled":true, "ballCount":0, "roundCount":3, "roundDurationSeconds":90},
    "karate_endless":  {"bScoringEnabled":true, "ballCount":0, "bEndlessMode":true},
    "baseball":        {"bScoringEnabled":true, "ballCount":1, "roundCount":9},
    "football":        {"bScoringEnabled":true, "ballCount":1, "roundCount":4, "roundDurationSeconds":900},
    "soccer":          {"bScoringEnabled":true, "ballCount":1, "roundCount":2, "roundDurationSeconds":2700},
    "golf":            {"bScoringEnabled":true, "ballCount":1, "roundCount":18},
    "tennis":          {"bScoringEnabled":true, "ballCount":1, "roundCount":3},
    "volleyball":      {"bScoringEnabled":true, "ballCount":1, "roundCount":5},
    "gymnastics":      {"bScoringEnabled":true, "ballCount":0, "routineDurationSeconds":90},
    "brain_brawl":     {"bScoringEnabled":true, "ballCount":0, "questionCount":20},
    "surfing":         {"bScoringEnabled":true, "ballCount":0, "waveDurationSeconds":60},
    "skateboarding":   {"bScoringEnabled":true, "ballCount":0, "runDurationSeconds":90},
    "snowboarding":    {"bScoringEnabled":true, "ballCount":0, "runDurationSeconds":120},
    "who_scene_it":    {"bScoringEnabled":false,"ballCount":0},
    "court_carnival":  {"bScoringEnabled":false,"ballCount":0},
    "market_browse":   {"bScoringEnabled":false,"ballCount":0}
  }
}
HEREDOC
echo "✓ FILE 11: ArenaSettings.json"

# ── FILE 12: infra/ios/ExportOptions.plist ────────────────────────────────────
cat > infra/ios/ExportOptions.plist << 'HEREDOC'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>             <string>app-store</string>
    <key>teamID</key>             <string>REPLACE_WITH_TEAM_ID</string>
    <key>signingStyle</key>       <string>manual</string>
    <key>uploadBitcode</key>      <false/>
    <key>uploadSymbols</key>      <true/>
    <key>provisioningProfiles</key>
    <dict>
        <key>REPLACE_WITH_BUNDLE_ID</key>
        <string>REPLACE_WITH_PROVISIONING_PROFILE_NAME</string>
    </dict>
</dict>
</plist>
HEREDOC
echo "✓ FILE 12: infra/ios/ExportOptions.plist"

# ── FILE 13: infra/fel_prebuild_ci_check.sh ───────────────────────────────────
cat > infra/fel_prebuild_ci_check.sh << 'HEREDOC'
#!/bin/bash
set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
echo "=== FEL PRE-BUILD CI CHECK — $PROJECT_ROOT ==="

# Gate 1: mode count == 19, prod >= 14
MC=$(python3 -c "import json; d=json.load(open('$PROJECT_ROOT/backend/FEL_ModeManager.production.json')); print(len(d['mode_manager']['mode_registry']))")
PC=$(python3 -c "import json; d=json.load(open('$PROJECT_ROOT/backend/FEL_ModeManager.production.json')); r=d['mode_manager']['mode_registry']; print(sum(1 for v in r.values() if v.get('status')=='production'))")
[ "$MC" -eq 19 ] && [ "$PC" -ge 14 ] && echo "PASS Gate 1 (modes=$MC prod=$PC)" || { echo "FAIL Gate 1 (modes=$MC prod=$PC)"; ERRORS=$((ERRORS+1)); }

# Gate 2: no mario_party_fever
F=$(grep -r "mario_party_fever" "$PROJECT_ROOT" --include="*.json" --include="*.swift" --include="*.py" --include="*.cpp" --include="*.h" --include="*.ini" -l 2>/dev/null | wc -l | tr -d ' ')
[ "$F" -eq 0 ] && echo "PASS Gate 2" || { echo "FAIL Gate 2: mario_party_fever in $F file(s)"; ERRORS=$((ERRORS+1)); }

# Gate 3: skateboarding/snowboarding NOT routing to VeniceBeach
C=$(grep -E "^(skateboarding|snowboarding)=.*VeniceBeach" "$PROJECT_ROOT/infra/ue5_config/DefaultGame.ini" | wc -l | tr -d ' ')
[ "$C" -eq 0 ] && echo "PASS Gate 3" || { echo "FAIL Gate 3: staging→VeniceBeach found"; ERRORS=$((ERRORS+1)); }

# Gate 4: GameMode.swift >= 19 cases
CC=$(grep -c "case " "$PROJECT_ROOT/FinalEvolutionLab/Models/GameMode.swift" 2>/dev/null || echo 0)
[ "$CC" -ge 19 ] && echo "PASS Gate 4 (cases=$CC)" || { echo "FAIL Gate 4 (cases=$CC)"; ERRORS=$((ERRORS+1)); }

# Gate 5: server.py economy logic
for PAT in "XP_CAP_PER_SESSION" "SHARD_BASE" "prq_delta" "neurocognitive"; do
    grep -q "$PAT" "$PROJECT_ROOT/backend/server.py" && echo "PASS Gate 5 ($PAT)" || { echo "FAIL Gate 5 missing: $PAT"; ERRORS=$((ERRORS+1)); }
done

# Gate 6: neurocognitive engine files present
[ -f "$PROJECT_ROOT/FinalEvolutionLab/Services/MentalResiliencyEngine.swift" ] && echo "PASS Gate 6a" || { echo "FAIL Gate 6a"; ERRORS=$((ERRORS+1)); }
[ -f "$PROJECT_ROOT/UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.h" ] && echo "PASS Gate 6b" || { echo "FAIL Gate 6b"; ERRORS=$((ERRORS+1)); }

echo "=== RESULT: $ERRORS error(s) ==="
[ "$ERRORS" -eq 0 ] && echo "P0 Registries Aligned — macOS Migration Complete" && exit 0 || exit 1
HEREDOC
chmod +x infra/fel_prebuild_ci_check.sh
echo "✓ FILE 13: infra/fel_prebuild_ci_check.sh (chmod +x)"

# ── FILE 14: court_carnival_environment_layout.json ──────────────────────────
cat > infra/fel_environment_layouts/court_carnival_environment_layout.json << 'HEREDOC'
{
  "id": "court_carnival_environment_layout",
  "category": "proposal",
  "type": "level_design_document",
  "mode_id": "court_carnival",
  "venue_id": "Venice_Beach_Court",
  "status": "staging",
  "compat": ["unreal"],
  "urls": [],
  "source_turn": 13,
  "schema_ref": "fel_environment_layouts_ue57_ios_plan",
  "sublevel_composition": {
    "load": ["SL_VeniceBeach_Shell","SL_CourtCarnival_Dressing","SL_CourtCarnival_FX"],
    "unload": ["SL_Basketball_Dressing"]
  },
  "atw_landmarks": [
    {"id":"ATW_01","label":"Right Corner", "position":[620, 660,0],"distance_cm":900,"score_value":3},
    {"id":"ATW_02","label":"Right Wing",   "position":[320, 570,0],"distance_cm":650,"score_value":2},
    {"id":"ATW_03","label":"Right Elbow",  "position":[160, 440,0],"distance_cm":470,"score_value":2},
    {"id":"ATW_04","label":"Top of Key",   "position":[0,   0,  0],"distance_cm":580,"score_value":2},
    {"id":"ATW_05","label":"Left Elbow",   "position":[160,-440,0],"distance_cm":470,"score_value":2},
    {"id":"ATW_06","label":"Left Wing",    "position":[320,-570,0],"distance_cm":650,"score_value":2},
    {"id":"ATW_07","label":"Left Corner",  "position":[620,-660,0],"distance_cm":900,"score_value":3}
  ],
  "spawn_points": [
    {"id":"SP_SOCIAL_01","position":[-200,  0,0],"facing_deg":0},
    {"id":"SP_SOCIAL_02","position":[-200,200,0],"facing_deg":350},
    {"id":"SP_SOCIAL_03","position":[-200,-200,0],"facing_deg":10},
    {"id":"SP_ATW_START","position":[680, 700,0],"facing_deg":225}
  ],
  "ios_budget": {"max_triangles":950000,"max_fx_emitters":8,"max_gpu_particles":400}
}
HEREDOC
echo "✓ FILE 14: infra/fel_environment_layouts/court_carnival_environment_layout.json"

# ── FILE 15: who_scene_it_environment_layout.json ────────────────────────────
cat > infra/fel_environment_layouts/who_scene_it_environment_layout.json << 'HEREDOC'
{
  "id": "who_scene_it_environment_layout",
  "category": "proposal",
  "type": "level_design_document",
  "mode_id": "who_scene_it",
  "venue_id": "Neuro_Arena",
  "status": "staging",
  "compat": ["unreal"],
  "urls": [],
  "source_turn": 13,
  "schema_ref": "fel_environment_layouts_ue57_ios_plan",
  "sublevel_composition": {
    "load": ["SL_NeuroArena_Shell","SL_WhoSceneIt_Dressing","SL_WhoSceneIt_Sequences","SL_WhoSceneIt_FX"],
    "unload": ["SL_BrainBrawl_Dressing"]
  },
  "media_screens": [
    {"id":"MSC_HERO_01", "label":"Primary Reveal Screen","position":[-860,   0,480],"resolution":"1024x576"},
    {"id":"MSC_FLANK_L", "label":"Left Flanking Screen", "position":[-820, 520,420],"resolution":"512x288"},
    {"id":"MSC_FLANK_R", "label":"Right Flanking Screen","position":[-820,-520,420],"resolution":"512x288"}
  ],
  "contestant_platforms": [
    {"id":"PLT_C1","position":[320, 560,0],"buzz_trigger":"BZZ_01"},
    {"id":"PLT_C2","position":[320,   0,0],"buzz_trigger":"BZZ_02"},
    {"id":"PLT_C3","position":[320,-560,0],"buzz_trigger":"BZZ_03"},
    {"id":"PLT_C4","position":[320,-840,0],"buzz_trigger":"BZZ_04"}
  ],
  "camera_sweeps": [
    {"id":"SWP_INTRO",        "duration_s":4.0},
    {"id":"SWP_HERO_REVEAL",  "duration_s":2.5},
    {"id":"SWP_BUZZIN_HERO",  "duration_s":1.8,"note":"runtime-parameterized to winning contestant Y"},
    {"id":"SWP_CORRECT",      "duration_s":3.2},
    {"id":"SWP_WRONG",        "duration_s":1.4},
    {"id":"SWP_SCORE_REVEAL", "duration_s":3.5},
    {"id":"SWP_FINAL_WINNER", "duration_s":5.0,"note":"WinnerY runtime-resolved"}
  ],
  "ios_budget": {"max_live_render_targets":1,"max_gpu_emitters":6,"note":"All sweep cameras non-ticking when idle"}
}
HEREDOC
echo "✓ FILE 15: infra/fel_environment_layouts/who_scene_it_environment_layout.json"

# ── RUN CI GATES ─────────────────────────────────────────────────────────────
echo ""
echo "=== Running CI Gate Validation ==="
bash infra/fel_prebuild_ci_check.sh
