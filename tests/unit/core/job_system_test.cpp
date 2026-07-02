#include "nexus/core/job_system.h"

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void worker_count_is_at_least_one() {
  nexus::core::JobSystem jobs(4);
  require(jobs.workerCount() == 4, "explicit worker count honored");
  nexus::core::JobSystem autoJobs(0);
  require(autoJobs.workerCount() >= 1, "auto worker count >= 1");
}

void parallel_for_sums_all_items() {
  nexus::core::JobSystem jobs(4);
  constexpr std::size_t kItems = 100'000;
  std::atomic<std::int64_t> sum{0};
  jobs.parallelFor(kItems, 256, [&sum](std::size_t i) {
    sum.fetch_add(static_cast<std::int64_t>(i), std::memory_order_relaxed);
  });
  // Sum of 0..kItems-1
  const std::int64_t expected =
      static_cast<std::int64_t>(kItems) * (kItems - 1) / 2;
  require(sum.load() == expected, "parallelFor visited every index exactly once");
}

void run_and_wait_idle_executes_all() {
  nexus::core::JobSystem jobs(3);
  std::atomic<int> counter{0};
  constexpr int kTasks = 5000;
  for (int i = 0; i < kTasks; ++i) {
    jobs.run([&counter]() { counter.fetch_add(1, std::memory_order_relaxed); });
  }
  jobs.waitIdle();
  require(counter.load() == kTasks, "all fire-and-forget tasks ran");
  require(jobs.executedJobs() >= static_cast<std::uint64_t>(kTasks),
          "executed counter advanced");
}

void nested_submission_completes() {
  nexus::core::JobSystem jobs(4);
  std::atomic<int> leaves{0};
  nexus::core::JobCounter counter;
  constexpr int kParents = 64;
  constexpr int kChildren = 16;
  for (int p = 0; p < kParents; ++p) {
    jobs.run(
        [&jobs, &leaves, &counter]() {
          for (int c = 0; c < kChildren; ++c) {
            jobs.run(
                [&leaves]() {
                  leaves.fetch_add(1, std::memory_order_relaxed);
                },
                counter);
          }
        },
        counter);
  }
  jobs.wait(counter);
  require(leaves.load() == kParents * kChildren,
          "nested child jobs all executed (work-stealing drained)");
}

void overflow_beyond_capacity_is_handled() {
  // Single worker so the deque can fill and route into the overflow queue.
  nexus::core::JobSystem jobs(1);
  std::atomic<int> counter{0};
  const int kTasks = static_cast<int>(nexus::core::JobSystem::kDequeCapacity) * 3;
  nexus::core::JobCounter c;
  for (int i = 0; i < kTasks; ++i) {
    jobs.run([&counter]() { counter.fetch_add(1, std::memory_order_relaxed); }, c);
  }
  jobs.wait(c);
  require(counter.load() == kTasks, "overflow queue absorbed burst beyond capacity");
}

} // namespace

auto main() -> int {
  worker_count_is_at_least_one();
  parallel_for_sums_all_items();
  run_and_wait_idle_executes_all();
  nested_submission_completes();
  overflow_beyond_capacity_is_handled();
  std::fprintf(stderr, "PASS: nexus_job_system_test\n");
  return 0;
}
