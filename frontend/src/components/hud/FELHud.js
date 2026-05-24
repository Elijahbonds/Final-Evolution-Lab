import React from 'react';
import HUD_ScoreBar from './HUD_ScoreBar';
import HUD_PRQMeter from './HUD_PRQMeter';
import HUD_ShardCounter from './HUD_ShardCounter';
import HUD_MRIMeter from './HUD_MRIMeter';
import HUD_AICoachPrompt from './HUD_AICoachPrompt';
import HUD_ComboFeed from './HUD_ComboFeed';

const FELHud = () => (
  <>
    <HUD_ScoreBar />
    <HUD_ShardCounter />
    <HUD_PRQMeter />
    <HUD_MRIMeter />
    <HUD_AICoachPrompt />
    <HUD_ComboFeed />
  </>
);

export default FELHud;
