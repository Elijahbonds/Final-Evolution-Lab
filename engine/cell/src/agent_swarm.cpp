#include "nexus/cell/agent_swarm.h"

#include "nexus/cell/observation_bus.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/log.h"

#include <chrono>
#include <sstream>

namespace nexus::cell {

// ── Constructor / Destructor ──────────────────────────────────────────────────

AgentSwarm::AgentSwarm(AgentSwarmConfig config) : m_config(std::move(config)) {}

AgentSwarm::~AgentSwarm() {
  if (m_running.load()) {
    stop();
  }
}

// ── Start ─────────────────────────────────────────────────────────────────────

void AgentSwarm::start(WisdomStore& wisdom, ObservationBus& bus) {
  if (m_running.exchange(true)) {
    return; // Already running
  }

  m_stopping.store(false);

  // Populate the shared tool registry.
  // Each tool is stateless in execute(), so sharing across workers is safe.
  m_toolRegistry = AgentToolRegistry{};
  m_toolRegistry.registerTool(std::make_unique<GitTool>(
      GitToolConfig{m_config.repo_root, m_config.git_allow_write}));
  m_toolRegistry.registerTool(std::make_unique<TerminalTool>(
      TerminalToolConfig{m_config.repo_root}));
  m_toolRegistry.registerTool(std::make_unique<IdeFileTool>(
      IdeFileToolConfig{m_config.repo_root}));

  // Spin up worker threads.
  for (std::uint32_t i = 0; i < m_config.max_workers; ++i) {
    m_workers.emplace_back(&AgentSwarm::workerLoop, this, &wisdom, &bus);
  }

  NEXUS_LOG_INFO(LogChannel::kCell,
                 "[CELL Swarm] started workers=" +
                     std::to_string(m_config.max_workers) +
                     " repo=" + m_config.repo_root);
}

// ── Stop ──────────────────────────────────────────────────────────────────────

void AgentSwarm::stop() {
  if (!m_running.exchange(false)) {
    return;
  }

  m_stopping.store(true);

  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    m_queueCv.notify_all();
  }

  for (auto& t : m_workers) {
    if (t.joinable()) { t.join(); }
  }
  m_workers.clear();

  NEXUS_LOG_INFO(LogChannel::kCell,
                 "[CELL Swarm] stopped completed=" +
                     std::to_string(m_completedTasks.load()) +
                     " failed=" + std::to_string(m_failedTasks.load()));
}

// ── Submit ────────────────────────────────────────────────────────────────────

auto AgentSwarm::submit(AgentTask task) -> std::string {
  // Assign a task_id if not provided
  if (task.task_id.empty()) {
    task.task_id = "agent_task_" + std::to_string(m_taskCounter.fetch_add(1));
  }

  const std::string id = task.task_id;

  {
    std::unique_lock<std::mutex> lock(m_queueMutex);
    // Block if at capacity (back-pressure)
    m_queueCv.wait(lock, [this] {
      return m_taskQueue.size() < m_config.task_queue_cap || m_stopping.load();
    });

    if (m_stopping.load()) {
      return id;
    }

    m_taskQueue.push(std::move(task));
    m_queueCv.notify_one();
  }

  NEXUS_LOG_INFO(LogChannel::kCell, "[CELL Swarm] submitted task_id=" + id);
  return id;
}

// ── Result polling ────────────────────────────────────────────────────────────

auto AgentSwarm::result(const std::string& task_id) const
    -> std::optional<AgentResult> {
  std::lock_guard<std::mutex> lock(m_resultMutex);
  const auto it = m_results.find(task_id);
  if (it == m_results.end()) { return std::nullopt; }
  return it->second;
}

// ── Status ────────────────────────────────────────────────────────────────────

auto AgentSwarm::status() const -> AgentSwarmStatus {
  AgentSwarmStatus s;
  s.active_workers  = m_activeWorkers.load();
  s.completed_tasks = m_completedTasks.load();
  s.failed_tasks    = m_failedTasks.load();
  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    s.queued_tasks = static_cast<std::uint32_t>(m_taskQueue.size());
  }
  return s;
}

// ── Worker loop ───────────────────────────────────────────────────────────────

void AgentSwarm::workerLoop(WisdomStore* wisdom, ObservationBus* bus) {
  AgentExecutor executor(*wisdom, *bus, m_toolRegistry);

  while (true) {
    AgentTask task;
    {
      std::unique_lock<std::mutex> lock(m_queueMutex);
      m_queueCv.wait(lock, [this] {
        return !m_taskQueue.empty() || m_stopping.load();
      });

      if (m_stopping.load() && m_taskQueue.empty()) { break; }
      if (m_taskQueue.empty()) { continue; }

      task = std::move(m_taskQueue.front());
      m_taskQueue.pop();
      m_queueCv.notify_all(); // wake submit() if it was blocked on capacity
    }

    m_activeWorkers.fetch_add(1);

    AgentResult res = executor.run(task);

    if (res.ok) {
      m_completedTasks.fetch_add(1);
    } else {
      m_failedTasks.fetch_add(1);
    }

    storeResult(std::move(res));
    m_activeWorkers.fetch_sub(1);
  }
}

// ── Store result ──────────────────────────────────────────────────────────────

void AgentSwarm::storeResult(AgentResult result) {
  std::lock_guard<std::mutex> lock(m_resultMutex);
  m_results[result.task_id] = std::move(result);
}

} // namespace nexus::cell
