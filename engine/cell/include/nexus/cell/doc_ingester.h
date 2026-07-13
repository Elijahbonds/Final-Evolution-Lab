#pragma once

// CELL Doc Ingester — RAG Pipeline
//
// Reads project documentation files (Markdown, plain-text) from a configured
// list of paths, chunks them into WisdomEntry candidates, scores each candidate
// through GEvalScorer, and upserts passing entries into WisdomStore.
//
// This gives CELL a "long-term memory" that is perfectly tuned to the project
// architecture, conventions, and standards — effectively implementing the
// Retrieval-Augmented Generation (RAG) pattern inside the engine.
//
// Chunking strategy:
//   • Level-1 / Level-2 Markdown headings (lines starting with "# " or "## ")
//     begin a new chunk.
//   • Blank lines within a chunk are preserved up to kMaxConsecutiveBlankLines;
//     a second consecutive blank line signals a paragraph break (new chunk).
//   • The first line of each chunk becomes rule_text (truncated to
//     DocIngesterConfig::max_chunk_length); subsequent lines become the
//     chunk's context stored as the chunk's source_excerpt.
//   • Chunks shorter than min_chunk_length characters are skipped.
//
// Domain derivation:
//   Derived from the filename stem, lower-cased and hyphens replaced by
//   underscores (e.g. "NEXUS_AGENT_ORCHESTRATION.md" → "nexus_agent_orchestration").
//   Override globally with DocIngesterConfig::domain_override.
//
// Deduplication:
//   Each (domain, rule_text) pair is tracked by a FNV-1a hash.  Entries
//   already present in WisdomStore (via upsert merge) are automatically
//   updated without duplicates.
//
// Threading:
//   ingest() is synchronous and intended to be called from the engine init
//   thread or the JobSystem.  It is NOT re-entrant (external locking required
//   if called concurrently).

#include "nexus/cell/geval_scorer.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/result.h"

#include <cstddef>
#include <string>
#include <unordered_set>
#include <vector>

namespace nexus::cell {

// ── Config ────────────────────────────────────────────────────────────────────

struct DocIngesterConfig {
  /// Files and/or directories to ingest.  Directories are scanned non-recursively
  /// for *.md and *.txt files.  Defaults are populated by applyDefaults().
  std::vector<std::string> doc_paths;

  /// Maximum length (in chars) of a single rule_text derived from a chunk.
  std::size_t max_chunk_length{200};

  /// Minimum chunk character count to be considered for ingestion.
  std::size_t min_chunk_length{20};

  /// Fixed confidence assigned to doc-derived entries (authoritative source).
  double doc_confidence{0.80};

  /// Minimum G-Eval aggregate score for a doc entry to be upserted.
  /// Lower than ResearchLoop default because docs may lack numeric deltas.
  double min_geval_score{4.5};

  /// If non-empty, all ingested entries are tagged with this domain instead of
  /// the filename-derived one.
  std::string domain_override;

  /// Populate doc_paths with sensible project defaults when left empty.
  bool use_default_paths{true};
};

// ── Per-chunk result (diagnostic) ─────────────────────────────────────────────

struct IngestResult {
  std::size_t files_scanned{0};
  std::size_t chunks_found{0};
  std::size_t chunks_passed_geval{0};
  std::size_t entries_upserted{0};
};

// ── Ingester ──────────────────────────────────────────────────────────────────

class DocIngester {
public:
  explicit DocIngester(DocIngesterConfig config = {});

  /// Scan all configured paths, score chunks, upsert passing entries into
  /// the provided WisdomStore.  Returns diagnostic counts.
  [[nodiscard]] auto ingest(WisdomStore& wisdom,
                             const GEvalScorer& scorer) -> IngestResult;

  [[nodiscard]] auto lastResult() const -> const IngestResult& { return m_lastResult; }
  [[nodiscard]] auto totalUpserted() const -> std::size_t { return m_totalUpserted; }

private:
  // ── File helpers ──────────────────────────────────────────────────────────
  [[nodiscard]] auto resolveFiles() const -> std::vector<std::string>;
  [[nodiscard]] static auto chunkFile(const std::string& path,
                                      std::size_t max_chunk_length,
                                      std::size_t min_chunk_length)
      -> std::vector<std::string>;
  [[nodiscard]] static auto domainFromPath(const std::string& path) -> std::string;
  [[nodiscard]] static auto fnv1aHash(const std::string& s) -> std::uint64_t;

  static void applyDefaults(DocIngesterConfig& cfg);

  DocIngesterConfig     m_config;
  std::unordered_set<std::uint64_t> m_seen; ///< hashes of already-ingested (domain+rule_text)
  IngestResult          m_lastResult;
  std::size_t           m_totalUpserted{0};
};

} // namespace nexus::cell
