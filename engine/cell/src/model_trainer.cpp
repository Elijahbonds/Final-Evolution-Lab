#include "nexus/cell/model_trainer.h"

#include "nexus/cell/experience_ledger.h"
#include "nexus/core/log.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <numeric>
#include <sstream>

namespace nexus::cell {

namespace {

auto nowMs() -> std::uint64_t {
  using namespace std::chrono;
  return static_cast<std::uint64_t>(
      duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

} // namespace

ModelTrainer::ModelTrainer(ModelConfig config) : m_config(std::move(config)) {}

ModelTrainer::~ModelTrainer() {
  stop();
}

void ModelTrainer::start(ExperienceLedger& ledger) {
  m_ledger = &ledger;
  m_running.store(true, std::memory_order_release);
  // Attempt to load the latest saved model.
  if (m_version.load() == 0) {
    for (std::uint32_t v = 99; v >= 1; --v) {
      if (loadModel(v)) {
        NEXUS_LOG_INFO(LogChannel::kCell, "ModelTrainer: loaded model v" + std::to_string(v));
        break;
      }
    }
  }
  m_thread = std::thread([this] { loop(); });
  NEXUS_LOG_INFO(LogChannel::kCell, "ModelTrainer started");
}

void ModelTrainer::stop() {
  if (!m_running.load(std::memory_order_acquire)) {
    return;
  }
  m_running.store(false, std::memory_order_release);
  {
    std::scoped_lock lock(m_cvMutex);
    m_trainNow.store(true, std::memory_order_release);
  }
  m_cv.notify_all();
  if (m_thread.joinable()) {
    m_thread.join();
  }
  NEXUS_LOG_INFO(LogChannel::kCell,
                 "ModelTrainer stopped (version=" + std::to_string(m_version.load()) + ")");
}

void ModelTrainer::trainNow() {
  {
    std::scoped_lock lock(m_cvMutex);
    m_trainNow.store(true, std::memory_order_release);
  }
  m_cv.notify_one();
}

auto ModelTrainer::predict(const std::unordered_map<std::string, double>& features) const
    -> double {
  std::scoped_lock lock(m_weightsMutex);
  double score = m_bias;
  for (const auto& [name, val] : features) {
    const auto it = m_weights.find(name);
    if (it != m_weights.end()) {
      score += it->second * val;
    }
  }
  // Clamp to [-1, 1].
  return std::max(-1.0, std::min(1.0, score));
}

auto ModelTrainer::currentPolicyWeights() const -> PolicyWeights {
  PolicyWeights pw;
  std::scoped_lock lock(m_weightsMutex);
  pw.weights       = m_weights;
  pw.bias          = m_bias;
  pw.model_version = m_version.load(std::memory_order_relaxed);
  return pw;
}

auto ModelTrainer::modelVersion() const -> std::uint32_t {
  return m_version.load(std::memory_order_relaxed);
}

auto ModelTrainer::lastMae() const -> double {
  return m_lastMae.load(std::memory_order_relaxed);
}

auto ModelTrainer::isRunning() const -> bool {
  return m_running.load(std::memory_order_acquire);
}

auto ModelTrainer::rollback() -> bool {
  const std::uint32_t cur = m_version.load(std::memory_order_relaxed);
  if (cur == 0) {
    return false;
  }
  return loadModel(cur - 1);
}

void ModelTrainer::loop() {
  while (m_running.load(std::memory_order_acquire)) {
    {
      std::unique_lock<std::mutex> lock(m_cvMutex);
      m_cv.wait_for(lock, m_config.train_interval, [this] {
        return m_trainNow.load(std::memory_order_acquire) ||
               !m_running.load(std::memory_order_acquire);
      });
      m_trainNow.store(false, std::memory_order_release);
    }
    if (!m_running.load(std::memory_order_acquire)) {
      break;
    }
    runTrainingCycle();
  }
}

void ModelTrainer::runTrainingCycle() {
  if (m_ledger == nullptr) {
    return;
  }
  const std::size_t total = m_ledger->totalCount();
  if (total < m_config.min_records_to_train) {
    return;
  }

  const auto batch = m_ledger->queryRecent(m_config.batch_size);
  if (batch.empty()) {
    return;
  }

  // Stochastic gradient descent on the online linear model.
  // Snapshot current weights for rollback comparison.
  std::unordered_map<std::string, double> newWeights;
  double newBias = 0.0;
  {
    std::scoped_lock lock(m_weightsMutex);
    newWeights = m_weights;
    newBias    = m_bias;
  }

  double mae_sum = 0.0;
  for (const auto& rec : batch) {
    auto features = extractFeatures(rec.context_json, "");
    if (features.empty()) {
      continue;
    }

    // Forward pass.
    double pred = newBias;
    for (const auto& [name, val] : features) {
      const auto it = newWeights.find(name);
      if (it != newWeights.end()) {
        pred += it->second * val;
      }
    }
    pred = std::max(-1.0, std::min(1.0, pred));

    const double error = rec.reward_signal - pred;
    mae_sum += std::abs(error);

    // SGD update.
    newBias += m_config.learning_rate * error;
    for (const auto& [name, val] : features) {
      newWeights[name] += m_config.learning_rate * error * val;
    }
  }

  const double newMae = mae_sum / static_cast<double>(batch.size());
  const double oldMae = m_lastMae.load(std::memory_order_relaxed);

  // Accept if MAE did not regress significantly (>5% worse).
  if (newMae <= oldMae * 1.05 || m_version.load() == 0) {
    {
      std::scoped_lock lock(m_weightsMutex);
      m_weights = std::move(newWeights);
      m_bias    = newBias;
    }
    m_lastMae.store(newMae, std::memory_order_relaxed);

    const std::uint32_t newVersion = m_version.fetch_add(1, std::memory_order_relaxed) + 1;
    saveModel(newVersion);
    NEXUS_LOG_INFO(LogChannel::kCell,
                   "ModelTrainer: trained v" + std::to_string(newVersion) +
                       " MAE=" + std::to_string(newMae) +
                       " features=" + std::to_string(m_weights.size()));
  } else {
    NEXUS_LOG_INFO(LogChannel::kCell,
                   "ModelTrainer: cycle rejected (MAE " + std::to_string(oldMae) +
                       " -> " + std::to_string(newMae) + "), keeping v" +
                       std::to_string(m_version.load()));
  }
}

auto ModelTrainer::extractFeatures(const nlohmann::json& json, const std::string& prefix)
    -> std::unordered_map<std::string, double> {
  std::unordered_map<std::string, double> out;
  if (json.is_number()) {
    out[prefix.empty() ? "value" : prefix] = json.get<double>();
  } else if (json.is_object()) {
    for (auto it = json.begin(); it != json.end(); ++it) {
      const std::string key = prefix.empty() ? it.key() : (prefix + "." + it.key());
      auto sub = extractFeatures(it.value(), key);
      out.insert(sub.begin(), sub.end());
    }
  } else if (json.is_array() && json.size() <= 8) {
    for (std::size_t i = 0; i < json.size(); ++i) {
      auto sub = extractFeatures(json[i], prefix + "[" + std::to_string(i) + "]");
      out.insert(sub.begin(), sub.end());
    }
  }
  return out;
}

void ModelTrainer::saveModel(std::uint32_t version) const {
  try {
    std::filesystem::create_directories(m_config.artifacts_dir);
    std::ostringstream path;
    path << m_config.artifacts_dir << "/model_v";
    path << std::setw(3) << std::setfill('0') << version << ".json";

    nlohmann::json j;
    j["version"] = version;
    j["bias"]    = m_bias;
    j["mae"]     = m_lastMae.load(std::memory_order_relaxed);
    {
      std::scoped_lock lock(m_weightsMutex);
      for (const auto& [name, w] : m_weights) {
        j["weights"][name] = w;
      }
    }
    std::ofstream file(path.str());
    file << j.dump(2);
  } catch (const std::exception& ex) {
    NEXUS_LOG_WARN(LogChannel::kCell,
                   std::string("ModelTrainer: save failed: ") + ex.what());
  }
}

auto ModelTrainer::loadModel(std::uint32_t version) -> bool {
  try {
    std::ostringstream path;
    path << m_config.artifacts_dir << "/model_v";
    path << std::setw(3) << std::setfill('0') << version << ".json";
    std::ifstream file(path.str());
    if (!file.is_open()) {
      return false;
    }
    const nlohmann::json j = nlohmann::json::parse(file, nullptr, false);
    if (j.is_discarded()) {
      return false;
    }
    std::scoped_lock lock(m_weightsMutex);
    m_bias = j.value("bias", 0.0);
    if (j.contains("weights") && j["weights"].is_object()) {
      for (auto it = j["weights"].begin(); it != j["weights"].end(); ++it) {
        m_weights[it.key()] = it.value().get<double>();
      }
    }
    m_version.store(j.value("version", version), std::memory_order_relaxed);
    m_lastMae.store(j.value("mae", 1.0), std::memory_order_relaxed);
    return true;
  } catch (...) {
    return false;
  }
}

} // namespace nexus::cell
