import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import {
  Wifi, Users, Gamepad2, Star, Crown, User, Copy, Check,
  Gift, Zap, Clock, BarChart3, Play, Pause, Eye, Radio,
  ArrowRight, Share2, DollarSign, Shield, Database, RefreshCw
} from "lucide-react";
import { API } from "@/config/api";

// ===================== MULTIPLAYER LOBBY =====================
export const MultiplayerView = () => {
  const [rooms, setRooms] = useState([]);
  const [creating, setCreating] = useState(false);
  const [gameMode, setGameMode] = useState('basketball_h2h');
  const [ws, setWs] = useState(null);
  const [activeRoom, setActiveRoom] = useState(null);
  const [players, setPlayers] = useState([]);
  const [myScore, setMyScore] = useState(0);
  const [opponentScore, setOpponentScore] = useState(0);
  const [gameActive, setGameActive] = useState(false);

  useEffect(() => { fetchRooms(); }, []);

  const fetchRooms = () => { axios.get(`${API}/multiplayer/rooms`).then(r => setRooms(r.data)).catch(console.error); };

  const createRoom = async () => {
    setCreating(true);
    try {
      const r = await axios.post(`${API}/multiplayer/create-room`, { game_mode: gameMode, max_players: 2, allow_spectators: true });
      setActiveRoom(r.data);
      connectWS(r.data.id);
    } catch (e) { console.error(e); }
    setCreating(false);
  };

  const joinRoom = async (roomId) => {
    try {
      await axios.post(`${API}/multiplayer/rooms/${roomId}/join`);
      setActiveRoom({ id: roomId });
      connectWS(roomId);
    } catch (e) { console.error(e); }
  };

  const spectateRoom = async (roomId) => {
    try {
      await axios.post(`${API}/multiplayer/rooms/${roomId}/spectate`);
      setActiveRoom({ id: roomId, spectating: true });
      connectWS(roomId);
    } catch (e) { console.error(e); }
  };

  const connectWS = (roomId) => {
    const wsUrl = `${BACKEND_URL.replace('https', 'wss').replace('http', 'ws')}/ws/game/${roomId}`;
    const socket = new WebSocket(wsUrl);
    socket.onmessage = (e) => {
      const data = JSON.parse(e.data);
      if (data.type === 'player_joined') setPlayers(p => [...p, data.user_id]);
      if (data.type === 'score_update') {
        if (data.user_id !== 'me') setOpponentScore(data.score);
      }
      if (data.type === 'ready_status' && data.all_ready) setGameActive(true);
    };
    setWs(socket);
  };

  const sendReady = () => { if (ws) ws.send(JSON.stringify({ type: 'ready' })); };
  const sendScore = (score) => { if (ws) ws.send(JSON.stringify({ type: 'score_update', score })); };

  if (activeRoom) {
    return (
      <div className="space-y-6 fade-in" data-testid="multiplayer-active">
        <div className="flex items-center justify-between">
          <div><p className="overline mb-1">LIVE MATCH</p><h1 className="text-3xl font-black" style={{fontFamily:'Barlow Condensed'}}>ROOM: {activeRoom.id?.slice(0,12)}</h1></div>
          <button onClick={() => {setActiveRoom(null);ws?.close();}} className="btn-secondary text-sm">Leave</button>
        </div>
        <div className="grid grid-cols-3 gap-6">
          <div className="surface-card p-6 text-center"><div className="metric-value text-4xl text-cyan-400">{myScore}</div><div className="metric-label">YOUR SCORE</div></div>
          <div className="surface-card p-6 text-center flex items-center justify-center"><div className="text-3xl font-bold text-zinc-600" style={{fontFamily:'Barlow Condensed'}}>VS</div></div>
          <div className="surface-card p-6 text-center"><div className="metric-value text-4xl text-red-400">{opponentScore}</div><div className="metric-label">OPPONENT</div></div>
        </div>
        <div className="surface-card p-6">
          <div className="flex items-center gap-4 mb-4">{players.map((p,i) => <span key={i} className="badge-clinical">{p}</span>)}</div>
          {!gameActive ? (
            <button data-testid="ready-btn" onClick={sendReady} className="btn-primary w-full text-lg py-4">READY UP</button>
          ) : (
            <div className="text-center text-green-400 text-lg font-bold">MATCH IN PROGRESS</div>
          )}
        </div>
        <div className="flex items-center gap-2 text-sm text-zinc-500"><div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>WebSocket connected · Low-latency mode</div>
      </div>
    );
  }

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">REAL-TIME PVP</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>MULTIPLAYER</h1></div>
      
      <div className="surface-card p-6" data-testid="create-room">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>CREATE MATCH</h2>
        <div className="flex gap-3">
          <select data-testid="mode-select" value={gameMode} onChange={e => setGameMode(e.target.value)} className="input-clinical flex-1">
            {['basketball_h2h','basketball_3v3','karate_h2h','soccer','tennis','football'].map(m => <option key={m} value={m}>{m.replace(/_/g,' ')}</option>)}
          </select>
          <button data-testid="create-room-btn" onClick={createRoom} disabled={creating} className="btn-primary px-8">{creating ? 'Creating...' : 'Create Room'}</button>
        </div>
      </div>

      <div data-testid="room-list">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>OPEN ROOMS</h2>
        <div className="space-y-3">
          {rooms.map((r, i) => (
            <div key={i} className="surface-card p-4 flex items-center justify-between card-hover">
              <div className="flex items-center gap-4">
                <Gamepad2 className="w-8 h-8 text-cyan-400" />
                <div><h3 className="font-bold">{r.host_name}'s Room</h3><p className="text-sm text-zinc-400">{r.game_mode.replace(/_/g,' ')} · {r.players?.length || 0}/{r.max_players} players</p></div>
              </div>
              <div className="flex gap-2">
                {r.settings?.allow_spectators && <button data-testid={`spectate-${r.id}`} onClick={() => spectateRoom(r.id)} className="btn-secondary text-sm py-2 px-4"><Eye className="w-4 h-4 inline mr-1" />Watch</button>}
                <button data-testid={`join-${r.id}`} onClick={() => joinRoom(r.id)} className="btn-primary text-sm py-2 px-4"><Play className="w-4 h-4 inline mr-1" />Join</button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ===================== REFERRAL SYSTEM =====================
export const ReferralView = () => {
  const [stats, setStats] = useState(null);
  const [code, setCode] = useState('');
  const [redeemCode, setRedeemCode] = useState('');
  const [copied, setCopied] = useState(false);
  const [redeemResult, setRedeemResult] = useState(null);

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    try {
      const s = await axios.get(`${API}/referral/stats`);
      setStats(s.data);
      if (!s.data.code) {
        const g = await axios.post(`${API}/referral/generate`);
        setCode(g.data.code);
      } else {
        setCode(s.data.code);
      }
    } catch { }
  };

  const copyCode = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const redeem = async () => {
    try {
      const r = await axios.post(`${API}/referral/redeem`, { code: redeemCode });
      setRedeemResult(r.data);
      setRedeemCode('');
    } catch (e) {
      setRedeemResult({ error: e.response?.data?.detail || 'Invalid code' });
    }
  };

  const requestPayout = async () => {
    try { await axios.post(`${API}/referral/payout`); loadData(); } catch (e) { console.error(e); }
  };

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">GROW THE LAB</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>REFERRAL REWARDS</h1></div>

      {/* Your Code */}
      <div className="surface-active p-8" data-testid="referral-code">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>YOUR REFERRAL CODE</h2>
        <div className="flex items-center gap-4 mb-4">
          <div className="flex-1 bg-black/50 border border-cyan-400/30 p-4 font-mono text-2xl text-cyan-400 text-center tracking-wider">{code || '...'}</div>
          <button data-testid="copy-code" onClick={copyCode} className="btn-primary px-6 py-4">
            {copied ? <Check className="w-6 h-6" /> : <Copy className="w-6 h-6" />}
          </button>
        </div>
        <p className="text-sm text-zinc-400">Share this code — earn <span className="text-cyan-400">200 coins + 100 XP</span> per referral. They get <span className="text-green-400">100 coins + 50 XP</span>.</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4" data-testid="referral-stats">
        <div className="surface-card p-6 text-center"><div className="metric-value text-3xl">{stats?.total_referrals || 0}</div><div className="metric-label">REFERRALS</div></div>
        <div className="surface-card p-6 text-center"><div className="metric-value text-3xl text-cyan-400">{stats?.total_coins_earned || 0}</div><div className="metric-label">COINS EARNED</div></div>
        <div className="surface-card p-6 text-center">
          <div className="metric-value text-3xl text-yellow-400">{stats?.pending_payout || 0}</div><div className="metric-label">PENDING PAYOUT</div>
          {(stats?.pending_payout || 0) >= 500 && <button data-testid="payout-btn" onClick={requestPayout} className="btn-primary text-sm mt-3 w-full"><DollarSign className="w-4 h-4 inline mr-1" />PayPal Payout</button>}
        </div>
      </div>

      {/* Redeem */}
      <div className="surface-card p-6" data-testid="redeem-section">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>REDEEM A CODE</h2>
        <div className="flex gap-3">
          <input data-testid="redeem-input" value={redeemCode} onChange={e => setRedeemCode(e.target.value.toUpperCase())} placeholder="FEL-XXXX-XXXXXX" className="input-clinical flex-1" />
          <button data-testid="redeem-btn" onClick={redeem} className="btn-primary">Redeem</button>
        </div>
        {redeemResult && (
          <div className={`mt-4 p-4 border ${redeemResult.error ? 'border-red-400/30 bg-red-400/5 text-red-400' : 'border-green-400/30 bg-green-400/5 text-green-400'}`}>
            {redeemResult.error || `${redeemResult.message} +${redeemResult.coins_earned} coins, +${redeemResult.xp_earned} XP`}
          </div>
        )}
      </div>
    </div>
  );
};

// ===================== ANALYTICS DASHBOARD =====================
export const AnalyticsView = () => {
  const [data, setData] = useState(null);
  const [policy, setPolicy] = useState(null);
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    Promise.all([axios.get(`${API}/analytics/dashboard`), axios.get(`${API}/analytics/policy`)])
      .then(([d, p]) => { setData(d.data); setPolicy(p.data); }).catch(console.error);
  }, []);

  const triggerSync = async () => {
    setSyncing(true);
    try { await axios.post(`${API}/analytics/sovereign-sync`); const d = await axios.get(`${API}/analytics/dashboard`); setData(d.data); } catch {}
    setSyncing(false);
  };

  return (
    <div className="space-y-8 fade-in">
      <div className="flex items-center justify-between">
        <div><p className="overline mb-1">PERFORMANCE DATA</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>ANALYTICS</h1></div>
        <button data-testid="sovereign-sync" onClick={triggerSync} disabled={syncing} className="btn-secondary flex items-center gap-2">
          <RefreshCw className={`w-4 h-4 ${syncing ? 'animate-spin' : ''}`} />{syncing ? 'Syncing...' : 'Sovereign Sync'}
        </button>
      </div>

      {/* Sync Status */}
      <div className="surface-active p-4 flex items-center justify-between" data-testid="sync-status">
        <div className="flex items-center gap-3">
          <Shield className="w-6 h-6 text-cyan-400" />
          <div>
            <div className="font-bold text-sm">SOVEREIGN SYNC</div>
            <div className="text-xs text-zinc-400">{data?.sovereign_sync?.sync_target}</div>
          </div>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <span className="text-green-400"><Database className="w-4 h-4 inline mr-1" />{data?.sovereign_sync?.synced || 0} synced</span>
          <span className="text-yellow-400">{data?.sovereign_sync?.pending_sync || 0} pending</span>
        </div>
      </div>

      {/* Overview */}
      <div className="grid grid-cols-2 gap-4" data-testid="analytics-overview">
        <div className="surface-card p-6 text-center"><div className="metric-value text-3xl">{data?.overview?.total_sessions || 0}</div><div className="metric-label">TOTAL SESSIONS</div></div>
        <div className="surface-card p-6 text-center"><div className="metric-value text-3xl">{data?.overview?.total_minutes || 0}</div><div className="metric-label">TOTAL MINUTES</div></div>
      </div>

      {/* Per-Mode Stats */}
      <div data-testid="mode-stats">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>VENUE PERFORMANCE</h2>
        {(data?.mode_stats?.length || 0) > 0 ? (
          <div className="space-y-3">
            {data.mode_stats.map((s, i) => (
              <div key={i} className="surface-card p-4 flex items-center justify-between">
                <div><h4 className="font-bold">{(s.game_mode || '').replace(/_/g, ' ')}</h4><p className="text-sm text-zinc-500">{s.total_sessions} sessions</p></div>
                <div className="flex items-center gap-6 text-sm">
                  <div className="text-center"><div className="font-mono text-cyan-400">{s.total_minutes}m</div><div className="metric-label">TIME</div></div>
                  <div className="text-center"><div className="font-mono text-green-400">{s.avg_score}</div><div className="metric-label">AVG SCORE</div></div>
                  <div className="text-center"><div className="font-mono text-yellow-400">{s.avg_latency_ms}ms</div><div className="metric-label">LATENCY</div></div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="surface-card p-8 text-center"><BarChart3 className="w-12 h-12 text-zinc-600 mx-auto mb-4" /><p className="text-zinc-400">Play game modes to start collecting analytics</p></div>
        )}
      </div>

      {/* Data Policy */}
      {policy && (
        <div className="surface-card p-6" data-testid="data-policy">
          <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>DATA POLICY · SOVEREIGN SYNC v1</h2>
          <div className="space-y-3 text-sm">
            {policy.sovereign_sync_protocol?.flow?.map((step, i) => (
              <div key={i} className="flex items-start gap-3 py-2 border-b border-white/5">
                <div className="w-6 h-6 bg-cyan-400/10 flex items-center justify-center flex-shrink-0 text-cyan-400 font-mono text-xs">{i+1}</div>
                <span className="text-zinc-300">{step.replace(/^\d+\.\s*/, '')}</span>
              </div>
            ))}
          </div>
          <div className="mt-4 grid grid-cols-2 gap-4 text-xs text-zinc-500">
            <div><span className="text-zinc-400">Encryption:</span> {policy.sovereign_sync_protocol?.private_signaling_server?.auth}</div>
            <div><span className="text-zinc-400">Data Format:</span> {policy.sovereign_sync_protocol?.private_signaling_server?.data_format}</div>
            <div><span className="text-zinc-400">Retention:</span> {policy.sovereign_sync_protocol?.retention}</div>
            <div><span className="text-zinc-400">Third-party:</span> {policy.sovereign_sync_protocol?.data_policy?.third_party_access}</div>
          </div>
        </div>
      )}
    </div>
  );
};
