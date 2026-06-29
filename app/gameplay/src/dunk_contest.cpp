// File: app/gameplay/src/dunk_contest.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: Flagship Mode - Basketball Dunk Contest (Venice Beach)
#include "nexus/gameplay/dunk_contest.h"

#include <algorithm>
#include <cmath>
#include <utility>

namespace nexus::gameplay {

namespace {

constexpr int kMinJudgeScore = 1;
constexpr int kMaxJudgeScore = 10;
constexpr double kAttemptScale = 50.0;

auto clampQuality(double quality) -> double {
  return std::clamp(quality, 0.0, 1.0);
}

} // namespace

DunkContest::DunkContest(DunkContestConfig config) : m_config(std::move(config)) {
  m_config.rounds = std::max(1, m_config.rounds);
  m_config.attemptsPerRound = std::max(1, m_config.attemptsPerRound);
  m_config.judges = std::max(1, m_config.judges);
  if (m_config.venueId.empty()) {
    m_config.venueId = "Venice_Beach_Court";
  }
}

auto DunkContest::catalogue() -> const std::vector<DunkType>& {
  // Base difficulty on a 1..10 scale; higher means a harder, higher-ceiling dunk.
  static const std::vector<DunkType> kCatalogue = {
      {"windmill", "Windmill", 8.5},
      {"360", "360 Spin", 9.0},
      {"between_the_legs", "Between the Legs", 9.5},
      {"reverse", "Reverse", 7.5},
      {"alley_oop", "Alley-Oop", 8.0},
  };
  return kCatalogue;
}

auto DunkContest::findDunkType(std::string_view id) -> const DunkType* {
  for (const DunkType& dunk : catalogue()) {
    if (dunk.id == id) {
      return &dunk;
    }
  }
  return nullptr;
}

auto DunkContest::addContestant(std::string contestantId) -> Result<void> {
  if (contestantId.empty()) {
    return Result<void>::err("contestant id must not be empty");
  }
  if (findContestant(contestantId) != nullptr) {
    return Result<void>::err("contestant already registered");
  }
  if (m_contestants.size() >= 2) {
    return Result<void>::err("dunk contest supports at most two contestants");
  }
  m_contestants.push_back(Contestant{std::move(contestantId), {}});
  return Result<void>::ok();
}

auto DunkContest::scoreAttempt(std::string_view contestantId,
                               std::string_view dunkTypeId,
                               double quality,
                               bool completed) -> Result<AttemptScore> {
  Contestant* contestant = findContestant(contestantId);
  if (contestant == nullptr) {
    return Result<AttemptScore>::err("unknown contestant");
  }
  const DunkType* dunk = findDunkType(dunkTypeId);
  if (dunk == nullptr) {
    return Result<AttemptScore>::err("unknown dunk type");
  }
  const auto maxAttempts =
      static_cast<std::size_t>(m_config.rounds) * static_cast<std::size_t>(m_config.attemptsPerRound);
  if (contestant->attempts.size() >= maxAttempts) {
    return Result<AttemptScore>::err("contestant has no remaining attempts");
  }

  const double clampedQuality = clampQuality(quality);

  AttemptScore attempt;
  attempt.dunkTypeId = dunk->id;
  attempt.quality = clampedQuality;
  attempt.completed = completed;
  attempt.judgeScores.reserve(static_cast<std::size_t>(m_config.judges));

  long judgeSum = 0;
  const double midJudge = (m_config.judges - 1) / 2.0;
  for (int j = 0; j < m_config.judges; ++j) {
    int judgeScore = 0;
    if (completed) {
      // Deterministic per-judge variation: judges lean slightly high or low but
      // never break the 1..10 envelope after clamping.
      const double bias = 1.0 + (static_cast<double>(j) - midJudge) * 0.05;
      const double raw = dunk->baseDifficulty * clampedQuality * bias;
      judgeScore = std::clamp(static_cast<int>(std::lround(raw)), kMinJudgeScore, kMaxJudgeScore);
    }
    attempt.judgeScores.push_back(judgeScore);
    judgeSum += judgeScore;
  }

  // Scale the raw judge sum onto a fixed 50-point attempt ceiling so the total
  // is comparable regardless of how many judges are configured.
  const double maxPossible = static_cast<double>(m_config.judges) * kMaxJudgeScore;
  attempt.total = (static_cast<double>(judgeSum) / maxPossible) * kAttemptScale;

  contestant->attempts.push_back(std::move(attempt));
  m_anyScored = true;
  return Result<AttemptScore>::ok(contestant->attempts.back());
}

auto DunkContest::roundScores(std::string_view contestantId) const -> std::vector<double> {
  std::vector<double> rounds(static_cast<std::size_t>(m_config.rounds), 0.0);
  const Contestant* contestant = findContestant(contestantId);
  if (contestant == nullptr) {
    return rounds;
  }
  const auto perRound = static_cast<std::size_t>(m_config.attemptsPerRound);
  for (std::size_t i = 0; i < contestant->attempts.size(); ++i) {
    const std::size_t roundIndex = i / perRound;
    if (roundIndex < rounds.size()) {
      rounds[roundIndex] += contestant->attempts[i].total;
    }
  }
  return rounds;
}

auto DunkContest::contestantTotal(std::string_view contestantId) const -> double {
  const Contestant* contestant = findContestant(contestantId);
  if (contestant == nullptr) {
    return 0.0;
  }
  double total = 0.0;
  for (const AttemptScore& attempt : contestant->attempts) {
    total += attempt.total;
  }
  return total;
}

auto DunkContest::standings() const -> std::vector<DunkStanding> {
  std::vector<DunkStanding> standings;
  standings.reserve(m_contestants.size());
  for (const Contestant& contestant : m_contestants) {
    standings.push_back(DunkStanding{contestant.id, contestantTotal(contestant.id)});
  }
  std::stable_sort(standings.begin(), standings.end(),
                   [](const DunkStanding& lhs, const DunkStanding& rhs) {
                     return lhs.total > rhs.total;
                   });
  return standings;
}

auto DunkContest::winner() const -> DunkWinner {
  DunkWinner result;
  if (!m_anyScored || m_contestants.empty()) {
    return result;
  }
  result.decided = true;
  const auto ranked = standings();
  result.contestantId = ranked.front().contestantId;
  // A tie requires at least two contestants whose top aggregates are equal.
  if (ranked.size() >= 2) {
    constexpr double kEpsilon = 1e-9;
    if (std::abs(ranked[0].total - ranked[1].total) <= kEpsilon) {
      result.tie = true;
      result.contestantId.clear();
    }
  }
  return result;
}

auto DunkContest::toJson() const -> nlohmann::json {
  nlohmann::json contestants = nlohmann::json::array();
  for (const Contestant& contestant : m_contestants) {
    nlohmann::json attempts = nlohmann::json::array();
    for (const AttemptScore& attempt : contestant.attempts) {
      attempts.push_back({
          {"dunk_type", attempt.dunkTypeId},
          {"quality", attempt.quality},
          {"completed", attempt.completed},
          {"judge_scores", attempt.judgeScores},
          {"total", attempt.total},
      });
    }
    contestants.push_back({
        {"id", contestant.id},
        {"round_scores", roundScores(contestant.id)},
        {"total", contestantTotal(contestant.id)},
        {"attempts", std::move(attempts)},
    });
  }

  nlohmann::json standingsJson = nlohmann::json::array();
  for (const DunkStanding& standing : standings()) {
    standingsJson.push_back({{"id", standing.contestantId}, {"total", standing.total}});
  }

  const DunkWinner result = winner();
  return {
      {"venue", m_config.venueId},
      {"config",
       {
           {"rounds", m_config.rounds},
           {"attempts_per_round", m_config.attemptsPerRound},
           {"judges", m_config.judges},
       }},
      {"contestants", std::move(contestants)},
      {"standings", std::move(standingsJson)},
      {"winner",
       {
           {"decided", result.decided},
           {"tie", result.tie},
           {"contestant", result.contestantId},
       }},
  };
}

auto DunkContest::findContestant(std::string_view contestantId) -> Contestant* {
  for (Contestant& contestant : m_contestants) {
    if (contestant.id == contestantId) {
      return &contestant;
    }
  }
  return nullptr;
}

auto DunkContest::findContestant(std::string_view contestantId) const -> const Contestant* {
  for (const Contestant& contestant : m_contestants) {
    if (contestant.id == contestantId) {
      return &contestant;
    }
  }
  return nullptr;
}

} // namespace nexus::gameplay
