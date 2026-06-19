/**
 * DistributionPage — central download + onboarding hub for Final Evolution Lab.
 *
 * Route: /download
 *
 * Sections (top → bottom):
 *  • Sticky Nav
 *  • Hero — "Get The Athlete OS"
 *  • Platform Grid (4 cards) — iOS · macOS · Android · Web (game client shell)
 *  • Install & Register Guides (tabbed by platform)
 *  • Web Game Client Shell — framework/container for future desktop wrapper
 *  • System Requirements
 *  • FAQ
 *  • Footer CTA
 *
 * Aesthetic matches LandingV2: obsidian (#050505) + neon cyan (#00E5FF) +
 * indigo-violet (#5E17EB). Pure SVG + CSS. Zero new npm deps.
 *
 * Store badges are composed in-component so the page has no image dependency.
 * Public download links can be enabled through REACT_APP_*_STORE_URL values.
 */
import React, { useState, useEffect } from "react";
import {
  Apple, Smartphone, Monitor, Globe, ArrowRight, Sparkles, Zap,
  Download, ShieldCheck, Cpu, Wifi, Hourglass, ChevronDown,
  Compass, Link2, FileText, Copy, CheckCircle2
} from "lucide-react";

// ──────────────────────────────────────────────────────────────
// PLATFORM CARDS
// ──────────────────────────────────────────────────────────────
const releaseUrl = (value) => {
  if (!value || value === "#") return null;
  return value;
};

const IOS_STORE_URL = releaseUrl(process.env.REACT_APP_IOS_STORE_URL);
const MACOS_STORE_URL = releaseUrl(process.env.REACT_APP_MACOS_STORE_URL);
const ANDROID_STORE_URL = releaseUrl(process.env.REACT_APP_ANDROID_STORE_URL);

const PLATFORMS = [
  {
    id: "ios",
    name: "iPhone & iPad",
    eyebrow: IOS_STORE_URL ? "App Store · iOS 17+" : "TestFlight · iOS 17+",
    icon: Apple,
    accent: "#00E5FF",
    status: IOS_STORE_URL ? "available" : "private-beta",
    statusLabel: IOS_STORE_URL ? "Available" : "Private beta",
    description: "Native UE5.7 host with the WKWebView dashboard overlay. iPhone 15 Pro / 16 Pro recommended for Metal 3 + 120 Hz. Public App Store access appears here when the listing is live.",
    badge: "appstore",
    storeUrl: IOS_STORE_URL,
    secondaryLabel: "Read iOS install guide",
  },
  {
    id: "macos",
    name: "Mac",
    eyebrow: MACOS_STORE_URL ? "Mac App Store · macOS 14+" : "Internal build · macOS 14+",
    icon: Monitor,
    accent: "#8B5CF6",
    status: MACOS_STORE_URL ? "available" : "internal",
    statusLabel: MACOS_STORE_URL ? "Apple Silicon" : "Internal build",
    description: "Universal Mac binary for Apple Silicon (M1/M2/M3/M4). Intel Macs run in Rosetta with Metal 3 features disabled. Public Mac distribution appears here when approved.",
    badge: "macappstore",
    storeUrl: MACOS_STORE_URL,
    secondaryLabel: "Read macOS install guide",
  },
  {
    id: "android",
    name: "Android",
    eyebrow: ANDROID_STORE_URL ? "Google Play · Android 13+" : "Play Console testing · Android 13+",
    icon: Smartphone,
    accent: "#34D399",
    status: ANDROID_STORE_URL ? "available" : "internal-testing",
    statusLabel: ANDROID_STORE_URL ? "Available" : "Internal test",
    description: "AAB-distributed through Play Console testing until the public listing is live. Vulkan-capable device with >=6 GB RAM recommended; Tensor / Snapdragon 8 Gen 2+.",
    badge: "googleplay",
    storeUrl: ANDROID_STORE_URL,
    secondaryLabel: "Read Android install guide",
  },
  {
    id: "web",
    name: "Web Client",
    eyebrow: "Browser · Coming Soon",
    icon: Globe,
    accent: "#5E17EB",
    status: "coming-soon",
    statusLabel: "Q3 2026",
    description: "Browser-hosted shell for the web game client wrapper — desktop distribution with WebGPU acceleration. Sign in early to be notified.",
    badge: "web",
    storeUrl: null,
    secondaryLabel: "Join the early-access list",
  },
];

// ──────────────────────────────────────────────────────────────
// INSTALL GUIDES
// ──────────────────────────────────────────────────────────────
const GUIDES = {
  ios: {
    label: "iOS / iPadOS",
    icon: Apple,
    steps: [
      { t: "Open the release link", b: "Use the App Store or TestFlight link provided by the Final Evolution Lab release channel." },
      { t: "Install and authenticate", b: "Use Face ID, Touch ID, or your Apple ID password. Download is ~620 MB; expect a one-time first-launch cook of 30-60 seconds." },
      { t: "Allow permissions on first launch", b: "Camera (for AI pose critique), Motion & Fitness (for the HealthKit bridge), and Notifications (for AI Coach neuro-cues)." },
      { t: "Sign in with Google", b: "Tap 'Enter Lab'. The OAuth handshake auto-creates your athlete profile and seeds your PRQ baseline at 75.0." },
      { t: "Run your first System Scan", b: "Tap 'Start System Scan' on the dashboard. Hold your iPhone at eye-level and perform the prompted movement screen - about 90 seconds." },
    ],
    requirements: ["iOS 17.0+", "iPhone 13 / iPad Air (5th gen) or newer", "5 GB free storage", "Wi-Fi or 5G for first launch"],
  },
  macos: {
    label: "macOS",
    icon: Monitor,
    steps: [
      { t: "Open the Mac release link", b: "Use the Mac App Store or internal distribution link provided by the release channel." },
      { t: "Install the app", b: "Authenticate with Touch ID or Apple ID. The universal binary is about 1.2 GB; Apple Silicon Macs run native arm64." },
      { t: "Grant Camera + Microphone access", b: "System Settings > Privacy & Security > Camera / Microphone - toggle on for Final Evolution Lab." },
      { t: "Sign in with Google", b: "First launch opens the auth handshake in your default browser; the macOS app receives the session back via deep link." },
      { t: "Pair your iPhone (optional)", b: "On the dashboard, choose 'Pair iPhone' to mirror HealthKit data into the macOS app." },
    ],
    requirements: ["macOS 14 Sonoma+", "Apple Silicon (M1 or newer) recommended", "8 GB RAM minimum", "10 GB free storage"],
  },
  android: {
    label: "Android",
    icon: Smartphone,
    steps: [
      { t: "Open the Play release link", b: "Use the Google Play testing or public listing link provided by the release channel." },
      { t: "Tap 'Install'", b: "AAB delivers ~480 MB to your specific device variant. Vulkan + arm64-v8a required." },
      { t: "Grant runtime permissions", b: "Camera, Motion sensors, and Notifications - toggle each on when first prompted by the app." },
      { t: "Sign in with Google", b: "The Play Services integration uses your device's Google account. Tap 'Continue as <you>' to bypass the password prompt." },
      { t: "First-time PRQ scan", b: "Hold your phone at eye-level, complete the 90-second movement screen, and your PRQ baseline locks in." },
    ],
    requirements: ["Android 13+ (API 33)", "Snapdragon 8 Gen 1 / Tensor G2 or better", "6 GB RAM", "Vulkan 1.1 driver"],
  },
  web: {
    label: "Web (Coming Soon)",
    icon: Globe,
    steps: [
      { t: "The web client is in private alpha", b: "It will live at https://play.finalevolutiongroup.com once public alpha opens. WebGPU + WebTransport required." },
      { t: "Join the early-access list", b: "Sign in with Google on this site. Athletes with PRQ ≥ 80 get first invitations." },
      { t: "Expected requirements", b: "Chrome 121+, Edge 121+, or Safari 18+. WebGPU-capable GPU (M1+, RTX 20-series+, RX 6000+, or Adreno 730+)." },
      { t: "Controller support", b: "Xbox / PlayStation / 8BitDo controllers via WebHID. Keyboard fallback for all 19 game modes." },
    ],
    requirements: ["TBD — Q3 2026", "WebGPU + WebTransport", "Modern Chromium-based browser", "Hardware-accelerated GPU"],
  },
};

// ──────────────────────────────────────────────────────────────
// FAQ
// ──────────────────────────────────────────────────────────────
const FAQ_ITEMS = [
  {
    q: "Is Final Evolution Lab free?",
    a: "Yes — the core OS, system scan, 4 academic tracks, and 5 starter game modes are free forever. Creator Cards (cosmetic + ability unlocks) and the Applied Kinesiology Certificate are paid; no subscription required.",
  },
  {
    q: "Do I need an iPhone to use it?",
    a: "No — the iOS app is the flagship experience, but a Mac, Android phone, or (soon) browser client lets you use the dashboard, education tracks, Bio-Fuel scanner, and marketplace. Game modes currently run natively on iOS, macOS, and Android only.",
  },
  {
    q: "Is my biometric data sovereign?",
    a: "Yes. PRQ, HealthKit, and movement-screen data are athlete-owned. We store derived metrics (PRQ index, training load) on our backend; raw biometric streams stay on-device unless you explicitly export them.",
  },
  {
    q: "What's the difference between FEL OS and the standalone game?",
    a: "FEL OS is the unified athlete dashboard (system scan + 4 education tracks + creator cards + 19 game modes). The 'standalone game' is the embedded UE5 binary that the dashboard launches — they're shipped together in one package.",
  },
  {
    q: "How do I get the Applied Kinesiology Certificate?",
    a: "Complete all 8 kinesiology lessons, master the 4 Bio-Digital anatomy modules, reach PRQ ≥ 80, and pass the 10-question final (≥ 80%). The cert is issued as FEL-AK-XXXXXXXXXX and stamps your athlete profile.",
  },
  {
    q: "When does the web game client launch?",
    a: "Q3 2026. The shell framework is already scaffolded into this site (see the Web Game Client section below) — game-mode wrappers ship one at a time as we validate WebGPU performance.",
  },
];

// ──────────────────────────────────────────────────────────────
// COMPONENTS
// ──────────────────────────────────────────────────────────────
const Nav = ({ onLogin }) => {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  return (
    <nav
      className={`fixed top-0 inset-x-0 z-50 transition-all duration-300 ${
        scrolled ? "bg-[#050505]/80 backdrop-blur-xl border-b border-white/10" : "bg-transparent"
      }`}
      data-testid="dist-nav"
    >
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="/" className="flex items-center gap-2.5">
          <div className="w-7 h-7 flex items-center justify-center bg-[#00E5FF]" style={{ boxShadow: "0 0 18px rgba(0,229,255,0.4)" }}>
            <Zap className="w-4 h-4 text-black" />
          </div>
          <span className="font-black text-sm tracking-tight uppercase" style={{ fontFamily: "Barlow Condensed" }}>
            Final Evolution Lab
          </span>
        </a>
        <div className="hidden md:flex items-center gap-8 font-mono text-[11px] tracking-[0.2em] uppercase text-white/60">
          <a href="#platforms" className="hover:text-white transition-colors">Platforms</a>
          <a href="#guides" className="hover:text-white transition-colors">Install</a>
          <a href="#shell" className="hover:text-white transition-colors">Web Client</a>
          <a href="#docs" className="hover:text-white transition-colors">Docs</a>
          <a href="#faq" className="hover:text-white transition-colors">FAQ</a>
        </div>
        <button
          data-testid="dist-nav-login"
          onClick={onLogin}
          className="px-4 py-2 bg-[#00E5FF] text-black font-bold uppercase tracking-[0.15em] text-[11px] hover:bg-white transition-colors"
        >
          Enter Lab
        </button>
      </div>
    </nav>
  );
};

// Compact SVG store-badge placeholders. Replace `<img>` of the real badges
// when official PNG assets are shipped (see DISTRIBUTION_PAGE.md §3).
const StoreBadge = ({ kind }) => {
  const W = 180; const H = 56;
  const common = "rounded-md border border-white/15 bg-black/40 backdrop-blur";
  if (kind === "appstore") {
    return (
      <div className={common} style={{ width: W, height: H }} data-testid="badge-appstore">
        <div className="h-full flex items-center gap-3 px-3">
          <Apple className="w-7 h-7 text-white shrink-0" />
          <div className="leading-none">
            <div className="text-[9px] text-white/60 uppercase tracking-[0.15em]">Download on the</div>
            <div className="text-base font-semibold text-white mt-0.5">App Store</div>
          </div>
        </div>
      </div>
    );
  }
  if (kind === "macappstore") {
    return (
      <div className={common} style={{ width: W, height: H }} data-testid="badge-macappstore">
        <div className="h-full flex items-center gap-3 px-3">
          <Monitor className="w-7 h-7 text-white shrink-0" />
          <div className="leading-none">
            <div className="text-[9px] text-white/60 uppercase tracking-[0.15em]">Mac App Store</div>
            <div className="text-base font-semibold text-white mt-0.5">Get on Mac</div>
          </div>
        </div>
      </div>
    );
  }
  if (kind === "googleplay") {
    return (
      <div className={common} style={{ width: W, height: H }} data-testid="badge-googleplay">
        <div className="h-full flex items-center gap-3 px-3">
          <svg viewBox="0 0 32 32" className="w-7 h-7 shrink-0">
            <defs>
              <linearGradient id="gp1" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#34D399" /><stop offset="100%" stopColor="#0EA5E9" />
              </linearGradient>
            </defs>
            <path d="M5 4 L5 28 L18 16 Z" fill="url(#gp1)" />
            <path d="M5 4 L22 14 L18 16 Z" fill="#FBBF24" opacity="0.95" />
            <path d="M5 28 L22 18 L18 16 Z" fill="#EF4444" opacity="0.9" />
            <path d="M22 14 L28 16 L22 18 Z" fill="#FBBF24" />
          </svg>
          <div className="leading-none">
            <div className="text-[9px] text-white/60 uppercase tracking-[0.15em]">Get it on</div>
            <div className="text-base font-semibold text-white mt-0.5">Google Play</div>
          </div>
        </div>
      </div>
    );
  }
  // web placeholder
  return (
    <div className={common} style={{ width: W, height: H }} data-testid="badge-web">
      <div className="h-full flex items-center gap-3 px-3">
        <Globe className="w-7 h-7 text-[#00E5FF] shrink-0" />
        <div className="leading-none">
          <div className="text-[9px] text-white/60 uppercase tracking-[0.15em]">Browser · Q3 2026</div>
          <div className="text-base font-semibold text-white mt-0.5">Web Client</div>
        </div>
      </div>
    </div>
  );
};

const Hero = ({ onLogin }) => (
  <section className="relative pt-32 pb-20 lg:pt-40 overflow-hidden">
    <div
      className="absolute inset-0 pointer-events-none"
      style={{
        backgroundImage:
          "linear-gradient(rgba(0,229,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(0,229,255,0.06) 1px, transparent 1px)",
        backgroundSize: "64px 64px",
        maskImage: "radial-gradient(ellipse at center top, black 30%, transparent 80%)",
        WebkitMaskImage: "radial-gradient(ellipse at center top, black 30%, transparent 80%)",
      }}
    />
    <div
      className="absolute -top-32 left-1/2 -translate-x-1/2 w-[120%] h-[480px] pointer-events-none"
      style={{
        background:
          "radial-gradient(ellipse at center, rgba(0,229,255,0.10) 0%, rgba(94,23,235,0.06) 35%, transparent 65%)",
        filter: "blur(40px)",
      }}
    />
    <div className="relative max-w-5xl mx-auto px-6 text-center">
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/[0.04] border border-white/10 font-mono text-[10px] tracking-[0.3em] text-white/60 uppercase mb-6">
        <Download className="w-3 h-3 text-[#00E5FF]" /> Distribution Hub · v2.0
      </div>
      <h1
        className="text-5xl sm:text-6xl md:text-7xl lg:text-8xl font-black uppercase tracking-[-0.03em] leading-[0.85] mb-6"
        style={{ fontFamily: "Barlow Condensed" }}
      >
        Get the
        <br />
        <span className="bg-gradient-to-r from-[#00E5FF] via-[#8B5CF6] to-[#5E17EB] bg-clip-text text-transparent">
          Athlete OS.
        </span>
      </h1>
      <p className="text-base md:text-lg text-white/60 max-w-2xl mx-auto leading-relaxed mb-8">
        One download, four platforms. Live telemetry, 19 game modes, NASM-CNC nutrition,
        and a sovereign performance ledger — fused into the only OS that audits your reps.
      </p>
      <div className="flex flex-wrap items-center justify-center gap-4 mb-12">
        <a href="#platforms" data-testid="dist-hero-platforms" className="group inline-flex items-center gap-2 px-7 py-3.5 bg-[#00E5FF] text-black font-bold uppercase tracking-[0.15em] text-sm hover:bg-white transition-all" style={{ boxShadow: "0 0 30px rgba(0,229,255,0.35)" }}>
          Choose your platform <ArrowRight className="w-4 h-4 group-hover:translate-x-0.5 transition-transform" />
        </a>
        <button data-testid="dist-hero-login" onClick={onLogin} className="inline-flex items-center gap-2 px-7 py-3.5 border border-white/15 text-white font-bold uppercase tracking-[0.15em] text-sm hover:bg-white/[0.03] hover:border-white/30 transition-all">
          Sign in first
        </button>
      </div>
      <div className="flex items-center justify-center gap-6 font-mono text-[10px] tracking-[0.3em] uppercase text-white/30">
        <span>iOS 17+</span><span>·</span>
        <span>macOS 14+</span><span>·</span>
        <span>Android 13+</span><span>·</span>
        <span className="text-[#00E5FF]">Web · Q3 26</span>
      </div>
    </div>
  </section>
);

const PlatformGrid = () => (
  <section id="platforms" className="relative max-w-7xl mx-auto px-6 py-20" data-testid="platform-grid">
    <div className="max-w-2xl mb-12">
      <div className="font-mono text-[10px] tracking-[0.4em] text-[#00E5FF] uppercase mb-3">Choose your platform</div>
      <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight leading-[0.95]" style={{ fontFamily: "Barlow Condensed" }}>
        Four ways in. <span className="text-[#00E5FF]">One athlete.</span>
      </h2>
    </div>
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
      {PLATFORMS.map((p) => {
        const Icon = p.icon;
        const comingSoon = p.status === "coming-soon";
        const hasPublicDownload = Boolean(p.storeUrl);
        const mutedStatus = comingSoon || !hasPublicDownload;
        return (
          <article
            key={p.id}
            data-testid={`platform-${p.id}`}
            className="group relative rounded-2xl p-7 lg:p-8 bg-[#0A0A0A]/60 backdrop-blur-xl border border-white/10 hover:border-white/20 transition-all duration-500 hover:-translate-y-1 overflow-hidden"
            style={{ boxShadow: "inset 0 1px 1px rgba(255,255,255,0.04), 0 4px 24px rgba(0,0,0,0.4)" }}
          >
            <div
              className="absolute -top-px -left-px -right-px h-px"
              style={{ background: `linear-gradient(90deg, transparent 0%, ${p.accent}80 50%, transparent 100%)` }}
            />
            <div className="flex items-start justify-between mb-6">
              <div className="flex items-start gap-4">
                <div
                  className="w-14 h-14 rounded-lg border flex items-center justify-center shrink-0"
                  style={{
                    background: `${p.accent}15`,
                    borderColor: `${p.accent}40`,
                    boxShadow: `0 0 20px ${p.accent}25`,
                  }}
                >
                  <Icon className="w-7 h-7" style={{ color: p.accent }} />
                </div>
                <div>
                  <div className="font-mono text-[10px] tracking-[0.3em] uppercase mb-1" style={{ color: p.accent }}>{p.eyebrow}</div>
                  <h3 className="text-2xl font-bold tracking-tight" style={{ fontFamily: "Barlow Condensed" }}>{p.name}</h3>
                </div>
              </div>
              <div
                className={`text-[10px] font-mono uppercase tracking-[0.2em] px-2 py-1 rounded ${
                  mutedStatus ? "text-white/40 border border-white/15" : "text-black"
                }`}
                style={!mutedStatus ? { background: p.accent } : {}}
              >
                {p.statusLabel}
              </div>
            </div>
            <p className="text-sm text-white/60 leading-relaxed mb-6">{p.description}</p>
            <div className="flex items-center gap-4 flex-wrap">
              {p.storeUrl ? (
                <a href={p.storeUrl} data-testid={`platform-${p.id}-download`} className="block hover:scale-105 transition-transform">
                  <StoreBadge kind={p.badge} />
                </a>
              ) : (
                <div
                  data-testid={`platform-${p.id}-download-unavailable`}
                  aria-disabled="true"
                  title={comingSoon ? "Public web client is coming soon." : "Public store link is not live yet."}
                  className="opacity-50 grayscale"
                >
                  <StoreBadge kind={p.badge} />
                </div>
              )}
              <a href={`#guide-${p.id}`} data-testid={`platform-${p.id}-guide`} className="text-xs font-mono uppercase tracking-[0.2em] text-white/50 hover:text-white transition-colors flex items-center gap-1">
                {p.secondaryLabel} <ArrowRight className="w-3 h-3" />
              </a>
            </div>
          </article>
        );
      })}
    </div>
  </section>
);

const InstallGuides = () => {
  const [active, setActive] = useState("ios");
  const guide = GUIDES[active];
  const Icon = guide.icon;
  return (
    <section id="guides" className="relative max-w-7xl mx-auto px-6 py-20" data-testid="install-guides">
      <div className="max-w-2xl mb-10">
        <div className="font-mono text-[10px] tracking-[0.4em] text-[#00E5FF] uppercase mb-3">Install & Register</div>
        <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight leading-[0.95]" style={{ fontFamily: "Barlow Condensed" }}>
          Five steps. <span className="text-[#00E5FF]">From scan to arena.</span>
        </h2>
      </div>
      {/* Tabs */}
      <div className="flex gap-2 flex-wrap mb-6">
        {Object.entries(GUIDES).map(([key, g]) => {
          const GIcon = g.icon;
          const isActive = key === active;
          return (
            <button
              key={key}
              data-testid={`guide-tab-${key}`}
              id={`guide-${key}`}
              onClick={() => setActive(key)}
              className={`inline-flex items-center gap-2 px-4 py-2.5 text-sm font-mono uppercase tracking-[0.15em] border transition-colors ${
                isActive
                  ? "bg-[#00E5FF] text-black border-[#00E5FF]"
                  : "border-white/10 text-white/60 hover:border-white/30 hover:text-white"
              }`}
            >
              <GIcon className="w-3.5 h-3.5" /> {g.label}
            </button>
          );
        })}
      </div>
      {/* Steps */}
      <div className="rounded-2xl bg-[#0A0A0A]/60 backdrop-blur-xl border border-white/10 p-6 lg:p-10">
        <div className="flex items-center gap-4 mb-6">
          <div className="w-12 h-12 rounded-lg border border-[#00E5FF]/40 bg-[#00E5FF]/10 flex items-center justify-center">
            <Icon className="w-6 h-6 text-[#00E5FF]" />
          </div>
          <div>
            <div className="text-xs font-mono uppercase tracking-[0.3em] text-white/40">Install guide</div>
            <div className="text-xl font-bold" style={{ fontFamily: "Barlow Condensed" }}>{guide.label}</div>
          </div>
        </div>
        <ol className="space-y-5" data-testid={`guide-steps-${active}`}>
          {guide.steps.map((s, i) => (
            <li key={i} className="flex items-start gap-4 group">
              <div
                className="shrink-0 w-9 h-9 rounded-full border-2 border-[#00E5FF]/30 bg-black/40 flex items-center justify-center font-mono text-sm font-bold text-[#00E5FF]"
                style={{ boxShadow: "0 0 12px rgba(0,229,255,0.15)" }}
              >
                {i + 1}
              </div>
              <div className="pt-1">
                <div className="font-semibold text-white">{s.t}</div>
                <div className="text-sm text-white/60 leading-relaxed mt-1">{s.b}</div>
              </div>
            </li>
          ))}
        </ol>
        <div className="mt-8 pt-6 border-t border-white/5">
          <div className="text-xs font-mono uppercase tracking-[0.3em] text-white/40 mb-3">Requirements</div>
          <div className="flex flex-wrap gap-2">
            {guide.requirements.map((r) => (
              <span key={r} className="px-3 py-1 rounded-full border border-white/10 bg-white/[0.03] text-xs font-mono text-white/70">{r}</span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};

// ──────────────────────────────────────────────────────────────
// WEB GAME CLIENT SHELL — framework/container scaffold
// ──────────────────────────────────────────────────────────────
const WebClientShell = () => {
  const [bootStage, setBootStage] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setBootStage((s) => (s + 1) % 5), 1800);
    return () => clearInterval(t);
  }, []);
  const STAGES = [
    "INITIALIZING SHELL",
    "NEGOTIATING SIGNALING",
    "ALLOCATING GPU CONTEXT",
    "STREAMING ASSET MANIFEST",
    "READY — AWAITING ATHLETE",
  ];
  return (
    <section id="shell" className="relative max-w-7xl mx-auto px-6 py-20" data-testid="web-client-shell">
      <div className="max-w-2xl mb-10">
        <div className="font-mono text-[10px] tracking-[0.4em] text-[#5E17EB] uppercase mb-3">Web Game Client · Container Shell</div>
        <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight leading-[0.95]" style={{ fontFamily: "Barlow Condensed" }}>
          The shell <span className="text-[#5E17EB]">is wired.</span>
        </h2>
        <p className="text-sm text-white/60 mt-4 max-w-xl">
          A framework already lives on this site for the future web-based game client wrapper. Below is the live boot-state of the container — game-mode wrappers ship into it one at a time as we validate WebGPU performance.
        </p>
      </div>
      <div className="relative aspect-video w-full rounded-2xl overflow-hidden border border-[#5E17EB]/30 bg-black" style={{ boxShadow: "0 0 60px rgba(94,23,235,0.15), inset 0 1px 1px rgba(255,255,255,0.04)" }}>
        {/* Scan lines */}
        <div
          className="absolute inset-0 pointer-events-none opacity-30"
          style={{ backgroundImage: "repeating-linear-gradient(0deg, rgba(94,23,235,0.08) 0px, rgba(94,23,235,0.08) 1px, transparent 1px, transparent 4px)" }}
        />
        {/* Grid */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            backgroundImage:
              "linear-gradient(rgba(94,23,235,0.12) 1px, transparent 1px), linear-gradient(90deg, rgba(94,23,235,0.12) 1px, transparent 1px)",
            backgroundSize: "48px 48px",
            maskImage: "radial-gradient(ellipse at center, black 40%, transparent 80%)",
            WebkitMaskImage: "radial-gradient(ellipse at center, black 40%, transparent 80%)",
          }}
        />
        {/* Center content */}
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center px-6">
          <Hourglass className="w-12 h-12 text-[#5E17EB] mb-4 animate-pulse" />
          <div className="font-mono text-[10px] tracking-[0.4em] text-white/40 uppercase mb-2">FEL Web Client v0.1 · Container Shell</div>
          <div className="font-mono text-base text-[#00E5FF] tracking-[0.2em] uppercase mb-4 min-h-[1.5em]" data-testid="shell-boot-stage">
            {STAGES[bootStage]}
          </div>
          <div className="w-64 h-1 bg-white/5 rounded-full overflow-hidden">
            <div className="h-full bg-gradient-to-r from-[#00E5FF] to-[#5E17EB] transition-all duration-700" style={{ width: `${((bootStage + 1) / STAGES.length) * 100}%` }} />
          </div>
        </div>
        {/* HUD corners */}
        {[
          { top: 12, left: 12 }, { top: 12, right: 12 }, { bottom: 12, left: 12 }, { bottom: 12, right: 12 },
        ].map((pos, i) => (
          <div key={i} className="absolute font-mono text-[9px] text-[#5E17EB]/60 tracking-widest" style={pos}>
            FEL · {String(i).padStart(2, "0")}
          </div>
        ))}
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-8">
        {[
          { icon: Cpu, t: "WebGPU pipeline", b: "Hardware-accelerated render path with Vulkan parity. Falls back to WebGL 2 with feature-flag gating." },
          { icon: Wifi, t: "WebTransport signaling", b: "QUIC-based session control to the Sovereign Hub. Replaces the legacy WebSocket where supported." },
          { icon: ShieldCheck, t: "Sovereign auth bridge", b: "Same Bearer-token flow as the native apps. localStorage fallback for cookie-strict browsers." },
        ].map((f) => {
          const FIcon = f.icon;
          return (
            <div key={f.t} className="rounded-xl border border-white/10 bg-white/[0.02] p-5">
              <FIcon className="w-5 h-5 text-[#5E17EB] mb-3" />
              <div className="font-bold mb-1" style={{ fontFamily: "Barlow Condensed" }}>{f.t}</div>
              <div className="text-xs text-white/55 leading-relaxed">{f.b}</div>
            </div>
          );
        })}
      </div>
    </section>
  );
};

// ──────────────────────────────────────────────────────────────
// TECHNICAL DOCUMENTATION
//   3 subsections: CoreMotion calibration · Deep-link protocol · Release notes
// ──────────────────────────────────────────────────────────────

const TECH_DOCS = {
  coremotion: {
    label: "CoreMotion Calibration",
    icon: Compass,
    eyebrow: "Sensor pipeline",
    headline: "Calibrate movement before you audit it.",
    blurb: "FEL reads accelerometer, gyroscope, magnetometer, and (on supported devices) the device-motion attitude quaternion at 100 Hz. Bad calibration = bad PRQ. Do this once per device, after every iOS major-version upgrade, and any time you change cases.",
    steps: [
      { t: "Find a flat, level surface", b: "A table or floor — not your lap. Confirm with a spirit-level app if you're unsure." },
      { t: "Open Settings → System Scan → Sensor Calibration", b: "From the FEL dashboard, tap the gear icon, then Sensor Calibration. The screen will prompt you to place the device face-up." },
      { t: "Hold still for 3 seconds (zero-bias capture)", b: "FEL averages 300 samples to lock the accelerometer & gyroscope bias offsets. Don't touch the screen during the countdown." },
      { t: "Rotate through 6 orientations", b: "Face-up, face-down, left edge, right edge, top edge, bottom edge — hold each for 2 seconds. This builds the magnetometer hard/soft-iron correction matrix." },
      { t: "Walk a 10-step figure-8 loop", b: "Final stage: the AHRS fusion validates the quaternion path. Indoor walking is fine; avoid heavy metal interference (gym equipment, MRI rooms, you know the drill)." },
      { t: "Re-calibrate after any drift warning", b: "If the dashboard's PRQ widget shows a 'Recalibrate' chip, repeat steps 1–5. Most athletes need this once every 4–6 weeks." },
    ],
    spec: {
      "Sample rate": "100 Hz (sensor) → 50 Hz (PRQ pipeline)",
      "Frame": "right-handed, x=right, y=up, z=toward user",
      "Quaternion source": "CMDeviceMotion.attitude (iOS), Sensor.TYPE_ROTATION_VECTOR (Android)",
      "Storage": "On-device only · raw streams never leave the phone unless exported",
      "Drift recovery": "Magnetometer-aided AHRS · Madgwick filter, β=0.033",
    },
  },
  deeplink: {
    label: "Deep-Link Protocol",
    icon: Link2,
    eyebrow: "URI Scheme · v1.0",
    headline: "finalevolution:// — the front door.",
    blurb: "FEL exposes a single custom URI scheme that the iOS, macOS, and Android apps all respond to. Use this in marketing emails, web buttons, push notifications, and partner integrations to land athletes on a specific surface — bypassing the cold-launch home screen.",
    schemes: [
      { uri: "finalevolution://", label: "Open the app", description: "Launches FEL on the last-active screen. No-op if the app is already foregrounded." },
      { uri: "finalevolution://system-scan", label: "Jump to system scan", description: "Boots straight into the PRQ scan flow." },
      { uri: "finalevolution://brain-brawl/launch", label: "Brain Brawl arena", description: "Already in production — used by the cognitive mode briefing on the web dashboard." },
      { uri: "finalevolution://mode/{modeId}", label: "Launch a specific game mode", description: "modeId is one of the 19 registered modes (basketball_h2h, brain_brawl, dunk_arena, etc.)." },
      { uri: "finalevolution://creator-card/{cardId}", label: "Open a Creator Card", description: "Marketplace deep-link with PayPal-ready checkout state." },
      { uri: "finalevolution://education/track/{trackId}", label: "Resume a track", description: "trackId ∈ {common_core, stem, kinesiology, brain_brawl}." },
      { uri: "finalevolution://biofuel/scan", label: "Open the AI vision scanner", description: "Camera-ready · scoped permission prompt on first use." },
      { uri: "finalevolution://auth/callback?session_token=…", label: "OAuth return", description: "Used by the Emergent Google auth handshake. Do NOT construct manually." },
    ],
    notes: [
      "Universal Links (`https://finalevolutiongroup.com/u/...`) are also supported on iOS for shared messages — they redirect to the deep-link automatically.",
      "If the FEL app isn't installed, the deep-link falls back to the platform's store listing (App Store / Play Store) via your phone's default handler.",
      "Deep-link payloads are SIGNED — the URI must include a `&sig=` parameter for partner integrations. Marketing emails generated by FEL include the signature automatically.",
    ],
  },
  releaseNotes: {
    label: "Release Notes",
    icon: FileText,
    eyebrow: "Changelog · public",
    headline: "What's new.",
    blurb: "We ship small, often. Major versions land roughly quarterly; minor versions every 2–3 weeks. Subscribe to the in-app release feed for the full firehose, including dev-only flags.",
    versions: [
      {
        v: "v2.0.0",
        date: "Feb 2026",
        tag: "current",
        highlights: [
          "FEL OS — unified 4-quadrant dashboard (System Scan · Cards · Arena · Academy)",
          "Education tracks: Common Core, STEM, Applied Kinesiology Certificate, Brain Brawl",
          "Bio-Fuel suite — NASM-CNC vision scanner (Gemini 2.5 Flash / GPT-5.2 athlete-pickable)",
          "FEL OS Pass — shareable PNG card with PRQ + cert badge",
          "Production hardening — K8s root /health, CORS regex, Bearer-fallback auth for in-app WebViews",
        ],
      },
      {
        v: "v1.8.0",
        date: "Jan 2026",
        tag: null,
        highlights: [
          "iOS native UE5 deep-link bridge — Brain Brawl Arena now playable via finalevolution://",
          "19th game mode added: Court Carnival (renamed from mario_party)",
          "Bio-Digital Masterclass anatomy overlays — 3D ghost-in-the-shell on real movement video",
        ],
      },
      {
        v: "v1.5.0",
        date: "Nov 2025",
        tag: null,
        highlights: [
          "Sovereign Hub WebSocket telemetry — sub-500 ms PRQ updates from the iOS bridge",
          "Creator Card marketplace + PayPal sandbox integration",
          "17-mode Venue Registry — first public mode count",
        ],
      },
      {
        v: "v1.0.0",
        date: "Sep 2025",
        tag: null,
        highlights: [
          "Public alpha launch — iOS only, 5 starter modes",
          "Google Auth handshake, base PRQ scoring, initial avatar builder",
        ],
      },
    ],
  },
};

const CopyableUri = ({ uri }) => {
  const [copied, setCopied] = useState(false);
  const onCopy = async () => {
    try {
      await navigator.clipboard.writeText(uri);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch (_e) { /* ignore */ }
  };
  return (
    <button
      data-testid={`deeplink-copy-${uri.replace(/[^a-z0-9]/gi, '-').slice(0, 40)}`}
      onClick={onCopy}
      className="group/copy inline-flex items-center gap-2 font-mono text-xs px-3 py-1.5 rounded border border-white/10 bg-black/40 hover:border-[#00E5FF]/40 hover:bg-[#00E5FF]/5 transition-colors min-w-0"
    >
      <code className="text-[#00E5FF] truncate">{uri}</code>
      {copied ? (
        <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
      ) : (
        <Copy className="w-3.5 h-3.5 text-white/40 group-hover/copy:text-white/80 shrink-0" />
      )}
    </button>
  );
};

const TechDocs = () => {
  const [active, setActive] = useState("coremotion");
  const doc = TECH_DOCS[active];
  const Icon = doc.icon;
  return (
    <section id="docs" className="relative max-w-7xl mx-auto px-6 py-20" data-testid="tech-docs">
      <div className="max-w-2xl mb-10">
        <div className="font-mono text-[10px] tracking-[0.4em] text-[#8B5CF6] uppercase mb-3">Technical Documentation</div>
        <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight leading-[0.95]" style={{ fontFamily: "Barlow Condensed" }}>
          Under the hood. <span className="text-[#8B5CF6]">Honest specs.</span>
        </h2>
      </div>
      {/* Tabs */}
      <div className="flex gap-2 flex-wrap mb-6" data-testid="docs-tabs">
        {Object.entries(TECH_DOCS).map(([key, d]) => {
          const DIcon = d.icon;
          const isActive = key === active;
          return (
            <button
              key={key}
              data-testid={`docs-tab-${key}`}
              onClick={() => setActive(key)}
              className={`inline-flex items-center gap-2 px-4 py-2.5 text-sm font-mono uppercase tracking-[0.15em] border transition-colors ${
                isActive
                  ? "bg-[#8B5CF6] text-black border-[#8B5CF6]"
                  : "border-white/10 text-white/60 hover:border-white/30 hover:text-white"
              }`}
            >
              <DIcon className="w-3.5 h-3.5" /> {d.label}
            </button>
          );
        })}
      </div>
      {/* Body */}
      <div
        className="rounded-2xl bg-[#0A0A0A]/60 backdrop-blur-xl border border-white/10 p-6 lg:p-10"
        data-testid={`docs-body-${active}`}
      >
        <div className="flex items-center gap-4 mb-4">
          <div className="w-12 h-12 rounded-lg border border-[#8B5CF6]/40 bg-[#8B5CF6]/10 flex items-center justify-center">
            <Icon className="w-6 h-6 text-[#8B5CF6]" />
          </div>
          <div>
            <div className="text-xs font-mono uppercase tracking-[0.3em] text-white/40">{doc.eyebrow}</div>
            <div className="text-xl font-bold" style={{ fontFamily: "Barlow Condensed" }}>{doc.headline}</div>
          </div>
        </div>
        <p className="text-sm text-white/60 leading-relaxed mb-6">{doc.blurb}</p>

        {/* CoreMotion subsection */}
        {active === "coremotion" && (
          <div className="space-y-6">
            <ol className="space-y-4" data-testid="coremotion-steps">
              {doc.steps.map((s, i) => (
                <li key={i} className="flex items-start gap-4">
                  <div
                    className="shrink-0 w-9 h-9 rounded-full border-2 border-[#8B5CF6]/30 bg-black/40 flex items-center justify-center font-mono text-sm font-bold text-[#8B5CF6]"
                    style={{ boxShadow: "0 0 12px rgba(139,92,246,0.15)" }}
                  >
                    {i + 1}
                  </div>
                  <div className="pt-1">
                    <div className="font-semibold text-white">{s.t}</div>
                    <div className="text-sm text-white/60 leading-relaxed mt-1">{s.b}</div>
                  </div>
                </li>
              ))}
            </ol>
            <div className="border-t border-white/5 pt-5">
              <div className="text-xs font-mono uppercase tracking-[0.3em] text-white/40 mb-3">Spec sheet</div>
              <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-2 text-xs">
                {Object.entries(doc.spec).map(([k, v]) => (
                  <div key={k} className="flex items-baseline gap-3 border-b border-white/5 pb-1.5">
                    <dt className="text-white/40 font-mono uppercase tracking-wider text-[10px] shrink-0">{k}</dt>
                    <dd className="text-white/80 font-mono ml-auto text-right">{v}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </div>
        )}

        {/* Deep-link subsection */}
        {active === "deeplink" && (
          <div className="space-y-5">
            <div className="space-y-3" data-testid="deeplink-table">
              {doc.schemes.map((s) => (
                <div key={s.uri} className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)] gap-3 lg:gap-6 items-start py-3 border-b border-white/5 last:border-b-0">
                  <CopyableUri uri={s.uri} />
                  <div className="min-w-0">
                    <div className="font-semibold text-white">{s.label}</div>
                    <div className="text-xs text-white/55 leading-relaxed mt-0.5">{s.description}</div>
                  </div>
                </div>
              ))}
            </div>
            <div className="border-t border-white/5 pt-5 space-y-2">
              <div className="text-xs font-mono uppercase tracking-[0.3em] text-white/40 mb-2">Notes</div>
              {doc.notes.map((n, i) => (
                <div key={i} className="flex items-start gap-2 text-xs text-white/55 leading-relaxed">
                  <span className="text-[#8B5CF6] mt-1">▸</span>
                  <span>{n}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Release notes subsection */}
        {active === "releaseNotes" && (
          <div className="space-y-5" data-testid="release-notes">
            {doc.versions.map((v) => (
              <div key={v.v} className="relative pl-6 border-l-2 border-white/10 pb-2 last:pb-0">
                <div className="absolute -left-[7px] top-0 w-3 h-3 rounded-full border-2 border-[#8B5CF6] bg-[#050505]" style={{ boxShadow: v.tag ? "0 0 12px rgba(139,92,246,0.6)" : undefined }} />
                <div className="flex items-baseline gap-3 mb-2 flex-wrap">
                  <div className="text-xl font-black text-white" style={{ fontFamily: "Barlow Condensed" }}>{v.v}</div>
                  <div className="font-mono text-[10px] uppercase tracking-[0.3em] text-white/40">{v.date}</div>
                  {v.tag && (
                    <span className="text-[10px] font-mono uppercase tracking-[0.2em] px-2 py-0.5 rounded bg-[#8B5CF6] text-black">
                      {v.tag}
                    </span>
                  )}
                </div>
                <ul className="space-y-1.5">
                  {v.highlights.map((h, i) => (
                    <li key={i} className="flex items-start gap-2 text-sm text-white/65">
                      <span className="text-[#00E5FF] mt-1">▸</span>
                      <span>{h}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  );
};

const FAQ = () => {
  const [open, setOpen] = useState(0);
  return (
    <section id="faq" className="relative max-w-3xl mx-auto px-6 py-20" data-testid="dist-faq">
      <div className="text-center mb-10">
        <div className="font-mono text-[10px] tracking-[0.4em] text-[#00E5FF] uppercase mb-3">Common Questions</div>
        <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight" style={{ fontFamily: "Barlow Condensed" }}>
          Honest answers.
        </h2>
      </div>
      <div className="space-y-2">
        {FAQ_ITEMS.map((item, i) => {
          const isOpen = open === i;
          return (
            <div key={i} className="rounded-xl border border-white/10 bg-[#0A0A0A]/60 backdrop-blur-md overflow-hidden">
              <button
                data-testid={`faq-q-${i}`}
                onClick={() => setOpen(isOpen ? -1 : i)}
                className="w-full flex items-center justify-between gap-4 px-5 py-4 text-left hover:bg-white/[0.02] transition-colors"
              >
                <span className="font-semibold text-white">{item.q}</span>
                <ChevronDown className={`w-4 h-4 text-[#00E5FF] shrink-0 transition-transform ${isOpen ? "rotate-180" : ""}`} />
              </button>
              {isOpen && (
                <div className="px-5 pb-5 text-sm text-white/65 leading-relaxed border-t border-white/5" data-testid={`faq-a-${i}`}>
                  <div className="pt-4">{item.a}</div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
};

const FooterCTA = ({ onLogin }) => (
  <section className="relative max-w-7xl mx-auto px-6 py-24">
    <div className="relative rounded-3xl p-12 lg:p-20 bg-[#0A0A0A]/60 backdrop-blur-2xl border border-white/10 overflow-hidden">
      <div
        className="absolute inset-0 pointer-events-none"
        style={{ background: "radial-gradient(circle at 20% 30%, rgba(0,229,255,0.10) 0%, transparent 50%), radial-gradient(circle at 80% 70%, rgba(94,23,235,0.10) 0%, transparent 50%)" }}
      />
      <div className="relative max-w-3xl">
        <div className="font-mono text-[10px] tracking-[0.4em] uppercase text-[#00E5FF] mb-4">Last gate.</div>
        <h2 className="text-4xl md:text-6xl font-black uppercase tracking-[-0.02em] leading-[0.9] mb-6" style={{ fontFamily: "Barlow Condensed" }}>
          Download. <span className="text-[#00E5FF]">Audit.</span> Train.
        </h2>
        <p className="text-white/60 mb-8 max-w-xl">
          Two minutes from store badge to system scan. No card required.
        </p>
        <button
          data-testid="dist-footer-cta"
          onClick={onLogin}
          className="group inline-flex items-center gap-2 px-7 py-3.5 bg-[#00E5FF] text-black font-bold uppercase tracking-[0.15em] text-sm hover:bg-white transition-all"
          style={{ boxShadow: "0 0 30px rgba(0,229,255,0.35)" }}
        >
          Sign in <ArrowRight className="w-4 h-4 group-hover:translate-x-0.5 transition-transform" />
        </button>
      </div>
    </div>
  </section>
);

const Footer = () => (
  <footer className="relative border-t border-white/5 py-12">
    <div className="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4">
      <div className="flex items-center gap-2 font-mono text-[10px] tracking-[0.3em] uppercase text-white/30">
        <Sparkles className="w-3 h-3 text-[#00E5FF]" /> © FEL · Distribution · v2.0
      </div>
      <div className="flex items-center gap-6 font-mono text-[10px] tracking-[0.3em] uppercase text-white/30">
        <a href="/" className="hover:text-white transition-colors">Home</a>
        <a href="#" className="hover:text-white transition-colors">Privacy</a>
        <a href="#" className="hover:text-white transition-colors">Terms</a>
      </div>
    </div>
  </footer>
);

// ──────────────────────────────────────────────────────────────
// PAGE
// ──────────────────────────────────────────────────────────────
export default function DistributionPage({ onLogin = () => {} }) {
  return (
    <div
      data-testid="distribution-page"
      className="min-h-screen text-white antialiased"
      style={{ background: "#050505", fontFamily: "'IBM Plex Sans', system-ui, sans-serif" }}
    >
      <Nav onLogin={onLogin} />
      <Hero onLogin={onLogin} />
      <PlatformGrid />
      <InstallGuides />
      <WebClientShell />
      <TechDocs />
      <FAQ />
      <FooterCTA onLogin={onLogin} />
      <Footer />
    </div>
  );
}
