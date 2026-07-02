#include "nexus/core/job_system.h"

#include "nexus/core/log.h"

#include <algorithm>
#include <chrono>

namespace nexus::core {

thread_local int JobSystem::s_workerIndex = -1;

// ---------------------------------------------------------------------------
// Chase-Lev bounded work-stealing deque
// ---------------------------------------------------------------------------

auto JobSystem::WorkStealingDeque::push(Job* job) -> bool {
  const std::int64_t bottom = m_bottom.load(std::memory_order_relaxed);
  const std::int64_t top = m_top.load(std::memory_order_acquire);
  if (bottom - top >= static_cast<std::int64_t>(kDequeCapacity)) {
    return false; // full -> caller routes to overflow queue
  }
  m_buffer[static_cast<std::size_t>(bottom) % kDequeCapacity].store(
      job, std::memory_order_relaxed);
  std::atomic_thread_fence(std::memory_order_release);
  m_bottom.store(bottom + 1, std::memory_order_relaxed);
  return true;
}

auto JobSystem::WorkStealingDeque::pop() -> Job* {
  const std::int64_t bottom = m_bottom.load(std::memory_order_relaxed) - 1;
  m_bottom.store(bottom, std::memory_order_relaxed);
  std::atomic_thread_fence(std::memory_order_seq_cst);
  std::int64_t top = m_top.load(std::memory_order_relaxed);

  if (top > bottom) {
    // Empty: restore bottom.
    m_bottom.store(bottom + 1, std::memory_order_relaxed);
    return nullptr;
  }

  Job* job = m_buffer[static_cast<std::size_t>(bottom) % kDequeCapacity].load(
      std::memory_order_relaxed);
  if (top != bottom) {
    return job; // more than one element, no contention
  }

  // Last element: race with a concurrent steal via CAS on top.
  if (!m_top.compare_exchange_strong(top, top + 1, std::memory_order_seq_cst,
                                     std::memory_order_relaxed)) {
    job = nullptr; // lost to a thief
  }
  m_bottom.store(bottom + 1, std::memory_order_relaxed);
  return job;
}

auto JobSystem::WorkStealingDeque::steal() -> Job* {
  std::int64_t top = m_top.load(std::memory_order_acquire);
  std::atomic_thread_fence(std::memory_order_seq_cst);
  const std::int64_t bottom = m_bottom.load(std::memory_order_acquire);
  if (top >= bottom) {
    return nullptr; // empty
  }
  Job* job = m_buffer[static_cast<std::size_t>(top) % kDequeCapacity].load(
      std::memory_order_relaxed);
  if (!m_top.compare_exchange_strong(top, top + 1, std::memory_order_seq_cst,
                                     std::memory_order_relaxed)) {
    return nullptr; // lost race
  }
  return job;
}

// ---------------------------------------------------------------------------
// JobSystem lifecycle
// ---------------------------------------------------------------------------

JobSystem::JobSystem(std::size_t workerCount) {
  if (workerCount == 0) {
    const unsigned hw = std::thread::hardware_concurrency();
    workerCount = hw > 1 ? static_cast<std::size_t>(hw) - 1 : 1;
  }
  workerCount = std::clamp<std::size_t>(workerCount, 1, kMaxWorkers);

  m_deques.reserve(workerCount);
  for (std::size_t i = 0; i < workerCount; ++i) {
    m_deques.push_back(std::make_unique<WorkStealingDeque>());
  }
  m_workers.reserve(workerCount);
  for (std::size_t i = 0; i < workerCount; ++i) {
    m_workers.emplace_back([this, i]() { workerLoop(i); });
  }
  NEXUS_LOG_INFO(LogChannel::kCore,
                 "Job system online with " + std::to_string(workerCount) +
                     " work-stealing workers");
}

JobSystem::~JobSystem() {
  m_running.store(false, std::memory_order_release);
  wakeWorkers();
  for (std::thread& t : m_workers) {
    if (t.joinable()) {
      t.join();
    }
  }
  // Drain any leftovers to avoid leaks.
  for (auto& deque : m_deques) {
    while (Job* job = deque->pop()) {
      delete job;
    }
  }
  std::scoped_lock lock(m_overflowMutex);
  while (!m_overflowQueue.empty()) {
    delete m_overflowQueue.front();
    m_overflowQueue.pop();
  }
}

void JobSystem::wakeWorkers() {
  std::scoped_lock lock(m_sleepMutex);
  m_sleepCv.notify_all();
}

void JobSystem::submit(Job* job) {
  m_outstanding.fetch_add(1, std::memory_order_acq_rel);
  const int self = s_workerIndex;
  bool queued = false;
  // Only the OWNING worker thread may push to its deque (Chase-Lev single-owner
  // invariant for push/pop). External (non-worker) submitters and full-deque
  // spillover go to the mutex-guarded global injection queue, from which any
  // worker can pull. This keeps the per-worker deques lock-free while remaining
  // memory-safe for cross-thread submission.
  if (self >= 0 && static_cast<std::size_t>(self) < m_deques.size()) {
    queued = m_deques[static_cast<std::size_t>(self)]->push(job);
  }
  if (!queued) {
    std::scoped_lock lock(m_overflowMutex);
    m_overflowQueue.push(job);
  }
  wakeWorkers();
}

void JobSystem::run(Task task, JobCounter& counter) {
  counter.add(1);
  submit(new Job{std::move(task), &counter});
}

void JobSystem::run(Task task) {
  m_idleCounter.add(1);
  submit(new Job{std::move(task), &m_idleCounter});
}

auto JobSystem::acquireJob(std::size_t selfIndex) -> Job* {
  // 1. Own deque (LIFO for cache locality).
  if (selfIndex < m_deques.size()) {
    if (Job* job = m_deques[selfIndex]->pop()) {
      return job;
    }
  }
  // 2. Overflow queue.
  {
    std::scoped_lock lock(m_overflowMutex);
    if (!m_overflowQueue.empty()) {
      Job* job = m_overflowQueue.front();
      m_overflowQueue.pop();
      return job;
    }
  }
  // 3. Steal from a pseudo-random victim.
  const std::size_t n = m_deques.size();
  if (n > 1) {
    std::uint32_t r = m_rng.fetch_add(0x9e3779b9U, std::memory_order_relaxed);
    for (std::size_t attempt = 0; attempt < n; ++attempt) {
      const std::size_t victim = (r + attempt) % n;
      if (victim == selfIndex) {
        continue;
      }
      if (Job* job = m_deques[victim]->steal()) {
        m_stealCount.fetch_add(1, std::memory_order_relaxed);
        return job;
      }
    }
  }
  return nullptr;
}

void JobSystem::execute(Job* job) {
  if (job->task) {
    job->task();
  }
  if (job->counter != nullptr) {
    job->counter->complete();
  }
  m_executedCount.fetch_add(1, std::memory_order_relaxed);
  m_outstanding.fetch_sub(1, std::memory_order_acq_rel);
  delete job;
}

void JobSystem::workerLoop(std::size_t index) {
  s_workerIndex = static_cast<int>(index);
  while (m_running.load(std::memory_order_acquire)) {
    Job* job = acquireJob(index);
    if (job != nullptr) {
      execute(job);
      continue;
    }
    // No work: sleep until woken (submission or shutdown).
    std::unique_lock<std::mutex> lock(m_sleepMutex);
    m_sleepCv.wait_for(lock, std::chrono::milliseconds(1), [this]() {
      return !m_running.load(std::memory_order_acquire) ||
             m_outstanding.load(std::memory_order_acquire) > 0;
    });
  }
}

void JobSystem::wait(JobCounter& counter) {
  const int self = s_workerIndex;
  const std::size_t selfIndex =
      self >= 0 ? static_cast<std::size_t>(self) : m_deques.size();
  while (counter.pending() > 0) {
    Job* job = acquireJob(selfIndex);
    if (job != nullptr) {
      execute(job);
    } else {
      std::this_thread::yield();
    }
  }
}

void JobSystem::waitIdle() { wait(m_idleCounter); }

void JobSystem::parallelFor(std::size_t itemCount, std::size_t grainSize,
                            const std::function<void(std::size_t)>& fn) {
  if (itemCount == 0) {
    return;
  }
  if (grainSize == 0) {
    grainSize = 1;
  }
  JobCounter counter;
  for (std::size_t begin = 0; begin < itemCount; begin += grainSize) {
    const std::size_t end = std::min(begin + grainSize, itemCount);
    run(
        [begin, end, &fn]() {
          for (std::size_t i = begin; i < end; ++i) {
            fn(i);
          }
        },
        counter);
  }
  wait(counter);
}

} // namespace nexus::core
