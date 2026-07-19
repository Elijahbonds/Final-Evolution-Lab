// THE CLOSET — live avatar preview + tabs: Skin / Face / Hair / Eyes / Mouth+Nose /
// Fits (wearables) / Card Skins. Every change hits the rig preview immediately;
// SAVE persists via /api/closet/look.
//
// RIG SEAM: extends M17 LoadedRig with setFace(FaceConfig) and
// equip(slot, itemId|null) — see README Integration Point 1.

import { useEffect, useMemo, useState } from 'react';
import type { Scene } from '@babylonjs/core';
import { MiniAvatarPreview, type LoadedRig } from './MiniAvatarPreview';
import { FaceEditor } from './FaceEditor';
import type {
  ClosetResponse, FaceConfig, Wardrobe, WearableItem, WearableSlot,
} from '../shared/closetContracts';

export interface ClosetRig extends LoadedRig {
  setFace(face: FaceConfig): void;
  equip(slot: WearableSlot, itemId: string | null): void;
}

type Tab = 'skin' | 'face' | 'hair' | 'eyes' | 'mouth_nose' | 'fits' | 'cards';
const TABS: { id: Tab; label: string }[] = [
  { id: 'skin', label: 'Skin' }, { id: 'face', label: 'Face' }, { id: 'hair', label: 'Hair' },
  { id: 'eyes', label: 'Eyes' }, { id: 'mouth_nose', label: 'Mouth/Nose' },
  { id: 'fits', label: 'Fits' }, { id: 'cards', label: 'Card Skins' },
];
const SLOT_LABEL: Record<WearableSlot, string> = {
  headwear: 'HEAD', top: 'TOP', bottom: 'BOTTOM', shoes: 'SHOES', accessory: 'EXTRA',
};

export function ClosetScreen(props: {
  loadCanonicalRig: (scene: Scene) => Promise<ClosetRig>;
  onClose: () => void;
}) {
  const [closet, setCloset] = useState<ClosetResponse | null>(null);
  const [face, setFace] = useState<FaceConfig | null>(null);
  const [wardrobe, setWardrobe] = useState<Wardrobe | null>(null);
  const [cardSkin, setCardSkin] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>('skin');
  const [rig, setRig] = useState<ClosetRig | null>(null);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/closet').then((r) => r.json()).then((c: ClosetResponse) => {
      setCloset(c); setFace(c.look.face); setWardrobe(c.look.wardrobe);
      setCardSkin(c.look.equippedCardSkin);
    });
  }, []);

  // Live-apply to the rig on every edit
  useEffect(() => { if (rig && face) rig.setFace(face); }, [rig, face]);
  useEffect(() => {
    if (!rig || !wardrobe || !closet) return;
    const active = cardSkin
      ? closet.cardSkins.find((s) => s.cardId === cardSkin)?.wardrobe ?? wardrobe
      : wardrobe;
    (Object.entries(active) as [WearableSlot, string | null][])
      .forEach(([slot, id]) => rig.equip(slot, id));
  }, [rig, wardrobe, cardSkin, closet]);

  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 2200); };

  const buy = async (item: WearableItem) => {
    const res = await fetch('/api/closet/buy', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ itemId: item.id }),
    });
    if (!res.ok) return flash((await res.json().catch(() => ({})))?.message ?? 'Purchase failed');
    setCloset((c) => c && {
      ...c, ownedWearables: [...c.ownedWearables, item.id],
      coinBalance: c.coinBalance - item.priceCoins,
    });
    flash(`${item.name} unlocked!`);
  };

  const save = async () => {
    if (!face || !wardrobe) return;
    setSaving(true);
    const res = await fetch('/api/closet/look', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ face, wardrobe, equippedCardSkin: cardSkin }),
    });
    setSaving(false);
    flash(res.ok ? 'Look saved — you’ll wear this everywhere.' : 'Save failed');
  };

  const spec = useMemo(() => closet && ({
    // Proportions come from the athlete's scan (M17); Closet only changes identity.
    avatarId: `closet_${closet.look.userId}`,
    proportions: { height: 1, torso: 1, arms: 1, forearms: 1, legs: 1, shins: 1, shoulders: 1, hips: 1 },
    palette: { skin: face?.skinTone ?? '#b98a63', jersey: '#22d3ee', shorts: '#0f172a', shoes: '#f8fafc', accent: '#f59e0b' },
    sourceScanId: '',
  }), [closet, face?.skinTone]);

  if (!closet || !face || !wardrobe || !spec) {
    return <p className="p-6 text-center text-sm text-slate-400">Opening your closet…</p>;
  }

  return (
    <div className="mx-auto flex h-full max-w-md flex-col p-3">
      <header className="mb-2 flex items-center justify-between">
        <h1 className="text-lg font-black tracking-wide">THE CLOSET</h1>
        <div className="flex items-center gap-3">
          <span className="font-mono text-sm text-amber-300">{closet.coinBalance} ¢</span>
          <button onClick={props.onClose} className="text-slate-500">✕</button>
        </div>
      </header>

      <MiniAvatarPreview
        spec={spec} clip="idle" loop spin
        loadCanonicalRig={props.loadCanonicalRig as any}
        onRig={(r) => setRig(r as ClosetRig)}
        className="h-64 w-full"
      />

      <div className="my-2 flex gap-1 overflow-x-auto">
        {TABS.map((t) => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`shrink-0 rounded-full px-3 py-1.5 text-[11px] font-black ${
              tab === t.id ? 'bg-cyan-400 text-black' : 'bg-slate-800 text-slate-300'}`}>
            {t.label}
          </button>
        ))}
      </div>

      <div className="flex-1 overflow-y-auto pb-20">
        {['skin', 'face', 'hair', 'eyes', 'mouth_nose'].includes(tab) && (
          <FaceEditor face={face} section={tab as any} onChange={setFace} />
        )}

        {tab === 'fits' && (
          <div className="space-y-4">
            {cardSkin && (
              <p className="rounded-lg bg-amber-500/10 p-2 text-[11px] text-amber-300">
                A Card Skin is equipped — unequip it in Card Skins to edit fits directly.
              </p>
            )}
            {(['headwear', 'top', 'bottom', 'shoes', 'accessory'] as WearableSlot[]).map((slot) => (
              <section key={slot}>
                <h4 className="mb-1 text-[11px] font-black tracking-widest text-slate-500">{SLOT_LABEL[slot]}</h4>
                <div className="grid grid-cols-2 gap-2">
                  {closet.catalog.filter((i) => i.slot === slot && !i.cardSkinOnly).map((item) => {
                    const owned = closet.ownedWearables.includes(item.id);
                    const equipped = wardrobe[slot] === item.id;
                    return (
                      <button key={item.id} disabled={!!cardSkin}
                        onClick={() => owned
                          ? setWardrobe({ ...wardrobe, [slot]: equipped && (slot === 'headwear' || slot === 'accessory') ? null : item.id })
                          : buy(item)}
                        className={`rounded-xl border p-2 text-left text-sm disabled:opacity-40 ${
                          equipped ? 'border-cyan-400 bg-cyan-950' : 'border-slate-700 bg-slate-900'}`}>
                        <p className="font-semibold leading-tight">{item.name}</p>
                        <p className="text-[10px] uppercase text-slate-500">{item.rarity}</p>
                        {!owned && <p className="text-[11px] font-black text-amber-300">{item.priceCoins} ¢</p>}
                        {equipped && <p className="text-[10px] font-black text-cyan-300">EQUIPPED</p>}
                      </button>
                    );
                  })}
                </div>
              </section>
            ))}
          </div>
        )}

        {tab === 'cards' && (
          <div className="space-y-2">
            {closet.cardSkins.length === 0 && (
              <p className="pt-4 text-center text-sm text-slate-500">
                Card skins come with Creator Cards you own. Create or collect cards to unlock full looks.
              </p>
            )}
            {closet.cardSkins.map((s) => (
              <button key={s.cardId}
                onClick={() => setCardSkin(cardSkin === s.cardId ? null : s.cardId)}
                className={`w-full rounded-xl border p-3 text-left ${
                  cardSkin === s.cardId ? 'border-amber-400 bg-amber-950/40' : 'border-slate-700 bg-slate-900'}`}>
                <p className="font-bold">{s.name}</p>
                <p className="text-[11px] text-slate-400">
                  {cardSkin === s.cardId ? 'EQUIPPED — tap to remove' : 'Tap to equip full look'}
                  {s.signatureItemId && ' · includes signature item'}
                </p>
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="fixed inset-x-0 bottom-0 mx-auto max-w-md bg-gradient-to-t from-slate-950 p-3">
        <button onClick={save} disabled={saving}
          className="w-full rounded-xl bg-cyan-400 py-3 font-black text-black disabled:opacity-50">
          {saving ? 'SAVING…' : 'SAVE LOOK'}
        </button>
      </div>

      {toast && (
        <p className="fixed bottom-20 left-1/2 -translate-x-1/2 rounded-full bg-slate-800 px-4 py-2 text-xs font-bold">
          {toast}
        </p>
      )}
    </div>
  );
}
