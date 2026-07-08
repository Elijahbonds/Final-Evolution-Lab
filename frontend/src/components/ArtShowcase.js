/*
 * ArtShowcase.js — Art Showcase Mode (route: /nexus/art)
 *
 * Gallery + glTF viewer + critique micro-games, built on the creative-models
 * foundation (art_exhibits model, /api/art/* endpoints). No heavy deps: the
 * 3D viewer uses a tiny raw-WebGL renderer (src/lib/gltfViewer.js).
 *
 * Features:
 *   - Gallery: swipeable image cards + orbit-camera glTF viewer
 *   - Lightbox: image + metadata (technique/tools/bio) + Creator Card lesson CTA
 *   - Publish flow -> marketplace stub listing
 *   - Micro-games: guess-the-technique, timed sketch, critique cards
 *   - ?recording=1 / RECORDING_LOCAL: deterministic seed banner + solo flow
 */
import React, { useState, useEffect, useRef, useCallback } from "react";
import axios from "axios";
import { mountGltfViewer } from "@/lib/gltfViewer";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://localhost:8000";
const API = `${BACKEND_URL}/api`;

const CYAN = "#00D4FF";
const PURPLE = "#9933FF";
const BG = "#050810";
const CARD = "#0c1120";
// Muted text tokens bumped for WCAG AA contrast on the dark surfaces.
const MUTED = "#9aa6c0";   // secondary text (was #8b94ab, ~4:1 → now ≥4.5:1)
const FAINT = "#8794b0";   // labels (was #6b7590, failed AA)
const BORDER = "#1c2438";
const TEXT = "#e8ecf5";

// prefers-reduced-motion (used to gate the lightbox fade + banner shimmer)
const reducedMotion = () => {
  try {
    return window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch (e) { return false; }
};

// Focusable-element query for modal focus traps.
const FOCUSABLE =
  'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])';

/**
 * useModalA11y — Escape-to-close, initial focus, focus restore, and a simple
 * Tab focus trap for a modal identified by `ref`. Shared by Lightbox + Lesson.
 */
function useModalA11y(ref, onClose) {
  useEffect(() => {
    const prevFocus = document.activeElement;
    const node = ref.current;
    // Move focus into the modal (first focusable, else the container).
    const focusables = node ? node.querySelectorAll(FOCUSABLE) : [];
    (focusables[0] || node)?.focus?.();

    const onKey = (e) => {
      if (e.key === "Escape") { e.stopPropagation(); onClose(); return; }
      if (e.key !== "Tab" || !node) return;
      const f = node.querySelectorAll(FOCUSABLE);
      if (!f.length) return;
      const first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault(); last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault(); first.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      prevFocus?.focus?.();
    };
  }, [ref, onClose]);
}

// Creator Card lesson packs (art) — mirrors the backend registry contract.
const ART_LESSON_PACKS = {
  card_visionary_01: {
    title: "Composition & Framing",
    lessons: ["rule_of_thirds", "color_balance", "focal_points"],
  },
  card_curator_01: {
    title: "Exhibit Curation",
    lessons: ["sequencing_works", "gallery_lighting", "artist_statements"],
  },
};

const isRecording = () =>
  new URLSearchParams(window.location.search).get("recording") === "1" ||
  process.env.REACT_APP_RECORDING_LOCAL === "1";

// Deterministic recording seed so the solo flow is reproducible.
const RECORD_SEED = 20260707;

// ── shared style helpers ────────────────────────────────────────────────────
const btn = (accent = CYAN) => ({
  minHeight: 44,
  minWidth: 44,
  padding: "10px 18px",
  borderRadius: 12,
  border: `1px solid ${accent}55`,
  background: `${accent}1a`,
  color: accent,
  fontWeight: 700,
  cursor: "pointer",
  fontSize: 15,
  transition: "all .15s",
  // Visible keyboard focus ring (falls back to a strong outline everywhere).
  outlineOffset: 2,
});

// A once-mounted <style> that gives every button/canvas a strong
// :focus-visible ring and honours reduced-motion. Keeps inline styles simple.
const A11Y_CSS = `
  .art-showcase button:focus-visible,
  .art-showcase canvas:focus-visible,
  .art-showcase textarea:focus-visible {
    outline: 3px solid ${CYAN};
    outline-offset: 2px;
    border-radius: 12px;
  }
  @media (prefers-reduced-motion: reduce) {
    .art-showcase * { animation-duration: .001ms !important;
      animation-iteration-count: 1 !important; transition-duration: .001ms !important; }
  }
`;

// ────────────────────────────────────────────────────────────────────────────
export default function ArtShowcase() {
  const [items, setItems] = useState([]);
  const [exhibit, setExhibit] = useState(null); // created exhibit record
  const [lightbox, setLightbox] = useState(null); // item in lightbox
  const [lesson, setLesson] = useState(null); // {cardId,title,lessons}
  const [tab, setTab] = useState("gallery"); // gallery | technique | sketch | critique
  const [status, setStatus] = useState("");
  const recording = isRecording();

  // Load sample content + create an exhibit to drive publish/critique/sketch.
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const s = await axios.get(`${API}/art/sample-exhibit`);
        if (!alive) return;
        setItems(s.data.items || []);
        // Create a draft exhibit from the sample items (mode session container).
        const created = await axios.post(`${API}/art/exhibits`, {
          title: s.data.title,
          items: (s.data.items || []).map((i) => ({
            type: i.type, path: i.path, meta: i.meta,
          })),
        });
        if (!alive) return;
        setExhibit(created.data);
      } catch (e) {
        setStatus("Offline preview — using sample content only.");
      }
    })();
    return () => { alive = false; };
  }, []);

  const openLesson = useCallback((cardId) => {
    const pack = ART_LESSON_PACKS[cardId] || ART_LESSON_PACKS.card_visionary_01;
    // best-effort: attach the pack to the exhibit (Creator Card tie-in)
    if (exhibit) {
      axios.post(`${API}/creator-cards/apply`, {
        card_id: cardId, project_type: "art", project_id: exhibit.exhibit_id,
      }).catch(() => {});
    }
    setLesson({ cardId, ...pack });
  }, [exhibit]);

  const publish = useCallback(async () => {
    if (!exhibit) return;
    try {
      const r = await axios.post(`${API}/art/exhibits/${exhibit.exhibit_id}/publish`);
      setExhibit((e) => ({ ...e, status: "published", marketplace: r.data.marketplace }));
      setStatus(`Published → marketplace listing ${r.data.marketplace.listing_id}`);
    } catch (e) {
      if (e?.response?.status === 409) setStatus("Already published.");
      else setStatus("Publish failed.");
    }
  }, [exhibit]);

  return (
    <div className="art-showcase" style={{ minHeight: "100vh", background: BG, color: TEXT,
      fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif" }}>
      <style>{A11Y_CSS}</style>
      {recording && (
        <div data-testid="recording-banner" style={{
          background: `linear-gradient(90deg, ${CYAN}22, ${PURPLE}22)`,
          padding: "8px 16px", fontSize: 13, letterSpacing: 1,
          borderBottom: `1px solid ${CYAN}33` }}>
          ● REC · deterministic seed {RECORD_SEED} · solo browse → micro-game → lesson
        </div>
      )}

      <header style={{ padding: "28px 20px 12px", maxWidth: 1100, margin: "0 auto" }}>
        <h1 style={{ margin: 0, fontSize: 30, fontWeight: 800,
          background: `linear-gradient(90deg, ${CYAN}, ${PURPLE})`,
          WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>
          Art Showcase
        </h1>
        <p style={{ color: MUTED, marginTop: 6 }}>
          Curate a gallery, play critique micro-games, learn from Creator Cards.
        </p>
        {/* Live region so publish/save/critique status is announced to SRs. */}
        <div role="status" aria-live="polite" aria-atomic="true"
          style={{ marginTop: 8, color: CYAN, fontSize: 14, minHeight: 18 }}>
          {status}
        </div>
      </header>

      <nav style={{ display: "flex", gap: 8, flexWrap: "wrap", padding: "0 20px",
        maxWidth: 1100, margin: "0 auto" }}>
        {[
          ["gallery", "Gallery"],
          ["technique", "Guess the Technique"],
          ["sketch", "Timed Sketch"],
          ["critique", "Critique Cards"],
        ].map(([id, label]) => (
          <button key={id} data-testid={`tab-${id}`} onClick={() => setTab(id)}
            aria-pressed={tab === id}
            style={{ ...btn(tab === id ? CYAN : "#556"),
              background: tab === id ? `${CYAN}22` : "transparent",
              color: tab === id ? CYAN : MUTED }}>
            {label}
          </button>
        ))}
        <div style={{ flex: 1 }} />
        {exhibit && (
          <button data-testid="publish-btn" onClick={publish}
            disabled={exhibit.status === "published"} style={{
              ...btn(PURPLE),
              opacity: exhibit.status === "published" ? 0.5 : 1 }}>
            {exhibit.status === "published" ? "Published ✓" : "Publish exhibit"}
          </button>
        )}
      </nav>

      <main style={{ maxWidth: 1100, margin: "0 auto", padding: "20px" }}>
        {tab === "gallery" && (
          <Gallery items={items} onOpen={setLightbox} />
        )}
        {tab === "technique" && (
          <GuessTechnique exhibitId={exhibit?.exhibit_id} recording={recording}
            onLesson={() => openLesson("card_visionary_01")} />
        )}
        {tab === "sketch" && (
          <TimedSketch exhibitId={exhibit?.exhibit_id} onSaved={setStatus} />
        )}
        {tab === "critique" && (
          <CritiqueCards items={items} exhibitId={exhibit?.exhibit_id} onSaved={setStatus} />
        )}
      </main>

      {lightbox && (
        <Lightbox item={lightbox} onClose={() => setLightbox(null)} onLesson={openLesson} />
      )}
      {lesson && (
        <LessonModal lesson={lesson} onClose={() => setLesson(null)} />
      )}
    </div>
  );
}

// ── Gallery ─────────────────────────────────────────────────────────────────
function Gallery({ items, onOpen }) {
  const images = items.filter((i) => i.type === "image");
  const models = items.filter((i) => i.type === "3d" || i.type === "model");
  // Technique filter chips (derived from content, so they grow with the bank).
  const techniques = Array.from(new Set(images.map((i) => i.meta?.technique).filter(Boolean)));
  const [filter, setFilter] = useState("all");
  const shown = filter === "all" ? images : images.filter((i) => i.meta?.technique === filter);

  return (
    <div>
      <h2 style={{ fontSize: 18, color: "#c3ccdd" }}>Works</h2>
      {techniques.length > 1 && (
        <div role="group" aria-label="Filter works by technique"
          style={{ display: "flex", gap: 8, flexWrap: "wrap", margin: "0 0 16px" }}>
          {["all", ...techniques].map((t) => (
            <button key={t} onClick={() => setFilter(t)} aria-pressed={filter === t}
              style={{ ...btn(filter === t ? CYAN : "#556"), padding: "6px 12px", fontSize: 13,
                background: filter === t ? `${CYAN}22` : "transparent",
                color: filter === t ? CYAN : MUTED }}>
              {t === "all" ? "All" : t.replace(/_/g, " ")}
            </button>
          ))}
        </div>
      )}
      <div style={{ display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 16 }}>
        {shown.map((it, i) => (
          <button key={it.path || i} data-testid="gallery-card" onClick={() => onOpen(it)}
            aria-label={`Open ${it.meta?.title || "artwork"}, technique ${it.meta?.technique || "unknown"}`}
            style={{ padding: 0, border: `1px solid ${BORDER}`, borderRadius: 14,
              overflow: "hidden", background: CARD, cursor: "pointer", textAlign: "left" }}>
            <img src={it.path}
              alt={it.meta?.alt || `${it.meta?.title || "Untitled"} by ${it.meta?.artist || "unknown artist"}`}
              style={{ width: "100%", height: 160, objectFit: "cover", display: "block" }} />
            <div style={{ padding: "10px 12px" }}>
              <div style={{ fontWeight: 700 }}>{it.meta?.title || "Untitled"}</div>
              <div style={{ fontSize: 12, color: MUTED }}>
                {(it.meta?.technique || "").replace(/_/g, " ")}
              </div>
            </div>
          </button>
        ))}
      </div>

      {models.length > 0 && (
        <>
          <h2 style={{ fontSize: 18, color: "#c3ccdd", marginTop: 28 }}>3D Sculpture</h2>
          <div style={{ display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))", gap: 16 }}>
            {models.map((m, i) => (
              <ModelViewerCard key={m.path || i} item={m} onOpen={onOpen} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

// Per-model environment tint so violet models get a violet-lit stage etc.
const modelTint = (item) => {
  const t = (item.meta?.title || "").toLowerCase();
  if (t.includes("prism") || t.includes("aurora"))
    return { skyTint: [0.42, 0.14, 0.75], groundTint: [0.04, 0.02, 0.10] };
  return { skyTint: [0.0, 0.55, 0.85], groundTint: [0.02, 0.04, 0.10] };
};

function ModelViewerCard({ item, onOpen }) {
  const canvasRef = useRef(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let handle = null;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(item.path);
        const gltf = await res.json();
        // Component may have unmounted while fetching — don't mount then.
        if (cancelled || !canvasRef.current) return;
        handle = mountGltfViewer(canvasRef.current, gltf, modelTint(item));
      } catch (e) { if (!cancelled) setError(true); }
    })();
    return () => { cancelled = true; if (handle) handle.dispose(); };
  }, [item.path]); // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <figure style={{ border: `1px solid ${BORDER}`, borderRadius: 14, overflow: "hidden",
      background: CARD, maxWidth: 480, margin: "16px 0 0" }}>
      <div style={{ position: "relative", height: 320,
        background: "radial-gradient(circle at 50% 40%, #0c1a33, #050810)" }}>
        {error ? (
          <div role="img" aria-label={item.meta?.alt || "3D model preview"}
            style={{ display: "grid", placeItems: "center", height: "100%", color: MUTED }}>
            3D preview unavailable
          </div>
        ) : (
          <canvas ref={canvasRef} data-testid="gltf-canvas" tabIndex={0}
            role="img"
            aria-label={`${item.meta?.title || "3D model"}. ${item.meta?.alt || ""} Interactive: drag or use arrow keys to orbit, plus and minus to zoom.`}
            style={{ width: "100%", height: "100%", display: "block", touchAction: "none" }} />
        )}
      </div>
      <figcaption style={{ padding: "12px 14px", display: "flex",
        justifyContent: "space-between", alignItems: "center", gap: 12 }}>
        <div>
          <div style={{ fontWeight: 700 }}>{item.meta?.title || "3D Model"}</div>
          <div style={{ fontSize: 12, color: MUTED }}>
            drag / arrow keys to orbit · scroll to zoom · {item.meta?.license}
          </div>
        </div>
        <button style={btn(CYAN)} onClick={() => onOpen(item)}
          aria-label={`Details for ${item.meta?.title || "3D model"}`}>Details</button>
      </figcaption>
    </figure>
  );
}

// ── Lightbox ────────────────────────────────────────────────────────────────
// Inline model preview for the lightbox (loads + mounts the WebGL viewer).
function LightboxModel({ item }) {
  const canvasRef = useRef(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let handle = null, cancelled = false;
    (async () => {
      try {
        const res = await fetch(item.path);
        const gltf = await res.json();
        if (cancelled || !canvasRef.current) return;
        handle = mountGltfViewer(canvasRef.current, gltf, modelTint(item));
      } catch (e) { if (!cancelled) setError(true); }
    })();
    return () => { cancelled = true; if (handle) handle.dispose(); };
  }, [item.path]); // eslint-disable-line react-hooks/exhaustive-deps
  if (error)
    return <div role="img" aria-label={item.meta?.alt} style={{ color: MUTED, padding: 24 }}>
      {item.meta?.title} (3D preview unavailable)</div>;
  return <canvas ref={canvasRef} tabIndex={0} role="img"
    aria-label={`${item.meta?.title}. ${item.meta?.alt || ""} Drag or arrow keys to orbit.`}
    style={{ width: "100%", height: 320, display: "block", touchAction: "none" }} />;
}

function Lightbox({ item, onClose, onLesson }) {
  const m = item.meta || {};
  const dialogRef = useRef(null);
  useModalA11y(dialogRef, onClose);
  const titleId = "lightbox-title";
  return (
    <div onClick={onClose} style={{
      position: "fixed", inset: 0, background: "rgba(2,4,10,.85)", zIndex: 50,
      display: "grid", placeItems: "center", padding: 16,
      animation: reducedMotion() ? "none" : "artFade .18s ease" }}>
      <div ref={dialogRef} role="dialog" aria-modal="true" aria-labelledby={titleId}
        tabIndex={-1} onClick={(e) => e.stopPropagation()} style={{ background: CARD,
        border: `1px solid ${CYAN}33`, borderRadius: 18, maxWidth: 820, width: "100%",
        display: "grid", gridTemplateColumns: "1fr", overflow: "hidden",
        boxShadow: `0 0 60px ${CYAN}22` }}>
        <div style={{ display: "grid", gridTemplateColumns: "minmax(0,1.2fr) minmax(0,1fr)" }}>
          <div style={{ background: "#02040a", minHeight: 260, display: "grid",
            placeItems: "center" }}>
            {item.type === "image" ? (
              <img src={item.path}
                alt={m.alt || `${m.title || "Untitled"} by ${m.artist || "unknown artist"}`}
                style={{ width: "100%", maxHeight: 420, objectFit: "contain" }} />
            ) : (
              <LightboxModel item={item} />
            )}
          </div>
          <div style={{ padding: 20 }}>
            <h2 id={titleId} style={{ margin: "0 0 4px", fontSize: 22 }}>{m.title || "Untitled"}</h2>
            <div style={{ color: CYAN, fontSize: 13, marginBottom: 12 }}>{m.artist}</div>
            <Meta label="Technique" value={(m.technique || "").replace(/_/g, " ")} />
            <Meta label="Tools" value={(m.tools || []).join(", ")} />
            <Meta label="Bio" value={m.artist_bio} />
            <Meta label="License" value={`${m.license} · ${m.source}`} />
            {m.card_id && (
              <button data-testid="lesson-cta" onClick={() => onLesson(m.card_id)}
                style={{ ...btn(PURPLE), marginTop: 14, width: "100%" }}>
                ✦ Open Creator Card lesson
              </button>
            )}
          </div>
        </div>
        <button onClick={onClose} aria-label="Close details"
          style={{ ...btn("#556"), margin: 12, justifySelf: "end" }}>Close</button>
      </div>
    </div>
  );
}

function Meta({ label, value }) {
  if (!value) return null;
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 1,
        color: FAINT }}>{label}</div>
      <div style={{ fontSize: 14 }}>{value}</div>
    </div>
  );
}

// ── Lesson modal (Creator Card tie-in) ──────────────────────────────────────
function LessonModal({ lesson, onClose }) {
  const dialogRef = useRef(null);
  useModalA11y(dialogRef, onClose);
  const titleId = "lesson-title";
  return (
    <div onClick={onClose} style={{
      position: "fixed", inset: 0, background: "rgba(2,4,10,.85)", zIndex: 60,
      display: "grid", placeItems: "center", padding: 16,
      animation: reducedMotion() ? "none" : "artFade .18s ease" }}>
      <div ref={dialogRef} role="dialog" aria-modal="true" aria-labelledby={titleId}
        tabIndex={-1} onClick={(e) => e.stopPropagation()} data-testid="lesson-modal" style={{
        background: CARD, border: `1px solid ${PURPLE}55`, borderRadius: 18,
        maxWidth: 460, width: "100%", padding: 24, boxShadow: `0 0 60px ${PURPLE}33` }}>
        <div style={{ fontSize: 12, color: PURPLE, letterSpacing: 1 }}>
          CREATOR CARD · {lesson.cardId}
        </div>
        <h2 id={titleId} style={{ margin: "6px 0 14px", fontSize: 22 }}>{lesson.title}</h2>
        <div style={{ display: "grid", gap: 10 }}>
          {lesson.lessons.map((l) => (
            <div key={l} style={{ padding: "12px 14px", borderRadius: 12,
              background: `${PURPLE}12`, border: `1px solid ${PURPLE}33` }}>
              <div style={{ fontWeight: 700 }}>{l.replace(/_/g, " ")}</div>
              <div style={{ fontSize: 13, color: MUTED }}>
                Micro-lesson · tap to study in the full Creator Card.
              </div>
            </div>
          ))}
        </div>
        <button onClick={onClose} style={{ ...btn(PURPLE), marginTop: 18, width: "100%" }}>
          Got it
        </button>
      </div>
    </div>
  );
}

// ── Micro-game 1: Guess the Technique ───────────────────────────────────────
const GT_CATEGORIES = [
  ["all", "All"], ["composition", "Composition"], ["color", "Color & Value"],
  ["mark_making", "Mark-Making"], ["rendering", "Rendering"], ["media_3d", "3D"],
];
const DIFF_COLORS = { easy: "#22c55e", medium: "#eab308", hard: "#ef4444" };

function GuessTechnique({ exhibitId, recording, onLesson }) {
  const seed = recording ? RECORD_SEED : Math.floor(Math.random() * 1e9);
  const [category, setCategory] = useState("all");
  const [round, setRound] = useState(null);
  const [qi, setQi] = useState(0);
  const [reveal, setReveal] = useState(null);
  const [score, setScore] = useState(0);

  const load = useCallback(async () => {
    setReveal(null); setQi(0); setScore(0); setRound(null);
    try {
      const params = { seed, count: 5 };
      if (category !== "all") params.category = category;
      const r = await axios.get(`${API}/art/guess-technique/round`, { params });
      setRound(r.data);
    } catch (e) { setRound({ questions: [] }); }
  }, [seed, category]);

  useEffect(() => { load(); }, [load]);

  const answer = async (opt) => {
    const q = round.questions[qi];
    try {
      const r = await axios.post(`${API}/art/guess-technique/answer`, {
        seed: round.seed, question_id: q.id, selected: opt,
        token: q.answer_token, exhibit_id: exhibitId,
      });
      setReveal(r.data);
      if (r.data.is_correct) setScore((s) => s + 1);
    } catch (e) { /* ignore */ }
  };

  const CategoryPicker = (
    <div role="group" aria-label="Choose a category"
      style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 16 }}>
      {GT_CATEGORIES.map(([id, label]) => (
        <button key={id} onClick={() => setCategory(id)} aria-pressed={category === id}
          style={{ ...btn(category === id ? CYAN : "#556"), padding: "6px 12px", fontSize: 13,
            background: category === id ? `${CYAN}22` : "transparent",
            color: category === id ? CYAN : MUTED }}>
          {label}
        </button>
      ))}
    </div>
  );

  if (!round) return <div style={{ color: MUTED }}>Loading round…</div>;
  if (round.questions.length === 0)
    return <div style={{ maxWidth: 640, margin: "0 auto" }}>
      {CategoryPicker}
      <div style={{ color: MUTED }}>No questions in this category.</div>
    </div>;

  const done = qi >= round.questions.length;
  if (done)
    return (
      <div style={{ textAlign: "center", padding: 40 }}>
        <h2>Round complete</h2>
        <div style={{ fontSize: 40, fontWeight: 800, color: CYAN }}
          role="status" aria-live="polite">
          {score}/{round.questions.length}
        </div>
        <button style={{ ...btn(CYAN), marginTop: 16 }} onClick={load}>Play again</button>
        <button style={{ ...btn(PURPLE), marginTop: 16, marginLeft: 8 }} onClick={onLesson}>
          ✦ Study composition lesson
        </button>
      </div>
    );

  const q = round.questions[qi];
  return (
    <div style={{ maxWidth: 640, margin: "0 auto" }}>
      {CategoryPicker}
      <div style={{ fontSize: 13, color: MUTED, display: "flex", gap: 10, alignItems: "center" }}>
        <span>Question {qi + 1} / {round.questions.length} · seed {round.seed}</span>
        {q.difficulty && (
          <span style={{ fontSize: 11, fontWeight: 700, textTransform: "uppercase",
            padding: "2px 8px", borderRadius: 8, color: DIFF_COLORS[q.difficulty],
            border: `1px solid ${DIFF_COLORS[q.difficulty]}55` }}>
            {q.difficulty}
          </span>
        )}
      </div>
      <img src={q.asset} alt={q.alt || `Artwork for: ${q.prompt}`} data-testid="gt-asset"
        style={{ width: "100%", height: 220, objectFit: "cover", borderRadius: 14,
          margin: "12px 0", border: `1px solid ${BORDER}` }} />
      <h3 style={{ marginTop: 0 }}>{q.prompt}</h3>
      <div style={{ display: "grid", gap: 10 }}>
        {q.options.map((opt) => {
          const chosen = reveal && reveal.selected === opt;
          const isCorrect = reveal && reveal.correct === opt;
          const color = reveal ? (isCorrect ? "#22c55e" : chosen ? "#ef4444" : "#556") : CYAN;
          return (
            <button key={opt} data-testid="gt-option" disabled={!!reveal}
              onClick={() => answer(opt)} style={{ ...btn(color), textAlign: "left",
                width: "100%", opacity: reveal && !isCorrect && !chosen ? 0.5 : 1 }}>
              {opt}
            </button>
          );
        })}
      </div>
      {reveal && (
        <div data-testid="gt-reveal" role="status" aria-live="assertive" style={{ marginTop: 16,
          padding: 16, borderRadius: 12, background: `${CYAN}10`, border: `1px solid ${CYAN}33` }}>
          <div style={{ fontWeight: 700, color: reveal.is_correct ? "#22c55e" : "#ef4444" }}>
            {reveal.is_correct ? "Correct!" : `Answer: ${reveal.correct}`}
          </div>
          <div style={{ fontSize: 14, color: "#c3ccdd", marginTop: 6 }}>{reveal.lesson}</div>
          <button style={{ ...btn(CYAN), marginTop: 12 }}
            onClick={() => { setReveal(null); setQi((i) => i + 1); }}>
            Next →
          </button>
        </div>
      )}
    </div>
  );
}

// ── Micro-game 2: Timed Sketch ──────────────────────────────────────────────
const SKETCH_PALETTE = ["#00D4FF", "#9933FF", "#e8ecf5", "#22c55e", "#eab308"];
const SKETCH_PROMPTS = [
  "Gesture study — capture the motion, not the detail",
  "Value study — three tones only",
  "Contour drawing — one continuous line",
  "Silhouette — read it as a shape",
  "Negative space — draw the gaps",
];
const SKETCH_SECONDS = 30;

function TimedSketch({ exhibitId, onSaved }) {
  const canvasRef = useRef(null);
  const strokes = useRef([]);
  const cur = useRef(null);
  const [time, setTime] = useState(SKETCH_SECONDS);
  const [running, setRunning] = useState(false);
  const [color, setColor] = useState(SKETCH_PALETTE[0]);
  const [width, setWidth] = useState(3);
  const [eraser, setEraser] = useState(false);
  const [prompt] = useState(() => SKETCH_PROMPTS[Math.floor(Math.random() * SKETCH_PROMPTS.length)]);
  const [strokeCount, setStrokeCount] = useState(0);
  const timerRef = useRef(null);
  // Live refs so mid-stroke handlers see the latest tool without re-binding.
  const toolRef = useRef({ color, width, eraser });
  toolRef.current = { color, width, eraser };

  const clearCanvas = () => {
    const c = canvasRef.current; if (!c) return;
    c.getContext("2d").clearRect(0, 0, c.width, c.height);
  };

  // Full redraw from the stroke list (used after undo).
  const redraw = () => {
    const c = canvasRef.current; if (!c) return;
    const ctx = c.getContext("2d");
    ctx.clearRect(0, 0, c.width, c.height);
    ctx.lineCap = "round"; ctx.lineJoin = "round";
    for (const s of strokes.current) {
      ctx.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
      ctx.strokeStyle = s.color; ctx.lineWidth = s.width;
      ctx.beginPath();
      s.points.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
      ctx.stroke();
    }
    ctx.globalCompositeOperation = "source-over";
  };

  const start = () => {
    strokes.current = []; setStrokeCount(0); clearCanvas();
    setTime(SKETCH_SECONDS); setRunning(true);
    timerRef.current = setInterval(() => {
      setTime((t) => {
        if (t <= 1) { clearInterval(timerRef.current); setRunning(false); save(); return 0; }
        return t - 1;
      });
    }, 1000);
  };

  const undo = () => {
    strokes.current.pop(); setStrokeCount(strokes.current.length); redraw();
  };

  const pos = (e) => {
    const r = canvasRef.current.getBoundingClientRect();
    const p = e.touches ? e.touches[0] : e;
    // Map CSS pixels to the canvas' internal coordinate space.
    const sx = canvasRef.current.width / r.width, sy = canvasRef.current.height / r.height;
    return [Math.round((p.clientX - r.left) * sx), Math.round((p.clientY - r.top) * sy)];
  };
  const down = (e) => {
    if (!running) return;
    const { color: c, width: w, eraser: er } = toolRef.current;
    cur.current = { points: [pos(e)], color: c, width: er ? w * 3 : w, erase: er };
  };
  const move = (e) => {
    if (!running || !cur.current) return;
    const [x, y] = pos(e); const pts = cur.current.points;
    pts.push([x, y]);
    const ctx = canvasRef.current.getContext("2d");
    ctx.globalCompositeOperation = cur.current.erase ? "destination-out" : "source-over";
    ctx.strokeStyle = cur.current.color; ctx.lineWidth = cur.current.width;
    ctx.lineCap = "round"; ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(pts[pts.length - 2][0], pts[pts.length - 2][1]);
    ctx.lineTo(x, y); ctx.stroke();
    ctx.globalCompositeOperation = "source-over";
    if (e.touches) e.preventDefault();
  };
  const up = () => {
    if (cur.current) {
      strokes.current.push(cur.current); cur.current = null;
      setStrokeCount(strokes.current.length);
    }
  };

  const save = async () => {
    if (!exhibitId) { onSaved("Sketch captured (no exhibit to attach)."); return; }
    let thumb = null;
    try { thumb = canvasRef.current.toDataURL("image/png"); } catch (e) {}
    try {
      const r = await axios.post(`${API}/art/exhibits/${exhibitId}/sketch`, {
        strokes: strokes.current, thumbnail: thumb ? "data:present" : null,
        duration_sec: SKETCH_SECONDS, prompt,
      });
      onSaved(`Sketch saved as derivative item ${r.data.item_id} (${strokes.current.length} strokes).`);
    } catch (e) { onSaved("Sketch save failed."); }
  };

  useEffect(() => () => clearInterval(timerRef.current), []);

  const swatch = (c) => ({
    width: 44, height: 44, minWidth: 44, borderRadius: 10, cursor: "pointer",
    background: c, border: color === c && !eraser ? `3px solid ${TEXT}` : `1px solid ${BORDER}`,
  });

  return (
    <div style={{ maxWidth: 640, margin: "0 auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2 style={{ margin: 0 }}>Timed Sketch</h2>
        <div style={{ fontSize: 28, fontWeight: 800, color: time <= 5 ? "#ef4444" : CYAN }}
          data-testid="sketch-timer" role="timer" aria-live="assertive" aria-atomic="true">
          {time}s
        </div>
      </div>
      <p style={{ color: MUTED, fontSize: 14 }}>
        Prompt: <strong style={{ color: TEXT }}>{prompt}</strong>. Saved as a derivative work.
      </p>

      {/* Tool palette */}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center",
        marginBottom: 10 }} role="group" aria-label="Sketch tools">
        {SKETCH_PALETTE.map((c) => (
          <button key={c} data-testid="sketch-color" aria-label={`Color ${c}`}
            aria-pressed={color === c && !eraser}
            onClick={() => { setColor(c); setEraser(false); }} style={swatch(c)} />
        ))}
        <button data-testid="sketch-eraser" onClick={() => setEraser((e) => !e)}
          aria-pressed={eraser}
          style={{ ...btn(eraser ? PURPLE : "#556"), padding: "8px 12px",
            background: eraser ? `${PURPLE}22` : "transparent" }}>
          Eraser
        </button>
        <label style={{ display: "flex", alignItems: "center", gap: 6, color: MUTED, fontSize: 13 }}>
          Size
          <input type="range" min={1} max={12} value={width} data-testid="sketch-size"
            aria-label="Brush size"
            onChange={(e) => setWidth(Number(e.target.value))}
            style={{ accentColor: CYAN }} />
          <span style={{ width: 20, textAlign: "right", color: TEXT }}>{width}</span>
        </label>
        <button style={{ ...btn("#556"), padding: "8px 12px" }} onClick={undo}
          disabled={strokeCount === 0} data-testid="sketch-undo" aria-label="Undo last stroke">
          Undo
        </button>
      </div>

      <canvas ref={canvasRef} width={600} height={340} data-testid="sketch-canvas"
        tabIndex={0} role="img"
        aria-label={`Sketch canvas for prompt: ${prompt}. Press Enter or Space to start the timer, then draw with a pointer.`}
        onKeyDown={(e) => { if (!running && (e.key === "Enter" || e.key === " ")) { e.preventDefault(); start(); } }}
        onMouseDown={down} onMouseMove={move} onMouseUp={up} onMouseLeave={up}
        onTouchStart={down} onTouchMove={move} onTouchEnd={up}
        style={{ width: "100%", height: 340, background: "#0a0f1c", borderRadius: 14,
          border: `1px solid ${CYAN}33`, touchAction: "none", cursor: "crosshair" }} />
      <div style={{ marginTop: 12, display: "flex", gap: 8, alignItems: "center" }}>
        <button style={btn(CYAN)} onClick={start} disabled={running} data-testid="sketch-start">
          {running ? "Drawing…" : `Start ${SKETCH_SECONDS}s sketch`}
        </button>
        {!running && <button style={btn(PURPLE)} onClick={save}>Save now</button>}
        <span style={{ color: MUTED, fontSize: 13 }}>{strokeCount} strokes</span>
      </div>
    </div>
  );
}

// ── Micro-game 3: Critique Cards ────────────────────────────────────────────
const RATING_LABELS = { 1: "Needs work", 2: "Developing", 3: "Solid", 4: "Strong", 5: "Masterful" };
const CRITIQUE_RUBRIC = {
  composition: {
    label: "Composition",
    hint: "Does your eye land where intended? Check the focal point, balance, use of the rule of thirds, leading lines, and negative space.",
    ph: "e.g. Strong diagonal leads to the focal point; a touch bottom-heavy…",
  },
  color: {
    label: "Color & Value",
    hint: "Is the palette intentional? Consider warm/cool balance, complementary accents, value grouping, and overall harmony.",
    ph: "e.g. Cool base with a warm accent; darks could group more cleanly…",
  },
  execution: {
    label: "Execution",
    hint: "How is the craft? Look at edge control, consistency of technique, finish, and confidence of the marks.",
    ph: "e.g. Clean edges in the light, looser handling in shadow reads well…",
  },
};

function CritiqueCards({ items, exhibitId, onSaved }) {
  const [composition, setComposition] = useState("");
  const [color, setColor] = useState("");
  const [execution, setExecution] = useState("");
  const [rating, setRating] = useState(3);
  const [targetId, setTargetId] = useState(items[0]?.id || items[0]?.path || "");
  const setters = { composition: setComposition, color: setColor, execution: setExecution };
  const values = { composition, color, execution };
  const target = items.find((i) => (i.id || i.path) === targetId) || items[0];

  const submit = async () => {
    if (!exhibitId) { onSaved("Critique captured (no exhibit)."); return; }
    try {
      await axios.post(`${API}/art/exhibits/${exhibitId}/critique`, {
        item_id: target?.id, composition, color, execution, rating,
      });
      onSaved("Critique card saved.");
      setComposition(""); setColor(""); setExecution(""); setRating(3);
    } catch (e) { onSaved("Critique save failed."); }
  };

  const field = (key) => {
    const { label, hint, ph } = CRITIQUE_RUBRIC[key];
    return (
      <label style={{ display: "block", marginBottom: 14 }}>
        <div style={{ fontSize: 12, textTransform: "uppercase", letterSpacing: 1,
          color: FAINT, marginBottom: 4 }}>{label}</div>
        <div style={{ fontSize: 12, color: MUTED, marginBottom: 6 }}>{hint}</div>
        <textarea value={values[key]} onChange={(e) => setters[key](e.target.value)}
          placeholder={ph} rows={2} aria-label={`${label} critique`}
          style={{ width: "100%", background: "#0a0f1c", color: TEXT,
            border: `1px solid ${BORDER}`, borderRadius: 10, padding: 10, resize: "vertical",
            minHeight: 44 }} />
      </label>
    );
  };

  return (
    <div style={{ maxWidth: 560, margin: "0 auto" }}>
      <h2 style={{ marginTop: 0 }}>Critique Cards</h2>
      <p style={{ color: MUTED, fontSize: 14 }}>
        Give structured feedback using the composition / color / execution rubric.
      </p>
      {items.length > 1 && (
        <label style={{ display: "block", marginBottom: 14 }}>
          <div style={{ fontSize: 12, textTransform: "uppercase", letterSpacing: 1,
            color: FAINT, marginBottom: 4 }}>Work being critiqued</div>
          <select value={targetId} onChange={(e) => setTargetId(e.target.value)}
            aria-label="Choose which work to critique"
            style={{ width: "100%", minHeight: 44, background: "#0a0f1c", color: TEXT,
              border: `1px solid ${BORDER}`, borderRadius: 10, padding: "0 10px" }}>
            {items.map((it) => (
              <option key={it.id || it.path} value={it.id || it.path}>
                {it.meta?.title || "Untitled"}
              </option>
            ))}
          </select>
        </label>
      )}
      {field("composition")}
      {field("color")}
      {field("execution")}
      <div style={{ margin: "8px 0 16px" }}>
        <div style={{ fontSize: 12, textTransform: "uppercase", letterSpacing: 1,
          color: FAINT, marginBottom: 6 }}>
          Overall — <span style={{ color: PURPLE }}>{RATING_LABELS[rating]}</span>
        </div>
        <div style={{ display: "flex", gap: 6 }} role="radiogroup" aria-label="Overall rating">
          {[1, 2, 3, 4, 5].map((r) => (
            <button key={r} onClick={() => setRating(r)} role="radio" aria-checked={r === rating}
              aria-label={`${r} of 5 — ${RATING_LABELS[r]}`}
              data-testid="critique-star" style={{ ...btn(r <= rating ? PURPLE : "#556"),
                minWidth: 44, background: r <= rating ? `${PURPLE}22` : "transparent" }}>
              ★
            </button>
          ))}
        </div>
      </div>
      <button style={{ ...btn(CYAN), width: "100%" }} onClick={submit} data-testid="critique-submit">
        Save critique
      </button>
    </div>
  );
}
