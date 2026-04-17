import React, { useState, useEffect, useCallback, createContext, useContext } from "react";
import "@/App.css";
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation, Link } from "react-router-dom";
import axios from "axios";
import { 
  Activity, Brain, Users, Gamepad2, GraduationCap, ShoppingBag, 
  Settings, LogOut, Home, User, Trophy, Heart, Dumbbell, 
  Play, Zap, Target, Clock, ChevronRight, Menu, X, Star,
  Shield, Award, TrendingUp, BarChart3, Calendar
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

// Configure axios
axios.defaults.withCredentials = true;

// ===================== AUTH CONTEXT =====================
const AuthContext = createContext(null);

export const useAuth = () => useContext(AuthContext);

const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const checkAuth = useCallback(async () => {
    // CRITICAL: If returning from OAuth callback, skip the /me check.
    // AuthCallback will exchange the session_id and establish the session first.
    if (window.location.hash?.includes('session_id=')) {
      setLoading(false);
      return;
    }
    
    try {
      const response = await axios.get(`${API}/auth/me`);
      setUser(response.data);
    } catch (error) {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  const logout = async () => {
    try {
      await axios.post(`${API}/auth/logout`);
    } catch (error) {
      console.error("Logout error:", error);
    }
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, setUser, loading, logout, checkAuth }}>
      {children}
    </AuthContext.Provider>
  );
};

// ===================== AUTH CALLBACK =====================
const AuthCallback = () => {
  const navigate = useNavigate();
  const { setUser } = useAuth();
  const hasProcessed = React.useRef(false);

  useEffect(() => {
    if (hasProcessed.current) return;
    hasProcessed.current = true;

    const processAuth = async () => {
      const hash = window.location.hash;
      const sessionId = hash.split('session_id=')[1]?.split('&')[0];
      
      if (!sessionId) {
        navigate('/login');
        return;
      }

      try {
        const response = await axios.post(`${API}/auth/session`, { session_id: sessionId });
        setUser(response.data);
        navigate('/dashboard', { replace: true, state: { user: response.data } });
      } catch (error) {
        console.error("Auth error:", error);
        navigate('/login');
      }
    };

    processAuth();
  }, [navigate, setUser]);

  return (
    <div className="min-h-screen flex items-center justify-center" style={{ background: 'var(--bg-default)' }}>
      <div className="text-center">
        <div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        <p className="text-zinc-400">Authenticating...</p>
      </div>
    </div>
  );
};

// ===================== PROTECTED ROUTE =====================
const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: 'var(--bg-default)' }}>
        <div className="w-16 h-16 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (!user && !location.state?.user) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

// ===================== LANDING PAGE =====================
const LandingPage = () => {
  const navigate = useNavigate();
  const { user } = useAuth();

  useEffect(() => {
    if (user) navigate('/dashboard');
  }, [user, navigate]);

  const handleLogin = () => {
    // REMINDER: DO NOT HARDCODE THE URL, OR ADD ANY FALLBACKS OR REDIRECT URLS, THIS BREAKS THE AUTH
    const redirectUrl = window.location.origin + '/dashboard';
    window.location.href = `https://auth.emergentagent.com/?redirect=${encodeURIComponent(redirectUrl)}`;
  };

  return (
    <div className="min-h-screen" style={{ background: 'var(--bg-default)' }}>
      {/* Hero Section */}
      <div className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-cyan-500/10 to-transparent"></div>
        
        {/* Header */}
        <header className="relative z-10 flex items-center justify-between px-8 py-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-cyan-400 flex items-center justify-center">
              <Zap className="w-6 h-6 text-black" />
            </div>
            <span className="text-xl font-bold tracking-tight" style={{ fontFamily: 'Barlow Condensed' }}>
              FINAL EVOLUTION LAB
            </span>
          </div>
          <button 
            data-testid="hero-login-btn"
            onClick={handleLogin}
            className="btn-primary"
          >
            Enter Lab
          </button>
        </header>

        {/* Hero Content */}
        <div className="relative z-10 max-w-6xl mx-auto px-8 py-24 text-center">
          <p className="overline mb-4">THE ATHLETE OPERATING SYSTEM</p>
          <h1 className="text-5xl md:text-7xl font-black tracking-tighter mb-6" style={{ fontFamily: 'Barlow Condensed' }}>
            YOUR MOVEMENT<br />
            <span className="text-cyan-400">AUDITED</span>
          </h1>
          <p className="text-xl text-zinc-400 max-w-2xl mx-auto mb-8">
            System scan meets game arena. Train with AI, compete globally, evolve continuously.
          </p>
          
          <div className="flex flex-wrap justify-center gap-4">
            <button 
              data-testid="cta-start-btn"
              onClick={handleLogin}
              className="btn-primary text-lg px-8 py-4"
            >
              Start System Scan
            </button>
            <button className="btn-secondary text-lg px-8 py-4">
              Watch Demo
            </button>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mt-16">
            {[
              { value: "17", label: "Game Modes" },
              { value: "9,356+", label: "AI Assets" },
              { value: "54", label: "Animations" },
              { value: "12", label: "Venues" }
            ].map((stat, i) => (
              <div key={i} className="text-center">
                <div className="metric-value text-cyan-400">{stat.value}</div>
                <div className="metric-label">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Features Grid */}
      <div className="max-w-6xl mx-auto px-8 py-24">
        <p className="overline text-center mb-4">CORE SYSTEMS</p>
        <h2 className="text-4xl font-bold text-center mb-16" style={{ fontFamily: 'Barlow Condensed' }}>
          ONE SCAN. TOTAL INTEGRATION.
        </h2>
        
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[
            { icon: Activity, title: "System Scan", desc: "Avatar, PRQ metrics, health signals, and workout plans unified" },
            { icon: Users, title: "Creator Cards", desc: "Digital collectibles from elite athletes and coaches" },
            { icon: Gamepad2, title: "Game Modes", desc: "17 modes across basketball, karate, soccer, and more" },
            { icon: Trophy, title: "Coach Economy", desc: "Instruction and critique as first-class currencies" },
            { icon: Brain, title: "Brain Brawl", desc: "Cognitive training for peak decision-making" },
            { icon: GraduationCap, title: "Education", desc: "Common Core to kinesiology certification" }
          ].map((feature, i) => (
            <div key={i} className="surface-card p-6 card-hover">
              <feature.icon className="w-10 h-10 text-cyan-400 mb-4" />
              <h3 className="text-xl font-bold mb-2" style={{ fontFamily: 'Barlow Condensed' }}>{feature.title}</h3>
              <p className="text-zinc-400">{feature.desc}</p>
            </div>
          ))}
        </div>
      </div>

      {/* CTA */}
      <div className="surface-glass py-16">
        <div className="max-w-4xl mx-auto px-8 text-center">
          <h2 className="text-3xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>
            READY TO EVOLVE?
          </h2>
          <p className="text-zinc-400 mb-8">Join the lab. Train smarter. Compete harder.</p>
          <button 
            data-testid="footer-cta-btn"
            onClick={handleLogin}
            className="btn-primary text-lg px-8 py-4"
          >
            Enter Final Evolution Lab
          </button>
        </div>
      </div>
    </div>
  );
};

// ===================== LOGIN PAGE =====================
const LoginPage = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) navigate('/dashboard');
  }, [user, navigate]);

  const handleLogin = () => {
    // REMINDER: DO NOT HARDCODE THE URL, OR ADD ANY FALLBACKS OR REDIRECT URLS, THIS BREAKS THE AUTH
    const redirectUrl = window.location.origin + '/dashboard';
    window.location.href = `https://auth.emergentagent.com/?redirect=${encodeURIComponent(redirectUrl)}`;
  };

  return (
    <div className="min-h-screen flex items-center justify-center" style={{ background: 'var(--bg-default)' }}>
      <div className="surface-card p-8 w-full max-w-md text-center">
        <div className="w-16 h-16 bg-cyan-400 flex items-center justify-center mx-auto mb-6">
          <Zap className="w-10 h-10 text-black" />
        </div>
        <h1 className="text-3xl font-bold mb-2" style={{ fontFamily: 'Barlow Condensed' }}>FINAL EVOLUTION LAB</h1>
        <p className="text-zinc-400 mb-8">Sign in to access your training dashboard</p>
        
        <button 
          data-testid="login-google-btn"
          onClick={handleLogin}
          className="btn-primary w-full flex items-center justify-center gap-3"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24">
            <path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          Continue with Google
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
    { id: 'dashboard', icon: Home, label: 'Dashboard' },
    { id: 'scan', icon: Activity, label: 'System Scan' },
    { id: 'games', icon: Gamepad2, label: 'Game Modes' },
    { id: 'cards', icon: Users, label: 'Creator Cards' },
    { id: 'coach', icon: Trophy, label: 'Coach Hub' },
    { id: 'education', icon: GraduationCap, label: 'Education' },
    { id: 'brain-brawl', icon: Brain, label: 'Brain Brawl' },
  ];

  const handleLogout = async () => {
    await logout();
    navigate('/');
  };

  return (
    <>
      {/* Mobile Toggle */}
      <button 
        data-testid="mobile-menu-btn"
        className="lg:hidden fixed top-4 left-4 z-50 p-2 bg-zinc-900 border border-zinc-800"
        onClick={() => setMobileOpen(!mobileOpen)}
      >
        {mobileOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
      </button>

      {/* Sidebar */}
      <aside className={`sidebar ${mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'} transition-transform`}>
        {/* Logo */}
        <div className="p-6 border-b border-white/5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-cyan-400 flex items-center justify-center">
              <Zap className="w-6 h-6 text-black" />
            </div>
            <div>
              <div className="font-bold text-sm tracking-tight" style={{ fontFamily: 'Barlow Condensed' }}>FINAL EVOLUTION</div>
              <div className="text-xs text-zinc-500">LAB v1.0</div>
            </div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 py-4">
          {navItems.map(item => (
            <button
              key={item.id}
              data-testid={`nav-${item.id}`}
              onClick={() => { setActiveTab(item.id); setMobileOpen(false); }}
              className={`nav-item w-full ${activeTab === item.id ? 'active' : ''}`}
            >
              <item.icon className="w-5 h-5" />
              {item.label}
            </button>
          ))}
        </nav>

        {/* User Section */}
        <div className="p-4 border-t border-white/5">
          <div className="flex items-center gap-3 mb-4">
            {user?.picture ? (
              <img src={user.picture} alt="" className="w-10 h-10 rounded-full" />
            ) : (
              <div className="w-10 h-10 bg-zinc-800 rounded-full flex items-center justify-center">
                <User className="w-5 h-5 text-zinc-400" />
              </div>
            )}
            <div className="flex-1 min-w-0">
              <div className="font-medium text-sm truncate">{user?.name || 'Athlete'}</div>
              <div className="text-xs text-zinc-500">Level {user?.level || 1}</div>
            </div>
          </div>
          <button 
            data-testid="logout-btn"
            onClick={handleLogout}
            className="nav-item w-full text-red-400 hover:text-red-300"
          >
            <LogOut className="w-5 h-5" />
            Sign Out
          </button>
        </div>
      </aside>
    </>
  );
};

// ===================== DASHBOARD VIEW =====================
const DashboardView = ({ setActiveTab }) => {
  const { user } = useAuth();
  const [prq, setPrq] = useState(null);
  const [stats, setStats] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [prqRes, statsRes] = await Promise.all([
          axios.get(`${API}/prq/metrics`),
          axios.get(`${API}/stats/overview`)
        ]);
        setPrq(prqRes.data);
        setStats(statsRes.data);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      }
    };
    fetchData();
  }, []);

  return (
    <div className="space-y-8 fade-in">
      {/* Welcome Header */}
      <div className="flex items-center justify-between">
        <div>
          <p className="overline mb-1">WELCOME BACK</p>
          <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>
            {user?.name?.split(' ')[0] || 'ATHLETE'}
          </h1>
        </div>
        <div className="text-right">
          <div className="metric-label">TODAY'S DATE</div>
          <div className="text-lg font-medium">{new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</div>
        </div>
      </div>

      {/* PRQ Overview */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* PRQ Score Card */}
        <div className="surface-active p-6 lg:col-span-1" data-testid="prq-score-card">
          <p className="overline mb-4">PERFORMANCE READINESS</p>
          <div className="flex items-center justify-center">
            <div className="relative">
              <svg className="w-48 h-48 -rotate-90">
                <circle cx="96" cy="96" r="80" fill="none" stroke="var(--secondary)" strokeWidth="12" />
                <circle 
                  cx="96" cy="96" r="80" 
                  fill="none" 
                  stroke="var(--primary)" 
                  strokeWidth="12"
                  strokeLinecap="round"
                  strokeDasharray={`${(prq?.overall_score || 75) * 5.02} 502`}
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="metric-value">{prq?.overall_score?.toFixed(0) || '75'}</span>
                <span className="metric-label">PRQ SCORE</span>
              </div>
            </div>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="lg:col-span-2 grid grid-cols-2 gap-4">
          {[
            { label: 'Workouts', value: stats?.total_workouts || 0, icon: Dumbbell, color: 'text-green-400' },
            { label: 'Sessions', value: stats?.coaching_sessions || 0, icon: Users, color: 'text-blue-400' },
            { label: 'Brain Brawls', value: stats?.brain_brawl_sessions || 0, icon: Brain, color: 'text-purple-400' },
            { label: 'XP Earned', value: stats?.xp || 0, icon: Star, color: 'text-yellow-400' }
          ].map((stat, i) => (
            <div key={i} className="surface-card p-6" data-testid={`stat-${stat.label.toLowerCase().replace(' ', '-')}`}>
              <stat.icon className={`w-8 h-8 ${stat.color} mb-3`} />
              <div className="metric-value text-2xl">{stat.value}</div>
              <div className="metric-label">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Quick Actions */}
      <div>
        <h2 className="text-2xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>QUICK START</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[
            { title: 'Start Workout', desc: 'AI-recommended training', icon: Dumbbell, action: () => setActiveTab('scan') },
            { title: 'Play Game', desc: '17 modes available', icon: Gamepad2, action: () => setActiveTab('games') },
            { title: 'Brain Brawl', desc: 'Sharpen your mind', icon: Brain, action: () => setActiveTab('brain-brawl') }
          ].map((item, i) => (
            <button
              key={i}
              data-testid={`quick-${item.title.toLowerCase().replace(' ', '-')}`}
              onClick={item.action}
              className="surface-card p-6 text-left card-hover flex items-center gap-4"
            >
              <div className="w-12 h-12 bg-cyan-400/10 flex items-center justify-center">
                <item.icon className="w-6 h-6 text-cyan-400" />
              </div>
              <div>
                <div className="font-bold">{item.title}</div>
                <div className="text-sm text-zinc-500">{item.desc}</div>
              </div>
              <ChevronRight className="w-5 h-5 text-zinc-600 ml-auto" />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};

// ===================== SYSTEM SCAN VIEW =====================
const SystemScanView = () => {
  const [prq, setPrq] = useState(null);
  const [health, setHealth] = useState([]);
  const [workouts, setWorkouts] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [prqRes, healthRes, workoutsRes] = await Promise.all([
          axios.get(`${API}/prq/metrics`),
          axios.get(`${API}/health/metrics`),
          axios.get(`${API}/workouts/recommended`)
        ]);
        setPrq(prqRes.data);
        setHealth(healthRes.data);
        setWorkouts(workoutsRes.data);
      } catch (error) {
        console.error('Error fetching scan data:', error);
      }
    };
    fetchData();
  }, []);

  const metrics = [
    { key: 'strength', label: 'Strength', color: '#FF6B6B' },
    { key: 'speed', label: 'Speed', color: '#4ECDC4' },
    { key: 'endurance', label: 'Endurance', color: '#45B7D1' },
    { key: 'agility', label: 'Agility', color: '#96CEB4' },
    { key: 'power', label: 'Power', color: '#FFEAA7' },
    { key: 'flexibility', label: 'Flexibility', color: '#DDA0DD' },
    { key: 'recovery', label: 'Recovery', color: '#98D8C8' },
    { key: 'mental', label: 'Mental', color: '#F7DC6F' }
  ];

  return (
    <div className="space-y-8 fade-in">
      <div>
        <p className="overline mb-1">PERFORMANCE ANALYSIS</p>
        <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>SYSTEM SCAN</h1>
      </div>

      {/* PRQ Breakdown */}
      <div className="surface-card p-6" data-testid="prq-breakdown">
        <h2 className="text-xl font-bold mb-6" style={{ fontFamily: 'Barlow Condensed' }}>PRQ BREAKDOWN</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {metrics.map(m => (
            <div key={m.key} className="surface-card p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="metric-label">{m.label}</span>
                <span className="font-mono text-lg">{prq?.[m.key]?.toFixed(0) || '--'}</span>
              </div>
              <div className="progress-bar">
                <div 
                  className="progress-fill" 
                  style={{ width: `${prq?.[m.key] || 0}%`, background: m.color }}
                ></div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Health Metrics */}
      <div className="surface-card p-6" data-testid="health-metrics">
        <h2 className="text-xl font-bold mb-6" style={{ fontFamily: 'Barlow Condensed' }}>HEALTH SIGNALS</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[
            { label: 'Heart Rate', value: health[0]?.heart_rate || 72, unit: 'BPM', icon: Heart },
            { label: 'Sleep', value: health[0]?.sleep_hours || 7.5, unit: 'HRS', icon: Clock },
            { label: 'Steps', value: health[0]?.steps || 8500, unit: '', icon: Activity },
            { label: 'Readiness', value: health[0]?.readiness_score || 85, unit: '%', icon: Zap }
          ].map((item, i) => (
            <div key={i} className="bg-black/50 p-4 border border-white/5">
              <item.icon className="w-5 h-5 text-cyan-400 mb-2" />
              <div className="metric-value text-2xl">{item.value}{item.unit && <span className="text-sm ml-1">{item.unit}</span>}</div>
              <div className="metric-label">{item.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Recommended Workouts */}
      <div data-testid="recommended-workouts">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>RECOMMENDED WORKOUTS</h2>
        <div className="grid md:grid-cols-3 gap-4">
          {workouts.map(workout => (
            <div key={workout.id} className="surface-card p-6 card-hover">
              <div className="badge-clinical mb-3">{workout.sport}</div>
              <h3 className="text-lg font-bold mb-2">{workout.name}</h3>
              <div className="flex items-center gap-4 text-sm text-zinc-400 mb-4">
                <span className="flex items-center gap-1"><Clock className="w-4 h-4" /> {workout.duration_minutes}min</span>
                <span className="flex items-center gap-1"><Target className="w-4 h-4" /> {workout.difficulty}</span>
              </div>
              <button data-testid={`start-workout-${workout.id}`} className="btn-primary w-full">Start Workout</button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ===================== GAME MODES VIEW =====================
const GameModesView = () => {
  const [modes, setModes] = useState([]);
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    const fetchModes = async () => {
      try {
        const response = await axios.get(`${API}/games/modes`);
        setModes(response.data);
      } catch (error) {
        console.error('Error fetching game modes:', error);
      }
    };
    fetchModes();
  }, []);

  const categories = ['all', 'Basketball', 'Combat', 'Field', 'Court', 'Board', 'Academy'];
  const filteredModes = filter === 'all' ? modes : modes.filter(m => m.category === filter);

  return (
    <div className="space-y-8 fade-in">
      <div>
        <p className="overline mb-1">ARENA ACCESS</p>
        <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>GAME MODES</h1>
      </div>

      {/* Filter */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {categories.map(cat => (
          <button
            key={cat}
            data-testid={`filter-${cat.toLowerCase()}`}
            onClick={() => setFilter(cat)}
            className={`px-4 py-2 text-sm font-medium uppercase tracking-wide transition-all ${
              filter === cat 
                ? 'bg-cyan-400 text-black' 
                : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" data-testid="game-modes-grid">
        {filteredModes.map(mode => (
          <div key={mode.id} className="game-mode-card surface-card card-hover cursor-pointer" data-testid={`game-${mode.id}`}>
            <img src={mode.image_url} alt={mode.name} />
            <div className="game-mode-overlay">
              <div className="badge-clinical mb-2 w-fit">{mode.category}</div>
              <h3 className="text-xl font-bold" style={{ fontFamily: 'Barlow Condensed' }}>{mode.display_name}</h3>
              <p className="text-sm text-zinc-400 mb-3">{mode.description}</p>
              <div className="flex items-center gap-4 text-xs text-zinc-500">
                <span>{mode.player_count}</span>
                <span>{mode.duration}</span>
                <span>{mode.difficulty}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== CREATOR CARDS VIEW =====================
const CreatorCardsView = () => {
  const [cards, setCards] = useState([]);

  useEffect(() => {
    const fetchCards = async () => {
      try {
        const response = await axios.get(`${API}/cards`);
        setCards(response.data);
      } catch (error) {
        console.error('Error fetching cards:', error);
      }
    };
    fetchCards();
  }, []);

  return (
    <div className="space-y-8 fade-in">
      <div className="flex items-center justify-between">
        <div>
          <p className="overline mb-1">ATHLETE MARKETPLACE</p>
          <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>CREATOR CARDS</h1>
        </div>
        <button className="btn-secondary flex items-center gap-2">
          <ShoppingBag className="w-5 h-5" /> My Collection
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" data-testid="creator-cards-grid">
        {cards.map(card => (
          <div 
            key={card.id} 
            className={`creator-card ${card.style} p-6 card-hover`}
            data-testid={`card-${card.id}`}
          >
            {/* Card Header */}
            <div className="flex items-start justify-between mb-4">
              <div className="badge-clinical">{card.tier}</div>
              <div className="text-right">
                <div className="text-xs text-zinc-500">PRICE</div>
                <div className="font-mono text-lg text-cyan-400">${card.price}</div>
              </div>
            </div>

            {/* Creator Image */}
            <div className="aspect-square mb-4 overflow-hidden bg-zinc-900">
              <img src={card.image_url} alt={card.name} className="w-full h-full object-cover" />
            </div>

            {/* Creator Info */}
            <h3 className="text-xl font-bold" style={{ fontFamily: 'Barlow Condensed' }}>{card.name}</h3>
            <p className="text-sm text-cyan-400 mb-2">{card.title}</p>
            <p className="text-sm text-zinc-400 mb-4 line-clamp-2">{card.bio}</p>

            {/* Stats */}
            <div className="grid grid-cols-3 gap-2 mb-4">
              {Object.entries(card.stats || {}).slice(0, 3).map(([key, val]) => (
                <div key={key} className="text-center p-2 bg-black/30">
                  <div className="font-mono text-lg">{val.toLocaleString()}</div>
                  <div className="text-xs text-zinc-500 uppercase">{key}</div>
                </div>
              ))}
            </div>

            {/* Actions */}
            <div className="flex gap-2">
              <button data-testid={`buy-${card.id}`} className="btn-primary flex-1">Purchase</button>
              <button className="btn-secondary px-4"><Star className="w-5 h-5" /></button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== COACH HUB VIEW =====================
const CoachHubView = () => {
  const [coaches, setCoaches] = useState([]);
  const [sessions, setSessions] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [coachesRes, sessionsRes] = await Promise.all([
          axios.get(`${API}/coach/available`),
          axios.get(`${API}/coach/sessions`)
        ]);
        setCoaches(coachesRes.data);
        setSessions(sessionsRes.data);
      } catch (error) {
        console.error('Error fetching coach data:', error);
      }
    };
    fetchData();
  }, []);

  return (
    <div className="space-y-8 fade-in">
      <div>
        <p className="overline mb-1">TRAINING NETWORK</p>
        <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>COACH HUB</h1>
      </div>

      {/* Available Coaches */}
      <div data-testid="available-coaches">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>AVAILABLE COACHES</h2>
        <div className="grid md:grid-cols-3 gap-4">
          {coaches.map((coach, i) => (
            <div key={i} className="surface-card p-6 card-hover">
              <div className="flex items-center gap-4 mb-4">
                <div className="w-16 h-16 bg-zinc-800 rounded-full flex items-center justify-center">
                  <User className="w-8 h-8 text-zinc-400" />
                </div>
                <div>
                  <h3 className="font-bold">{coach.name}</h3>
                  <p className="text-sm text-cyan-400">{coach.sport}</p>
                </div>
              </div>
              <div className="flex items-center gap-4 text-sm text-zinc-400 mb-4">
                <span className="flex items-center gap-1"><Star className="w-4 h-4 text-yellow-400" /> {coach.rating}</span>
                <span>{coach.sessions} sessions</span>
              </div>
              <button data-testid={`book-coach-${i}`} className="btn-primary w-full">Book Session</button>
            </div>
          ))}
        </div>
      </div>

      {/* My Sessions */}
      <div data-testid="my-sessions">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>MY SESSIONS</h2>
        {sessions.length === 0 ? (
          <div className="surface-card p-8 text-center">
            <Calendar className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
            <p className="text-zinc-400">No sessions scheduled yet</p>
            <p className="text-sm text-zinc-600">Book a coach to start your training journey</p>
          </div>
        ) : (
          <div className="space-y-4">
            {sessions.map((session, i) => (
              <div key={i} className="surface-card p-4 flex items-center justify-between">
                <div>
                  <h4 className="font-medium">{session.session_type} Session</h4>
                  <p className="text-sm text-zinc-400">{session.sport}</p>
                </div>
                <div className="badge-clinical">{session.status}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// ===================== EDUCATION VIEW =====================
const EducationView = () => {
  const [courses, setCourses] = useState([]);
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    const fetchCourses = async () => {
      try {
        const response = await axios.get(`${API}/education/courses`);
        setCourses(response.data);
      } catch (error) {
        console.error('Error fetching courses:', error);
      }
    };
    fetchCourses();
  }, []);

  const categories = ['all', 'brain_brawl', 'kinesiology', 'stem', 'common_core'];
  const filteredCourses = filter === 'all' ? courses : courses.filter(c => c.category === filter);

  return (
    <div className="space-y-8 fade-in">
      <div>
        <p className="overline mb-1">ATHLETE ACADEMY</p>
        <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>EDUCATION</h1>
      </div>

      {/* Filter */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {categories.map(cat => (
          <button
            key={cat}
            data-testid={`edu-filter-${cat}`}
            onClick={() => setFilter(cat)}
            className={`px-4 py-2 text-sm font-medium uppercase tracking-wide transition-all whitespace-nowrap ${
              filter === cat 
                ? 'bg-cyan-400 text-black' 
                : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'
            }`}
          >
            {cat.replace('_', ' ')}
          </button>
        ))}
      </div>

      {/* Courses Grid */}
      <div className="grid md:grid-cols-2 gap-6" data-testid="courses-grid">
        {filteredCourses.map(course => (
          <div key={course.id} className="surface-card overflow-hidden card-hover" data-testid={`course-${course.id}`}>
            <div className="aspect-video">
              <img src={course.image_url} alt={course.title} className="w-full h-full object-cover" />
            </div>
            <div className="p-6">
              <div className="flex items-center gap-2 mb-3">
                <span className="badge-clinical">{course.category.replace('_', ' ')}</span>
                {course.is_certificate && (
                  <span className="badge-clinical" style={{ background: 'rgba(0, 255, 157, 0.1)', borderColor: 'rgba(0, 255, 157, 0.3)', color: '#00FF9D' }}>
                    Certificate
                  </span>
                )}
              </div>
              <h3 className="text-xl font-bold mb-2" style={{ fontFamily: 'Barlow Condensed' }}>{course.title}</h3>
              <p className="text-sm text-zinc-400 mb-4">{course.description}</p>
              <div className="flex items-center gap-4 text-sm text-zinc-500 mb-4">
                <span className="flex items-center gap-1"><Clock className="w-4 h-4" /> {course.duration_hours}h</span>
                <span className="flex items-center gap-1"><BarChart3 className="w-4 h-4" /> {course.level}</span>
                <span>{course.instructor}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="font-mono text-xl text-cyan-400">
                  {course.price === 0 ? 'FREE' : `$${course.price}`}
                </span>
                <button data-testid={`enroll-${course.id}`} className="btn-primary">Enroll Now</button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== BRAIN BRAWL VIEW =====================
const BrainBrawlView = () => {
  const [questions, setQuestions] = useState([]);
  const [currentQ, setCurrentQ] = useState(0);
  const [score, setScore] = useState(0);
  const [gameState, setGameState] = useState('menu'); // menu, playing, results
  const [answers, setAnswers] = useState([]);

  const startGame = async () => {
    try {
      const response = await axios.get(`${API}/brain-brawl/questions?count=5`);
      setQuestions(response.data);
      setCurrentQ(0);
      setScore(0);
      setAnswers([]);
      setGameState('playing');
    } catch (error) {
      console.error('Error fetching questions:', error);
    }
  };

  const answerQuestion = (index) => {
    const isCorrect = index === questions[currentQ].correct;
    if (isCorrect) setScore(s => s + 100);
    setAnswers([...answers, { question: currentQ, selected: index, correct: isCorrect }]);
    
    if (currentQ + 1 >= questions.length) {
      setGameState('results');
      submitResults();
    } else {
      setCurrentQ(c => c + 1);
    }
  };

  const submitResults = async () => {
    try {
      await axios.post(`${API}/brain-brawl/submit`, {
        mode: 'quick_fire',
        questions_total: questions.length,
        questions_correct: answers.filter(a => a.correct).length + (questions[currentQ]?.correct === answers[answers.length - 1]?.selected ? 1 : 0),
        score: score
      });
    } catch (error) {
      console.error('Error submitting results:', error);
    }
  };

  return (
    <div className="space-y-8 fade-in">
      <div>
        <p className="overline mb-1">COGNITIVE TRAINING</p>
        <h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>BRAIN BRAWL</h1>
      </div>

      {gameState === 'menu' && (
        <div className="max-w-2xl mx-auto text-center" data-testid="brain-brawl-menu">
          <div className="surface-card p-12">
            <Brain className="w-24 h-24 text-cyan-400 mx-auto mb-6" />
            <h2 className="text-3xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>SHARPEN YOUR MIND</h2>
            <p className="text-zinc-400 mb-8">Test your sports IQ and cognitive abilities under pressure</p>
            
            <div className="grid grid-cols-3 gap-4 mb-8">
              {[
                { label: 'Questions', value: '5' },
                { label: 'Categories', value: 'Sports IQ' },
                { label: 'Reward', value: '+XP' }
              ].map((item, i) => (
                <div key={i} className="bg-black/50 p-4 border border-white/5">
                  <div className="metric-value text-2xl">{item.value}</div>
                  <div className="metric-label">{item.label}</div>
                </div>
              ))}
            </div>

            <button 
              data-testid="start-brain-brawl"
              onClick={startGame}
              className="btn-primary text-lg px-12 py-4"
            >
              Start Challenge
            </button>
          </div>
        </div>
      )}

      {gameState === 'playing' && questions.length > 0 && (
        <div className="max-w-3xl mx-auto" data-testid="brain-brawl-game">
          {/* Progress */}
          <div className="flex items-center justify-between mb-6">
            <span className="font-mono text-zinc-400">Q{currentQ + 1}/{questions.length}</span>
            <span className="font-mono text-cyan-400">SCORE: {score}</span>
          </div>
          <div className="progress-bar mb-8">
            <div className="progress-fill" style={{ width: `${((currentQ + 1) / questions.length) * 100}%` }}></div>
          </div>

          {/* Question */}
          <div className="surface-card p-8">
            <h2 className="text-2xl font-bold mb-8 text-center" style={{ fontFamily: 'Barlow Condensed' }}>
              {questions[currentQ].question}
            </h2>
            <div className="grid grid-cols-2 gap-4">
              {questions[currentQ].options.map((option, i) => (
                <button
                  key={i}
                  data-testid={`answer-${i}`}
                  onClick={() => answerQuestion(i)}
                  className="surface-card p-6 text-left card-hover text-lg font-medium"
                >
                  <span className="text-cyan-400 mr-3">{['A', 'B', 'C', 'D'][i]}.</span>
                  {option}
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
            <h2 className="text-3xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>CHALLENGE COMPLETE</h2>
            
            <div className="metric-value text-6xl text-cyan-400 mb-2">{score}</div>
            <div className="metric-label mb-8">FINAL SCORE</div>

            <div className="grid grid-cols-2 gap-4 mb-8">
              <div className="bg-black/50 p-4 border border-white/5">
                <div className="metric-value text-2xl text-green-400">{answers.filter(a => a.correct).length}</div>
                <div className="metric-label">Correct</div>
              </div>
              <div className="bg-black/50 p-4 border border-white/5">
                <div className="metric-value text-2xl text-red-400">{answers.filter(a => !a.correct).length}</div>
                <div className="metric-label">Incorrect</div>
              </div>
            </div>

            <button 
              data-testid="play-again"
              onClick={() => setGameState('menu')}
              className="btn-primary text-lg px-12 py-4"
            >
              Play Again
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

// ===================== MAIN DASHBOARD =====================
const Dashboard = () => {
  const [activeTab, setActiveTab] = useState('dashboard');
  const location = useLocation();
  const { user, setUser } = useAuth();

  useEffect(() => {
    // Set user from location state if available
    if (location.state?.user && !user) {
      setUser(location.state.user);
    }
  }, [location.state, user, setUser]);

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard': return <DashboardView setActiveTab={setActiveTab} />;
      case 'scan': return <SystemScanView />;
      case 'games': return <GameModesView />;
      case 'cards': return <CreatorCardsView />;
      case 'coach': return <CoachHubView />;
      case 'education': return <EducationView />;
      case 'brain-brawl': return <BrainBrawlView />;
      default: return <DashboardView setActiveTab={setActiveTab} />;
    }
  };

  return (
    <div className="min-h-screen" style={{ background: 'var(--bg-default)' }}>
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />
      <main className="main-content">
        {renderContent()}
      </main>
    </div>
  );
};

// ===================== APP ROUTER =====================
function AppRouter() {
  const location = useLocation();
  
  // Check URL fragment (not query params) for session_id
  if (location.hash?.includes('session_id=')) {
    return <AuthCallback />;
  }
  
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/dashboard" element={
        <ProtectedRoute>
          <Dashboard />
        </ProtectedRoute>
      } />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

// ===================== MAIN APP =====================
function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRouter />
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
