#pragma once

// CELL Model Trainer — The Cell Tank
//
// Runs on a background thread at a longer interval (default 60 s) and maintains
// a lightweight online linear model: reward = bias + sum(weight_i * feature_i).
// Weights are updated with stochastic gradient descent on each training batch.
// After every successful cycle the model is serialised to
//   artifacts/cell/model_v{NNN}.json
// The previous version is kept as a rollback target.  If the new model
// regresses (mean absolute error increases), it is automatically abandoned.

#include <nlohmann/json.hpp>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>

namespace nexus::cell {
class ExperienceLedger;
}

namespace nexus::cell {

struct ModelConfig {
  std::string   artifacts_dir{"artifacts/cell"};
  std::chrono::seconds train_interval{60};
  double        learning_rate{0.01};
  std::size_t   batch_size{256};
  /// Minimum records before training begins.
  std::size_t   min_records_to_train{100};
};

class ModelTrainer {
public:
  explicit ModelTrainer(ModelConfig config = {});
  ~ModelTrainer();

  ModelTrainer(const ModelTrainer&) = delete;
  auto operator=(const ModelTrainer&) -> ModelTrainer& = delete;

  void start(ExperienceLedger& ledger);
  void stop();

  /// Force an immediate training cycle.
  void trainNow();

  /// Predict expected reward for a given feature map.
  [[nodiscard]] auto predict(const std::unordered_map<std::string, double>& features) const -> double;

  [[nodiscard]] auto modelVersion() const -> std::uint32_t;
  [[nodiscard]] auto lastMae() const -> double;
  [[nodiscard]] auto isRunning() const -> bool;

  /// Roll back to the previous saved version (if available).
  auto rollback() -> bool;

private:
  void loop();
  void runTrainingCycle();

  /// Extract named numeric leaf values from arbitrary JSON.
  static auto extractFeatures(const nlohmann::json& json,
                               const std::string& prefix = "")
      -> std::unordered_map<std::string, double>;

  void saveModel(std::uint32_t version) const;
  auto loadModel(std::uint32_t version) -> bool;

  ModelConfig             m_config;
  ExperienceLedger*       m_ledger{nullptr};

  mutable std::mutex      m_weightsMutex;
  std::unordered_map<std::string, double> m_weights;
  double                  m_bias{0.0};

  std::atomic<std::uint32_t> m_version{0};
  std::atomic<double>        m_lastMae{1.0};

  std::thread              m_thread;
  std::mutex               m_cvMutex;
  std::condition_variable  m_cv;
  std::atomic<bool>        m_running{false};
  std::atomic<bool>        m_trainNow{false};
};

} // namespace nexus::cell
