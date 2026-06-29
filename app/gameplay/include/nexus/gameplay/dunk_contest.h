// File: app/gameplay/include/nexus/gameplay/dunk_contest.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: Flagship Mode - Basketball Dunk Contest (Venice Beach)
#pragma once

#include "nexus/core/result.h"

#include <cstddef>
#include <nlohmann/json.hpp>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

/// A single dunk in the catalogue with a base difficulty on a 1..10 scale.
struct DunkType {
  // Stable identifier used in commands (e.g. "windmill", "360").
  std::string id;
  // Human-readable display name.
  std::string name;
  // Base difficulty, 1.0 (easy) .. 10.0 (hardest), used as the scoring ceiling.
  double baseDifficulty{1.0};
};

/// Tunable parameters for a dunk contest session.
struct DunkContestConfig {
  // Number of scoring rounds in the contest.
  int rounds{2};
  // Attempts each contestant takes per round.
  int attemptsPerRound{2};
  // Number of judges; each judge awards an integer 1..10 score.
  int judges{5};
  // Venue identifier (flagship venue is Venice Beach).
  std::string venueId{"Venice_Beach_Court"};
};

/// Deterministic result of a single scored dunk attempt.
struct AttemptScore {
  // The dunk type identifier that was attempted.
  std::string dunkTypeId;
  // Execution quality in [0, 1] used to compute the score.
  double quality{0.0};
  // Whether the dunk was completed; a miss scores zero.
  bool completed{false};
  // Per-judge integer scores. Completed dunks are clamped to [1, 10];
  // a missed dunk yields 0 from every judge.
  std::vector<int> judgeScores;
  // Attempt total scaled to a 50-point maximum.
  double total{0.0};
};

/// Final placement decision for the contest.
struct DunkWinner {
  // True once at least one attempt has been scored.
  bool decided{false};
  // True when the top aggregate scores are equal (a tie).
  bool tie{false};
  // Winning contestant id (empty when tied or undecided).
  std::string contestantId;
};

/// A single contestant's accumulated standing.
struct DunkStanding {
  std::string contestantId;
  // Sum of every scored attempt across all rounds, on the 50-point scale.
  double total{0.0};
};

/// Deterministic, render-free Basketball Dunk Contest game mode.
///
/// Supports head-to-head play for up to two contestants. All scoring is a pure
/// function of (dunk difficulty, execution quality, completion) so replays are
/// reproducible across runs and platforms.
class DunkContest {
public:
  explicit DunkContest(DunkContestConfig config = {});

  /// Returns the immutable catalogue of supported dunk types.
  [[nodiscard]] static auto catalogue() -> const std::vector<DunkType>&;

  /// Finds a dunk type by id, or nullptr when unknown.
  [[nodiscard]] static auto findDunkType(std::string_view id) -> const DunkType*;

  [[nodiscard]] auto config() const -> const DunkContestConfig& { return m_config; }

  /// Registers a contestant. Fails on duplicates or beyond the 2-player cap.
  auto addContestant(std::string contestantId) -> Result<void>;

  [[nodiscard]] auto contestantCount() const -> std::size_t { return m_contestants.size(); }

  /// Scores one attempt for a registered contestant. Judge scores are a
  /// deterministic function of difficulty*quality (clamped 1..10); a missed
  /// dunk scores zero. The attempt is recorded for round/total accumulation.
  auto scoreAttempt(std::string_view contestantId,
                    std::string_view dunkTypeId,
                    double quality,
                    bool completed) -> Result<AttemptScore>;

  /// Computes per-round totals (size == config rounds) for a contestant.
  [[nodiscard]] auto roundScores(std::string_view contestantId) const -> std::vector<double>;

  /// Aggregate total across every scored attempt for a contestant.
  [[nodiscard]] auto contestantTotal(std::string_view contestantId) const -> double;

  /// Standings sorted by total descending (ties keep registration order).
  [[nodiscard]] auto standings() const -> std::vector<DunkStanding>;

  /// Resolves the winner using the highest-aggregate rule, flagging ties.
  [[nodiscard]] auto winner() const -> DunkWinner;

  /// Full JSON snapshot of config, contestants, per-round scores and winner.
  [[nodiscard]] auto toJson() const -> nlohmann::json;

private:
  struct Contestant {
    std::string id;
    std::vector<AttemptScore> attempts;
  };

  [[nodiscard]] auto findContestant(std::string_view contestantId) -> Contestant*;
  [[nodiscard]] auto findContestant(std::string_view contestantId) const -> const Contestant*;

  DunkContestConfig m_config;
  std::vector<Contestant> m_contestants;
  bool m_anyScored{false};
};

} // namespace nexus::gameplay
