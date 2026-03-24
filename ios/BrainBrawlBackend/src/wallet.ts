import { PlayerId } from "./types";

interface Hold {
  id: string;
  playerId: PlayerId;
  amount: number;
}

export class InMemoryShardWallet {
  private balances = new Map<PlayerId, number>();
  private holds = new Map<string, Hold>();
  private holdCounter = 1;

  setBalance(playerId: PlayerId, amount: number): void {
    this.balances.set(playerId, Math.max(0, Math.floor(amount)));
  }

  getBalance(playerId: PlayerId): number {
    return this.balances.get(playerId) ?? 0;
  }

  reserve(playerId: PlayerId, amount: number): string {
    const normalized = Math.floor(amount);
    if (normalized <= 0) {
      throw new Error("Reserve amount must be greater than zero.");
    }
    if (this.getAvailableBalance(playerId) < normalized) {
      throw new Error("Insufficient shards to reserve.");
    }

    const holdId = `hold_${this.holdCounter++}`;
    this.holds.set(holdId, { id: holdId, playerId, amount: normalized });
    return holdId;
  }

  release(holdId: string): void {
    this.holds.delete(holdId);
  }

  capture(holdId: string): number {
    const hold = this.holds.get(holdId);
    if (!hold) {
      throw new Error("Hold not found.");
    }

    this.debit(hold.playerId, hold.amount);
    this.holds.delete(holdId);
    return hold.amount;
  }

  debit(playerId: PlayerId, amount: number): void {
    const normalized = Math.floor(amount);
    if (normalized <= 0) {
      throw new Error("Debit amount must be greater than zero.");
    }

    const current = this.getBalance(playerId);
    if (current < normalized) {
      throw new Error("Insufficient shard balance.");
    }

    this.balances.set(playerId, current - normalized);
  }

  credit(playerId: PlayerId, amount: number): void {
    const normalized = Math.floor(amount);
    if (normalized <= 0) {
      return;
    }
    this.balances.set(playerId, this.getBalance(playerId) + normalized);
  }

  private getReservedTotal(playerId: PlayerId): number {
    let total = 0;
    for (const hold of this.holds.values()) {
      if (hold.playerId === playerId) {
        total += hold.amount;
      }
    }
    return total;
  }

  private getAvailableBalance(playerId: PlayerId): number {
    return this.getBalance(playerId) - this.getReservedTotal(playerId);
  }
}
