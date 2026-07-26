#pragma once

// NEXUS multi-core job system (Workstream 1).
//
// A work-stealing task scheduler used to distribute physics, render-prep, and
// gameplay work across CPU cores within the mobile ship budget. Each worker owns
// a lock-free Chase-Lev deque (atomic owner push/pop, CAS-based steal); a
// mutex-guarded overflow queue absorbs bursts beyond a deque's fixed capacity so
// submission never fails. This is a cooperative scheduler, NOT an OS thread pool
// abstraction — callers may help-drain while waiting to avoid stalls.

#include <array>
#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>
#include <vector>

namespace nexus::core {

/// Reference-counted completion token. Decremented when a submitted job ends.
class JobCounter {
public:
  void add(std::int64_t n) { m_pending.fetch_add(n, std::memory_order_relaxed); }
  void complete() { m_pending.fetch_sub(1, std::memory_order_acq_rel); }
  [[nodiscard]] auto pending() const -> std::int64_t {
    return m_pending.load(std::memory_order_acquire);
  }

private:
  std::atomic<std::int64_t> m_pending{0};
};

class JobSystem {
public:
  using Task = std::function<void()>;

  /// workerCount == 0 => auto (hardware_concurrency-1, clamped to [1,kMaxWorkers]).
  explicit JobSystem(std::size_t workerCount = 0);
  ~JobSystem();

  JobSystem(const JobSystem&) = delete;
  auto operator=(const JobSystem&) -> JobSystem& = delete;

  [[nodiscard]] auto workerCount() const -> std::size_t { return m_workers.size(); }

  /// Submits a single task, incrementing the supplied counter.
  void run(Task task, JobCounter& counter);

  /// Submits a task tracked by an internal counter (fire and forget + waitIdle).
  void run(Task task);

  /// Splits [0, itemCount) into chunks and runs fn(index) across workers, then
  /// blocks (help-draining) until all chunk tasks finish. Deterministic results
  /// when fn writes to disjoint indices or atomics.
  void parallelFor(std::size_t itemCount, std::size_t grainSize,
                   const std::function<void(std::size_t)>& fn);

  /// Blocks until counter reaches zero, executing other jobs while waiting.
  void wait(JobCounter& counter);

  /// Blocks until all internally-tracked work is drained.
  void waitIdle();

  [[nodiscard]] auto stolenJobs() const -> std::uint64_t {
    return m_stealCount.load(std::memory_order_relaxed);
  }
  [[nodiscard]] auto executedJobs() const -> std::uint64_t {
    return m_executedCount.load(std::memory_order_relaxed);
  }

  static constexpr std::size_t kMaxWorkers = 32;
  static constexpr std::size_t kDequeCapacity = 4096;

private:
  struct Job {
    Task task;
    JobCounter* counter{nullptr};
  };

  // Bounded lock-free Chase-Lev deque holding Job pointers (trivially copyable,
  // safe under the steal/pop data race; Job lifetime owned by the scheduler).
  class WorkStealingDeque {
  public:
    auto push(Job* job) -> bool;   // owner only
    auto pop() -> Job*;            // owner only (LIFO)
    auto steal() -> Job*;          // any thread (FIFO)

  private:
    std::array<std::atomic<Job*>, kDequeCapacity> m_buffer{};
    std::atomic<std::int64_t> m_top{0};
    std::atomic<std::int64_t> m_bottom{0};
  };

  void workerLoop(std::size_t index);
  auto acquireJob(std::size_t selfIndex) -> Job*;
  void execute(Job* job);
  void submit(Job* job);
  void wakeWorkers();

  std::vector<std::thread> m_workers;
  std::vector<std::unique_ptr<WorkStealingDeque>> m_deques;

  std::mutex m_overflowMutex;
  std::queue<Job*> m_overflowQueue;

  std::mutex m_sleepMutex;
  std::condition_variable m_sleepCv;
  std::atomic<bool> m_running{true};
  std::atomic<std::int64_t> m_outstanding{0};

  JobCounter m_idleCounter;
  std::atomic<std::uint64_t> m_stealCount{0};
  std::atomic<std::uint64_t> m_executedCount{0};
  std::atomic<std::uint32_t> m_rng{0x9e3779b9U};

  static thread_local int s_workerIndex;
};

} // namespace nexus::core
