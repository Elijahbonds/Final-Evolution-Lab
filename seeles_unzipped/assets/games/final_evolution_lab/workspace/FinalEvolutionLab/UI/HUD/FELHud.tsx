import React from 'react';
import HUD_ScoreBar from './HUD_ScoreBar';
import HUD_PRQMeter from './HUD_PRQMeter';
import HUD_ShardCounter from './HUD_ShardCounter';
import HUD_MRIMeter from './HUD_MRIMeter';
import HUD_AICoachPrompt from './HUD_AICoachPrompt';
import HUD_ComboFeed from './HUD_ComboFeed';

/**
 * FELHud — Master HUD bundle for Final Evolution AI Coach.
 * Loaded by BPFL_HUDManager via WebBrowserWidget.LoadURL().
 * All 6 sub-components maintain their own WebSocket connections
 * to ws://localhost:8080/ws/hud and reconnect automatically on drop.
 *
 * Message types consumed:
 *   score_update   → HUD_ScoreBar
 *   prq_update     → HUD_PRQMeter
 *   economy_update → HUD_ShardCounter
 *   mri_update     → HUD_MRIMeter
 *   coach_tip      → HUD_AICoachPrompt (auto-dismiss 5s)
 *   game_event     → HUD_ComboFeed (last 5 events)
 */
const FELHud: React.FC = () => (
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
