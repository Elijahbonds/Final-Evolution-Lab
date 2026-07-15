'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { PRQ_ATTRS } from '@/lib/prq';
import { ROSTER } from '@/lib/game-data';
import { AvatarFigure } from '@/components/avatar-figure';
import { Flame, Sparkles, Coins, Gem, Check } from 'lucide-react';

const ATTR_LABELS: Record<string, string> = {
  strength: 'Strength',
  speed: 'Speed',
  endurance: 'Endurance',
  agility: 'Agility',
  power: 'Power',
  flexibility: 'Flexibility',
  recovery: 'Recovery',
  mental: 'Mental',
};

export function ProfileView({ userName, email }: { userName: string; email: string }) {
  const [data, setData] = useState<any>(null);
  const [saving, setSaving] = useState<string | null>(null);

  const selectAvatar = async (key: string) => {
    if (saving) return;
    setSaving(key);
    try {
      const r = await fetch('/api/profile', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ avatarKey: key }),
      });
      const j = r?.ok ? await r.json() : null;
      if (j?.profile) setData(j);
    } catch {}
    setSaving(null);
  };

  useEffect(() => {
    let live = true;
    fetch('/api/profile')
      .then((r) => (r?.ok ? r.json() : null))
      .then((j) => {
        if (live && j?.profile) setData(j);
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);

  const grade = data?.grade;
  const p = data?.profile;
  const currentAvatar = ROSTER.find((r) => r.key === p?.avatarKey) ?? null;

  return (
    <main className="mx-auto max-w-[900px] px-4 py-6">
      <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="fel-panel rounded-xl p-6">
        <div className="flex flex-wrap items-center gap-5">
          <div
            className="flex h-20 w-20 items-center justify-center rounded-full border-2 text-3xl font-bold fel-heading"
            style={{ borderColor: grade?.color ?? '#00E5FF', color: grade?.color ?? '#00E5FF', boxShadow: `0 0 28px ${grade?.color ?? '#00E5FF'}44` }}
          >
            {currentAvatar ? <AvatarFigure avatar={currentAvatar} size={54} /> : (userName?.[0] ?? 'A').toUpperCase()}
          </div>
          <div>
            <h1 className="fel-heading text-3xl font-bold text-white">{userName}</h1>
            <p className="font-mono text-xs text-white/40">{email}</p>
            {currentAvatar && (
              <p className="fel-heading text-sm font-bold" style={{ color: currentAvatar.accent }}>{currentAvatar.name.toUpperCase()}</p>
            )}
            {grade && (
              <span
                className="fel-heading mt-2 inline-block rounded px-2.5 py-0.5 text-sm font-bold"
                style={{ background: `${grade?.color}1c`, color: grade?.color, border: `1px solid ${grade?.color}55` }}
              >
                {grade?.label} · PRQ {Math.round(data?.prq ?? 0)}
              </span>
            )}
          </div>
          <div className="ml-auto grid grid-cols-2 gap-x-6 gap-y-2 sm:grid-cols-4">
            {[
              { icon: Coins, label: 'Credits', value: p?.labCredits, color: '#FFD700' },
              { icon: Sparkles, label: 'XP', value: p?.xp, color: '#00FF9D' },
              { icon: Gem, label: 'Shards', value: p?.shards, color: '#A855F7' },
              { icon: Flame, label: 'Streak', value: p?.streakDays, color: '#FF3366' },
            ].map((s) => {
              const Icon = s.icon;
              return (
                <div key={s.label} className="text-center">
                  <div className="flex items-center justify-center gap-1 font-mono text-xl font-bold" style={{ color: s.color }}>
                    <Icon className="h-4 w-4" />
                    {s.value ?? '–'}
                  </div>
                  <div className="text-[10px] uppercase tracking-wider text-white/40">{s.label}</div>
                </div>
              );
            })}
          </div>
        </div>
      </motion.div>

      <h2 className="fel-heading mt-8 text-2xl font-bold text-white">SELECT YOUR ATHLETE</h2>
      <p className="text-xs text-white/45">Pick the body type you're building toward. Your athlete shows up across the Lab.</p>
      <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        {ROSTER.map((r, i) => {
          const selected = p?.avatarKey === r.key;
          return (
            <motion.button
              key={r.key}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.03 * i }}
              onClick={() => selectAvatar(r.key)}
              disabled={!!saving}
              className={`fel-card relative rounded-lg p-3 text-left transition-all ${selected ? '' : 'opacity-80 hover:opacity-100'}`}
              style={selected ? { borderColor: `${r.accent}88`, boxShadow: `0 0 20px ${r.accent}33` } : undefined}
            >
              {selected && (
                <span className="absolute right-2 top-2 flex h-5 w-5 items-center justify-center rounded-full" style={{ background: r.accent }}>
                  <Check className="h-3.5 w-3.5 text-black" />
                </span>
              )}
              <AvatarFigure avatar={r} size={72} />
              <div className="fel-heading mt-1 text-center text-sm font-bold" style={{ color: r.accent }}>
                {saving === r.key ? 'SAVING…' : r.name.toUpperCase()}
              </div>
              <div className="text-center text-[10px] uppercase tracking-wider text-white/40">
                {r.sex} · {r.build} · {r.bias.join(' / ')}
              </div>
              <p className="mt-1 hidden text-center text-[11px] leading-snug text-white/50 sm:block">{r.tagline}</p>
            </motion.button>
          );
        })}
      </div>

      <h2 className="fel-heading mt-8 text-2xl font-bold text-white">PRQ ATTRIBUTES</h2>
      <p className="text-xs text-white/45">Performance Readiness Quotient — decays 0.5/day of inactivity. Train to grow.</p>
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        {PRQ_ATTRS.map((attr, i) => {
          const val = Number(p?.[attr] ?? 0);
          const color = val >= 80 ? '#A855F7' : val >= 60 ? '#00E5FF' : val >= 40 ? '#00FF9D' : '#FFD700';
          return (
            <motion.div
              key={attr}
              initial={{ opacity: 0, x: -12 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.04 * i }}
              className="fel-card rounded-lg p-4"
            >
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-white/80">{ATTR_LABELS?.[attr]}</span>
                <span className="font-mono text-sm font-bold" style={{ color }}>
                  {p ? val.toFixed(1) : '–'}
                </span>
              </div>
              <div className="mt-2 h-2 overflow-hidden rounded-full bg-white/10">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${Math.min(val, 100)}%` }}
                  transition={{ duration: 0.8, delay: 0.1 + 0.04 * i }}
                  className="h-full rounded-full"
                  style={{ background: `linear-gradient(90deg, ${color}88, ${color})`, boxShadow: `0 0 10px ${color}66` }}
                />
              </div>
            </motion.div>
          );
        })}
      </div>
    </main>
  );
}
