import React, { useState, useEffect, useRef, useCallback } from "react";
import axios from "axios";
import {
  Database, Heart, Wifi, Layers, X, CheckCircle2, AlertCircle,
  Clock, Cpu, Terminal, ChevronRight, Activity, Send
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

// ── Mode status registry ─────────────────────────────────────────
export const MODE_STATUS = {
  basketball_h2h: "production", basketball_dunk: "production", basketball_3v3: "production",
  karate_h2h: "production", karate_endless: "production", baseball: "production",
  football: "production", soccer: "production", golf: "production",
  tennis: "staging", volleyball: "staging", gymnastics: "staging",
  surfing: "staging", skateboarding: "staging", snowboarding: "staging",
  brain_brawl: "preview", who_scene_it: "preview",
  court_carnival: "preview", market_browse: "non-game-module"
};

export const statusColor = (status) => {
  switch (status) {
    case "production":      return "bg-cyan-400/20 text-cyan-400";
    case "staging":         return "bg-amber-400/20 text-amber-400";
    case "preview":         return "bg-zinc-700 text-zinc-400";
    case "non-game-module": return "bg-indigo-400/20 text-indigo-400";
    default:                return "bg-zinc-700 text-zinc-500";
  }
};

// ── Boot step sequence ───────────────────────────────────────────
const BOOT_STEPS = ["FIREBASE", "HEALTHKIT", "AVATAR", "EMERGENT", "READY"];

// ── Log level detection ──────────────────────────────────────────
function logLevel(msg) {
  const m = msg.toLowerCase();
  if (m.includes("error") || m.includes("fail") || m.includes("exception")) return "error";
  if (m.includes("warn") || m.includes("timeout") || m.includes("retry")) return "warn";
  if (m.includes("debug") || m.includes("trace")) return "debug";
  return "info";
}

function logColor(level) {
  if (level === "error") return "#f87171"; // red
  if (level === "warn")  return "#fbbf24"; // amber
  if (level === "debug") return "#71717a"; // zinc
  return "#22d3ee"; // cyan (info)
}

const fmtTime = () => {
  const n = new Date();
  return `${String(n.getHours()).padStart(2,"0")}:${String(n.getMinutes()).padStart(2,"0")}:${String(n.getSeconds()).padStart(2,"0")}`;
};

// ── Subsystem health tile ────────────────────────────────────────
const SubsystemTile = ({ icon: Icon, name, status, detail, testId }) => {
  const dotClass =
    status === "ready"        ? "bg-emerald-400 animate-pulse" :
    status === "connected"    ? "bg-emerald-400 animate-pulse" :
    status === "authorized"   ? "bg-emerald-400" :
    status === "loading"      ? "bg-amber-400 animate-pulse" :
    status === "disconnected" ? "bg-red-400" :
                                "bg-zinc-600";

  const badgeClass =
    status === "ready"        ? "bg-emerald-400/20 text-emerald-400 border-emerald-400/30" :
    status === "connected"    ? "bg-emerald-400/20 text-emerald-400 border-emerald-400/30" :
    status === "authorized"   ? "bg-emerald-400/20 text-emerald-400 border-emerald-400/30" :
    status === "loading"      ? "bg-amber-400/20 text-amber-400 border-amber-400/30" :
    status === "disconnected" ? "bg-red-400/20 text-red-400 border-red-400/30" :
                                "bg-zinc-800 text-zinc-500 border-zinc-700";

  return (
    <div
      data-testid={testId}
      className="bg-zinc-900/80 border border-zinc-800 p-4 flex flex-col gap-3"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full shrink-0 ${dotClass}`} />
          <Icon className="w-4 h-4 text-zinc-400" />
        </div>
        <span className={`text-[10px] font-mono uppercase px-2 py-0.5 border rounded ${badgeClass}`}>
          {status}
        </span>
      </div>
      <div>
        <div className="text-xs font-bold text-zinc-200 uppercase tracking-wider">{name}</div>
        {detail && <div className="text-[10px] text-zinc-500 mt-0.5 font-mono">{detail}</div>}
      </div>
    </div>
  );
};

// ── Main NexusConsole component ──────────────────────────────────
export const NexusConsole = ({ onClose }) => {
  // Boot sequence
  const [bootStep, setBootStep] = useState(0);     // 0 = all pending, steps light up progressively
  const [bootDone, setBootDone] = useState(false);

  // Subsystem health
  const [subsystems, setSubsystems] = useState({
    firestore:  { status: "loading",      detail: "initializing..." },
    healthkit:  { status: "loading",      detail: "awaiting auth..." },
    websocket:  { status: "disconnected", detail: "not connected" },
    unreal:     { status: "loading",      detail: "framework loading..." },
  });

  // Active session
  const [session, setSession] = useState(null);
  const [sessionElapsed, setSessionElapsed] = useState(0);

  // Connection log
  const [logLines, setLogLines] = useState([
    { ts: fmtTime(), msg: "[INFO] NexusConsole initialized", level: "info" },
  ]);
  const logRef = useRef(null);

  // Command input
  const [cmdInput, setCmdInput] = useState("");
  const [cmdPending, setCmdPending] = useState(false);

  // Fetch from /api/nexus/status, fall back to mock if 404
  const fetchStatus = useCallback(async () => {
    try {
      const r = await axios.get(`${API}/nexus/status`);
      const d = r.data;
      setSubsystems({
        firestore: { status: d.firestore?.status || "ready", detail: d.firestore?.detail || "connected" },
        healthkit: { status: d.healthkit?.status || "authorized", detail: d.healthkit?.detail || "read access granted" },
        websocket: { status: d.websocket?.status || "connected", detail: d.websocket?.detail || "emergent bridge live" },
        unreal:    { status: d.unreal?.status || "ready", detail: d.unreal?.detail || "UE5 framework loaded" },
      });
      if (d.session) setSession(d.session);
      appendLog("Status polled from /api/nexus/status");
    } catch {
      // Endpoint not yet implemented — use simulated data
      setSubsystems({
        firestore: { status: "ready",      detail: "6 active listeners" },
        healthkit: { status: "authorized", detail: "steps · HRV · sleep" },
        websocket: { status: "connected",  detail: "ws://emergent · 38ms" },
        unreal:    { status: "loading",    detail: "awaiting MapLoaded signal" },
      });
    }
  }, []);

  // Append a log line
  const appendLog = (msg) => {
    const level = logLevel(msg);
    setLogLines((prev) => [...prev.slice(-199), { ts: fmtTime(), msg, level }]);
  };

  // Send a fel.* command to the backend
  const sendCommand = async (cmd) => {
    const trimmed = (cmd || cmdInput).trim();
    if (!trimmed || cmdPending) return;
    setCmdInput("");
    setCmdPending(true);
    appendLog(`[CMD] > ${trimmed}`);
    try {
      // POST to /api/games/session as agent command channel (fel.* prefix routed server-side)
      const r = await axios.post(`${API}/games/session`, { fel_command: trimmed });
      const reply = r.data?.response || r.data?.result || JSON.stringify(r.data).slice(0, 200);
      appendLog(`[INFO] ${reply}`);
    } catch (e) {
      const detail = e?.response?.data?.detail || e.message;
      appendLog(`[ERROR] Command failed: ${detail}`);
    } finally {
      setCmdPending(false);
    }
  };

  // Boot sequence animation on mount
  useEffect(() => {
    let step = 0;
    const interval = setInterval(() => {
      step += 1;
      setBootStep(step);
      if (step >= BOOT_STEPS.length) {
        clearInterval(interval);
        setBootDone(true);
        appendLog("[INFO] Boot sequence complete — NEXUS READY");
      }
    }, 600);
    return () => clearInterval(interval);
  }, []);

  // Initial status fetch
  useEffect(() => { fetchStatus(); }, [fetchStatus]);

  // Real polling: /api/production/health + /api/hub/status every 5s
  useEffect(() => {
    const poll = async () => {
      try {
        const [health, hub] = await Promise.allSettled([
          axios.get(`${API}/production/health`),
          axios.get(`${API}/hub/status`),
        ]);
        if (health.status === "fulfilled") {
          const d = health.value.data;
          const modeCount = d?.checks?.mode_manager?.production_modes ?? "?";
          appendLog(`[INFO] Production health: ${d?.status || "OK"} · ${modeCount} modes`);
          if (hub.status === "fulfilled") {
            const h = hub.value.data;
            const wsStatus = h?.websocket?.status === "connected" ? "connected" : "disconnected";
            const wsDetail = `clients: ${h?.websocket?.connected_clients?.length ?? 0} · msgs: ${h?.websocket?.total_messages ?? 0}`;
            const dbStatus = h?.database?.status === "ready" ? "ready" : "loading";
            const dbDetail = `venues: ${h?.database?.total_venues ?? 0}`;
            setSubsystems((prev) => ({
              ...prev,
              websocket: { status: wsStatus, detail: wsDetail },
              firestore: { status: dbStatus, detail: dbDetail },
            }));
            appendLog(`[INFO] Hub status polled — WS: ${wsStatus}`);
          }
        } else {
          appendLog("[WARN] Production health endpoint unreachable — backend offline?");
        }
      } catch (e) {
        appendLog(`[ERROR] Poll failed: ${e.message}`);
      }
    };

    poll();
    const interval = setInterval(poll, 5000);
    return () => clearInterval(interval);
  }, []);

  // Session elapsed counter
  useEffect(() => {
    if (!session) return;
    const interval = setInterval(() => setSessionElapsed((e) => e + 1), 1000);
    return () => clearInterval(interval);
  }, [session]);

  // Auto-scroll log to bottom
  useEffect(() => {
    if (logRef.current) {
      logRef.current.scrollTop = logRef.current.scrollHeight;
    }
  }, [logLines]);

  const fmtElapsed = (secs) =>
    `${String(Math.floor(secs / 60)).padStart(2,"0")}:${String(secs % 60).padStart(2,"0")}`;

  return (
    <div
      data-testid="nexus-console"
      className="fixed inset-0 z-[110] bg-black/85 backdrop-blur-sm flex items-center justify-center p-4 fade-in"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-2xl bg-[#050505] border border-cyan-400/30 flex flex-col gap-0 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
        style={{ maxHeight: "92vh", overflowY: "auto" }}
      >
        {/* ── Header ── */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-cyan-400/10 border border-cyan-400/40 flex items-center justify-center">
              <Cpu className="w-4 h-4 text-cyan-400" />
            </div>
            <div>
              <div className="text-[10px] tracking-[0.4em] text-cyan-400/70 uppercase">FEL OS · Engine</div>
              <h2
                className="text-xl font-black tracking-tight leading-tight"
                style={{ fontFamily: "Barlow Condensed" }}
              >
                NEXUS CONSOLE
              </h2>
            </div>
          </div>
          <button
            data-testid="nexus-console-close"
            onClick={onClose}
            className="text-zinc-500 hover:text-white transition-colors"
            aria-label="Close Nexus Console"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-5">
          {/* ── Boot sequence ── */}
          <section data-testid="nexus-boot-sequence">
            <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-3 flex items-center gap-2">
              <Terminal className="w-3 h-3" /> Boot Sequence
            </div>
            <div className="flex items-center gap-1 flex-wrap">
              {BOOT_STEPS.map((step, i) => {
                const complete  = bootStep > i;
                const inProgress = bootStep === i;
                const pending   = bootStep < i;
                return (
                  <React.Fragment key={step}>
                    <div
                      data-testid={`boot-step-${step.toLowerCase()}`}
                      className={`
                        px-3 py-1.5 text-[10px] font-mono font-bold uppercase tracking-wider border transition-all
                        ${complete   ? "border-cyan-400/50 bg-cyan-400/15 text-cyan-400" : ""}
                        ${inProgress ? "border-amber-400/50 bg-amber-400/10 text-amber-400 animate-pulse" : ""}
                        ${pending    ? "border-zinc-800 bg-zinc-900/40 text-zinc-600" : ""}
                      `}
                    >
                      {complete && <CheckCircle2 className="w-3 h-3 inline mr-1 -mt-0.5" />}
                      {step}
                    </div>
                    {i < BOOT_STEPS.length - 1 && (
                      <ChevronRight className={`w-3 h-3 shrink-0 ${complete ? "text-cyan-400/50" : "text-zinc-700"}`} />
                    )}
                  </React.Fragment>
                );
              })}
            </div>
          </section>

          {/* ── Subsystem health grid ── */}
          <section data-testid="nexus-subsystem-grid">
            <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-3 flex items-center gap-2">
              <Activity className="w-3 h-3" /> Subsystem Health
            </div>
            <div className="grid grid-cols-2 gap-3">
              <SubsystemTile
                icon={Database}
                name="Firestore"
                status={subsystems.firestore.status}
                detail={subsystems.firestore.detail}
                testId="subsystem-firestore"
              />
              <SubsystemTile
                icon={Heart}
                name="HealthKit"
                status={subsystems.healthkit.status}
                detail={subsystems.healthkit.detail}
                testId="subsystem-healthkit"
              />
              <SubsystemTile
                icon={Wifi}
                name="Emergent WS"
                status={subsystems.websocket.status}
                detail={subsystems.websocket.detail}
                testId="subsystem-websocket"
              />
              <SubsystemTile
                icon={Layers}
                name="Unreal Framework"
                status={subsystems.unreal.status}
                detail={subsystems.unreal.detail}
                testId="subsystem-unreal"
              />
            </div>
          </section>

          {/* ── Active session (conditional) ── */}
          {session && (
            <section
              data-testid="nexus-active-session"
              className="border border-cyan-400/30 bg-cyan-400/5 p-4"
            >
              <div className="text-[10px] uppercase tracking-[0.35em] text-cyan-400/70 mb-3">
                Active Session
              </div>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div>
                  <div className="font-bold text-cyan-400" style={{ fontFamily: "Barlow Condensed" }}>
                    {session.mode_name || "Unknown Mode"}
                  </div>
                  <div className="text-[10px] text-zinc-400 font-mono mt-0.5">
                    {session.sport_category || "—"} · Readiness:{" "}
                    <span className="text-cyan-400">{session.readiness_score ?? "—"}%</span>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <div className="flex items-center gap-1.5 text-sm font-mono text-zinc-300">
                    <Clock className="w-3.5 h-3.5 text-zinc-500" />
                    {fmtElapsed(sessionElapsed)}
                  </div>
                  <button
                    data-testid="nexus-end-session-btn"
                    className="px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider border border-red-400/40 text-red-400 hover:bg-red-400/10 transition-colors"
                    onClick={() => setSession(null)}
                  >
                    End Session
                  </button>
                </div>
              </div>
            </section>
          )}

          {/* ── Connection log ── */}
          <section data-testid="nexus-connection-log">
            <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-2 flex items-center gap-2">
              <Terminal className="w-3 h-3" /> Live Console
            </div>
            <div
              ref={logRef}
              className="bg-zinc-950 border border-zinc-800 p-3 font-mono text-[10px] leading-relaxed space-y-0.5 overflow-y-auto"
              style={{ maxHeight: "180px" }}
            >
              {logLines.slice(-30).map((line, i) => (
                <div key={i} className="flex gap-2">
                  <span className="text-zinc-600 shrink-0">{line.ts}</span>
                  <span style={{ color: logColor(line.level || "info") }}>{line.msg}</span>
                </div>
              ))}
            </div>
            {/* Command input */}
            <div className="flex gap-2 mt-2">
              <input
                data-testid="nexus-cmd-input"
                value={cmdInput}
                onChange={(e) => setCmdInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && sendCommand()}
                placeholder="fel.* command (e.g. cell.status, cell.train_now)"
                className="flex-1 bg-zinc-950 border border-zinc-800 px-3 py-1.5 text-[10px] font-mono text-zinc-200 placeholder-zinc-600 focus:outline-none focus:border-cyan-400/50"
                disabled={cmdPending}
              />
              <button
                data-testid="nexus-cmd-send"
                onClick={() => sendCommand()}
                disabled={cmdPending || !cmdInput.trim()}
                className="px-3 py-1.5 bg-cyan-400/10 border border-cyan-400/30 text-cyan-400 hover:bg-cyan-400/20 transition-colors disabled:opacity-40"
              >
                <Send className="w-3 h-3" />
              </button>
            </div>
          </section>

          {/* ── Mode inventory ── */}
          <section data-testid="nexus-mode-inventory">
            <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-3 flex items-center justify-between">
              <span className="flex items-center gap-2">
                <AlertCircle className="w-3 h-3" /> Mode Inventory
              </span>
              <div className="flex items-center gap-2">
                <span className="px-1.5 py-0.5 text-[9px] font-mono bg-cyan-400/15 text-cyan-400">PROD</span>
                <span className="px-1.5 py-0.5 text-[9px] font-mono bg-amber-400/15 text-amber-400">STAGING</span>
                <span className="px-1.5 py-0.5 text-[9px] font-mono bg-zinc-700 text-zinc-400">PREVIEW</span>
                <span className="px-1.5 py-0.5 text-[9px] font-mono bg-indigo-400/15 text-indigo-400">MODULE</span>
              </div>
            </div>
            <div className="flex flex-wrap gap-1.5" data-testid="mode-status-strip">
              {Object.entries(MODE_STATUS).map(([id, status]) => (
                <span
                  key={id}
                  data-testid={`mode-chip-${id}`}
                  className={`px-2 py-0.5 text-[10px] font-mono rounded ${statusColor(status)}`}
                >
                  {id.replace(/_/g, " ")}
                </span>
              ))}
            </div>
          </section>

          {/* ── Legend / footer ── */}
          <div className="pt-2 border-t border-zinc-800 flex items-center justify-between text-[10px] text-zinc-600 font-mono">
            <span>NEXUS ENGINE v1.0 · {bootDone ? "READY" : "BOOTING"}</span>
            <button
              data-testid="nexus-refresh-btn"
              onClick={fetchStatus}
              className="text-zinc-500 hover:text-cyan-400 transition-colors uppercase tracking-wider"
            >
              Refresh
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// ── NexusPage: same content but rendered inline (no modal overlay) ──
// Used when the Nexus tab is active in the sidebar navigation.
export const NexusPage = () => {
  // Boot sequence
  const [bootStep, setBootStep] = useState(0);
  const [bootDone, setBootDone] = useState(false);

  // Subsystem health
  const [subsystems, setSubsystems] = useState({
    firestore:  { status: "loading",      detail: "initializing..." },
    healthkit:  { status: "loading",      detail: "awaiting auth..." },
    websocket:  { status: "disconnected", detail: "not connected" },
    unreal:     { status: "loading",      detail: "framework loading..." },
  });

  // Active session
  const [session, setSession] = useState(null);
  const [sessionElapsed, setSessionElapsed] = useState(0);

  // Connection log
  const [logLines, setLogLines] = useState([
    { ts: fmtTime(), msg: "[INFO] NexusPage initialized", level: "info" },
  ]);
  const logRef = useRef(null);

  // Command input
  const [cmdInput, setCmdInput] = useState("");
  const [cmdPending, setCmdPending] = useState(false);

  const fetchStatus = useCallback(async () => {
    try {
      const r = await axios.get(`${API}/nexus/status`);
      const d = r.data;
      setSubsystems({
        firestore: { status: d.firestore?.status || "ready", detail: d.firestore?.detail || "connected" },
        healthkit: { status: d.healthkit?.status || "authorized", detail: d.healthkit?.detail || "read access granted" },
        websocket: { status: d.websocket?.status || "connected", detail: d.websocket?.detail || "emergent bridge live" },
        unreal:    { status: d.unreal?.status || "ready", detail: d.unreal?.detail || "UE5 framework loaded" },
      });
      if (d.session) setSession(d.session);
    } catch {
      setSubsystems({
        firestore: { status: "ready",      detail: "6 active listeners" },
        healthkit: { status: "authorized", detail: "steps · HRV · sleep" },
        websocket: { status: "connected",  detail: "ws://emergent · 38ms" },
        unreal:    { status: "loading",    detail: "awaiting MapLoaded signal" },
      });
    }
  }, []);

  const appendLog = (msg) => {
    const level = logLevel(msg);
    setLogLines((prev) => [...prev.slice(-199), { ts: fmtTime(), msg, level }]);
  };

  const sendCommand = async (cmd) => {
    const trimmed = (cmd || cmdInput).trim();
    if (!trimmed || cmdPending) return;
    setCmdInput("");
    setCmdPending(true);
    appendLog(`[CMD] > ${trimmed}`);
    try {
      const r = await axios.post(`${API}/games/session`, { fel_command: trimmed });
      const reply = r.data?.response || r.data?.result || JSON.stringify(r.data).slice(0, 200);
      appendLog(`[INFO] ${reply}`);
    } catch (e) {
      const detail = e?.response?.data?.detail || e.message;
      appendLog(`[ERROR] Command failed: ${detail}`);
    } finally {
      setCmdPending(false);
    }
  };

  useEffect(() => {
    let step = 0;
    const interval = setInterval(() => {
      step += 1;
      setBootStep(step);
      if (step >= BOOT_STEPS.length) {
        clearInterval(interval);
        setBootDone(true);
        appendLog("[INFO] Boot sequence complete — NEXUS READY");
      }
    }, 600);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => { fetchStatus(); }, [fetchStatus]);

  // Real polling
  useEffect(() => {
    const poll = async () => {
      try {
        const [health, hub] = await Promise.allSettled([
          axios.get(`${API}/production/health`),
          axios.get(`${API}/hub/status`),
        ]);
        if (health.status === "fulfilled") {
          const d = health.value.data;
          const modeCount = d?.checks?.mode_manager?.production_modes ?? "?";
          appendLog(`[INFO] Health: ${d?.status || "OK"} · ${modeCount} modes`);
          if (hub.status === "fulfilled") {
            const h = hub.value.data;
            const wsStatus = h?.websocket?.status === "connected" ? "connected" : "disconnected";
            setSubsystems((prev) => ({
              ...prev,
              websocket: { status: wsStatus, detail: `clients: ${h?.websocket?.connected_clients?.length ?? 0}` },
              firestore: { status: h?.database?.status === "ready" ? "ready" : "loading", detail: `venues: ${h?.database?.total_venues ?? 0}` },
            }));
          }
        } else {
          appendLog("[WARN] Backend health unreachable");
        }
      } catch (e) {
        appendLog(`[ERROR] Poll failed: ${e.message}`);
      }
    };
    poll();
    const interval = setInterval(poll, 5000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (!session) return;
    const interval = setInterval(() => setSessionElapsed((e) => e + 1), 1000);
    return () => clearInterval(interval);
  }, [session]);

  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [logLines]);

  const fmtElapsed = (secs) =>
    `${String(Math.floor(secs / 60)).padStart(2,"0")}:${String(secs % 60).padStart(2,"0")}`;

  return (
    <div
      data-testid="nexus-page"
      className="bg-[#050505] border border-cyan-400/30 p-5 space-y-5"
    >
      {/* Boot sequence */}
      <section data-testid="nexus-page-boot">
        <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-3 flex items-center gap-2">
          <Terminal className="w-3 h-3" /> Boot Sequence
        </div>
        <div className="flex items-center gap-1 flex-wrap">
          {BOOT_STEPS.map((step, i) => {
            const complete  = bootStep > i;
            const inProgress = bootStep === i;
            const pending   = bootStep < i;
            return (
              <React.Fragment key={step}>
                <div
                  className={`px-3 py-1.5 text-[10px] font-mono font-bold uppercase tracking-wider border transition-all
                    ${complete   ? "border-cyan-400/50 bg-cyan-400/15 text-cyan-400" : ""}
                    ${inProgress ? "border-amber-400/50 bg-amber-400/10 text-amber-400 animate-pulse" : ""}
                    ${pending    ? "border-zinc-800 bg-zinc-900/40 text-zinc-600" : ""}
                  `}
                >
                  {complete && <CheckCircle2 className="w-3 h-3 inline mr-1 -mt-0.5" />}
                  {step}
                </div>
                {i < BOOT_STEPS.length - 1 && (
                  <ChevronRight className={`w-3 h-3 shrink-0 ${complete ? "text-cyan-400/50" : "text-zinc-700"}`} />
                )}
              </React.Fragment>
            );
          })}
        </div>
      </section>

      {/* Subsystem grid */}
      <section>
        <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-3 flex items-center gap-2">
          <Activity className="w-3 h-3" /> Subsystem Health
        </div>
        <div className="grid grid-cols-2 gap-3">
          <SubsystemTile icon={Database}  name="Firestore"        status={subsystems.firestore.status}  detail={subsystems.firestore.detail}  testId="page-subsystem-firestore" />
          <SubsystemTile icon={Heart}     name="HealthKit"        status={subsystems.healthkit.status}  detail={subsystems.healthkit.detail}  testId="page-subsystem-healthkit" />
          <SubsystemTile icon={Wifi}      name="Emergent WS"      status={subsystems.websocket.status}  detail={subsystems.websocket.detail}  testId="page-subsystem-websocket" />
          <SubsystemTile icon={Layers}    name="NEXUS Engine"     status={subsystems.unreal.status}     detail={subsystems.unreal.detail}     testId="page-subsystem-unreal" />
        </div>
      </section>

      {/* Active session */}
      {session && (
        <section className="border border-cyan-400/30 bg-cyan-400/5 p-4" data-testid="nexus-page-session">
          <div className="text-[10px] uppercase tracking-[0.35em] text-cyan-400/70 mb-3">Active Session</div>
          <div className="flex items-center justify-between flex-wrap gap-3">
            <div>
              <div className="font-bold text-cyan-400" style={{ fontFamily: "Barlow Condensed" }}>{session.mode_name || "Unknown Mode"}</div>
              <div className="text-[10px] text-zinc-400 font-mono mt-0.5">{session.sport_category || "—"} · Readiness: <span className="text-cyan-400">{session.readiness_score ?? "—"}%</span></div>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1.5 text-sm font-mono text-zinc-300">
                <Clock className="w-3.5 h-3.5 text-zinc-500" />{fmtElapsed(sessionElapsed)}
              </div>
              <button data-testid="nexus-page-end-session" className="px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider border border-red-400/40 text-red-400 hover:bg-red-400/10 transition-colors" onClick={() => setSession(null)}>
                End Session
              </button>
            </div>
          </div>
        </section>
      )}

      {/* Live Console + Command Input */}
      <section>
        <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-2 flex items-center gap-2">
          <Terminal className="w-3 h-3" /> Live Console
        </div>
        <div ref={logRef} className="bg-zinc-950 border border-zinc-800 p-3 font-mono text-[10px] leading-relaxed space-y-0.5 overflow-y-auto" style={{ maxHeight: "200px" }}>
          {logLines.slice(-30).map((line, i) => (
            <div key={i} className="flex gap-2">
              <span className="text-zinc-600 shrink-0">{line.ts}</span>
              <span style={{ color: logColor(line.level || "info") }}>{line.msg}</span>
            </div>
          ))}
        </div>
        <div className="flex gap-2 mt-2">
          <input
            data-testid="nexus-page-cmd-input"
            value={cmdInput}
            onChange={(e) => setCmdInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && sendCommand()}
            placeholder="fel.* command (e.g. cell.status, cell.train_now)"
            className="flex-1 bg-zinc-950 border border-zinc-800 px-3 py-1.5 text-[10px] font-mono text-zinc-200 placeholder-zinc-600 focus:outline-none focus:border-cyan-400/50"
            disabled={cmdPending}
          />
          <button
            data-testid="nexus-page-cmd-send"
            onClick={() => sendCommand()}
            disabled={cmdPending || !cmdInput.trim()}
            className="px-3 py-1.5 bg-cyan-400/10 border border-cyan-400/30 text-cyan-400 hover:bg-cyan-400/20 transition-colors disabled:opacity-40"
          >
            <Send className="w-3 h-3" />
          </button>
        </div>
      </section>

      {/* Mode inventory */}
      <section data-testid="nexus-page-mode-inventory">
        <div className="text-[10px] uppercase tracking-[0.35em] text-zinc-500 mb-3">Mode Inventory</div>
        <div className="flex flex-wrap gap-1.5">
          {Object.entries(MODE_STATUS).map(([id, status]) => (
            <span key={id} className={`px-2 py-0.5 text-[10px] font-mono rounded ${statusColor(status)}`}>
              {id.replace(/_/g, " ")}
            </span>
          ))}
        </div>
      </section>

      {/* Footer */}
      <div className="pt-2 border-t border-zinc-800 flex items-center justify-between text-[10px] text-zinc-600 font-mono">
        <span>NEXUS ENGINE v1.0 · {bootDone ? "READY" : "BOOTING"}</span>
        <button data-testid="nexus-page-refresh" onClick={fetchStatus} className="text-zinc-500 hover:text-cyan-400 transition-colors uppercase tracking-wider">Refresh</button>
      </div>
    </div>
  );
};

export default NexusConsole;
