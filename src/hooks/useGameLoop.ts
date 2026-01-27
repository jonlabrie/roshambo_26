import { useState, useEffect, useCallback, useRef } from 'react'
import { io, Socket } from 'socket.io-client'

export type Throw = 'R' | 'P' | 'S' | null
export type Result = 'WIN' | 'LOSS' | 'SAFE' | null
export type GameState = 'ACTIVE' | 'REVEAL'

// Use your local IP for mobile access on the same network
const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'http://192.168.1.18:3001'

interface RoundData {
    id: string
    worldThrow: Throw
    distribution: { R: number; P: number; S: number }
    totalPlayers: number
    playerResult?: Result
    pointsDelta?: number
}

export function useGameLoop() {
    const [timeLeft, setTimeLeft] = useState(0)
    const [gameState, setGameState] = useState<GameState>('ACTIVE')
    const [playerThrow, setPlayerThrow] = useState<Throw>(null)
    const [isLocked, setIsLocked] = useState(false)
    const [showDecision, setShowDecision] = useState(false)
    const [roundCount, setRoundCount] = useState(0)
    const [roundResult, setRoundResult] = useState<Result>(null)
    const [currentStreak, setCurrentStreak] = useState(0)
    const [bestStreak, setBestStreak] = useState(0)
    const [stakingStreak, setStakingStreak] = useState(0)
    const [totalPoints, setTotalPoints] = useState(0)
    const [lastRound, setLastRound] = useState<RoundData | null>(null)
    const [history, setHistory] = useState<RoundData[]>([])
    const [showResult, setShowResult] = useState(false)
    const [stats, setStats] = useState<any>(null)
    const [user, setUser] = useState<any>(null)
    const [token, setToken] = useState<string | null>(localStorage.getItem('roshambo_auth_token'))
    const [inventory, setInventory] = useState<string[]>(['default'])
    const [equippedId, setEquippedId] = useState<string>('default')
    const [catalog, setCatalog] = useState<any[]>([])

    // Identity / Persistence
    const deviceIdRef = useRef<string | null>(null)
    const isSyncedRef = useRef(false)
    const socketRef = useRef<Socket | null>(null)
    const playerThrowRef = useRef<Throw>(null)
    const isLockedRef = useRef(false)
    const stakingStreakRef = useRef(0)
    const lastRoundRef = useRef<RoundData | null>(null)

    // Initialize Device ID
    useEffect(() => {
        let id = localStorage.getItem('roshambo_device_id')
        if (!id) {
            id = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)
            localStorage.setItem('roshambo_device_id', id)
        }
        deviceIdRef.current = id
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

    const login = (newToken: string, newUser: any) => {
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
    useEffect(() => { lastRoundRef.current = lastRound }, [lastRound])

    // Push progress to server when it changes (and we are synced)
    useEffect(() => {
        if (isSyncedRef.current && socketRef.current && deviceIdRef.current) {
            const payload: any = {
                deviceId: deviceIdRef.current,
                totalPoints,
                bestStreak,
                currentStreak,
                stakingStreak
            }
            if (token) {
                payload.token = token
            }

            // If the last round was just updated in the current "decision" phase,
            // we send its result info to update the history record on server.
            if (lastRoundRef.current) {
                payload.lastRoundId = lastRoundRef.current.id
                payload.lastPointsDelta = lastRoundRef.current.pointsDelta
            }

            socketRef.current.emit('update-progress', payload)
        }
    }, [totalPoints, bestStreak, currentStreak, stakingStreak, lastRound, token])

    // Emit throw when locked
    useEffect(() => {
        if (isLocked && playerThrow && socketRef.current && deviceIdRef.current) {
            const payload: any = {
                deviceId: deviceIdRef.current,
                throw: playerThrow
            }
            if (token) {
                payload.token = token
            }
            socketRef.current.emit('submit-throw', payload)
        }
    }, [isLocked, playerThrow, token])

    const calculateResult = useCallback((player: Throw, world: Throw): Result => {
        if (!player || !world) return null
        if (player === world) return 'LOSS'
        if (
            (player === 'R' && world === 'S') ||
            (player === 'P' && world === 'R') ||
            (player === 'S' && world === 'P')
        ) return 'WIN'
        return 'SAFE'
    }, [])

    const handleServerReveal = useCallback((serverRound: any) => {
        const worldThrow = serverRound.worldThrow
        let res: Result = null
        let delta = 0

        const currentThrow = playerThrowRef.current
        const currentIsLocked = isLockedRef.current
        const currentStakingStreak = stakingStreakRef.current

        if (currentIsLocked && currentThrow) {
            res = calculateResult(currentThrow, worldThrow)
            const prevStakingPotential = currentStakingStreak > 0 ? Math.pow(3, currentStakingStreak - 1) : 0

            if (res === 'WIN') {
                setCurrentStreak(s => {
                    const next = s + 1
                    setBestStreak(b => Math.max(b, next))
                    return next
                })
                setStakingStreak(prev => prev + 1)
                setRoundResult('WIN')
                setShowDecision(true)
                delta = Math.pow(3, currentStakingStreak)
            } else if (res === 'SAFE') {
                if (currentStakingStreak > 0) {
                    setRoundResult('SAFE')
                    setShowDecision(true)
                    delta = 0
                } else {
                    setRoundResult(null)
                    setShowDecision(false)
                }
            } else if (res === 'LOSS') {
                delta = -prevStakingPotential
                setCurrentStreak(0)
                setStakingStreak(0)
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
        setTimeout(() => {
            setShowResult(false)
            setHistory(prev => [roundData, ...prev].slice(0, 30))
        }, 3000)

        setPlayerThrow(null)
        setIsLocked(false)
    }, [calculateResult])

    const getStats = useCallback((timeframe: 'hour' | 'day' | 'week' | 'all') => {
        if (socketRef.current) {
            socketRef.current.emit('get-stats', { timeframe })
        }
    }, [])

    useEffect(() => {
        const socket = io(SOCKET_URL, {
            auth: { token }
        })
        socketRef.current = socket

        socket.on('connect', () => {
            if (deviceIdRef.current) {
                socket.emit('sync-player', { deviceId: deviceIdRef.current })
            }
        })

        socket.on('stats-data', (data) => {
            setStats(data)
        })

        socket.on('player-data', (data) => {
            if (data && data.user) {
                setTotalPoints(data.user.totalPoints || 0)
                setBestStreak(data.user.bestStreak || 0)
                setCurrentStreak(data.user.currentStreak || 0)
                setStakingStreak(data.user.stakingStreak || 0)
                setInventory(data.user.inventory || ['default'])
                setEquippedId(data.user.equippedCharacterId || 'default')

                // Reconstitute history if we have global history already or when it arrives
                if (data.history && data.history.length > 0) {
                    const lastPersonal = data.history[0]
                    if ((data.user.stakingStreak || 0) > 0) {
                        setRoundResult(lastPersonal.playerResult as Result)
                        setShowDecision(true)
                    }

                    setHistory(prev => {
                        return prev.map(globalRound => {
                            const personal = data.history.find((h: any) => h.roundId === globalRound.id)
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
            setTimeLeft(data.timeLeft)
            setRoundCount(data.roundCount)

            const globalHistory = data.history.map((h: any) => ({
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
            setTimeLeft(data.timeLeft)
            setRoundCount(data.roundCount)
        })

        socket.on('reveal', (data) => {
            handleServerReveal(data)
        })

        socket.on('active', (data) => {
            setGameState('ACTIVE')
            setTimeLeft(data.timeLeft)
            setRoundCount(data.roundCount)
            setPlayerThrow(null)
            setIsLocked(false)
        })

        return () => {
            socket.disconnect()
        }
    }, [handleServerReveal])

    // Removal of local interpolation to ensure server is absolute source of truth
    useEffect(() => {
        // We rely entirely on the socket 'sync' messages which arrive every 1s
    }, [])

    const bank = () => {
        if (stakingStreak > 0) {
            const roundEarnings = Math.pow(3, stakingStreak - 1)
            setTotalPoints(p => p + roundEarnings)
        }
        setStakingStreak(0)
        setRoundResult(null)
        setShowDecision(false)
    }

    const stake = () => {
        setRoundResult(null)
        setShowDecision(false)
    }

    return {
        timeLeft,
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
        equipCharacter
    }
}
