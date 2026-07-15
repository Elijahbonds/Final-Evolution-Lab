#include "nexus/cell/research_loop.h"
#include "nexus/core/log.h"

namespace nexus::cell {

ResearchLoop::ResearchLoop(ResearchLoopConfig config) : m_config(std::move(config)) {}

auto ResearchLoop::isOnlineLearningEnabled() const -> bool {
#if CELL_ONLINE_LEARNING
  return true;
#else
  return false;
#endif
}

auto ResearchLoop::tick() -> Result<void> {
#if !CELL_ONLINE_LEARNING
  // Online learning is disabled at compile time.  This is intentional —
  // learning happens via nightly BatchLearner instead.
  return Result<void>::ok();
#else
  // Budget gate: every LLM-consuming tick checks the meter first.
  if (!BudgetMeter::instance().consume(m_config.subsystemName, m_config.tokensPerCycle)) {
    return Result<void>::err("[ResearchLoop] Daily token cap reached — skipping cycle.");
  }
  // TODO: implement online research cycle body when CELL_ONLINE_LEARNING=1.
  NEXUS_LOG_INFO(nexus::LogChannel::kCell, "[ResearchLoop] Online tick (budget consumed).");
  return Result<void>::ok();
#endif
}

} // namespace nexus::cell
