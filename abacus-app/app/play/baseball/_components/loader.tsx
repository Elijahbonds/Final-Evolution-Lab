'use client';

import dynamicImport from 'next/dynamic';
import { Loader2 } from 'lucide-react';
import { GameShell } from '@/components/games/game-shell';

const BaseballGame = dynamicImport(() => import('@/components/games/baseball-game'), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] items-center justify-center">
      <Loader2 className="h-8 w-8 animate-spin text-[#00E5FF]" />
    </div>
  ),
});

export function BaseballLoader() {
  return <GameShell mode="baseball" title="HOME RUN DERBY" venue="Catalina Ballpark" Game={BaseballGame} />;
}
