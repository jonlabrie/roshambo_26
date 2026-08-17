import { GlobalResult, SettledPlayer } from './Settlement';

// In-memory recent-round results. Global results are also persisted (Round
// collection); this store exists so /api/v1 reads never hit the DB. Eviction
// keeps the newest `keep` rounds. Single-process by design (see spec §10).
// HOW MANY ROUNDS THE TAPE ADVERTISES, and therefore the floor on what the store must retain.
// These were independent numbers and disagreed: the store kept 5 while /api/v1/state asked it
// for 10, so the Stats room's ten-cell tape could only ever fill five of them however many
// cells it had (found 2026-08-17). Anything that serves a tape reads this.
export const TAPE_LENGTH = 10;

export class ResultsStore {
    private global = new Map<string, GlobalResult>();
    private byInstance = new Map<string, Map<string, SettledPlayer[]>>();
    private order: string[] = []; // oldest first

    // Defaults comfortably above TAPE_LENGTH: a store that keeps exactly the tape's length has
    // no room for the round currently settling, so the newest entry would evict the oldest one
    // the tape still wants to show.
    constructor(private keep = TAPE_LENGTH + 2) {}

    seed(roundsNewestFirst: GlobalResult[]): void {
        for (const r of [...roundsNewestFirst].reverse()) this.storeRound(r, []);
    }

    storeRound(round: GlobalResult, players: SettledPlayer[]): void {
        this.global.set(round.id, round);
        const instances = new Map<string, SettledPlayer[]>();
        for (const p of players) {
            if (!p.instanceId) continue;
            const list = instances.get(p.instanceId) ?? [];
            list.push(p);
            instances.set(p.instanceId, list);
        }
        this.byInstance.set(round.id, instances);
        this.order.push(round.id);
        while (this.order.length > this.keep) {
            const evicted = this.order.shift()!;
            this.global.delete(evicted);
            this.byInstance.delete(evicted);
        }
    }

    getGlobal(roundId: string): GlobalResult | undefined {
        return this.global.get(roundId);
    }

    getInstance(roundId: string, instanceId: string): SettledPlayer[] | undefined {
        return this.byInstance.get(roundId)?.get(instanceId);
    }

    tape(n = 10): GlobalResult[] {
        return this.order.slice(-n).reverse().map(id => this.global.get(id)!);
    }
}
