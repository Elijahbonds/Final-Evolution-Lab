# Brain Brawl Backend (Python Scaffold)

Python equivalent of the TypeScript Brain Brawl backend module.

## Included features

- Shard wager escrow
- Tutor sponsorship perks (Magnus, Elara, Jax)
- Sabotage purchases/effects
- Anti-cheat checks (speed + interaction proof)
- Dynamic remediation hook

## Layout

- `brain_brawl/types.py` - domain enums, dataclasses, constants
- `brain_brawl/wallet.py` - in-memory shard ledger + hold/capture escrow
- `brain_brawl/anti_cheat.py` - anti-cheat engine
- `brain_brawl/remediation.py` - adaptive difficulty helper
- `brain_brawl/service.py` - Brain Brawl lifecycle and game rules
- `brain_brawl/__init__.py` - package exports
- `example.py` - runnable flow demo

## Quick run

```bash
python example.py
```

## Integration notes

1. Replace `InMemoryShardWallet` with your persistent wallet/ledger.
2. Expose `BrainBrawlService` methods via FastAPI, Flask, or your existing backend framework.
3. Persist `BrainBrawlMatch` rows/documents in your DB.
4. Emit match updates to clients via WebSocket/realtime channels.

This scaffold is intentionally framework-agnostic so you can embed it into your current stack.
