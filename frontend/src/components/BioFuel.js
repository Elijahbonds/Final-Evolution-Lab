/**
 * FEL OS — Bio-Fuel Stripe & Scanner
 *
 * Top-level stripe ABOVE the 4 quadrants showing today's NASM-CNC macros,
 * supportive AI Coach cues, and a deep-link to the scanner / cookbook / DoorDash.
 */
import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import {
  Camera, Soup, Truck, Sparkles, Loader2, X, ChefHat, Beef, Droplet,
  Moon, Wind, Scale, Apple, ChevronRight, Upload, ShoppingCart, Plus
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const CUE_ICON = { Beef, Droplet, Moon, Wind, Scale, Sparkles, Soup };

// ============================================================
// BIOFUEL STRIPE (compact horizontal bar above the 4 quadrants)
// ============================================================
export const BioFuelStripe = ({ onOpenScanner, onOpenCookbook, onOpenDoorDash }) => {
  const [today, setToday] = useState(null);
  const [cues, setCues] = useState([]);

  const refresh = () => {
    axios.get(`${API}/biofuel/today`).then((r) => setToday(r.data)).catch(console.error);
    axios.get(`${API}/biofuel/cues`).then((r) => setCues(r.data.cues || [])).catch(console.error);
  };
  useEffect(() => { refresh(); }, []);

  if (!today) {
    return (
      <div className="border border-emerald-400/20 bg-emerald-400/5 p-4 flex items-center gap-3" data-testid="biofuel-stripe-loading">
        <Loader2 className="w-4 h-4 animate-spin text-emerald-400" />
        <span className="text-xs text-emerald-300">Loading Bio-Fuel…</span>
      </div>
    );
  }

  const macros = [
    { label: "kcal", got: today.consumed.calories, target: today.target.calories, pct: today.pct.calories, color: "text-emerald-400", bar: "bg-emerald-400" },
    { label: "protein", got: today.consumed.protein_g, target: today.target.protein_g, pct: today.pct.protein_g, color: "text-rose-400", bar: "bg-rose-400" },
    { label: "carbs", got: today.consumed.carbs_g, target: today.target.carbs_g, pct: today.pct.carbs_g, color: "text-amber-400", bar: "bg-amber-400" },
    { label: "fats", got: today.consumed.fats_g, target: today.target.fats_g, pct: today.pct.fats_g, color: "text-cyan-400", bar: "bg-cyan-400" },
  ];

  return (
    <div className="border border-emerald-400/30 bg-gradient-to-br from-emerald-400/[0.06] to-zinc-950 p-4" data-testid="biofuel-stripe">
      <div className="flex items-start justify-between flex-wrap gap-3 mb-3">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 border border-emerald-400/40 flex items-center justify-center bg-emerald-400/10">
            <Soup className="w-4 h-4 text-emerald-400" />
          </div>
          <div>
            <div className="text-[10px] tracking-[0.4em] uppercase text-emerald-400">FEL OS · Bio-Fuel · NASM-CNC</div>
            <div className="font-bold tracking-tight" data-testid="biofuel-intent-label">{today.intent_label}</div>
            {today.targets_confidence === "default_assumption" && today.assumption_note && (
              <div className="text-[10px] text-amber-400/90 max-w-[220px]" data-testid="biofuel-targets-note">{today.assumption_note}</div>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <button data-testid="biofuel-scan-btn" onClick={onOpenScanner} className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-400 text-black text-xs font-bold hover:bg-emerald-300 transition-colors">
            <Camera className="w-3.5 h-3.5" /> Scan Meal
          </button>
          <button data-testid="biofuel-cookbook-btn" onClick={onOpenCookbook} className="flex items-center gap-1.5 px-3 py-1.5 border border-emerald-400/40 text-emerald-300 text-xs font-bold hover:bg-emerald-400/10 transition-colors">
            <ChefHat className="w-3.5 h-3.5" /> 3D Cookbook
          </button>
          <button data-testid="biofuel-doordash-btn" onClick={onOpenDoorDash} className="flex items-center gap-1.5 px-3 py-1.5 border border-zinc-700 text-zinc-300 text-xs font-bold hover:border-emerald-400/40 hover:text-emerald-300 transition-colors">
            <Truck className="w-3.5 h-3.5" /> Performance Delivery
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3" data-testid="biofuel-macros">
        {macros.map((m) => (
          <div key={m.label} data-testid={`biofuel-macro-${m.label}`} className="space-y-1">
            <div className="flex items-baseline justify-between">
              <span className="text-[10px] uppercase tracking-wider text-zinc-500">{m.label}</span>
              <span className={`text-xs font-mono ${m.color}`}>{m.pct}%</span>
            </div>
            <div className="h-1.5 bg-zinc-900 overflow-hidden">
              <div className={`h-full ${m.bar} transition-all`} style={{ width: `${Math.min(100, m.pct)}%` }} />
            </div>
            <div className="text-xs text-zinc-400 font-mono">{m.got}<span className="text-zinc-600">/{m.target}</span></div>
          </div>
        ))}
      </div>

      {cues.length > 0 && (
        <div className="mt-3 pt-3 border-t border-emerald-400/10 space-y-2" data-testid="biofuel-cues">
          {cues.slice(0, 2).map((c) => {
            const Icon = CUE_ICON[c.icon] || Sparkles;
            return (
              <div key={c.id} data-testid={`cue-${c.id}`} className="flex items-start gap-2 text-xs">
                <Icon className="w-3.5 h-3.5 text-emerald-400 mt-0.5 shrink-0" />
                <div className="flex-1 min-w-0">
                  <span className="font-bold text-emerald-300">{c.title}</span>
                  <span className="text-zinc-600"> · </span>
                  <span className="text-zinc-400">{c.message}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ============================================================
// SCANNER MODAL
// ============================================================
export const BioFuelScanner = ({ onClose, onLogged }) => {
  const [model, setModel] = useState("gemini-2.5-flash");
  const [imageData, setImageData] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);
  const [hint, setHint] = useState("");
  const [scanning, setScanning] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const fileRef = useRef(null);

  const MAX_EDGE_PX = 1280;
  const JPEG_Q = 0.82;

  const onFile = (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!/^image\/(jpeg|png|webp)$/.test(f.type)) {
      setError("Use JPEG, PNG, or WEBP (no SVG/GIF/HEIC)");
      return;
    }
    setError(null);
    setResult(null);
    const reader = new FileReader();
    reader.onload = (ev) => {
      const dataUrl = ev.target.result;
      setImagePreview(dataUrl);
      const img = new Image();
      img.onload = () => {
        let { width, height } = img;
        if (width > MAX_EDGE_PX || height > MAX_EDGE_PX) {
          const scale = MAX_EDGE_PX / Math.max(width, height);
          width = Math.round(width * scale);
          height = Math.round(height * scale);
        }
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, width, height);
        const jpeg = canvas.toDataURL("image/jpeg", JPEG_Q);
        setImageData(String(jpeg).split(",")[1]);
      };
      img.onerror = () => setError("Could not decode image — try another photo.");
      img.src = dataUrl;
    };
    reader.readAsDataURL(f);
  };

  const scan = async () => {
    if (!imageData) return;
    setScanning(true); setError(null); setResult(null);
    try {
      const r = await axios.post(`${API}/biofuel/scan`, { model, image_base64: imageData, hint: hint || undefined });
      setResult(r.data);
    } catch (e) {
      const d = e.response?.data?.detail;
      setError(typeof d === "string" ? d : d ? JSON.stringify(d) : "Scan failed");
    } finally {
      setScanning(false);
    }
  };

  const confirmScan = async () => {
    if (!result?.scan_id) return;
    setConfirming(true); setError(null);
    try {
      const r = await axios.post(`${API}/biofuel/scan/confirm`, { scan_id: result.scan_id });
      setResult((prev) => ({
        ...prev,
        ...r.data,
        pending_confirmation:
          r.data.already_confirmed || r.data.pending_confirmation === false ? false : prev?.pending_confirmation,
        nutri_shards_awarded: r.data.nutri_shards_awarded ?? prev?.nutri_shards_awarded,
      }));
      if (onLogged && !r.data.already_confirmed) onLogged();
    } catch (e) {
      const d = e.response?.data?.detail;
      setError(typeof d === "string" ? d : d ? JSON.stringify(d) : "Confirm failed");
    } finally {
      setConfirming(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 fade-in" onClick={onClose} data-testid="biofuel-scanner-modal">
      <div className="relative w-full max-w-2xl bg-zinc-950 border border-emerald-400/30 p-6 space-y-5" onClick={(e) => e.stopPropagation()}>
        <button data-testid="scanner-close" onClick={onClose} className="absolute top-4 right-4 text-zinc-500 hover:text-white">
          <X className="w-5 h-5" />
        </button>

        <div>
          <div className="text-[10px] tracking-[0.4em] uppercase text-emerald-400">Bio-Fuel · AI Vision Scanner</div>
          <h3 className="text-2xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>SCAN YOUR MEAL</h3>
          <p className="text-xs text-zinc-400 mt-1">Photo → estimate (pending). Confirm to log today&apos;s meal and earn Nutri-Shards.</p>
        </div>

        {/* Model picker */}
        <div className="grid grid-cols-2 gap-2" data-testid="scanner-model-picker">
          {[
            { id: "gemini-2.5-flash", label: "Gemini 2.5 Flash", note: "Fastest · food-recognition specialist" },
            { id: "gpt-5.2", label: "GPT-5.2", note: "Strongest reasoning · slower" },
          ].map((m) => (
            <button
              key={m.id}
              data-testid={`scanner-model-${m.id}`}
              onClick={() => setModel(m.id)}
              className={`text-left p-3 border transition-colors ${model === m.id ? "border-emerald-400 bg-emerald-400/10" : "border-zinc-800 hover:border-zinc-600"}`}
            >
              <div className={`text-sm font-bold ${model === m.id ? "text-emerald-300" : "text-zinc-200"}`}>{m.label}</div>
              <div className="text-[11px] text-zinc-500">{m.note}</div>
            </button>
          ))}
        </div>

        {/* Image picker */}
        <div className="border border-dashed border-zinc-700 p-4 text-center">
          {imagePreview ? (
            <img src={imagePreview} alt="" className="mx-auto max-h-56 rounded" data-testid="scanner-preview" />
          ) : (
            <div className="text-zinc-500 text-sm py-8">No image selected</div>
          )}
          <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" onChange={onFile} className="hidden" data-testid="scanner-file-input" />
          <button
            data-testid="scanner-pick-btn"
            onClick={() => fileRef.current?.click()}
            className="mt-3 inline-flex items-center gap-2 px-4 py-2 border border-zinc-700 hover:border-emerald-400/40 text-sm"
          >
            <Upload className="w-4 h-4" /> {imagePreview ? "Replace photo" : "Pick a photo"}
          </button>
        </div>

        {/* Optional hint */}
        <input
          data-testid="scanner-hint"
          value={hint}
          onChange={(e) => setHint(e.target.value)}
          placeholder="Optional context (e.g., 'post-workout', 'breakfast')"
          className="w-full bg-zinc-900 border border-zinc-800 px-3 py-2 text-sm text-zinc-100 focus:border-emerald-400 focus:outline-none"
        />

        {error && <div className="p-3 bg-red-400/10 border border-red-400/40 text-xs text-red-300" data-testid="scanner-error">{typeof error === "string" ? error : JSON.stringify(error)}</div>}

        {!result ? (
          <button
            data-testid="scanner-submit-btn"
            disabled={!imageData || scanning}
            onClick={scan}
            className={`w-full py-3 font-bold ${imageData ? "bg-emerald-400 text-black hover:bg-emerald-300" : "bg-zinc-900 text-zinc-600 cursor-not-allowed"}`}
          >
            {scanning ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : "Scan Meal"}
          </button>
        ) : (
          <div className="border border-emerald-400/40 bg-emerald-400/5 p-4 space-y-2" data-testid="scanner-result">
            <div className="flex items-baseline justify-between">
              <div className="font-bold text-emerald-300">{result.label}</div>
              <div className="text-xs text-zinc-500 font-mono">{result.model}</div>
            </div>
            <div className="grid grid-cols-4 gap-2 text-center">
              {[
                ["kcal", result.calories, "text-emerald-400"],
                ["P", `${result.protein_g}g`, "text-rose-400"],
                ["C", `${result.carbs_g}g`, "text-amber-400"],
                ["F", `${result.fats_g}g`, "text-cyan-400"],
              ].map(([l, v, c]) => (
                <div key={l} className="p-2 bg-zinc-900">
                  <div className={`text-lg font-black ${c}`}>{v}</div>
                  <div className="text-[10px] text-zinc-500 uppercase">{l}</div>
                </div>
              ))}
            </div>
            {result.pending_confirmation ? (
              <>
                <div className="text-xs text-amber-300/90 flex items-start gap-2 pt-1">
                  <Sparkles className="w-3.5 h-3.5 shrink-0 mt-0.5 text-amber-400" />
                  Pending — review the estimate, then confirm to add it to today and award shards (vision can misread photos).
                </div>
                <button
                  data-testid="scanner-confirm-btn"
                  disabled={confirming}
                  onClick={confirmScan}
                  className="w-full mt-2 py-3 bg-emerald-400 text-black text-sm font-bold hover:bg-emerald-300 disabled:opacity-50"
                >
                  {confirming ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : "Confirm & log meal"}
                </button>
              </>
            ) : (
              <div className="text-xs text-zinc-400 flex items-center gap-2 pt-1">
                <Sparkles className="w-3.5 h-3.5 text-emerald-400" />
                +{result.nutri_shards_awarded ?? 0} Nutri-Shards · logged to today
              </div>
            )}
            <button data-testid="scanner-done-btn" onClick={onClose} className="w-full mt-2 py-2 bg-zinc-100 text-black text-sm font-bold hover:bg-white">Done</button>
          </div>
        )}

        <div className="text-[11px] text-zinc-600 leading-relaxed">
          NASM-CNC vision: {model === "gemini-2.5-flash" ? "Gemini 2.5 Flash" : "GPT-5.2"} estimates calories, macros, and athletic micros (collagen, omega-3, magnesium, sodium). Use as guidance, not a replacement for clinical advice.
        </div>
      </div>
    </div>
  );
};

// ============================================================
// 3D COOKBOOK MODAL
// ============================================================
export const BioFuelCookbook = ({ onClose }) => {
  const [data, setData] = useState(null);
  const [active, setActive] = useState(null);
  const [intent, setIntent] = useState(null);

  useEffect(() => {
    const url = intent ? `${API}/biofuel/recipes?intent=${intent}` : `${API}/biofuel/recipes`;
    axios.get(url).then((r) => setData(r.data)).catch(console.error);
  }, [intent]);

  const spinCss = `
@keyframes fel-dish-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.fel-recipe-dish-spin { animation: fel-dish-spin 48s linear infinite; will-change: transform; }
@media (prefers-reduced-motion: reduce) { .fel-recipe-dish-spin { animation: none; } }
`;

  const openCart = async (recipeId) => {
    try {
      const r = await axios.post(`${API}/biofuel/instacart-cart`, { recipe_id: recipeId });
      window.open(r.data.deep_link, "_blank");
    } catch (e) { console.error(e); }
  };

  return (
    <div className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 fade-in" onClick={onClose} data-testid="biofuel-cookbook-modal">
      <div className="relative w-full max-w-4xl max-h-[90vh] bg-zinc-950 border border-emerald-400/30 p-6 overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <button data-testid="cookbook-close" onClick={onClose} className="absolute top-4 right-4 text-zinc-500 hover:text-white">
          <X className="w-5 h-5" />
        </button>
        <div className="mb-4">
          <div className="text-[10px] tracking-[0.4em] uppercase text-emerald-400">FEL OS · 3D Cookbook</div>
          <h3 className="text-2xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>RECIPES BY ATHLETIC INTENT</h3>
        </div>
        <style dangerouslySetInnerHTML={{ __html: spinCss }} />

        {/* Intent filter */}
        {data && (
          <div className="flex gap-2 flex-wrap mb-4" data-testid="cookbook-intents">
            <button data-testid="intent-all" onClick={() => setIntent(null)} className={`px-3 py-1 text-xs border ${!intent ? "border-emerald-400 bg-emerald-400/10 text-emerald-300" : "border-zinc-800 text-zinc-400"}`}>All</button>
            {data.intents.map((i) => (
              <button key={i.id} data-testid={`intent-${i.id}`} onClick={() => setIntent(i.id)} className={`px-3 py-1 text-xs border ${intent === i.id ? "border-emerald-400 bg-emerald-400/10 text-emerald-300" : "border-zinc-800 text-zinc-400 hover:border-zinc-600"}`}>
                {i.label}
              </button>
            ))}
          </div>
        )}

        {!data ? (
          <div className="flex justify-center py-12"><Loader2 className="w-6 h-6 animate-spin text-emerald-400" /></div>
        ) : active ? (
          <RecipeDetail recipe={active} onBack={() => setActive(null)} onCart={() => openCart(active.id)} />
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3" data-testid="cookbook-grid">
            {data.recipes.map((r) => (
              <RecipeCard key={r.id} recipe={r} onClick={async () => {
                const det = await axios.get(`${API}/biofuel/recipes/${r.id}`);
                setActive(det.data);
              }} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// "3D" recipe card — animated SVG dish with rotating ingredient nodes
const RecipeCard = ({ recipe, onClick }) => {
  const [a, b, c] = recipe.viz_palette || ["#34d399", "#059669", "#064e3b"];
  return (
    <button data-testid={`recipe-${recipe.id}`} onClick={onClick} className="text-left border border-zinc-800 hover:border-emerald-400/40 bg-zinc-950 p-4 group transition-colors">
      <div className="relative h-32 mb-3 overflow-hidden bg-black flex items-center justify-center">
        {/* CSS-driven rotation (NUTRI-10) — no per-card JS timers */}
        <svg viewBox="-100 -100 200 200" className="w-32 h-32 fel-recipe-dish-spin">
          <defs>
            <radialGradient id={`g-${recipe.id}`}>
              <stop offset="0%" stopColor={a} />
              <stop offset="60%" stopColor={b} />
              <stop offset="100%" stopColor={c} />
            </radialGradient>
          </defs>
          <ellipse cx="0" cy="0" rx="80" ry="20" fill={c} opacity="0.6" />
          <circle cx="0" cy="-2" r="60" fill={`url(#g-${recipe.id})`} />
          {[0, 60, 120, 180, 240, 300].map((deg) => {
            const r = 38;
            const x = r * Math.cos((deg * Math.PI) / 180);
            const y = r * Math.sin((deg * Math.PI) / 180);
            return <circle key={deg} cx={x} cy={y} r="6" fill={a} opacity="0.85" />;
          })}
        </svg>
      </div>
      <div className="flex items-baseline justify-between mb-1">
        <div className="font-bold group-hover:text-emerald-300 transition-colors">{recipe.title}</div>
        <div className="text-[10px] text-zinc-500">{recipe.duration_min} min</div>
      </div>
      <div className="text-[11px] text-emerald-400 uppercase tracking-wider mb-2">{recipe.intent_label}</div>
      <div className="grid grid-cols-4 gap-1 text-center text-[11px]">
        <Pill l="kcal" v={recipe.macros.calories} />
        <Pill l="P" v={`${recipe.macros.protein_g}g`} />
        <Pill l="C" v={`${recipe.macros.carbs_g}g`} />
        <Pill l="F" v={`${recipe.macros.fats_g}g`} />
      </div>
    </button>
  );
};

const Pill = ({ l, v }) => (
  <div className="bg-zinc-900 py-1">
    <div className="font-mono text-zinc-100">{v}</div>
    <div className="text-zinc-600 text-[9px] uppercase">{l}</div>
  </div>
);

const RecipeDetail = ({ recipe, onBack, onCart }) => (
  <div className="space-y-4" data-testid={`recipe-detail-${recipe.id}`}>
    <button data-testid="recipe-back" onClick={onBack} className="text-xs text-zinc-400 hover:text-emerald-300">← Back to cookbook</button>
    <div>
      <div className="text-[10px] uppercase tracking-[0.4em] text-emerald-400">{recipe.intent_label}</div>
      <h4 className="text-2xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>{recipe.title}</h4>
      <p className="text-sm text-zinc-300 mt-2">{recipe.summary}</p>
    </div>
    <div className="grid grid-cols-4 gap-2">
      <Pill l="kcal" v={recipe.macros.calories} />
      <Pill l="protein" v={`${recipe.macros.protein_g}g`} />
      <Pill l="carbs" v={`${recipe.macros.carbs_g}g`} />
      <Pill l="fats" v={`${recipe.macros.fats_g}g`} />
    </div>
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <div className="text-[10px] uppercase tracking-wider text-zinc-500 mb-2">Ingredients</div>
        <ul className="text-sm text-zinc-200 space-y-1">
          {recipe.ingredients.map((ing, i) => (
            <li key={i} className="flex justify-between border-b border-zinc-900 py-1">
              <span>{ing.name}</span>
              <span className="text-zinc-500 font-mono text-xs">{ing.qty}</span>
            </li>
          ))}
        </ul>
      </div>
      <div>
        <div className="text-[10px] uppercase tracking-wider text-zinc-500 mb-2">Method</div>
        <ol className="text-sm text-zinc-200 space-y-2 list-decimal list-inside">
          {recipe.steps.map((s, i) => (<li key={i}>{s}</li>))}
        </ol>
      </div>
    </div>
    <button data-testid="recipe-cart-btn" onClick={onCart} className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-emerald-400 text-black font-bold hover:bg-emerald-300">
      <ShoppingCart className="w-4 h-4" /> Send to Instacart
    </button>
    <div className="text-[11px] text-zinc-600">Awaiting Instacart Connect partner credentials for one-click cart push. For now, Instacart opens with your ingredient list pre-searched.</div>
  </div>
);

// ============================================================
// DOORDASH PERFORMANCE DELIVERY MODAL
// ============================================================
export const BioFuelDoorDash = ({ onClose, onLogged }) => {
  const [matches, setMatches] = useState(null);
  const [intent, setIntent] = useState(null);
  const [logging, setLogging] = useState(false);

  const search = async (intentId) => {
    setIntent(intentId);
    setMatches(null);
    try {
      const r = await axios.post(`${API}/biofuel/doordash-search`, intentId ? { intent: intentId } : {});
      setMatches(r.data);
    } catch (e) { console.error(e); }
  };
  useEffect(() => { search(null); }, []);

  const logMeal = async (meal) => {
    if (!matches || logging) return;
    const dayKey = new Date().toISOString().slice(0, 10);
    const client_event_id = `dd:${matches.intent}:${meal.name}:${dayKey}`;
    setLogging(true);
    try {
      await axios.post(`${API}/biofuel/log`, {
        label: meal.name,
        calories: meal.macros.calories,
        protein_g: meal.macros.protein_g,
        carbs_g: meal.macros.carbs_g,
        fats_g: meal.macros.fats_g,
        hydration_ml: typeof meal.macros?.hydration_ml === "number" ? meal.macros.hydration_ml : 0,
        intent: matches.intent,
        source: "doordash",
        client_event_id,
      });
      if (onLogged) onLogged();
    } catch (e) { console.error(e); }
    finally { setLogging(false); }
  };

  const intents = [
    { id: "fascial_hydration", label: "Fascial Hydration" },
    { id: "cns_ignition", label: "CNS Ignition" },
    { id: "post_dunk_recovery", label: "Post-Dunk Recovery" },
    { id: "endurance_base", label: "Endurance Base" },
    { id: "sleep_anabolic", label: "Sleep Anabolic" },
  ];

  return (
    <div className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 fade-in" onClick={onClose} data-testid="biofuel-doordash-modal">
      <div className="relative w-full max-w-3xl max-h-[90vh] bg-zinc-950 border border-emerald-400/30 p-6 overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <button data-testid="doordash-close" onClick={onClose} className="absolute top-4 right-4 text-zinc-500 hover:text-white"><X className="w-5 h-5" /></button>
        <div className="mb-4">
          <div className="text-[10px] tracking-[0.4em] uppercase text-emerald-400">Performance Delivery · DoorDash</div>
          <h3 className="text-2xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>MACRO-AWARE DELIVERY</h3>
          <p className="text-xs text-zinc-400 mt-1">We filter local options to fit your remaining macros for the day.</p>
        </div>

        <div className="flex gap-2 flex-wrap mb-4">
          <button data-testid="doordash-intent-auto" onClick={() => search(null)} className={`px-3 py-1 text-xs border ${!intent ? "border-emerald-400 bg-emerald-400/10 text-emerald-300" : "border-zinc-800 text-zinc-400"}`}>Auto (today's intent)</button>
          {intents.map((i) => (
            <button key={i.id} data-testid={`doordash-intent-${i.id}`} onClick={() => search(i.id)} className={`px-3 py-1 text-xs border ${intent === i.id ? "border-emerald-400 bg-emerald-400/10 text-emerald-300" : "border-zinc-800 text-zinc-400 hover:border-zinc-600"}`}>{i.label}</button>
          ))}
        </div>

        {!matches ? (
          <div className="flex justify-center py-12"><Loader2 className="w-6 h-6 animate-spin text-emerald-400" /></div>
        ) : matches.no_safe_matches ? (
          <div className="rounded border border-amber-500/30 bg-amber-500/5 p-4 text-sm text-zinc-300" data-testid="doordash-no-safe-matches">
            <div className="text-amber-400/90 font-bold text-xs uppercase tracking-wider mb-1">No safe delivery matches</div>
            <p className="text-zinc-400 leading-relaxed">{matches.message || "All options were removed by your allergy or diet filters for this macro window. Try another intent or log a custom meal."}</p>
          </div>
        ) : (
          <div className="space-y-2" data-testid="doordash-matches">
            <div className="text-xs text-zinc-500 mb-1">
              Fitting <span className="text-emerald-300">{matches.intent_label}</span> · ≤ {matches.max_calories} kcal · ≥ {matches.min_protein_g}g protein
            </div>
            {matches.matches.map((m, i) => (
              <div key={i} data-testid={`doordash-match-${i}`} className="flex items-center justify-between p-3 border border-zinc-800 hover:border-emerald-400/40 bg-zinc-950 transition-colors">
                <div className="min-w-0">
                  <div className="font-medium truncate">{m.name}</div>
                  <div className="text-xs text-zinc-500 font-mono">
                    {m.macros.calories} kcal · {m.macros.protein_g}P · {m.macros.carbs_g}C · {m.macros.fats_g}F
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button data-testid={`doordash-log-${i}`} onClick={() => logMeal(m)} disabled={logging} className="p-2 border border-zinc-700 text-zinc-300 hover:border-emerald-400/40 hover:text-emerald-300 disabled:opacity-40 disabled:pointer-events-none" title="Log to today">
                    <Plus className="w-3.5 h-3.5" />
                  </button>
                  <a data-testid={`doordash-open-${i}`} href={m.deep_link} target="_blank" rel="noreferrer" className="px-3 py-2 bg-emerald-400 text-black text-xs font-bold hover:bg-emerald-300 inline-flex items-center gap-1">
                    Open <ChevronRight className="w-3 h-3" />
                  </a>
                </div>
              </div>
            ))}
            <div className="text-[11px] text-zinc-600 pt-2">
              Awaiting DoorDash Marketplace partner credentials for in-app macro-aware ordering. For now, "Open" deep-links to DoorDash with the meal pre-searched.
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default BioFuelStripe;
