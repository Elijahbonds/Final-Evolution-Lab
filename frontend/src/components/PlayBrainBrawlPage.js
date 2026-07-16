import React from 'react';
import QuizPage from '@/components/QuizPage.js';
import { BRAIN_BRAWL_BANK } from '@/game/data/quizBanks.js';

/** Brain Brawl — training-science speed quiz. Route: /play/brain-brawl */
export default function PlayBrainBrawlPage() {
  return (
    <QuizPage
      title="BRAIN BRAWL"
      subtitle="Training science, under the clock — streaks multiply"
      bank={BRAIN_BRAWL_BANK}
      accent="#a78bfa"
    />
  );
}
