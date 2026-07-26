// BrainBrawlMode — rapid-fire movement-IQ duel. 10 questions, 10s each.
import { createQuizMode } from './QuizMode';
import { BRAIN_BRAWL } from '../core/QuizCore';
import { BRAIN_BRAWL_PACK } from '../content/quizPacks';

export const BrainBrawlMode = createQuizMode({
  modeId: 'brain_brawl',
  defaultVenueId: 'brain_brawl',
  pack: BRAIN_BRAWL_PACK,
  cfg: BRAIN_BRAWL,
  renderQuestionScene: false,
  foeSkill: 0.65,
  foeSpeed: 0.5,
});
