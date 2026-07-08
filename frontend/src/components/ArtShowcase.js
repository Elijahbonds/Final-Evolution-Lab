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
});

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
    <div style={{ minHeight: "100vh", background: BG, color: "#e8ecf5",
      fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif" }}>
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
        <p style={{ color: "#8b94ab", marginTop: 6 }}>
          Curate a gallery, play critique micro-games, learn from Creator Cards.
        </p>
        {status && (
          <div style={{ marginTop: 8, color: CYAN, fontSize: 14 }}>{status}</div>
        )}
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
            style={{ ...btn(tab === id ? CYAN : "#556"),
              background: tab === id ? `${CYAN}22` : "transparent",
              color: tab === id ? CYAN : "#8b94ab" }}>
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
  return (
    <div>
      <h2 style={{ fontSize: 18, color: "#c3ccdd" }}>Works</h2>
      <div style={{ display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 16 }}>
        {images.map((it, i) => (
          <button key={i} data-testid="gallery-card" onClick={() => onOpen(it)}
            style={{ padding: 0, border: `1px solid #1c2438`, borderRadius: 14,
              overflow: "hidden", background: CARD, cursor: "pointer", textAlign: "left" }}>
            <img src={it.path} alt={it.meta?.alt || it.meta?.title || "artwork"}
              style={{ width: "100%", height: 160, objectFit: "cover", display: "block" }} />
            <div style={{ padding: "10px 12px" }}>
              <div style={{ fontWeight: 700 }}>{it.meta?.title || "Untitled"}</div>
              <div style={{ fontSize: 12, color: "#8b94ab" }}>{it.meta?.technique}</div>
            </div>
          </button>
        ))}
      </div>

      {models.length > 0 && (
        <>
          <h2 style={{ fontSize: 18, color: "#c3ccdd", marginTop: 28 }}>3D Sculpture</h2>
          {models.map((m, i) => (
            <ModelViewerCard key={i} item={m} onOpen={onOpen} />
          ))}
        </>
      )}
    </div>
  );
}

function ModelViewerCard({ item, onOpen }) {
  const canvasRef = useRef(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let handle;
    (async () => {
      try {
        const res = await fetch(item.path);
        const gltf = await res.json();
        handle = mountGltfViewer(canvasRef.current, gltf);
      } catch (e) { setError(true); }
    })();
    return () => handle && handle.dispose();
  }, [item.path]);
  return (
    <div style={{ border: `1px solid #1c2438`, borderRadius: 14, overflow: "hidden",
      background: CARD, maxWidth: 480 }}>
      <div style={{ position: "relative", height: 320,
        background: "radial-gradient(circle at 50% 40%, #0c1a33, #050810)" }}>
        {error ? (
          <div role="img" aria-label={item.meta?.alt || "3D model preview"}
            style={{ display: "grid", placeItems: "center", height: "100%", color: "#8b94ab" }}>
            3D preview unavailable
          </div>
        ) : (
          <canvas ref={canvasRef} data-testid="gltf-canvas"
            aria-label={item.meta?.alt || "Interactive 3D model, drag to orbit"}
            style={{ width: "100%", height: "100%", display: "block", touchAction: "none" }} />
        )}
      </div>
      <div style={{ padding: "12px 14px", display: "flex",
        justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <div style={{ fontWeight: 700 }}>{item.meta?.title || "3D Model"}</div>
          <div style={{ fontSize: 12, color: "#8b94ab" }}>
            drag to orbit · scroll to zoom · {item.meta?.license}
          </div>
        </div>
        <button style={btn(CYAN)} onClick={() => onOpen(item)}>Details</button>
      </div>
    </div>
  );
}

// ── Lightbox ────────────────────────────────────────────────────────────────
function Lightbox({ item, onClose, onLesson }) {
  const m = item.meta || {};
  return (
    <div onClick={onClose} role="dialog" aria-modal="true" style={{
      position: "fixed", inset: 0, background: "rgba(2,4,10,.85)", zIndex: 50,
      display: "grid", placeItems: "center", padding: 16,
      animation: "artFade .18s ease" }}>
      <div onClick={(e) => e.stopPropagation()} style={{ background: CARD,
        border: `1px solid ${CYAN}33`, borderRadius: 18, maxWidth: 820, width: "100%",
        display: "grid", gridTemplateColumns: "1fr", overflow: "hidden",
        boxShadow: `0 0 60px ${CYAN}22` }}>
        <div style={{ display: "grid", gridTemplateColumns: "minmax(0,1.2fr) minmax(0,1fr)" }}>
          <div style={{ background: "#02040a", minHeight: 260, display: "grid",
            placeItems: "center" }}>
            {item.type === "image" ? (
              <img src={item.path} alt={m.alt || m.title || "artwork"}
                style={{ width: "100%", maxHeight: 420, objectFit: "contain" }} />
            ) : (
              <div role="img" aria-label={m.alt} style={{ color: "#8b94ab", padding: 24 }}>
                {m.title} (3D)
              </div>
            )}
          </div>
          <div style={{ padding: 20 }}>
            <h3 style={{ margin: "0 0 4px", fontSize: 22 }}>{m.title || "Untitled"}</h3>
            <div style={{ color: CYAN, fontSize: 13, marginBottom: 12 }}>{m.artist}</div>
            <Meta label="Technique" value={m.technique} />
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
        <button onClick={onClose} aria-label="Close"
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
        color: "#6b7590" }}>{label}</div>
      <div style={{ fontSize: 14 }}>{value}</div>
    </div>
  );
}

// ── Lesson modal (Creator Card tie-in) ──────────────────────────────────────
function LessonModal({ lesson, onClose }) {
  return (
    <div onClick={onClose} role="dialog" aria-modal="true" style={{
      position: "fixed", inset: 0, background: "rgba(2,4,10,.85)", zIndex: 60,
      display: "grid", placeItems: "center", padding: 16 }}>
      <div onClick={(e) => e.stopPropagation()} data-testid="lesson-modal" style={{
        background: CARD, border: `1px solid ${PURPLE}55`, borderRadius: 18,
        maxWidth: 460, width: "100%", padding: 24, boxShadow: `0 0 60px ${PURPLE}33` }}>
        <div style={{ fontSize: 12, color: PURPLE, letterSpacing: 1 }}>
          CREATOR CARD · {lesson.cardId}
        </div>
        <h3 style={{ margin: "6px 0 14px", fontSize: 22 }}>{lesson.title}</h3>
        <div style={{ display: "grid", gap: 10 }}>
          {lesson.lessons.map((l) => (
            <div key={l} style={{ padding: "12px 14px", borderRadius: 12,
              background: `${PURPLE}12`, border: `1px solid ${PURPLE}33` }}>
              <div style={{ fontWeight: 700 }}>{l.replace(/_/g, " ")}</div>
              <div style={{ fontSize: 13, color: "#8b94ab" }}>
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
function GuessTechnique({ exhibitId, recording, onLesson }) {
  const seed = recording ? RECORD_SEED : Math.floor(Math.random() * 1e9);
  const [round, setRound] = useState(null);
  const [qi, setQi] = useState(0);
  const [reveal, setReveal] = useState(null);
  const [score, setScore] = useState(0);

  const load = useCallback(async () => {
    setReveal(null); setQi(0); setScore(0);
    try {
      const r = await axios.get(`${API}/art/guess-technique/round`, {
        params: { seed, count: 5 },
      });
      setRound(r.data);
    } catch (e) { setRound({ questions: [] }); }
  }, [seed]);

  useEffect(() => { load(); }, [load]);

  const answer = async (opt) => {
    const q = round.questions[qi];
    try {
      const r = await axios.post(`${API}/art/guess-technique/answer`, {
        seed: round.seed, question_id: q.id, selected: opt, exhibit_id: exhibitId,
      });
      setReveal(r.data);
      if (r.data.is_correct) setScore((s) => s + 1);
    } catch (e) { /* ignore */ }
  };

  if (!round) return <div style={{ color: "#8b94ab" }}>Loading round…</div>;
  if (round.questions.length === 0)
    return <div style={{ color: "#8b94ab" }}>No questions available.</div>;

  const done = qi >= round.questions.length;
  if (done)
    return (
      <div style={{ textAlign: "center", padding: 40 }}>
        <h2>Round complete</h2>
        <div style={{ fontSize: 40, fontWeight: 800, color: CYAN }}>
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
      <div style={{ fontSize: 13, color: "#8b94ab" }}>
        Question {qi + 1} / {round.questions.length} · seed {round.seed}
      </div>
      <img src={q.asset} alt={q.alt} data-testid="gt-asset"
        style={{ width: "100%", height: 220, objectFit: "cover", borderRadius: 14,
          margin: "12px 0", border: `1px solid #1c2438` }} />
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
        <div data-testid="gt-reveal" style={{ marginTop: 16, padding: 16, borderRadius: 12,
          background: `${CYAN}10`, border: `1px solid ${CYAN}33` }}>
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
function TimedSketch({ exhibitId, onSaved }) {
  const canvasRef = useRef(null);
  const strokes = useRef([]);
  const cur = useRef(null);
  const [time, setTime] = useState(30);
  const [running, setRunning] = useState(false);
  const timerRef = useRef(null);

  const start = () => {
    strokes.current = [];
    const ctx = canvasRef.current.getContext("2d");
    ctx.clearRect(0, 0, canvasRef.current.width, canvasRef.current.height);
    setTime(30); setRunning(true);
    timerRef.current = setInterval(() => {
      setTime((t) => {
        if (t <= 1) { clearInterval(timerRef.current); setRunning(false); save(); return 0; }
        return t - 1;
      });
    }, 1000);
  };

  const pos = (e) => {
    const r = canvasRef.current.getBoundingClientRect();
    const p = e.touches ? e.touches[0] : e;
    return [Math.round(p.clientX - r.left), Math.round(p.clientY - r.top)];
  };
  const down = (e) => { if (!running) return; cur.current = { points: [pos(e)], color: CYAN, width: 3 }; };
  const move = (e) => {
    if (!running || !cur.current) return;
    const [x, y] = pos(e); const pts = cur.current.points;
    pts.push([x, y]);
    const ctx = canvasRef.current.getContext("2d");
    ctx.strokeStyle = CYAN; ctx.lineWidth = 3; ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(pts[pts.length - 2][0], pts[pts.length - 2][1]);
    ctx.lineTo(x, y); ctx.stroke();
    if (e.touches) e.preventDefault();
  };
  const up = () => { if (cur.current) { strokes.current.push(cur.current); cur.current = null; } };

  const save = async () => {
    if (!exhibitId) { onSaved("Sketch captured (no exhibit to attach)."); return; }
    let thumb = null;
    try { thumb = canvasRef.current.toDataURL("image/png"); } catch (e) {}
    try {
      const r = await axios.post(`${API}/art/exhibits/${exhibitId}/sketch`, {
        strokes: strokes.current, thumbnail: thumb ? "data:present" : null,
        duration_sec: 30, prompt: "60-second study",
      });
      onSaved(`Sketch saved as derivative item ${r.data.item_id} (${strokes.current.length} strokes).`);
    } catch (e) { onSaved("Sketch save failed."); }
  };

  useEffect(() => () => clearInterval(timerRef.current), []);

  return (
    <div style={{ maxWidth: 640, margin: "0 auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2 style={{ margin: 0 }}>Timed Sketch</h2>
        <div style={{ fontSize: 28, fontWeight: 800, color: time <= 5 ? "#ef4444" : CYAN }}
          data-testid="sketch-timer">{time}s</div>
      </div>
      <p style={{ color: "#8b94ab", fontSize: 14 }}>Draw a 60-second study. Saved as a derivative work.</p>
      <canvas ref={canvasRef} width={600} height={340} data-testid="sketch-canvas"
        onMouseDown={down} onMouseMove={move} onMouseUp={up} onMouseLeave={up}
        onTouchStart={down} onTouchMove={move} onTouchEnd={up}
        style={{ width: "100%", height: 340, background: "#0a0f1c", borderRadius: 14,
          border: `1px solid ${CYAN}33`, touchAction: "none", cursor: "crosshair" }} />
      <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
        <button style={btn(CYAN)} onClick={start} disabled={running} data-testid="sketch-start">
          {running ? "Drawing…" : "Start 30s sketch"}
        </button>
        {!running && <button style={btn(PURPLE)} onClick={save}>Save now</button>}
      </div>
    </div>
  );
}

// ── Micro-game 3: Critique Cards ────────────────────────────────────────────
function CritiqueCards({ items, exhibitId, onSaved }) {
  const [composition, setComposition] = useState("");
  const [color, setColor] = useState("");
  const [execution, setExecution] = useState("");
  const [rating, setRating] = useState(3);
  const target = items[0];

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

  const field = (label, value, set, ph) => (
    <label style={{ display: "block", marginBottom: 12 }}>
      <div style={{ fontSize: 12, textTransform: "uppercase", letterSpacing: 1,
        color: "#6b7590", marginBottom: 4 }}>{label}</div>
      <textarea value={value} onChange={(e) => set(e.target.value)} placeholder={ph}
        rows={2} style={{ width: "100%", background: "#0a0f1c", color: "#e8ecf5",
          border: `1px solid #1c2438`, borderRadius: 10, padding: 10, resize: "vertical",
          minHeight: 44 }} />
    </label>
  );

  return (
    <div style={{ maxWidth: 560, margin: "0 auto" }}>
      <h2 style={{ marginTop: 0 }}>Critique Cards</h2>
      <p style={{ color: "#8b94ab", fontSize: 14 }}>
        Give structured feedback on <strong>{target?.meta?.title || "the work"}</strong>.
      </p>
      {field("Composition", composition, setComposition, "Framing, balance, focal point…")}
      {field("Color", color, setColor, "Palette, harmony, contrast…")}
      {field("Execution", execution, setExecution, "Craft, technique, finish…")}
      <div style={{ margin: "8px 0 16px" }}>
        <div style={{ fontSize: 12, textTransform: "uppercase", letterSpacing: 1,
          color: "#6b7590", marginBottom: 6 }}>Overall</div>
        <div style={{ display: "flex", gap: 6 }}>
          {[1, 2, 3, 4, 5].map((r) => (
            <button key={r} onClick={() => setRating(r)} aria-label={`${r} stars`}
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
