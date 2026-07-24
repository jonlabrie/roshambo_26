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
    deviceId?: string
    totalPoints?: number
    pointsDelta?: number
}

export interface ServerStats {
    globalDistribution?: { avgR: number; avgP: number; avgS: number }
    topPoints?: LeaderboardEntry[]
    biggestWins?: LeaderboardEntry[]
}
