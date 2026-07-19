// Face tab of the Closet: swatches + sliders per feature group. Emits partial
// FaceConfig changes upward; ClosetScreen applies them to the live rig preview.

import type { FaceConfig, HairStyleId, FacialHairId } from '../shared/closetContracts';
import { SKIN_SWATCHES } from '../shared/closetContracts';

const HAIR_STYLES: { id: HairStyleId; label: string }[] = [
  { id: 'afro', label: 'Afro' }, { id: 'high_top', label: 'High Top' },
  { id: 'braids', label: 'Braids' }, { id: 'locs', label: 'Locs' },
  { id: 'cornrows', label: 'Cornrows' }, { id: 'twists', label: 'Twists' },
  { id: 'curly', label: 'Curly' }, { id: 'wavy', label: 'Wavy' },
  { id: 'straight_short', label: 'Straight · Short' }, { id: 'straight_long', label: 'Straight · Long' },
  { id: 'ponytail', label: 'Ponytail' }, { id: 'buns', label: 'Buns' },
  { id: 'buzz', label: 'Buzz' }, { id: 'bald', label: 'Bald' }, { id: 'hijab', label: 'Hijab' },
];

const HAIR_COLORS = ['#0d0a08', '#1f1b16', '#3b2a1a', '#5a3a20', '#8a5a2b', '#b58143', '#d9b380', '#5b5b5b', '#b8b8b8', '#d94f30', '#7c3aed', '#0ea5e9'];
const EYE_COLORS = ['#2a1a0e', '#4a2f1d', '#6b4423', '#3e5c2f', '#2f5c5c', '#2f4a7c', '#6b7280'];
const FACIAL_HAIR: { id: FacialHairId | null; label: string }[] = [
  { id: null, label: 'None' }, { id: 'stubble', label: 'Stubble' },
  { id: 'goatee', label: 'Goatee' }, { id: 'mustache', label: 'Mustache' }, { id: 'full_beard', label: 'Beard' },
];

function Slider(props: { label: string; value: number; onChange: (v: number) => void }) {
  return (
    <label className="block">
      <span className="flex justify-between text-[11px] text-slate-400">
        <span>{props.label}</span>
      </span>
      <input type="range" min={0} max={1} step={0.01} value={props.value}
        onChange={(e) => props.onChange(+e.target.value)}
        className="w-full accent-cyan-400" />
    </label>
  );
}

function Swatches(props: { colors: string[]; value: string; onChange: (c: string) => void }) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {props.colors.map((c) => (
        <button key={c} onClick={() => props.onChange(c)}
          style={{ background: c }}
          className={`h-7 w-7 rounded-full border-2 ${props.value === c ? 'border-cyan-400' : 'border-transparent'}`} />
      ))}
    </div>
  );
}

export function FaceEditor(props: {
  face: FaceConfig;
  section: 'skin' | 'face' | 'hair' | 'eyes' | 'mouth_nose';
  onChange: (face: FaceConfig) => void;
}) {
  const f = props.face;
  const set = (patch: Partial<FaceConfig>) => props.onChange({ ...f, ...patch });

  switch (props.section) {
    case 'skin':
      return (
        <div className="space-y-3">
          <h4 className="text-[11px] font-black tracking-widest text-slate-500">SKIN TONE</h4>
          <Swatches colors={SKIN_SWATCHES} value={f.skinTone} onChange={(skinTone) => set({ skinTone })} />
          <label className="block text-[11px] text-slate-400">Fine tune
            <input type="color" value={f.skinTone}
              onChange={(e) => set({ skinTone: e.target.value })}
              className="ml-2 h-7 w-12 rounded border-0 bg-transparent" />
          </label>
          <Slider label="Freckles" value={f.extras.freckles}
            onChange={(v) => set({ extras: { ...f.extras, freckles: v } })} />
        </div>
      );

    case 'face':
      return (
        <div className="space-y-2">
          <h4 className="text-[11px] font-black tracking-widest text-slate-500">FACE SHAPE</h4>
          <Slider label="Width" value={f.faceShape.width} onChange={(v) => set({ faceShape: { ...f.faceShape, width: v } })} />
          <Slider label="Jaw" value={f.faceShape.jaw} onChange={(v) => set({ faceShape: { ...f.faceShape, jaw: v } })} />
          <Slider label="Cheeks" value={f.faceShape.cheeks} onChange={(v) => set({ faceShape: { ...f.faceShape, cheeks: v } })} />
          <h4 className="pt-2 text-[11px] font-black tracking-widest text-slate-500">FACIAL HAIR</h4>
          <div className="flex flex-wrap gap-1.5">
            {FACIAL_HAIR.map((fh) => (
              <button key={fh.label}
                onClick={() => set({ extras: { ...f.extras, facialHairId: fh.id } })}
                className={`rounded-full px-3 py-1 text-[11px] font-bold ${
                  f.extras.facialHairId === fh.id ? 'bg-cyan-400 text-black' : 'bg-slate-800 text-slate-300'}`}>
                {fh.label}
              </button>
            ))}
          </div>
        </div>
      );

    case 'hair':
      return (
        <div className="space-y-3">
          <h4 className="text-[11px] font-black tracking-widest text-slate-500">STYLE</h4>
          <div className="grid grid-cols-3 gap-1.5">
            {HAIR_STYLES.map((h) => (
              <button key={h.id} onClick={() => set({ hair: { ...f.hair, styleId: h.id } })}
                className={`rounded-lg px-2 py-2 text-[11px] font-bold ${
                  f.hair.styleId === h.id ? 'bg-cyan-400 text-black' : 'bg-slate-800 text-slate-300'}`}>
                {h.label}
              </button>
            ))}
          </div>
          <h4 className="text-[11px] font-black tracking-widest text-slate-500">COLOR</h4>
          <Swatches colors={HAIR_COLORS} value={f.hair.color} onChange={(color) => set({ hair: { ...f.hair, color } })} />
        </div>
      );

    case 'eyes':
      return (
        <div className="space-y-2">
          <h4 className="text-[11px] font-black tracking-widest text-slate-500">EYES</h4>
          <Slider label="Shape" value={f.eyes.shape} onChange={(v) => set({ eyes: { ...f.eyes, shape: v } })} />
          <Slider label="Size" value={f.eyes.size} onChange={(v) => set({ eyes: { ...f.eyes, size: v } })} />
          <Slider label="Spacing" value={f.eyes.spacing} onChange={(v) => set({ eyes: { ...f.eyes, spacing: v } })} />
          <h4 className="pt-1 text-[11px] font-black tracking-widest text-slate-500">EYE COLOR</h4>
          <Swatches colors={EYE_COLORS} value={f.eyes.color} onChange={(color) => set({ eyes: { ...f.eyes, color } })} />
          <h4 className="pt-1 text-[11px] font-black tracking-widest text-slate-500">BROWS</h4>
          <Slider label="Thickness" value={f.brows.thickness} onChange={(v) => set({ brows: { ...f.brows, thickness: v } })} />
          <Slider label="Angle" value={f.brows.angle} onChange={(v) => set({ brows: { ...f.brows, angle: v } })} />
        </div>
      );

    case 'mouth_nose':
      return (
        <div className="space-y-2">
          <h4 className="text-[11px] font-black tracking-widest text-slate-500">NOSE</h4>
          <Slider label="Width" value={f.nose.width} onChange={(v) => set({ nose: { ...f.nose, width: v } })} />
          <Slider label="Length" value={f.nose.length} onChange={(v) => set({ nose: { ...f.nose, length: v } })} />
          <Slider label="Bridge" value={f.nose.bridge} onChange={(v) => set({ nose: { ...f.nose, bridge: v } })} />
          <h4 className="pt-1 text-[11px] font-black tracking-widest text-slate-500">MOUTH</h4>
          <Slider label="Width" value={f.mouth.width} onChange={(v) => set({ mouth: { ...f.mouth, width: v } })} />
          <Slider label="Lip fullness" value={f.mouth.lipFullness} onChange={(v) => set({ mouth: { ...f.mouth, lipFullness: v } })} />
          <Slider label="Resting expression" value={f.mouth.smileRest} onChange={(v) => set({ mouth: { ...f.mouth, smileRest: v } })} />
        </div>
      );
  }
}
