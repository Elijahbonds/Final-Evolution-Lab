// FELVenueConfig.h — All 14 production venue definitions
// Spawn points | Camera zones | Collision volumes | Interactable props | Map paths
// Map convention: /Game/FEL/Maps/MAP_{VenueName}
// Performance budget: max 800 draw calls/frame on iPhone 14
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "FELVenueConfig.generated.h"

USTRUCT(BlueprintType)
struct FFELSpawnPoint
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadWrite) FName SpawnId;
    UPROPERTY(BlueprintReadWrite) FVector Location = FVector::ZeroVector;
    UPROPERTY(BlueprintReadWrite) FRotator Rotation = FRotator::ZeroRotator;
    UPROPERTY(BlueprintReadWrite) FString Role;  // "player", "opponent", "spectator", "camera"
};

USTRUCT(BlueprintType)
struct FFELCameraZone
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadWrite) FName ZoneId;
    UPROPERTY(BlueprintReadWrite) FVector Location = FVector::ZeroVector;
    UPROPERTY(BlueprintReadWrite) FRotator Rotation = FRotator::ZeroRotator;
    UPROPERTY(BlueprintReadWrite) float FOV = 90.f;
    UPROPERTY(BlueprintReadWrite) FString TriggerPhase;  // "intro", "gameplay", "score", "outro"
};

USTRUCT(BlueprintType)
struct FFELVenueConfig
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadWrite) FName VenueId;
    UPROPERTY(BlueprintReadWrite) FName ModeId;
    UPROPERTY(BlueprintReadWrite) FString MapPath;      // /Game/FEL/Maps/MAP_{Name}
    UPROPERTY(BlueprintReadWrite) TArray<FFELSpawnPoint> SpawnPoints;
    UPROPERTY(BlueprintReadWrite) TArray<FFELCameraZone> CameraZones;
    UPROPERTY(BlueprintReadWrite) TArray<FName> CollisionBlockers;
    UPROPERTY(BlueprintReadWrite) TArray<FName> InteractableProps;
    UPROPERTY(BlueprintReadWrite) FString MobileRiskNote;
    UPROPERTY(BlueprintReadWrite) int32 MaxDrawCallBudget = 800;
};

// ─── Venue Registry ──────────────────────────────────────────────────
inline TArray<FFELVenueConfig> FEL_GetAllVenueConfigs()
{
    TArray<FFELVenueConfig> Venues;

    // 1. Venice Beach Court (Basketball H2H / Dunk / 3v3 / CourtCarnival)
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("VeniceBeach_Court");
        V.ModeId = TEXT("basketball_h2h");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_VeniceBeach");
        V.SpawnPoints = {
            {TEXT("SP_Player"), {0,0,0}, {0,0,0}, "player"},
            {TEXT("SP_Opponent"), {600,0,0}, {0,180,0}, "opponent"},
            {TEXT("SP_Camera_Intro"), {300,800,300}, {-20,0,0}, "camera"}
        };
        V.CameraZones = {
            {TEXT("Cam_Intro"), {300,800,300}, {-20,0,0}, 80.f, "intro"},
            {TEXT("Cam_Gameplay"), {300,0,450}, {-35,0,0}, 90.f, "gameplay"},
            {TEXT("Cam_Score"), {300,300,600}, {-45,0,0}, 75.f, "score"}
        };
        V.CollisionBlockers = {TEXT("Wall_N"), TEXT("Wall_S"), TEXT("Wall_E"), TEXT("Wall_W"), TEXT("Bleachers_Collision")};
        V.InteractableProps = {TEXT("Basketball_Hoop_L"), TEXT("Basketball_Hoop_R"), TEXT("CourtLine_Markers")};
        V.MobileRiskNote = TEXT("LOW. Baked lighting. Crowd as 2D billboard cards (<100 instances). LOD for bleachers. No real-time shadows.");
        V.MaxDrawCallBudget = 600;
        Venues.Add(V);
    }

    // 2. Zen Dojo (Karate H2H / Karate Endless)
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Zen_Dojo");
        V.ModeId = TEXT("karate_h2h");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_ZenDojo");
        V.SpawnPoints = {
            {TEXT("SP_Player"), {-250,0,0}, {0,0,0}, "player"},
            {TEXT("SP_Opponent"), {250,0,0}, {0,180,0}, "opponent"}
        };
        V.CameraZones = {
            {TEXT("Cam_Intro"), {0,700,200}, {-15,0,0}, 70.f, "intro"},
            {TEXT("Cam_Combat"), {0,500,180}, {-10,0,0}, 85.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Dojo_Wall_N"), TEXT("Dojo_Wall_S"), TEXT("Dojo_Wall_E"), TEXT("Dojo_Wall_W")};
        V.InteractableProps = {TEXT("Tatami_Mat"), TEXT("Incense_Brazier"), TEXT("Trophy_Case")};
        V.MobileRiskNote = TEXT("LOW. Small interior. Baked lighting. No particles on mobile. Fog via cheap post-process.");
        V.MaxDrawCallBudget = 400;
        Venues.Add(V);
    }

    // 3. Baseball Park
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Baseball_Park");
        V.ModeId = TEXT("baseball");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_BaseballPark");
        V.SpawnPoints = {
            {TEXT("SP_Batter"), {0,0,0}, {0,0,0}, "player"},
            {TEXT("SP_Pitcher"), {1800,0,0}, {0,180,0}, "opponent"},
            {TEXT("SP_Outfield"), {3600,0,0}, {0,180,0}, "opponent"}
        };
        V.CameraZones = {
            {TEXT("Cam_BatterBox"), {0,300,150}, {-20,0,0}, 80.f, "gameplay"},
            {TEXT("Cam_Pitcher"), {900,200,100}, {0,0,0}, 75.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Backstop"), TEXT("FieldWall_L"), TEXT("FieldWall_R"), TEXT("FoulPole_L"), TEXT("FoulPole_R")};
        V.InteractableProps = {TEXT("Home_Plate"), TEXT("Pitching_Rubber"), TEXT("Bases_x3"), TEXT("Scoreboard")};
        V.MobileRiskNote = TEXT("MEDIUM. Crowd via instanced meshes (LOD aggressive). Baked stadium lights. Grass: simple flat mesh with texture. No real-time GI.");
        V.MaxDrawCallBudget = 700;
        Venues.Add(V);
    }

    // 4. Gridiron Stadium
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Gridiron_Stadium");
        V.ModeId = TEXT("football");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_GridironStadium");
        V.SpawnPoints = {
            {TEXT("SP_QB"), {0,0,0}, {0,0,0}, "player"},
            {TEXT("SP_WR"), {1000,300,0}, {0,0,0}, "player"},
            {TEXT("SP_Defender"), {1200,300,0}, {0,180,0}, "opponent"}
        };
        V.CameraZones = {
            {TEXT("Cam_Sideline"), {500,600,200}, {-15,0,0}, 90.f, "gameplay"},
            {TEXT("Cam_Endzone"), {4500,0,300}, {-25,0,0}, 85.f, "score"}
        };
        V.CollisionBlockers = {TEXT("Endzone_Wall_N"), TEXT("Endzone_Wall_S"), TEXT("Sideline_E"), TEXT("Sideline_W")};
        V.InteractableProps = {TEXT("Goalpost_N"), TEXT("Goalpost_S"), TEXT("Yardage_Markers"), TEXT("Scoreboard")};
        V.MobileRiskNote = TEXT("HIGH. Large open field. Aggressive LOD + frustum culling required. Crowd: billboard cards only. Baked lighting mandatory. Cap particle FX (tackle dust). Max 750 draw calls.");
        V.MaxDrawCallBudget = 750;
        Venues.Add(V);
    }

    // 5. Soccer Stadium
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Soccer_Stadium");
        V.ModeId = TEXT("soccer");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_SoccerStadium");
        V.SpawnPoints = {
            {TEXT("SP_Striker"), {0,0,0}, {0,0,0}, "player"},
            {TEXT("SP_Goalkeeper"), {5000,0,0}, {0,180,0}, "opponent"}
        };
        V.CameraZones = {
            {TEXT("Cam_Center"), {2500,800,300}, {-20,0,0}, 90.f, "gameplay"},
            {TEXT("Cam_Goal"), {4800,400,200}, {0,180,0}, 75.f, "score"}
        };
        V.CollisionBlockers = {TEXT("Pitch_Boundary_N"), TEXT("Pitch_Boundary_S"), TEXT("Goal_Net_N"), TEXT("Goal_Net_S")};
        V.InteractableProps = {TEXT("Goal_N"), TEXT("Goal_S"), TEXT("Corner_Flags_x4"), TEXT("Scoreboard")};
        V.MobileRiskNote = TEXT("HIGH. Same as gridiron — large open space. Billboard crowd, baked lighting, LOD grass, capped shadows.");
        V.MaxDrawCallBudget = 750;
        Venues.Add(V);
    }

    // 6. Links Golf Course
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Links_Golf_Course");
        V.ModeId = TEXT("golf");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_LinksGolfCourse");
        V.SpawnPoints = {
            {TEXT("SP_Tee_H1"), {0,0,0}, {0,0,0}, "player"},
            {TEXT("SP_Tee_H2"), {1200,800,0}, {0,45,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_TeeBox"), {0,300,100}, {-10,0,0}, 70.f, "gameplay"},
            {TEXT("Cam_Green"), {400,300,150}, {-15,0,0}, 65.f, "gameplay"},
            {TEXT("Cam_AerialShot"), {200,0,800}, {-60,0,0}, 80.f, "intro"}
        };
        V.CollisionBlockers = {TEXT("Rough_Boundary"), TEXT("Water_Hazard"), TEXT("Sand_Trap")};
        V.InteractableProps = {TEXT("Golf_Pin_H1"), TEXT("Golf_Pin_H2"), TEXT("Golf_Cart"), TEXT("Scorecard_Board")};
        V.MobileRiskNote = TEXT("MEDIUM. Long draw distances. Use aggressive LOD and distance culling on trees/grass. Aerial camera must cull distant terrain tiles. No volumetric fog.");
        V.MaxDrawCallBudget = 650;
        Venues.Add(V);
    }

    // 7. Tennis Court
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Tennis_Court");
        V.ModeId = TEXT("tennis");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_TennisCourt");
        V.SpawnPoints = {
            {TEXT("SP_Near_Baseline"), {0,-1200,0}, {0,0,0}, "player"},
            {TEXT("SP_Far_Baseline"), {0,1200,0}, {0,180,0}, "opponent"}
        };
        V.CameraZones = {
            {TEXT("Cam_Side"), {800,0,300}, {-15,90,0}, 85.f, "gameplay"},
            {TEXT("Cam_Net"), {0,0,200}, {0,0,0}, 75.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Net"), TEXT("Fence_N"), TEXT("Fence_S"), TEXT("Fence_E"), TEXT("Fence_W")};
        V.InteractableProps = {TEXT("Tennis_Net"), TEXT("Ball_Machine"), TEXT("Umpire_Chair"), TEXT("Scoreboard")};
        V.MobileRiskNote = TEXT("LOW. Small court footprint. Baked lighting. No crowd needed. Clean geometry.");
        V.MaxDrawCallBudget = 350;
        Venues.Add(V);
    }

    // 8. Sand Volleyball Court
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Sand_Court");
        V.ModeId = TEXT("volleyball");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_SandCourt");
        V.SpawnPoints = {
            {TEXT("SP_Front_L"), {-200,-300,0}, {0,0,0}, "player"},
            {TEXT("SP_Back_L"), {-200,300,0}, {0,0,0}, "player"},
            {TEXT("SP_Front_R"), {200,-300,0}, {0,180,0}, "opponent"},
            {TEXT("SP_Back_R"), {200,300,0}, {0,180,0}, "opponent"}
        };
        V.CameraZones = {
            {TEXT("Cam_Side"), {800,0,400}, {-20,0,0}, 80.f, "gameplay"},
            {TEXT("Cam_Spike"), {0,0,600}, {-45,0,0}, 70.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Net"), TEXT("Sand_Boundary")};
        V.InteractableProps = {TEXT("Volleyball_Net"), TEXT("Scoreboard_Post"), TEXT("Beach_Chair")};
        V.MobileRiskNote = TEXT("LOW. Beach setting. Simple baked lighting. Sand material: low-cost shader. No reflective water needed.");
        V.MaxDrawCallBudget = 400;
        Venues.Add(V);
    }

    // 9. Training Floor (Gymnastics)
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Training_Floor");
        V.ModeId = TEXT("gymnastics");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_TrainingFloor");
        V.SpawnPoints = {
            {TEXT("SP_FloorCenter"), {0,0,0}, {0,0,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_Judge"), {0,600,200}, {-10,0,0}, 80.f, "gameplay"},
            {TEXT("Cam_Overhead"), {0,0,1000}, {-90,0,0}, 90.f, "score"}
        };
        V.CollisionBlockers = {TEXT("Floor_Boundary"), TEXT("Padded_Wall_N"), TEXT("Padded_Wall_S")};
        V.InteractableProps = {TEXT("Floor_Mat"), TEXT("Judges_Table"), TEXT("Score_Display"), TEXT("Balance_Beam")};
        V.MobileRiskNote = TEXT("LOW. Interior arena. Small footprint. Baked area lights. No outdoor lighting complexity.");
        V.MaxDrawCallBudget = 450;
        Venues.Add(V);
    }

    // 10. Venice Beach Surf
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Venice_Beach_Surf");
        V.ModeId = TEXT("surfing");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_VeniceBeachSurf");
        V.SpawnPoints = {
            {TEXT("SP_WaveEntry"), {0,0,0}, {0,0,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_ShoreFollow"), {200,400,100}, {-10,-30,0}, 80.f, "gameplay"},
            {TEXT("Cam_Aerial"), {0,0,600}, {-70,0,0}, 90.f, "intro"}
        };
        V.CollisionBlockers = {TEXT("Shore_Boundary"), TEXT("Rocks_N"), TEXT("Pier_Collision")};
        V.InteractableProps = {TEXT("Surfboard"), TEXT("Wave_Trigger"), TEXT("Pier"), TEXT("Beach_Umbrellas")};
        V.MobileRiskNote = TEXT("HIGH. Ocean water shader is expensive. Use mobile-safe water material (no SSR). Limit wave particles. No real-time reflections. Aggressive LOD on beach props.");
        V.MaxDrawCallBudget = 700;
        Venues.Add(V);
    }

    // 11. Skate Park
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Skate_Park");
        V.ModeId = TEXT("skateboarding");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_SkatePark");
        V.SpawnPoints = {
            {TEXT("SP_DropIn"), {0,0,200}, {0,0,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_Follow"), {0,300,150}, {-15,0,0}, 90.f, "gameplay"},
            {TEXT("Cam_Trick"), {0,0,500}, {-60,0,0}, 80.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Park_Boundary"), TEXT("Halfpipe_Collision"), TEXT("Rail_Collision")};
        V.InteractableProps = {TEXT("Halfpipe"), TEXT("Grind_Rail_x3"), TEXT("Flat_Box"), TEXT("Kicker_Ramp")};
        V.MobileRiskNote = TEXT("MEDIUM. Concrete environment. Baked AO + lighting. Limit particle trails on tricks. No volumetric lighting.");
        V.MaxDrawCallBudget = 550;
        Venues.Add(V);
    }

    // 12. Mountain Slope
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Mountain_Slope");
        V.ModeId = TEXT("snowboarding");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_MountainSlope");
        V.SpawnPoints = {
            {TEXT("SP_TopOfSlope"), {0,0,2000}, {0,0,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_Behind"), {0,200,100}, {-10,0,0}, 90.f, "gameplay"},
            {TEXT("Cam_BottomFinish"), {0,6000,200}, {-10,180,0}, 85.f, "score"}
        };
        V.CollisionBlockers = {TEXT("Slope_Boundary_L"), TEXT("Slope_Boundary_R"), TEXT("Tree_Collision_Volume")};
        V.InteractableProps = {TEXT("Slalom_Gates"), TEXT("Kicker_Jump"), TEXT("Finish_Line_Banner")};
        V.MobileRiskNote = TEXT("HIGH. Long draw distance. Terrain LOD critical. Snow material: mobile-safe vertex blend only. No SSR on snow. Sparse tree placement with LOD billboards.");
        V.MaxDrawCallBudget = 750;
        Venues.Add(V);
    }

    // 13. Neuro Arena (Brain Brawl / Who Scene It)
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Neuro_Arena");
        V.ModeId = TEXT("brain_brawl");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_NeuroArena");
        V.SpawnPoints = {
            {TEXT("SP_Center"), {0,0,0}, {0,0,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_CategoryWheel"), {0,500,200}, {-20,0,0}, 75.f, "intro"},
            {TEXT("Cam_Question"), {0,0,300}, {-30,0,0}, 70.f, "gameplay"},
            {TEXT("Cam_MediaScreen"), {0,600,100}, {0,0,0}, 80.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Arena_Wall_N"), TEXT("Arena_Wall_S"), TEXT("Arena_Wall_E"), TEXT("Arena_Wall_W")};
        V.InteractableProps = {TEXT("Category_Wheel"), TEXT("Answer_Panels_x4"), TEXT("Score_Hologram"), TEXT("Media_Screen")};
        V.MobileRiskNote = TEXT("LOW. Interior enclosed space. Emissive materials for neon glow effects (no dynamic lights needed). Screen textures are UI planes — low cost.");
        V.MaxDrawCallBudget = 400;
        Venues.Add(V);
    }

    // 14. Court Carnival Route (Around the World)
    {
        FFELVenueConfig V;
        V.VenueId = TEXT("Court_Carnival_Route");
        V.ModeId = TEXT("court_carnival");
        V.MapPath = TEXT("/Game/FEL/Maps/MAP_VeniceBeach");   // shares Venice Beach map with shot-ring overlay
        V.SpawnPoints = {
            {TEXT("SP_Station_0_BaselineLeft"), {-400,-800,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_1_WingLeft"), {-700,-400,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_2_TopOfKey"), {0,-600,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_3_WingRight"), {700,-400,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_4_BaselineRight"), {400,-800,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_5_HalfCourtLogo"), {0,-1400,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_6_VeniceMural"), {-1200,-600,0}, {0,45,0}, "player"},
            {TEXT("SP_Station_7_BoardwalkEdge"), {1400,-400,0}, {0,-45,0}, "player"},
            {TEXT("SP_Station_8_BleacherCorner"), {-1000,200,0}, {0,0,0}, "player"},
            {TEXT("SP_Station_9_DunkLane"), {0,-400,0}, {0,0,0}, "player"}
        };
        V.CameraZones = {
            {TEXT("Cam_BaselineLeft"), {-400,-1000,200}, {-15,0,0}, 75.f, "gameplay"},
            {TEXT("Cam_WingLeft"), {-900,-300,200}, {-15,45,0}, 75.f, "gameplay"},
            {TEXT("Cam_TopOfKey"), {0,-800,250}, {-20,0,0}, 80.f, "gameplay"},
            {TEXT("Cam_WingRight"), {900,-300,200}, {-15,-45,0}, 75.f, "gameplay"},
            {TEXT("Cam_BaselineRight"), {400,-1000,200}, {-15,0,0}, 75.f, "gameplay"},
            {TEXT("Cam_HalfCourt"), {0,-1600,300}, {-25,0,0}, 85.f, "gameplay"},
            {TEXT("Cam_VeniceMural"), {-1000,-800,200}, {-10,30,0}, 70.f, "gameplay"},
            {TEXT("Cam_BoardwalkEdge"), {1600,-200,200}, {-10,-30,0}, 70.f, "gameplay"},
            {TEXT("Cam_BleacherCorner"), {-800,400,250}, {-20,15,0}, 75.f, "gameplay"},
            {TEXT("Cam_DunkLane"), {0,-200,400}, {-40,0,0}, 80.f, "gameplay"}
        };
        V.CollisionBlockers = {TEXT("Court_Boundary"), TEXT("Bleachers_Collision"), TEXT("Mural_Wall")};
        V.InteractableProps = {
            TEXT("ShotRing_0"), TEXT("ShotRing_1"), TEXT("ShotRing_2"), TEXT("ShotRing_3"), TEXT("ShotRing_4"),
            TEXT("ShotRing_5"), TEXT("ShotRing_6"), TEXT("ShotRing_7"), TEXT("ShotRing_8"), TEXT("ShotRing_9"),
            TEXT("M_ShotRing_CyanEmissive")  // material asset required: /Game/FEL/Materials/M_ShotRing
        };
        V.MobileRiskNote = TEXT("LOW. Shares Venice Beach map. Shot rings use emissive material — no dynamic lights. Camera transitions per station: simple interpolation, no render target cost.");
        V.MaxDrawCallBudget = 620;
        Venues.Add(V);
    }

    return Venues;
}
