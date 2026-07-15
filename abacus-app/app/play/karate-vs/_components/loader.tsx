'use client';

import dynamicImport from 'next/dynamic';
import { Loader2 } from 'lucide-react';
import { GameShell } from '@/components/games/game-shell';
import { is3D } from '@/components/three/flags';

const spinner = () => (
  <div className="flex h-[60vh] items-center justify-center">
    <Loader2 className="h-8 w-8 animate-spin text-[#00E5FF]" />
  </div>
);

const KarateVs2D = dynamicImport(() => import('@/components/games/karate-versus-game'), { ssr: false, loading: spinner });
const KarateVs3D = dynamicImport(() => import('@/components/games/karate-versus-3d'), { ssr: false, loading: spinner });

export function KarateVsLoader() {
  const Game = is3D('karateVersus') ? KarateVs3D : KarateVs2D;
  return <GameShell mode="karateVersus" title="KARATE VS" venue="Shimogamo Dojo" Game={Game} />;
}
