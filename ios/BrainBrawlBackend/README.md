# Brain Brawl Backend (TypeScript Scaffold)

This folder contains a backend-oriented TypeScript scaffold for the **Brain Brawl** system:

- Shard wagers with escrow
- Tutor sponsorship perks (Magnus, Elara, Jax)
- Sabotage purchases/effects
- Anti-cheat checks
- Dynamic remediation hooks

## Scope

This is intentionally framework-agnostic (no Express/Nest dependency).  
You can wire it into any API layer.

## Files

- `src/types.ts` - domain types, enums, and constants
- `src/wallet.ts` - in-memory shard wallet + hold/capture escrow primitives
- `src/antiCheat.ts` - answer/task integrity checks
- `src/remediation.ts` - difficulty adjustment logic
- `src/brainBrawlService.ts` - match lifecycle and core game logic
- `src/index.ts` - module exports
- `src/example.ts` - simple end-to-end flow sample

## Suggested integration

1. Instantiate `BrainBrawlService` at app startup.
2. Replace `InMemoryShardWallet` with your persistent wallet/ledger implementation.
3. Expose methods as API endpoints:
   - `createMatch`, `acceptMatch`, `purchaseSabotage`, `recordAnswer`, `finalizeByScore`.
4. Persist `BrainBrawlMatch` records in your DB.
5. Emit match events to clients using WebSocket/Realtime channel.

## Notes

- The logic enforces **local score outcome first, then payout settlement** at finalize time.
- Sabotage effects are deterministic and server-side to reduce client tampering.
- Anti-cheat flags are tracked per participant and can auto-forfeit abusive sessions.
