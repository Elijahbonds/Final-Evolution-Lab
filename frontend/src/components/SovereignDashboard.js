import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import {
  Wifi, WifiOff, Database, Shield, Zap, Radio, RefreshCw,
  Check, Clock, Activity, Server, Lock, Globe, Smartphone
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

export const SovereignDashboard = () => {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [health, setHealth] = useState(null);
  const [handshake, setHandshake] = useState(null);
  const pollRef = useRef(null);

  const fetchStatus = async () => {
    try {
      const [s, h, hs] = await Promise.all([
        axios.get(`${API}/sovereign/status`),
        axios.get(`${API}/production/health`),
        axios.get(`${API}/production/handshake-log`)
      ]);
      setStatus(s.data);
      setHealth(h.data);
      setHandshake(hs.data);
    } catch (e) { console.error(e); }
    setLoading(false);
  };

  useEffect(() => {
    fetchStatus();
    pollRef.current = setInterval(fetchStatus, 3000); // Poll every 3s
    return () => clearInterval(pollRef.current);
  }, []);

  if (loading || !status) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{background:'var(--bg-default)'}}>
        <div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  const wsConnected = status.websocket.status === 'connected';
  const dbReady = status.database.status === 'ready';

  return (
    <div className="space-y-6 fade-in">
      <div className="flex items-center justify-between">
        <div>
          <p className="overline mb-1">SOVEREIGN BACKEND · M4 PRO</p>
          <h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>LIVE CONNECTION</h1>
        </div>
        <button onClick={fetchStatus} className="btn-secondary flex items-center gap-2 text-sm">
          <RefreshCw className="w-4 h-4" /> Refresh
        </button>
      </div>

      {/* Primary Status Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* WebSocket Status */}
        <div className={`surface-card p-8 border-l-4 ${wsConnected ? 'border-l-green-400' : 'border-l-yellow-400'}`} data-testid="ws-status">
          <div className="flex items-center gap-4 mb-6">
            {wsConnected ? (
              <div className="w-14 h-14 bg-green-400/10 rounded-full flex items-center justify-center">
                <Wifi className="w-8 h-8 text-green-400" />
              </div>
            ) : (
              <div className="w-14 h-14 bg-yellow-400/10 rounded-full flex items-center justify-center relative">
                <Radio className="w-8 h-8 text-yellow-400 animate-pulse" />
              </div>
            )}
            <div>
              <h2 className="text-2xl font-bold" style={{fontFamily:'Barlow Condensed'}}>
                {wsConnected ? 'WEBSOCKET CONNECTED' : 'WAITING FOR CONNECTION'}
              </h2>
              <p className="text-sm text-zinc-400 font-mono mt-1">{status.websocket.url || 'No URL configured'}</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">CLIENTS</div>
              <div className="font-mono text-xl">{status.websocket.connected_clients?.length || 0}</div>
            </div>
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">KEEPALIVE</div>
              <div className="font-mono text-xl">{status.websocket.keepalive_active ? <span className="text-green-400">ACTIVE</span> : <span className="text-zinc-500">IDLE</span>}</div>
            </div>
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">FOCUS LOCK</div>
              <div className="font-mono text-xl">{status.websocket.focus_lock ? <span className="text-cyan-400">ON ({status.websocket.keepalive_interval_ms}ms)</span> : 'OFF'}</div>
            </div>
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">MESSAGES</div>
              <div className="font-mono text-xl">{status.websocket.total_messages}</div>
            </div>
          </div>
          {status.websocket.last_heartbeat && (
            <div className="mt-3 text-xs text-zinc-500 font-mono flex items-center gap-1">
              <Activity className="w-3 h-3" /> Last heartbeat: {new Date(status.websocket.last_heartbeat).toLocaleTimeString()}
            </div>
          )}
        </div>

        {/* Database Status */}
        <div className={`surface-card p-8 border-l-4 ${dbReady ? 'border-l-green-400' : 'border-l-red-400'}`} data-testid="db-status">
          <div className="flex items-center gap-4 mb-6">
            <div className={`w-14 h-14 ${dbReady ? 'bg-green-400/10' : 'bg-red-400/10'} rounded-full flex items-center justify-center`}>
              <Database className={`w-8 h-8 ${dbReady ? 'text-green-400' : 'text-red-400'}`} />
            </div>
            <div>
              <h2 className="text-2xl font-bold" style={{fontFamily:'Barlow Condensed'}}>
                {dbReady ? 'DATABASE READY' : 'DATABASE INITIALIZING'}
              </h2>
              <p className="text-sm text-zinc-400">MongoDB · {status.database.total_venues} venue collections</p>
            </div>
          </div>
          <div className="space-y-2 max-h-48 overflow-y-auto">
            {status.database.venues?.map((v, i) => (
              <div key={i} className="flex items-center gap-3 py-2 border-b border-white/5">
                <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                <span className="font-mono text-sm">{v}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Encryption Status */}
      <div className="surface-card p-6" data-testid="encryption-status">
        <div className="flex items-center gap-3 mb-4">
          <Lock className="w-6 h-6 text-cyan-400" />
          <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>ENCRYPTION · {status.encryption.algorithm}</h2>
        </div>
        <div className="grid grid-cols-3 gap-4">
          <div className="bg-black/30 p-4 border border-white/5">
            <div className="flex items-center gap-2 mb-2"><Shield className="w-4 h-4 text-green-400" /><span className="metric-label">IN TRANSIT</span></div>
            <div className="font-mono text-sm text-green-400">{status.encryption.transit}</div>
          </div>
          <div className="bg-black/30 p-4 border border-white/5">
            <div className="flex items-center gap-2 mb-2"><Database className="w-4 h-4 text-green-400" /><span className="metric-label">AT REST</span></div>
            <div className="font-mono text-sm text-green-400">{status.encryption.at_rest}</div>
          </div>
          <div className="bg-black/30 p-4 border border-white/5">
            <div className="flex items-center gap-2 mb-2"><Globe className="w-4 h-4 text-green-400" /><span className="metric-label">TUNNEL</span></div>
            <div className="font-mono text-sm text-green-400">{status.encryption.cloudflare_tunnel}</div>
          </div>
        </div>
      </div>

      {/* Monetization + Events */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4" data-testid="event-counters">
        <div className="surface-card p-5 text-center"><div className="metric-value text-2xl">{status.monetization.total_match_events}</div><div className="metric-label">MATCH EVENTS</div></div>
        <div className="surface-card p-5 text-center"><div className="metric-value text-2xl">{status.monetization.total_referral_events}</div><div className="metric-label">REFERRAL EVENTS</div></div>
        <div className="surface-card p-5 text-center"><div className="badge-clinical">{status.monetization.referral_system}</div><div className="metric-label mt-2">REFERRAL</div></div>
        <div className="surface-card p-5 text-center"><div className="badge-clinical">{status.monetization.match_score_to_referral}</div><div className="metric-label mt-2">SCORE→REWARD</div></div>
      </div>

      {/* INI Config */}
      <div className="surface-card p-6" data-testid="ini-config">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>DefaultGame.ini · [Emergent]</h2>
        <div className="bg-black/50 border border-white/5 p-4 font-mono text-sm space-y-1">
          {Object.entries(status.ini_config || {}).map(([k, v]) => (
            <div key={k}><span className="text-zinc-500">{k}=</span><span className="text-cyan-400">{v}</span></div>
          ))}
        </div>
      </div>

      {/* Server Info + Production Health */}
      {health && (
        <div className="surface-card p-6" data-testid="production-health">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>PRODUCTION HEALTH CHECK</h2>
            <span className={`badge-clinical ${health.status === 'PRODUCTION_READY' ? '' : 'bg-yellow-400/10 border-yellow-400/30 text-yellow-400'}`} style={health.status === 'PRODUCTION_READY' ? {background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'} : {}}>{health.status}</span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">MODES</div>
              <div className="font-mono">{health.checks?.mode_manager?.production_modes || 0} production / {health.checks?.mode_manager?.total_modes || 0} total</div>
            </div>
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">PRQ SOURCE</div>
              <div className="font-mono text-cyan-400">{health.checks?.prq_calculator?.static === false ? 'cpp_bridge (LIVE)' : 'STATIC'}</div>
            </div>
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">PLACEHOLDER</div>
              <div className="font-mono text-green-400">{health.placeholder_data === false ? 'NONE' : 'DETECTED'}</div>
            </div>
            <div className="bg-black/30 p-3 border border-white/5">
              <div className="metric-label">UPROJECT</div>
              <div className="font-mono text-xs">{health.checks?.websocket?.listening_for?.uproject || '-'}</div>
            </div>
          </div>
        </div>
      )}

      {/* Handshake Log */}
      {handshake && (
        <div className="surface-card p-6" data-testid="handshake-log">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>HANDSHAKE LOG</h2>
            <span className={`text-sm font-mono ${handshake.handshake_status === 'CONNECTED' ? 'text-green-400' : 'text-yellow-400 animate-pulse'}`}>{handshake.handshake_status}</span>
          </div>
          <div className="bg-black/50 border border-white/5 p-4 font-mono text-xs max-h-48 overflow-y-auto space-y-1">
            {handshake.log?.map((entry, i) => (
              <div key={i} className={`${entry.level === 'WAIT' ? 'text-yellow-400' : entry.level === 'ERROR' ? 'text-red-400' : 'text-zinc-400'}`}>
                <span className="text-zinc-600">[{new Date(entry.ts).toLocaleTimeString()}]</span> <span className={entry.level === 'WAIT' ? 'text-yellow-400' : 'text-zinc-500'}>[{entry.level}]</span> {entry.msg}
              </div>
            ))}
          </div>
          <div className="mt-3 flex items-center gap-4 text-xs text-zinc-500 font-mono">
            <span>Bridge: {handshake.bridge_identifier}</span>
            <span>UUID: {handshake.project_uuid}</span>
            <span>Messages: {handshake.total_messages_processed}</span>
          </div>
        </div>
      )}

      <div className="flex items-center justify-between text-xs text-zinc-600 font-mono">
        <span><Server className="w-3 h-3 inline mr-1" />FEL Sovereign Backend v{status.server.version}</span>
        <span><Clock className="w-3 h-3 inline mr-1" />Uptime: {Math.floor(status.server.uptime_seconds / 60)}m {status.server.uptime_seconds % 60}s</span>
        <span><Smartphone className="w-3 h-3 inline mr-1" />Tap app icon on iPhone to go live</span>
      </div>
    </div>
  );
};
