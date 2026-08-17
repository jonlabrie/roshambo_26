import { useState, useEffect, useCallback, useRef } from 'react'
import { io, Socket } from 'socket.io-client'
import type { Throw, Result, RoundData, ServerRound, PersonalRoundResult, Character, AuthUser, ServerStats } from '../types'
import { calculateResult as rulesCalculateResult, potDelta } from '../lib/gameRules'

export type { Throw, Result, RoundData } from '../types'
export type GameState = 'ACTIVE' | 'REVEAL'

// Use your local IP for mobile access on the same network
import { blendOffset, secondsLeftAt } from '../lib/roundClock'

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || ''

// The clock fields the server puts on `init`, `sync` and `active`. All optional: a server
// older than 2026-08-17 sends only `timeLeft`, and the deployed PWA and the deployed server
// do not ship together.
interface ClockPayload {
    phase?: string
    serverTimeMs?: number
    phaseEndsAtMs?: number
    timeLeft?: number
}

export function useGameLoop() {
    const [timeLeft, setTimeLeft] = useState(0)
    // THE CLOCK THE ROBLOX CLIENT HAS ALWAYS HAD. `sync` now carries an absolute phase
    // deadline and the server's idea of now; these hold the derived offset and deadline so a
    // local ticker can count down smoothly instead of stepping once per server tick. See
    // ../lib/roundClock.ts for why the pair is needed rather than the deadline alone.
    const serverOffsetRef = useRef<number | null>(null)
    const phaseEndsAtRef = useRef<number | null>(null)
    const phaseRef = useRef<string>('OPEN')
    const [gameState, setGameState] = useState<GameState>('ACTIVE')
    const [playerThrow, setPlayerThrow] = useState<Throw>(null)
    const [isLocked, setIsLocked] = useState(false)
    const [showDecision, setShowDecision] = useState(false)
    const [roundCount, setRoundCount] = useState(0)
    const [roundResult, setRoundResult] = useState<Result>(null)
    const [currentStreak, setCurrentStreak] = useState(0)
    const [bestStreak, setBestStreak] = useState(0)
    const [stakingStreak, setStakingStreak] = useState(0)
    const [pointsAtStake, setPointsAtStake] = useState(0)
    const [totalPoints, setTotalPoints] = useState(0)
    const [lastRound, setLastRound] = useState<RoundData | null>(null)
    const [history, setHistory] = useState<RoundData[]>([])
    const [showResult, setShowResult] = useState(false)
    // Server-reported OPEN length, arriving on `init`. Unlike revealMs (read only
    // inside a socket-handler closure via a ref) this is rendered directly as
    // PieTimer's `totalTime` prop, so it must be state — a ref mutation wouldn't
    // trigger the re-render the countdown ring needs. The fallback matches the
    // server's default (51s) but should never be the number in use.
    const [openMs, setOpenMs] = useState(51000)
    const [stats, setStats] = useState<ServerStats | null>(null)
    const [user, setUser] = useState<AuthUser | null>(null)
    const [token, setToken] = useState<string | null>(localStorage.getItem('roshambo_auth_token'))
    const [inventory, setInventory] = useState<string[]>(['default'])
    const [equippedId, setEquippedId] = useState<string>('default')
    const [catalog, setCatalog] = useState<Character[]>([])
    const [actionMessage, setActionMessage] = useState<string | null>(null)

    // Audio Settings
    const [audioEnabled, setAudioEnabled] = useState<boolean>(() => {
        const saved = localStorage.getItem('roshambo_audio_enabled')
        return saved === null ? true : saved === 'true'
    })
    const [audioVolume, setAudioVolume] = useState<number>(() => {
        const saved = localStorage.getItem('roshambo_audio_volume')
        return saved === null ? 0.5 : parseFloat(saved)
    })

    // Identity / Persistence
    const deviceIdRef = useRef<string | null>(localStorage.getItem('roshambo_device_id'))
    const isSyncedRef = useRef(false)
    const socketRef = useRef<Socket | null>(null)
    const playerThrowRef = useRef<Throw>(null)
    const isLockedRef = useRef(false)
    const stakingStreakRef = useRef(0)
    const pointsAtStakeRef = useRef(0)
    const lastRoundRef = useRef<RoundData | null>(null)
    const serverResultRef = useRef<{ result: Result; delta: number } | null>(null)
    const audioCtxRef = useRef<AudioContext | null>(null)
    const audioEnabledRef = useRef(audioEnabled)
    const audioVolumeRef = useRef(audioVolume)
    // Server-reported REVEAL length, arriving on `init`. The fallback matches the
    // server's default (7s) but should never be the number in use.
    const revealMsRef = useRef(7000)

    // Initialize Device ID if missing
    useEffect(() => {
        if (!deviceIdRef.current) {
            const id = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)
            localStorage.setItem('roshambo_device_id', id)
            deviceIdRef.current = id
        }
    }, [])

    // Fetch Catalog
    useEffect(() => {
        fetch(`${SOCKET_URL}/store/catalog`)
            .then(res => res.json())
            .then(data => setCatalog(data))
            .catch(err => console.error('Error fetching store catalog:', err))
    }, [])

    const buyCharacter = async (characterId: string) => {
        if (!token) return { success: false, message: 'Auth required' }
        try {
            const res = await fetch(`${SOCKET_URL}/store/purchase`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ characterId })
            })
            const data = await res.json()
            if (!res.ok) throw new Error(data.message)

            setInventory(data.inventory)
            setTotalPoints(data.totalPoints)
            return { success: true }
        } catch (err) {
            return { success: false, message: (err as Error).message }
        }
    }

    const equipCharacter = async (characterId: string) => {
        if (!token) return { success: false, message: 'Auth required' }
        try {
            const res = await fetch(`${SOCKET_URL}/store/equip`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ characterId })
            })
            const data = await res.json()
            if (!res.ok) throw new Error(data.message)

            setEquippedId(data.equippedCharacterId)
            return { success: true }
        } catch (err) {
            return { success: false, message: (err as Error).message }
        }
    }

    const login = (newToken: string, newUser: AuthUser) => {
        localStorage.setItem('roshambo_auth_token', newToken)
        setToken(newToken)
        setUser(newUser)
        // Socket will reconnect via useEffect
    }

    const logout = () => {
        localStorage.removeItem('roshambo_auth_token')
        setToken(null)
        setUser(null)
    }

    // Keep refs in sync with state for socket closure access
    useEffect(() => { playerThrowRef.current = playerThrow }, [playerThrow])
    useEffect(() => { isLockedRef.current = isLocked }, [isLocked])
    useEffect(() => { stakingStreakRef.current = stakingStreak }, [stakingStreak])
    useEffect(() => { pointsAtStakeRef.current = pointsAtStake }, [pointsAtStake])
    useEffect(() => { lastRoundRef.current = lastRound }, [lastRound])

    // Persistence and Ref Sync for Audio Settings
    useEffect(() => {
        localStorage.setItem('roshambo_audio_enabled', audioEnabled.toString())
        audioEnabledRef.current = audioEnabled
    }, [audioEnabled])

    useEffect(() => {
        localStorage.setItem('roshambo_audio_volume', audioVolume.toString())
        audioVolumeRef.current = audioVolume
    }, [audioVolume])

    // Removal of client-side progress pushing. Server is now the source of truth for scores.
    useEffect(() => {
        // No longer pushing progress from client to server.
    }, [token])

    // Emit throw when locked
    useEffect(() => {
        if (isLocked && playerThrow && socketRef.current && deviceIdRef.current) {
            const payload: { deviceId: string; throw: Throw; token?: string } = {
                deviceId: deviceIdRef.current,
                throw: playerThrow
            }
            if (token) {
                payload.token = token
            }
            socketRef.current.emit('submit-throw', payload)
        }
    }, [isLocked, playerThrow, token])

    // The rules themselves live in `src/lib/gameRules.ts`, held to the same
    // `shared-fixtures/game-rules.json` the server and the Roblox client run — this wrapper only
    // adds the nil-guard the UI needs. Inlining the matchup table here again is how the third copy
    // of the rules came to have no test at all.
    const calculateResult = useCallback((player: Throw, world: Throw): Result => {
        if (!player || !world) return null
        return rulesCalculateResult(player, world)
    }, [])

    const ensureAudioContext = useCallback((): AudioContext | null => {
        if (!audioCtxRef.current) {
            const AudioContextClass = window.AudioContext
                || (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
            if (!AudioContextClass) return null
            audioCtxRef.current = new AudioContextClass()
        }
        const ctx = audioCtxRef.current
        if (ctx.state === 'suspended') void ctx.resume()
        return ctx
    }, [])

    // THE BELL IS THE OWNER'S OWN BYODO-IN RECORDING, and it is the SAME FILE Roblox plays
    // (`rbxassetid://108417212310624`, BellSoundController). Source master:
    // `byodo_bell_strike.wav` -- 20s mono 48k, cut in the 65ms squeak-to-impact gap and
    // filtered HP80 + LP600 -- encoded here to AAC for the web.
    //
    // This REPLACES the FM+noise gong synthesis that shipped with the reveal. That synth was a
    // "modern gong" at 200Hz with a 6s decay and sounded nothing like the bell the arena rings;
    // now that both platforms run one backend and players move between them, two different
    // instruments for the same beat is a seam, not a variation. It is in git history at 3c04337
    // if it is ever wanted back.
    //
    // NO SYNTHESISED FALLBACK on purpose: if the asset fails to load, the right outcome is
    // silence and a warning, not a different instrument quietly taking its place.
    const BELL_URL = '/audio/bonsho-strike.m4a'
    const bellBufferRef = useRef<AudioBuffer | null>(null)
    const bellLoadingRef = useRef(false)

    const loadBell = useCallback(async (ctx: AudioContext) => {
        if (bellBufferRef.current || bellLoadingRef.current) return
        bellLoadingRef.current = true
        try {
            const res = await fetch(BELL_URL)
            if (!res.ok) throw new Error(`${res.status} ${res.statusText}`)
            bellBufferRef.current = await ctx.decodeAudioData(await res.arrayBuffer())
        } catch (e) {
            console.warn('[SFX] Could not load the bell:', e)
        } finally {
            bellLoadingRef.current = false
        }
    }, [])

    const playGongSound = useCallback(() => {
        if (!audioEnabledRef.current) return
        const ctx = ensureAudioContext()
        if (!ctx) return
        if (ctx.state !== 'running') {
            console.warn('[SFX] audio context is', ctx.state, '- bell skipped until the page is touched')
            return
        }
        const buffer = bellBufferRef.current
        if (!buffer) {
            // First reveal can land before the decode finishes. Start it and miss this one beat
            // rather than block, and every later strike has it.
            void loadBell(ctx)
            return
        }
        // A FRESH SOURCE PER STRIKE, exactly as BellSoundController clones a one-shot per hit,
        // so ring tails overlap naturally instead of one strike cutting off the last. The bell
        // rings for 20s against a 60s round, so overlap is only reachable if the round ever
        // shortens -- but the behaviour matches the arena either way.
        const src = ctx.createBufferSource()
        src.buffer = buffer
        const gain = ctx.createGain()
        gain.gain.setValueAtTime(audioVolumeRef.current, ctx.currentTime)
        src.connect(gain)
        gain.connect(ctx.destination)
        src.start()
        src.onended = () => {
            src.disconnect()
            gain.disconnect()
        }
    }, [ensureAudioContext, loadBell])

    // WEBAUDIO IS SILENT UNTIL THE USER HAS TOUCHED THE PAGE, AND NOTHING HERE EVER DID THAT.
    //
    // The gong has been inaudible since it was added (`3c04337`). The AudioContext was created
    // lazily inside playGongSound, which only ever runs from a socket `reveal` event -- never a
    // user gesture -- so the browser started it `suspended`. The resume() beside it is called
    // from that same network callback, which is not a gesture either, so it does not unlock.
    //
    // And even where a resume eventually succeeded it was too late: `now = ctx.currentTime` was
    // read and the whole six-second envelope scheduled immediately after, while the context was
    // still suspended and its clock not advancing. The gong was scheduled into a timeline that
    // had not started.
    //
    // So: unlock on the first real gesture, once. iOS additionally requires a source to be
    // STARTED inside the gesture, not merely a resume() -- hence the one-sample silent buffer.
    useEffect(() => {
        const events = ['pointerdown', 'touchend', 'keydown'] as const
        const remove = () => events.forEach(e => document.removeEventListener(e, unlock))
        function unlock() {
            const ctx = ensureAudioContext()
            if (!ctx) return
            const src = ctx.createBufferSource()
            src.buffer = ctx.createBuffer(1, 1, ctx.sampleRate)
            src.connect(ctx.destination)
            src.start(0)
            // Decode the bell now, on the gesture, so the first reveal is not the one that
            // misses. decodeAudioData needs a running context, which is exactly what we just got.
            void loadBell(ctx)
            remove()
        }
        events.forEach(e => document.addEventListener(e, unlock))
        return remove
    }, [ensureAudioContext, loadBell])

    const handleServerReveal = useCallback((serverRound: ServerRound) => {
        // Trigger SFX
        playGongSound()

        const worldThrow = serverRound.worldThrow
        let res: Result = null
        let delta = 0

        const currentThrow = playerThrowRef.current
        const currentIsLocked = isLockedRef.current

        if (currentIsLocked && currentThrow) {
            res = calculateResult(currentThrow, worldThrow)

            // Authoritative server data takes precedence
            if (serverResultRef.current) {
                res = serverResultRef.current.result
                delta = serverResultRef.current.delta
                serverResultRef.current = null // Consume
            } else {
                // Safety fallback for local calculation — the pot math from `src/lib/gameRules.ts`
                // rather than restated here, so the shared fixtures cover it too.
                if (res) delta = potDelta(pointsAtStakeRef.current, res)
            }

            if (res === 'WIN') {
                setRoundResult('WIN')
                setShowDecision(true)
            } else if (res === 'SAFE') {
                setRoundResult('SAFE')
                setShowDecision(false)
            } else if (res === 'LOSS') {
                setRoundResult('LOSS')
                setShowDecision(false)
            }
        }

        const roundData: RoundData = {
            id: serverRound.id,
            worldThrow,
            distribution: serverRound.distribution || { R: 33, P: 33, S: 33 },
            totalPlayers: serverRound.totalPlayers || 0,
            playerResult: res,
            pointsDelta: delta
        }

        setLastRound(roundData)
        setShowResult(true)
        // The overlay holds for the whole reveal and hands straight over to the next
        // round, rather than clearing early and leaving a "Waiting…" gap. The length
        // comes off the wire (`revealMs` on init) because the literal that used to live
        // here went stale twice — nothing links a number here to the server's config.
        setTimeout(() => {
            setShowResult(false)
            setHistory(prev => [roundData, ...prev].slice(0, 30))
        }, revealMsRef.current)

        setPlayerThrow(null)
        setIsLocked(false)
    }, [calculateResult, playGongSound])

    const getStats = useCallback((timeframe: 'hour' | 'day' | 'week' | 'all') => {
        if (socketRef.current) {
            socketRef.current.emit('get-stats', { timeframe })
        }
    }, [])

    // Folds a server payload's clock fields into the refs above. Called from every handler
    // that carries them (`init`, `sync`, `active`) rather than from one place, because they are
    // three separate wire messages and only `sync` repeats.
    //
    // `timeLeft` remains the FALLBACK, not the primary: a server that predates the absolute
    // fields still drives the countdown the old way. That matters because the deployed PWA and
    // the deployed server do not ship together.
    const applyClock = useCallback((data: ClockPayload) => {
        if (typeof data.phase === 'string') phaseRef.current = data.phase
        if (typeof data.serverTimeMs === 'number') {
            serverOffsetRef.current = blendOffset(serverOffsetRef.current, data.serverTimeMs - Date.now())
        }
        if (typeof data.phaseEndsAtMs === 'number') {
            phaseEndsAtRef.current = data.phaseEndsAtMs
        } else if (typeof data.timeLeft === 'number') {
            setTimeLeft(data.timeLeft)
        }
    }, [])

    // THE LOCAL TICKER. Counts down from the absolute deadline at 10Hz instead of stepping once
    // per server tick, so the displayed second changes when it actually elapses rather than when
    // a packet happens to land. React bails out of a setState that produces an equal value, so
    // this re-renders once a second despite running ten times.
    //
    // Held to OPEN, matching the wire contract the UI was built against: PieTimer is calibrated
    // to `openMs` and the reveal overlay owns the screen afterwards. The server publishes a live
    // boundary during LOCK and REVEAL too, so showing a countdown there is now possible — but it
    // is a visual change, not a clock fix, and belongs to whoever decides the reveal's look.
    useEffect(() => {
        const id = setInterval(() => {
            const endsAt = phaseEndsAtRef.current
            const offset = serverOffsetRef.current
            if (endsAt === null || offset === null) return
            setTimeLeft(phaseRef.current === 'OPEN' ? secondsLeftAt(endsAt, offset, Date.now()) : 0)
        }, 100)
        return () => clearInterval(id)
    }, [])

    useEffect(() => {
        const socket = io(SOCKET_URL, {
            auth: { token }
        })
        socketRef.current = socket

        socket.on('connect', () => {
            console.log('[SOCKET] Connected. Ready to sync...')
            if (deviceIdRef.current) {
                socket.emit('sync-player', { deviceId: deviceIdRef.current })
            }
        })

        socket.on('stats-data', (data) => {
            setStats(data)
        })

        socket.on('player-data', (data) => {
            if (data && data.user) {
                console.log(`[SYNC] Player Data Received: Points=${data.user.totalPoints}, StakeStreak=${data.user.stakingStreak}`)
                setTotalPoints(data.user.totalPoints || 0)
                setBestStreak(data.user.bestStreak || 0)
                setCurrentStreak(data.user.currentStreak || 0)
                setStakingStreak(data.user.stakingStreak || 0)
                setPointsAtStake(data.user.pointsAtStake || 0)
                setInventory(data.user.inventory || ['default'])
                setEquippedId(data.user.equippedCharacterId || 'default')

                if (data.lastResult) {
                    serverResultRef.current = {
                        result: data.lastResult.result as Result,
                        delta: data.lastResult.delta
                    }
                }

                // Reconstitute history if we have global history already or when it arrives
                if (data.history && data.history.length > 0) {
                    // We DO NOT auto-trigger Decision UI on refresh anymore to prevent Arena occlusion
                    // The user can see their pot in the header and will get a fresh decision after the next round.

                    setHistory(prev => {
                        return prev.map(globalRound => {
                            const personal = data.history.find((h: PersonalRoundResult) => h.roundId === globalRound.id)
                            if (personal) {
                                return {
                                    ...globalRound,
                                    playerResult: personal.playerResult as Result,
                                    pointsDelta: personal.pointsDelta
                                }
                            }
                            return globalRound
                        })
                    })
                }

                isSyncedRef.current = true
            }
        })

        socket.on('init', (data) => {
            setGameState('ACTIVE')
            if (typeof data.revealMs === 'number') revealMsRef.current = data.revealMs
            if (typeof data.openMs === 'number') setOpenMs(data.openMs)
            applyClock(data)
            setRoundCount(data.roundCount)

            const globalHistory = data.history.map((h: ServerRound) => ({
                id: h.id,
                worldThrow: h.worldThrow,
                distribution: h.distribution || { R: 33, P: 33, S: 33 },
                totalPlayers: h.totalPlayers || 0
            }))

            setHistory(globalHistory)

            // Re-emit sync-player if we already have deviceId but weren't synced
            if (deviceIdRef.current && !isSyncedRef.current) {
                socket.emit('sync-player', { deviceId: deviceIdRef.current })
            }
        })

        socket.on('sync', (data) => {
            setGameState('ACTIVE')
            applyClock(data)
            setRoundCount(data.roundCount)
        })

        socket.on('reveal', (data) => {
            handleServerReveal(data)
        })

        socket.on('active', (data) => {
            setGameState('ACTIVE')
            applyClock(data)
            setRoundCount(data.roundCount)
            setPlayerThrow(null)
            setIsLocked(false)
        })

        return () => {
            socket.disconnect()
        }
    }, [handleServerReveal, token, applyClock])

    // Removal of local interpolation to ensure server is absolute source of truth
    useEffect(() => {
        // We rely entirely on the socket 'sync' messages which arrive every 1s
    }, [])

    const bank = () => {
        if (pointsAtStake > 0 && socketRef.current && deviceIdRef.current) {
            // Optimistic Update
            const earnings = pointsAtStake
            setTotalPoints(prev => prev + earnings)
            // Note: currentStreak is NOT reset on bank (independent)
            setStakingStreak(0)
            setPointsAtStake(0)

            socketRef.current.emit('bank', { deviceId: deviceIdRef.current })
            setActionMessage(`Bank ${earnings.toLocaleString()} pts`)
            setTimeout(() => setActionMessage(null), 2000)
        }
        setRoundResult(null)
        setShowDecision(false)
    }

    const stake = () => {
        if (pointsAtStake > 0) {
            setActionMessage(`Stake ${pointsAtStake.toLocaleString()} pts!`)
            setTimeout(() => setActionMessage(null), 2000)
        }
        setRoundResult(null)
        setShowDecision(false)
    }

    return {
        timeLeft,
        openMs,
        gameState,
        playerThrow,
        setPlayerThrow,
        isLocked,
        setIsLocked,
        roundResult,
        showDecision,
        roundCount,
        currentStreak,
        bestStreak,
        stakingStreak,
        pointsAtStake,
        totalPoints,
        lastRound,
        history,
        showResult,
        stats,
        getStats,
        bank,
        stake,
        user,
        login,
        logout,
        token,
        inventory,
        equippedId,
        equippedCharacter: catalog.find(c => c.id === equippedId) || catalog.find(c => c.id === 'default'),
        catalog,
        buyCharacter,
        equipCharacter,
        actionMessage,
        audioEnabled,
        setAudioEnabled,
        audioVolume,
        setAudioVolume
    }
}
