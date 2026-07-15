#include "nexus/net/net_message.h"
#include "nexus/net/net_message_bus.h"
#include "nexus/net/net_session.h"
#include "nexus/net/local_multiplayer_router.h"
#include "nexus/gameplay/matchmaking_client.h"
#include "nexus/gameplay/remote_player_state.h"
#include "nexus/gameplay/brain_brawl_mode.h"
#include "nexus/gameplay/arena_session_manager.h"

#include <cstdio>
#include <cstdlib>
#include <vector>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

// ── NetMessage round-trip ────────────────────────────────────────────────────

void net_message_round_trips_json() {
  nexus::net::NetMessage msg;
  msg.kind      = nexus::net::NetMessageKind::kPlayerInput;
  msg.senderId  = "player-abc";
  msg.roomCode  = "ROOM01";
  msg.payload   = {{"action", "submit_answer"}, {"correct", true}};
  msg.timestamp = 1.5;

  const auto j = msg.toJson();
  require(j["kind"] == "player_input",   "kind serialised");
  require(j["sender_id"] == "player-abc", "sender_id serialised");
  require(j["room_code"] == "ROOM01",     "room_code serialised");

  const auto decoded = nexus::net::NetMessage::fromJson(j);
  require(decoded.kind == nexus::net::NetMessageKind::kPlayerInput, "kind decoded");
  require(decoded.senderId == "player-abc", "sender_id decoded");
  require(decoded.roomCode == "ROOM01",     "room_code decoded");
  require(decoded.timestamp == 1.5,         "timestamp decoded");
  require(decoded.payload["action"] == "submit_answer", "payload decoded");
}

void net_message_kind_strings_round_trip() {
  using K = nexus::net::NetMessageKind;
  require(nexus::net::NetMessage::kindFromString("player_input")   == K::kPlayerInput,   "player_input");
  require(nexus::net::NetMessage::kindFromString("game_state_sync")== K::kGameStateSync, "game_state_sync");
  require(nexus::net::NetMessage::kindFromString("lobby_event")    == K::kLobbyEvent,    "lobby_event");
  require(nexus::net::NetMessage::kindFromString("match_result")   == K::kMatchResult,   "match_result");
  require(nexus::net::NetMessage::kindFromString("unknown")        == K::kPlayerInput,   "unknown → player_input");
}

// ── NetMessageBus ────────────────────────────────────────────────────────────

void bus_push_and_drain() {
  nexus::net::NetMessageBus bus;
  require(bus.size() == 0, "bus starts empty");

  nexus::net::NetMessage msg;
  msg.senderId = "p1";
  bus.push(msg);
  bus.push(msg);
  require(bus.size() == 2, "bus has 2 messages after push");

  std::vector<nexus::net::NetMessage> out;
  const auto count = bus.drain(out);
  require(count == 2, "drain returned 2");
  require(out.size() == 2, "out has 2 messages");
  require(bus.size() == 0, "bus empty after drain");
}

void bus_clear() {
  nexus::net::NetMessageBus bus;
  nexus::net::NetMessage msg;
  bus.push(msg);
  bus.clear();
  require(bus.size() == 0, "bus cleared");
}

// ── NetSession (stub mode) ───────────────────────────────────────────────────

void net_session_local_multi_send_and_poll() {
  nexus::net::NetSessionConfig cfg;
  cfg.mode             = nexus::net::NetSessionMode::kLocalMulti;
  cfg.useStubTransport = true;

  nexus::net::NetSession session(cfg);
  require(session.connect().isOk(), "local_multi connect ok");
  require(session.state() == nexus::net::NetSessionState::kReady, "state kReady");

  nexus::net::NetMessage msg;
  msg.kind     = nexus::net::NetMessageKind::kPlayerInput;
  msg.senderId = "local_p2";
  msg.payload  = {{"action", "submit_answer"}, {"correct", false}};
  require(session.send(msg).isOk(), "local send ok");

  // Before poll, bus is empty (outbox not flushed yet)
  require(session.bus().size() == 0, "bus empty before poll");

  session.poll();
  require(session.bus().size() == 1, "bus has 1 message after poll");

  std::vector<nexus::net::NetMessage> out;
  session.bus().drain(out);
  require(out.size() == 1,                                "drained 1 message");
  require(out[0].senderId == "local_p2",                  "sender preserved");
  require(out[0].payload["action"] == "submit_answer",    "action preserved");
}

void net_session_solo_send_is_noop() {
  nexus::net::NetSession session;  // default: kSolo
  require(session.connect().isOk(), "solo connect ok");
  nexus::net::NetMessage msg;
  require(session.send(msg).isOk(), "solo send ok (no-op)");
  session.poll();
  require(session.bus().size() == 0, "solo bus stays empty");
}

void net_session_online_stub_connect_succeeds() {
  nexus::net::NetSessionConfig cfg;
  cfg.mode             = nexus::net::NetSessionMode::kOnline;
  cfg.roomCode         = "ROOM42";
  cfg.localUserId      = "user-xyz";
  cfg.relayUrl         = "ws://127.0.0.1:8787/ws/relay";
  cfg.useStubTransport = true;

  nexus::net::NetSession session(cfg);
  require(session.connect().isOk(), "online stub connect ok");
  require(session.state() == nexus::net::NetSessionState::kReady, "online stub kReady");
}

// ── LocalMultiplayerRouter ───────────────────────────────────────────────────

void local_router_dispatches_player2_input() {
  nexus::net::NetSessionConfig cfg;
  cfg.mode             = nexus::net::NetSessionMode::kLocalMulti;
  cfg.useStubTransport = true;

  nexus::net::NetSession session(cfg);
  (void)session.connect();

  nexus::net::LocalMultiplayerRouter router(session);
  router.setPlayer2Id("p2-test");
  router.dispatchPlayer2Input("tackle", {{"power", 0.8F}});

  session.poll();
  require(session.bus().size() == 1, "router dispatched 1 message");

  std::vector<nexus::net::NetMessage> out;
  session.bus().drain(out);
  require(out[0].senderId == "p2-test",       "sender is p2");
  require(out[0].payload["action"] == "tackle","action preserved");
  require(out[0].payload["power"] == 0.8F,    "payload field preserved");
  require(out[0].kind == nexus::net::NetMessageKind::kPlayerInput, "kind kPlayerInput");
}

void local_router_dispatches_state_sync() {
  nexus::net::NetSession session({.mode = nexus::net::NetSessionMode::kLocalMulti,
                                   .useStubTransport = true});
  (void)session.connect();

  nexus::net::LocalMultiplayerRouter router(session);
  router.dispatchStateSync({{"player_score", 12.0F}, {"op_goals", 2}});

  session.poll();
  std::vector<nexus::net::NetMessage> out;
  session.bus().drain(out);
  require(out.size() == 1, "state sync dispatched");
  require(out[0].kind == nexus::net::NetMessageKind::kGameStateSync, "kind kGameStateSync");
  require(out[0].payload["player_score"] == 12.0F, "state payload preserved");
}

// ── RemotePlayerState ────────────────────────────────────────────────────────

void remote_player_state_json_round_trip() {
  nexus::gameplay::RemotePlayerState s;
  s.playerId  = "remote-p2";
  s.score     = 42.5F;
  s.correct   = 7;
  s.hp        = 60;
  s.goals     = 2;
  s.dunkScore = 18;

  const auto j = s.toJson();
  const auto decoded = nexus::gameplay::RemotePlayerState::fromJson(j);
  require(decoded.playerId  == "remote-p2", "player_id round-trip");
  require(decoded.score     == 42.5F,       "score round-trip");
  require(decoded.correct   == 7,           "correct round-trip");
  require(decoded.hp        == 60,          "hp round-trip");
  require(decoded.goals     == 2,           "goals round-trip");
  require(decoded.dunkScore == 18,          "dunk_score round-trip");
}

// ── BrainBrawlMode remote opponent ──────────────────────────────────────────

void brain_brawl_remote_opponent_bypasses_ghost_ai() {
  nexus::gameplay::BrainBrawlMode mode;
  mode.reset();

  nexus::gameplay::RemotePlayerState remote;
  remote.playerId = "opponent-p2";
  remote.correct  = 5;  // pre-seeded remote score

  mode.setRemoteOpponent(&remote);
  require(mode.hasRemoteOpponent(), "remote opponent registered");
  require(mode.opponentCorrect() == 5, "opponent score synced from remote state");

  // Submit a local answer — ghost AI should not advance the opponent.
  const int opponentBefore = mode.opponentCorrect();
  // Force update to fire advanceGhostOpponent
  for (int i = 0; i < 20; ++i) {
    mode.update(0.5);  // 10 seconds total: ghost would have fired twice
  }
  // Ghost AI is suppressed; opponent count should remain driven by remote state.
  require(mode.opponentCorrect() == remote.correct, "ghost AI suppressed by remote state");

  // Apply a real remote answer via the bus path.
  mode.applyRemoteAnswer(true);
  require(mode.opponentCorrect() == 6, "applyRemoteAnswer increments opponent");

  mode.setRemoteOpponent(nullptr);
  require(!mode.hasRemoteOpponent(), "remote opponent cleared");
}

// ── ArenaSessionManager multiplayer session ──────────────────────────────────

void arena_session_manager_multiplayer_session() {
  nexus::gameplay::ArenaSessionManager manager;

  const std::vector<std::string> players = {"p1", "p2"};
  const auto result = manager.startMultiplayerSession(
      "basketball_dunk", "p1", players,
      nexus::gameplay::MultiplayerMode::kLocalMulti, "ROOM99");
  require(result.isOk(), "startMultiplayerSession ok");

  const auto& state = manager.state();
  require(state.phase == nexus::gameplay::ArenaSessionPhase::kActive, "session active");
  require(state.multiplayerMode == nexus::gameplay::MultiplayerMode::kLocalMulti, "local_multi mode");
  require(state.roomCode == "ROOM99", "room code stored");
  require(state.playerIds.size() == 2, "two player IDs");

  manager.updatePlayerScore("p2", 12.5F);
  const auto json = manager.stateJson();
  require(json.contains("player_scores"), "player_scores in stateJson");
  require(json["player_scores"]["p2"] == 12.5F, "p2 score in stateJson");
  require(json["room_code"] == "ROOM99", "room_code in stateJson");
}

// ── MatchmakingClient (stub) ─────────────────────────────────────────────────

void matchmaking_client_stub_create_lobby() {
  nexus::gameplay::MatchmakingClientConfig cfg;
  cfg.useStubTransport = true;

  nexus::gameplay::MatchmakingClient client(cfg);
  const auto result = client.createLobby("brain_brawl", "user-abc");
  require(result.isOk(), "createLobby ok (stub)");
  require(!result.value().id.empty(), "lobby id not empty");
}

void matchmaking_client_stub_join_lobby() {
  nexus::gameplay::MatchmakingClientConfig cfg;
  cfg.useStubTransport = true;

  nexus::gameplay::MatchmakingClient client(cfg);
  const auto result = client.joinLobby("STUB01", "user-xyz");
  require(result.isOk(), "joinLobby ok (stub)");
}

void matchmaking_client_build_relay_config() {
  nexus::gameplay::MatchmakingClientConfig cfg;
  cfg.wsRelayUrl       = "ws://relay.example.com/ws/relay";
  cfg.useStubTransport = true;

  nexus::gameplay::MatchmakingClient client(cfg);
  nexus::net::NetSessionConfig netCfg;
  const auto result = client.buildRelayConfig("ABC123", "user-xyz", netCfg);
  require(result.isOk(), "buildRelayConfig ok");
  require(netCfg.roomCode == "ABC123", "room code in net config");
  require(netCfg.localUserId == "user-xyz", "user id in net config");
  require(netCfg.mode == nexus::net::NetSessionMode::kOnline, "mode kOnline");
  require(netCfg.relayUrl.find("ABC123") != std::string::npos, "room in relay URL");
}

void matchmaking_client_empty_room_code_rejected() {
  nexus::gameplay::MatchmakingClient client;
  nexus::net::NetSessionConfig netCfg;
  const auto result = client.buildRelayConfig("", "user", netCfg);
  require(result.isErr(), "empty room_code rejected");
}

} // namespace

auto main() -> int {
  // NetMessage
  net_message_round_trips_json();
  net_message_kind_strings_round_trip();

  // NetMessageBus
  bus_push_and_drain();
  bus_clear();

  // NetSession
  net_session_local_multi_send_and_poll();
  net_session_solo_send_is_noop();
  net_session_online_stub_connect_succeeds();

  // LocalMultiplayerRouter
  local_router_dispatches_player2_input();
  local_router_dispatches_state_sync();

  // RemotePlayerState
  remote_player_state_json_round_trip();

  // BrainBrawlMode remote
  brain_brawl_remote_opponent_bypasses_ghost_ai();

  // ArenaSessionManager multiplayer
  arena_session_manager_multiplayer_session();

  // MatchmakingClient
  matchmaking_client_stub_create_lobby();
  matchmaking_client_stub_join_lobby();
  matchmaking_client_build_relay_config();
  matchmaking_client_empty_room_code_rejected();

  std::fprintf(stderr, "PASS: nexus_net_test\n");
  return 0;
}
