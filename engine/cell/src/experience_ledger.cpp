#include "nexus/cell/experience_ledger.h"
#include "nexus/core/log.h"

#include <algorithm>
#include <chrono>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <vector>

namespace nexus::cell {

ExperienceLedger::ExperienceLedger(std::string ledgerDirectory)
    : m_ledgerDirectory(std::move(ledgerDirectory)) {}

auto ExperienceLedger::todayDateString() -> std::string {
  const auto now = std::chrono::system_clock::now();
  const std::time_t tt = std::chrono::system_clock::to_time_t(now);
  std::tm tmBuf{};
#if defined(_WIN32)
  gmtime_s(&tmBuf, &tt);
#else
  gmtime_r(&tt, &tmBuf);
#endif
  std::ostringstream oss;
  oss << std::put_time(&tmBuf, "%Y-%m-%d");
  return oss.str();
}

auto ExperienceLedger::todayFile() const -> std::string {
  return m_ledgerDirectory + "/" + todayDateString() + ".jsonl";
}

auto ExperienceLedger::append(const nlohmann::json& record) -> Result<void> {
  std::error_code ec;
  std::filesystem::create_directories(m_ledgerDirectory, ec);
  if (ec) {
    return Result<void>::err("ExperienceLedger: cannot create directory: " + ec.message());
  }
  std::ofstream stream(todayFile(), std::ios::app);
  if (!stream.is_open()) {
    return Result<void>::err("ExperienceLedger: cannot open " + todayFile());
  }
  stream << record.dump() << '\n';
  return Result<void>::ok();
}

auto ExperienceLedger::readRecent(std::size_t maxCount) const -> std::vector<nlohmann::json> {
  // Collect all JSONL files, sort descending by name (newest first).
  std::vector<std::filesystem::path> files;
  std::error_code ec;
  for (const auto& entry : std::filesystem::directory_iterator(m_ledgerDirectory, ec)) {
    if (entry.is_regular_file() && entry.path().extension() == ".jsonl") {
      files.push_back(entry.path());
    }
  }
  std::sort(files.begin(), files.end(), [](const auto& a, const auto& b) { return a > b; });

  std::vector<nlohmann::json> results;
  results.reserve(maxCount);

  for (const auto& file : files) {
    if (results.size() >= maxCount) {
      break;
    }
    // Read lines into a buffer then reverse for newest-first within day.
    std::ifstream stream(file);
    if (!stream.is_open()) {
      continue;
    }
    std::vector<std::string> lines;
    std::string line;
    while (std::getline(stream, line)) {
      if (!line.empty()) {
        lines.push_back(std::move(line));
      }
    }
    // Append in reverse (newest within day is last line).
    for (auto it = lines.rbegin(); it != lines.rend() && results.size() < maxCount; ++it) {
      try {
        results.push_back(nlohmann::json::parse(*it));
      } catch (...) {
        // Skip malformed lines.
      }
    }
  }
  return results;
}

} // namespace nexus::cell
