#include "nexus/cell/doc_ingester.h"

#include "nexus/core/log.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace nexus::cell {

namespace {

// ── String helpers ────────────────────────────────────────────────────────────

auto trimLeft(std::string s) -> std::string {
  s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char c) {
    return !std::isspace(c);
  }));
  return s;
}

auto trimRight(std::string s) -> std::string {
  s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char c) {
    return !std::isspace(c);
  }).base(), s.end());
  return s;
}

auto trim(std::string s) -> std::string {
  return trimLeft(trimRight(std::move(s)));
}

auto lowercase(std::string s) -> std::string {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

auto stripMarkdownPrefix(std::string line) -> std::string {
  // Strip leading '#' heading markers and bold/italic markers.
  std::size_t i = 0;
  while (i < line.size() && line[i] == '#') { ++i; }
  if (i > 0 && i < line.size() && line[i] == ' ') {
    line = line.substr(i + 1);
  }
  // Strip leading/trailing '**', '*', '_'
  for (const auto* marker : {"**", "__", "*", "_"}) {
    const std::size_t mlen = std::strlen(marker);
    while (line.size() >= mlen * 2 &&
           line.substr(0, mlen) == marker &&
           line.substr(line.size() - mlen) == marker) {
      line = line.substr(mlen, line.size() - mlen * 2);
    }
  }
  return trim(line);
}

auto nowMs() -> std::uint64_t {
  using namespace std::chrono;
  return static_cast<std::uint64_t>(
      duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

} // namespace

// ── Constructor ───────────────────────────────────────────────────────────────

DocIngester::DocIngester(DocIngesterConfig config) : m_config(std::move(config)) {
  if (m_config.use_default_paths && m_config.doc_paths.empty()) {
    applyDefaults(m_config);
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

auto DocIngester::ingest(WisdomStore& wisdom, const GEvalScorer& scorer) -> IngestResult {
  IngestResult result;
  const auto files = resolveFiles();
  result.files_scanned = files.size();

  for (const auto& file : files) {
    const std::string domain = m_config.domain_override.empty()
                                   ? domainFromPath(file)
                                   : m_config.domain_override;

    const auto chunks = chunkFile(file, m_config.max_chunk_length, m_config.min_chunk_length);
    result.chunks_found += chunks.size();

    for (const auto& chunk : chunks) {
      if (chunk.empty()) { continue; }

      // Build candidate entry.
      WisdomEntry entry;
      entry.domain          = domain;
      entry.rule_text       = chunk;
      entry.confidence      = m_config.doc_confidence;
      entry.evidence_count  = 1;
      entry.last_updated_ms = nowMs();
      entry.tier            = WisdomTier::kTactical;

      // Dedup check.
      const std::uint64_t hash = fnv1aHash(domain + "|" + entry.rule_text);
      if (m_seen.count(hash)) { continue; }

      // Score through G-Eval.
      GEvalConfig gCfg = scorer.config();
      gCfg.min_score   = m_config.min_geval_score;
      GEvalScorer docScorer(gCfg);
      auto evalResult = docScorer.score(entry);

      if (!evalResult.passes) {
        // One refinement attempt.
        entry      = docScorer.refine(std::move(entry));
        evalResult = docScorer.score(entry);
      }

      if (!evalResult.passes) { continue; }

      ++result.chunks_passed_geval;
      m_seen.insert(hash);
      wisdom.upsert(std::move(entry));
      ++result.entries_upserted;
    }
  }

  m_lastResult   = result;
  m_totalUpserted += result.entries_upserted;

  NEXUS_LOG_INFO(LogChannel::kCell,
                 "DocIngester: scanned=" + std::to_string(result.files_scanned) +
                     " chunks=" + std::to_string(result.chunks_found) +
                     " passed=" + std::to_string(result.chunks_passed_geval) +
                     " upserted=" + std::to_string(result.entries_upserted));
  return result;
}

// ── Private helpers ───────────────────────────────────────────────────────────

auto DocIngester::resolveFiles() const -> std::vector<std::string> {
  std::vector<std::string> files;
  for (const auto& pathStr : m_config.doc_paths) {
    const std::filesystem::path p(pathStr);
    std::error_code ec;
    if (std::filesystem::is_regular_file(p, ec)) {
      files.push_back(pathStr);
    } else if (std::filesystem::is_directory(p, ec)) {
      // Non-recursive scan: only .md and .txt in the immediate directory.
      for (const auto& entry : std::filesystem::directory_iterator(p, ec)) {
        if (!entry.is_regular_file()) { continue; }
        const auto ext = entry.path().extension().string();
        if (ext == ".md" || ext == ".txt") {
          files.push_back(entry.path().string());
        }
      }
    }
  }
  return files;
}

auto DocIngester::chunkFile(const std::string& path,
                              std::size_t max_chunk_length,
                              std::size_t min_chunk_length) -> std::vector<std::string> {
  std::ifstream file(path);
  if (!file.is_open()) {
    return {};
  }

  std::vector<std::string> chunks;
  std::string currentChunk;
  int consecutiveBlank = 0;

  auto commitChunk = [&]() {
    const std::string trimmed = trim(currentChunk);
    if (trimmed.size() >= min_chunk_length) {
      // Use first line as the rule_text, truncated to max_chunk_length.
      std::string firstLine;
      {
        std::istringstream ss(trimmed);
        std::getline(ss, firstLine);
      }
      firstLine = stripMarkdownPrefix(firstLine);
      if (firstLine.size() > max_chunk_length) {
        firstLine = firstLine.substr(0, max_chunk_length);
      }
      if (firstLine.size() >= min_chunk_length) {
        chunks.push_back(firstLine);
      }
    }
    currentChunk.clear();
    consecutiveBlank = 0;
  };

  std::string line;
  while (std::getline(file, line)) {
    const bool isBlank = trim(line).empty();
    const bool isHeading1 = line.size() >= 2 && line[0] == '#' && line[1] == ' ';
    const bool isHeading2 = line.size() >= 3 && line[0] == '#' && line[1] == '#' && line[2] == ' ';

    if (isHeading1 || isHeading2) {
      if (!currentChunk.empty()) {
        commitChunk();
      }
      currentChunk = line + "\n";
      consecutiveBlank = 0;
    } else if (isBlank) {
      ++consecutiveBlank;
      if (consecutiveBlank >= 2 && !currentChunk.empty()) {
        commitChunk();
      } else {
        currentChunk += "\n";
      }
    } else {
      consecutiveBlank = 0;
      currentChunk += line + "\n";
    }
  }
  if (!currentChunk.empty()) {
    commitChunk();
  }

  return chunks;
}

auto DocIngester::domainFromPath(const std::string& path) -> std::string {
  const std::filesystem::path p(path);
  std::string stem = p.stem().string();
  std::transform(stem.begin(), stem.end(), stem.begin(),
                 [](unsigned char c) {
                   return static_cast<char>(
                       std::isalnum(c) ? std::tolower(c) : '_');
                 });
  return stem;
}

auto DocIngester::fnv1aHash(const std::string& s) -> std::uint64_t {
  // FNV-1a 64-bit
  std::uint64_t hash = 0xcbf29ce484222325ULL;
  for (unsigned char c : s) {
    hash ^= c;
    hash *= 0x100000001b3ULL;
  }
  return hash;
}

void DocIngester::applyDefaults(DocIngesterConfig& cfg) {
  // Scan the repo-root-relative paths most likely to contain architectural docs.
  cfg.doc_paths = {
      "AGENTS.md",
      "docs",
      "NEXUS_ONLY_PIVOT.md",
      "SHIPPING_ARCHITECTURE.md",
      "NEXUS_RESUME.md",
  };
}

} // namespace nexus::cell
