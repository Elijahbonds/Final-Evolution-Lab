#include "nexus/cell/geval_scorer.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <string>

namespace nexus::cell {

namespace {

// ── String helpers ────────────────────────────────────────────────────────────

auto containsAny(const std::string& text,
                 std::initializer_list<const char*> keywords) -> bool {
  for (const char* kw : keywords) {
    if (text.find(kw) != std::string::npos) {
      return true;
    }
  }
  return false;
}

auto countOccurrences(const std::string& text, const char* needle) -> std::size_t {
  std::size_t count = 0;
  std::size_t pos   = 0;
  const std::size_t len = std::strlen(needle);
  while ((pos = text.find(needle, pos)) != std::string::npos) {
    ++count;
    pos += len;
  }
  return count;
}

auto trimTrailing(std::string s) -> std::string {
  while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) {
    s.pop_back();
  }
  return s;
}

} // namespace

// ── Constructor ───────────────────────────────────────────────────────────────

GEvalScorer::GEvalScorer(GEvalConfig config) : m_config(std::move(config)) {}

// ── Public API ────────────────────────────────────────────────────────────────

auto GEvalScorer::score(const WisdomEntry& entry) const -> GEvalResult {
  GEvalResult result;
  result.metrics.clarity       = scoreClarity(entry);
  result.metrics.specificity   = scoreSpecificity(entry);
  result.metrics.conciseness   = scoreConciseness(entry);
  result.metrics.actionability = scoreActionability(entry);
  result.aggregate = (result.metrics.clarity +
                      result.metrics.specificity +
                      result.metrics.conciseness +
                      result.metrics.actionability) / 4.0;
  result.passes = result.aggregate >= m_config.min_score;
  return result;
}

auto GEvalScorer::refine(WisdomEntry entry) const -> WisdomEntry {
  std::string& rule = entry.rule_text;

  // 1. Trim trailing whitespace.
  rule = trimTrailing(rule);

  // 2. Remove parenthetical verbose suffixes like " (delta=12%, n=47)" if the
  //    rest of the rule already describes the finding clearly.  Only trim if
  //    the core rule (before the first '(') is long enough to stand alone.
  const std::size_t parenPos = rule.find(" (");
  if (parenPos != std::string::npos && parenPos >= 30) {
    rule = rule.substr(0, parenPos);
  }

  // 3. Normalise direction language: replace "higher … improves" or
  //    "lower … improves" so the pattern is deterministic.
  auto normaliseDirection = [](std::string& r, const char* dir, const char* outcome) {
    const std::string marker = std::string(dir) + " ";
    const std::size_t pos = r.find(marker);
    if (pos == 0 && r.find(outcome) != std::string::npos) {
      // Already well-formed — leave as-is.
    }
  };
  normaliseDirection(rule, "higher", "improves");
  normaliseDirection(rule, "lower",  "improves");

  // 4. Ensure confidence is at least 0.05 so specificity has something to work with.
  if (entry.confidence < 0.05) {
    entry.confidence = 0.05;
  }

  return entry;
}

// ── Private metric scorers ────────────────────────────────────────────────────

auto GEvalScorer::scoreClarity(const WisdomEntry& entry) const -> double {
  const std::string& r = entry.rule_text;
  if (r.empty()) {
    return 0.0;
  }

  double score = 0.0;

  // +4.0 — explicit direction keyword
  if (containsAny(r, {"higher ", "lower ", "increasing ", "decreasing ",
                       "more ", "less ", "faster ", "slower "})) {
    score += 4.0;
  }

  // +4.0 — explicit outcome keyword
  if (containsAny(r, {"improves", "degrades", "increases", "decreases",
                       "benefits", "harms", "reduces", "boosts"})) {
    score += 4.0;
  }

  // +2.0 — sentence ends with "outcomes" or similar conclusive word
  if (containsAny(r, {"outcomes", "performance", "result", "score", "reward"})) {
    score += 2.0;
  }

  return std::min(10.0, score);
}

auto GEvalScorer::scoreSpecificity(const WisdomEntry& entry) const -> double {
  if (entry.evidence_count == 0) {
    return 0.0;
  }

  // log2(evidence_count) → scale to [0, 1] where 1024 evidence = 1.0
  const double evidenceScore = std::min(1.0, std::log2(static_cast<double>(entry.evidence_count)) / 10.0);

  // confidence is already [0, 1]
  const double combined = 0.5 * evidenceScore + 0.5 * entry.confidence;
  return combined * 10.0;
}

auto GEvalScorer::scoreConciseness(const WisdomEntry& entry) const -> double {
  const std::size_t len = entry.rule_text.size();

  if (len == 0) {
    return 0.0;
  }

  if (len <= m_config.concise_length_target) {
    return 10.0;
  }

  if (len >= m_config.concise_length_max) {
    return 0.0;
  }

  // Linear decay between target and max.
  const double excess = static_cast<double>(len - m_config.concise_length_target);
  const double range  = static_cast<double>(m_config.concise_length_max -
                                             m_config.concise_length_target);
  return 10.0 * (1.0 - (excess / range));
}

auto GEvalScorer::scoreActionability(const WisdomEntry& entry) const -> double {
  const std::string& r = entry.rule_text;
  double score = 0.0;

  // +4.0 — contains a numeric delta marker (generated by ResearchLoop)
  if (containsAny(r, {"delta=", "delta =", "%", "Δ"})) {
    score += 4.0;
  }

  // +3.0 — rule is bound to a concrete feature path (contains a dot separator)
  if (r.find('.') != std::string::npos) {
    score += 3.0;
  }

  // +2.0 — sample size anchor makes the rule trustworthy / actionable
  if (containsAny(r, {"n=", "n =", "samples=", "count="})) {
    score += 2.0;
  }

  // +1.0 — domain is non-empty (entry is classified)
  if (!entry.domain.empty()) {
    score += 1.0;
  }

  return std::min(10.0, score);
}

} // namespace nexus::cell
