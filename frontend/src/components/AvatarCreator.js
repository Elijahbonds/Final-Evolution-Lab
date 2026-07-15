/**
 * AvatarCreator — full avatar editor connected to the System Scan.
 * Tabs: Body · Face · Hair · Clothes · Accessories
 * Scan Import maps PRQ metrics → body model + build sliders.
 */
import React, { useState, useEffect, useCallback } from "react";
import axios from "axios";
import {
  User, Scan, Save, RefreshCw, Zap, ChevronLeft, ChevronRight,
  Check, Shirt, Scissors, Palette, Shield, Dumbbell
} from "lucide-react";
import { API_URL } from "@/lib/apiClient";

const API = API_URL;

// ─── Default state ────────────────────────────────────────────────────────────
export const DEFAULT_AVATAR = {
  gender: "masculine",
  body_model: "athletic",
  build_muscle: 55,
  build_height: 60,
  face_shape: "oval",
  eye_style: "default",
  jaw_style: "default",
  skin_tone: "#8D5524",
  hair_style: "fade",
  hair_color: "#2C1810",
  jersey_style: "performance",
  jersey_color: "#5CE1E6",
  jersey_number: "1",
  shorts_color: "#111827",
  shoe_style: "court",
  shoe_color: "#FFFFFF",
  accessories: [],
};

// ─── Option catalogs ──────────────────────────────────────────────────────────
const GENDER_OPTIONS = [
  { id: "masculine", label: "Masculine" },
  { id: "feminine",  label: "Feminine"  },
  { id: "nonbinary", label: "Non-Binary" },
];

const BODY_MODELS = [
  { id: "lean",       label: "Lean",       desc: "Explosive speed-first",  muscle: 35, icon: "⚡" },
  { id: "athletic",   label: "Athletic",   desc: "Balanced performance",   muscle: 55, icon: "🏃" },
  { id: "balanced",   label: "Balanced",   desc: "All-round versatility",  muscle: 50, icon: "⚖️" },
  { id: "powerhouse", label: "Powerhouse", desc: "Strength-dominant",      muscle: 80, icon: "💪" },
];

const FACE_SHAPES = ["oval", "round", "square", "angular", "heart"];
const EYE_STYLES  = ["default", "intense", "soft", "wide", "hooded"];
const JAW_STYLES  = ["default", "strong", "soft", "defined", "sharp"];

const SKIN_TONES = [
  { hex: "#FDDBB4", label: "Porcelain" },
  { hex: "#F1C27D", label: "Fair"      },
  { hex: "#E0AC69", label: "Medium"    },
  { hex: "#C68642", label: "Tan"       },
  { hex: "#8D5524", label: "Brown"     },
  { hex: "#5C3317", label: "Deep"      },
  { hex: "#3B1F0A", label: "Ebony"     },
  { hex: "#D4956A", label: "Warm"      },
];

const HAIR_STYLES = [
  { id: "bald",     label: "Bald"     },
  { id: "buzz",     label: "Buzz Cut" },
  { id: "fade",     label: "Fade"     },
  { id: "short",    label: "Short"    },
  { id: "medium",   label: "Medium"   },
  { id: "long",     label: "Long"     },
  { id: "curly",    label: "Curly"    },
  { id: "afro",     label: "Afro"     },
  { id: "braids",   label: "Braids"   },
  { id: "dreads",   label: "Dreads"   },
  { id: "mohawk",   label: "Mohawk"   },
  { id: "ponytail", label: "Ponytail" },
];

const HAIR_COLORS = [
  { hex: "#2C1810", label: "Black"    },
  { hex: "#4A2E1A", label: "Dark Br." },
  { hex: "#7B4A2D", label: "Brown"    },
  { hex: "#C19A6B", label: "Caramel"  },
  { hex: "#E8C99A", label: "Blonde"   },
  { hex: "#D4A017", label: "Gold"     },
  { hex: "#CC3333", label: "Red"      },
  { hex: "#999999", label: "Silver"   },
  { hex: "#FFFFFF", label: "White"    },
  { hex: "#5CE1E6", label: "Cyan"     },
  { hex: "#FF6B6B", label: "Coral"    },
  { hex: "#A855F7", label: "Violet"   },
];

const JERSEY_STYLES = ["performance", "retro", "streetwear", "sleeveless", "compression"];

const JERSEY_COLORS = [
  { hex: "#5CE1E6", label: "Cyan"   },
  { hex: "#FF6B6B", label: "Red"    },
  { hex: "#00FF9D", label: "Green"  },
  { hex: "#FFB800", label: "Gold"   },
  { hex: "#A855F7", label: "Purple" },
  { hex: "#3B82F6", label: "Blue"   },
  { hex: "#F97316", label: "Orange" },
  { hex: "#FFFFFF", label: "White"  },
  { hex: "#111827", label: "Black"  },
];

const SHORTS_COLORS = [
  { hex: "#111827", label: "Black"  },
  { hex: "#1E3A8A", label: "Navy"   },
  { hex: "#5CE1E6", label: "Cyan"   },
  { hex: "#FF6B6B", label: "Red"    },
  { hex: "#FFFFFF", label: "White"  },
  { hex: "#374151", label: "Gray"   },
  { hex: "#A855F7", label: "Purple" },
  { hex: "#00FF9D", label: "Green"  },
];

const SHOE_STYLES = ["court", "trainer", "cleat", "retro", "hi-top", "slide"];
const SHOE_COLORS = [
  { hex: "#FFFFFF", label: "White"  },
  { hex: "#111827", label: "Black"  },
  { hex: "#5CE1E6", label: "Cyan"   },
  { hex: "#FFB800", label: "Gold"   },
  { hex: "#FF6B6B", label: "Red"    },
  { hex: "#3B82F6", label: "Blue"   },
  { hex: "#A855F7", label: "Purple" },
  { hex: "#374151", label: "Gray"   },
];

const ACCESSORIES = [
  { id: "headband",            label: "Headband"      },
  { id: "wristband",           label: "Wristband"     },
  { id: "compression_sleeve",  label: "Sleeve"        },
  { id: "chain",               label: "Chain"         },
  { id: "glasses",             label: "Glasses"       },
  { id: "tattoo_arm",          label: "Arm Tattoo"    },
  { id: "tattoo_chest",        label: "Chest Tattoo"  },
  { id: "face_paint",          label: "Face Paint"    },
  { id: "beard",               label: "Beard"         },
  { id: "mask",                label: "Mask"          },
];

// ─── PRQ → avatar mapping ─────────────────────────────────────────────────────
function prqToAvatarConfig(prq) {
  const strength  = prq.strength  ?? 70;
  const speed     = prq.speed     ?? 70;
  const power     = prq.power     ?? 70;
  const agility   = prq.agility   ?? 70;
  const endurance = prq.endurance ?? 70;

  let body_model = "athletic";
  const strengthScore = strength * 0.6 + power * 0.4;
  const speedScore    = speed * 0.6 + agility * 0.4;

  if      (strengthScore > 80) body_model = "powerhouse";
  else if (speedScore    > 80) body_model = "lean";
  else if (strengthScore > 65 && speedScore > 65) body_model = "athletic";
  else body_model = "balanced";

  const build_muscle = Math.min(100, Math.round(strength * 0.5 + power * 0.3 + endurance * 0.2));
  const build_height = Math.min(100, Math.round(agility * 0.4 + speed * 0.3 + endurance * 0.3));

  return { body_model, build_muscle, build_height };
}

// ─── SVG Avatar preview ───────────────────────────────────────────────────────
function AvatarSVG({ config }) {
  const isFem = config.gender === "feminine";

  // Body proportions derived from sliders
  const muscleFactor = config.build_muscle / 100;   // 0–1
  const heightFactor = config.build_height / 100;   // 0–1

  const W   = 200;
  const H   = 360;
  const cx  = W / 2;

  // Head
  const headR = 34 + (isFem ? 2 : 0);
  const headY = 52;

  // Neck
  const neckW = isFem ? 11 : 13 + muscleFactor * 3;
  const neckH = 16;

  // Shoulders
  const shoulderW = 44 + muscleFactor * 28 + (isFem ? -6 : 0);
  const shoulderY = headY + headR + neckH;

  // Torso
  const torsoW_top = shoulderW;
  const torsoW_bot = isFem ? shoulderW * 0.9 : shoulderW * 0.78;
  const torsoH     = 80 + heightFactor * 14;

  // Waist / hips
  const hipW  = isFem ? torsoW_bot * 1.25 : torsoW_bot * 0.92;
  const hipH  = 12;
  const hipY  = shoulderY + torsoH;

  // Shorts
  const shortsH = 44 + heightFactor * 8;
  const shortsY = hipY + hipH;

  // Legs
  const legW   = 18 + muscleFactor * 6;
  const legH   = 70 + heightFactor * 18;
  const legY   = shortsY + shortsH;
  const legGap = hipW * 0.22;

  // Shoes
  const shoeW = 30 + muscleFactor * 4;
  const shoeH = 16;
  const shoeY = legY + legH;

  // Arms
  const armW     = 14 + muscleFactor * 6 + (isFem ? -2 : 0);
  const armH     = torsoH * 0.75;
  const armTopY  = shoulderY + 4;
  const armBotW  = armW * 0.8;

  // Face shape → head viewBox path
  const faceRadius = (() => {
    switch (config.face_shape) {
      case "round":    return { rx: headR,      ry: headR + 2 };
      case "square":   return { rx: headR - 4,  ry: headR,     rx2: 4  };
      case "angular":  return { rx: headR - 6,  ry: headR + 2  };
      case "heart":    return { rx: headR + 2,  ry: headR - 2  };
      default:         return { rx: headR - 2,  ry: headR + 4  }; // oval
    }
  })();

  // Eye positions
  const eyeY    = headY - 4;
  const eyeL    = cx - 11;
  const eyeR    = cx + 11;
  const eyeSize = config.eye_style === "wide" ? 4 : config.eye_style === "soft" ? 2.5 : 3;

  // Hair paths by style
  const hairPath = (() => {
    const hx = cx;
    const hy = headY - faceRadius.ry;
    switch (config.hair_style) {
      case "bald":  return null;
      case "buzz":
        return <ellipse cx={hx} cy={hy + faceRadius.ry * 0.35} rx={faceRadius.rx * 0.98} ry={faceRadius.ry * 0.48} fill={config.hair_color} />;
      case "short":
        return <ellipse cx={hx} cy={hy + faceRadius.ry * 0.25} rx={faceRadius.rx + 2} ry={faceRadius.ry * 0.55} fill={config.hair_color} />;
      case "fade":
        return <>
          <ellipse cx={hx} cy={hy + faceRadius.ry * 0.2} rx={faceRadius.rx + 1} ry={faceRadius.ry * 0.52} fill={config.hair_color} />
          <rect x={cx - faceRadius.rx - 2} y={headY - faceRadius.ry * 0.6} width={4} height={faceRadius.ry * 0.5} rx={2} fill={config.hair_color} />
          <rect x={cx + faceRadius.rx - 2} y={headY - faceRadius.ry * 0.6} width={4} height={faceRadius.ry * 0.5} rx={2} fill={config.hair_color} />
        </>;
      case "medium":
        return <ellipse cx={hx} cy={hy + faceRadius.ry * 0.15} rx={faceRadius.rx + 4} ry={faceRadius.ry * 0.7} fill={config.hair_color} />;
      case "long":
        return <>
          <ellipse cx={hx} cy={hy + faceRadius.ry * 0.1} rx={faceRadius.rx + 5} ry={faceRadius.ry * 0.75} fill={config.hair_color} />
          <rect x={cx - faceRadius.rx - 5} y={headY} width={10} height={torsoH * 0.35} rx={4} fill={config.hair_color} />
          <rect x={cx + faceRadius.rx - 5} y={headY} width={10} height={torsoH * 0.35} rx={4} fill={config.hair_color} />
        </>;
      case "curly":
        return <>
          <ellipse cx={hx} cy={hy + faceRadius.ry * 0.1} rx={faceRadius.rx + 10} ry={faceRadius.ry * 0.85} fill={config.hair_color} />
          {[...Array(6)].map((_, i) => (
            <circle key={i} cx={hx + (i - 2.5) * 10} cy={hy + 4} r={6} fill={config.hair_color} />
          ))}
        </>;
      case "afro":
        return <>
          <circle cx={hx} cy={headY - faceRadius.ry * 0.4} r={faceRadius.rx + 16} fill={config.hair_color} />
        </>;
      case "braids": {
        const braidY = headY - faceRadius.ry * 0.05;
        return <>
          <ellipse cx={hx} cy={hy + faceRadius.ry * 0.2} rx={faceRadius.rx + 3} ry={faceRadius.ry * 0.6} fill={config.hair_color} />
          {[-10, 0, 10].map((xOff, i) => (
            <rect key={i} x={cx + xOff - 3} y={braidY} width={6} height={torsoH * 0.5} rx={3} fill={config.hair_color} />
          ))}
        </>;
      }
      case "dreads": {
        const drY = headY - faceRadius.ry * 0.05;
        return <>
          <ellipse cx={hx} cy={hy + faceRadius.ry * 0.2} rx={faceRadius.rx + 2} ry={faceRadius.ry * 0.55} fill={config.hair_color} />
          {[-18, -10, -2, 6, 14].map((xOff, i) => (
            <rect key={i} x={cx + xOff - 4} y={drY} width={8} height={torsoH * 0.45 + i * 4} rx={4} fill={config.hair_color} />
          ))}
        </>;
      }
      case "mohawk":
        return <>
          <rect x={cx - 8} y={hy - 18} width={16} height={faceRadius.ry * 0.7 + 18} rx={6} fill={config.hair_color} />
        </>;
      case "ponytail":
        return <>
          <ellipse cx={hx} cy={hy + faceRadius.ry * 0.2} rx={faceRadius.rx + 3} ry={faceRadius.ry * 0.6} fill={config.hair_color} />
          <rect x={cx - 5} y={headY - faceRadius.ry * 1.0} width={10} height={torsoH * 0.5} rx={4} fill={config.hair_color} />
        </>;
      default:
        return <ellipse cx={hx} cy={hy + faceRadius.ry * 0.25} rx={faceRadius.rx + 2} ry={faceRadius.ry * 0.55} fill={config.hair_color} />;
    }
  })();

  // Jersey decoration based on style
  const jerseyAccent = (() => {
    const darken = (hex, factor = 0.7) => {
      const r = parseInt(hex.slice(1, 3), 16);
      const g = parseInt(hex.slice(3, 5), 16);
      const b = parseInt(hex.slice(5, 7), 16);
      return `rgb(${Math.round(r * factor)},${Math.round(g * factor)},${Math.round(b * factor)})`;
    };
    switch (config.jersey_style) {
      case "retro":
        return <rect x={cx - torsoW_top * 0.5 + 4} y={shoulderY + 8} width={torsoW_top - 8} height={6} fill={darken(config.jersey_color)} rx={1} />;
      case "streetwear":
        return <>
          <rect x={cx - 4} y={shoulderY} width={8} height={torsoH * 0.5} fill={darken(config.jersey_color)} />
        </>;
      case "sleeveless":
        return null;
      case "compression":
        return <rect x={cx - torsoW_top * 0.5 + 6} y={shoulderY + torsoH * 0.6} width={torsoW_top - 12} height={4} fill={darken(config.jersey_color)} rx={1} />;
      default: // performance
        return <line x1={cx - torsoW_top * 0.3} y1={shoulderY + 10} x2={cx + torsoW_top * 0.3} y2={shoulderY + 10} stroke={darken(config.jersey_color)} strokeWidth={2} />;
    }
  })();

  // Accessories overlays
  const accessoryOverlays = [];
  if (config.accessories.includes("headband")) {
    accessoryOverlays.push(
      <rect key="hb" x={cx - faceRadius.rx - 2} y={headY - faceRadius.ry * 0.35} width={(faceRadius.rx + 2) * 2} height={7} rx={3} fill="#5CE1E6" opacity={0.9} />
    );
  }
  if (config.accessories.includes("chain")) {
    accessoryOverlays.push(
      <ellipse key="chain" cx={cx} cy={shoulderY + 14} rx={14} ry={8} fill="none" stroke="#FFB800" strokeWidth={2} />
    );
  }
  if (config.accessories.includes("glasses")) {
    accessoryOverlays.push(
      <g key="glasses">
        <circle cx={eyeL} cy={eyeY} r={7} fill="none" stroke="#374151" strokeWidth={2} />
        <circle cx={eyeR} cy={eyeY} r={7} fill="none" stroke="#374151" strokeWidth={2} />
        <line x1={eyeL + 7} y1={eyeY} x2={eyeR - 7} y2={eyeY} stroke="#374151" strokeWidth={2} />
      </g>
    );
  }
  if (config.accessories.includes("wristband")) {
    const wbY = armTopY + armH - 18;
    accessoryOverlays.push(
      <g key="wb">
        <rect x={cx - shoulderW - 4} y={wbY} width={armBotW} height={8} rx={3} fill="#FF6B6B" />
        <rect x={cx + shoulderW - armBotW + 4} y={wbY} width={armBotW} height={8} rx={3} fill="#FF6B6B" />
      </g>
    );
  }
  if (config.accessories.includes("mask")) {
    accessoryOverlays.push(
      <ellipse key="mask" cx={cx} cy={headY + 6} rx={faceRadius.rx - 2} ry={14} fill="#111827" opacity={0.85} />
    );
  }
  if (config.accessories.includes("beard")) {
    accessoryOverlays.push(
      <ellipse key="beard" cx={cx} cy={headY + faceRadius.ry * 0.55} rx={faceRadius.rx * 0.65} ry={10} fill={config.hair_color} opacity={0.9} />
    );
  }
  if (config.accessories.includes("tattoo_arm")) {
    accessoryOverlays.push(
      <rect key="tatt" x={cx - shoulderW - 2} y={armTopY + armH * 0.3} width={armW - 2} height={22} rx={2} fill="#374151" opacity={0.5} />
    );
  }
  if (config.accessories.includes("face_paint")) {
    accessoryOverlays.push(
      <g key="fp">
        <line x1={eyeL - 6} y1={eyeY - 6} x2={eyeL + 6} y2={eyeY + 4} stroke="#5CE1E6" strokeWidth={2.5} strokeLinecap="round" />
        <line x1={eyeR - 6} y1={eyeY + 4} x2={eyeR + 6} y2={eyeY - 6} stroke="#5CE1E6" strokeWidth={2.5} strokeLinecap="round" />
      </g>
    );
  }

  // Jersey text color (ensure contrast)
  const textColor = config.jersey_color === "#FFFFFF" || config.jersey_color === "#FFB800" ? "#111827" : "#FFFFFF";

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ maxHeight: 360 }}>
      {/* Background glow */}
      <radialGradient id="glow" cx="50%" cy="60%" r="50%">
        <stop offset="0%"   stopColor={config.jersey_color} stopOpacity={0.12} />
        <stop offset="100%" stopColor="#000000"             stopOpacity={0}    />
      </radialGradient>
      <rect x={0} y={0} width={W} height={H} fill="url(#glow)" />

      {/* ── Arms (behind torso) ─────────────────────────── */}
      <polygon
        points={`
          ${cx - shoulderW - 2},${armTopY}
          ${cx - shoulderW - 2 - 4},${armTopY + armH}
          ${cx - shoulderW - 2 - 4 + armBotW},${armTopY + armH}
          ${cx - shoulderW + armW - 2},${armTopY}
        `}
        fill={config.jersey_style === "sleeveless" ? config.skin_tone : config.jersey_color}
      />
      <polygon
        points={`
          ${cx + shoulderW + 2},${armTopY}
          ${cx + shoulderW + 6},${armTopY + armH}
          ${cx + shoulderW + 6 - armBotW},${armTopY + armH}
          ${cx + shoulderW - armW + 2},${armTopY}
        `}
        fill={config.jersey_style === "sleeveless" ? config.skin_tone : config.jersey_color}
      />

      {/* ── Torso ─────────────────────────────────────────── */}
      <polygon
        points={`
          ${cx - torsoW_top},${shoulderY}
          ${cx + torsoW_top},${shoulderY}
          ${cx + torsoW_bot},${shoulderY + torsoH}
          ${cx - torsoW_bot},${shoulderY + torsoH}
        `}
        fill={config.jersey_color}
      />
      {jerseyAccent}

      {/* Jersey number */}
      <text
        x={cx} y={shoulderY + torsoH * 0.52}
        textAnchor="middle" dominantBaseline="middle"
        fontSize={22} fontWeight="bold" fontFamily="Barlow Condensed, sans-serif"
        fill={textColor} opacity={0.85}
      >{config.jersey_number || "1"}</text>

      {/* ── Hips ──────────────────────────────────────────── */}
      <rect x={cx - hipW} y={hipY} width={hipW * 2} height={hipH} rx={4} fill={config.shorts_color} />

      {/* ── Shorts ────────────────────────────────────────── */}
      <polygon
        points={`
          ${cx - hipW},${shortsY}
          ${cx + hipW},${shortsY}
          ${cx + hipW * 0.85},${shortsY + shortsH}
          ${cx - hipW * 0.85},${shortsY + shortsH}
        `}
        fill={config.shorts_color}
      />
      {/* Shorts split line */}
      <line x1={cx} y1={shortsY} x2={cx} y2={shortsY + shortsH * 0.9} stroke="#00000030" strokeWidth={2} />

      {/* ── Legs ──────────────────────────────────────────── */}
      {/* Left leg */}
      <rect x={cx - legGap - legW} y={legY} width={legW} height={legH} rx={legW * 0.4} fill={config.skin_tone} />
      {/* Right leg */}
      <rect x={cx + legGap}        y={legY} width={legW} height={legH} rx={legW * 0.4} fill={config.skin_tone} />

      {/* ── Shoes ─────────────────────────────────────────── */}
      {/* Left shoe */}
      <rect x={cx - legGap - legW - 4} y={shoeY} width={shoeW} height={shoeH} rx={config.shoe_style === "hi-top" ? 2 : 6} fill={config.shoe_color} />
      {config.shoe_style === "hi-top" && (
        <rect x={cx - legGap - legW - 4} y={shoeY - 10} width={legW + 4} height={12} rx={2} fill={config.shoe_color} />
      )}
      {/* Right shoe */}
      <rect x={cx + legGap - 4} y={shoeY} width={shoeW} height={shoeH} rx={config.shoe_style === "hi-top" ? 2 : 6} fill={config.shoe_color} />
      {config.shoe_style === "hi-top" && (
        <rect x={cx + legGap - 4} y={shoeY - 10} width={legW + 4} height={12} rx={2} fill={config.shoe_color} />
      )}

      {/* ── Neck ──────────────────────────────────────────── */}
      <rect x={cx - neckW} y={headY + faceRadius.ry - 4} width={neckW * 2} height={neckH + 4} rx={2} fill={config.skin_tone} />

      {/* ── Head ──────────────────────────────────────────── */}
      {/* Hair (behind head for clean layering) */}
      {hairPath}
      {/* Head fill */}
      <ellipse cx={cx} cy={headY} rx={faceRadius.rx} ry={faceRadius.ry} fill={config.skin_tone} />

      {/* ── Face features ─────────────────────────────────── */}
      {/* Eyes */}
      <circle cx={eyeL} cy={eyeY} r={eyeSize} fill={config.accessories.includes("glasses") ? "transparent" : "#1A1A2E"} />
      <circle cx={eyeR} cy={eyeY} r={eyeSize} fill={config.accessories.includes("glasses") ? "transparent" : "#1A1A2E"} />
      {/* Eye shine */}
      <circle cx={eyeL + 1} cy={eyeY - 1} r={0.9} fill="#FFFFFF90" />
      <circle cx={eyeR + 1} cy={eyeY - 1} r={0.9} fill="#FFFFFF90" />
      {/* Eyebrows */}
      {config.eye_style === "intense" ? (
        <>
          <line x1={eyeL - 5} y1={eyeY - 7} x2={eyeL + 5} y2={eyeY - 9} stroke="#2C1810" strokeWidth={2.5} strokeLinecap="round" />
          <line x1={eyeR - 5} y1={eyeY - 9} x2={eyeR + 5} y2={eyeY - 7} stroke="#2C1810" strokeWidth={2.5} strokeLinecap="round" />
        </>
      ) : (
        <>
          <line x1={eyeL - 5} y1={eyeY - 8} x2={eyeL + 5} y2={eyeY - 8} stroke="#2C181060" strokeWidth={2} strokeLinecap="round" />
          <line x1={eyeR - 5} y1={eyeY - 8} x2={eyeR + 5} y2={eyeY - 8} stroke="#2C181060" strokeWidth={2} strokeLinecap="round" />
        </>
      )}
      {/* Nose */}
      <ellipse cx={cx} cy={headY + 8} rx={2.5} ry={3.5} fill="#00000018" />
      {/* Mouth — expression */}
      <path
        d={`M ${cx - 7} ${headY + 17} Q ${cx} ${headY + 21} ${cx + 7} ${headY + 17}`}
        stroke="#00000040" strokeWidth={1.8} fill="none" strokeLinecap="round"
      />
      {/* Jaw accent for angular/square */}
      {(config.face_shape === "square" || config.face_shape === "angular") && (
        <line x1={cx - faceRadius.rx + 2} y1={headY + faceRadius.ry - 6}
              x2={cx + faceRadius.rx - 2} y2={headY + faceRadius.ry - 6}
              stroke="#00000015" strokeWidth={2} />
      )}

      {/* ── Accessory overlays ────────────────────────────── */}
      {accessoryOverlays}

      {/* ── Compression sleeve ────────────────────────────── */}
      {config.accessories.includes("compression_sleeve") && (
        <rect x={cx - shoulderW - 6} y={armTopY + armH * 0.25}
              width={armW + 2} height={armH * 0.55} rx={3}
              fill="#374151" opacity={0.55} />
      )}
    </svg>
  );
}

// ─── Reusable sub-components ──────────────────────────────────────────────────
function TabButton({ active, onClick, icon: Icon, label }) {
  return (
    <button
      onClick={onClick}
      className={`flex flex-col items-center gap-1 px-3 py-2 text-xs transition-colors ${
        active
          ? "text-cyan-400 border-b-2 border-cyan-400"
          : "text-zinc-500 hover:text-zinc-300"
      }`}
    >
      <Icon className="w-4 h-4" />
      <span className="font-medium whitespace-nowrap">{label}</span>
    </button>
  );
}

function OptionChip({ value, selected, onClick, children }) {
  return (
    <button
      data-testid={`avatar-opt-${value}`}
      onClick={onClick}
      className={`px-3 py-1.5 text-sm capitalize rounded transition-colors ${
        selected
          ? "bg-cyan-400 text-black font-semibold"
          : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
      }`}
    >
      {children || value}
    </button>
  );
}

function ColorSwatch({ hex, label, selected, onClick }) {
  return (
    <button
      data-testid={`avatar-color-${hex.replace("#", "")}`}
      onClick={onClick}
      title={label}
      className={`relative w-9 h-9 rounded transition-all border-2 ${
        selected ? "border-cyan-400 scale-110 ring-1 ring-cyan-400/40" : "border-zinc-700 hover:border-zinc-500"
      }`}
      style={{ background: hex }}
    >
      {selected && <Check className="absolute inset-0 m-auto w-3.5 h-3.5 text-white drop-shadow" />}
    </button>
  );
}

function BuildSlider({ label, value, onChange, leftLabel, rightLabel }) {
  return (
    <div>
      <div className="flex justify-between items-center mb-1.5">
        <span className="text-xs text-zinc-400 uppercase tracking-widest">{label}</span>
        <span className="font-mono text-sm text-cyan-400">{value}</span>
      </div>
      <input
        type="range" min={0} max={100} value={value}
        onChange={e => onChange(Number(e.target.value))}
        data-testid={`avatar-slider-${label.toLowerCase().replace(/\s+/g, "-")}`}
        className="w-full h-2 rounded-full appearance-none bg-zinc-700 cursor-pointer"
        style={{
          background: `linear-gradient(to right, #5CE1E6 0%, #5CE1E6 ${value}%, #3F3F46 ${value}%, #3F3F46 100%)`
        }}
      />
      <div className="flex justify-between text-xs text-zinc-600 mt-1">
        <span>{leftLabel}</span><span>{rightLabel}</span>
      </div>
    </div>
  );
}

function SectionHeading({ children }) {
  return (
    <h3 className="text-xs uppercase tracking-widest text-zinc-500 mb-3 mt-1">{children}</h3>
  );
}

// ─── Main component ───────────────────────────────────────────────────────────
export function AvatarCreator({ onSave }) {
  const [config, setConfig]       = useState(DEFAULT_AVATAR);
  const [activeTab, setActiveTab] = useState("body");
  const [scanLoading, setScanLoading] = useState(false);
  const [saveState, setSaveState] = useState("idle"); // idle | saving | saved
  const [scanApplied, setScanApplied] = useState(false);

  // Load saved config from API on mount
  useEffect(() => {
    Promise.all([
      axios.get(`${API}/avatar/config`),
      axios.get(`${API}/avatar/options`),
    ])
      .then(([c]) => setConfig(prev => ({ ...DEFAULT_AVATAR, ...c.data })))
      .catch(() => {/* stay with DEFAULT_AVATAR */});
  }, []);

  const set = useCallback((key, value) => {
    setConfig(prev => ({ ...prev, [key]: value }));
  }, []);

  const toggleAccessory = useCallback((id) => {
    setConfig(prev => ({
      ...prev,
      accessories: prev.accessories.includes(id)
        ? prev.accessories.filter(a => a !== id)
        : [...prev.accessories, id],
    }));
  }, []);

  // Apply a body model preset (also updates sliders)
  const applyBodyModel = useCallback((model) => {
    const preset = BODY_MODELS.find(b => b.id === model);
    setConfig(prev => ({
      ...prev,
      body_model: model,
      build_muscle: preset ? preset.muscle : prev.build_muscle,
    }));
  }, []);

  // Scan Import — read PRQ and auto-configure build
  const importFromScan = async () => {
    setScanLoading(true);
    try {
      const res = await axios.get(`${API}/prq/metrics`);
      const suggested = prqToAvatarConfig(res.data);
      setConfig(prev => ({ ...prev, ...suggested }));
      setScanApplied(true);
      setTimeout(() => setScanApplied(false), 3000);
    } catch {
      // Offline fallback — use mock PRQ
      const fallbackPRQ = { strength: 75, speed: 72, power: 76, agility: 73, endurance: 70 };
      const suggested = prqToAvatarConfig(fallbackPRQ);
      setConfig(prev => ({ ...prev, ...suggested }));
      setScanApplied(true);
      setTimeout(() => setScanApplied(false), 3000);
    } finally {
      setScanLoading(false);
    }
  };

  const saveAvatar = async () => {
    setSaveState("saving");
    try {
      await axios.put(`${API}/avatar/config`, config);
      if (onSave) onSave(config);
    } catch {}
    setSaveState("saved");
    setTimeout(() => setSaveState("idle"), 2000);
  };

  const TABS = [
    { id: "body",        icon: Dumbbell,  label: "Body"       },
    { id: "face",        icon: User,      label: "Face"       },
    { id: "hair",        icon: Scissors,  label: "Hair"       },
    { id: "clothes",     icon: Shirt,     label: "Clothes"    },
    { id: "accessories", icon: Shield,    label: "Extras"     },
  ];

  return (
    <div className="space-y-6 fade-in" data-testid="avatar-creator">
      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <p className="overline mb-1">CUSTOMIZE YOUR ATHLETE</p>
          <h1 className="text-4xl font-black" style={{ fontFamily: "Barlow Condensed" }}>
            AVATAR CREATOR
          </h1>
        </div>
        <div className="flex items-center gap-3">
          {/* Scan Import */}
          <button
            data-testid="avatar-scan-import"
            onClick={importFromScan}
            disabled={scanLoading}
            className={`flex items-center gap-2 btn-secondary transition-all ${
              scanApplied ? "border-green-400 text-green-400" : ""
            }`}
          >
            {scanLoading ? (
              <RefreshCw className="w-4 h-4 animate-spin" />
            ) : scanApplied ? (
              <Check className="w-4 h-4" />
            ) : (
              <Scan className="w-4 h-4" />
            )}
            {scanApplied ? "Scan Applied!" : "Import Scan"}
          </button>
          {/* Save */}
          <button
            data-testid="save-avatar"
            onClick={saveAvatar}
            disabled={saveState === "saving"}
            className={`flex items-center gap-2 btn-primary ${
              saveState === "saved" ? "!bg-green-400 !text-black" : ""
            }`}
          >
            {saveState === "saving" ? (
              <RefreshCw className="w-4 h-4 animate-spin" />
            ) : saveState === "saved" ? (
              <Check className="w-4 h-4" />
            ) : (
              <Save className="w-4 h-4" />
            )}
            {saveState === "saved" ? "Saved!" : "Save Avatar"}
          </button>
        </div>
      </div>

      {/* Scan hint */}
      {!scanApplied && (
        <div className="flex items-center gap-2 text-xs text-zinc-500 bg-zinc-900/50 border border-zinc-800 px-4 py-2 rounded">
          <Zap className="w-3.5 h-3.5 text-cyan-400 shrink-0" />
          <span>
            <strong className="text-zinc-300">Tip:</strong> Hit <strong className="text-cyan-400">Import Scan</strong> to auto-configure your body build from your PRQ performance metrics.
          </span>
        </div>
      )}

      {/* ── Main Layout ──────────────────────────────────────────────────────── */}
      <div className="grid lg:grid-cols-[280px_1fr] gap-6">

        {/* Left: SVG Preview */}
        <div className="space-y-4">
          <div
            data-testid="avatar-preview"
            className="surface-card p-4 flex flex-col items-center"
          >
            <AvatarSVG config={config} />
            {/* Quick info strip */}
            <div className="w-full mt-4 grid grid-cols-2 gap-2 text-xs">
              <div className="bg-black/40 p-2 text-center rounded">
                <span className="text-zinc-500 block">GENDER</span>
                <span className="text-zinc-200 capitalize">{config.gender}</span>
              </div>
              <div className="bg-black/40 p-2 text-center rounded">
                <span className="text-zinc-500 block">BUILD</span>
                <span className="text-zinc-200 capitalize">{config.body_model}</span>
              </div>
              <div className="bg-black/40 p-2 text-center rounded">
                <span className="text-zinc-500 block">MUSCLE</span>
                <span className="text-cyan-400">{config.build_muscle}</span>
              </div>
              <div className="bg-black/40 p-2 text-center rounded">
                <span className="text-zinc-500 block">HAIR</span>
                <span className="text-zinc-200 capitalize">{config.hair_style}</span>
              </div>
            </div>
          </div>

          {/* Randomize */}
          <button
            data-testid="avatar-randomize"
            onClick={() => {
              const pick = arr => arr[Math.floor(Math.random() * arr.length)];
              const colors = [...SKIN_TONES, ...HAIR_COLORS];
              setConfig({
                gender:       pick(GENDER_OPTIONS).id,
                body_model:   pick(BODY_MODELS).id,
                build_muscle: Math.round(Math.random() * 70 + 20),
                build_height: Math.round(Math.random() * 60 + 30),
                face_shape:   pick(FACE_SHAPES),
                eye_style:    pick(EYE_STYLES),
                jaw_style:    pick(JAW_STYLES),
                skin_tone:    pick(SKIN_TONES).hex,
                hair_style:   pick(HAIR_STYLES).id,
                hair_color:   pick(HAIR_COLORS).hex,
                jersey_style: pick(JERSEY_STYLES),
                jersey_color: pick(JERSEY_COLORS).hex,
                jersey_number: String(Math.ceil(Math.random() * 99)),
                shorts_color: pick(SHORTS_COLORS).hex,
                shoe_style:   pick(SHOE_STYLES),
                shoe_color:   pick(SHOE_COLORS).hex,
                accessories:  ACCESSORIES
                  .filter(() => Math.random() > 0.75)
                  .map(a => a.id),
              });
            }}
            className="btn-secondary w-full flex items-center justify-center gap-2 text-sm"
          >
            <RefreshCw className="w-4 h-4" />
            Randomize
          </button>
        </div>

        {/* Right: Tab Editor */}
        <div className="surface-card" data-testid="avatar-options">
          {/* Tab bar */}
          <div className="flex border-b border-zinc-800 overflow-x-auto">
            {TABS.map(t => (
              <TabButton
                key={t.id}
                active={activeTab === t.id}
                onClick={() => setActiveTab(t.id)}
                icon={t.icon}
                label={t.label}
              />
            ))}
          </div>

          <div className="p-5 space-y-6">
            {/* ── BODY ─────────────────────────────────────────────────────── */}
            {activeTab === "body" && (
              <div className="space-y-6">
                {/* Gender */}
                <div>
                  <SectionHeading>Gender / Presentation</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {GENDER_OPTIONS.map(g => (
                      <OptionChip
                        key={g.id} value={g.id}
                        selected={config.gender === g.id}
                        onClick={() => set("gender", g.id)}
                      >{g.label}</OptionChip>
                    ))}
                  </div>
                </div>

                {/* Body Model */}
                <div>
                  <SectionHeading>Body Model</SectionHeading>
                  <div className="grid grid-cols-2 gap-3">
                    {BODY_MODELS.map(m => (
                      <button
                        key={m.id}
                        data-testid={`avatar-body-model-${m.id}`}
                        onClick={() => applyBodyModel(m.id)}
                        className={`p-3 text-left rounded border transition-all ${
                          config.body_model === m.id
                            ? "border-cyan-400 bg-cyan-400/10 text-white"
                            : "border-zinc-700 bg-zinc-900 text-zinc-400 hover:border-zinc-600"
                        }`}
                      >
                        <div className="text-xl mb-1">{m.icon}</div>
                        <div className="font-bold text-sm">{m.label}</div>
                        <div className="text-xs text-zinc-500">{m.desc}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Build Sliders */}
                <div className="space-y-5">
                  <SectionHeading>Build Sliders</SectionHeading>
                  <BuildSlider
                    label="Muscle Mass"
                    value={config.build_muscle}
                    onChange={v => set("build_muscle", v)}
                    leftLabel="Lean"
                    rightLabel="Jacked"
                  />
                  <BuildSlider
                    label="Height / Frame"
                    value={config.build_height}
                    onChange={v => set("build_height", v)}
                    leftLabel="Compact"
                    rightLabel="Tall"
                  />
                </div>
              </div>
            )}

            {/* ── FACE ─────────────────────────────────────────────────────── */}
            {activeTab === "face" && (
              <div className="space-y-6">
                {/* Skin Tone */}
                <div>
                  <SectionHeading>Skin Tone</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {SKIN_TONES.map(s => (
                      <ColorSwatch
                        key={s.hex} hex={s.hex} label={s.label}
                        selected={config.skin_tone === s.hex}
                        onClick={() => set("skin_tone", s.hex)}
                      />
                    ))}
                  </div>
                </div>

                {/* Face Shape */}
                <div>
                  <SectionHeading>Face Shape</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {FACE_SHAPES.map(f => (
                      <OptionChip
                        key={f} value={f}
                        selected={config.face_shape === f}
                        onClick={() => set("face_shape", f)}
                      />
                    ))}
                  </div>
                </div>

                {/* Eye Style */}
                <div>
                  <SectionHeading>Eyes</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {EYE_STYLES.map(e => (
                      <OptionChip
                        key={e} value={e}
                        selected={config.eye_style === e}
                        onClick={() => set("eye_style", e)}
                      />
                    ))}
                  </div>
                </div>

                {/* Jaw Style */}
                <div>
                  <SectionHeading>Jaw / Chin</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {JAW_STYLES.map(j => (
                      <OptionChip
                        key={j} value={j}
                        selected={config.jaw_style === j}
                        onClick={() => set("jaw_style", j)}
                      />
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* ── HAIR ─────────────────────────────────────────────────────── */}
            {activeTab === "hair" && (
              <div className="space-y-6">
                {/* Hair Style grid */}
                <div>
                  <SectionHeading>Hair Style</SectionHeading>
                  <div className="grid grid-cols-3 gap-2">
                    {HAIR_STYLES.map(h => (
                      <button
                        key={h.id}
                        data-testid={`avatar-hair-${h.id}`}
                        onClick={() => set("hair_style", h.id)}
                        className={`py-2.5 px-2 text-sm rounded border text-center transition-all ${
                          config.hair_style === h.id
                            ? "border-cyan-400 bg-cyan-400/10 text-white font-semibold"
                            : "border-zinc-700 bg-zinc-900 text-zinc-400 hover:border-zinc-600"
                        }`}
                      >
                        {h.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Hair Color */}
                <div>
                  <SectionHeading>Hair Color</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {HAIR_COLORS.map(c => (
                      <ColorSwatch
                        key={c.hex} hex={c.hex} label={c.label}
                        selected={config.hair_color === c.hex}
                        onClick={() => set("hair_color", c.hex)}
                      />
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* ── CLOTHES ──────────────────────────────────────────────────── */}
            {activeTab === "clothes" && (
              <div className="space-y-6">
                {/* Jersey Style */}
                <div>
                  <SectionHeading>Jersey Style</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {JERSEY_STYLES.map(s => (
                      <OptionChip
                        key={s} value={s}
                        selected={config.jersey_style === s}
                        onClick={() => set("jersey_style", s)}
                      />
                    ))}
                  </div>
                </div>

                {/* Jersey Number */}
                <div>
                  <SectionHeading>Jersey Number</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {["1","5","7","10","11","13","21","23","24","30","32","33"].map(n => (
                      <button
                        key={n}
                        data-testid={`avatar-number-${n}`}
                        onClick={() => set("jersey_number", n)}
                        className={`w-10 h-10 font-bold text-sm rounded border transition-all ${
                          config.jersey_number === n
                            ? "border-cyan-400 bg-cyan-400/10 text-cyan-400"
                            : "border-zinc-700 bg-zinc-900 text-zinc-400 hover:border-zinc-500"
                        }`}
                      >{n}</button>
                    ))}
                    {/* Custom number input */}
                    <input
                      type="number" min={0} max={99}
                      value={config.jersey_number}
                      onChange={e => set("jersey_number", String(Math.min(99, Math.max(0, Number(e.target.value) || 0)))}
                      data-testid="avatar-number-custom"
                      placeholder="##"
                      className="w-14 h-10 bg-zinc-900 border border-zinc-700 text-center text-sm text-zinc-200 rounded focus:border-cyan-400 focus:outline-none"
                    />
                  </div>
                </div>

                {/* Jersey Color */}
                <div>
                  <SectionHeading>Jersey Color</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {JERSEY_COLORS.map(c => (
                      <ColorSwatch
                        key={c.hex} hex={c.hex} label={c.label}
                        selected={config.jersey_color === c.hex}
                        onClick={() => set("jersey_color", c.hex)}
                      />
                    ))}
                  </div>
                </div>

                {/* Shorts Color */}
                <div>
                  <SectionHeading>Shorts Color</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {SHORTS_COLORS.map(c => (
                      <ColorSwatch
                        key={c.hex} hex={c.hex} label={c.label}
                        selected={config.shorts_color === c.hex}
                        onClick={() => set("shorts_color", c.hex)}
                      />
                    ))}
                  </div>
                </div>

                {/* Shoe Style */}
                <div>
                  <SectionHeading>Shoe Style</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {SHOE_STYLES.map(s => (
                      <OptionChip
                        key={s} value={s}
                        selected={config.shoe_style === s}
                        onClick={() => set("shoe_style", s)}
                      />
                    ))}
                  </div>
                </div>

                {/* Shoe Color */}
                <div>
                  <SectionHeading>Shoe Color</SectionHeading>
                  <div className="flex flex-wrap gap-2">
                    {SHOE_COLORS.map(c => (
                      <ColorSwatch
                        key={c.hex} hex={c.hex} label={c.label}
                        selected={config.shoe_color === c.hex}
                        onClick={() => set("shoe_color", c.hex)}
                      />
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* ── ACCESSORIES ──────────────────────────────────────────────── */}
            {activeTab === "accessories" && (
              <div className="space-y-4">
                <SectionHeading>Accessories &amp; Extras</SectionHeading>
                <p className="text-xs text-zinc-500 -mt-2">Mix and match multiple extras — they stack on the avatar preview.</p>
                <div className="grid grid-cols-2 gap-3">
                  {ACCESSORIES.map(acc => {
                    const active = config.accessories.includes(acc.id);
                    return (
                      <button
                        key={acc.id}
                        data-testid={`avatar-acc-${acc.id}`}
                        onClick={() => toggleAccessory(acc.id)}
                        className={`flex items-center justify-between px-4 py-3 rounded border text-sm transition-all ${
                          active
                            ? "border-cyan-400 bg-cyan-400/10 text-white"
                            : "border-zinc-700 bg-zinc-900 text-zinc-400 hover:border-zinc-600"
                        }`}
                      >
                        <span className="capitalize">{acc.label}</span>
                        {active && <Check className="w-4 h-4 text-cyan-400 shrink-0" />}
                      </button>
                    );
                  })}
                </div>

                {config.accessories.length > 0 && (
                  <div className="mt-4 pt-4 border-t border-zinc-800">
                    <span className="text-xs text-zinc-500 uppercase tracking-widest">Equipped</span>
                    <div className="flex flex-wrap gap-2 mt-2">
                      {config.accessories.map(id => {
                        const acc = ACCESSORIES.find(a => a.id === id);
                        return (
                          <span
                            key={id}
                            className="text-xs px-2.5 py-1 rounded-full bg-cyan-400/15 text-cyan-300 border border-cyan-400/30 flex items-center gap-1.5"
                          >
                            {acc?.label || id}
                            <button
                              onClick={() => toggleAccessory(id)}
                              className="text-cyan-400/60 hover:text-cyan-400"
                            >×</button>
                          </span>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
