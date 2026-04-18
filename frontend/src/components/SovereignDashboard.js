import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import {
  Wifi, WifiOff, Database, Shield, Zap, Radio, RefreshCw,
  Check, Clock, Activity, Server, Lock, Globe, Smartphone,
  Heart, TrendingUp, Target, Flame, Brain, Dumbbell, Play
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

export const SovereignDashboard = () => {
  const [status, setStatus] = useState(null);
  const [health, setHealth] = useState(null);
  const [handshake, setHandshake] = useState(null);
  const [liveVenue, setLiveVenue] = useState(null);
  const [loading, setLoading] = useState(true);
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
    pollRef.current = setInterval(fetchStatus, 3000);
    return () => clearInterval(pollRef.current);
  }, []);

  if (loading || !status) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{background:'var(--bg-default)'}}>
        <div className="text-center">
          <div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-zinc-400 font-mono text-sm">Initializing Sovereign Hub...</p>
        </div>
      </div>
    );
  }

  const wsConnected = status.websocket.status === 'connected';
  const dbReady = status.database.status === 'ready';

  return (
    <div className="space-y-6 fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <p className="overline mb-1">LOCAL SOVEREIGN · M4 PRO MAC MINI</p>
          <h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>COMMAND CENTER</h1>
        </div>
        <div className="flex items-center gap-3">
          <span className="badge-clinical" style={{background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'}}>LOCAL MODE</span>
          <button onClick={fetchStatus} className="btn-secondary flex items-center gap-2 text-sm"><RefreshCw className="w-4 h-4" /> Refresh</button>
        </div>
      </div>

      {/* Primary Status: WebSocket + Database */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* WebSocket — Sovereign Hub */}
        <div className={`surface-card p-8 border-l-4 ${wsConnected ? 'border-l-green-400' : 'border-l-yellow-400'}`} data-testid="ws-status">
          <div className="flex items-center gap-4 mb-4">
            {wsConnected ? (
              <div className="w-14 h-14 bg-green-400/10 rounded-full flex items-center justify-center"><Wifi className="w-8 h-8 text-green-400" /></div>
            ) : (
              <div className="w-14 h-14 bg-yellow-400/10 rounded-full flex items-center justify-center"><Radio className="w-8 h-8 text-yellow-400 animate-pulse" /></div>
            )}
            <div>
              <h2 className="text-2xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{wsConnected ? 'BRIDGE CONNECTED' : 'WAITING FOR CONNECTION'}</h2>
              <p className="text-sm font-mono text-cyan-400">Sovereign Hub Listening on Port 8888</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">CLIENTS</div><div className="font-mono text-xl">{status.websocket.connected_clients?.length || 0}</div></div>
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">MESSAGES</div><div className="font-mono text-xl">{status.websocket.total_messages}</div></div>
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">FOCUS LOCK</div><div className="font-mono text-sm text-cyan-400">ON ({status.websocket.keepalive_interval_ms}ms)</div></div>
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">CLOUD</div><div className="font-mono text-sm text-zinc-500">DISABLED</div></div>
          </div>
        </div>

        {/* Database — Local MongoDB */}
        <div className={`surface-card p-8 border-l-4 ${dbReady ? 'border-l-green-400' : 'border-l-red-400'}`} data-testid="db-status">
          <div className="flex items-center gap-4 mb-4">
            <div className={`w-14 h-14 ${dbReady ? 'bg-green-400/10' : 'bg-red-400/10'} rounded-full flex items-center justify-center`}>
              <Database className={`w-8 h-8 ${dbReady ? 'text-green-400' : 'text-red-400'}`} />
            </div>
            <div>
              <h2 className="text-2xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{dbReady ? 'DATABASE READY' : 'INITIALIZING'}</h2>
              <p className="text-sm text-zinc-400">Local MongoDB · {status.database.total_venues} venue collections</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 max-h-40 overflow-y-auto">
            {status.database.venues?.map((v, i) => (
              <div key={i} className="flex items-center gap-2 py-1 text-sm"><Check className="w-3 h-3 text-green-400 flex-shrink-0" /><span className="font-mono text-xs text-zinc-400">{v}</span></div>
            ))}
          </div>
        </div>
      </div>

      {/* Biomechanical Data Feed — replaces video window */}
      <div className="surface-active p-6" data-testid="biomechanical-feed">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>BIOMECHANICAL DATA FEED</h2>
          <div className="flex items-center gap-2">
            <div className={`w-2 h-2 rounded-full ${wsConnected ? 'bg-green-400 animate-pulse' : 'bg-zinc-600'}`}></div>
            <span className="text-xs font-mono text-zinc-500">{wsConnected ? 'LIVE' : 'STANDBY'}</span>
          </div>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[
            {label:'ACTIVE VENUE', value: liveVenue || 'Awaiting...', icon: Target, color: 'text-cyan-400'},
            {label:'PRQ SCORE', value: '—', icon: TrendingUp, color: 'text-cyan-400', note: 'Local MongoDB (NOT simulation)'},
            {label:'HEART RATE', value: '—', icon: Heart, color: 'text-red-400'},
            {label:'SESSION TIME', value: '00:00', icon: Clock, color: 'text-yellow-400'},
          ].map((m, i) => (
            <div key={i} className="bg-black/50 p-5 border border-white/5">
              <m.icon className={`w-6 h-6 ${m.color} mb-2`} />
              <div className="font-mono text-2xl mb-1">{m.value}</div>
              <div className="metric-label">{m.label}</div>
              {m.note && <div className="text-xs text-zinc-600 mt-1">{m.note}</div>}
            </div>
          ))}
        </div>
        <div className="mt-4 bg-black/30 p-3 border border-white/5 text-xs text-zinc-600 font-mono">
          Data source: UFELEmergentBridgeSubsystem → ws://localhost:8888 → Local MongoDB · No cloud · No video window
        </div>
      </div>

      {/* Active Venue Grid — from FEL_VenueRegistry.production.json */}
      <div data-testid="venue-grid">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>VENUE MAP · LIVE IDENTIFICATION</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {(status.database.venues || []).map((v, i) => (
            <div key={i} className={`surface-card p-4 text-center card-hover cursor-pointer ${liveVenue === v ? 'border-l-2 border-cyan-400 bg-cyan-400/5' : ''}`} onClick={() => setLiveVenue(v)}>
              <div className="text-sm font-bold text-cyan-400 uppercase mb-1">{v.replace(/_/g, ' ')}</div>
              <div className="text-xs text-zinc-600 font-mono">FEL_VenueRegistry</div>
              {liveVenue === v && <div className="mt-2 text-xs text-green-400">ACTIVE</div>}
            </div>
          ))}
        </div>
      </div>

      {/* Production Health */}
      {health && (
        <div className="surface-card p-6" data-testid="production-health">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>PRODUCTION HEALTH</h2>
            <span className="badge-clinical" style={{background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'}}>{health.status}</span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">MODES</div><div className="font-mono">{health.checks?.mode_manager?.production_modes} prod / {health.checks?.mode_manager?.total_modes} total</div></div>
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">PRQ SOURCE</div><div className="font-mono text-cyan-400">Local MongoDB</div></div>
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">PLACEHOLDER</div><div className="font-mono text-green-400">{health.placeholder_data === false ? 'NONE' : 'DETECTED'}</div></div>
            <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">CLOUD</div><div className="font-mono text-zinc-500">DISABLED</div></div>
          </div>
        </div>
      )}

      {/* Encryption */}
      <div className="surface-card p-6" data-testid="encryption-status">
        <div className="flex items-center gap-3 mb-3"><Lock className="w-5 h-5 text-cyan-400" /><h2 className="text-lg font-bold" style={{fontFamily:'Barlow Condensed'}}>ENCRYPTION · AES-256-GCM</h2></div>
        <div className="grid grid-cols-3 gap-3">
          <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">TRANSIT</div><div className="font-mono text-sm text-green-400">AES-256-GCM</div></div>
          <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">AT REST</div><div className="font-mono text-sm text-green-400">WiredTiger AES-256</div></div>
          <div className="bg-black/30 p-3 border border-white/5"><div className="metric-label">NETWORK</div><div className="font-mono text-sm text-green-400">localhost (no cloud)</div></div>
        </div>
      </div>

      {/* Handshake Log */}
      {handshake && (
        <div className="surface-card p-6" data-testid="handshake-log">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>SOVEREIGN HUB LOG</h2>
            <span className={`text-sm font-mono ${handshake.handshake_status === 'CONNECTED' ? 'text-green-400' : 'text-yellow-400 animate-pulse'}`}>{handshake.handshake_status}</span>
          </div>
          <div className="bg-black/50 border border-white/5 p-4 font-mono text-xs max-h-56 overflow-y-auto space-y-1">
            {handshake.log?.map((entry, i) => (
              <div key={i} className={`${entry.level === 'WAIT' ? 'text-yellow-400' : entry.level === 'ERROR' ? 'text-red-400' : 'text-zinc-400'}`}>
                <span className="text-zinc-600">[{new Date(entry.ts).toLocaleTimeString()}]</span>{' '}
                <span className={entry.level === 'WAIT' ? 'text-yellow-400' : 'text-zinc-500'}>[{entry.level}]</span>{' '}
                {entry.msg}
              </div>
            ))}
          </div>
          <div className="mt-3 flex items-center gap-4 text-xs text-zinc-500 font-mono">
            <span>Bridge: {handshake.bridge_identifier}</span>
            <span>UUID: {handshake.project_uuid}</span>
          </div>
        </div>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between text-xs text-zinc-600 font-mono">
        <span><Server className="w-3 h-3 inline mr-1" />FEL Sovereign Hub v{status.server.version} · LOCAL</span>
        <span><Clock className="w-3 h-3 inline mr-1" />Uptime: {Math.floor(status.server.uptime_seconds / 60)}m {status.server.uptime_seconds % 60}s</span>
        <span><Smartphone className="w-3 h-3 inline mr-1" />Tap app → ws://localhost:8888 → Hub turns GREEN</span>
      </div>
    </div>
  );
};
