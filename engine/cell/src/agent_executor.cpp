#include "nexus/cell/agent_executor.h"

#include "nexus/core/log.h"

#include <algorithm>
#include <chrono>
#include <sstream>
#include <string>

namespace nexus::cell {

namespace {

auto nowMs() -> double {
  using namespace std::chrono;
  return static_cast<double>(
      duration_cast<microseconds>(steady_clock::now().time_since_epoch()).count()) / 1000.0;
}

auto nowSeconds() -> double {
  using namespace std::chrono;
  return duration_cast<duration<double>>(steady_clock::now().time_since_epoch()).count();
}

/// Lowercase a string for keyword matching.
auto toLower(std::string s) -> std::string {
  std::transform(s.begin(), s.end(), s.begin(), ::tolower);
  return s;
}

/// Count how many keywords from `tokens` appear in `text`.
auto countKeywordHits(const std::string& text,
                      const std::vector<std::string>& tokens) -> std::size_t {
  std::size_t hits = 0;
  const std::string lower = toLower(text);
  for (const auto& tok : tokens) {
    if (lower.find(tok) != std::string::npos) { ++hits; }
  }
  return hits;
}

/// Extract keyword tokens from a prompt (simple whitespace split, lowercased).
auto extractTokens(const std::string& text) -> std::vector<std::string> {
  std::vector<std::string> tokens;
  std::istringstream iss(toLower(text));
  std::string word;
  while (iss >> word) {
    // Strip common punctuation
    while (!word.empty() && !std::isalnum(static_cast<unsigned char>(word.back()))) {
      word.pop_back();
    }
    if (word.size() >= 3) { tokens.push_back(word); }
  }
  return tokens;
}

/// Terminal tokens that signal task completion.
static const std::vector<std::string> kDoneTokens = {
    "done", "success", "complete", "finished", "ok", "passed", "found",
    "error", "failed", "no such"  // error/fail states also terminate the loop
};

} // namespace

// ── Constructor ───────────────────────────────────────────────────────────────

AgentExecutor::AgentExecutor(WisdomStore& wisdom, ObservationBus& bus,
                             const AgentToolRegistry& tools)
    : m_wisdom(wisdom), m_bus(bus), m_tools(tools) {}

// ── Main entry point ──────────────────────────────────────────────────────────

auto AgentExecutor::run(const AgentTask& task) -> AgentResult {
  AgentResult result;
  result.task_id = task.task_id;

  const double t_start = nowMs();

  NEXUS_LOG_INFO(LogChannel::kCell,
                 "[CELL Agent] task=" + task.task_id + " prompt=" + task.prompt);

  std::vector<AgentStepTrace> trace;

  for (std::uint32_t step = 0; step < task.max_steps; ++step) {
    // ── Think ─────────────────────────────────────────────────────────────────
    auto thought = think(task, trace);

    if (thought.should_stop) {
      NEXUS_LOG_INFO(LogChannel::kCell,
                     "[CELL Agent] task=" + task.task_id + " stop at step " +
                         std::to_string(step));
      break;
    }

    // ── Act ───────────────────────────────────────────────────────────────────
    const AgentTool* tool = m_tools.tool(thought.selected_tool);
    ToolResult tool_result;

    if (!tool) {
      tool_result = ToolResult{false, "", "tool '" + thought.selected_tool + "' not found"};
    } else {
      tool_result = tool->execute(thought.tool_params);
    }

    // ── Observe ───────────────────────────────────────────────────────────────
    AgentStepTrace step_trace;
    step_trace.step        = step;
    step_trace.thought     = thought.thought;
    step_trace.tool_name   = thought.selected_tool;
    step_trace.tool_params = thought.tool_params;
    step_trace.tool_result = tool_result;
    trace.push_back(step_trace);

    // Push into ObservationBus so ResearchLoop can learn from tool outcomes
    m_bus.push(Observation{
        ObservationType::kAgentOutput,
        "cell_agent_" + task.task_id,
        {{"step",       step},
         {"tool",       thought.selected_tool},
         {"ok",         tool_result.ok},
         {"output_len", static_cast<int>(tool_result.output.size())},
         {"thought",    thought.thought}},
        nowSeconds()});

    // ── Done detection ────────────────────────────────────────────────────────
    if (isDone(task, step_trace)) {
      break;
    }
  }

  result.steps_used   = static_cast<std::uint32_t>(trace.size());
  result.trace        = std::move(trace);
  result.duration_ms  = nowMs() - t_start;
  result.summary      = buildSummary(task, result.trace);
  result.ok           = !result.trace.empty() && result.trace.back().tool_result.ok;

  NEXUS_LOG_INFO(LogChannel::kCell,
                 "[CELL Agent] task=" + task.task_id +
                     " done ok=" + (result.ok ? "true" : "false") +
                     " steps=" + std::to_string(result.steps_used) +
                     " ms=" + std::to_string(static_cast<int>(result.duration_ms)));

  // Final observation: task summary
  m_bus.push(Observation{
      ObservationType::kAgentOutput,
      "cell_agent",
      {{"task_id",    task.task_id},
       {"ok",         result.ok},
       {"steps_used", result.steps_used},
       {"duration_ms",result.duration_ms},
       {"reward",     result.ok ? 0.9 : 0.2}},
      nowSeconds()});

  return result;
}

// ── Think step ────────────────────────────────────────────────────────────────

auto AgentExecutor::think(const AgentTask& task,
                           const std::vector<AgentStepTrace>& trace) -> ThinkResult {
  ThinkResult result;

  // Build current context from the prompt + recent tool outputs
  std::string context = task.prompt;
  if (!trace.empty()) {
    const auto& last = trace.back();
    context += " | last_tool=" + last.tool_name +
               " last_ok=" + (last.tool_result.ok ? "1" : "0") +
               " last_out=" + last.tool_result.output.substr(
                   0, std::min<std::size_t>(200, last.tool_result.output.size()));
  }

  // Query WisdomStore for relevant heuristics
  const auto tokens       = extractTokens(context);
  std::vector<WisdomEntry> relevant_wisdom;
  for (const auto& tok : tokens) {
    auto entries = m_wisdom.query(tok);
    for (auto& e : entries) {
      if (e.confidence > 0.3) { relevant_wisdom.push_back(std::move(e)); }
    }
  }
  // Also pull top-N global wisdom
  {
    auto top = m_wisdom.topN(5);
    for (auto& e : top) { relevant_wisdom.push_back(std::move(e)); }
  }

  // Score available tools against current context + wisdom
  auto scored = scoreTools(context, task.allowed_tools, relevant_wisdom);

  if (scored.empty()) {
    result.should_stop = true;
    result.thought = "No applicable tools available — stopping.";
    return result;
  }

  const auto& [best_tool, score] = scored.front();

  result.selected_tool = best_tool;
  result.tool_params   = buildToolParams(best_tool, context, task, trace);

  // Thought summary
  std::ostringstream oss;
  oss << "Selected tool=" << best_tool << " score=" << score;
  if (!relevant_wisdom.empty()) {
    oss << " wisdom_hits=" << relevant_wisdom.size();
    oss << " top_rule=\"" << relevant_wisdom.front().rule_text.substr(
               0, std::min<std::size_t>(60, relevant_wisdom.front().rule_text.size()))
        << "\"";
  }
  result.thought = oss.str();

  return result;
}

// ── Tool scoring ──────────────────────────────────────────────────────────────

auto AgentExecutor::scoreTools(const std::string& context,
                                const std::vector<std::string>& allowed_tools,
                                const std::vector<WisdomEntry>& wisdom) const
    -> std::vector<std::pair<std::string, double>> {
  // Tool-to-keyword affinity map
  static const std::unordered_map<std::string, std::vector<std::string>> kAffinity = {
      {"git",      {"git", "commit", "diff", "branch", "status", "log",
                    "change", "modified", "staged", "repo", "revision"}},
      {"terminal", {"cat", "ls", "find", "grep", "head", "tail", "read", "list",
                    "search", "show", "print", "file", "directory", "count"}},
      {"ide_file", {"file", "read", "source", "code", "header", "cpp", "swift",
                    "json", "yaml", "md", "content", "view", "open"}},
  };

  const std::vector<std::string> ctx_tokens = extractTokens(context);

  std::vector<std::pair<std::string, double>> scores;

  for (const auto& tool_name : allowed_tools) {
    double score = 0.0;

    // Keyword affinity bonus
    const auto it = kAffinity.find(tool_name);
    if (it != kAffinity.end()) {
      score += static_cast<double>(countKeywordHits(context, it->second)) * 0.15;
    }

    // Wisdom bonus: rules that mention this tool or its domain
    for (const auto& e : wisdom) {
      if (toLower(e.rule_text).find(tool_name) != std::string::npos) {
        score += e.confidence * 0.25;
      }
    }

    // Small freshness penalty for recently used tools to encourage variety
    // (last step used same tool → reduce score slightly)
    // (not implemented here — kept simple)

    scores.emplace_back(tool_name, score);
  }

  // Sort descending
  std::sort(scores.begin(), scores.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });

  return scores;
}

// ── Build tool params ─────────────────────────────────────────────────────────

auto AgentExecutor::buildToolParams(const std::string& tool_name,
                                     const std::string& context,
                                     const AgentTask& task,
                                     const std::vector<AgentStepTrace>& trace) const
    -> nlohmann::json {
  nlohmann::json params = nlohmann::json::object();
  const auto tokens = extractTokens(context);

  if (tool_name == "git") {
    // Determine subcommand heuristically
    std::string subcmd = "status"; // safe default
    if (countKeywordHits(context, {"diff", "change", "modified"})) {
      subcmd = "diff";
    } else if (countKeywordHits(context, {"log", "history", "commit"})) {
      subcmd = "log";
      params["args"] = "--oneline -10";
    } else if (countKeywordHits(context, {"branch", "branches"})) {
      subcmd = "branch";
    }
    params["subcommand"] = subcmd;
  } else if (tool_name == "terminal") {
    // Build a safe command from context keywords
    std::string cmd = "ls -la"; // default
    if (countKeywordHits(context, {"grep", "search", "find"})) {
      // Extract a search term from tokens
      std::string term;
      for (const auto& t : tokens) {
        if (t.size() > 4) { term = t; break; }
      }
      cmd = "grep -r " + (term.empty() ? "TODO" : term) + " --include='*.cpp' -l 2>/dev/null | head -20";
    } else if (countKeywordHits(context, {"cat", "read", "content"})) {
      // Extract file path hint from context
      cmd = "ls -la";
    } else if (countKeywordHits(context, {"count", "wc", "lines"})) {
      cmd = "find . -name '*.cpp' -o -name '*.h' | xargs wc -l 2>/dev/null | tail -5";
    }
    params["command"] = cmd;
  } else if (tool_name == "ide_file") {
    // Try to infer a file path from the task prompt
    std::string path = "engine/cell/include/nexus/cell/cell_types.h"; // fallback
    // Look for a .h, .cpp, .swift, .json, .md token in context
    for (const auto& tok : tokens) {
      if (tok.size() > 4 &&
          (tok.rfind(".h") != std::string::npos   ||
           tok.rfind(".cpp") != std::string::npos  ||
           tok.rfind(".swift") != std::string::npos||
           tok.rfind(".json") != std::string::npos ||
           tok.rfind(".md") != std::string::npos)) {
        path = tok;
        break;
      }
    }
    params["path"]      = path;
    params["max_lines"] = 100;
  }

  return params;
}

// ── Done detection ────────────────────────────────────────────────────────────

auto AgentExecutor::isDone(const AgentTask& task,
                            const AgentStepTrace& last_step) const -> bool {
  // Always stop on tool error — avoid spinning on broken tools
  if (!last_step.tool_result.ok && !last_step.tool_result.error.empty()) {
    return true;
  }

  // Check if the output contains a terminal signal
  const std::string lower_out = toLower(last_step.tool_result.output);
  for (const auto& tok : kDoneTokens) {
    if (lower_out.find(tok) != std::string::npos) { return true; }
  }

  // Check if the task prompt keywords are satisfied by the output
  const auto task_tokens = extractTokens(task.prompt);
  std::size_t satisfied = 0;
  for (const auto& tok : task_tokens) {
    if (lower_out.find(tok) != std::string::npos) { ++satisfied; }
  }
  if (!task_tokens.empty() &&
      static_cast<double>(satisfied) / task_tokens.size() > 0.5) {
    return true;
  }

  return false;
}

// ── Summary builder ───────────────────────────────────────────────────────────

auto AgentExecutor::buildSummary(const AgentTask& task,
                                  const std::vector<AgentStepTrace>& trace) const
    -> std::string {
  if (trace.empty()) {
    return "No steps executed for task: " + task.task_id;
  }

  const auto& last = trace.back();

  // Use the last tool output as the summary (truncated)
  std::string out = last.tool_result.output;
  if (out.size() > 512) {
    out = out.substr(0, 512) + "\n[…truncated…]";
  }
  if (out.empty()) {
    out = last.tool_result.error.empty() ? "(no output)" : last.tool_result.error;
  }

  return "task=" + task.task_id + " steps=" + std::to_string(trace.size()) +
         " last_tool=" + last.tool_name + "\n" + out;
}

} // namespace nexus::cell
