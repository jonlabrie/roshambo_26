import React, { useState, useEffect, useMemo, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { SymbolIcon } from './Symbols'
import { cn } from '../lib/utils'

interface VideoArenaProps {
    gameState: 'ACTIVE' | 'REVEAL'
    playerThrow: 'R' | 'P' | 'S' | null
    isLocked: boolean
    showResult: boolean
    lastRound: any
    playerName: string
    character: any
}

const THROW_LABEL: Record<string, string> = {
    R: 'Rock',
    P: 'Paper',
    S: 'Scissors'
}

// Define available clips for each state
// Character-based manifest is now used inside the component

export const VideoArena: React.FC<VideoArenaProps> = ({
    gameState,
    playerThrow,
    isLocked,
    showResult,
    lastRound,
    playerName,
    character
}) => {
    const videoRef = useRef<HTMLVideoElement>(null)
    const [currentClip, setCurrentClip] = useState<string>('')
    const [selectionFinished, setSelectionFinished] = useState(false)

    // Reset selection state when a new round starts (isLocked becomes false)
    useEffect(() => {
        if (!isLocked) {
            setSelectionFinished(false)
        }
    }, [isLocked])

    // Determine the visual "state" string (key)
    const visualState = useMemo(() => {
        if (showResult && lastRound) {
            const worldThrow = lastRound.worldThrow
            if (worldThrow === 'R') return 'rock'
            if (worldThrow === 'P') return 'paper'
            if (worldThrow === 'S') return 'scissors'
        }
        // Only show selection video if Locked AND it hasn't finished its one-time play
        if (isLocked && !selectionFinished) return 'selection'

        return 'idle'
    }, [showResult, lastRound, isLocked, selectionFinished])

    const characterManifest = useMemo(() => {
        return character?.ultra || {
            idle: ['idle1.mp4'],
            selection: ['selection1.mp4'],
            rock: ['rock1.mp4'],
            paper: ['paper1.mp4'],
            scissors: ['scissors1.mp4']
        }
    }, [character])

    // Randomize clip whenever the visual state changes
    useEffect(() => {
        const availableClips = characterManifest[visualState as keyof typeof characterManifest]
        if (availableClips && availableClips.length > 0) {
            const randomIndex = Math.floor(Math.random() * availableClips.length)
            const filename = availableClips[randomIndex]
            setCurrentClip(`/videos/${visualState}/${filename}`)
        }
    }, [visualState, characterManifest])

    const handleVideoEnded = () => {
        if (visualState === 'selection') {
            setSelectionFinished(true)
        }
    }

    // Satisfy lint and potentially use for extra effects
    const isActive = gameState === 'ACTIVE'
    const source = currentClip
    const key = visualState // Use the state as the key for AnimatePresence transitions

    return (
        <div className="w-full h-full relative flex items-center justify-center overflow-hidden bg-black">
            {/* Cinematic Background Layer */}
            <AnimatePresence mode="wait">
                <motion.div
                    key={key}
                    initial={{ opacity: 0 }}
                    animate={{
                        opacity: 1,
                        scale: isActive ? [1, 1.02, 1] : 1
                    }}
                    transition={{
                        opacity: { duration: 1 },
                        scale: { duration: 10, repeat: Infinity, ease: "easeInOut" }
                    }}
                    className="absolute inset-0 z-0"
                >
                    <video
                        key={source}
                        ref={videoRef}
                        src={source}
                        autoPlay
                        loop={visualState !== 'selection'}
                        onEnded={handleVideoEnded}
                        muted
                        playsInline
                        className="w-full h-full object-cover"
                    />
                    {/* Vignette Overlay for Depth */}
                    <div className="absolute inset-0 shadow-[inset_0_0_150px_rgba(0,0,0,0.8)] pointer-events-none" />
                </motion.div>
            </AnimatePresence>

            {/* SELECTION / LOCKED OVERLAY (When not in result) */}
            {!showResult && playerThrow && (
                <div className="absolute inset-0 z-10 flex flex-col items-center justify-center pointer-events-none p-6">
                    <AnimatePresence>
                        {isLocked && (
                            <motion.div
                                initial={{ scale: 0.9, opacity: 0 }}
                                animate={{ scale: 1, opacity: 1 }}
                                exit={{ scale: 1.1, opacity: 0 }}
                                className="flex flex-col items-center gap-4"
                            >
                                <div className="relative">
                                    <motion.div
                                        initial={{ scale: 1, opacity: 0 }}
                                        animate={{ scale: 1.5, opacity: 0.4 }}
                                        transition={{ duration: 0.4 }}
                                        className="absolute inset-0 bg-blue-500/40 rounded-full blur-2xl"
                                    />
                                    <SymbolIcon
                                        type={playerThrow}
                                        className="w-24 h-24 text-green-400 scale-110 drop-shadow-[0_0_20px_rgba(34,197,94,0.4)]"
                                    />
                                </div>
                                <div className="px-6 py-2 bg-black/60 backdrop-blur-md rounded-2xl border border-blue-500/30">
                                    <span className="text-[10px] font-black text-blue-500 animate-pulse uppercase tracking-[0.3em] italic">
                                        {`${playerName} throws ${THROW_LABEL[playerThrow]}`}
                                    </span>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            )}

            {/* Content Overlays (Same as Rive/Standard) */}
            {showResult && lastRound && (
                <div className="absolute inset-0 z-10 flex flex-col items-center justify-center pointer-events-none p-6">
                    <motion.div
                        initial={{ scale: 0.8, opacity: 0, y: 10 }}
                        animate={{ scale: 1, opacity: 1, y: 0 }}
                        className="flex flex-col items-center"
                    >
                        <div className="relative mb-6">
                            <SymbolIcon
                                type={lastRound.worldThrow}
                                className={cn(
                                    "w-28 h-28 drop-shadow-[0_0_20px_rgba(255,255,255,0.3)]",
                                    lastRound.playerResult === 'SAFE' ? "text-yellow-400" :
                                        lastRound.playerResult === 'LOSS' ? "text-red-400" : "text-slate-400"
                                )}
                            />
                        </div>
                        <div
                            className={cn(
                                "px-10 py-5 rounded-3xl font-black uppercase tracking-[0.3em] italic text-white shadow-2xl border-2 bg-black/60 backdrop-blur-xl text-center",
                                lastRound.playerResult === 'WIN' ? "border-green-500/50 shadow-green-500/40 text-green-400" :
                                    lastRound.playerResult === 'LOSS' ? "border-red-500/50 shadow-red-500/40 text-red-400" :
                                        lastRound.playerResult === 'SAFE' ? "border-yellow-500/50 shadow-yellow-500/40 text-yellow-400" :
                                            "border-slate-500/50 shadow-slate-500/20 text-slate-500"
                            )}
                        >
                            {`World throws ${lastRound.worldThrow === 'R' ? 'Rock' : lastRound.worldThrow === 'P' ? 'Paper' : 'Scissors'}`}
                        </div>
                    </motion.div>

                    <motion.span
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        className={cn(
                            "mt-4 text-sm font-black tracking-widest uppercase tabular-nums",
                            !lastRound.playerResult ? "text-slate-500" :
                                lastRound.pointsDelta > 0 ? "text-green-400" : "text-red-400"
                        )}
                    >
                        {!lastRound.playerResult ? 'NO THROW' :
                            `${lastRound.pointsDelta > 0 ? '+' : ''}${lastRound.pointsDelta} PTS`}
                    </motion.span>
                </div>
            )}
        </div>
    )
}
