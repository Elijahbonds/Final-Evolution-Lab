import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { 
  Zap, Activity, Gamepad2, Trophy, Brain, GraduationCap, 
  ChevronRight, ArrowRight, ShieldCheck, Flame, Coins, 
  Cpu, Layers, Sparkles, Database, Code, Globe, Play, HelpCircle,
  Calendar, Clock, Send, Mail, MapPin, CheckCircle, Info, Award, User, X,
  Smartphone
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://127.0.0.1:8000";
const API = `${BACKEND_URL}/api`;

export function LandingPage() {
  const [activeTab, setActiveTab] = useState("simulator");
  
  // Simulator State
  const [selectedMode, setSelectedMode] = useState("basketball_h2h");
  const [performanceScore, setPerformanceScore] = useState(78);
  const [outcome, setOutcome] = useState("win");
  const [isSimulating, setIsSimulating] = useState(false);
  const [simulationResult, setSimulationResult] = useState(null);
  const [comboCount, setComboCount] = useState(4);
  const [criticalCount, setCriticalCount] = useState(2);
  const [pacingScore, setPacingScore] = useState(82);
  const [mriScore, setMriScore] = useState(76);

  // Lead Contact Form State
  const [contactForm, setContactForm] = useState({
    name: "",
    email: "",
    sport: "General",
    level: "Intermediate",
    message: ""
  });
  const [contactStatus, setContactStatus] = useState(null); // null | 'submitting' | 'success' | 'error'
  const [contactError, setContactError] = useState("");
  const [lastLeadId, setLastLeadId] = useState("");

  // Booking Scheduler State
  const [bookingModalOpen, setBookingModalOpen] = useState(false);
  const [selectedPlanForBooking, setSelectedPlanForBooking] = useState(null);
  const [bookingDate, setBookingDate] = useState("");
  const [bookingTime, setBookingTime] = useState("");
  const [bookingDetails, setBookingDetails] = useState({
    name: "",
    email: "",
    phone: ""
  });
  const [bookingStatus, setBookingStatus] = useState(null); // null | 'booking' | 'success' | 'error'
  const [bookingError, setBookingError] = useState("");

  // Payment checkout states
  const [paymentMethod, setPaymentMethod] = useState("card"); // 'card' | 'paypal'
  const [cardDetails, setCardDetails] = useState({
    number: "4242 4242 4242 4242",
    expiry: "12/28",
    cvv: "424"
  });
  const [promoCode, setPromoCode] = useState("");

  // Booking Modal Trigger
  const openBookingModal = (planName) => {
    setSelectedPlanForBooking(planName);
    setBookingModalOpen(true);
    setBookingStatus(null);
    setBookingError("");
    setPaymentMethod("card");
    setPromoCode("");
  };

  const handleDownloadAppClick = () => {
    if (localStorage.getItem("fel_has_purchased") === "true") {
      window.location.href = "/download";
    } else {
      openBookingModal("General Membership & App License");
    }
  };

  // Submit Contact Form
  const handleContactSubmit = async (e) => {
    e.preventDefault();
    if (!contactForm.name || !contactForm.email) {
      setContactStatus("error");
      setContactError("Name and email are required fields.");
      return;
    }
    setContactStatus("submitting");
    setContactError("");
    try {
      const res = await fetch(`${API}/leads`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(contactForm)
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.detail || "Failed to submit lead");
      }
      setContactStatus("success");
      setLastLeadId(data.lead_id);
      setContactForm({ name: "", email: "", sport: "General", level: "Intermediate", message: "" });
    } catch (err) {
      setContactStatus("error");
      setContactError(err.message || "An error occurred during submission.");
    }
  };

  // Submit Booking request as a lead
  const handleBookingSubmit = async (e) => {
    e.preventDefault();
    
    // Check for bypass promo code first
    if (promoCode.toLowerCase().trim() === "igotbounce") {
      setBookingStatus("booking");
      setTimeout(() => {
        localStorage.setItem("fel_has_purchased", "true");
        setBookingStatus("success");
        setPromoCode("");
      }, 1000);
      return;
    }

    if (!bookingDetails.name || !bookingDetails.email || !bookingDate || !bookingTime) {
      setBookingStatus("error");
      setBookingError("All fields except phone are required.");
      return;
    }
    setBookingStatus("booking");
    setBookingError("");
    try {
      const messageBody = `[BOOKING REQUEST] Plan: ${selectedPlanForBooking} | Date: ${bookingDate} | Time: ${bookingTime} | Phone: ${bookingDetails.phone || 'N/A'}`;
      const leadPayload = {
        name: bookingDetails.name,
        email: bookingDetails.email,
        sport: "General",
        level: "Intermediate",
        message: messageBody
      };
      const res = await fetch(`${API}/leads`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(leadPayload)
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.detail || "Failed to submit booking");
      }
      // Set the local license flag on successful booking submit
      localStorage.setItem("fel_has_purchased", "true");
      setBookingStatus("success");
      setBookingDetails({ name: "", email: "", phone: "" });
      setBookingDate("");
      setBookingTime("");
    } catch (err) {
      setBookingStatus("error");
      setBookingError(err.message || "An error occurred while booking.");
    }
  };

  const gameModes = {
    basketball_h2h: { name: "Basketball H2H", weight: 1.2, color: "text-cyan-400", border: "border-cyan-400/30", bg: "bg-cyan-500/10" },
    football: { name: "Football Field", weight: 1.5, color: "text-pink-400", border: "border-pink-400/30", bg: "bg-pink-500/10" },
    golf: { name: "Precision Golf", weight: 0.9, color: "text-emerald-400", border: "border-emerald-400/30", bg: "bg-emerald-500/10" },
    karate: { name: "Karate Dojo", weight: 1.1, color: "text-amber-400", border: "border-amber-400/30", bg: "bg-amber-500/10" },
    brain_brawl: { name: "Brain Brawl Arena", weight: 1.3, color: "text-purple-400", border: "border-purple-400/30", bg: "bg-purple-500/10" }
  };

  const handleLogin = () => {
    window.location.href = window.location.origin + '/login';
  };

  const runSimulation = () => {
    setIsSimulating(true);
    setSimulationResult(null);
    setTimeout(() => {
      const modeData = gameModes[selectedMode];
      
      // 1. Shards Payout Math (P1 spec §6.2)
      let baseShards = 15;
      if (outcome === "win") baseShards = 50;
      else if (outcome === "draw") baseShards = 25;

      const comboBonus = comboCount > 3 ? (comboCount - 3) * 5 : 0;
      const critBonus = criticalCount * 10;
      const subtotal = baseShards + comboBonus + critBonus;
      const pacingBonus = pacingScore >= 75 ? Math.ceil(subtotal * 0.05) : 0;
      const totalShards = subtotal + pacingBonus;

      // 2. XP Math (capped at 500)
      const rawXp = Math.round(performanceScore * 5);
      const xpAwarded = Math.min(rawXp, 500);

      // 3. PRQ Delta Math (P1 spec §6.1)
      const outcomeBase = { win: 2.0, draw: 0.5, loss: 0.2 }[outcome] || 0.2;
      const cBonus = Math.min(1.0, comboCount * 0.05);
      const crBonus = Math.min(0.5, criticalCount * 0.1);
      const domBonus = outcome === "win" ? Math.min(0.5, performanceScore * 0.05) : 0.0;
      const mriBonus = (mriScore / 100) * 0.5;

      const prqDelta = outcomeBase * modeData.weight + cBonus + crBonus + domBonus + mriBonus;
      const roundedPrqDelta = parseFloat(Math.min(100.0, prqDelta).toFixed(2));

      setSimulationResult({
        xp: xpAwarded,
        shards: totalShards,
        prqDelta: roundedPrqDelta,
        capped: rawXp > 500,
        rawXp: rawXp,
        comboBonus,
        critBonus,
        pacingBonus,
        pacingBonusApplied: pacingScore >= 75
      });
      setIsSimulating(false);
    }, 1200);
  };

  return (
    <div className="min-h-screen bg-[#050505] text-white selection:bg-cyan-500 selection:text-black overflow-x-hidden font-sans">
      
      {/* BACKGROUND EFFECTS */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(0,229,255,0.08),transparent_50%)] pointer-events-none"></div>
      <div className="absolute top-[30%] left-[-10%] w-[500px] h-[500px] bg-[radial-gradient(circle,rgba(168,85,247,0.05),transparent_60%)] pointer-events-none blur-3xl"></div>
      
      {/* CYBER GRID HEADER */}
      <div className="border-b border-white/5 bg-black/60 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-cyan-400 flex items-center justify-center rounded-sm shadow-[0_0_15px_rgba(0,229,255,0.4)]">
              <Zap className="w-6 h-6 text-black fill-current" />
            </div>
            <div className="flex flex-col">
              <span className="text-xl font-bold tracking-tight uppercase leading-none" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
                FINAL EVOLUTION LAB
              </span>
              <span className="text-[10px] text-cyan-400 font-mono tracking-widest uppercase">
                Google Cloud Stack
              </span>
            </div>
          </div>
          <div className="hidden lg:flex items-center gap-6 text-xs font-semibold tracking-wider uppercase">
            <a href="#features" className="text-zinc-400 hover:text-cyan-400 transition-colors">Core Systems</a>
            <a href="#simulator" className="text-zinc-400 hover:text-cyan-400 transition-colors">OS Simulator</a>
            <a href="#founder" className="text-zinc-400 hover:text-cyan-400 transition-colors">Founder</a>
            <a href="#programs" className="text-zinc-400 hover:text-cyan-400 transition-colors">Programs & Pricing</a>
            <a href="#events" className="text-zinc-400 hover:text-cyan-400 transition-colors">Events</a>
            <a href="#contact" className="text-zinc-400 hover:text-cyan-400 transition-colors">Contact</a>
          </div>

          <div className="flex items-center gap-4">
            <button 
              data-testid="hero-login-btn"
              onClick={handleLogin}
              className="px-6 py-2.5 bg-cyan-400 hover:bg-cyan-300 text-black font-semibold text-xs tracking-widest uppercase transition-all duration-300 shadow-[0_0_20px_rgba(0,229,255,0.2)] hover:shadow-[0_0_30px_rgba(0,229,255,0.5)] active:scale-95 rounded-sm"
            >
              Enter Lab
            </button>
          </div>
        </div>
      </div>

      {/* HERO SECTION */}
      <section className="relative pt-20 pb-28 border-b border-white/5">
        {/* Subtle Scan Lines */}
        <div className="absolute inset-0 bg-[linear-gradient(rgba(18,16,16,0)_50%,rgba(0,0,0,0.25)_50%),linear-gradient(90deg,rgba(255,0,0,0.06),rgba(0,255,0,0.02),rgba(0,0,255,0.06))] bg-[size:100%_4px,3px_100%] pointer-events-none opacity-20"></div>
        
        <div className="max-w-6xl mx-auto px-6 grid lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-7 space-y-6 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-cyan-400/10 border border-cyan-400/20 text-cyan-400 text-[10px] font-mono tracking-widest uppercase rounded-full">
              <Activity className="w-3.5 h-3.5 animate-pulse" /> Unified Athlete OS
            </div>
            
            <h1 className="text-5xl sm:text-6xl md:text-7xl font-black tracking-tighter uppercase leading-[0.9]" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              YOUR MOVEMENT / <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#5ce1e6] via-[#1e90ff] to-indigo-500 filter drop-shadow-[0_2px_20px_rgba(92,225,230,0.3)]">
                AUDITED IN REAL-TIME
              </span>
            </h1>
            
            <p className="text-zinc-400 text-lg md:text-xl max-w-xl mx-auto lg:mx-0 leading-relaxed font-light">
              Test, don't guess. Final Evolution Lab merges clinical biomechanics with nervous system training to audit movement patterns, accelerate reaction speed, and optimize athletic outputs like vertical jump on a high-fidelity platform.
            </p>

            <div className="flex flex-wrap justify-center lg:justify-start gap-4 pt-4">
              <button 
                data-testid="cta-start-btn" 
                onClick={handleLogin}
                className="px-8 py-4 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-bold text-sm tracking-wider uppercase transition-all duration-300 flex items-center gap-2 rounded-sm group shadow-[0_0_25px_rgba(92,225,230,0.3)]"
              >
                START YOUR EVOLUTION <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </button>
              <a 
                href="#programs"
                className="px-8 py-4 bg-white/5 hover:bg-white/10 text-white font-bold text-sm tracking-wider uppercase transition-all duration-300 border border-white/10 hover:border-white/20 rounded-sm flex items-center gap-2"
              >
                EXPLORE PROGRAMS
              </a>
              <button
                onClick={handleDownloadAppClick}
                className="px-8 py-4 bg-transparent hover:bg-white/5 text-[#5ce1e6] font-bold text-sm tracking-wider uppercase transition-all duration-300 border border-[#5ce1e6]/30 hover:border-[#5ce1e6]/60 rounded-sm flex items-center gap-2"
              >
                <Smartphone className="w-4 h-4" /> DOWNLOAD APP
              </button>
            </div>

            {/* Quick Metrics */}
            <div className="grid grid-cols-3 gap-6 pt-12 border-t border-white/5 max-w-md mx-auto lg:mx-0">
              <div>
                <div className="text-3xl font-bold tracking-tight text-white font-mono">17</div>
                <div className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono mt-1">Playable Modes</div>
              </div>
              <div>
                <div className="text-3xl font-bold tracking-tight text-cyan-400 font-mono">0ms</div>
                <div className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono mt-1">Wix Latency</div>
              </div>
              <div>
                <div className="text-3xl font-bold tracking-tight text-indigo-400 font-mono">100%</div>
                <div className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono mt-1">Google Stack</div>
              </div>
            </div>
          </div>

          <div className="lg:col-span-5 relative">
            {/* Visual Glassmorphic HUD Widget */}
            <div className="relative z-10 border border-white/10 rounded-lg p-6 bg-gradient-to-br from-[#0F0F13]/90 to-[#0A0A0C]/90 backdrop-blur-xl shadow-2xl space-y-6">
              <div className="flex items-center justify-between border-b border-white/5 pb-4">
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 bg-cyan-400 rounded-full animate-ping"></span>
                  <span className="text-xs font-mono text-cyan-400 tracking-wider">LIVE ATHLETE STREAM</span>
                </div>
                <span className="text-[10px] text-zinc-500 font-mono">NODE_US_EAST</span>
              </div>

              {/* Simulated Health Ring */}
              <div className="flex items-center justify-center py-4">
                <div className="relative w-44 h-44">
                  <svg className="w-full h-full" viewBox="0 0 100 100">
                    <circle cx="50" cy="50" r="42" fill="none" stroke="rgba(255,255,255,0.03)" strokeWidth="6" />
                    <circle cx="50" cy="50" r="42" fill="none" stroke="url(#cyanGradient)" strokeWidth="6" strokeLinecap="round" strokeDasharray="210 264" transform="rotate(-90 50 50)" />
                  </svg>
                  <div className="absolute inset-0 flex flex-col items-center justify-center">
                    <span className="text-4xl font-extrabold font-mono tracking-tighter">89.4</span>
                    <span className="text-[10px] text-zinc-500 font-mono tracking-widest uppercase">PRQ INDEX</span>
                  </div>
                </div>
              </div>

              <div className="space-y-3 font-mono text-xs">
                <div className="flex justify-between p-2.5 bg-white/5 rounded border border-white/5">
                  <span className="text-zinc-400">ACTIVATED MODE</span>
                  <span className="text-cyan-400 font-bold">BASKETBALL_H2H</span>
                </div>
                <div className="flex justify-between p-2.5 bg-white/5 rounded border border-white/5">
                  <span className="text-zinc-400">SHARDS EARNED</span>
                  <span className="text-yellow-400 font-bold">+50 SHARDS</span>
                </div>
                <div className="flex justify-between p-2.5 bg-white/5 rounded border border-white/5">
                  <span className="text-zinc-400">DATABASE LATENCY</span>
                  <span className="text-emerald-400 font-bold">~1.4ms (SQL)</span>
                </div>
              </div>
            </div>
            {/* Glowing aura background behind the widget */}
            <div className="absolute inset-0 -m-4 bg-gradient-to-br from-cyan-500/20 to-purple-500/20 rounded-xl blur-3xl pointer-events-none z-0"></div>
          </div>
        </div>
      </section>

      {/* CORE FEATURES SECTION */}
      <section id="features" className="py-24 border-b border-white/5 bg-black/20">
        <div className="max-w-6xl mx-auto px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-4">
            <span className="overline">Core Architecture</span>
            <h2 className="text-4xl sm:text-5xl font-extrabold uppercase" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              One Unified Platform. No Add-Ons.
            </h2>
            <p className="text-zinc-400 font-light">
              By transitioning away from Wix, we built an integrated arena where every component feeds the same telemetry database instantly.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            
            {/* CARD 1 */}
            <div className="p-8 border border-white/10 bg-[#0F0F13]/55 hover:border-cyan-400/30 transition-all duration-300 rounded relative group">
              <div className="w-12 h-12 bg-cyan-400/10 flex items-center justify-center text-cyan-400 rounded mb-6 group-hover:scale-110 transition-transform">
                <Gamepad2 className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold uppercase mb-2 font-mono">17 Game Modes</h3>
              <p className="text-zinc-400 text-sm leading-relaxed">
                Play soccer, basketball, boxing, surfing, and karate. Build performance data points directly on client devices, bypassing intermediate web builders.
              </p>
            </div>

            {/* CARD 2 */}
            <div className="p-8 border border-white/10 bg-[#0F0F13]/55 hover:border-purple-400/30 transition-all duration-300 rounded relative group">
              <div className="w-12 h-12 bg-purple-400/10 flex items-center justify-center text-purple-400 rounded mb-6 group-hover:scale-110 transition-transform">
                <Brain className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold uppercase mb-2 font-mono">AI Coach Critique</h3>
              <p className="text-zinc-400 text-sm leading-relaxed">
                Uses the integrated Google Gemini model to analyze physical telemetry, workout forms, and provide tactical recommendations inside the app wrapper.
              </p>
            </div>

            {/* CARD 3 */}
            <div className="p-8 border border-white/10 bg-[#0F0F13]/55 hover:border-emerald-400/30 transition-all duration-300 rounded relative group">
              <div className="w-12 h-12 bg-emerald-400/10 flex items-center justify-center text-emerald-400 rounded mb-6 group-hover:scale-110 transition-transform">
                <Trophy className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold uppercase mb-2 font-mono">Balanced Economy</h3>
              <p className="text-zinc-400 text-sm leading-relaxed">
                Integrated database triggers write direct transaction receipts. XP calculations are capped at 500 per session to avoid hyper-inflation.
              </p>
            </div>

            {/* CARD 4 */}
            <div className="p-8 border border-white/10 bg-[#0F0F13]/55 hover:border-pink-400/30 transition-all duration-300 rounded relative group">
              <div className="w-12 h-12 bg-pink-400/10 flex items-center justify-center text-pink-400 rounded mb-6 group-hover:scale-110 transition-transform">
                <Activity className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold uppercase mb-2 font-mono">Biometric Scans</h3>
              <p className="text-zinc-400 text-sm leading-relaxed">
                Sync iOS HealthKit telemetry, avatar dimensions, and daily workout logs instantly into a secure JSONB schema hosted on Google Cloud SQL.
              </p>
            </div>

            {/* CARD 5 */}
            <div className="p-8 border border-white/10 bg-[#0F0F13]/55 hover:border-amber-400/30 transition-all duration-300 rounded relative group">
              <div className="w-12 h-12 bg-amber-400/10 flex items-center justify-center text-amber-400 rounded mb-6 group-hover:scale-110 transition-transform">
                <GraduationCap className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold uppercase mb-2 font-mono">Academic Track</h3>
              <p className="text-zinc-400 text-sm leading-relaxed">
                Earn physical science credits and certificates linked directly to kinesiology benchmarks, mapped automatically to student profiles.
              </p>
            </div>

            {/* CARD 6 */}
            <div className="p-8 border border-white/10 bg-[#0F0F13]/55 hover:border-blue-400/30 transition-all duration-300 rounded relative group">
              <div className="w-12 h-12 bg-blue-400/10 flex items-center justify-center text-blue-400 rounded mb-6 group-hover:scale-110 transition-transform">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold uppercase mb-2 font-mono">Vault Control</h3>
              <p className="text-zinc-400 text-sm leading-relaxed">
                Complete data custody. Verify game scores, session hashes, and critique logs cryptographically using standard cloud structures.
              </p>
            </div>

          </div>
        </div>
      </section>

      {/* INTERACTIVE SIMULATOR */}
      <section id="simulator" className="py-24 border-b border-white/5 relative">
        <div className="max-w-6xl mx-auto px-6">
          <div className="grid lg:grid-cols-12 gap-12 items-center">
            
            <div className="lg:col-span-5 space-y-6">
              <span className="overline text-indigo-400">Live OS Test</span>
              <h2 className="text-4xl sm:text-5xl font-extrabold uppercase leading-tight" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
                Interactive Game Payout Simulator
              </h2>
              <p className="text-zinc-400 font-light leading-relaxed">
                Experience the game session arithmetic compiled directly in our backend. Select a game mode to fetch its mathematical PRQ delta weight, adjust your performance score, and simulate the database commit.
              </p>
              
              <div className="p-4 border border-zinc-800 bg-[#0B0B0D] rounded space-y-3 font-mono text-xs">
                <div className="flex items-center gap-2 text-cyan-400">
                  <Database className="w-4 h-4" />
                  <span>SESSION METRICS RULESET</span>
                </div>
                <ul className="space-y-1.5 text-zinc-500">
                  <li>• Win: +50 Shards | Loss: +15 | Draw: +25</li>
                  <li>• XP Cap: Hard capped at exactly 500 XP</li>
                  <li>• PRQ Weight: Mode Weight * Outcome Factor</li>
                </ul>
              </div>
            </div>

            <div className="lg:col-span-7 bg-[#0F0F13]/90 border border-white/10 rounded-lg p-8 relative overflow-hidden shadow-2xl">
              <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl from-cyan-500/10 to-transparent pointer-events-none"></div>
              
              {/* Header */}
              <div className="flex justify-between items-center border-b border-white/5 pb-4 mb-6">
                <div className="flex items-center gap-2 font-mono text-xs">
                  <Cpu className="w-4 h-4 text-cyan-400" />
                  <span className="text-zinc-400">CALCULATION NODE // PORT 8000</span>
                </div>
                <div className="flex gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-red-500/30"></span>
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500/30"></span>
                  <span className="w-2.5 h-2.5 rounded-full bg-green-500/30"></span>
                </div>
              </div>

              {/* Selection Controls */}
              <div className="grid md:grid-cols-2 gap-6 mb-6">
                
                {/* Game Mode Choice */}
                <div className="space-y-2">
                  <label className="text-xs font-mono text-zinc-400 uppercase">Select Game Mode</label>
                  <div className="grid grid-cols-1 gap-2">
                    {Object.entries(gameModes).map(([key, mode]) => (
                      <button
                        key={key}
                        onClick={() => { setSelectedMode(key); setSimulationResult(null); }}
                        className={`flex items-center justify-between p-3 rounded border text-sm font-mono transition-all ${
                          selectedMode === key 
                            ? "bg-white/5 border-cyan-400 text-white shadow-[0_0_10px_rgba(0,229,255,0.05)]" 
                            : "border-white/5 text-zinc-400 hover:border-white/10 hover:text-white"
                        }`}
                      >
                        <div className="flex items-center gap-2">
                          <span className={`w-1.5 h-1.5 rounded-full ${selectedMode === key ? 'bg-cyan-400' : 'bg-zinc-600'}`}></span>
                          <span>{mode.name}</span>
                        </div>
                        <span className="text-[10px] text-zinc-500">w{mode.weight}</span>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Outcome & Performance slider */}
                <div className="space-y-6">
                  
                  {/* Outcome select */}
                  <div className="space-y-2">
                    <label className="text-xs font-mono text-zinc-400 uppercase">Outcome</label>
                    <div className="grid grid-cols-3 gap-2">
                      {["win", "draw", "loss"].map((o) => (
                        <button
                          key={o}
                          onClick={() => { setOutcome(o); setSimulationResult(null); }}
                          className={`py-2 rounded text-xs font-mono uppercase border transition-all ${
                            outcome === o 
                              ? "bg-cyan-400/10 border-cyan-400/40 text-cyan-400 font-bold" 
                              : "border-white/5 text-zinc-500 hover:border-white/10 hover:text-zinc-400"
                          }`}
                        >
                          {o}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Performance Slider */}
                  <div className="space-y-2">
                    <div className="flex justify-between items-center text-xs font-mono">
                      <span className="text-zinc-400 uppercase">Athlete Score</span>
                      <span className="text-cyan-400 font-bold">{performanceScore}%</span>
                    </div>
                    <input
                      type="range"
                      min="10"
                      max="100"
                      value={performanceScore}
                      onChange={(e) => { setPerformanceScore(parseInt(e.target.value)); setSimulationResult(null); }}
                      className="w-full accent-cyan-400 h-1 bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                    />
                  </div>

                  {/* Combo Count Slider */}
                  <div className="space-y-2">
                    <div className="flex justify-between items-center text-xs font-mono">
                      <span className="text-zinc-400 uppercase">Combos (Hits)</span>
                      <span className="text-cyan-400 font-bold">{comboCount}</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="15"
                      value={comboCount}
                      onChange={(e) => { setComboCount(parseInt(e.target.value)); setSimulationResult(null); }}
                      className="w-full accent-cyan-400 h-1 bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                    />
                  </div>

                  {/* Critical Strikes Slider */}
                  <div className="space-y-2">
                    <div className="flex justify-between items-center text-xs font-mono">
                      <span className="text-zinc-400 uppercase">Critical Strikes</span>
                      <span className="text-cyan-400 font-bold">{criticalCount}</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="10"
                      value={criticalCount}
                      onChange={(e) => { setCriticalCount(parseInt(e.target.value)); setSimulationResult(null); }}
                      className="w-full accent-cyan-400 h-1 bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                    />
                  </div>

                  {/* Pacing Score Slider */}
                  <div className="space-y-2">
                    <div className="flex justify-between items-center text-xs font-mono">
                      <span className="text-zinc-400 uppercase font-semibold">Pacing Score (sub-bonus)</span>
                      <span className={`font-bold ${pacingScore >= 75 ? 'text-green-400' : 'text-zinc-400'}`}>{pacingScore}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={pacingScore}
                      onChange={(e) => { setPacingScore(parseInt(e.target.value)); setSimulationResult(null); }}
                      className="w-full accent-cyan-400 h-1 bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                    />
                  </div>

                  {/* MRI Resiliency Score Slider */}
                  <div className="space-y-2">
                    <div className="flex justify-between items-center text-xs font-mono">
                      <span className="text-zinc-400 uppercase">Mental Resiliency (MRI)</span>
                      <span className="text-cyan-400 font-bold">{mriScore}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={mriScore}
                      onChange={(e) => { setMriScore(parseInt(e.target.value)); setSimulationResult(null); }}
                      className="w-full accent-cyan-400 h-1 bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                    />
                  </div>

                  <button
                    onClick={runSimulation}
                    disabled={isSimulating}
                    className="w-full py-3.5 bg-cyan-400 hover:bg-cyan-300 disabled:bg-zinc-800 disabled:text-zinc-600 text-black font-extrabold text-xs tracking-widest uppercase transition-all rounded shadow-[0_4px_12px_rgba(0,229,255,0.1)] flex items-center justify-center gap-2"
                  >
                    {isSimulating ? (
                      <>
                        <div className="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin"></div>
                        <span>Evaluating Metrics...</span>
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4 fill-current" />
                        <span>Run Session Simulator</span>
                      </>
                    )}
                  </button>
                </div>
              </div>

              {/* Results Display */}
              <div className="border-t border-white/5 pt-6 min-h-[140px] flex items-center justify-center">
                {simulationResult ? (
                  <div className="w-full grid grid-cols-1 md:grid-cols-3 gap-4 font-mono">
                    
                    {/* XP Receipt */}
                    <div className="p-4 border border-zinc-800 bg-[#070709] rounded relative overflow-hidden">
                      <div className="text-[10px] text-zinc-500 uppercase tracking-wider">XP Awarded</div>
                      <div className="text-3xl font-bold text-white mt-1 flex items-baseline gap-1">
                        <span>{simulationResult.xp}</span>
                        <span className="text-xs text-zinc-500">XP</span>
                      </div>
                      {simulationResult.capped && (
                        <div className="absolute top-2 right-2 text-[8px] bg-red-500/10 border border-red-500/20 text-red-400 px-1.5 py-0.5 rounded font-mono">
                          MAX CAPPED (500)
                        </div>
                      )}
                      <div className="text-[9px] text-zinc-600 mt-2">
                        Raw calculated: {simulationResult.rawXp}
                      </div>
                    </div>

                    {/* Shards Receipt */}
                    {/* Shards Receipt */}
                    <div className="p-4 border border-zinc-800 bg-[#070709] rounded relative">
                      <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Economy Shards</div>
                      <div className="text-3xl font-bold text-yellow-400 mt-1 flex items-baseline gap-1">
                        <span>+{simulationResult.shards}</span>
                        <Coins className="w-4 h-4 text-yellow-400 self-center" />
                      </div>
                      <div className="text-[9px] text-zinc-500 mt-2 space-y-0.5 font-mono">
                        <div>Base: {outcome === 'win' ? '50' : outcome === 'draw' ? '25' : '15'}</div>
                        {simulationResult.comboBonus > 0 && <div className="text-[#5ce1e6]">Combo: +{simulationResult.comboBonus}</div>}
                        {simulationResult.critBonus > 0 && <div className="text-purple-400 font-semibold">Critical: +{simulationResult.critBonus}</div>}
                        {simulationResult.pacingBonus > 0 && <div className="text-green-400 font-bold">Pacing (5%): +{simulationResult.pacingBonus}</div>}
                      </div>
                    </div>

                    {/* PRQ delta */}
                    <div className="p-4 border border-zinc-800 bg-[#070709] rounded">
                      <div className="text-[10px] text-zinc-500 uppercase tracking-wider">PRQ Score Delta</div>
                      <div className="text-3xl font-bold text-emerald-400 mt-1">
                        +{simulationResult.prqDelta}
                      </div>
                      <div className="text-[9px] text-zinc-500 mt-2 space-y-0.5 font-mono">
                        <div>Weight: {gameModes[selectedMode].weight}x</div>
                        <div>Base: {({ win: 2.0, draw: 0.5, loss: 0.2 }[outcome] || 0.2).toFixed(1)}</div>
                        <div>MRI Factor: +{((mriScore / 100) * 0.5).toFixed(2)}</div>
                      </div>
                    </div>

                  </div>
                ) : (
                  <div className="text-zinc-600 text-xs font-mono text-center flex flex-col items-center gap-2">
                    <HelpCircle className="w-6 h-6 text-zinc-700" />
                    <span>Run the simulation to calculate XP, Shards, and performance indicators</span>
                  </div>
                )}
              </div>

            </div>

          </div>
        </div>
      </section>

      {/* FOUNDER PROFILE SECTION */}
      <section id="founder" className="py-24 border-b border-white/5 bg-black/40">
        <div className="max-w-6xl mx-auto px-6">
          <div className="grid lg:grid-cols-12 gap-12 items-center">
            
            <div className="lg:col-span-5 relative">
              <div className="border border-white/10 rounded-sm overflow-hidden bg-[#0F0F13] relative group shadow-2xl">
                <img 
                  src="https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=600&auto=format&fit=crop" 
                  alt="Elijah Bonds - Founder" 
                  className="w-full h-[450px] object-cover filter grayscale contrast-125 hover:grayscale-0 transition-all duration-700"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black via-black/30 to-transparent"></div>
                <div className="absolute bottom-6 left-6 right-6 space-y-1">
                  <div className="text-[10px] text-[#5ce1e6] font-mono tracking-widest uppercase">FOUNDER & HEAD OF KINESIOLOGY</div>
                  <h3 className="text-2xl font-bold uppercase tracking-tight font-sans">Elijah Bonds</h3>
                  <div className="flex flex-wrap gap-1.5 pt-2">
                    {["FMS", "SFMA", "CES", "PES", "NESTA Biomechanics"].map((cred) => (
                      <span key={cred} className="px-2 py-0.5 bg-[#5ce1e6]/10 border border-[#5ce1e6]/20 text-[#5ce1e6] text-[9px] font-mono rounded-none">
                        {cred}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
              <div className="absolute inset-0 -m-4 bg-gradient-to-tr from-[#1e90ff]/10 to-transparent rounded-sm blur-3xl pointer-events-none z-0"></div>
            </div>

            <div className="lg:col-span-7 space-y-6">
              <span className="overline text-[#5ce1e6] font-mono">Expertise & Philosophy</span>
              <h2 className="text-4xl sm:text-5xl font-extrabold uppercase leading-tight" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
                Test, Don't Guess.
              </h2>
              <p className="text-zinc-300 font-light leading-relaxed text-base">
                Scattered e-commerce templates and generic fitness routines fail to address unique physical structures. Final Evolution Lab was founded on a strict, clinical approach to athletic progression: auditing the nervous system and biomechanics first.
              </p>
              <p className="text-zinc-400 font-light leading-relaxed text-sm">
                Elijah Bonds combines certifications in Functional Movement Screening (FMS), Selective Functional Movement Assessment (SFMA), and neuroscience coaching to analyze joint deviations, reaction rate thresholds, and ground reaction forces. We identify and isolate movement leaks, helping athletes optimize their vertical jump, agility, and injury resilience.
              </p>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4">
                <div className="p-4 border border-white/5 bg-[#0F0F13] flex gap-3">
                  <div className="w-10 h-10 bg-[#5ce1e6]/10 flex items-center justify-center text-[#5ce1e6] shrink-0">
                    <Activity className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold uppercase font-mono text-white">Biomechanical Precision</h4>
                    <p className="text-xs text-zinc-500 mt-1">Isolating joint angles and kinematics to remove movement inefficiencies.</p>
                  </div>
                </div>
                
                <div className="p-4 border border-white/5 bg-[#0F0F13] flex gap-3">
                  <div className="w-10 h-10 bg-[#1e90ff]/10 flex items-center justify-center text-[#1e90ff] shrink-0">
                    <Brain className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold uppercase font-mono text-white">Neuro-Agility Audits</h4>
                    <p className="text-xs text-zinc-500 mt-1">Measuring cognitive load, eye-tracking reaction times, and CNS readiness.</p>
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* PROGRAMS & PRICING SECTION */}
      <section id="programs" className="py-24 border-b border-white/5 bg-black/20">
        <div className="max-w-6xl mx-auto px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-4">
            <span className="overline text-[#5ce1e6] font-mono">Structured Training Pathways</span>
            <h2 className="text-4xl sm:text-5xl font-extrabold uppercase" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              Programs & Pricing
            </h2>
            <p className="text-zinc-400 font-light">
              Choose an entry track designed to audit your biomechanics and build structured physical and cognitive capacity.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            
            {/* PLAN 1 */}
            <div className="border border-white/10 bg-[#0F0F13] flex flex-col justify-between p-8 rounded-none relative group hover:border-[#1e90ff]/30 transition-all duration-300">
              <div className="space-y-6">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="text-xl font-bold uppercase tracking-tight text-white">Vault Membership</h3>
                    <p className="text-[10px] text-zinc-500 font-mono mt-1">MONTHLY OS ACCESS</p>
                  </div>
                  <span className="px-2 py-0.5 bg-white/5 border border-white/10 text-zinc-400 text-[9px] font-mono">POPULAR</span>
                </div>
                
                <div className="flex items-baseline gap-1.5 border-b border-white/5 pb-6">
                  <span className="text-4xl font-extrabold font-mono text-white">$49</span>
                  <span className="text-xs text-zinc-500 uppercase tracking-widest font-mono">/ Month</span>
                </div>

                <ul className="space-y-3.5 text-xs text-zinc-400">
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Complete Athlete OS Dashboard Access</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Real-time local game telemetry sync</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Biometric scan logs (HealthKit integration)</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Base shard payout multipliers</span>
                  </li>
                </ul>
              </div>

              <div className="pt-8">
                <button 
                  onClick={() => openBookingModal("Vault Membership Setup")}
                  className="w-full py-3 bg-white/5 hover:bg-white/10 border border-white/10 text-white font-bold text-xs tracking-widest uppercase transition-all rounded-none"
                >
                  Enroll Now
                </button>
              </div>
            </div>

            {/* PLAN 2 */}
            <div className="border border-[#5ce1e6]/30 bg-[#0F0F13] flex flex-col justify-between p-8 rounded-none relative group hover:border-[#5ce1e6]/60 transition-all duration-300 shadow-[0_0_30px_rgba(92,225,230,0.05)]">
              <div className="absolute top-0 right-8 transform -translate-y-1/2 px-3 py-1 bg-[#5ce1e6] text-black text-[9px] font-extrabold tracking-widest uppercase rounded-sm">
                RECOMMENDED
              </div>
              <div className="space-y-6">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="text-xl font-bold uppercase tracking-tight text-white">Elite Athletic Audit</h3>
                    <p className="text-[10px] text-[#5ce1e6] font-mono mt-1">ONE-TIME COMPREHENSIVE SCAN</p>
                  </div>
                </div>
                
                <div className="flex items-baseline gap-1.5 border-b border-white/5 pb-6">
                  <span className="text-4xl font-extrabold font-mono text-white">$199</span>
                  <span className="text-xs text-zinc-500 uppercase tracking-widest font-mono">One-Time</span>
                </div>

                <ul className="space-y-3.5 text-xs text-zinc-400">
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Full visual movement audit with joint angle mapping</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>1-on-1 performance review with Elijah Bonds</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Identified movement leaks & corrective exercises</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Postgres session audit receipt registration</span>
                  </li>
                </ul>
              </div>

              <div className="pt-8">
                <button 
                  onClick={() => openBookingModal("Elite Athletic Audit")}
                  className="w-full py-3 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-extrabold text-xs tracking-widest uppercase transition-all rounded-none shadow-[0_0_20px_rgba(92,225,230,0.2)]"
                >
                  Book Session
                </button>
              </div>
            </div>

            {/* PLAN 3 */}
            <div className="border border-white/10 bg-[#0F0F13] flex flex-col justify-between p-8 rounded-none relative group hover:border-[#1e90ff]/30 transition-all duration-300">
              <div className="space-y-6">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="text-xl font-bold uppercase tracking-tight text-white">Neuro-Athletic Accelerator</h3>
                    <p className="text-[10px] text-zinc-500 font-mono mt-1">MONTHLY INTENSIVE COACHING</p>
                  </div>
                </div>
                
                <div className="flex items-baseline gap-1.5 border-b border-white/5 pb-6">
                  <span className="text-4xl font-extrabold font-mono text-white">$99</span>
                  <span className="text-xs text-zinc-500 uppercase tracking-widest font-mono">/ Month</span>
                </div>

                <ul className="space-y-3.5 text-xs text-zinc-400">
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Agility, cognitive load & reaction threshold coaching</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Biweekly central nervous system readiness logs</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Personalized nutrition & BioFuel target structures</span>
                  </li>
                  <li className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 text-[#5ce1e6] shrink-0" />
                    <span>Direct messaging support with Head Coach</span>
                  </li>
                </ul>
              </div>

              <div className="pt-8">
                <button 
                  onClick={() => openBookingModal("Neuro-Athletic Accelerator")}
                  className="w-full py-3 bg-white/5 hover:bg-white/10 border border-white/10 text-white font-bold text-xs tracking-widest uppercase transition-all rounded-none"
                >
                  Book Accelerator
                </button>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* EVENTS & SEMINARS SECTION */}
      <section id="events" className="py-24 border-b border-white/5 bg-black/40">
        <div className="max-w-6xl mx-auto px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-4">
            <span className="overline text-[#1e90ff] font-mono">Live Labs & Exhibits</span>
            <h2 className="text-4xl sm:text-5xl font-extrabold uppercase" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              Upcoming Events
            </h2>
            <p className="text-zinc-400 font-light">
              Participate in our physical audits, dunk shows, and seminars. See biomechanical science live in action.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-8">
            
            {/* EVENT 1 */}
            <div className="p-8 border border-white/5 bg-[#0F0F13] rounded-none hover:border-[#5ce1e6]/30 transition-all duration-300 flex flex-col md:flex-row gap-6 relative">
              <div className="md:w-28 shrink-0 flex flex-col items-center justify-center p-4 border border-[#5ce1e6]/20 bg-[#5ce1e6]/5 text-center h-28 self-start">
                <span className="text-3xl font-black font-mono text-[#5ce1e6]">15</span>
                <span className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono">JUN 2026</span>
              </div>
              <div className="space-y-4 flex-1">
                <div className="space-y-1">
                  <span className="px-2 py-0.5 bg-[#5ce1e6]/10 border border-[#5ce1e6]/20 text-[#5ce1e6] text-[8px] font-mono uppercase tracking-widest">Live Exhibition</span>
                  <h3 className="text-2xl font-bold uppercase tracking-tight text-white mt-1">Dunk Shows w/ The Hoopbus</h3>
                </div>
                <p className="text-xs text-zinc-400 leading-relaxed">
                  Join us at Venice Beach Courts for a high-flying dunk exhibition. Watch elite jumpers perform with live telemetry body sensor feeds projected in real-time.
                </p>
                <div className="flex flex-wrap gap-x-6 gap-y-2 text-[10px] text-zinc-500 font-mono pt-2 border-t border-white/5">
                  <span className="flex items-center gap-1.5"><Clock className="w-3.5 h-3.5 text-zinc-600" /> 6:00 PM - 9:00 PM</span>
                  <span className="flex items-center gap-1.5"><MapPin className="w-3.5 h-3.5 text-zinc-600" /> Venice Beach Courts, CA</span>
                </div>
                <button 
                  onClick={() => openBookingModal("RSVP: Hoopbus Dunk Show")}
                  className="mt-2 text-xs font-bold text-[#5ce1e6] hover:text-[#4dd0d5] uppercase tracking-wider flex items-center gap-1.5 transition-colors"
                >
                  Register Free Interest <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

            {/* EVENT 2 */}
            <div className="p-8 border border-white/5 bg-[#0F0F13] rounded-none hover:border-[#1e90ff]/30 transition-all duration-300 flex flex-col md:flex-row gap-6 relative">
              <div className="md:w-28 shrink-0 flex flex-col items-center justify-center p-4 border border-[#1e90ff]/20 bg-[#1e90ff]/5 text-center h-28 self-start">
                <span className="text-3xl font-black font-mono text-[#1e90ff]">02</span>
                <span className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono">JUL 2026</span>
              </div>
              <div className="space-y-4 flex-1">
                <div className="space-y-1">
                  <span className="px-2 py-0.5 bg-[#1e90ff]/10 border border-[#1e90ff]/20 text-[#1e90ff] text-[8px] font-mono uppercase tracking-widest">Seminar</span>
                  <h3 className="text-2xl font-bold uppercase tracking-tight text-white mt-1">Athletic Development Seminar</h3>
                </div>
                <p className="text-xs text-zinc-400 leading-relaxed">
                  A full-day masterclass on biomechanics and neuroscience auditing. Elijah Bonds will breakdown stance stability, valgus traps, and reactiveness limits.
                </p>
                <div className="flex flex-wrap gap-x-6 gap-y-2 text-[10px] text-zinc-500 font-mono pt-2 border-t border-white/5">
                  <span className="flex items-center gap-1.5"><Clock className="w-3.5 h-3.5 text-zinc-600" /> 10:00 AM - 4:00 PM</span>
                  <span className="flex items-center gap-1.5"><MapPin className="w-3.5 h-3.5 text-zinc-600" /> Final Evolution HQ, CA</span>
                </div>
                <button 
                  onClick={() => openBookingModal("RSVP: Athletic Seminar")}
                  className="mt-2 text-xs font-bold text-[#1e90ff] hover:text-white uppercase tracking-wider flex items-center gap-1.5 transition-colors"
                >
                  Reserve Passes <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* LEAD-GENERATION CONTACT FORM SECTION */}
      <section id="contact" className="py-24 border-b border-white/5 relative">
        <div className="max-w-6xl mx-auto px-6">
          <div className="grid lg:grid-cols-12 gap-12 items-start">
            
            <div className="lg:col-span-5 space-y-6">
              <span className="overline text-[#5ce1e6] font-mono">Transmission Node</span>
              <h2 className="text-4xl sm:text-5xl font-extrabold uppercase leading-tight" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
                Submit Your Telemetry Intent
              </h2>
              <p className="text-zinc-400 font-light leading-relaxed text-sm">
                Have questions about program placements, booking custom group seminars, or integrations? Fill out the secure contact request form. Elijah Bonds and our kinesiologists will review your goals and schedule a diagnostic call.
              </p>
              
              <div className="space-y-4">
                <div className="flex items-center gap-3 text-xs font-mono text-zinc-500">
                  <Mail className="w-4 h-4 text-[#5ce1e6]" />
                  <span>support@finalevolutiongroup.com</span>
                </div>
                <div className="flex items-center gap-3 text-xs font-mono text-zinc-500">
                  <ShieldCheck className="w-4 h-4 text-[#1e90ff]" />
                  <span>Secure 256-bit Database encryption</span>
                </div>
              </div>
            </div>

            <div className="lg:col-span-7 bg-[#0F0F13] border border-white/10 p-8 rounded-none relative shadow-2xl">
              <form onSubmit={handleContactSubmit} className="space-y-6">
                
                <div className="grid md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Full Name *</label>
                    <input 
                      type="text" 
                      required
                      placeholder="e.g. Amir Smith"
                      value={contactForm.name}
                      onChange={(e) => setContactForm({ ...contactForm, name: e.target.value })}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm placeholder:text-zinc-600 transition-colors"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Email Address *</label>
                    <input 
                      type="email" 
                      required
                      placeholder="e.g. athlete@domain.com"
                      value={contactForm.email}
                      onChange={(e) => setContactForm({ ...contactForm, email: e.target.value })}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm placeholder:text-zinc-600 transition-colors"
                    />
                  </div>
                </div>

                <div className="grid md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Focus Sport</label>
                    <select 
                      value={contactForm.sport}
                      onChange={(e) => setContactForm({ ...contactForm, sport: e.target.value })}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm transition-colors cursor-pointer"
                    >
                      <option value="General">General Biomechanics</option>
                      <option value="Basketball">Basketball</option>
                      <option value="Football">Football / Soccer</option>
                      <option value="Golf">Precision Golf</option>
                      <option value="Combat Sports">Combat Sports / Dojo</option>
                      <option value="Track & Field">Track & Field</option>
                    </select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Performance Level</label>
                    <select 
                      value={contactForm.level}
                      onChange={(e) => setContactForm({ ...contactForm, level: e.target.value })}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm transition-colors cursor-pointer"
                    >
                      <option value="Amateur">Amateur / Recreational</option>
                      <option value="Collegiate">Collegiate Athlete</option>
                      <option value="Professional">Professional</option>
                      <option value="Elite">Elite / Olympic Candidate</option>
                    </select>
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Tell Us About Your Goals</label>
                  <textarea 
                    rows="4"
                    placeholder="Describe vertical jump targets, reaction time limits, or history of movement imbalances..."
                    value={contactForm.message}
                    onChange={(e) => setContactForm({ ...contactForm, message: e.target.value })}
                    className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm placeholder:text-zinc-600 transition-colors"
                  ></textarea>
                </div>

                {contactStatus === 'success' && (
                  <div className="p-4 border border-[#00FF9D]/30 bg-[#00FF9D]/5 rounded-none flex items-start gap-3">
                    <CheckCircle className="w-5 h-5 text-[#00FF9D] shrink-0 mt-0.5" />
                    <div>
                      <h4 className="text-sm font-bold font-mono text-white">TRANSMISSION SECURED</h4>
                      <p className="text-xs text-zinc-400 mt-1">Lead ID: <span className="text-[#00FF9D] font-mono">{lastLeadId}</span>. Elijah Bonds has received your request and will contact you shortly.</p>
                    </div>
                  </div>
                )}

                {contactStatus === 'error' && (
                  <div className="p-4 border border-red-500/30 bg-red-500/5 rounded-none flex items-start gap-3">
                    <Info className="w-5 h-5 text-red-500 shrink-0 mt-0.5" />
                    <div>
                      <h4 className="text-sm font-bold font-mono text-white">TRANSMISSION ERROR</h4>
                      <p className="text-xs text-zinc-400 mt-1">{contactError}</p>
                    </div>
                  </div>
                )}

                <button 
                  type="submit" 
                  disabled={contactStatus === 'submitting'}
                  className="w-full py-4 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-extrabold text-xs tracking-widest uppercase transition-all rounded-none flex items-center justify-center gap-2 shadow-[0_0_20px_rgba(92,225,230,0.15)] disabled:bg-zinc-800 disabled:text-zinc-500"
                >
                  {contactStatus === 'submitting' ? (
                    <>
                      <div className="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin"></div>
                      <span>Broadcasting Lead Payload...</span>
                    </>
                  ) : (
                    <>
                      <Send className="w-4 h-4" />
                      <span>Transmit Request</span>
                    </>
                  )}
                </button>

              </form>
            </div>

          </div>
        </div>
      </section>

      {/* BOOKING SCHEDULER MODAL */}
      {bookingModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fade-in">
          <div className="relative w-full max-w-lg border border-white/10 bg-[#0F0F13] p-8 shadow-2xl space-y-6">
            
            {/* Close Button */}
            <button 
              onClick={() => setBookingModalOpen(false)}
              className="absolute top-4 right-4 p-1.5 border border-white/10 bg-[#050505] text-zinc-500 hover:text-white transition-colors"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Header */}
            <div className="space-y-1.5 border-b border-white/5 pb-4">
              <span className="overline text-[#5ce1e6] font-mono">LAB APPOINTMENT SCHEDULER</span>
              <h3 className="text-2xl font-bold uppercase tracking-tight text-white">{selectedPlanForBooking}</h3>
            </div>

            {bookingStatus === 'success' ? (
              <div className="space-y-6 py-4 text-center">
                <div className="w-16 h-16 bg-[#00FF9D]/10 border border-[#00FF9D]/20 text-[#00FF9D] flex items-center justify-center mx-auto rounded-sm">
                  <CheckCircle className="w-8 h-8" />
                </div>
                <div className="space-y-2">
                  <h4 className="text-lg font-bold uppercase font-mono text-[#00FF9D] tracking-wider">
                    {!selectedPlanForBooking?.startsWith("RSVP:") ? "MEMBERSHIP LICENSE UNLOCKED" : "RSVP REGISTRATION COMPLETE"}
                  </h4>
                  <p className="text-xs text-zinc-400 max-w-sm mx-auto leading-relaxed">
                    {!selectedPlanForBooking?.startsWith("RSVP:") 
                      ? "Your Vault Game License is now active. You have been granted direct access to download the standalone APK (Android/emulator) and Win64 ZIP packages."
                      : "Your spot has been reserved. You have also been granted trial access to the download portal."}
                  </p>
                </div>
                <div className="pt-2 flex flex-col gap-2">
                  <Link 
                    to="/download"
                    onClick={() => setBookingModalOpen(false)}
                    className="w-full py-3 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-extrabold text-xs uppercase tracking-widest transition-all rounded-sm shadow-[0_0_15px_rgba(92,225,230,0.3)] block text-center"
                  >
                    Go to Download Center →
                  </Link>
                  <button 
                    onClick={() => setBookingModalOpen(false)}
                    className="w-full py-2 bg-white/5 hover:bg-white/10 border border-white/5 text-zinc-500 hover:text-white uppercase font-bold text-[10px] tracking-wider transition-colors"
                  >
                    Dismiss Portal
                  </button>
                </div>
              </div>
            ) : (
              <form onSubmit={handleBookingSubmit} className="space-y-5">
                
                {/* Promo/Bypass Code field */}
                <div className="space-y-2 border-b border-white/5 pb-3">
                  <div className="flex justify-between items-center">
                    <label className="text-[10px] font-mono text-[#5ce1e6] uppercase tracking-widest">PROMO / BYPASS CODE</label>
                    <span className="text-[9px] text-zinc-500 font-mono">Use code to skip checkout validation</span>
                  </div>
                  <input 
                    type="text" 
                    placeholder="Enter bypass code (e.g. igotbounce)"
                    value={promoCode}
                    onChange={(e) => setPromoCode(e.target.value)}
                    className="w-full bg-[#050505] border border-[#5ce1e6]/30 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] text-sm"
                  />
                </div>
                
                <div className="space-y-2">
                  <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Athlete Name *</label>
                  <input 
                    type="text" 
                    required
                    placeholder="Your Full Name"
                    value={bookingDetails.name}
                    onChange={(e) => setBookingDetails({ ...bookingDetails, name: e.target.value })}
                    className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm"
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Email Address *</label>
                    <input 
                      type="email" 
                      required
                      placeholder="athlete@domain.com"
                      value={bookingDetails.email}
                      onChange={(e) => setBookingDetails({ ...bookingDetails, email: e.target.value })}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Phone Number</label>
                    <input 
                      type="tel" 
                      placeholder="Optional"
                      value={bookingDetails.phone}
                      onChange={(e) => setBookingDetails({ ...bookingDetails, phone: e.target.value })}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Select Date *</label>
                    <input 
                      type="date" 
                      required
                      value={bookingDate}
                      onChange={(e) => setBookingDate(e.target.value)}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm cursor-pointer"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Select Hour *</label>
                    <input 
                      type="time" 
                      required
                      value={bookingTime}
                      onChange={(e) => setBookingTime(e.target.value)}
                      className="w-full bg-[#050505] border border-white/10 text-white font-mono px-4 py-3 rounded-none focus:outline-none focus:border-[#5ce1e6] focus:ring-1 focus:ring-[#5ce1e6] text-sm cursor-pointer"
                    />
                  </div>
                </div>

                {/* Secure Payment section for non-RSVP plans */}
                {!selectedPlanForBooking?.startsWith("RSVP:") && (
                  <div className="space-y-4 border-t border-white/5 pt-4">
                    <div className="flex items-center justify-between">
                      <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest">Select Payment Method</label>
                      <div className="flex gap-2">
                        <button 
                          type="button" 
                          onClick={() => setPaymentMethod("card")}
                          className={`px-3 py-1 text-[10px] font-mono uppercase border transition-all ${paymentMethod === 'card' ? 'border-[#5ce1e6] text-[#5ce1e6] bg-[#5ce1e6]/10' : 'border-white/10 text-zinc-400'}`}
                        >
                          Credit Card
                        </button>
                        <button 
                          type="button" 
                          onClick={() => setPaymentMethod("paypal")}
                          className={`px-3 py-1 text-[10px] font-mono uppercase border transition-all ${paymentMethod === 'paypal' ? 'border-[#5ce1e6] text-[#5ce1e6] bg-[#5ce1e6]/10' : 'border-white/10 text-zinc-400'}`}
                        >
                          PayPal
                        </button>
                      </div>
                    </div>

                    {paymentMethod === "card" ? (
                      <div className="space-y-3 p-4 bg-white/5 border border-white/10 rounded-sm">
                        <div className="space-y-1">
                          <label className="text-[9px] font-mono text-zinc-500 uppercase">Card Number</label>
                          <input 
                            type="text" 
                            placeholder="4242 4242 4242 4242"
                            value={cardDetails.number}
                            onChange={(e) => setCardDetails({ ...cardDetails, number: e.target.value })}
                            className="w-full bg-[#050505] border border-white/10 text-white font-mono px-3 py-2 text-xs focus:outline-none focus:border-[#5ce1e6]"
                          />
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                          <div className="space-y-1">
                            <label className="text-[9px] font-mono text-zinc-500 uppercase">Expiry Date</label>
                            <input 
                              type="text" 
                              placeholder="MM/YY"
                              value={cardDetails.expiry}
                              onChange={(e) => setCardDetails({ ...cardDetails, expiry: e.target.value })}
                              className="w-full bg-[#050505] border border-white/10 text-white font-mono px-3 py-2 text-xs focus:outline-none focus:border-[#5ce1e6] text-center"
                            />
                          </div>
                          <div className="space-y-1">
                            <label className="text-[9px] font-mono text-zinc-500 uppercase">CVV</label>
                            <input 
                              type="text" 
                              placeholder="123"
                              value={cardDetails.cvv}
                              onChange={(e) => setCardDetails({ ...cardDetails, cvv: e.target.value })}
                              className="w-full bg-[#050505] border border-white/10 text-white font-mono px-3 py-2 text-xs focus:outline-none focus:border-[#5ce1e6] text-center"
                            />
                          </div>
                        </div>
                      </div>
                    ) : (
                      <div className="p-4 bg-yellow-500/5 border border-yellow-500/20 text-center text-xs text-yellow-400 font-mono rounded-sm space-y-1">
                        <div>PayPal secure sandbox active.</div>
                        <div className="text-[10px] text-zinc-500">Checkout completes instantly upon clicking Submit.</div>
                      </div>
                    )}
                  </div>
                )}

                {bookingStatus === 'error' && (
                  <div className="p-3 border border-red-500/30 bg-red-500/5 text-xs text-red-400 font-mono">
                    {bookingError}
                  </div>
                )}

                <div className="flex gap-4 pt-4">
                  <button 
                    type="button" 
                    onClick={() => setBookingModalOpen(false)}
                    className="flex-1 py-3 border border-white/10 text-zinc-400 hover:text-white hover:bg-white/5 uppercase font-bold text-xs tracking-wider transition-colors"
                  >
                    Cancel
                  </button>
                  <button 
                    type="submit" 
                    disabled={bookingStatus === 'booking'}
                    className="flex-1 py-3 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-extrabold text-xs tracking-widest uppercase transition-all flex items-center justify-center gap-2 shadow-[0_0_15px_rgba(92,225,230,0.15)] disabled:bg-zinc-800"
                  >
                    {bookingStatus === 'booking' ? (
                      <>
                        <div className="w-3.5 h-3.5 border-2 border-black border-t-transparent rounded-full animate-spin"></div>
                        <span>Processing...</span>
                      </>
                    ) : (
                      <span>{!selectedPlanForBooking?.startsWith("RSVP:") ? "Pay & Unlock Downloads" : "Confirm RSVP"}</span>
                    )}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* GOOGLE INFRASTRUCTURE STACK */}
      <section id="architecture" className="py-24 border-b border-white/5 bg-gradient-to-b from-black/0 via-cyan-500/[0.01] to-black/0">
        <div className="max-w-6xl mx-auto px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-4">
            <span className="overline text-emerald-400">100% Google Stack</span>
            <h2 className="text-4xl sm:text-5xl font-extrabold uppercase" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              Native Google Cloud Ecosystem
            </h2>
            <p className="text-zinc-400 font-light">
              By replacing third-party website builder dependencies, the system scales securely, maintaining sub-millisecond database updates.
            </p>
          </div>

          <div className="grid md:grid-cols-4 gap-6">
            
            {/* Tech 1 */}
            <div className="p-6 border border-zinc-800/80 bg-[#0A0A0E] rounded space-y-4">
              <div className="w-10 h-10 bg-cyan-400/5 flex items-center justify-center text-cyan-400 border border-cyan-400/20 rounded">
                <Globe className="w-5 h-5" />
              </div>
              <h4 className="text-md font-bold font-mono">Firebase Hosting</h4>
              <p className="text-xs text-zinc-500 leading-relaxed">
                Serves our static assets from global CDN edge networks, featuring built-in micro-caching and fully automated SSL integration.
              </p>
            </div>

            {/* Tech 2 */}
            <div className="p-6 border border-zinc-800/80 bg-[#0A0A0E] rounded space-y-4">
              <div className="w-10 h-10 bg-indigo-400/5 flex items-center justify-center text-indigo-400 border border-indigo-400/20 rounded">
                <Database className="w-5 h-5" />
              </div>
              <h4 className="text-md font-bold font-mono">Cloud SQL Postgres</h4>
              <p className="text-xs text-zinc-500 leading-relaxed">
                Enterprise SQL backplane handling player levels, transactional credits, and bio-scans with zero sync latency.
              </p>
            </div>

            {/* Tech 3 */}
            <div className="p-6 border border-zinc-800/80 bg-[#0A0A0E] rounded space-y-4">
              <div className="w-10 h-10 bg-purple-400/5 flex items-center justify-center text-purple-400 border border-purple-400/20 rounded">
                <Cpu className="w-5 h-5" />
              </div>
              <h4 className="text-md font-bold font-mono">Google Cloud Run</h4>
              <p className="text-xs text-zinc-500 leading-relaxed">
                Containerized FastAPI server automatically scaling to zero. Perfect for bursty game telemetry sessions.
              </p>
            </div>

            {/* Tech 4 */}
            <div className="p-6 border border-zinc-800/80 bg-[#0A0A0E] rounded space-y-4">
              <div className="w-10 h-10 bg-emerald-400/5 flex items-center justify-center text-emerald-400 border border-emerald-400/20 rounded">
                <Code className="w-5 h-5" />
              </div>
              <h4 className="text-md font-bold font-mono">Firebase SDK</h4>
              <p className="text-xs text-zinc-500 leading-relaxed">
                Direct client-side authentication and live database synchronization for iOS game packages and web browsers alike.
              </p>
            </div>

          </div>
        </div>
      </section>

      {/* ECONOMY / TOKENOMICS */}
      <section id="tokenomics" className="py-24 border-b border-white/5">
        <div className="max-w-6xl mx-auto px-6">
          <div className="grid lg:grid-cols-12 gap-12 items-center">
            
            <div className="lg:col-span-6 relative">
              <div className="relative z-10 border border-white/10 rounded-lg p-8 bg-[#0F0F13]/90 space-y-6">
                <div className="text-xs font-mono text-cyan-400 uppercase tracking-widest">
                  Active Token Ledger
                </div>
                
                <div className="space-y-4">
                  <div className="flex items-center justify-between p-4 border border-zinc-800/50 bg-[#0A0A0D] rounded">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 bg-yellow-500/10 flex items-center justify-center rounded">
                        <Coins className="w-5 h-5 text-yellow-500" />
                      </div>
                      <div>
                        <div className="text-sm font-bold font-mono">Base Shard Token</div>
                        <div className="text-[10px] text-zinc-500">Earned via arena outcomes</div>
                      </div>
                    </div>
                    <span className="text-xs font-mono text-zinc-400">WIN: +50 / LOSS: +15</span>
                  </div>

                  <div className="flex items-center justify-between p-4 border border-zinc-800/50 bg-[#0A0A0D] rounded">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 bg-cyan-500/10 flex items-center justify-center rounded">
                        <Flame className="w-5 h-5 text-cyan-500" />
                      </div>
                      <div>
                        <div className="text-sm font-bold font-mono">Athlete Level XP</div>
                        <div className="text-[10px] text-zinc-500">Increases stats and rankings</div>
                      </div>
                    </div>
                    <span className="text-xs font-mono text-zinc-400">HARD CAP: 500/SESSION</span>
                  </div>

                  <div className="flex items-center justify-between p-4 border border-zinc-800/50 bg-[#0A0A0D] rounded">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 bg-purple-500/10 flex items-center justify-center rounded">
                        <Trophy className="w-5 h-5 text-purple-500" />
                      </div>
                      <div>
                        <div className="text-sm font-bold font-mono">Coach Critique Credits</div>
                        <div className="text-[10px] text-zinc-500">Used for expert reviews</div>
                      </div>
                    </div>
                    <span className="text-xs font-mono text-zinc-400">MULTIPLAYER EXCHANGE</span>
                  </div>
                </div>
              </div>
              <div className="absolute inset-0 -m-4 bg-[radial-gradient(circle,rgba(234,179,8,0.06),transparent_60%)] rounded-xl blur-2xl pointer-events-none z-0"></div>
            </div>

            <div className="lg:col-span-6 space-y-6">
              <span className="overline text-yellow-500 font-mono">Play-to-Earn Mechanics</span>
              <h2 className="text-4xl sm:text-5xl font-extrabold uppercase leading-tight" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
                Anti-Inflationary Game Economy
              </h2>
              <p className="text-zinc-400 font-light leading-relaxed">
                Wix apps rely on basic e-commerce templates. Final Evolution Lab implements customized game economy rules. Earn Base Shards to acquire athlete card upgrades and exchange coaching credits. With session receipts written to your Postgres database and a strict 500 XP hard cap, standard progression scales evenly.
              </p>
              
              <div className="flex items-center gap-4">
                <button 
                  onClick={handleLogin}
                  className="px-6 py-3 border border-yellow-500/30 text-yellow-400 hover:bg-yellow-500/10 font-bold text-xs tracking-wider uppercase transition-all duration-300 rounded"
                >
                  View Economy Rules
                </button>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* FINAL CALL TO ACTION */}
      <section className="py-32 relative overflow-hidden bg-black/40">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(0,229,255,0.04),transparent_60%)] pointer-events-none"></div>
        
        <div className="max-w-4xl mx-auto px-6 text-center space-y-8 relative z-10">
          <span className="overline tracking-[0.3em]">SECURE SYSTEM LOGIN</span>
          <h2 className="text-5xl md:text-6xl font-black uppercase leading-none" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
            Ready to Audit <br />
            <span className="text-cyan-400">Your Athletic Potential?</span>
          </h2>
          
          <p className="text-zinc-400 text-lg max-w-xl mx-auto font-light">
            Connect using your Google credentials to immediately load the Vault athlete dashboard and view your performance metrics.
          </p>

          <div className="pt-4">
            <button 
              data-testid="footer-cta-btn"
              onClick={handleLogin}
              className="px-10 py-5 bg-cyan-400 hover:bg-cyan-300 text-black font-extrabold text-sm tracking-widest uppercase transition-all duration-300 shadow-[0_0_35px_rgba(0,229,255,0.3)] hover:shadow-[0_0_50px_rgba(0,229,255,0.6)] active:scale-95 rounded-sm"
            >
              Enter Final Evolution Lab
            </button>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="border-t border-white/5 py-12 bg-black">
        <div className="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-zinc-800 flex items-center justify-center rounded-sm">
              <Zap className="w-4 h-4 text-cyan-400 fill-current" />
            </div>
            <span className="text-sm font-bold tracking-tight uppercase" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              FINAL EVOLUTION
            </span>
          </div>

          <div className="flex flex-wrap justify-center gap-8 text-xs text-zinc-500 font-mono">
            <span>© 2026 Final Evolution Lab. All rights reserved.</span>
            <span className="text-zinc-700">|</span>
            <span>Infrastructure by Google Cloud</span>
          </div>
        </div>
      </footer>

      {/* GRADIENT DEFINITIONS */}
      <svg className="absolute w-0 h-0 pointer-events-none">
        <defs>
          <linearGradient id="cyanGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#00E5FF" />
            <stop offset="100%" stopColor="#6366F1" />
          </linearGradient>
        </defs>
      </svg>

    </div>
  );
}
