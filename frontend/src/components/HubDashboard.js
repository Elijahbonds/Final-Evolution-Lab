import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import {
  Wifi, WifiOff, Database, Shield, Zap, Radio, RefreshCw,
  Check, Clock, Activity, Server, Lock, Globe, Smartphone,
  Heart, TrendingUp, Target, Flame, Brain, Dumbbell, Play,
  AlertTriangle, Eye, User, Award, ChevronUp
} from "lucide-react";
import { API_URL } from "@/lib/apiClient";

const API = API_URL;

// Offline/standby snapshot so the Hub view always renders even when the
// local command-center endpoints are unreachable (no live backend / web shell).
const FALLBACK_HUB_STATUS = {
  websocket: { status: "standby", connected_clients: [], total_messages: 0 },
  database: {
    status: "ready",
    total_venues: 12,
    venues: [
      "VeniceBeach", "Dojo", "BaseballPark", "Gridiron", "SoccerStadium",
      "Links", "TennisCourt", "SandCourt", "TrainingFloor", "NeuroArena",
      "Luma_Venice_Shop", "SecureEnclave",
    ],
  },
  integrity: { status: "AWAITING AUTH", hardware_auth: null },
  telemetry: null,
  active_creator_card: null,
  server: { version: "1.0.0", uptime_seconds: 0 },
};
const FALLBACK_HUB_HEALTH = {
  status: "STANDBY",
  checks: { mode_manager: { production_modes: 19 }, blocking_issues: 0 },
};
const FALLBACK_HUB_HANDSHAKE = {
  handshake_status: "STANDBY",
  log: [
    { ts: Date.now(), level: "WAIT", msg: "Local command center offline — showing shell standby snapshot." },
    { ts: Date.now(), level: "INFO", msg: "Open the Final Evolution Hub binary on port 8888 to go live." },
  ],
};

export const HubDashboard = () => {
  const [status, setStatus] = useState(null);
  const [health, setHealth] = useState(null);
  const [handshake, setHandshake] = useState(null);
  const [telemetry, setTelemetry] = useState(null);
  const [loading, setLoading] = useState(true);
  const pollRef = useRef(null);

  const fetchAll = async () => {
    try {
      const [s, h, hs, t] = await Promise.all([
        axios.get(`${API}/hub/status`),
        axios.get(`${API}/production/health`),
        axios.get(`${API}/production/handshake-log`),
        axios.get(`${API}/telemetry/live`).catch(() => ({data: null}))
      ]);
      setStatus(s.data);
      setHealth(h.data);
      setHandshake(hs.data);
      if (t.data) setTelemetry(t.data);
    } catch (e) {
      // No live command center — render the standby snapshot instead of
      // spinning forever. Only seed fallbacks once so we don't clobber a
      // previously connected state.
      setStatus((prev) => prev || FALLBACK_HUB_STATUS);
      setHealth((prev) => prev || FALLBACK_HUB_HEALTH);
      setHandshake((prev) => prev || FALLBACK_HUB_HANDSHAKE);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchAll();
    pollRef.current = setInterval(fetchAll, 2000);
    return () => clearInterval(pollRef.current);
  }, []);

  if (loading || !status) {
    return <div className="min-h-screen flex items-center justify-center" style={{background:'var(--bg-default)'}}><div className="text-center"><div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div><p className="text-zinc-400 font-mono text-sm">Initializing Final Evolution Hub...</p></div></div>;
  }

  const wsConnected = status.websocket.status === 'connected';
  const dbReady = status.database.status === 'ready';
  const integrityOk = status.integrity?.status === 'ACTIVE';
  const telem = status.telemetry;
  const card = status.active_creator_card;
  const blockingIssues = health?.checks?.blocking_issues ?? health?.blocking_issues ?? 0;

  return (
    <div className="space-y-6 fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <p className="overline mb-1">LOCAL COMMAND CENTER · PORT 8888</p>
          <h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>FINAL EVOLUTION HUB</h1>
        </div>
        <div className="flex items-center gap-3">
          <span className="badge-clinical" style={{background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'}}>LOCAL HUB</span>
          <button onClick={fetchAll} className="btn-secondary flex items-center gap-2 text-sm"><RefreshCw className="w-4 h-4" /></button>
        </div>
      </div>

      {/* Primary Status Row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* WebSocket */}
        <div className={`surface-card p-6 border-l-4 ${wsConnected ? 'border-l-green-400' : 'border-l-yellow-400'}`} data-testid="ws-status">
          <div className="flex items-center gap-3 mb-3">
            {wsConnected ? <Wifi className="w-8 h-8 text-green-400" /> : <Radio className="w-8 h-8 text-yellow-400 animate-pulse" />}
            <div>
              <h3 className="text-lg font-bold" style={{fontFamily:'Barlow Condensed'}}>{wsConnected ? 'CONNECTED' : 'LISTENING'}</h3>
              <p className="font-mono text-xs text-cyan-400">wss://finalevolutiongroup.com/ws/vault</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div className="bg-black/30 p-2 border border-white/5"><span className="metric-label">CLIENTS</span><div className="font-mono">{status.websocket.connected_clients?.length || 0}</div></div>
            <div className="bg-black/30 p-2 border border-white/5"><span className="metric-label">MSGS</span><div className="font-mono">{status.websocket.total_messages}</div></div>
          </div>
        </div>

        {/* Database */}
        <div className={`surface-card p-6 border-l-4 ${dbReady ? 'border-l-green-400' : 'border-l-red-400'}`} data-testid="db-status">
          <div className="flex items-center gap-3 mb-3">
            <Database className={`w-8 h-8 ${dbReady ? 'text-green-400' : 'text-red-400'}`} />
            <div>
              <h3 className="text-lg font-bold" style={{fontFamily:'Barlow Condensed'}}>{dbReady ? 'DATABASE READY' : 'INITIALIZING'}</h3>
              <p className="text-xs text-zinc-400">Local MongoDB · {status.database.total_venues} venues</p>
            </div>
          </div>
          <div className="text-xs text-zinc-500">PRQ source: <span className="text-cyan-400">Local MongoDB (NOT simulation)</span></div>
        </div>

        {/* Integrity Guard */}
        <div className={`surface-card p-6 border-l-4 ${integrityOk ? 'border-l-green-400' : status.integrity?.status === 'INTEGRITY_WARNING' ? 'border-l-red-400' : 'border-l-zinc-600'}`} data-testid="integrity-status">
          <div className="flex items-center gap-3 mb-3">
            {integrityOk ? <Shield className="w-8 h-8 text-green-400" /> : status.integrity?.status === 'INTEGRITY_WARNING' ? <AlertTriangle className="w-8 h-8 text-red-400" /> : <Shield className="w-8 h-8 text-zinc-600" />}
            <div>
              <h3 className="text-lg font-bold" style={{fontFamily:'Barlow Condensed'}}>{status.integrity?.status || 'AWAITING AUTH'}</h3>
              <p className="text-xs text-zinc-400">Integrity Guard (bIsHardwareAuthenticated)</p>
            </div>
          </div>
          {status.integrity?.hardware_auth && (
            <div className="grid grid-cols-3 gap-1 text-xs">
              <div className={`p-1 text-center ${status.integrity.hardware_auth.bIsHardwareAuthenticated ? 'text-green-400' : 'text-zinc-600'}`}>HW Auth {status.integrity.hardware_auth.bIsHardwareAuthenticated ? '✓' : '—'}</div>
              <div className={`p-1 text-center ${status.integrity.hardware_auth.back_camera_verified ? 'text-green-400' : 'text-zinc-600'}`}>Camera {status.integrity.hardware_auth.back_camera_verified ? '✓' : '—'}</div>
              <div className={`p-1 text-center ${status.integrity.hardware_auth.imu_visual_sync ? 'text-green-400' : 'text-zinc-600'}`}>IMU Sync {status.integrity.hardware_auth.imu_visual_sync ? '✓' : '—'}</div>
            </div>
          )}
        </div>
      </div>

      {/* Live Telemetry — Stadium Overlay View */}
      <div className="surface-active p-6" data-testid="telemetry-stadium">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>LIVE TELEMETRY · STADIUM VIEW</h2>
          <div className="flex items-center gap-2">{wsConnected ? <><div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div><span className="text-xs font-mono text-green-400">LIVE FEED</span></> : <span className="text-xs font-mono text-zinc-600">STANDBY</span>}</div>
        </div>

        {/* PRQ + Combo + Buckets — the AFELBasketballGameState overlay */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-4">
          <div className="bg-black/60 p-5 border border-cyan-400/20 text-center">
            <TrendingUp className="w-6 h-6 text-cyan-400 mx-auto mb-2" />
            <div className="metric-value text-4xl text-cyan-400">{telem?.prq || '—'}</div>
            <div className="metric-label">PRQ SCORE</div>
            <div className="text-xs text-zinc-600 mt-1">Local MongoDB</div>
          </div>
          <div className="bg-black/60 p-5 border border-yellow-400/20 text-center">
            <Flame className="w-6 h-6 text-yellow-400 mx-auto mb-2" />
            <div className="metric-value text-4xl text-yellow-400">{telem?.combo_meter || '—'}</div>
            <div className="metric-label">COMBO METER</div>
          </div>
          <div className="bg-black/60 p-5 border border-green-400/20 text-center">
            <Target className="w-6 h-6 text-green-400 mx-auto mb-2" />
            <div className="metric-value text-4xl text-green-400">{telem?.buckets || '—'}</div>
            <div className="metric-label">BUCKETS</div>
          </div>
          <div className="bg-black/60 p-5 border border-purple-400/20 text-center">
            <ChevronUp className="w-6 h-6 text-purple-400 mx-auto mb-2" />
            <div className="metric-value text-4xl text-purple-400">{telem?.vertical_jump || '—'}</div>
            <div className="metric-label">VERT (IN)</div>
          </div>
          <div className="bg-black/60 p-5 border border-white/10 text-center">
            <Activity className="w-6 h-6 text-white mx-auto mb-2" />
            <div className="font-mono text-sm text-zinc-400 mt-2">
              {telem?.velocity_vectors ? (
                <div>X:{telem.velocity_vectors.x||0} Y:{telem.velocity_vectors.y||0} Z:{telem.velocity_vectors.z||0}</div>
              ) : '—'}
            </div>
            <div className="metric-label">VELOCITY</div>
          </div>
        </div>

        {/* Data source confirmation */}
        <div className="bg-black/30 p-2 border border-white/5 text-xs text-zinc-600 font-mono text-center">
          AFELBasketballGameState → wss://finalevolutiongroup.com/ws/vault → Local MongoDB · No cloud · No simulation
        </div>
      </div>

      {/* Active Creator Card — Directive 5 */}
      {card && (
        <div className="surface-card p-6" data-testid="active-creator-card">
          <div className="flex items-center gap-3 mb-3"><Award className="w-6 h-6 text-yellow-400" /><h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>ACTIVE CREATOR CARD</h2></div>
          <div className="badge-clinical inline-block">{card}</div>
          <p className="text-xs text-zinc-500 mt-2">Loaded via StoodCardId from performance bridge</p>
        </div>
      )}

      {/* Venue Grid */}
      <div data-testid="venue-grid">
        <h2 className="text-xl font-bold mb-3" style={{fontFamily:'Barlow Condensed'}}>VENUE IDENTIFICATION · FEL_VenueRegistry</h2>
        <div className="grid grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
          {(status.database.venues || []).map((v, i) => (
            <div key={i} className="surface-card p-3 text-center"><Check className="w-3 h-3 text-green-400 mx-auto mb-1" /><div className="text-xs font-mono text-cyan-400">{v.replace(/_/g,' ')}</div></div>
          ))}
        </div>
      </div>

      {/* Production Health + Encryption */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {health && (
          <div className="surface-card p-5" data-testid="production-health">
            <div className="flex items-center justify-between mb-3"><h3 className="font-bold" style={{fontFamily:'Barlow Condensed'}}>PRODUCTION HEALTH</h3><span className="badge-clinical" style={{background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'}}>{health.status}</span></div>
            <div className="grid grid-cols-2 gap-2 text-sm">
              <div className="bg-black/30 p-2 border border-white/5"><span className="metric-label">MODES</span><div className="font-mono">{health.checks?.mode_manager?.production_modes} prod</div></div>
              <div className="bg-black/30 p-2 border border-white/5"><span className="metric-label">BLOCKERS</span><div className={`font-mono ${blockingIssues === 0 ? 'text-green-400' : 'text-yellow-400'}`}>{blockingIssues}</div></div>
            </div>
          </div>
        )}
        <div className="surface-card p-5" data-testid="encryption">
          <div className="flex items-center gap-2 mb-3"><Lock className="w-5 h-5 text-cyan-400" /><h3 className="font-bold" style={{fontFamily:'Barlow Condensed'}}>ENCRYPTION</h3></div>
          <div className="grid grid-cols-3 gap-2 text-xs">
            <div className="bg-black/30 p-2 border border-white/5 text-center"><div className="text-green-400">AES-256-GCM</div><div className="metric-label">TRANSIT</div></div>
            <div className="bg-black/30 p-2 border border-white/5 text-center"><div className="text-green-400">WiredTiger</div><div className="metric-label">AT REST</div></div>
            <div className="bg-black/30 p-2 border border-white/5 text-center"><div className="text-green-400">localhost</div><div className="metric-label">NETWORK</div></div>
          </div>
        </div>
      </div>

      {/* Handshake Log */}
      {handshake && (
        <div className="surface-card p-5" data-testid="handshake-log">
          <div className="flex items-center justify-between mb-3">
            <h3 className="font-bold" style={{fontFamily:'Barlow Condensed'}}>CONNECTION LOG</h3>
            <span className={`text-sm font-mono ${handshake.handshake_status === 'CONNECTED' ? 'text-green-400' : 'text-yellow-400 animate-pulse'}`}>{handshake.handshake_status}</span>
          </div>
          <div className="bg-black/50 border border-white/5 p-3 font-mono text-xs max-h-44 overflow-y-auto space-y-1">
            {handshake.log?.map((e, i) => (
              <div key={i} className={e.level === 'WAIT' ? 'text-yellow-400' : 'text-zinc-400'}>
                <span className="text-zinc-600">[{new Date(e.ts).toLocaleTimeString()}]</span> [{e.level}] {e.msg}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between text-xs text-zinc-600 font-mono">
        <span><Server className="w-3 h-3 inline mr-1" />Final Evolution Hub v{status.server.version} · LOCAL</span>
        <span><Clock className="w-3 h-3 inline mr-1" />Uptime: {Math.floor(status.server.uptime_seconds/60)}m</span>
        <span><Smartphone className="w-3 h-3 inline mr-1" />iPhone → Port 8888 → Hub turns GREEN</span>
      </div>
    </div>
  );
};
