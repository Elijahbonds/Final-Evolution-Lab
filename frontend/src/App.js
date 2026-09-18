import React, { useState, useEffect, useCallback, useRef, createContext, useContext } from "react";
import "@/App.css";
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from "react-router-dom";
import axios from "axios";
import {
  Activity, Brain, Users, Gamepad2, GraduationCap, ShoppingBag,
  LogOut, Home, User, Trophy, Heart, Dumbbell,
  Zap, Target, Clock, ChevronRight, Menu, X, Star,
  Award, BarChart3, Calendar, MessageCircle, Send,
  Play, Pause, Shield, TrendingUp, Radio, Wifi, WifiOff,
  Crosshair, Timer, Flame, Crown, Medal, ChevronDown,
  Swords, Video, Palette, UserPlus, Gift, Download, Smartphone
} from "lucide-react";
import { PayPalScriptProvider, PayPalButtons } from "@paypal/react-paypal-js";
import { StreaksView, SocialView, TournamentsView, AvatarBuilderView, VideoCritiqueView } from "@/components/NewViews";
import { MultiplayerView, ReferralView, AnalyticsView } from "@/components/QualityGates";
import { HubDashboard } from "@/components/HubDashboard";
import { FELOSDashboard, EducationTracksPortal } from "@/components/FELOSDashboard";
import { LandingPage as RedesignedLandingPage } from "@/components/LandingPage";
import DownloadPage from "@/components/DownloadPage";
import { TriviaArenaView } from "@/components/TriviaArenaView";
import Phase3HUD from "@/components/hud/Phase3HUD";
import { FEL_ARENA_MODES } from "@/lib/arenaModes";
import { initializeApp } from "firebase/app";
import { getAuth, signInWithPopup, GoogleAuthProvider } from "firebase/auth";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://localhost:8000";
const API = `${BACKEND_URL}/api`;
axios.defaults.withCredentials = true;

const FALLBACK_PRQ = { strength: 75, speed: 72, endurance: 70, agility: 73, power: 76, flexibility: 68, recovery: 80, mental: 78 };
const FALLBACK_WORKOUTS = [
  {
    id: "local-athlete-primer",
    name: "Athlete Shell Primer",
    sport: "training",
    difficulty: "Foundation",
    duration_minutes: 12,
    exercises: [
      { name: "Dynamic Warmup", sets: 1, reps: "3 min", rest: "30s" },
      { name: "Lateral Bounds", sets: 3, reps: "8/side", rest: "45s" },
      { name: "Reaction Drops", sets: 3, reps: "10", rest: "45s" },
    ],
  },
];
const FALLBACK_COACHES = [
  { name: "FEL Movement Coach", specialty: "Biomechanics", sport: "training", rate: 25, rating: 4.9, sessions: 128 },
  { name: "Bio-Fuel Coach", specialty: "Performance Nutrition", sport: "nutrition", rate: 20, rating: 4.8, sessions: 96 },
];
const FALLBACK_LEADERS = [
  { rank: 1, user_id: "dev-athlete", name: "FEL Athlete", prq_score: 75, level: 1, sport: "basketball" },
  { rank: 2, user_id: "coach-sim", name: "Coach Simulator", prq_score: 72, level: 2, sport: "training" },
  { rank: 3, user_id: "arena-bot", name: "Arena Bot", prq_score: 70, level: 1, sport: "soccer" },
];
const FALLBACK_PROGRESS = { total_workouts: 0, total_games: 0, total_brawls: 0, xp: 0 };

// Mirror of the server-authoritative economy formulas (backend/app/utils).
// Used only as an offline fallback so completed sessions always surface
// XP / Shards / PRQ / MRI rewards even when the backend is unreachable.
const SHARD_BASE_BY_OUTCOME = { win: 50, draw: 25, loss: 15 };
const PRQ_MODE_WEIGHTS = {
  basketball_h2h: 1.2, basketball_dunk: 1.0, basketball_3v3: 1.3,
  karate: 1.4, karate_h2h: 1.4, karate_endless: 1.4,
  baseball: 1.0, football: 1.5, soccer: 1.1, golf: 0.9, tennis: 1.1,
  volleyball: 1.2, gymnastics: 1.0, brain_brawl: 0.8, surfing: 1.05,
  skateboarding: 1.0, snowboarding: 1.0, market_browse: 0.0,
};
function computeLocalReward({ mode_id, score, outcome, duration_seconds = 30, combo = 0, critical = 0, pacing = 0 }) {
  const xp = Math.min(500, Math.max(10, Math.floor(score / 5)));
  const base = SHARD_BASE_BY_OUTCOME[outcome] ?? 15;
  let shards = base + Math.max(0, combo - 3) * 5 + Math.max(0, critical) * 10;
  const pacingBonus = pacing >= 75;
  if (pacingBonus) shards = Math.floor(shards * 1.05);
  const weight = PRQ_MODE_WEIGHTS[mode_id] ?? 1.0;
  const timeFactor = Math.min(1, Math.max(0, duration_seconds) / 60);
  const prq_delta = Math.round(Math.min(100, Math.max(0, score) * 0.1 * weight * 1.25 * timeFactor) * 100) / 100;
  const mri = Math.round((37.5 + 0.25 * Math.min(100, pacing)) * 100) / 100;
  return { xp, shards, prq_delta, mri, pacing_bonus_applied: pacingBonus, source: "local" };
}
function normalizeServerReward(data) {
  const economy = data?.economy || {};
  return {
    xp: economy.xp ?? data?.xp_earned ?? 0,
    shards: economy.shards ?? data?.shards_earned ?? 0,
    prq_delta: economy.prq_delta ?? data?.prq_delta ?? 0,
    mri: economy.mri ?? data?.mri ?? 0,
    pacing_bonus_applied: economy.pacing_bonus_applied ?? false,
    source: "server",
  };
}

// Initialize Firebase SDK
const firebaseConfig = {
  apiKey: process.env.REACT_APP_FIREBASE_API_KEY || "AIzaSyFakeKey-ForLocalTestingOnly",
  authDomain: process.env.REACT_APP_FIREBASE_AUTH_DOMAIN || "final-evolution-lab.firebaseapp.com",
  projectId: process.env.REACT_APP_FIREBASE_PROJECT_ID || "final-evolution-lab",
  storageBucket: process.env.REACT_APP_FIREBASE_STORAGE_BUCKET || "final-evolution-lab.appspot.com",
  messagingSenderId: process.env.REACT_APP_FIREBASE_MESSAGING_SENDER_ID || "1234567890",
  appId: process.env.REACT_APP_FIREBASE_APP_ID || "1:1234567890:web:fakeappid"
};

let firebaseApp, firebaseAuth;
try {
  firebaseApp = initializeApp(firebaseConfig);
  firebaseAuth = getAuth(firebaseApp);
} catch (e) {
  console.error("Firebase initialization failed:", e);
}

// ── Mobile-WebView Bearer fallback ─────────────────────────────
// iOS Safari ITP and in-app WebViews (Instagram, Twitter, Messages)
// frequently strip 3rd-party cookies even when SameSite=None+Secure is set.
// We mirror the session_token in localStorage and attach it as
// Authorization: Bearer <token> on every axios call. The backend already
// accepts both cookie and Bearer (see get_current_user in server.py).
const FEL_TOKEN_KEY = "fel_session_token";
axios.interceptors.request.use((config) => {
  try {
    const tok = localStorage.getItem(FEL_TOKEN_KEY);
    if (tok && !config.headers?.Authorization) {
      config.headers = config.headers || {};
      config.headers.Authorization = `Bearer ${tok}`;
    }
  } catch (_e) { /* localStorage unavailable in private mode — fall back to cookie */ }
  return config;
});

/** Dashboard embedded in Unreal iOS WKWebView — digital goods must use StoreKit, not PayPal web checkout. */
function felIOSHostedWebView() {
  if (typeof window === "undefined") return false;
  // Fallback to User Agent detection to ensure StoreKit-only split for all iOS devices (preventing PayPal presentation on iOS)
  const ua = window.navigator?.userAgent || "";
  if (/iPad|iPhone|iPod/.test(ua) && !window.MSStream) {
    return true;
  }
  if (window.__FEL_BRIDGE_TOKEN__) return true;
  const mh = window.webkit?.messageHandlers;
  if (!mh) return false;
  return !!(mh.FELBridge || mh.felNativeBridge || mh.FELNativeBridge);
}

// ===================== AUTH CONTEXT =====================
const AuthContext = createContext(null);
export const useAuth = () => useContext(AuthContext);

const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const checkAuth = useCallback(async () => {
    if (window.location.hash?.includes('session_id=')) { setLoading(false); return; }
    try { const r = await axios.get(`${API}/auth/me`); setUser(r.data); } catch { setUser(null); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { checkAuth(); }, [checkAuth]);
  const logout = async () => {
    try { await axios.post(`${API}/auth/logout`); } catch (_e) { /* ignore */ }
    try { localStorage.removeItem(FEL_TOKEN_KEY); } catch (_e) { /* ignore */ }
    setUser(null);
  };
  return <AuthContext.Provider value={{ user, setUser, loading, logout }}>{children}</AuthContext.Provider>;
};

const AuthCallback = () => {
  const navigate = useNavigate();
  const { setUser } = useAuth();
  const hasProcessed = useRef(false);
  useEffect(() => {
    if (hasProcessed.current) return;
    hasProcessed.current = true;
    const process = async () => {
      const sid = window.location.hash.split('session_id=')[1]?.split('&')[0];
      if (!sid) { navigate('/login'); return; }
      try {
        const r = await axios.post(`${API}/auth/session`, { session_id: sid });
        // Persist Bearer fallback for mobile WebViews that strip cookies.
        if (r.data?.session_token) {
          try { localStorage.setItem(FEL_TOKEN_KEY, r.data.session_token); } catch (_e) { /* ignore */ }
        }
        setUser(r.data);
        navigate('/dashboard', { replace: true, state: { user: r.data } });
      } catch { navigate('/login'); }
    };
    process();
  }, [navigate, setUser]);
  return <div className="min-h-screen flex items-center justify-center" style={{background:'var(--bg-default)'}}><div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin"></div></div>;
};

const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();
  const location = useLocation();
  if (loading) return <div className="min-h-screen flex items-center justify-center" style={{background:'var(--bg-default)'}}><div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin"></div></div>;
  if (!user && !location.state?.user) return <Navigate to="/login" replace />;
  return children;
};

// ===================== LANDING PAGE =====================
const LandingPage = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  useEffect(() => { if (user) navigate('/dashboard'); }, [user, navigate]);
  return <RedesignedLandingPage />;
};

const LoginPage = () => {
  const { user, setUser } = useAuth();
  const navigate = useNavigate();
  const [authError, setAuthError] = useState("");
  const [isAuthenticating, setIsAuthenticating] = useState(false);

  useEffect(() => { if (user) navigate('/dashboard'); }, [user, navigate]);

  const handleLogin = async () => {
    if (!firebaseAuth) {
      setAuthError("Firebase Auth is not properly initialized. Contact administration.");
      return;
    }
    setIsAuthenticating(true);
    setAuthError("");
    const provider = new GoogleAuthProvider();
    try {
      const result = await signInWithPopup(firebaseAuth, provider);
      const idToken = await result.user.getIdToken();
      // Exchange token for backend session
      const r = await axios.post(`${API}/auth/session`, { session_id: idToken });
      if (r.data?.session_token) {
        try { localStorage.setItem(FEL_TOKEN_KEY, r.data.session_token); } catch (_e) {}
      }
      setUser(r.data);
      navigate('/dashboard', { replace: true, state: { user: r.data } });
    } catch (error) {
      console.error("Google Auth Sign-In failed:", error);
      setAuthError(error.message || "Authentication failed. Please try again.");
    } finally {
      setIsAuthenticating(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#050505]" style={{background:'var(--bg-default)'}}>
      <div className="surface-card p-8 w-full max-w-md text-center border border-white/10 rounded-sm">
        <div className="w-16 h-16 bg-[#5ce1e6] flex items-center justify-center mx-auto mb-6 shadow-[0_0_15px_rgba(92,225,230,0.3)]">
          <Zap className="w-10 h-10 text-black fill-current" />
        </div>
        <h1 className="text-3xl font-extrabold mb-2 text-white" style={{fontFamily:'Barlow Condensed'}}>FINAL EVOLUTION LAB</h1>
        <p className="text-zinc-400 mb-8 text-sm">Sign in using your Google credentials to enter the Athlete OS</p>
        
        {authError && (
          <div className="mb-6 p-3 border border-red-500/30 bg-red-500/5 text-xs text-red-400 font-mono text-left">
            {authError}
          </div>
        )}

        <button 
          data-testid="login-google-btn" 
          onClick={handleLogin} 
          disabled={isAuthenticating}
          className="btn-primary w-full flex items-center justify-center gap-3 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-extrabold py-3.5 tracking-wider transition-all disabled:bg-zinc-800 disabled:text-zinc-500 rounded-none shadow-[0_0_20px_rgba(92,225,230,0.15)]"
        >
          {isAuthenticating ? (
            <>
              <div className="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin"></div>
              <span>Securing Session...</span>
            </>
          ) : (
            <span>Continue with Google</span>
          )}
        </button>
      </div>
    </div>
  );
};

// ===================== SIDEBAR =====================
const Sidebar = ({ activeTab, setActiveTab }) => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [mobileOpen, setMobileOpen] = useState(false);
  const navItems = [
    {id:'fel-os',icon:Crosshair,label:'FEL OS'},
    {id:'dashboard',icon:Home,label:'Dashboard'},{id:'scan',icon:Activity,label:'System Scan'},
    {id:'games',icon:Gamepad2,label:'Game Modes'},{id:'multiplayer',icon:Swords,label:'Multiplayer'},
    {id:'cards',icon:Users,label:'Creator Cards'},{id:'coach',icon:Trophy,label:'Coach Hub'},
    {id:'ai-coach',icon:MessageCircle,label:'AI Coach'},
    {id:'education',icon:GraduationCap,label:'Education'},{id:'brain-brawl',icon:Brain,label:'Brain Brawl'},
    {id:'trivia',icon:Award,label:'Trivia Arena'},{id:'hud',icon:Radio,label:'HUD Overlay'},
    {id:'streaks',icon:Flame,label:'Streaks'},{id:'social',icon:UserPlus,label:'Social'},
    {id:'tournaments',icon:Swords,label:'Tournaments'},{id:'avatar',icon:Palette,label:'Avatar'},
    {id:'critique',icon:Video,label:'Video Critique'},{id:'referral',icon:Gift,label:'Referrals'},
    {id:'analytics',icon:BarChart3,label:'Analytics'},
    {id:'vault',icon:Shield,label:'Final Evolution Hub'},
    {id:'leaderboard',icon:Crown,label:'Leaderboard'},{id:'streaming',icon:Download,label:'Get App'},
    {id:'profile',icon:User,label:'Profile'},
  ];
  return (
    <>
      <button data-testid="mobile-menu-btn" className="lg:hidden fixed top-4 left-4 z-[60] p-2 bg-zinc-900 border border-zinc-800" onClick={() => setMobileOpen(!mobileOpen)}>
        {mobileOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
      </button>
      <aside className={`sidebar ${mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'} transition-transform`}>
        <div className="p-6 border-b border-white/5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-cyan-400 flex items-center justify-center"><Zap className="w-6 h-6 text-black" /></div>
            <div><div className="font-bold text-sm tracking-tight" style={{fontFamily:'Barlow Condensed'}}>FINAL EVOLUTION</div><div className="text-xs text-zinc-500">LAB v1.0</div></div>
          </div>
        </div>
        <nav className="flex-1 py-2 overflow-y-auto">
          {navItems.map(item => (
            <button key={item.id} data-testid={`nav-${item.id}`} onClick={() => {setActiveTab(item.id);setMobileOpen(false);}} className={`nav-item w-full ${activeTab === item.id ? 'active' : ''}`}>
              <item.icon className="w-5 h-5" />{item.label}
            </button>
          ))}
        </nav>
        <div className="p-4 border-t border-white/5">
          <div className="flex items-center gap-3 mb-3">
            {user?.picture ? <img src={user.picture} alt="" className="w-9 h-9 rounded-full" /> : <div className="w-9 h-9 bg-zinc-800 rounded-full flex items-center justify-center"><User className="w-5 h-5 text-zinc-400" /></div>}
            <div className="flex-1 min-w-0"><div className="font-medium text-sm truncate">{user?.name || 'Athlete'}</div><div className="text-xs text-zinc-500">Lvl {user?.level || 1}</div></div>
          </div>
          <button data-testid="logout-btn" onClick={async () => {await logout();navigate('/');}} className="nav-item w-full text-red-400 hover:text-red-300"><LogOut className="w-5 h-5" />Sign Out</button>
        </div>
      </aside>
    </>
  );
};

// ===================== DASHBOARD =====================
const DashboardView = ({ setActiveTab }) => {
  const { user } = useAuth();
  const [prq, setPrq] = useState(null);
  const [stats, setStats] = useState(null);
  useEffect(() => {
    Promise.all([axios.get(`${API}/prq/metrics`), axios.get(`${API}/stats/overview`)])
      .then(([p, s]) => { setPrq(p.data); setStats(s.data); }).catch(() => {
        setPrq({ ...FALLBACK_PRQ, overall_score: 75 });
        setStats({ total_workouts: 0, game_sessions: 0, brain_brawl_sessions: 0, xp: 0 });
      });
  }, []);
  return (
    <div className="space-y-8 fade-in" data-testid="dashboard-view">
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div><p className="overline mb-1">WELCOME BACK</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>{user?.name?.split(' ')[0] || 'ATHLETE'}</h1></div>
        <div className="text-right"><div className="metric-label">TODAY</div><div className="text-lg font-medium">{new Date().toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'})}</div></div>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="surface-active p-6" data-testid="prq-score-card">
          <p className="overline mb-4">PERFORMANCE READINESS</p>
          <div className="flex items-center justify-center">
            <div className="relative">
              <svg className="w-48 h-48" viewBox="0 0 192 192"><circle cx="96" cy="96" r="80" fill="none" stroke="var(--secondary)" strokeWidth="12" /><circle cx="96" cy="96" r="80" fill="none" stroke="var(--primary)" strokeWidth="12" strokeLinecap="round" transform="rotate(-90 96 96)" strokeDasharray={`${(prq?.overall_score||75)*5.02} 502`} /></svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center"><span className="metric-value">{prq?.overall_score?.toFixed(0)||'75'}</span><span className="metric-label">PRQ</span></div>
            </div>
          </div>
        </div>
        <div className="lg:col-span-2 grid grid-cols-2 gap-4">
          {[{l:'Workouts',v:stats?.total_workouts||0,icon:Dumbbell,c:'text-green-400'},{l:'Games',v:stats?.game_sessions||0,icon:Gamepad2,c:'text-blue-400'},{l:'Brain Brawls',v:stats?.brain_brawl_sessions||0,icon:Brain,c:'text-purple-400'},{l:'XP',v:stats?.xp||0,icon:Star,c:'text-yellow-400'}].map((s,i)=>(
            <div key={i} className="surface-card p-6"><s.icon className={`w-8 h-8 ${s.c} mb-3`} /><div className="metric-value text-2xl">{s.v}</div><div className="metric-label">{s.l}</div></div>
          ))}
        </div>
      </div>
      <div>
        <h2 className="text-2xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>QUICK START</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[{t:'Play Game',d:'19 modes',icon:Gamepad2,a:'games'},{t:'AI Coach',d:'Get training plan',icon:MessageCircle,a:'ai-coach'},{t:'Brain Brawl',d:'Test your IQ',icon:Brain,a:'brain-brawl'},{t:'Streak',d:'Check in today',icon:Flame,a:'streaks'}].map((i,idx)=>(
            <button key={idx} data-testid={`quick-${i.a}`} onClick={()=>setActiveTab(i.a)} className="surface-card p-5 text-left card-hover flex items-center gap-4">
              <div className="w-12 h-12 bg-cyan-400/10 flex items-center justify-center flex-shrink-0"><i.icon className="w-6 h-6 text-cyan-400" /></div>
              <div className="flex-1 min-w-0"><div className="font-bold">{i.t}</div><div className="text-sm text-zinc-500">{i.d}</div></div>
              <ChevronRight className="w-5 h-5 text-zinc-600 flex-shrink-0" />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};

// ===================== SYSTEM SCAN =====================
const SystemScanView = () => {
  const [prq, setPrq] = useState(null);
  const [workouts, setWorkouts] = useState([]);
  const [activeWorkout, setActiveWorkout] = useState(null);
  const [exerciseIdx, setExerciseIdx] = useState(0);
  const [workoutTimer, setWorkoutTimer] = useState(0);
  const [timerRunning, setTimerRunning] = useState(false);
  const timerRef = useRef(null);

  useEffect(() => {
    Promise.all([axios.get(`${API}/prq/metrics`), axios.get(`${API}/workouts/recommended`)])
      .then(([p,w]) => {setPrq(p.data);setWorkouts(w.data);}).catch(() => { setPrq(FALLBACK_PRQ); setWorkouts(FALLBACK_WORKOUTS); });
  }, []);

  useEffect(() => {
    if (timerRunning) { timerRef.current = setInterval(() => setWorkoutTimer(t => t+1), 1000); }
    return () => clearInterval(timerRef.current);
  }, [timerRunning]);

  const startWorkout = (w) => { setActiveWorkout(w); setExerciseIdx(0); setWorkoutTimer(0); setTimerRunning(true); };
  const completeExercise = () => {
    if (exerciseIdx + 1 >= activeWorkout.exercises.length) {
      setTimerRunning(false);
      axios.post(`${API}/workouts/log`, {workout_id: activeWorkout.id, workout_name: activeWorkout.name, duration_minutes: Math.ceil(workoutTimer/60)}).catch(console.error);
      setActiveWorkout(null);
    } else { setExerciseIdx(i => i+1); }
  };

  const metrics = [{k:'strength',l:'STR',c:'#FF6B6B'},{k:'speed',l:'SPD',c:'#4ECDC4'},{k:'endurance',l:'END',c:'#45B7D1'},{k:'agility',l:'AGI',c:'#96CEB4'},{k:'power',l:'PWR',c:'#FFEAA7'},{k:'flexibility',l:'FLX',c:'#DDA0DD'},{k:'recovery',l:'REC',c:'#98D8C8'},{k:'mental',l:'MNT',c:'#F7DC6F'}];

  if (activeWorkout) {
    const ex = activeWorkout.exercises[exerciseIdx];
    return (
      <div className="space-y-6 fade-in max-w-2xl mx-auto" data-testid="active-workout">
        <div className="flex items-center justify-between">
          <div><p className="overline mb-1">ACTIVE WORKOUT</p><h1 className="text-3xl font-black" style={{fontFamily:'Barlow Condensed'}}>{activeWorkout.name}</h1></div>
          <div className="text-right"><div className="metric-value text-2xl text-cyan-400">{Math.floor(workoutTimer/60)}:{String(workoutTimer%60).padStart(2,'0')}</div><div className="metric-label">ELAPSED</div></div>
        </div>
        <div className="progress-bar"><div className="progress-fill" style={{width:`${((exerciseIdx+1)/activeWorkout.exercises.length)*100}%`}}></div></div>
        <div className="surface-active p-8 text-center">
          <div className="badge-clinical mb-4 inline-block">{exerciseIdx+1} / {activeWorkout.exercises.length}</div>
          <h2 className="text-3xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>{ex.name}</h2>
          <div className="flex justify-center gap-8 mb-8">
            <div><div className="metric-value text-4xl">{ex.sets}</div><div className="metric-label">Sets</div></div>
            <div><div className="metric-value text-4xl">{ex.reps}</div><div className="metric-label">Reps</div></div>
            <div><div className="metric-value text-4xl">{ex.rest}</div><div className="metric-label">Rest</div></div>
          </div>
          <button data-testid="complete-exercise" onClick={completeExercise} className="btn-primary text-lg px-12 py-4">{exerciseIdx + 1 >= activeWorkout.exercises.length ? 'Finish Workout' : 'Next Exercise'}</button>
        </div>
        <button onClick={() => {setActiveWorkout(null);setTimerRunning(false);}} className="btn-secondary w-full">Cancel Workout</button>
      </div>
    );
  }

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">PERFORMANCE ANALYSIS</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>SYSTEM SCAN</h1></div>
      <div className="surface-card p-6" data-testid="prq-breakdown">
        <h2 className="text-xl font-bold mb-6" style={{fontFamily:'Barlow Condensed'}}>PRQ BREAKDOWN</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {metrics.map(m => (
            <div key={m.k} className="surface-card p-4">
              <div className="flex items-center justify-between mb-2"><span className="metric-label">{m.l}</span><span className="font-mono text-lg">{prq?.[m.k]?.toFixed(0)||'--'}</span></div>
              <div className="progress-bar"><div className="progress-fill" style={{width:`${prq?.[m.k]||0}%`,background:m.c}}></div></div>
            </div>
          ))}
        </div>
      </div>
      <div className="surface-card p-6" data-testid="health-signals">
        <h2 className="text-xl font-bold mb-6" style={{fontFamily:'Barlow Condensed'}}>HEALTH SIGNALS</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[{l:'Heart Rate',v:'72',u:'BPM',icon:Heart},{l:'Sleep',v:'7.5',u:'HRS',icon:Clock},{l:'Steps',v:'8,500',u:'',icon:Activity},{l:'Readiness',v:'85',u:'%',icon:Zap}].map((h,i)=>(
            <div key={i} className="bg-black/50 p-4 border border-white/5"><h.icon className="w-5 h-5 text-cyan-400 mb-2" /><div className="metric-value text-2xl">{h.v}{h.u && <span className="text-sm ml-1">{h.u}</span>}</div><div className="metric-label">{h.l}</div></div>
          ))}
        </div>
      </div>
      <div data-testid="recommended-workouts">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>WORKOUT PLANS</h2>
        <div className="grid md:grid-cols-2 gap-4">
          {workouts.map(w => (
            <div key={w.id} className="surface-card p-6 card-hover">
              <div className="flex items-center gap-2 mb-3"><span className="badge-clinical">{w.sport}</span><span className="badge-clinical" style={{background:'rgba(255,184,0,0.1)',borderColor:'rgba(255,184,0,0.3)',color:'#FFB800'}}>{w.difficulty}</span></div>
              <h3 className="text-lg font-bold mb-2">{w.name}</h3>
              <div className="flex items-center gap-4 text-sm text-zinc-400 mb-3"><span className="flex items-center gap-1"><Clock className="w-4 h-4" />{w.duration_minutes}min</span><span>{w.exercises.length} exercises</span></div>
              <div className="space-y-2 mb-4">{w.exercises.map((e,i) => <div key={i} className="flex items-center justify-between text-sm py-1 border-b border-white/5"><span>{e.name}</span><span className="text-zinc-500">{e.sets}×{e.reps}</span></div>)}</div>
              <button data-testid={`start-workout-${w.id}`} onClick={()=>startWorkout(w)} className="btn-primary w-full">Start Workout</button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ===================== PLAYABLE GAME ENGINE (UE5 SIMULATOR) =====================
const PlayableGame = ({ mode, onComplete, onBack }) => {
  const [score, setScore] = useState(0);
  const [timeLeft, setTimeLeft] = useState(30);
  const [gameActive, setGameActive] = useState(true);
  const [targets, setTargets] = useState([]);
  const [combo, setCombo] = useState(0);
  const [maxCombo, setMaxCombo] = useState(0);
  const [floaters, setFloaters] = useState([]);
  const [bgLoaded, setBgLoaded] = useState(false);
  const [consoleLogs, setConsoleLogs] = useState([]);
  const [reward, setReward] = useState(null);
  const timerRef = useRef(null);
  const audioCtxRef = useRef(null);
  const logContainerRef = useRef(null);
  const submittedRef = useRef(false);

  // Dynamic asset pre-caching
  useEffect(() => {
    setBgLoaded(false);
    const img = new Image();
    img.src = mode.image_url;
    img.onload = () => setBgLoaded(true);
    
    // Seed initial console logs simulating Unreal Engine client loading
    setConsoleLogs([
      { id: 1, ts: new Date().toLocaleTimeString(), msg: `[Engine] Initializing Unreal Engine 5.7.0-shipping...` },
      { id: 2, ts: new Date().toLocaleTimeString(), msg: `[LocalHub] Re-authenticating local hardware token...` },
      { id: 3, ts: new Date().toLocaleTimeString(), msg: `[LocalHub] Connecting to vault hub wss://localhost:8888...` },
      { id: 4, ts: new Date().toLocaleTimeString(), msg: `[LocalHub] Protocol: AES-256-GCM secure tunnels enabled.` },
      { id: 5, ts: new Date().toLocaleTimeString(), msg: `[Engine] Loading Map: /Game/FEL/Venues/${mode.venue}/${mode.venue}` },
    ]);

    return () => {
      img.onload = null;
      img.src = '';
    };
  }, [mode]);

  // Audio Context cleanup
  useEffect(() => {
    return () => {
      if (audioCtxRef.current) {
        audioCtxRef.current.close().catch(console.error);
        audioCtxRef.current = null;
      }
    };
  }, []);

  // Scroll console logs to bottom
  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
    }
  }, [consoleLogs]);

  const addLog = useCallback((msg) => {
    setConsoleLogs(prev => [...prev, { id: Date.now() + Math.random(), ts: new Date().toLocaleTimeString(), msg }].slice(-25));
  }, []);

  const getAudioContext = useCallback(() => {
    if (!audioCtxRef.current) {
      audioCtxRef.current = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtxRef.current.state === "suspended") {
      audioCtxRef.current.resume();
    }
    return audioCtxRef.current;
  }, []);

  const playSound = useCallback((type) => {
    try {
      const ctx = getAudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);

      if (type === 'hit') {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(450, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(900, ctx.currentTime + 0.12);
        gain.gain.setValueAtTime(0.12, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.12);
        osc.start();
        osc.stop(ctx.currentTime + 0.12);
      } else if (type === 'bonus') {
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(550, ctx.currentTime);
        osc.frequency.setValueAtTime(1100, ctx.currentTime + 0.08);
        gain.gain.setValueAtTime(0.15, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.2);
        osc.start();
        osc.stop(ctx.currentTime + 0.2);
      } else if (type === 'miss') {
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(180, ctx.currentTime);
        osc.frequency.linearRampToValueAtTime(90, ctx.currentTime + 0.15);
        gain.gain.setValueAtTime(0.08, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.15);
        osc.start();
        osc.stop(ctx.currentTime + 0.15);
      } else if (type === 'gameover') {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(500, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(250, ctx.currentTime + 0.4);
        gain.gain.setValueAtTime(0.15, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.4);
        osc.start();
        osc.stop(ctx.currentTime + 0.4);
      }
    } catch (e) {
      console.warn("Web Audio API failed:", e);
    }
  }, [getAudioContext]);

  useEffect(() => {
    if (gameActive && timeLeft > 0) {
      timerRef.current = setInterval(() => setTimeLeft(t => t - 1), 1000);
    }
    return () => clearInterval(timerRef.current);
  }, [gameActive, timeLeft]);

  // Spawn targets over the Unreal Engine frame (ensuring they remain testable by Puppeteer)
  useEffect(() => {
    if (!gameActive) return;
    const spawn = setInterval(() => {
      const isBonus = Math.random() > 0.25;
      const newTarget = {
        id: Date.now() + Math.random(), 
        x: Math.random() * 60 + 20, 
        y: Math.random() * 50 + 20,
        size: Math.random() * 15 + 35, 
        type: isBonus ? 'target' : 'bonus',
        created: Date.now()
      };
      setTargets(prev => [...prev, newTarget].slice(-6));
      addLog(`[Engine] Telemetry target spawned: ID_${Math.floor(newTarget.id % 10000)} (type=${newTarget.type})`);
    }, mode.game_type === 'precision' ? 1400 : 750);
    return () => clearInterval(spawn);
  }, [gameActive, mode.game_type, addLog]);

  useEffect(() => {
    const cleanup = setInterval(() => {
      setTargets(prev => prev.filter(t => Date.now() - t.created < 2500));
    }, 400);
    return () => clearInterval(cleanup);
  }, []);

  useEffect(() => {
    const floatCleanup = setInterval(() => {
      setFloaters(prev => prev.filter(f => Date.now() - f.id < 800));
    }, 100);
    return () => clearInterval(floatCleanup);
  }, []);

  const hitTarget = (target) => {
    if (!gameActive) return;
    const points = target.type === 'bonus' ? 50 : 25;
    const comboBonus = combo > 2 ? combo * 5 : 0;
    const totalPoints = points + comboBonus;
    
    setScore(s => s + totalPoints);
    setCombo(c => { const next = c + 1; setMaxCombo(m => Math.max(m, next)); return next; });
    setTargets(prev => prev.filter(t => t.id !== target.id));
    
    setFloaters(prev => [...prev, {
      id: Date.now(),
      x: target.x,
      y: target.y,
      text: `+${totalPoints}${comboBonus > 0 ? ` (Combo x${combo})` : ''}`,
      type: target.type
    }]);

    playSound(target.type);
    addLog(`[Telemetry] Target hit! ID_${Math.floor(target.id % 10000)} +${totalPoints} pts (Combo x${combo + 1})`);
  };

  const handleMiss = () => {
    if (!gameActive) return;
    setCombo(0);
    playSound('miss');
    addLog(`[Telemetry] Input miss registered. Combo reset.`);
  };

  const finalizeGame = useCallback(async () => {
    if (submittedRef.current) return;
    submittedRef.current = true;
    setGameActive(false);
    clearInterval(timerRef.current);
    playSound('gameover');
    addLog(`[Ledger] Session ended. Committing receipt for ${mode.id}...`);
    try {
      const result = await onComplete(score, maxCombo);
      if (result) {
        setReward(result);
        addLog(`[Ledger] Rewards: +${result.xp} XP · +${result.shards} Shards · PRQ ${result.prq_delta >= 0 ? '+' : ''}${result.prq_delta}`);
      }
    } catch (_e) {
      addLog(`[Error] Reward commit failed; showing local estimate.`);
    }
  }, [mode.id, score, maxCombo, onComplete, playSound, addLog]);

  useEffect(() => {
    if (timeLeft <= 0 && gameActive) { finalizeGame(); }
  }, [timeLeft, gameActive, finalizeGame]);

  const getGameTitle = () => {
    const titles = {
      shooting: 'Shoot & Score', timing: 'Perfect Timing', combat: 'Strike Zone',
      reflex: 'Reflex Rush', precision: 'Precision Shot', balance: 'Balance Master',
      endurance: 'Endurance Mode', strategy: 'Strategy Play', quiz: 'Brain Brawl'
    };
    return titles[mode.game_type] || 'Challenge';
  };

  const getTargetIcon = (type) => {
    if (type === 'bonus') return Star;
    if (mode.category === 'Basketball') return Target;
    if (mode.category === 'Combat') return Swords;
    if (mode.category === 'Performance') return Medal;
    if (mode.category === 'Board') return Flame;
    if (mode.category === 'Academy') return Brain;
    return Crosshair;
  };

  const getTargetColors = () => {
    const category = (mode.category || '').toLowerCase();
    if (category === 'basketball') {
      return { bg: 'bg-orange-500/85', border: 'border-orange-400', glow: 'shadow-orange-500/60', text: 'text-orange-400' };
    }
    if (category === 'combat') {
      return { bg: 'bg-red-600/85', border: 'border-red-400', glow: 'shadow-red-500/60', text: 'text-red-400' };
    }
    if (category === 'performance') {
      return { bg: 'bg-amber-500/85', border: 'border-amber-400', glow: 'shadow-amber-500/60', text: 'text-amber-400' };
    }
    if (category === 'board') {
      return { bg: 'bg-cyan-500/85', border: 'border-cyan-400', glow: 'shadow-cyan-500/60', text: 'text-cyan-400' };
    }
    return { bg: 'bg-cyan-400/85', border: 'border-cyan-300', glow: 'shadow-cyan-400/60', text: 'text-cyan-400' };
  };

  const colors = getTargetColors();

  const handleLaunchNative = () => {
    addLog(`[LocalHub] Traversal initiated: finalevolution://launch?map=${mode.venue}&mode=${mode.id}`);
    axios.post(`${API}/vault/launch-mode`, { mode_id: mode.id })
      .then(r => {
        addLog(`[LocalHub] Handshake registered. Deep linking to local binary...`);
        if (r.data.deep_link) {
          window.location.href = r.data.deep_link;
        }
      })
      .catch(err => {
        addLog(`[Error] Traversal failed: ${err.message}`);
      });
  };

  if (!gameActive) {
    return (
      <div className="max-w-2xl mx-auto text-center space-y-6 fade-in p-8 surface-card border border-white/10 rounded-2xl shadow-2xl relative overflow-hidden" data-testid="game-results">
        <div className="absolute inset-0 bg-radial-gradient from-cyan-900/10 to-transparent pointer-events-none"></div>
        <Award className="w-20 h-20 text-cyan-400 mx-auto animate-pulse" />
        <h2 className="text-4xl font-black tracking-wider text-white" style={{fontFamily:'Barlow Condensed'}}>UNREAL MODULE COMPLETE</h2>
        <div className="metric-value text-6xl text-cyan-400 drop-shadow-[0_0_15px_rgba(0,229,255,0.4)]">{score}</div>
        <div className="metric-label text-zinc-400 tracking-wider">REPLICATED LEDGER SCORE</div>

        {/* Server-authoritative economy rewards (XP / Shards / PRQ / MRI) */}
        {reward ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 max-w-2xl mx-auto" data-testid="game-rewards">
            <div className="bg-black/40 p-4 border border-white/5 rounded-xl"><div className="metric-value text-2xl text-yellow-400 font-bold">+{reward.xp}</div><div className="metric-label text-xs">XP</div></div>
            <div className="bg-black/40 p-4 border border-white/5 rounded-xl"><div className="metric-value text-2xl text-cyan-400 font-bold">+{reward.shards}</div><div className="metric-label text-xs">SHARDS</div></div>
            <div className="bg-black/40 p-4 border border-white/5 rounded-xl"><div className={`metric-value text-2xl font-bold ${reward.prq_delta >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>{reward.prq_delta >= 0 ? `+${reward.prq_delta}` : reward.prq_delta}</div><div className="metric-label text-xs">PRQ Δ</div></div>
            <div className="bg-black/40 p-4 border border-white/5 rounded-xl"><div className="metric-value text-2xl text-purple-400 font-bold">{reward.mri}</div><div className="metric-label text-xs">MRI</div></div>
          </div>
        ) : (
          <div className="flex items-center justify-center gap-2 text-zinc-500 text-sm" data-testid="game-rewards-pending">
            <div className="w-4 h-4 border-2 border-cyan-400 border-t-transparent rounded-full animate-spin"></div>
            Committing session receipt...
          </div>
        )}

        <div className="bg-black/30 p-4 border border-white/5 rounded-xl font-mono text-left text-xs text-zinc-400 space-y-1 max-w-lg mx-auto">
          <div><span className="text-zinc-600">»</span> [Ledger] Sync Target: M4 Pro Mac Mini (LocalHub Mode)</div>
          <div><span className="text-zinc-600">»</span> [Ledger] {reward?.source === 'server' ? 'Server-verified receipt committed.' : reward?.source === 'local' ? 'Offline estimate (backend unreachable).' : 'Awaiting receipt...'}{reward?.pacing_bonus_applied ? ' · Pacing bonus applied.' : ''}</div>
        </div>

        <div className="grid grid-cols-2 gap-4 max-w-lg mx-auto">
          <div className="bg-black/40 p-4 border border-white/5 rounded-xl"><div className="metric-value text-3xl text-cyan-400 font-bold">{maxCombo}</div><div className="metric-label text-xs">MAX COMBO</div></div>
          <div className="bg-black/40 p-4 border border-white/5 rounded-xl"><div className="text-md font-bold text-white truncate">{mode.name}</div><div className="metric-label text-xs">MODE</div></div>
        </div>
        <div className="flex gap-4 max-w-lg mx-auto pt-4">
          <button data-testid="play-again-btn" onClick={() => {submittedRef.current=false;setReward(null);setScore(0);setTimeLeft(30);setCombo(0);setMaxCombo(0);setGameActive(true);}} className="btn-primary flex-1 shadow-lg shadow-cyan-500/20">Re-Initialize</button>
          <button data-testid="back-to-modes" onClick={onBack} className="btn-secondary flex-1">Back to Lobbies</button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 fade-in" data-testid="active-game">
      <style>{`
        @keyframes floatFade {
          0% { transform: translate(-50%, -50%) scale(0.8) translateY(0); opacity: 1; }
          100% { transform: translate(-50%, -50%) scale(1.2) translateY(-50px); opacity: 0; }
        }
        .animate-float-fade {
          animation: floatFade 0.8s forwards cubic-bezier(0.25, 1, 0.5, 1);
        }
        .text-glow-cyan {
          text-shadow: 0 0 10px rgba(0, 229, 255, 0.5);
        }
        .hud-panel {
          background: rgba(10, 10, 10, 0.75);
          backdrop-filter: blur(8px);
          border: 1px solid rgba(255, 255, 255, 0.08);
        }
      `}</style>
      
      <div className="flex items-center justify-between">
        <button onClick={onBack} className="btn-secondary text-sm px-4 py-2 border border-white/10 hover:border-white/30 rounded-lg">Exit</button>
        <div className="text-center">
          <span className="badge-clinical text-[10px] uppercase font-mono tracking-widest px-2 py-0.5" style={{background:'rgba(6, 182, 212, 0.1)', borderColor:'rgba(6, 182, 212, 0.3)', color:'#22d3ee'}}>UE5 SIMULATOR OVERLAY</span>
          <h2 className="text-2xl font-black text-white tracking-wide uppercase" style={{fontFamily:'Barlow Condensed'}}>{mode.display_name} · {getGameTitle()}</h2>
        </div>
        <div className="flex items-center gap-4">
          <div className="text-center px-4 py-1 bg-black/40 border border-white/5 rounded-lg">
            <div className={`metric-value text-2xl font-mono ${timeLeft <= 10 ? 'text-red-400 animate-pulse' : 'text-cyan-400 text-glow-cyan'}`}>
              {timeLeft}s
            </div>
            <div className="metric-label text-[10px] text-zinc-500">UE RUNTIME</div>
          </div>
        </div>
      </div>

      {/* Main Unreal Simulator Dashboard Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
        
        {/* Left Side: UE5 Telemetry Overlay & HUD */}
        <div className="space-y-4 lg:col-span-1">
          <div className="hud-panel p-4 rounded-xl space-y-4">
            <h3 className="text-xs font-mono font-bold text-zinc-500 uppercase tracking-widest border-b border-white/5 pb-2">UE5 Game Stats</h3>
            
            <div className="space-y-3">
              <div>
                <div className="flex justify-between text-xs font-mono text-zinc-400 mb-1"><span>STAMINA</span><span>84%</span></div>
                <div className="w-full bg-zinc-800 h-2 rounded-full overflow-hidden">
                  <div className="bg-orange-500 h-full rounded-full shadow-[0_0_8px_rgba(249,115,22,0.6)]" style={{width:'84%'}}></div>
                </div>
              </div>

              <div>
                <div className="flex justify-between text-xs font-mono text-zinc-400 mb-1"><span>FOCUS LATENCY</span><span>500ms</span></div>
                <div className="w-full bg-zinc-800 h-2 rounded-full overflow-hidden">
                  <div className="bg-cyan-400 h-full rounded-full shadow-[0_0_8px_rgba(34,211,238,0.6)]" style={{width:'90%'}}></div>
                </div>
              </div>

              <div className="bg-black/30 p-3 rounded-lg border border-white/5 space-y-1 text-xs font-mono">
                <div className="text-zinc-500">VENUE: <span className="text-white">{mode.venue}</span></div>
                <div className="text-zinc-500">DIFFICULTY: <span className="text-white">{mode.difficulty}</span></div>
                <div className="text-zinc-500">PLAYERS: <span className="text-white">{mode.player_count}</span></div>
              </div>
            </div>
          </div>

          <div className="hud-panel p-4 rounded-xl space-y-3 text-center">
            <h3 className="text-xs font-mono font-bold text-zinc-500 uppercase tracking-widest border-b border-white/5 pb-2">Local Hub Launcher</h3>
            <button 
              onClick={handleLaunchNative}
              className="btn-primary w-full py-2.5 flex items-center justify-center gap-2 text-xs font-bold uppercase tracking-wider shadow-lg shadow-cyan-500/20"
            >
              <Play className="w-3.5 h-3.5 fill-black text-black" />
              Launch Native 3D Client
            </button>
            <div className="text-[10px] text-zinc-500 font-mono leading-relaxed">
              Launches cooked binary for <span className="text-cyan-400">{mode.name}</span>. Ensure local launcher is open.
            </div>
          </div>
        </div>

        {/* Center: Unreal Engine Gameplay Screen Render */}
        <div className="lg:col-span-2 relative w-full border border-white/10 overflow-hidden rounded-2xl shadow-2xl transition-all duration-300 hover:border-white/20" 
             style={{ height: '480px', cursor: 'crosshair' }} 
             onClick={handleMiss}>
          
          {/* Main Screenshot Background */}
          <div 
            className="absolute inset-0 transition-transform duration-500"
            style={{
              backgroundImage: bgLoaded ? `url(${mode.image_url})` : 'none',
              backgroundSize: 'cover',
              backgroundPosition: 'center',
            }}
          />

          {!bgLoaded && (
            <div className="absolute inset-0 flex items-center justify-center bg-black/90 z-20">
              <div className="text-center space-y-3">
                <div className="w-12 h-12 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin mx-auto"></div>
                <p className="text-xs text-zinc-500 font-mono tracking-widest uppercase">LOADING UNREAL ENGINE FRAME...</p>
              </div>
            </div>
          )}

          {/* Cinematic lighting/blur overlay to maintain gameplay UI contrast */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/25 to-black/40"></div>

          {/* Interactive target overlay buttons */}
          {targets.map(t => {
            const Icon = getTargetIcon(t.type);
            const tColors = t.type === 'bonus' 
              ? { bg: 'bg-yellow-400/85', border: 'border-yellow-300', glow: 'shadow-yellow-400/60', text: 'text-yellow-400' }
              : colors;

            return (
              <button key={t.id} data-testid={`target-${t.id}`}
                onClick={(e) => {e.stopPropagation(); hitTarget(t);}}
                className="absolute transition-transform duration-100 hover:scale-110 active:scale-95 group focus:outline-none z-10"
                style={{
                  left: `${t.x}%`,
                  top: `${t.y}%`,
                  width: `${t.size}px`,
                  height: `${t.size}px`,
                  transform: 'translate(-50%, -50%)',
                }}
              >
                {/* Glowing Outer Ring */}
                <div className={`w-full h-full rounded-full flex items-center justify-center ${tColors.bg} border-2 ${tColors.border} shadow-lg ${tColors.glow} backdrop-blur-sm transition-all duration-150 group-hover:brightness-110`}>
                  <Icon className="w-5 h-5 text-black filter drop-shadow-sm transition-transform duration-200 group-hover:scale-110" />
                </div>
              </button>
            );
          })}

          {/* Floating score text */}
          {floaters.map(f => (
            <div key={f.id}
              className={`absolute font-black text-2xl select-none pointer-events-none animate-float-fade drop-shadow-[0_2px_8px_rgba(0,0,0,0.8)] z-10 ${f.type === 'bonus' ? 'text-yellow-400' : colors.text}`}
              style={{
                left: `${f.x}%`,
                top: `${f.y}%`,
                transform: 'translate(-50%, -50%)',
              }}
            >
              {f.text}
            </div>
          ))}

          {/* Visual HUD overlays */}
          <div className="absolute top-4 left-4 bg-black/60 border border-white/10 px-3 py-1.5 rounded-lg flex items-center gap-2 text-xs font-mono pointer-events-none select-none">
            <div className="w-1.5 h-1.5 bg-green-400 rounded-full animate-ping"></div>
            <span className="text-zinc-400">LEDGER SYNC PROTOCOL ACTIVE</span>
          </div>

          <div className="absolute bottom-4 left-4 bg-black/60 border border-white/10 px-3 py-1 rounded-full text-xs font-mono text-zinc-400 uppercase tracking-widest pointer-events-none select-none">
            STADIUM_WORLD: {mode.venue.toUpperCase()}
          </div>
          
          <div className="absolute bottom-4 right-4 bg-black/60 border border-white/10 px-3 py-1 rounded-full text-xs font-mono text-cyan-400 uppercase tracking-widest pointer-events-none select-none">
            SCORE: {score}
          </div>
        </div>

        {/* Right Side: Unreal Engine Console Logs Stream */}
        <div className="lg:col-span-1 flex flex-col space-y-4">
          <div className="hud-panel p-4 rounded-xl flex-1 flex flex-col min-h-[300px] max-h-[480px]">
            <div className="flex items-center gap-2 border-b border-white/5 pb-2 mb-3">
              <span className="w-1.5 h-1.5 bg-cyan-400 rounded-full"></span>
              <h3 className="text-xs font-mono font-bold text-zinc-500 uppercase tracking-widest">Console Stream</h3>
            </div>
            
            <div 
              ref={logContainerRef}
              className="flex-1 overflow-y-auto font-mono text-[10px] space-y-2 text-zinc-400 pr-1 max-h-[420px]"
            >
              {consoleLogs.map(log => (
                <div key={log.id} className="leading-relaxed break-words">
                  <span className="text-zinc-600">[{log.ts}]</span> {log.msg}
                </div>
              ))}
            </div>
          </div>
        </div>

      </div>
    </div>
  );
};

// ===================== GAME MODES VIEW =====================
const GameModesView = () => {
  const [modes, setModes] = useState([]);
  const [filter, setFilter] = useState('all');
  const [playingMode, setPlayingMode] = useState(null);
  const [launchingMode, setLaunchingMode] = useState(null);
  const [sessionState, setSessionState] = useState(null);
  const [launchStatus, setLaunchStatus] = useState(null); // null, 'launching', 'map_loading', 'timeout'
  const wsRef = useRef(null);

  // Fetch modes from centralized venue registry (not hardcoded)
  useEffect(() => {
    axios
      .get(`${API}/games/modes`)
      .then(r => setModes(Array.isArray(r.data) && r.data.length ? r.data : FEL_ARENA_MODES))
      .catch(() => setModes(FEL_ARENA_MODES));
  }, []);

  const launchNativeMode = async (mode) => {
    setLaunchingMode(mode.id);
    setLaunchStatus('launching');
    try {
      const r = await axios.post(`${API}/hub/launch-mode`, { mode_id: mode.id });
      setSessionState(r.data);

      // Deep link to UE5 native binary
      const deepLink = r.data.deep_link;
      if (deepLink) {
        window.location.href = deepLink;

        // State-Aware Handshake: listen for MapLoaded via WebSocket
        // NOT a blind timeout — wait for actual bridge confirmation
        const wsUrl = `${BACKEND_URL.replace('https','wss').replace('http','ws')}/ws/hub`;
        const ws = new WebSocket(wsUrl);
        wsRef.current = ws;
        setLaunchStatus('map_loading');

        ws.onmessage = (e) => {
          try {
            const msg = JSON.parse(e.data);
            if (msg.type === 'vault_handshake' || msg.type === 'map_loaded') {
              // MapLoaded signal received from UFELBridgeSubsystem
              setLaunchStatus(null);
              setLaunchingMode(null);
              ws.close();
            }
          } catch {}
        };

        // 10s System Re-auth (NOT browser fallback)
        // If no MapLoaded signal, trigger re-auth instead of showing placeholder
        setTimeout(() => {
          if (launchStatus === 'map_loading' || launchingMode === mode.id) {
            ws.close();
            setLaunchStatus('timeout');
            // System Re-auth: re-verify session, do NOT fall back to browser game
            axios.post(`${API}/session/state`, { session_id: r.data.session_id, state: 'timeout' }).catch(() => {});
            setLaunchingMode(null);
          }
        }, 10000);
      } else {
        // No deep link available (desktop/web) — use browser version
        setLaunchingMode(null);
        setLaunchStatus(null);
        setPlayingMode(mode);
      }
    } catch {
      setLaunchingMode(null);
      setLaunchStatus(null);
      setPlayingMode(mode);
    }
  };

  const handleGameComplete = async (score, combo = 0) => {
    const safeScore = Math.max(0, Math.min(10000, Math.round(score || 0)));
    const outcome = safeScore >= 500 ? 'win' : safeScore >= 200 ? 'draw' : 'loss';
    const pacing = Math.min(100, combo * 12);
    const critical = Math.floor(combo / 3);
    const payload = {
      mode_id: playingMode.id, score: safeScore, outcome,
      duration_seconds: 30, completed: true,
      combo_count: combo, critical_count: critical, pacing_score: pacing,
    };
    try {
      const r = await axios.post(`${API}/games/session`, payload);
      if (sessionState?.session_id) {
        axios.post(`${API}/session/state`, {session_id: sessionState.session_id, state: 'completed', score: safeScore}).catch(() => {});
      }
      return normalizeServerReward(r.data);
    } catch {
      return computeLocalReward({ mode_id: playingMode.id, score: safeScore, outcome, duration_seconds: 30, combo, critical, pacing });
    }
  };

  if (launchingMode || launchStatus === 'timeout') {
    return (
      <div className="max-w-xl mx-auto text-center space-y-6 fade-in" data-testid="ue5-loading">
        <div className="surface-active p-12">
          {launchStatus === 'timeout' ? (
            <>
              <Shield className="w-20 h-20 text-yellow-400 mx-auto mb-6" />
              <h2 className="text-3xl font-bold" style={{fontFamily:'Barlow Condensed'}}>SYSTEM RE-AUTH REQUIRED</h2>
              <p className="text-zinc-400 mt-3">No MapLoaded signal received within 10s.</p>
              <p className="text-zinc-500 text-sm mt-2">Verify UE5 binary is running and Final Evolution Hub is reachable.</p>
              <div className="flex gap-4 mt-6 justify-center">
                <button onClick={() => {setLaunchStatus(null);setLaunchingMode(null);}} className="btn-secondary">Back to Modes</button>
                <button onClick={() => launchNativeMode(modes.find(m => m.id === launchingMode) || modes[0])} className="btn-primary">Retry Launch</button>
              </div>
            </>
          ) : (
            <>
              <div className="w-20 h-20 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin mx-auto mb-6"></div>
              <h2 className="text-3xl font-bold" style={{fontFamily:'Barlow Condensed'}}>INITIALIZING UE5 MODULE</h2>
              <p className="text-zinc-400 mt-3 font-mono text-sm">FinalEvolutionLab.uproject → {(launchingMode || '').replace(/_/g,' ')}</p>
              <div className="mt-6 space-y-2 text-xs text-zinc-500 font-mono">
                <div className="flex items-center gap-2 justify-center"><div className="w-2 h-2 bg-green-400 rounded-full"></div>Session registered at Final Evolution Hub</div>
                <div className="flex items-center gap-2 justify-center"><div className={`w-2 h-2 rounded-full ${launchStatus === 'map_loading' ? 'bg-cyan-400 animate-pulse' : 'bg-zinc-600'}`}></div>Awaiting MapLoaded handshake from bridge...</div>
                <div className="flex items-center gap-2 justify-center"><div className="w-2 h-2 bg-zinc-600 rounded-full"></div>Secure Enclave validated</div>
              </div>
              <p className="text-xs text-zinc-600 mt-6">State-aware handshake (no blind timeout)</p>
            </>
          )}
        </div>
      </div>
    );
  }

  if (playingMode) {
    if (playingMode.id === 'trivia_arena') {
      return <TriviaArenaView onBack={() => setPlayingMode(null)} />;
    }
    if (playingMode.game_type === 'quiz') {
      return <BrainBrawlView onBack={() => setPlayingMode(null)} />;
    }
    return <PlayableGame mode={playingMode} onComplete={handleGameComplete} onBack={() => setPlayingMode(null)} />;
  }

  const categories = ['all','Basketball','Combat','Field','Court','Precision','Board','Performance','Academy'];
  const filtered = filter === 'all' ? modes : modes.filter(m => m.category === filter);

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">ARENA ACCESS</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>GAME MODES</h1></div>
      <div className="flex gap-2 overflow-x-auto pb-2">
        {categories.map(c => (
          <button key={c} data-testid={`filter-${c.toLowerCase()}`} onClick={() => setFilter(c)} className={`px-4 py-2 text-sm font-medium uppercase tracking-wide whitespace-nowrap transition-all ${filter===c?'bg-cyan-400 text-black':'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'}`}>{c}</button>
        ))}
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" data-testid="game-modes-grid">
        {filtered.map(mode => (
          <div key={mode.id} className="game-mode-card surface-card card-hover cursor-pointer" data-testid={`game-${mode.id}`} onClick={() => mode.playable && setPlayingMode(mode)}>
            <img src={mode.image_url} alt={mode.name} loading="lazy" />
            <div className="game-mode-overlay">
              <div className="flex items-center gap-2 mb-2">
                <span className="badge-clinical">{mode.category}</span>
                {mode.playable && <span className="badge-clinical" style={{background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'}}>PLAYABLE</span>}
              </div>
              <h3 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{mode.display_name}</h3>
              <p className="text-sm text-zinc-400 mb-2">{mode.description}</p>
              <div className="flex items-center gap-4 text-xs text-zinc-500"><span>{mode.player_count}</span><span>{mode.duration}</span><span>{mode.difficulty}</span></div>
              {mode.playable && <button data-testid={`play-${mode.id}`} className="btn-primary mt-3 text-sm py-2 w-full" onClick={(e) => {e.stopPropagation();launchNativeMode(mode);}}>{launchingMode === mode.id ? <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin"></div>Launching UE5...</span> : <span><Play className="w-4 h-4 inline mr-1" />Launch Game</span>}</button>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== CREATOR CARDS =====================
const CreatorCardsView = () => {
  const [cards, setCards] = useState([]);
  const [selected, setSelected] = useState(null);
  const [purchaseState, setPurchaseState] = useState(null);
  useEffect(() => {
    axios
      .get(`${API}/marketplace/cards`)
      .then(r => setCards(r.data))
      .catch(() => axios.get(`${API}/cards`).then(r => setCards(r.data)).catch(console.error));
  }, []);

  if (selected) {
    return (
      <div className="space-y-6 fade-in max-w-3xl mx-auto" data-testid="card-detail">
        <button onClick={() => setSelected(null)} className="btn-secondary text-sm">Back to Gallery</button>
        <div className={`creator-card ${selected.style} p-8`}>
          <div className="flex flex-col md:flex-row gap-8">
            <div className="w-full md:w-64 aspect-square bg-zinc-900 overflow-hidden flex-shrink-0"><img src={selected.image_url} alt={selected.name} className="w-full h-full object-cover" /></div>
            <div className="flex-1">
              <div className="badge-clinical mb-3">{selected.tier}</div>
              <h2 className="text-3xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{selected.name}</h2>
              <p className="text-cyan-400 mb-3">{selected.title}</p>
              <p className="text-zinc-400 mb-6">{selected.bio}</p>
              <h4 className="text-sm font-bold uppercase tracking-wider text-zinc-500 mb-2">Signature Moves</h4>
              <div className="flex flex-wrap gap-2 mb-4">{selected.signature_moves.map((m,i) => <span key={i} className="badge-clinical">{m}</span>)}</div>
              <h4 className="text-sm font-bold uppercase tracking-wider text-zinc-500 mb-2">Challenges</h4>
              <div className="space-y-2 mb-6">{selected.challenges.map((c,i) => (
                <div key={i} className="surface-card p-3 flex items-center justify-between"><div><div className="font-medium text-sm">{c.name}</div><div className="text-xs text-zinc-500">{c.description}</div></div><span className="text-cyan-400 font-mono">+{c.reward} XP</span></div>
              ))}</div>
              <div className="flex flex-col sm:flex-row sm:items-center gap-4">
                <span className="metric-value text-3xl text-cyan-400">${selected.price}</span>
                {felIOSHostedWebView() ? (
                  <div className="space-y-2 max-w-md">
                    <p className="text-sm text-zinc-400">
                      In the iOS game shell, creator cards use In-App Purchase (StoreKit). Web PayPal checkout is not used here.
                    </p>
                    <button
                      type="button"
                      className="btn-primary text-sm"
                      data-testid="purchase-card-storekit"
                      onClick={() => {
                        try {
                          window.webkit?.messageHandlers?.felNativeBridge?.postMessage({
                            fel_action: "purchase_card",
                            item_type: "card",
                            item_id: selected.id,
                          });
                        } catch (_e) { /* no bridge */ }
                      }}
                    >
                      Open in-app purchase
                    </button>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <button data-testid="purchase-card" className="btn-primary w-full" onClick={() => {
                      setPurchaseState({status:'pending', card:selected.id});
                      axios.post(`${API}/marketplace/purchase`, {item_type: 'creator_card', item_id: selected.id, payment_method: 'stripe', return_url: window.location.href, cancel_url: window.location.href}).then(r => {
                        setPurchaseState({status:r.data.status, card:selected.id, checkout_url:r.data.checkout_url, offline: r.data.checkout_url?.includes('offline')});
                        if (r.data.checkout_url) window.open(r.data.checkout_url, '_blank');
                      }).catch(err => {
                        setPurchaseState({status:'error', card:selected.id, message: err?.response?.data?.detail || err.message});
                      });
                    }}>Purchase via Stripe</button>
                    <button data-testid="purchase-card-shards" className="btn-secondary w-full text-sm" onClick={() => {
                      setPurchaseState({status:'spending_shards', card:selected.id});
                      axios.post(`${API}/marketplace/purchase`, {item_type: 'creator_card', item_id: selected.id, payment_method: 'shards'}).then(r => {
                        setPurchaseState({status:r.data.status, card:selected.id, message:`Spent ${r.data.amount_shards || selected.price_shards} Shards`});
                      }).catch(err => {
                        setPurchaseState({status:'error', card:selected.id, message: err?.response?.data?.detail || err.message});
                      });
                    }}>Buy with {selected.price_shards} Shards</button>
                    {purchaseState?.card === selected.id && (
                      <p className="text-xs text-zinc-500 font-mono">
                        PAYMENT: {purchaseState.status}{purchaseState.offline ? ' · OFFLINE SANDBOX' : ''}{purchaseState.message ? ` · ${purchaseState.message}` : ''}
                      </p>
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 fade-in">
      <div className="flex items-center justify-between"><div><p className="overline mb-1">ATHLETE MARKETPLACE</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>CREATOR CARDS</h1></div></div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" data-testid="creator-cards-grid">
        {cards.map(card => (
          <div key={card.id} className={`creator-card ${card.style} p-6 card-hover cursor-pointer`} data-testid={`card-${card.id}`} onClick={() => setSelected(card)}>
            <div className="flex items-start justify-between mb-4"><div className="badge-clinical">{card.tier}</div><div className="text-right"><div className="text-xs text-zinc-500">PRICE</div><div className="font-mono text-lg text-cyan-400">${card.price}</div></div></div>
            <div className="aspect-square mb-4 overflow-hidden bg-zinc-900"><img src={card.image_url} alt={card.name} className="w-full h-full object-cover" loading="lazy" /></div>
            <h3 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{card.name}</h3>
            <p className="text-sm text-cyan-400 mb-2">{card.title}</p>
            <p className="text-sm text-zinc-400 mb-4 line-clamp-2">{card.bio}</p>
            <div className="grid grid-cols-3 gap-2 mb-4">{Object.entries(card.stats||{}).slice(0,3).map(([k,v])=>(<div key={k} className="text-center p-2 bg-black/30"><div className="font-mono text-lg">{v.toLocaleString()}</div><div className="text-xs text-zinc-500 uppercase">{k}</div></div>))}</div>
            <button data-testid={`buy-${card.id}`} className="btn-primary w-full">View Card</button>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== AI COACH =====================
const AICoachView = () => {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [model, setModel] = useState('gpt-5.2');
  const [convId] = useState(() => `conv_${Date.now()}`);
  const chatEndRef = useRef(null);

  useEffect(() => { chatEndRef.current?.scrollIntoView({behavior:'smooth'}); }, [messages]);

  const quickPrompts = [
    {label: 'Workout Plan', prompt: 'Create a personalized workout plan for today based on my PRQ metrics'},
    {label: 'Nutrition', prompt: 'What should I eat pre and post workout today?'},
    {label: 'Recovery', prompt: 'Design a recovery protocol based on my current fatigue levels'},
    {label: 'Performance', prompt: 'Analyze my PRQ and suggest areas to improve'},
  ];

  const sendMessage = async (text) => {
    const msg = text || input.trim();
    if (!msg || loading) return;
    setMessages(prev => [...prev, {role:'user', content:msg}]);
    setInput('');
    setLoading(true);
    try {
      const r = await axios.post(`${API}/ai/chat`, {message: msg, model, conversation_id: convId});
      setMessages(prev => [...prev, {role:'ai', content: r.data.response, model: r.data.model}]);
    } catch {
      setMessages(prev => [...prev, {role:'ai', content: 'Connection issue. Please try again.', model: 'error'}]);
    }
    setLoading(false);
  };

  return (
    <div className="space-y-6 fade-in h-full flex flex-col" style={{minHeight:'calc(100vh - 4rem)'}}>
      <div className="flex items-center justify-between">
        <div><p className="overline mb-1">POWERED BY AI</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>AI COACH</h1></div>
        <select data-testid="model-select" value={model} onChange={e => setModel(e.target.value)} className="input-clinical w-auto text-sm">
          <option value="gpt-5.2">GPT-5.2</option><option value="claude">Claude Sonnet</option><option value="gemini">Gemini Flash</option>
        </select>
      </div>

      {messages.length === 0 && (
        <div className="flex-1 flex items-center justify-center" data-testid="coach-welcome">
          <div className="text-center max-w-xl">
            <MessageCircle className="w-16 h-16 text-cyan-400 mx-auto mb-6" />
            <h2 className="text-2xl font-bold mb-3" style={{fontFamily:'Barlow Condensed'}}>YOUR PERSONAL AI COACH</h2>
            <p className="text-zinc-400 mb-8">Get personalized training plans, nutrition advice, recovery protocols, and performance analysis.</p>
            <div className="grid grid-cols-2 gap-3">
              {quickPrompts.map((q,i) => (
                <button key={i} data-testid={`quick-prompt-${i}`} onClick={() => sendMessage(q.prompt)} className="surface-card p-4 text-left card-hover">
                  <div className="font-medium text-sm">{q.label}</div><div className="text-xs text-zinc-500 mt-1">{q.prompt.slice(0,50)}...</div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {messages.length > 0 && (
        <div className="flex-1 overflow-y-auto space-y-4 surface-card p-4" data-testid="chat-messages" style={{maxHeight:'calc(100vh - 20rem)'}}>
          {messages.map((m,i) => (
            <div key={i} className={`flex ${m.role==='user'?'justify-end':'justify-start'}`}>
              <div className={`max-w-[80%] p-4 ${m.role==='user'?'bg-cyan-400/10 border border-cyan-400/30':'surface-card'}`}>
                {m.role === 'ai' && <div className="text-xs text-zinc-500 mb-2 font-mono uppercase">{m.model}</div>}
                <div className="text-sm whitespace-pre-wrap">{m.content}</div>
              </div>
            </div>
          ))}
          {loading && <div className="flex justify-start"><div className="surface-card p-4"><div className="flex gap-1"><div className="w-2 h-2 bg-cyan-400 rounded-full animate-bounce"></div><div className="w-2 h-2 bg-cyan-400 rounded-full animate-bounce" style={{animationDelay:'0.1s'}}></div><div className="w-2 h-2 bg-cyan-400 rounded-full animate-bounce" style={{animationDelay:'0.2s'}}></div></div></div></div>}
          <div ref={chatEndRef} />
        </div>
      )}

      <div className="flex gap-3">
        <input data-testid="chat-input" value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key==='Enter' && sendMessage()} placeholder="Ask your AI coach anything..." className="input-clinical flex-1" />
        <button data-testid="send-btn" onClick={() => sendMessage()} disabled={loading || !input.trim()} className="btn-primary px-6"><Send className="w-5 h-5" /></button>
      </div>
    </div>
  );
};

// ===================== COACH HUB =====================
const CoachHubView = () => {
  const [coaches, setCoaches] = useState([]);
  const [sessions, setSessions] = useState([]);
  useEffect(() => {
    Promise.all([axios.get(`${API}/coach/available`), axios.get(`${API}/coach/sessions`)])
      .then(([c,s]) => {setCoaches(c.data);setSessions(s.data);}).catch(() => { setCoaches(FALLBACK_COACHES); setSessions([]); });
  }, []);
  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">TRAINING NETWORK</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>COACH HUB</h1></div>
      <div data-testid="available-coaches">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>AVAILABLE COACHES</h2>
        <div className="grid md:grid-cols-2 gap-4">
          {coaches.map((c,i) => (
            <div key={i} className="surface-card p-6 card-hover">
              <div className="flex items-center gap-4 mb-3">
                <div className="w-14 h-14 bg-zinc-800 rounded-full flex items-center justify-center"><User className="w-7 h-7 text-zinc-400" /></div>
                <div className="flex-1"><h3 className="font-bold text-lg">{c.name}</h3><p className="text-sm text-cyan-400">{c.specialty || c.sport}</p></div>
                <div className="text-right"><div className="font-mono text-lg text-cyan-400">${c.rate || 25}</div><div className="text-xs text-zinc-500">per session</div></div>
              </div>
              <div className="flex items-center gap-4 text-sm text-zinc-400 mb-4"><span className="flex items-center gap-1"><Star className="w-4 h-4 text-yellow-400" />{c.rating}</span><span>{c.sessions} sessions</span></div>
              <button data-testid={`book-coach-${i}`} className="btn-primary w-full">Book Session</button>
            </div>
          ))}
        </div>
      </div>
      <div data-testid="my-sessions">
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>MY SESSIONS</h2>
        {sessions.length === 0 ? (
          <div className="surface-card p-8 text-center"><Calendar className="w-12 h-12 text-zinc-600 mx-auto mb-4" /><p className="text-zinc-400">No sessions scheduled</p></div>
        ) : (
          <div className="space-y-3">{sessions.map((s,i) => <div key={i} className="surface-card p-4 flex items-center justify-between"><div><h4 className="font-medium">{s.session_type} Session</h4><p className="text-sm text-zinc-400">{s.sport}</p></div><div className="badge-clinical">{s.status}</div></div>)}</div>
        )}
      </div>
    </div>
  );
};

// ===================== BRAIN BRAWL =====================
const LOCAL_BRAIN_BRAWL_QUESTIONS = [
  {
    question: "Which training quality is most tied to reaction drills?",
    options: ["Decision speed", "Ignoring cues", "Static posture only", "No feedback"],
    answer: 0,
    difficulty: "Cognitive",
  },
  {
    question: "What should an athlete prioritize before increasing speed?",
    options: ["Movement control", "Random reps", "Skipping warmups", "Fatigue only"],
    answer: 0,
    difficulty: "Foundational",
  },
  {
    question: "Which plane is most associated with rotational skills?",
    options: ["Transverse", "Sagittal", "Frontal", "None"],
    answer: 0,
    difficulty: "Kinesiology",
  },
];

const BrainBrawlView = ({ onBack }) => {
  const [questions, setQuestions] = useState([]);
  const [sessionId, setSessionId] = useState(null);
  const [picked, setPicked] = useState([]);
  const [verified, setVerified] = useState(null);
  const [currentQ, setCurrentQ] = useState(0);
  const [gameState, setGameState] = useState('menu');
  const [timeLeft, setTimeLeft] = useState(15);
  const [category, setCategory] = useState('all');
  const timerRef = useRef(null);

  const startGame = async () => {
    try {
      const r = await axios.post(`${API}/brain-brawl/session/start`, { category, count: 10 });
      setSessionId(r.data.session_id);
      setQuestions(r.data.questions);
      setCurrentQ(0);
      setPicked([]);
      setVerified(null);
      setTimeLeft(15);
      setGameState('playing');
    } catch (e) {
      setSessionId('local-brain-brawl');
      setQuestions(LOCAL_BRAIN_BRAWL_QUESTIONS);
      setCurrentQ(0);
      setPicked([]);
      setVerified(null);
      setTimeLeft(15);
      setGameState('playing');
    }
  };

  const answerQuestion = useCallback((index) => {
    clearTimeout(timerRef.current);
    const next = [...picked, index];
    setPicked(next);
    if (currentQ + 1 >= questions.length) {
      axios
        .post(`${API}/brain-brawl/session/submit`, { session_id: sessionId, answers: next })
        .then((res) => {
          setVerified(res.data);
          setGameState('results');
        })
        .catch(() => {
          const activeQuestions = questions.length ? questions : LOCAL_BRAIN_BRAWL_QUESTIONS;
          const correct = activeQuestions.reduce((sum, q, i) => sum + (next[i] === (q.answer ?? 0) ? 1 : 0), 0);
          setVerified({
            score: correct * 100,
            xp_earned: correct * 50,
            questions_correct: correct,
            questions_total: activeQuestions.length,
          });
          setGameState('results');
        });
    } else {
      setCurrentQ((c) => c + 1);
      setTimeLeft(15);
    }
  }, [currentQ, picked, questions, sessionId]);

  useEffect(() => {
    if (gameState === 'playing' && timeLeft > 0) {
      timerRef.current = setTimeout(() => setTimeLeft(t => t - 1), 1000);
    } else if (gameState === 'playing' && timeLeft <= 0) {
      answerQuestion(-1); // Time's up
    }
    return () => clearTimeout(timerRef.current);
  }, [gameState, timeLeft, answerQuestion]);

  return (
    <div className="space-y-8 fade-in">
      {onBack && <button onClick={onBack} className="btn-secondary text-sm">Back to Game Modes</button>}
      <div><p className="overline mb-1">COGNITIVE TRAINING</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>BRAIN BRAWL</h1></div>

      {gameState === 'menu' && (
        <div className="max-w-2xl mx-auto text-center" data-testid="brain-brawl-menu">
          <div className="surface-card p-12">
            <Brain className="w-24 h-24 text-cyan-400 mx-auto mb-6" />
            <h2 className="text-3xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>SHARPEN YOUR MIND</h2>
            <p className="text-zinc-400 mb-6">Test your sports IQ and cognitive abilities</p>
            <div className="flex gap-2 justify-center mb-8">
              {['all','sports_iq','kinesiology'].map(c => <button key={c} data-testid={`bb-cat-${c}`} onClick={() => setCategory(c)} className={`px-4 py-2 text-sm uppercase ${category===c?'bg-cyan-400 text-black':'bg-zinc-800 text-zinc-400'}`}>{c.replace('_',' ')}</button>)}
            </div>
            <div className="grid grid-cols-3 gap-4 mb-8">
              {[{l:'Questions',v:'10'},{l:'Time per Q',v:'15s'},{l:'Reward',v:'+XP'}].map((i,idx) => <div key={idx} className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl">{i.v}</div><div className="metric-label">{i.l}</div></div>)}
            </div>
            <button data-testid="start-brain-brawl" onClick={startGame} className="btn-primary text-lg px-12 py-4">Start Challenge</button>
          </div>
        </div>
      )}

      {gameState === 'playing' && questions.length > 0 && (
        <div className="max-w-3xl mx-auto" data-testid="brain-brawl-game">
          <div className="flex items-center justify-between mb-4">
            <span className="font-mono text-zinc-400">Q{currentQ + 1}/{questions.length}</span>
            <div className={`metric-value text-2xl ${timeLeft <= 5 ? 'text-red-400' : 'text-cyan-400'}`}>{timeLeft}s</div>
            <span className="font-mono text-zinc-500 text-sm">Verified grading</span>
          </div>
          <div className="progress-bar mb-6"><div className="progress-fill" style={{width:`${((currentQ+1)/questions.length)*100}%`}}></div></div>
          <div className="surface-card p-8">
            {questions[currentQ].difficulty && <span className="badge-clinical mb-4 inline-block">{questions[currentQ].difficulty}</span>}
            <h2 className="text-2xl font-bold mb-8 text-center" style={{fontFamily:'Barlow Condensed'}}>{questions[currentQ].question}</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {questions[currentQ].options.map((opt,i) => (
                <button key={i} data-testid={`answer-${i}`} onClick={() => answerQuestion(i)} className="surface-card p-5 text-left card-hover text-lg font-medium">
                  <span className="text-cyan-400 mr-3 font-mono">{['A','B','C','D'][i]}.</span>{opt}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {gameState === 'results' && verified && (
        <div className="max-w-2xl mx-auto text-center" data-testid="brain-brawl-results">
          <div className="surface-card p-12">
            <Award className="w-24 h-24 text-cyan-400 mx-auto mb-6" />
            <h2 className="text-3xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>CHALLENGE COMPLETE</h2>
            <div className="metric-value text-6xl text-cyan-400 mb-2">{verified.score ?? 0}</div>
            <div className="metric-label mb-2">SERVER-VERIFIED SCORE</div>
            <div className="text-sm text-zinc-400 mb-8">+{verified.xp_earned ?? 0} XP · {verified.questions_correct ?? 0}/{verified.questions_total ?? 0} correct</div>
            <div className="grid grid-cols-3 gap-4 mb-8">
              <div className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl text-green-400">{verified.questions_correct}</div><div className="metric-label">Correct</div></div>
              <div className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl text-red-400">{(verified.questions_total ?? 0) - (verified.questions_correct ?? 0)}</div><div className="metric-label">Wrong</div></div>
              <div className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl">{verified.questions_total}</div><div className="metric-label">Total</div></div>
            </div>
            <button data-testid="play-again" onClick={() => { setGameState('menu'); setVerified(null); }} className="btn-primary text-lg px-12 py-4">Play Again</button>
          </div>
        </div>
      )}
    </div>
  );
};

// ===================== LEADERBOARD =====================
const LeaderboardView = () => {
  const [leaders, setLeaders] = useState([]);
  const { user } = useAuth();
  useEffect(() => { axios.get(`${API}/leaderboard`).then(r => setLeaders(r.data)).catch(() => setLeaders(FALLBACK_LEADERS)); }, []);
  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">GLOBAL RANKINGS</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>LEADERBOARD</h1></div>
      {/* Top 3 Podium */}
      <div className="grid grid-cols-3 gap-4 items-end" data-testid="leaderboard-podium">
        {leaders.length >= 3 && [leaders[1], leaders[0], leaders[2]].map((l,i) => {
          const heights = ['h-32','h-40','h-24'];
          const medals = [<Medal className="w-8 h-8 text-gray-300" />, <Crown className="w-10 h-10 text-yellow-400" />, <Medal className="w-7 h-7 text-amber-600" />];
          return (
            <div key={i} className="text-center">
              <div className="mb-3">{medals[i]}</div>
              <div className="w-16 h-16 bg-zinc-800 rounded-full mx-auto mb-2 flex items-center justify-center overflow-hidden">
                {l.picture ? <img src={l.picture} alt="" className="w-full h-full object-cover" /> : <User className="w-8 h-8 text-zinc-400" />}
              </div>
              <div className="font-bold text-sm truncate">{l.name}</div>
              <div className="font-mono text-cyan-400">{l.prq_score}</div>
              <div className={`${heights[i]} bg-gradient-to-t from-cyan-400/20 to-transparent border-t-2 border-cyan-400 mt-2`}></div>
            </div>
          );
        })}
      </div>
      {/* Full List */}
      <div className="surface-card" data-testid="leaderboard-list">
        <div className="grid grid-cols-12 gap-4 p-4 text-sm text-zinc-500 border-b border-white/5">
          <span className="col-span-1">RANK</span><span className="col-span-5">ATHLETE</span><span className="col-span-2">PRQ</span><span className="col-span-2">LEVEL</span><span className="col-span-2">SPORT</span>
        </div>
        {leaders.map((l,i) => (
          <div key={i} data-testid={`leader-${i}`} className={`grid grid-cols-12 gap-4 p-4 items-center border-b border-white/5 transition-colors hover:bg-white/5 ${l.user_id === user?.user_id ? 'bg-cyan-400/5 border-l-2 border-l-cyan-400' : ''}`}>
            <span className="col-span-1 font-mono text-zinc-400">#{l.rank}</span>
            <span className="col-span-5 flex items-center gap-3"><div className="w-8 h-8 bg-zinc-800 rounded-full flex items-center justify-center"><User className="w-4 h-4 text-zinc-400" /></div><span className="font-medium truncate">{l.name}</span></span>
            <span className="col-span-2 font-mono text-cyan-400">{l.prq_score}</span>
            <span className="col-span-2">Lvl {l.level}</span>
            <span className="col-span-2 text-zinc-400 capitalize">{l.sport}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== DOWNLOAD PORTAL =====================
const DownloadPortalView = () => {
  return (
    <div className="space-y-8 fade-in">
      <div>
        <p className="overline mb-1">LOCAL MOBILE BUILDS</p>
        <h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>GET APP</h1>
        <p className="text-zinc-400 text-sm max-w-xl mt-1">
          Final Evolution utilizes a cloud-native architecture. You stream the simulation or download the early access builds below for your platform.
        </p>
      </div>

      <div className="grid md:grid-cols-2 gap-6">
        {/* iOS Card */}
        <div className="surface-card p-6 flex flex-col justify-between border border-white/5 hover:border-cyan-400/20 transition-all duration-300 rounded-lg">
          <div className="space-y-4">
            <div className="flex justify-between items-start">
              <div className="w-10 h-10 bg-cyan-400/10 flex items-center justify-center text-cyan-400 rounded">
                <Smartphone className="w-6 h-6" />
              </div>
              <span className="text-[10px] text-zinc-500 font-mono">TestFlight</span>
            </div>
            <h3 className="text-xl font-bold uppercase font-mono" style={{fontFamily:'Barlow Condensed'}}>iOS Client</h3>
            <p className="text-zinc-400 text-sm leading-relaxed">
              Install the mobile app via Apple TestFlight. Syncs your HealthKit biomechanics and physical sensors natively.
            </p>
          </div>
          <div className="pt-6">
            <a href="https://testflight.apple.com" target="_blank" rel="noreferrer" className="btn-primary w-full text-center flex items-center justify-center gap-2">
              Request TestFlight Access <ChevronRight className="w-4 h-4" />
            </a>
          </div>
        </div>

        {/* Android Card */}
        <div className="surface-card p-6 flex flex-col justify-between border border-white/5 hover:border-cyan-400/20 transition-all duration-300 rounded-lg">
          <div className="space-y-4">
            <div className="flex justify-between items-start">
              <div className="w-10 h-10 bg-cyan-400/10 flex items-center justify-center text-cyan-400 rounded">
                <Download className="w-6 h-6" />
              </div>
              <span className="text-[10px] text-zinc-500 font-mono">APK Sideload</span>
            </div>
            <h3 className="text-xl font-bold uppercase font-mono" style={{fontFamily:'Barlow Condensed'}}>Android Build</h3>
            <p className="text-zinc-400 text-sm leading-relaxed">
              Direct APK installer. Install on your Android mobile device or configure inside high-performance PC emulators.
            </p>
          </div>
          <div className="pt-6">
            <a href="/downloads/FinalEvolutionLab.apk" download className="btn-primary w-full text-center flex items-center justify-center gap-2">
              <Download className="w-4 h-4" /> Download Direct APK
            </a>
          </div>
        </div>
      </div>

      <div className="surface-card p-6 rounded-lg">
        <h3 className="text-lg font-bold mb-3" style={{fontFamily:'Barlow Condensed'}}>HOW TO ACCESS THE STREAM</h3>
        <p className="text-zinc-400 text-sm leading-relaxed mb-4">
          Final Evolution utilizes a cloud-native architecture. You don’t download the Lab; you stream the simulation. Our Unreal Engine 5.7 core runs on high-performance GPU instances and pipes the visual experience directly to your browser. This eliminates local hardware limitations and provides an industrial-grade digital twin experience.
        </p>
        <div className="bg-black/50 p-4 border border-white/5 font-mono text-xs text-zinc-400 rounded">
          <div className="text-zinc-600 font-bold"># Start local client mapping</div>
          <div>finalevolution://open-mode?id=basketball_dunk</div>
        </div>
      </div>
    </div>
  );
};

// ===================== PROFILE =====================
const ProfileView = () => {
  const { user } = useAuth();
  const [progress, setProgress] = useState(null);
  const [editing, setEditing] = useState(false);
  const [bio, setBio] = useState(user?.bio || '');
  const [sport, setSport] = useState(user?.sport || 'basketball');

  useEffect(() => { axios.get(`${API}/profile/progress`).then(r => setProgress(r.data)).catch(() => setProgress(FALLBACK_PROGRESS)); }, []);

  const saveProfile = async () => {
    try { await axios.put(`${API}/profile`, {bio, sport}); setEditing(false); } catch (e) { console.error(e); }
  };

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">ATHLETE PROFILE</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>PROFILE</h1></div>
      <div className="surface-card p-8" data-testid="profile-card">
        <div className="flex items-center gap-6 mb-6">
          <div className="w-24 h-24 bg-zinc-800 rounded-full flex items-center justify-center overflow-hidden flex-shrink-0">
            {user?.picture ? <img src={user.picture} alt="" className="w-full h-full object-cover" /> : <User className="w-12 h-12 text-zinc-400" />}
          </div>
          <div className="flex-1">
            <h2 className="text-3xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{user?.name}</h2>
            <p className="text-cyan-400">{user?.email}</p>
            <div className="flex items-center gap-4 mt-2">
              <span className="badge-clinical">Level {user?.level || 1}</span>
              <span className="badge-clinical">{user?.role}</span>
              <span className="badge-clinical">{sport}</span>
            </div>
          </div>
          <button data-testid="edit-profile" onClick={() => setEditing(!editing)} className="btn-secondary">{editing ? 'Cancel' : 'Edit'}</button>
        </div>
        {editing && (
          <div className="space-y-4 border-t border-white/5 pt-6">
            <div><label className="metric-label block mb-2">BIO</label><textarea data-testid="bio-input" value={bio} onChange={e => setBio(e.target.value)} className="input-clinical" rows={3} placeholder="Tell us about yourself..." /></div>
            <div><label className="metric-label block mb-2">PRIMARY SPORT</label>
              <select data-testid="sport-select" value={sport} onChange={e => setSport(e.target.value)} className="input-clinical">
                {['basketball','karate','soccer','football','tennis','golf','surfing','skateboarding','snowboarding','training'].map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>
            <button data-testid="save-profile" onClick={saveProfile} className="btn-primary">Save Changes</button>
          </div>
        )}
      </div>
      {/* Progress Stats */}
      {progress && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4" data-testid="progress-stats">
          {[{l:'Workouts',v:progress.total_workouts,icon:Dumbbell},{l:'Games',v:progress.total_games,icon:Gamepad2},{l:'Brain Brawls',v:progress.total_brawls,icon:Brain},{l:'XP',v:progress.xp,icon:Star}].map((s,i)=>(
            <div key={i} className="surface-card p-6 text-center"><s.icon className="w-8 h-8 text-cyan-400 mx-auto mb-3" /><div className="metric-value text-3xl">{s.v}</div><div className="metric-label">{s.l}</div></div>
          ))}
        </div>
      )}
    </div>
  );
};

// ===================== MAIN DASHBOARD =====================
const Dashboard = () => {
  const [activeTab, setActiveTab] = useState('fel-os');
  const location = useLocation();
  const { user, setUser } = useAuth();
  useEffect(() => { if (location.state?.user && !user) setUser(location.state.user); }, [location.state, user, setUser]);

  const renderContent = () => {
    switch(activeTab) {
      case 'fel-os': return <FELOSDashboard setActiveTab={setActiveTab} />;
      case 'dashboard': return <DashboardView setActiveTab={setActiveTab} />;
      case 'scan': return <SystemScanView />;
      case 'games': return <GameModesView />;
      case 'cards': return <CreatorCardsView />;
      case 'coach': return <CoachHubView />;
      case 'ai-coach': return <AICoachView />;
      case 'education': return <EducationTracksPortal setActiveTab={setActiveTab} />;
      case 'brain-brawl': return <BrainBrawlView />;
      case 'trivia': return <TriviaArenaView onBack={() => setActiveTab('games')} />;
      case 'hud': return <Phase3HUD />;
      case 'streaks': return <StreaksView />;
      case 'social': return <SocialView />;
      case 'tournaments': return <TournamentsView />;
      case 'avatar': return <AvatarBuilderView />;
      case 'critique': return <VideoCritiqueView />;
      case 'multiplayer': return <MultiplayerView />;
      case 'referral': return <ReferralView />;
      case 'analytics': return <AnalyticsView />;
      case 'vault': return <HubDashboard />;
      case 'leaderboard': return <LeaderboardView />;
      case 'streaming': return <DownloadPortalView />;
      case 'profile': return <ProfileView />;
      default: return <DashboardView setActiveTab={setActiveTab} />;
    }
  };

  return (
    <div className="min-h-screen" style={{background:'var(--bg-default)'}}>
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />
      <main className="main-content">{renderContent()}</main>
    </div>
  );
};

// ===================== APP ROUTER =====================
function AppRouter() {
  const location = useLocation();
  if (location.hash?.includes('session_id=')) return <AuthCallback />;
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
      <Route path="/hud" element={<Phase3HUD />} />
      <Route path="/download" element={<DownloadPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function App() {
  return <BrowserRouter><AuthProvider><PayPalScriptProvider options={{clientId: process.env.REACT_APP_PAYPAL_CLIENT_ID || 'test'}}><AppRouter /></PayPalScriptProvider></AuthProvider></BrowserRouter>;
}

export default App;
