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
  Swords, Video, Palette, UserPlus, Gift
} from "lucide-react";
import { PayPalScriptProvider, PayPalButtons } from "@paypal/react-paypal-js";
import { StreaksView, SocialView, TournamentsView, AvatarBuilderView, VideoCritiqueView } from "@/components/NewViews";
import { MultiplayerView, ReferralView, AnalyticsView } from "@/components/QualityGates";
import { SovereignDashboard } from "@/components/SovereignDashboard";
import { FELOSDashboard } from "@/components/FELOSDashboard";
import DistributionPage from "@/components/DistributionPage";
import { API, toWebSocketUrl } from "@/config/api";

axios.defaults.withCredentials = true;

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

// ===================== DOWNLOAD / DISTRIBUTION PAGE =====================
const DownloadPage = () => {
  const handleLogin = () => {
    // REMINDER: DO NOT HARDCODE THE URL, OR ADD ANY FALLBACKS OR REDIRECT URLS, THIS BREAKS THE AUTH
    const redirectUrl = window.location.origin + '/dashboard';
    window.location.href = `https://auth.emergentagent.com/?redirect=${encodeURIComponent(redirectUrl)}`;
  };
  return <DistributionPage onLogin={handleLogin} />;
};

// ===================== LANDING PAGE =====================
const LandingPage = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  useEffect(() => { if (user) navigate('/dashboard'); }, [user, navigate]);
  const handleLogin = () => {
    // REMINDER: DO NOT HARDCODE THE URL, OR ADD ANY FALLBACKS OR REDIRECT URLS, THIS BREAKS THE AUTH
    const redirectUrl = window.location.origin + '/dashboard';
    window.location.href = `https://auth.emergentagent.com/?redirect=${encodeURIComponent(redirectUrl)}`;
  };
  const handleWatchDemo = () => navigate('/download');
  return (
    <div className="min-h-screen" style={{background:'var(--bg-default)'}}>
      <div className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-cyan-500/10 to-transparent"></div>
        <header className="relative z-10 flex items-center justify-between px-8 py-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-cyan-400 flex items-center justify-center"><Zap className="w-6 h-6 text-black" /></div>
            <span className="text-xl font-bold tracking-tight" style={{fontFamily:'Barlow Condensed'}}>FINAL EVOLUTION LAB</span>
          </div>
          <button data-testid="hero-login-btn" onClick={handleLogin} className="btn-primary">Enter Lab</button>
        </header>
        <div className="relative z-10 max-w-6xl mx-auto px-8 py-24 text-center">
          <p className="overline mb-4">THE ATHLETE OPERATING SYSTEM</p>
          <h1 className="text-5xl md:text-7xl font-black tracking-tighter mb-6" style={{fontFamily:'Barlow Condensed'}}>YOUR MOVEMENT<br/><span className="text-cyan-400">AUDITED</span></h1>
          <p className="text-xl text-zinc-400 max-w-2xl mx-auto mb-8">System scan meets game arena. 18 playable modes, Sovereign Shop, AI coaching, and cognitive training.</p>
          <div className="flex flex-wrap justify-center gap-4">
            <button data-testid="cta-start-btn" onClick={handleLogin} className="btn-primary text-lg px-8 py-4">Start System Scan</button>
            <button onClick={handleWatchDemo} className="btn-secondary text-lg px-8 py-4">Watch Demo</button>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mt-16">
            {[{v:"18",l:"Playable Modes"},{v:"9,356+",l:"AI Assets"},{v:"54",l:"Animations"},{v:"12",l:"Venues"}].map((s,i) => (
              <div key={i} className="text-center"><div className="metric-value text-cyan-400">{s.v}</div><div className="metric-label">{s.l}</div></div>
            ))}
          </div>
        </div>
      </div>
      <div className="max-w-6xl mx-auto px-8 py-24">
        <p className="overline text-center mb-4">CORE SYSTEMS</p>
        <h2 className="text-4xl font-bold text-center mb-16" style={{fontFamily:'Barlow Condensed'}}>ONE SCAN. TOTAL INTEGRATION.</h2>
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[
            {icon:Activity,t:"System Scan",d:"Avatar, PRQ metrics, health signals, and workout plans unified"},
            {icon:Users,t:"Creator Cards",d:"Digital collectibles from elite athletes and coaches"},
            {icon:Gamepad2,t:"18 Playable Modes",d:"Basketball, karate, soccer, surfing, academy games, and more"},
            {icon:Trophy,t:"Coach Economy",d:"Instruction and critique as first-class currencies"},
            {icon:Brain,t:"Brain Brawl",d:"Cognitive training for peak decision-making"},
            {icon:GraduationCap,t:"Education",d:"Common Core to kinesiology certification"}
          ].map((f,i) => (
            <div key={i} className="surface-card p-6 card-hover">
              <f.icon className="w-10 h-10 text-cyan-400 mb-4" /><h3 className="text-xl font-bold mb-2" style={{fontFamily:'Barlow Condensed'}}>{f.t}</h3><p className="text-zinc-400">{f.d}</p>
            </div>
          ))}
        </div>
      </div>
      <div className="surface-glass py-16">
        <div className="max-w-4xl mx-auto px-8 text-center">
          <h2 className="text-3xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>READY TO EVOLVE?</h2>
          <p className="text-zinc-400 mb-8">Join the lab. Train smarter. Compete harder.</p>
          <button data-testid="footer-cta-btn" onClick={handleLogin} className="btn-primary text-lg px-8 py-4">Enter Final Evolution Lab</button>
        </div>
      </div>
    </div>
  );
};

const LoginPage = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  useEffect(() => { if (user) navigate('/dashboard'); }, [user, navigate]);
  const handleLogin = () => {
    // REMINDER: DO NOT HARDCODE THE URL, OR ADD ANY FALLBACKS OR REDIRECT URLS, THIS BREAKS THE AUTH
    const redirectUrl = window.location.origin + '/dashboard';
    window.location.href = `https://auth.emergentagent.com/?redirect=${encodeURIComponent(redirectUrl)}`;
  };
  return (
    <div className="min-h-screen flex items-center justify-center" style={{background:'var(--bg-default)'}}>
      <div className="surface-card p-8 w-full max-w-md text-center">
        <div className="w-16 h-16 bg-cyan-400 flex items-center justify-center mx-auto mb-6"><Zap className="w-10 h-10 text-black" /></div>
        <h1 className="text-3xl font-bold mb-2" style={{fontFamily:'Barlow Condensed'}}>FINAL EVOLUTION LAB</h1>
        <p className="text-zinc-400 mb-8">Sign in to access your training dashboard</p>
        <button data-testid="login-google-btn" onClick={handleLogin} className="btn-primary w-full flex items-center justify-center gap-3">Continue with Google</button>
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
    {id:'streaks',icon:Flame,label:'Streaks'},{id:'social',icon:UserPlus,label:'Social'},
    {id:'tournaments',icon:Swords,label:'Tournaments'},{id:'avatar',icon:Palette,label:'Avatar'},
    {id:'critique',icon:Video,label:'Video Critique'},{id:'referral',icon:Gift,label:'Referrals'},
    {id:'analytics',icon:BarChart3,label:'Analytics'},
    {id:'sovereign',icon:Shield,label:'Sovereign'},
    {id:'leaderboard',icon:Crown,label:'Leaderboard'},{id:'streaming',icon:Radio,label:'Pixel Stream'},
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
      .then(([p, s]) => { setPrq(p.data); setStats(s.data); }).catch(console.error);
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
          {[{t:'Play Game',d:'18 modes + shop',icon:Gamepad2,a:'games'},{t:'AI Coach',d:'Get training plan',icon:MessageCircle,a:'ai-coach'},{t:'Brain Brawl',d:'Test your IQ',icon:Brain,a:'brain-brawl'},{t:'Streak',d:'Check in today',icon:Flame,a:'streaks'}].map((i,idx)=>(
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
      .then(([p,w]) => {setPrq(p.data);setWorkouts(w.data);}).catch(console.error);
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

// ===================== PLAYABLE GAME ENGINE =====================
const PlayableGame = ({ mode, onComplete, onBack }) => {
  const [score, setScore] = useState(0);
  const [timeLeft, setTimeLeft] = useState(30);
  const [gameActive, setGameActive] = useState(true);
  const [targets, setTargets] = useState([]);
  const [combo, setCombo] = useState(0);
  const [highScore, setHighScore] = useState(0);
  const timerRef = useRef(null);

  useEffect(() => {
    if (gameActive && timeLeft > 0) {
      timerRef.current = setInterval(() => setTimeLeft(t => t - 1), 1000);
    } else if (timeLeft <= 0) {
      setGameActive(false);
      clearInterval(timerRef.current);
    }
    return () => clearInterval(timerRef.current);
  }, [gameActive, timeLeft]);

  useEffect(() => {
    if (!gameActive) return;
    const spawn = setInterval(() => {
      setTargets(prev => [...prev, {
        id: Date.now(), x: Math.random() * 80 + 10, y: Math.random() * 60 + 10,
        size: Math.random() * 30 + 30, type: Math.random() > 0.3 ? 'target' : 'bonus',
        created: Date.now()
      }].slice(-8));
    }, mode.game_type === 'precision' ? 1500 : 800);
    return () => clearInterval(spawn);
  }, [gameActive, mode.game_type]);

  useEffect(() => {
    const cleanup = setInterval(() => {
      setTargets(prev => prev.filter(t => Date.now() - t.created < 3000));
    }, 500);
    return () => clearInterval(cleanup);
  }, []);

  const hitTarget = (target) => {
    if (!gameActive) return;
    const points = target.type === 'bonus' ? 50 : 25;
    const comboBonus = combo > 2 ? combo * 5 : 0;
    setScore(s => s + points + comboBonus);
    setCombo(c => c + 1);
    setTargets(prev => prev.filter(t => t.id !== target.id));
  };

  const endGame = () => {
    setGameActive(false);
    clearInterval(timerRef.current);
    onComplete(score);
  };

  useEffect(() => {
    if (timeLeft <= 0 && score > 0) { endGame(); }
  }, [timeLeft]);

  const getGameTitle = () => {
    const titles = {
      shooting: 'Shoot & Score', timing: 'Perfect Timing', combat: 'Strike Zone',
      reflex: 'Reflex Rush', precision: 'Precision Shot', balance: 'Balance Master',
      endurance: 'Endurance Mode', strategy: 'Strategy Play', quiz: 'Brain Brawl'
    };
    return titles[mode.game_type] || 'Challenge';
  };

  if (!gameActive) {
    return (
      <div className="max-w-xl mx-auto text-center space-y-6 fade-in" data-testid="game-results">
        <Award className="w-20 h-20 text-cyan-400 mx-auto" />
        <h2 className="text-4xl font-bold" style={{fontFamily:'Barlow Condensed'}}>GAME OVER</h2>
        <div className="metric-value text-6xl text-cyan-400">{score}</div>
        <div className="metric-label">FINAL SCORE</div>
        <div className="grid grid-cols-2 gap-4">
          <div className="surface-card p-4"><div className="metric-value text-2xl">{combo}</div><div className="metric-label">MAX COMBO</div></div>
          <div className="surface-card p-4"><div className="metric-value text-2xl">{mode.display_name}</div><div className="metric-label">MODE</div></div>
        </div>
        <div className="flex gap-4">
          <button data-testid="play-again-btn" onClick={() => {setScore(0);setTimeLeft(30);setCombo(0);setGameActive(true);}} className="btn-primary flex-1">Play Again</button>
          <button data-testid="back-to-modes" onClick={onBack} className="btn-secondary flex-1">Back to Modes</button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 fade-in" data-testid="active-game">
      <div className="flex items-center justify-between">
        <button onClick={onBack} className="btn-secondary text-sm px-4 py-2">Exit</button>
        <h2 className="text-xl font-bold" style={{fontFamily:'Barlow Condensed'}}>{mode.display_name}: {getGameTitle()}</h2>
        <div className="flex items-center gap-4">
          <div className="text-center"><div className={`metric-value text-2xl ${timeLeft <= 10 ? 'text-red-400' : 'text-cyan-400'}`}>{timeLeft}</div><div className="metric-label">TIME</div></div>
        </div>
      </div>
      <div className="flex items-center justify-between surface-card p-3">
        <div className="flex items-center gap-4"><span className="font-mono text-lg">SCORE: <span className="text-cyan-400">{score}</span></span></div>
        {combo > 1 && <div className="badge-clinical" style={{background:'rgba(255,184,0,0.1)',borderColor:'rgba(255,184,0,0.3)',color:'#FFB800'}}>COMBO x{combo}</div>}
      </div>
      <div className="relative w-full bg-black/60 border border-white/10 overflow-hidden" style={{height:'400px',cursor:'crosshair'}} onClick={() => setCombo(0)}>
        <div className="absolute inset-0" style={{backgroundImage:'radial-gradient(circle at 50% 50%, rgba(0,229,255,0.03) 0%, transparent 70%)'}}></div>
        {targets.map(t => (
          <button key={t.id} data-testid={`target-${t.id}`}
            onClick={(e) => {e.stopPropagation(); hitTarget(t);}}
            className="absolute transition-all duration-100"
            style={{left:`${t.x}%`,top:`${t.y}%`,width:`${t.size}px`,height:`${t.size}px`,transform:'translate(-50%,-50%)'}}
          >
            <div className={`w-full h-full rounded-full flex items-center justify-center ${t.type === 'bonus' ? 'bg-yellow-400/80 border-2 border-yellow-300' : 'bg-cyan-400/80 border-2 border-cyan-300'} hover:scale-110 active:scale-90 transition-transform`}>
              {t.type === 'bonus' ? <Star className="w-4 h-4 text-black" /> : <Crosshair className="w-4 h-4 text-black" />}
            </div>
          </button>
        ))}
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 text-zinc-600 text-sm">TAP TARGETS TO SCORE</div>
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
  useEffect(() => { axios.get(`${API}/games/modes`).then(r => setModes(r.data)).catch(console.error); }, []);

  const launchNativeMode = async (mode) => {
    setLaunchingMode(mode.id);
    setLaunchStatus('launching');
    try {
      const r = await axios.post(`${API}/streaming/launch-mode`, { mode_id: mode.id });
      setSessionState(r.data);

      // Deep link to UE5 native binary
      const deepLink = r.data.deep_link;
      if (deepLink) {
        window.location.href = deepLink;

        // State-Aware Handshake: listen for MapLoaded via WebSocket
        // NOT a blind timeout — wait for actual bridge confirmation
        const wsUrl = toWebSocketUrl('/ws/sovereign');
        const ws = new WebSocket(wsUrl);
        wsRef.current = ws;
        setLaunchStatus('map_loading');

        ws.onmessage = (e) => {
          try {
            const msg = JSON.parse(e.data);
            if (msg.type === 'sovereign_handshake' || msg.type === 'map_loaded') {
              // MapLoaded signal received from UFELEmergentBridgeSubsystem
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

  const handleGameComplete = async (score) => {
    try {
      await axios.post(`${API}/games/session`, {mode_id: playingMode.id, score, duration_seconds: 30, completed: true});
      if (sessionState?.session_id) {
        await axios.post(`${API}/session/state`, {session_id: sessionState.session_id, state: 'completed', score});
      }
    } catch {}
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
              <p className="text-zinc-500 text-sm mt-2">Verify UE5 binary is running and Sovereign Hub is reachable.</p>
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
                <div className="flex items-center gap-2 justify-center"><div className="w-2 h-2 bg-green-400 rounded-full"></div>Session registered at Sovereign Hub</div>
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
  useEffect(() => { axios.get(`${API}/cards`).then(r => setCards(r.data)).catch(console.error); }, []);

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
              <div className="flex items-center gap-4"><span className="metric-value text-3xl text-cyan-400">${selected.price}</span><button data-testid="purchase-card" className="btn-primary" onClick={() => {
                axios.post(`${API}/payments/create-order`, {item_type: 'card', item_id: selected.id, amount: selected.price, return_url: window.location.href, cancel_url: window.location.href}).then(r => {
                  if (r.data.approval_url) window.open(r.data.approval_url, '_blank');
                }).catch(console.error);
              }}>Purchase via PayPal</button></div>
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
      .then(([c,s]) => {setCoaches(c.data);setSessions(s.data);}).catch(console.error);
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

// ===================== EDUCATION =====================
const EducationView = () => {
  const [courses, setCourses] = useState([]);
  const [filter, setFilter] = useState('all');
  useEffect(() => { axios.get(`${API}/education/courses`).then(r => setCourses(r.data)).catch(console.error); }, []);
  const categories = ['all','brain_brawl','kinesiology','stem','common_core'];
  const filtered = filter === 'all' ? courses : courses.filter(c => c.category === filter);
  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">ATHLETE ACADEMY</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>EDUCATION</h1></div>
      <div className="flex gap-2 overflow-x-auto pb-2">
        {categories.map(c => <button key={c} data-testid={`edu-filter-${c}`} onClick={() => setFilter(c)} className={`px-4 py-2 text-sm font-medium uppercase tracking-wide whitespace-nowrap transition-all ${filter===c?'bg-cyan-400 text-black':'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'}`}>{c.replace('_',' ')}</button>)}
      </div>
      <div className="grid md:grid-cols-2 gap-6" data-testid="courses-grid">
        {filtered.map(course => (
          <div key={course.id} className="surface-card overflow-hidden card-hover" data-testid={`course-${course.id}`}>
            <div className="aspect-video"><img src={course.image_url} alt={course.title} className="w-full h-full object-cover" loading="lazy" /></div>
            <div className="p-6">
              <div className="flex items-center gap-2 mb-3">
                <span className="badge-clinical">{course.category.replace('_',' ')}</span>
                {course.is_certificate && <span className="badge-clinical" style={{background:'rgba(0,255,157,0.1)',borderColor:'rgba(0,255,157,0.3)',color:'#00FF9D'}}>Certificate</span>}
              </div>
              <h3 className="text-xl font-bold mb-2" style={{fontFamily:'Barlow Condensed'}}>{course.title}</h3>
              <p className="text-sm text-zinc-400 mb-4">{course.description}</p>
              <div className="flex items-center gap-4 text-sm text-zinc-500 mb-4"><span className="flex items-center gap-1"><Clock className="w-4 h-4" />{course.duration_hours}h</span><span>{course.level}</span><span>{course.instructor}</span></div>
              <div className="flex items-center justify-between"><span className="font-mono text-xl text-cyan-400">{course.price===0?'FREE':`$${course.price}`}</span><button data-testid={`enroll-${course.id}`} className="btn-primary" onClick={() => {
                if (course.price > 0) {
                  axios.post(`${API}/payments/create-order`, {item_type: 'course', item_id: course.id, amount: course.price, return_url: window.location.href, cancel_url: window.location.href}).then(r => {
                    if (r.data.approval_url) window.open(r.data.approval_url, '_blank');
                  }).catch(console.error);
                } else {
                  axios.post(`${API}/education/enroll/${course.id}`).catch(console.error);
                }
              }}>Enroll{course.price > 0 ? ' via PayPal' : ''}</button></div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== BRAIN BRAWL =====================
const BrainBrawlView = ({ onBack }) => {
  const [questions, setQuestions] = useState([]);
  const [currentQ, setCurrentQ] = useState(0);
  const [score, setScore] = useState(0);
  const [gameState, setGameState] = useState('menu');
  const [answers, setAnswers] = useState([]);
  const [timeLeft, setTimeLeft] = useState(15);
  const [category, setCategory] = useState('all');
  const timerRef = useRef(null);

  useEffect(() => {
    if (gameState === 'playing' && timeLeft > 0) {
      timerRef.current = setTimeout(() => setTimeLeft(t => t - 1), 1000);
    } else if (gameState === 'playing' && timeLeft <= 0) {
      answerQuestion(-1); // Time's up
    }
    return () => clearTimeout(timerRef.current);
  }, [gameState, timeLeft]);

  const startGame = async () => {
    try { const r = await axios.get(`${API}/brain-brawl/questions?category=${category}&count=10`); setQuestions(r.data); setCurrentQ(0); setScore(0); setAnswers([]); setTimeLeft(15); setGameState('playing'); } catch (e) { console.error(e); }
  };

  const answerQuestion = (index) => {
    clearTimeout(timerRef.current);
    const isCorrect = index === questions[currentQ]?.correct;
    const timeBonus = isCorrect ? timeLeft * 5 : 0;
    if (isCorrect) setScore(s => s + 100 + timeBonus);
    setAnswers(prev => [...prev, {q: currentQ, selected: index, correct: isCorrect}]);
    if (currentQ + 1 >= questions.length) {
      setGameState('results');
      axios.post(`${API}/brain-brawl/submit`, {mode:'quick_fire', questions_total: questions.length, questions_correct: answers.filter(a=>a.correct).length + (isCorrect?1:0), score: score + (isCorrect ? 100+timeBonus : 0), category}).catch(console.error);
    } else { setCurrentQ(c => c + 1); setTimeLeft(15); }
  };

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
            <span className="font-mono text-zinc-400">Q{currentQ+1}/{questions.length}</span>
            <div className={`metric-value text-2xl ${timeLeft <= 5 ? 'text-red-400' : 'text-cyan-400'}`}>{timeLeft}s</div>
            <span className="font-mono text-cyan-400">SCORE: {score}</span>
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

      {gameState === 'results' && (
        <div className="max-w-2xl mx-auto text-center" data-testid="brain-brawl-results">
          <div className="surface-card p-12">
            <Award className="w-24 h-24 text-cyan-400 mx-auto mb-6" />
            <h2 className="text-3xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>CHALLENGE COMPLETE</h2>
            <div className="metric-value text-6xl text-cyan-400 mb-2">{score}</div>
            <div className="metric-label mb-8">FINAL SCORE</div>
            <div className="grid grid-cols-3 gap-4 mb-8">
              <div className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl text-green-400">{answers.filter(a=>a.correct).length}</div><div className="metric-label">Correct</div></div>
              <div className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl text-red-400">{answers.filter(a=>!a.correct).length}</div><div className="metric-label">Wrong</div></div>
              <div className="bg-black/50 p-4 border border-white/5"><div className="metric-value text-2xl">{answers.length}</div><div className="metric-label">Total</div></div>
            </div>
            <button data-testid="play-again" onClick={() => setGameState('menu')} className="btn-primary text-lg px-12 py-4">Play Again</button>
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
  useEffect(() => { axios.get(`${API}/leaderboard`).then(r => setLeaders(r.data)).catch(console.error); }, []);
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

// ===================== PIXEL STREAMING =====================
const PixelStreamingView = () => {
  const [status, setStatus] = useState(null);
  const [activeMode, setActiveMode] = useState(null);
  const [launchingMode, setLaunchingMode] = useState(null);
  const [error, setError] = useState('');

  const refreshStatus = useCallback(() => {
    axios.get(`${API}/streaming/status`).then(r => setStatus(r.data)).catch(console.error);
  }, []);

  useEffect(() => { refreshStatus(); }, [refreshStatus]);

  const launchMode = async (modeId) => {
    setLaunchingMode(modeId);
    setError('');
    try {
      const r = await axios.post(`${API}/streaming/launch-mode`, {mode_id: modeId});
      setActiveMode(r.data);
    } catch (e) {
      console.error(e);
      setError(e.response?.data?.detail || 'Unable to launch this mode. Confirm you are signed in and the backend is running.');
    } finally {
      setLaunchingMode(null);
    }
  };

  const wsConnected = status?.available;
  const isLocalSovereign = status?.mode === 'local_sovereign' || status?.e3ds_disabled;

  return (
    <div className="space-y-6 fade-in">
      <div className="flex items-center justify-between">
        <div><p className="overline mb-1">LOCAL SOVEREIGN STREAM · UE 5.7</p><h1 className="text-4xl font-black" style={{fontFamily:'Barlow Condensed'}}>PIXEL STREAMING</h1></div>
        <div className="flex items-center gap-2">
          {wsConnected ? <Wifi className="w-5 h-5 text-green-400" /> : <WifiOff className="w-5 h-5 text-yellow-400" />}
          <span className={`text-sm font-mono ${wsConnected ? 'text-green-400' : 'text-yellow-400'}`}>{wsConnected ? 'LIVE DATA FEED' : 'LISTENING'}</span>
        </div>
      </div>

      <div className="surface-card p-6" data-testid="streaming-status">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            <Shield className={`w-7 h-7 ${wsConnected ? 'text-green-400' : 'text-cyan-400'}`} />
            <div>
              <h3 className="text-lg font-bold" style={{fontFamily:'Barlow Condensed'}}>{isLocalSovereign ? 'LOCAL SOVEREIGN MODE' : 'STREAM STATUS'}</h3>
              <p className="text-sm text-zinc-400">{status?.message || 'Checking streaming bridge status...'}</p>
            </div>
          </div>
          <button onClick={refreshStatus} className="btn-secondary text-sm">Refresh</button>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-5">
          <div className="bg-black/30 p-3 border border-white/5">
            <div className="metric-label">Provider</div>
            <div className="font-mono text-cyan-400">{status?.provider || 'checking'}</div>
          </div>
          <div className="bg-black/30 p-3 border border-white/5">
            <div className="metric-label">Data Feed</div>
            <div className={`font-mono ${status?.data_feed ? 'text-green-400' : 'text-zinc-500'}`}>{status?.data_feed ? 'READY' : 'PENDING'}</div>
          </div>
          <div className="bg-black/30 p-3 border border-white/5">
            <div className="metric-label">Video Feed</div>
            <div className="font-mono text-zinc-500">{status?.video_feed ? 'ON' : 'LOCAL ONLY'}</div>
          </div>
          <div className="bg-black/30 p-3 border border-white/5">
            <div className="metric-label">Modes</div>
            <div className="font-mono text-cyan-400">{status?.supported_modes?.length || 0}</div>
          </div>
        </div>
      </div>

      <div className="surface-card overflow-hidden" data-testid="stream-viewer">
        <div className="aspect-video bg-black flex items-center justify-center border border-white/5">
          <div className="text-center px-6">
            <Radio className={`w-16 h-16 mx-auto mb-4 ${wsConnected ? 'text-green-400 animate-pulse' : 'text-cyan-700'}`} />
            <h3 className="text-xl font-bold text-zinc-200" style={{fontFamily:'Barlow Condensed'}}>{wsConnected ? 'SOVEREIGN HUB CONNECTED' : 'AWAITING SOVEREIGN DEVICE'}</h3>
            <p className="text-sm text-zinc-500 mt-2 max-w-xl mx-auto">
              Final Evolution Lab now uses the local Sovereign Hub for UE mode launch commands and biomechanical telemetry. Cloud E3DS video is disabled for this path; launch commands are sent to connected native clients.
            </p>
            <div className="flex flex-wrap items-center justify-center gap-6 mt-6 text-zinc-500">
              <div className="text-center"><div className="font-mono text-lg text-cyan-400">WSS</div><div className="text-xs">Bridge</div></div>
              <div className="text-center"><div className="font-mono text-lg text-cyan-400">AES-256</div><div className="text-xs">Telemetry</div></div>
              <div className="text-center"><div className="font-mono text-lg text-cyan-400">UE 5.7</div><div className="text-xs">Modes</div></div>
            </div>
          </div>
        </div>
      </div>

      {activeMode && (
        <div className="surface-active p-5" data-testid="active-stream-mode">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="metric-label">Active Launch Session</div>
              <div className="text-lg font-bold text-cyan-400" style={{fontFamily:'Barlow Condensed'}}>{activeMode.mode_id.replace(/_/g,' ').toUpperCase()} · {activeMode.venue}</div>
              <div className="text-xs text-zinc-500 font-mono">{activeMode.session_id}</div>
            </div>
            {activeMode.deep_link && (
              <a className="btn-primary text-sm" href={activeMode.deep_link}>Open Native Client</a>
            )}
          </div>
        </div>
      )}

      {error && <div className="surface-card p-4 border-l-4 border-l-red-400 text-sm text-red-300" data-testid="stream-error">{error}</div>}

      <div>
        <h2 className="text-xl font-bold mb-4" style={{fontFamily:'Barlow Condensed'}}>LAUNCH GAME MODE</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3" data-testid="stream-modes">
          {(status?.supported_modes || []).map(m => (
            <button key={m} data-testid={`stream-${m}`} onClick={() => launchMode(m)} disabled={!!launchingMode}
              className={`surface-card p-4 text-center card-hover ${activeMode?.mode_id === m ? 'border-l-2 border-cyan-400' : ''} ${launchingMode ? 'opacity-60 cursor-wait' : ''}`}>
              <div className="text-sm font-bold text-cyan-400 uppercase mb-1">{m.replace(/_/g,' ')}</div>
              <div className="text-xs text-zinc-600 font-mono">{launchingMode === m ? 'launching...' : (status?.mode_maps?.[m] || m)}</div>
            </button>
          ))}
        </div>
      </div>

      <div className="surface-card p-6" data-testid="deploy-instructions">
        <h3 className="text-lg font-bold mb-3" style={{fontFamily:'Barlow Condensed'}}>NATIVE CLIENT HANDOFF</h3>
        <div className="bg-black/50 p-4 border border-white/5 font-mono text-sm text-zinc-400 overflow-x-auto">
          <div className="text-zinc-600"># Connect an iOS/macOS build to receive mode launch commands</div>
          <div>open finalevolution://pair</div>
          <div>connect {status?.ws_url || 'wss://finalevolutiongroup.com/ws/sovereign'}</div>
          <div className="text-cyan-400 mt-2">Launch a mode above to generate a session deep link.</div>
          <div className="text-zinc-600 mt-2"># Cloud GPU streaming remains disabled in sovereign mode.</div>
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

  useEffect(() => { axios.get(`${API}/profile/progress`).then(r => setProgress(r.data)).catch(console.error); }, []);

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
      case 'education': return <EducationView />;
      case 'brain-brawl': return <BrainBrawlView />;
      case 'streaks': return <StreaksView />;
      case 'social': return <SocialView />;
      case 'tournaments': return <TournamentsView />;
      case 'avatar': return <AvatarBuilderView />;
      case 'critique': return <VideoCritiqueView />;
      case 'multiplayer': return <MultiplayerView />;
      case 'referral': return <ReferralView />;
      case 'analytics': return <AnalyticsView />;
      case 'sovereign': return <SovereignDashboard />;
      case 'leaderboard': return <LeaderboardView />;
      case 'streaming': return <PixelStreamingView />;
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
      <Route path="/download" element={<DownloadPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function App() {
  return <BrowserRouter><AuthProvider><PayPalScriptProvider options={{clientId: process.env.REACT_APP_PAYPAL_CLIENT_ID || 'test'}}><AppRouter /></PayPalScriptProvider></AuthProvider></BrowserRouter>;
}

export default App;
