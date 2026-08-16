export type Throw = 'R' | 'P' | 'S' | null
export type Result = 'WIN' | 'LOSS' | 'SAFE' | null

export interface RoundData {
    id: string
    worldThrow: Throw
    distribution: { R: number; P: number; S: number }
    totalPlayers: number
    playerResult?: Result
    pointsDelta?: number
}

// Wire shape of a round as broadcast by the server ('reveal' / 'init' history)
export interface ServerRound {
    id: string
    worldThrow: Throw
    distribution?: { R: number; P: number; S: number }
    totalPlayers?: number
}

// Per-player round outcome from the 'player-data' history
export interface PersonalRoundResult {
    roundId: string
    playerResult: string
    pointsDelta: number
}

// Mirrors server/src/constants/characters.ts (served via GET /store/catalog)
export interface Character {
    id: string
    name: string
    price: number
    description: string
    lite: { primaryColor: string; accentColor: string }
    full: { src: string; stateMachine: string }
    ultra: {
        idle: string[]
        selection: string[]
        rock: string[]
        paper: string[]
        scissors: string[]
    }
}

// User object returned by the /auth routes
export interface AuthUser {
    id: string
    email: string
    displayName: string
    totalPoints: number
}

export interface LeaderboardEntry {
    _id?: string
    // The player's OWN id, on rows that are not themselves a user (biggestWins rows are
    // PlayerRound documents, so `_id` is the round and `userId` is the player).
    userId?: string
    // What a row is labelled with. There is deliberately no `deviceId` here: it is a bearer
    // credential on the socket transport — `sync-player`/`bank`/`update-progress` all resolve
    // an account from a client-supplied one — and this board used to render its first eight
    // characters as other players' pseudonyms. See server/src/leaderboards.ts.
    displayName?: string
    // Career earnings, and the basis the server sorts the board by. totalPoints is the
    // spendable wallet and goes DOWN on a purchase, so it must not be what a ranked list
    // displays.
    lifetimeBanked?: number
    totalPoints?: number
    pointsDelta?: number
}

export interface ServerStats {
    globalDistribution?: { avgR: number; avgP: number; avgS: number }
    topPoints?: LeaderboardEntry[]
    biggestWins?: LeaderboardEntry[]
}
