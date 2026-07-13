#pragma once

// CELL Agent Swarm — Parallel Agent Fleet
//
// Manages a pool of AgentExecutor workers that consume tasks from a
// shared queue and sync results back through ObservationBus.
//
// Key properties:
//   • Zero-cost inference — no token APIs, all local WisdomStore heuristics
//   • Parallel execution  — N workers process tasks concurrently
//   • Sync via ObservationBus — each completed task is pushed as kAgentOutput
//   • Non-blocking submit  — enqueue returns immediately with a task_id
//   • Bounded queue        — back-pressure via task_queue_cap
//
// Lifecycle:
//   1. Construct with AgentSwarmConfig
//   2. start(wisdom, bus, tools) — spin up worker threads
//   3. submit(AgentTask) → task_id — enqueue work
//   4. result(task_id) → optional<AgentResult> — poll completion
//   5. stop() — drain queue and join threads
//
// Git / terminal / IDE integration:
//   The tool registry is populated by the caller (SelfImprovementScheduler)
//   with GitTool, TerminalTool, and IdeFileTool instances configured for
//   the NEXUS repo root.

#include "nexus/cell/agent_executor.h"
#include "nexus/cell/agent_tool.h"

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <queue>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace nexus::cell {

class ObservationBus;
class WisdomStore;

// ── Config ────────────────────────────────────────────────────────────────────

struct AgentSwarmConfig {
  std::uint32_t max_workers{4};       ///< Parallel worker threads
  std::uint32_t task_queue_cap{64};   ///< Max queued tasks (submit blocks beyond this)
  std::string   repo_root{"."};       ///< Root for GitTool / IdeFileTool sandboxes
  bool          git_allow_write{false}; ///< Allow git add/commit from agent
};

// ── Swarm status ──────────────────────────────────────────────────────────────

struct AgentSwarmStatus {
  std::uint32_t active_workers{0};
  std::uint32_t queued_tasks{0};
  std::uint64_t completed_tasks{0};
  std::uint64_t failed_tasks{0};
};

// ── Swarm ─────────────────────────────────────────────────────────────────────

class AgentSwarm {
public:
  explicit AgentSwarm(AgentSwarmConfig config = {});
  ~AgentSwarm();

  AgentSwarm(const AgentSwarm&)            = delete;
  AgentSwarm& operator=(const AgentSwarm&) = delete;

  /// Spin up worker threads.  Must be called before submit().
  void start(WisdomStore& wisdom, ObservationBus& bus);

  /// Gracefully drain the queue and join worker threads.
  void stop();

  /// Enqueue a task.  Returns the task_id (echoes task.task_id if non-empty,
  /// else generates one).  Non-blocking unless the queue is at capacity.
  [[nodiscard]] auto submit(AgentTask task) -> std::string;

  /// Poll the result for a completed task.  Returns nullopt if not yet done.
  [[nodiscard]] auto result(const std::string& task_id) const
      -> std::optional<AgentResult>;

  [[nodiscard]] auto status() const -> AgentSwarmStatus;
  [[nodiscard]] auto isRunning() const -> bool { return m_running.load(); }

private:
  void workerLoop(WisdomStore* wisdom, ObservationBus* bus);

  void storeResult(AgentResult result);

  AgentSwarmConfig m_config;

  // Tool registry shared across all workers (thread-safe execute())
  AgentToolRegistry m_toolRegistry;

  // Task queue
  mutable std::mutex      m_queueMutex;
  std::condition_variable m_queueCv;
  std::queue<AgentTask>   m_taskQueue;

  // Result store
  mutable std::mutex                             m_resultMutex;
  std::unordered_map<std::string, AgentResult>   m_results;

  // Worker threads
  std::vector<std::thread>      m_workers;
  std::atomic<bool>             m_running{false};
  std::atomic<bool>             m_stopping{false};
  std::atomic<std::uint32_t>    m_activeWorkers{0};
  std::atomic<std::uint64_t>    m_completedTasks{0};
  std::atomic<std::uint64_t>    m_failedTasks{0};

  // Task ID counter
  std::atomic<std::uint64_t> m_taskCounter{0};
};

} // namespace nexus::cell
