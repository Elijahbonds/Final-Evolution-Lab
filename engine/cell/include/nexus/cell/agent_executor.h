#pragma once

// CELL Agent Executor — Zero-Cost Local ReAct Loop
//
// Executes a single task using a Reason + Act cycle driven entirely by
// local WisdomStore heuristics and tool calls.  No external API, no tokens,
// no per-query cost — intelligence comes from accumulated NEXUS knowledge.
//
// ReAct loop (max_steps bounded):
//   1. Think  — query WisdomStore for rules matching the current context,
//               score candidate tools, decide the next action.
//   2. Act    — invoke the selected AgentTool with derived params.
//   3. Observe — record the tool result into the trace and ObservationBus.
//   4. Repeat until the task is considered done or max_steps is reached.
//
// Done-detection heuristic:
//   - The last tool returned non-empty output AND no error AND the output
//     contains a terminal token ("done", "success", "complete", "ok",
//     or the task keywords are satisfied).
//   - Fallback: max_steps exhausted.
//
// Thread safety:
//   run() is blocking and designed to be called from a single worker thread.
//   Multiple AgentExecutor instances can run concurrently (AgentSwarm).

#include "nexus/cell/agent_tool.h"
#include "nexus/cell/observation_bus.h"
#include "nexus/cell/wisdom_store.h"

#include <nlohmann/json.hpp>

#include <cstdint>
#include <string>
#include <vector>

namespace nexus::cell {

// ── Task descriptor ───────────────────────────────────────────────────────────

struct AgentTask {
  std::string              task_id;
  std::string              prompt;        ///< Natural-language task description
  std::vector<std::string> allowed_tools; ///< Tool names available for this task
  std::uint32_t            max_steps{10};
  double                   wisdom_weight{0.6}; ///< 0–1 how much to trust WisdomStore vs keywords
};

// ── Step trace entry ──────────────────────────────────────────────────────────

struct AgentStepTrace {
  std::uint32_t step{0};
  std::string   thought;     ///< Reasoning summary
  std::string   tool_name;
  nlohmann::json tool_params;
  ToolResult     tool_result;
};

// ── Result ────────────────────────────────────────────────────────────────────

struct AgentResult {
  std::string                 task_id;
  bool                        ok{false};
  std::string                 summary;    ///< Final answer / summary
  std::vector<AgentStepTrace> trace;
  std::uint32_t               steps_used{0};
  double                      duration_ms{0.0};
};

// ── Executor ──────────────────────────────────────────────────────────────────

class AgentExecutor {
public:
  AgentExecutor(WisdomStore& wisdom, ObservationBus& bus,
                const AgentToolRegistry& tools);

  /// Execute a task synchronously.  Blocks until done or max_steps exhausted.
  [[nodiscard]] auto run(const AgentTask& task) -> AgentResult;

private:
  // ── ReAct internals ──────────────────────────────────────────────────────

  struct ThinkResult {
    std::string   thought;
    std::string   selected_tool;
    nlohmann::json tool_params;
    bool          should_stop{false};
  };

  [[nodiscard]] auto think(const AgentTask& task,
                           const std::vector<AgentStepTrace>& trace) -> ThinkResult;

  [[nodiscard]] auto scoreTools(const std::string& context,
                                const std::vector<std::string>& allowed_tools,
                                const std::vector<WisdomEntry>& wisdom) const
      -> std::vector<std::pair<std::string, double>>;

  [[nodiscard]] auto buildToolParams(const std::string& tool_name,
                                     const std::string& context,
                                     const AgentTask&   task,
                                     const std::vector<AgentStepTrace>& trace) const
      -> nlohmann::json;

  [[nodiscard]] auto isDone(const AgentTask& task,
                             const AgentStepTrace& last_step) const -> bool;

  [[nodiscard]] auto buildSummary(const AgentTask& task,
                                   const std::vector<AgentStepTrace>& trace) const
      -> std::string;

  WisdomStore&              m_wisdom;
  ObservationBus&           m_bus;
  const AgentToolRegistry&  m_tools;
};

} // namespace nexus::cell
