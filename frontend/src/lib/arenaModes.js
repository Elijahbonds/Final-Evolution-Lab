export const FEL_ARENA_MODES = [
  ["basketball_h2h", "Street · 1v1", "Basketball", "VeniceBeach", "1v1", "3 min"],
  ["basketball_dunk_3d", "3D H2H Dunk Contest", "Basketball", "VeniceBeachBlueCourt", "1v1", "5 min"],
  ["basketball_dunk_irl", "IRL H2H Dunk Contest", "Basketball", "RegulationCourtIRL", "Camera", "5 min"],
  ["basketball_3v3", "Street · 3v3", "Basketball", "VeniceBeach", "3v3", "8 min"],
  ["karate", "Karate · Dojo", "Combat", "Dojo", "Solo", "3 min"],
  ["karate_h2h", "Karate · 1v1", "Combat", "Dojo", "1v1", "3 min"],
  ["karate_endless", "Karate · Endless", "Combat", "Dojo", "Solo", "Endless"],
  ["baseball", "Baseball · Ballpark", "Field", "BaseballPark", "Solo", "5 min"],
  ["football", "Football · Kick Return", "Field", "Gridiron", "Solo", "4 min"],
  ["soccer", "Soccer · Stadium", "Field", "SoccerStadium", "Solo", "3 min"],
  ["golf", "Golf · Links", "Precision", "Links", "Solo", "5 min"],
  ["tennis", "Tennis · Court", "Court", "TennisCourt", "1v1", "3 min"],
  ["volleyball", "Volleyball · Sand Court", "Court", "SandCourt", "2v2", "3 min"],
  ["gymnastics", "Gymnastics · Floor", "Performance", "TrainingFloor", "Solo", "4 min"],
  ["brain_brawl", "Academy · Brain Brawl", "Academy", "NeuroArena", "Solo", "2 min"],
  ["who_scene_it", "Who Scene It", "Academy", "NeuroArena", "2-8", "15 min"],
  ["court_carnival", "Court Carnival", "Party", "VeniceBeach", "2-4", "30 min"],
  ["surfing", "Surf · Line", "Board", "VeniceBeach", "Solo", "3 min"],
  ["skateboarding", "Skate · Park", "Board", "SkatePark", "Solo", "3 min"],
  ["snowboarding", "Snow · Line", "Board", "MountainSlope", "Solo", "3 min"],
  ["market_browse", "Sovereign Shop", "Academy", "Luma_Venice_Shop", "Browse", "Open"],
].map(([id, displayName, category, venue, playerCount, duration]) => ({
  id,
  name: displayName,
  display_name: displayName,
  category,
  venue,
  player_count: playerCount,
  duration,
  difficulty: category === "Academy" ? "Cognitive" : "Adaptive",
  game_type: id === "brain_brawl" || id === "who_scene_it" ? "quiz" : id === "court_carnival" ? "party" : "reflex",
  playable: id !== "market_browse",
  image_url:
    category === "Basketball"
      ? "/images/ue5_basketball.png"
      : category === "Combat"
        ? "/images/ue5_dojo.png"
        : category === "Field"
          ? "/images/ue5_soccer.png"
          : "/images/ue5_board.png",
  description: `${displayName} route wired through FEL ArenaSettings and the Phase 2 Vault/HUD realtime backend.`,
}));

