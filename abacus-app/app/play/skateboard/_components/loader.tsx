'use client';

import dynamicImport from 'next/dynamic';
import { Loader2 } from 'lucide-react';
import { GameShell } from '@/components/games/game-shell';
import { is3D } from '@/components/three/flags';

const SkateboardGame2D = dynamicImport(() => import('@/components/games/skateboard-game'), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] items-center justify-center">
      <Loader2 className="h-8 w-8 animate-spin text-[#00E5FF]" />
    </div>
  ),
});

const Skateboard3D = dynamicImport(() => import('@/components/games/skateboard-3d'), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] items-center justify-center">
      <Loader2 className="h-8 w-8 animate-spin text-[#00E5FF]" />
    </div>
  ),
});

export function SkateboardLoader() {
  const Game = is3D('skateboard') ? Skateboard3D : SkateboardGame2D;
  return <GameShell mode="skateboarding" title="SKATE RUN" venue="Venice Skatepark" Game={Game} />;
}
