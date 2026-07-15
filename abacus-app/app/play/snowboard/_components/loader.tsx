'use client';

import dynamicImport from 'next/dynamic';
import { Loader2 } from 'lucide-react';
import { GameShell } from '@/components/games/game-shell';
import { is3D } from '@/components/three/flags';

const SnowboardGame2D = dynamicImport(() => import('@/components/games/snowboard-game'), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] items-center justify-center">
      <Loader2 className="h-8 w-8 animate-spin text-[#00E5FF]" />
    </div>
  ),
});

const Snowboard3D = dynamicImport(() => import('@/components/games/snowboard-3d'), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] items-center justify-center">
      <Loader2 className="h-8 w-8 animate-spin text-[#00E5FF]" />
    </div>
  ),
});

export function SnowboardLoader() {
  const Game = is3D('snowboarding') ? Snowboard3D : SnowboardGame2D;
  return <GameShell mode="snowboarding" title="SLALOM DESCENT" venue="Mountain Slope" Game={Game} />;
}
