'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { motion } from 'framer-motion';
import { Lock, Play, Flame, Sparkles, Coins, Zap } from 'lucide-react';
import { VENUES } from '@/lib/game-data';

interface ProfileData {
  profile: any;
  prq: number;
  grade: { label: string; color: string };
}

export function HubWorld({ userName }: { userName: string }) {
  const [data, setData] = useState<ProfileData | null>(null);

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

  return (
    <main className="mx-auto max-w-[1200px] px-4 py-6">
      {/* Profile card */}
      <motion.section
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        className="fel-panel relative overflow-hidden rounded-xl p-5 sm:p-6"
      >
        <div
          className="pointer-events-none absolute -right-20 -top-20 h-64 w-64 rounded-full blur-[100px]"
          style={{ background: `${grade?.color ?? '#00E5FF'}22` }}
        />
        <div className="relative flex flex-wrap items-center gap-5">
          <div
            className="flex h-16 w-16 items-center justify-center rounded-full border-2 text-2xl font-bold fel-heading"
            style={{ borderColor: grade?.color ?? '#00E5FF', color: grade?.color ?? '#00E5FF', boxShadow: `0 0 24px ${grade?.color ?? '#00E5FF'}44` }}
          >
            {(userName?.[0] ?? 'A').toUpperCase()}
          </div>
          <div className="min-w-[140px]">
            <h2 className="fel-heading text-2xl font-bold text-white">{userName}</h2>
            {data ? (
              <span
                className="fel-heading mt-1 inline-block rounded px-2 py-0.5 text-sm font-bold"
                style={{ background: `${grade?.color}1c`, color: grade?.color, border: `1px solid ${grade?.color}55` }}
              >
                {grade?.label}
              </span>
            ) : (
              <span className="mt-1 inline-block h-5 w-20 animate-pulse rounded bg-white/10" />
            )}
          </div>
          <div className="ml-auto flex items-center gap-6">
            <div className="text-center">
              <div className="font-mono text-[28px] font-bold leading-none" style={{ color: grade?.color ?? '#00E5FF' }}>
                {data ? Math.round(data?.prq ?? 0) : '–'}
              </div>
              <div className="mt-1 text-[11px] uppercase tracking-wider text-white/40">PRQ</div>
            </div>
            <div className="text-center">
              <div className="flex items-center gap-1 font-mono text-[28px] font-bold leading-none text-[#FFD700]">
                <Coins className="h-5 w-5" />
                {p?.labCredits ?? '–'}
              </div>
              <div className="mt-1 text-[11px] uppercase tracking-wider text-white/40">Lab Credits</div>
            </div>
            <div className="hidden text-center sm:block">
              <div className="flex items-center gap-1 font-mono text-[28px] font-bold leading-none text-[#00FF9D]">
                <Sparkles className="h-5 w-5" />
                {p?.xp ?? '–'}
              </div>
              <div className="mt-1 text-[11px] uppercase tracking-wider text-white/40">XP</div>
            </div>
            <div className="hidden text-center sm:block">
              <div className="flex items-center gap-1 font-mono text-[28px] font-bold leading-none text-[#FF3366]">
                <Flame className="h-5 w-5" />
                {p?.streakDays ?? '–'}
              </div>
              <div className="mt-1 text-[11px] uppercase tracking-wider text-white/40">Streak</div>
            </div>
          </div>
        </div>
      </motion.section>

      {/* Venue grid */}
      <div className="mt-8 flex items-center gap-3">
        <Zap className="h-5 w-5 text-[#00E5FF]" />
        <h3 className="fel-heading text-2xl font-bold text-white">VENUES</h3>
        <span className="font-mono text-xs text-white/40">4 LIVE · 9 COMING SOON</span>
      </div>
      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {VENUES.map((venue, i) => {
          const inner = (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.05 * i, duration: 0.4 }}
              whileHover={venue.playable ? { scale: 1.02 } : undefined}
              className={`fel-card group relative overflow-hidden rounded-xl ${venue.playable ? 'cursor-pointer hover:border-[#00E5FF]/50 hover:shadow-[0_0_28px_rgba(0,229,255,0.15)]' : ''} transition-all`}
            >
              <div className="relative aspect-video bg-[#0F0F13]">
                {venue.image ? (
                  <Image
                    src={venue.image}
                    alt={`${venue.name} venue artwork`}
                    fill
                    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
                    className="object-cover opacity-80 transition-transform duration-500 group-hover:scale-105"
                  />
                ) : (
                  <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_40%,rgba(168,85,247,0.35),rgba(5,5,5,0.9))]">
                    <div className="absolute inset-0 opacity-30 [background-image:linear-gradient(rgba(0,229,255,0.25)_1px,transparent_1px),linear-gradient(90deg,rgba(0,229,255,0.25)_1px,transparent_1px)] [background-size:28px_28px]" />
                  </div>
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-[#050505] via-transparent to-transparent" />
                {!venue.playable && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black/60 backdrop-blur-[2px]">
                    <span className="fel-heading flex items-center gap-2 rounded-md border border-white/20 bg-black/60 px-3 py-1.5 text-sm font-bold text-white/70">
                      <Lock className="h-4 w-4" /> COMING SOON
                    </span>
                  </div>
                )}
                {venue.playable && (
                  <span className="absolute right-3 top-3 flex items-center gap-1 rounded bg-black/80 px-2 py-0.5 font-mono text-[10px] font-bold uppercase text-[#00FF9D] ring-1 ring-[#00FF9D]/60">
                    <Play className="h-3 w-3" /> Live
                  </span>
                )}
              </div>
              <div className="p-4">
                <h4 className="fel-heading text-xl font-bold text-white">{venue.name}</h4>
                <p className="mt-1 line-clamp-1 text-xs text-white/45">{(venue.modes ?? []).join(' · ')}</p>
              </div>
            </motion.div>
          );
          return venue.playable && venue.href ? (
            <Link key={venue.key} href={venue.href}>
              {inner}
            </Link>
          ) : (
            <div key={venue.key}>{inner}</div>
          );
        })}
      </div>
    </main>
  );
}
