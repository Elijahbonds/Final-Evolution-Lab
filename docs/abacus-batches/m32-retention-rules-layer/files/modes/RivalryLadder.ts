// Rivalry Ladder — the 1v1 campaign. Five named rivals; beating one unlocks
// the next AND their signature move for the player's kit. Data + hooks only —
// reuses the existing 1v1 AI and moveset systems.

import { RIVALS, type Rival } from '../shared/progressionContracts';

export interface LadderState {
  defeated: string[];            // rival ids
  unlockedMoves: string[];       // signature move ids now in the player's kit
}

export interface OneVOneHooks {
  applyRivalProfile(r: Rival): void;          // maps onto existing AI params
  grantPlayerMove(moveId: string): void;      // adds to the player's kit
  showRivalIntro(r: Rival): Promise<void>;    // name card + tagline before tip-off
  showRivalLine(line: string): void;          // post-game line (their voice)
  setHud(update: Record<string, string | number>): void;
}

// ── server endpoints (thin) ─────────────────────────────────────────────────
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
}
const C = { ladder: 'rivalry_ladder' };

export async function getLadder(db: Db, userId: string): Promise<LadderState> {
  return (await db.get<LadderState>(C.ladder, userId)) ?? { defeated: [], unlockedMoves: [] };
}

export async function recordRivalDefeat(
  db: Db, userId: string, rivalId: string,
): Promise<LadderState> {
  const state = await getLadder(db, userId);
  const rival = RIVALS.find((r) => r.id === rivalId);
  if (!rival) throw Object.assign(new Error('unknown rival'), { status: 404 });
  // Sequence enforcement: can only defeat the current next rival
  const next = nextRival(state);
  if (!next || next.id !== rivalId) {
    throw Object.assign(new Error('rival not yet unlocked'), { status: 409 });
  }
  state.defeated.push(rivalId);
  if (!state.unlockedMoves.includes(rival.signatureMoveId)) {
    state.unlockedMoves.push(rival.signatureMoveId);
  }
  await db.put(C.ladder, userId, { userId, ...state });
  return state;
}

export function nextRival(state: LadderState): Rival | null {
  return RIVALS.find((r) => !state.defeated.includes(r.id)) ?? null;
}

// ── client-side match flow ──────────────────────────────────────────────────
export async function playRivalMatch(
  hooks: OneVOneHooks,
  state: LadderState,
  playGame: () => Promise<{ playerWon: boolean }>,
): Promise<{ rivalId: string; playerWon: boolean; moveUnlocked: string | null }> {
  const rival = nextRival(state);
  if (!rival) throw new Error('ladder complete');

  hooks.applyRivalProfile(rival);
  hooks.setHud({
    ladder: `RIVAL ${RIVALS.indexOf(rival) + 1}/${RIVALS.length}`,
    rival: rival.name,
  });
  await hooks.showRivalIntro(rival);

  const { playerWon } = await playGame();

  if (playerWon) {
    hooks.showRivalLine(rival.lossLine);
    hooks.grantPlayerMove(rival.signatureMoveId);      // server confirms via recordRivalDefeat
    return { rivalId: rival.id, playerWon, moveUnlocked: rival.signatureMoveId };
  }
  hooks.showRivalLine(rival.winLine);
  return { rivalId: rival.id, playerWon, moveUnlocked: null };
}

// SIGNATURE MOVE EFFECTS (map onto existing systems; tuned, no new anims req.):
//   move_hesi_burst   — pro-stick hesi gains a short burst window (speed 1.15 for 0.5s)
//   move_chase_block  — block attempts within 1.5m of the rim get +0.2 success
//   move_deep_range   — green window beyond the arc widens by 20%
//   move_strip_steal  — steal attempts during opponent crossovers +0.15
//   move_clutch_gene  — at 18+ points, your shot meter slows 15% (easier greens)
// Ladder UI: rival cards on the 1v1 mode screen — defeated = full color +
// "MOVE EARNED"; current = highlighted; locked = silhouette.
