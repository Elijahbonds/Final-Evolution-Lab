import React from 'react';
import QuizPage from '@/components/QuizPage.js';
import { WHO_SCENE_IT_BANK } from '@/game/data/quizBanks.js';

/** Who-Scene-It — name the FEL scene from the clue. Route: /play/who-scene-it */
export default function PlayWhoSceneItPage() {
  return (
    <QuizPage
      title="WHO-SCENE-IT"
      subtitle="Name the FEL scene from the clue — original content only"
      bank={WHO_SCENE_IT_BANK}
      accent="#f472b6"
    />
  );
}
