'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { signOut } from 'next-auth/react';
import { Coins, LogOut, Zap } from 'lucide-react';

interface HeaderData {
  prq: number;
  gradeLabel: string;
  gradeColor: string;
  credits: number;
}

export function AppHeader() {
  const [data, setData] = useState<HeaderData | null>(null);

  useEffect(() => {
    let live = true;
    fetch('/api/profile')
      .then((r) => (r?.ok ? r.json() : null))
      .then((j) => {
        if (!live || !j?.profile) return;
        setData({
          prq: j?.prq ?? 0,
          gradeLabel: j?.grade?.label ?? 'READY',
          gradeColor: j?.grade?.color ?? '#00FF9D',
          credits: j?.profile?.labCredits ?? 0,
        });
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);

  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-[#050505]/85 backdrop-blur-md">
      <div className="mx-auto flex max-w-[1200px] items-center justify-between px-4 py-3">
        <Link href="/" className="fel-heading text-2xl font-bold text-white">
          <span className="text-[#00E5FF] fel-glow-cyan">FINAL EVOLUTION</span> LAB
        </Link>
        <div className="flex items-center gap-2">
          {data ? (
            <>
              <span
                className="hidden sm:inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1 font-mono text-xs"
                style={{ borderColor: `${data.gradeColor}55`, color: data.gradeColor }}
              >
                <Zap className="h-3.5 w-3.5" />
                PRQ {Math.round(data.prq)} · {data.gradeLabel}
              </span>
              <span className="inline-flex items-center gap-1.5 rounded-md border border-[#FFD700]/40 px-2.5 py-1 font-mono text-xs text-[#FFD700]">
                <Coins className="h-3.5 w-3.5" />
                {data.credits} LC
              </span>
            </>
          ) : (
            <span className="h-6 w-24 animate-pulse rounded bg-white/10" />
          )}
          <button
            onClick={() => signOut({ callbackUrl: '/login' })}
            aria-label="Sign out"
            className="rounded-md border border-white/10 p-1.5 text-white/50 transition-colors hover:border-[#FF3366]/50 hover:text-[#FF3366]"
          >
            <LogOut className="h-4 w-4" />
          </button>
        </div>
      </div>
    </header>
  );
}
