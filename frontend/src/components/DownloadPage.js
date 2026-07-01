import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { 
  ArrowLeft, Download, Smartphone, Laptop, ShieldCheck, 
  BookOpen, HelpCircle, Terminal, ExternalLink, Lock, CheckCircle 
} from "lucide-react";

export default function DownloadPage() {
  const [hasPurchased, setHasPurchased] = useState(false);
  const [passcode, setPasscode] = useState("");
  const [passcodeError, setPasscodeError] = useState("");

  useEffect(() => {
    const purchased = localStorage.getItem("fel_has_purchased") === "true";
    setHasPurchased(purchased);
  }, []);

  const simulatePurchase = () => {
    localStorage.setItem("fel_has_purchased", "true");
    setHasPurchased(true);
  };

  const handlePasscodeSubmit = (e) => {
    e.preventDefault();
    if (passcode.toLowerCase().trim() === "igotbounce") {
      localStorage.setItem("fel_has_purchased", "true");
      setHasPurchased(true);
      setPasscodeError("");
    } else {
      setPasscodeError("Invalid bypass code");
    }
  };

  const revokeLicense = () => {
    localStorage.removeItem("fel_has_purchased");
    setHasPurchased(false);
  };

  if (!hasPurchased) {
    return (
      <div className="min-h-screen bg-[#050505] text-white selection:bg-cyan-500 selection:text-black overflow-y-auto font-sans flex flex-col justify-center items-center px-6 py-12 relative">
        {/* Background Gradients */}
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(0,229,255,0.05),transparent_50%)] pointer-events-none"></div>
        <div className="absolute top-[40%] left-[-10%] w-[500px] h-[500px] bg-[radial-gradient(circle,rgba(168,85,247,0.03),transparent_60%)] pointer-events-none blur-3xl"></div>
        
        <div className="max-w-md w-full border border-white/10 bg-[#0F0F13]/90 rounded p-8 text-center space-y-6 backdrop-blur-xl relative z-10 shadow-[0_0_50px_rgba(0,0,0,0.8)]">
          <div className="w-16 h-16 bg-red-500/10 border border-red-500/20 text-red-500 flex items-center justify-center mx-auto rounded-sm shadow-[0_0_15px_rgba(239,68,68,0.1)]">
            <Lock className="w-8 h-8" />
          </div>
          
          <div className="space-y-2">
            <span className="text-[10px] text-red-400 font-mono tracking-widest uppercase">ACCESS DENIED · SECURE GATEWAY</span>
            <h2 className="text-3xl font-black uppercase tracking-tight text-white leading-none" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              LICENSE REQUIRED
            </h2>
            <p className="text-zinc-400 text-xs leading-relaxed font-light">
              Final Evolution Lab standalone game clients and emulator builds are restricted to active Vault members. Please purchase a membership or complete a consultation to unlock direct APK/ZIP downloads.
            </p>
          </div>
          
          <div className="pt-4 space-y-3">
            <Link 
              to="/" 
              className="block w-full py-3 bg-[#5ce1e6] hover:bg-[#4dd0d5] text-black font-extrabold text-xs tracking-widest uppercase transition-all rounded-sm shadow-[0_0_15px_rgba(92,225,230,0.15)] text-center"
            >
              Go to Store & Checkout
            </Link>
            
            <button
              onClick={simulatePurchase}
              className="block w-full py-3 bg-white/5 hover:bg-white/10 border border-white/10 text-white font-bold text-xs tracking-widest uppercase transition-all rounded-sm"
            >
              Simulate Purchase (Test Unlock)
            </button>

            {/* Bypass Code Form */}
            <form onSubmit={handlePasscodeSubmit} className="space-y-2 pt-4 border-t border-white/5">
              <label className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest block text-left">
                ENTER BYPASS CODE
              </label>
              <div className="flex gap-2">
                <input 
                  type="text" 
                  placeholder="e.g. igotbounce"
                  value={passcode}
                  onChange={(e) => {
                    setPasscode(e.target.value);
                    setPasscodeError("");
                  }}
                  className="flex-1 bg-[#050505] border border-white/10 text-white font-mono px-3 py-2 text-xs focus:outline-none focus:border-cyan-400"
                />
                <button 
                  type="submit"
                  className="px-4 py-2 bg-cyan-400 hover:bg-cyan-300 text-black font-bold text-xs uppercase tracking-wider transition-all"
                >
                  Apply
                </button>
              </div>
              {passcodeError && (
                <div className="text-red-400 font-mono text-[10px] text-left">{passcodeError}</div>
              )}
            </form>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#050505] text-white selection:bg-cyan-500 selection:text-black overflow-y-auto font-sans pb-20">
      
      {/* Background Gradients */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(0,229,255,0.05),transparent_50%)] pointer-events-none"></div>
      <div className="absolute top-[40%] left-[-10%] w-[500px] h-[500px] bg-[radial-gradient(circle,rgba(168,85,247,0.03),transparent_60%)] pointer-events-none blur-3xl"></div>

      <div className="max-w-6xl mx-auto px-6 pt-10">
        
        {/* Navigation back */}
        <div className="mb-6 flex justify-between items-center">
          <Link 
            to={localStorage.getItem("fel_token") ? "/dashboard" : "/"}
            className="inline-flex items-center gap-2 text-zinc-400 hover:text-cyan-400 transition-colors text-xs font-mono tracking-widest uppercase"
          >
            <ArrowLeft className="w-4 h-4" /> Back to {localStorage.getItem("fel_token") ? "Dashboard" : "Home"}
          </Link>

          <button 
            onClick={revokeLicense}
            className="text-zinc-500 hover:text-red-400 transition-colors uppercase text-[10px] tracking-wider font-mono bg-white/5 px-3 py-1 border border-white/10 rounded-sm"
          >
            [ Revoke License / Test Lock ]
          </button>
        </div>

        {/* Status Bar */}
        <div className="mb-8 bg-cyan-400/5 border border-cyan-400/20 p-4 rounded-sm flex items-center gap-3">
          <div className="w-8 h-8 bg-cyan-400/10 border border-cyan-400/20 text-cyan-400 flex items-center justify-center rounded-sm">
            <CheckCircle className="w-5 h-5" />
          </div>
          <div>
            <div className="text-xs font-mono font-bold text-cyan-400 uppercase tracking-wider">VAULT LICENSE UNLOCKED & ACTIVE</div>
            <div className="text-[10px] text-zinc-500 font-mono">Your profile matches authenticated purchase signature · Sideloading enabled</div>
          </div>
        </div>

        {/* Header */}
        <div className="space-y-4 mb-12">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-cyan-400/10 border border-cyan-400/20 text-cyan-400 text-[10px] font-mono tracking-widest uppercase rounded-full">
            <ShieldCheck className="w-3.5 h-3.5" /> SECURE GATEWAY // ACCESS GRANTED
          </div>
          <h1 
            className="text-4xl sm:text-5xl md:text-6xl font-black tracking-tight uppercase leading-[0.9]"
            style={{ fontFamily: "'Barlow Condensed', sans-serif" }}
          >
            Download Game Packages
          </h1>
          <p className="text-zinc-400 text-sm md:text-base max-w-2xl font-light">
            Vault Membership is active. Download the standalone game packages below to install on your mobile device, emulator, or PC.
          </p>
        </div>

        {/* Download Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          
          {/* Android Card */}
          <div className="border border-white/10 bg-[#0F0F13]/90 rounded p-6 flex flex-col justify-between hover:border-cyan-400/30 transition-all duration-300 relative group">
            <div className="space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 bg-cyan-400/10 flex items-center justify-center text-cyan-400 rounded">
                  <Smartphone className="w-6 h-6" />
                </div>
                <span className="text-[10px] text-zinc-500 font-mono">v1.0 (APK)</span>
              </div>
              <h3 className="text-lg font-bold uppercase font-mono">Android Package</h3>
              <p className="text-zinc-400 text-xs leading-relaxed">
                Direct sideload build. Run natively on your Android mobile device or inside PC emulators like BlueStacks, Nox, or LDPlayer.
              </p>
            </div>
            <div className="pt-6">
              <a 
                href="/downloads/FinalEvolutionLab.apk" 
                download
                className="w-full py-3 bg-cyan-400 hover:bg-cyan-300 text-black font-bold text-xs tracking-widest uppercase transition-all rounded flex items-center justify-center gap-2 shadow-[0_0_15px_rgba(0,229,255,0.1)] text-center cursor-pointer"
              >
                <Download className="w-4 h-4" /> Download Direct APK
              </a>
            </div>
          </div>

          {/* Windows Desktop Card */}
          <div className="border border-white/10 bg-[#0F0F13]/90 rounded p-6 flex flex-col justify-between hover:border-purple-400/30 transition-all duration-300 relative group">
            <div className="space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 bg-purple-400/10 flex items-center justify-center text-purple-400 rounded">
                  <Laptop className="w-6 h-6" />
                </div>
                <span className="text-[10px] text-zinc-500 font-mono">Win64 Standalone</span>
              </div>
              <h3 className="text-lg font-bold uppercase font-mono">Windows Build</h3>
              <p className="text-zinc-400 text-xs leading-relaxed">
                PC package for Windows 10/11. Experience the environment assets and high-fidelity physics simulator with direct keyboard/controller layout.
              </p>
            </div>
            <div className="pt-6">
              <a 
                href="/downloads/FinalEvolutionLab_Win64.zip" 
                download
                className="w-full py-3 bg-purple-500 hover:bg-purple-400 text-white font-bold text-xs tracking-widest uppercase transition-all rounded flex items-center justify-center gap-2 shadow-[0_0_15px_rgba(168,85,247,0.1)] text-center cursor-pointer"
              >
                <Download className="w-4 h-4" /> Download Win64 (.zip)
              </a>
            </div>
          </div>

          {/* macOS Desktop Card */}
          <div className="border border-white/10 bg-[#0F0F13]/90 rounded p-6 flex flex-col justify-between hover:border-teal-400/30 transition-all duration-300 relative group">
            <div className="space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 bg-teal-400/10 flex items-center justify-center text-teal-400 rounded">
                  <Laptop className="w-6 h-6" />
                </div>
                <span className="text-[10px] text-zinc-500 font-mono">macOS Universal</span>
              </div>
              <h3 className="text-lg font-bold uppercase font-mono">macOS Build</h3>
              <p className="text-zinc-400 text-xs leading-relaxed">
                Mac standalone package for Apple Silicon and Intel. Run the high-fidelity simulator directly on your macOS environment.
              </p>
            </div>
            <div className="pt-6">
              <a 
                href="/downloads/FinalEvolutionLab_Mac.zip" 
                download
                className="w-full py-3 bg-teal-500 hover:bg-teal-400 text-black font-bold text-xs tracking-widest uppercase transition-all rounded flex items-center justify-center gap-2 shadow-[0_0_15px_rgba(20,184,166,0.1)] text-center cursor-pointer"
              >
                <Download className="w-4 h-4" /> Download Mac (.zip)
              </a>
            </div>
          </div>

          {/* iOS TestFlight Card */}
          <div className="border border-white/10 bg-[#0F0F13]/90 rounded p-6 flex flex-col justify-between hover:border-[#1e90ff]/30 transition-all duration-300 relative group">
            <div className="space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 bg-[#1e90ff]/10 flex items-center justify-center text-[#1e90ff] rounded">
                  <Smartphone className="w-6 h-6" />
                </div>
                <span className="text-[10px] text-zinc-500 font-mono">TestFlight App</span>
              </div>
              <h3 className="text-lg font-bold uppercase font-mono">iOS Invitation</h3>
              <p className="text-zinc-400 text-xs leading-relaxed">
                Install directly on Apple devices. Syncs your HealthKit biomechanics and physical sensors through Apple TestFlight.
              </p>
            </div>
            <div className="pt-6">
              <a 
                href="https://testflight.apple.com" 
                target="_blank" 
                rel="noreferrer"
                className="w-full py-3 bg-white/5 hover:bg-white/10 border border-white/10 text-white font-bold text-xs tracking-widest uppercase transition-all rounded flex items-center justify-center gap-2 text-center"
              >
                Request TestFlight Access <ExternalLink className="w-4 h-4" />
              </a>
            </div>
          </div>

        </div>

        {/* Documentation Portal */}
        <div className="grid md:grid-cols-12 gap-8 border-t border-white/5 pt-12">
          
          {/* Left: Table of Contents / Sidebar */}
          <div className="md:col-span-4 space-y-4">
            <div className="flex items-center gap-2 font-mono text-xs text-zinc-400 uppercase tracking-widest">
              <BookOpen className="w-4 h-4 text-cyan-400" />
              <span>SETUP DOCUMENTATION</span>
            </div>
            <div className="flex flex-col gap-2 text-sm">
              <a href="#android-install" className="text-zinc-500 hover:text-cyan-400 transition-colors">Android Installation</a>
              <a href="#emulator-config" className="text-zinc-500 hover:text-cyan-400 transition-colors">PC Emulator Setup</a>
              <a href="#win64-run" className="text-zinc-500 hover:text-cyan-400 transition-colors">Windows Execution</a>
              <a href="#mac-run" className="text-zinc-500 hover:text-cyan-400 transition-colors">macOS Execution</a>
              <a href="#deeplinking" className="text-zinc-500 hover:text-cyan-400 transition-colors">Deep Link Integration</a>
            </div>
          </div>

          {/* Right: Docs content */}
          <div className="md:col-span-8 space-y-12">
            
            {/* Sec 1: Android Install */}
            <div id="android-install" className="space-y-4">
              <h3 className="text-xl font-bold uppercase font-mono border-b border-white/5 pb-2 text-cyan-400">
                1. Sideloading Android APK
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed font-light">
                To run the app directly on your Android phone or tablet, follow these steps to sideload the package:
              </p>
              <ol className="list-decimal list-inside space-y-2 text-xs text-zinc-400 font-mono">
                <li>Click the <strong className="text-white">"Download Direct APK"</strong> button above to download <code className="text-cyan-400 bg-white/5 px-1 py-0.5 rounded">FinalEvolutionLab.apk</code>.</li>
                <li>On your device, navigate to <strong className="text-white">Settings &gt; Apps &gt; Special App Access</strong> and toggle <strong className="text-white">"Install Unknown Apps"</strong> for your browser/files app.</li>
                <li>Tap the downloaded file in your Notification Bar or Files app and click <strong className="text-white">Install</strong>.</li>
                <li>Launch the app from your app drawer. Enter your credentials or scan your authentication QR code to sync.</li>
              </ol>
            </div>

            {/* Sec 2: Emulator Config */}
            <div id="emulator-config" className="space-y-4">
              <h3 className="text-xl font-bold uppercase font-mono border-b border-white/5 pb-2 text-cyan-400">
                2. Running inside PC Emulators
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed font-light">
                If you do not have an Android device or wish to run tests on your PC, you can configure BlueStacks or LDPlayer to emulate the environment:
              </p>
              <div className="p-4 border border-zinc-800 bg-[#0B0B0D] rounded space-y-3 font-mono text-xs">
                <div className="flex items-center gap-2 text-purple-400">
                  <HelpCircle className="w-4 h-4" />
                  <span>RECOMMENDED EMULATORS</span>
                </div>
                <p className="text-zinc-500 text-[11px] leading-relaxed">
                  We recommend <strong className="text-white">LDPlayer 9</strong> or <strong className="text-white">BlueStacks 5 (Android 11 / Pie 64-bit instance)</strong> for optimized frame rates and WebRTC video decoding capability.
                </p>
              </div>
              <ol className="list-decimal list-inside space-y-2 text-xs text-zinc-400 font-mono">
                <li>Download and install your preferred emulator.</li>
                <li>Open the emulator settings and configure it to use:
                  <ul className="list-disc list-inside pl-4 mt-1 space-y-1 text-zinc-500">
                    <li>Graphics Engine: <strong className="text-white">Vulkan</strong> (preferred) or OpenGL</li>
                    <li>CPU/RAM Allocation: <strong className="text-white">4 Cores / 4GB RAM</strong> (minimum)</li>
                    <li>Model: <strong className="text-white">ASUS ROG Phone 2</strong> (or other high-performance profile)</li>
                  </ul>
                </li>
                <li>Drag and drop the downloaded <code className="text-cyan-400">FinalEvolutionLab.apk</code> file into the emulator window to trigger automatic installation.</li>
                <li>Open the app and test the economy updates and real-time HUD overlays.</li>
              </ol>
            </div>

            {/* Sec 3: Win64 Run */}
            <div id="win64-run" className="space-y-4">
              <h3 className="text-xl font-bold uppercase font-mono border-b border-white/5 pb-2 text-cyan-400">
                3. Windows Standalone Build
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed font-light">
                For PC testing, run the Unreal Engine cooked game client directly on Windows:
              </p>
              <ol className="list-decimal list-inside space-y-2 text-xs text-zinc-400 font-mono">
                <li>Download <code className="text-cyan-400">FinalEvolutionLab_Win64.zip</code>.</li>
                <li>Right-click the zip file and choose <strong className="text-white">Extract All</strong> to save to a local folder.</li>
                <li>Open the extracted directory and run the executable file: <code className="text-white">FinalEvolutionLab.exe</code>.</li>
                <li>Connect a controller (Xbox/PlayStation supported) or use standard WASD / Arrow Key controls.</li>
              </ol>
            </div>

            {/* Sec 4: macOS Run */}
            <div id="mac-run" className="space-y-4">
              <h3 className="text-xl font-bold uppercase font-mono border-b border-white/5 pb-2 text-cyan-400">
                4. macOS Standalone Build
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed font-light">
                For macOS testing, run the natively packaged client on Apple Silicon or Intel Macs:
              </p>
              <ol className="list-decimal list-inside space-y-2 text-xs text-zinc-400 font-mono">
                <li>Download <code className="text-cyan-400">FinalEvolutionLab_Mac.zip</code>.</li>
                <li>Double-click the zip file to extract <code className="text-white">FinalEvolutionLab.app</code> (or <code className="text-white">FinalEvolutionLab-Mac-Shipping.app</code>).</li>
                <li>
                  <strong className="text-white">Gatekeeper Bypass Options:</strong>
                  <ul className="list-disc list-inside pl-4 mt-1 space-y-1 text-zinc-500">
                    <li><strong className="text-zinc-300">Method 1 (Finder):</strong> Right-click (or Control-click) the app icon, choose <strong className="text-white">Open</strong> from the shortcut menu, and then click <strong className="text-white">Open</strong> in the confirmation dialog.</li>
                    <li><strong className="text-zinc-300">Method 2 (Terminal CLI):</strong> Open your Terminal app and strip the quarantine attribute using:
                      <pre className="mt-1 p-2 bg-black/40 border border-white/5 rounded text-cyan-400 text-[10px] select-all overflow-x-auto">
                        xattr -d com.apple.quarantine FinalEvolutionLab.app
                      </pre>
                      (or <code className="text-cyan-300">xattr -d com.apple.quarantine FinalEvolutionLab-Mac-Shipping.app</code>)
                    </li>
                  </ul>
                </li>
                <li>Connect a controller (Mac-compatible Xbox/PlayStation controller supported) or use standard WASD keyboard mapping.</li>
              </ol>
            </div>

            {/* Sec 5: Deeplinking */}
            <div id="deeplinking" className="space-y-4">
              <h3 className="text-xl font-bold uppercase font-mono border-b border-white/5 pb-2 text-cyan-400">
                5. Deep Linking Integration
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed font-light">
                Vault mobile clients map deep links to bypass standard lobbies and launch directly into target venues.
              </p>
              
              <div className="space-y-2 font-mono text-xs">
                <div className="text-zinc-400">Supported Schema:</div>
                <div className="p-3 bg-white/5 border border-white/5 rounded flex items-center justify-between">
                  <code className="text-cyan-400">finalevolution://open-mode?id=basketball_h2h</code>
                  <span className="text-[10px] text-zinc-500">Basketball 1v1</span>
                </div>
                <div className="p-3 bg-white/5 border border-white/5 rounded flex items-center justify-between">
                  <code className="text-cyan-400">finalevolution://open-mode?id=brain_brawl</code>
                  <span className="text-[10px] text-zinc-500">Brain Brawl</span>
                </div>
              </div>
            </div>

          </div>

        </div>

      </div>

    </div>
  );
}
