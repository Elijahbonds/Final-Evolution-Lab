export interface AntiCheatAnswerInput {
  responseMs: number;
  hasInteractionProof?: boolean;
}

export interface AntiCheatResult {
  flags: string[];
  autoForfeit: boolean;
}

export class AntiCheatEngine {
  private static readonly TOO_FAST_MS = 350;
  private static readonly TOO_SLOW_MS = 45_000;
  private static readonly MAX_FLAGS_BEFORE_FORFEIT = 4;

  inspectAnswer(input: AntiCheatAnswerInput, priorFlags: string[]): AntiCheatResult {
    const flags: string[] = [];

    if (input.responseMs < AntiCheatEngine.TOO_FAST_MS) {
      flags.push("response_too_fast");
    }

    if (input.responseMs > AntiCheatEngine.TOO_SLOW_MS) {
      flags.push("response_too_slow");
    }

    if (!input.hasInteractionProof) {
      flags.push("missing_interaction_proof");
    }

    const totalFlags = priorFlags.length + flags.length;
    return {
      flags,
      autoForfeit: totalFlags >= AntiCheatEngine.MAX_FLAGS_BEFORE_FORFEIT,
    };
  }
}
