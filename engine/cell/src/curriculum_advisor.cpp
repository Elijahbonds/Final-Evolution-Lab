#include "nexus/cell/curriculum_advisor.h"

#include <algorithm>
#include <chrono>
#include <map>
#include <string>

namespace nexus::cell {

namespace {

auto nowMs() -> std::uint64_t {
  using namespace std::chrono;
  return static_cast<std::uint64_t>(
      duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count());
}

auto clamp01(double v) -> double {
  return std::max(0.0, std::min(1.0, v));
}

struct SkillAccumulator {
  std::vector<double> rewards; ///< clamped to [0,1], oldest first
};

} // namespace

CurriculumAdvisor::CurriculumAdvisor(CurriculumAdvisorConfig config)
    : m_config(std::move(config)) {}

auto CurriculumAdvisor::isExcluded(const std::string& source) const -> bool {
  if (source.empty()) { return true; }
  for (const auto& prefix : m_config.exclude_source_prefixes) {
    if (source.rfind(prefix, 0) == 0) { return true; }
  }
  return false;
}

auto CurriculumAdvisor::computeFocusAreas(const ExperienceLedger& ledger,
                                          const WisdomStore& wisdom) const
    -> std::vector<FocusArea> {
  const auto records = ledger.queryRecent(m_config.ledger_window);

  // Group clamped rewards per skill (source_system), oldest first —
  // queryRecent returns newest-last which preserves chronological order.
  std::map<std::string, SkillAccumulator> skills;
  for (const auto& rec : records) {
    if (isExcluded(rec.source_system)) { continue; }
    skills[rec.source_system].rewards.push_back(clamp01(rec.reward_signal));
  }

  std::vector<FocusArea> areas;
  areas.reserve(skills.size());

  for (const auto& [skill, acc] : skills) {
    const auto& rewards = acc.rewards;
    if (rewards.size() < m_config.min_evidence) { continue; }

    double sum = 0.0;
    for (const double r : rewards) { sum += r; }
    const double mean = sum / static_cast<double>(rewards.size());

    // Trend: compare mean of the older half vs. the newer half.
    std::string trend = "flat";
    if (rewards.size() >= 4) {
      const std::size_t half = rewards.size() / 2;
      double oldSum = 0.0;
      double newSum = 0.0;
      for (std::size_t i = 0; i < half; ++i)               { oldSum += rewards[i]; }
      for (std::size_t i = half; i < rewards.size(); ++i)  { newSum += rewards[i]; }
      const double oldMean = oldSum / static_cast<double>(half);
      const double newMean = newSum / static_cast<double>(rewards.size() - half);
      if (newMean - oldMean >  m_config.trend_epsilon) { trend = "improving"; }
      if (oldMean - newMean >  m_config.trend_epsilon) { trend = "declining"; }
    }

    // Base confidence saturates with evidence volume.
    const double n = static_cast<double>(rewards.size());
    double confidence = n / (n + m_config.confidence_saturation);

    double weakness = clamp01(1.0 - mean);

    // Supporting wisdom rules for the skill domain (highest confidence first).
    // High-confidence "degrades" rules nudge weakness up slightly; wisdom
    // confidence blends into the overall confidence (70/30 evidence/wisdom).
    std::vector<std::string> ruleTexts;
    const auto entries = wisdom.query(skill);
    if (!entries.empty()) {
      double wisdomConfSum = 0.0;
      for (const auto& e : entries) {
        if (ruleTexts.size() < m_config.max_rules_per_area) {
          ruleTexts.push_back(e.rule_text);
        }
        wisdomConfSum += e.confidence;
        if (e.confidence >= 0.5 &&
            e.rule_text.find("degrades") != std::string::npos) {
          weakness = clamp01(weakness + 0.05 * e.confidence);
        }
      }
      const double wisdomMean = wisdomConfSum / static_cast<double>(entries.size());
      confidence = clamp01(0.7 * confidence + 0.3 * wisdomMean);
    }

    FocusArea area;
    area.skill            = skill;
    area.weakness_score   = weakness;
    area.confidence       = confidence;
    area.priority         = clamp01(weakness * confidence);
    area.evidence_count   = static_cast<std::uint64_t>(rewards.size());
    area.mean_reward      = mean;
    area.trend            = trend;
    area.supporting_rules = std::move(ruleTexts);
    area.recommendation   = weakness >= 0.6   ? "prioritize"
                            : weakness <= 0.3 ? "maintain"
                                              : "monitor";
    areas.push_back(std::move(area));
  }

  std::sort(areas.begin(), areas.end(), [](const FocusArea& a, const FocusArea& b) {
    if (a.priority != b.priority) { return a.priority > b.priority; }
    return a.skill < b.skill; // deterministic tiebreak
  });

  if (areas.size() > m_config.max_focus_areas) {
    areas.resize(m_config.max_focus_areas);
  }
  return areas;
}

auto CurriculumAdvisor::focusAreaToJson(const FocusArea& area) -> nlohmann::json {
  nlohmann::json rules = nlohmann::json::array();
  for (const auto& r : area.supporting_rules) { rules.push_back(r); }
  return {{"skill",            area.skill},
          {"weakness_score",   area.weakness_score},
          {"confidence",       area.confidence},
          {"priority",         area.priority},
          {"evidence_count",   area.evidence_count},
          {"mean_reward",      area.mean_reward},
          {"trend",            area.trend},
          {"recommendation",   area.recommendation},
          {"supporting_rules", std::move(rules)}};
}

auto CurriculumAdvisor::focusReport(const ExperienceLedger& ledger,
                                    const WisdomStore& wisdom) const
    -> nlohmann::json {
  const auto areas = computeFocusAreas(ledger, wisdom);
  nlohmann::json arr = nlohmann::json::array();
  for (const auto& a : areas) { arr.push_back(focusAreaToJson(a)); }

  const std::size_t analysed =
      std::min(m_config.ledger_window, ledger.totalCount());

  return {{"version",         1},
          {"generated_at_ms", nowMs()},
          {"focus_areas",     std::move(arr)},
          {"inputs", {{"ledger_records_analysed", analysed},
                      {"wisdom_entries",          wisdom.count()}}}};
}

} // namespace nexus::cell
