import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { SymbolIcon } from './Symbols'
import { cn } from '../lib/utils'

interface ArenaVisualsProps {
    gameState: 'ACTIVE' | 'REVEAL'
    playerThrow: 'R' | 'P' | 'S' | null
    isLocked: boolean
    showResult: boolean
    lastRound: any
    playerName: string
    character: any
    actionMessage: string | null
}

const THROW_LABEL: Record<string, string> = {
    R: 'Rock',
    P: 'Paper',
    S: 'Scissors'
}

export const ArenaVisuals: React.FC<ArenaVisualsProps> = ({
    gameState,
    playerThrow,
    isLocked,
    showResult,
    lastRound,
    playerName,
    character,
    actionMessage
}) => {
    const primaryColor = character?.lite?.primaryColor || '#3b82f6'
    const accentColor = character?.lite?.accentColor || '#60a5fa'

    return (
        <div className="flex-1 flex items-center justify-center w-full relative h-full">
            {/* Background Ambient Layers (Idle State) */}
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
                <motion.div
                    animate={{
                        scale: [1, 1.1, 1],
                        opacity: [0.3, 0.4, 0.3],
                    }}
                    transition={{ duration: 10, repeat: Infinity, ease: "easeInOut" }}
                    className="absolute inset-0 bg-radial-gradient from-transparent to-transparent opacity-30"
                    style={{ backgroundImage: `radial-gradient(circle, ${primaryColor}11 0%, transparent 70%)` }}
                />

                {/* Floating "Particles" for Idle */}
                <AnimatePresence>
                    {!playerThrow && !showResult && (
                        <motion.div
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            className="absolute inset-0"
                        >
                            {[...Array(6)].map((_, i) => (
                                <motion.div
                                    key={i}
                                    animate={{
                                        y: [-20, 20],
                                        opacity: [0.1, 0.3, 0.1],
                                        scale: [0.8, 1.2, 0.8]
                                    }}
                                    transition={{
                                        duration: 4 + Math.random() * 4,
                                        repeat: Infinity,
                                        delay: Math.random() * 2,
                                        ease: "easeInOut"
                                    }}
                                    className="absolute w-20 h-20 rounded-full blur-3xl opacity-5"
                                    style={{
                                        left: `${Math.random() * 100}%`,
                                        top: `${Math.random() * 100}%`,
                                        backgroundColor: primaryColor
                                    }}
                                />
                            ))}
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>

            {/* Core Interaction Display */}
            <div className="relative z-10 w-full flex flex-col items-center">
                <AnimatePresence mode="wait">
                    {showResult && lastRound ? (
                        /* RESULT STATE */
                        <motion.div
                            key="result"
                            initial={{ scale: 0.8, opacity: 0, y: 20 }}
                            animate={{ scale: 1, opacity: 1, y: 0 }}
                            exit={{ scale: 1.1, opacity: 0 }}
                            className="flex flex-col items-center gap-6"
                        >
                            <div className="relative">
                                {/* Success/Failure Glare */}
                                <motion.div
                                    animate={{ scale: [1, 1.2, 1], opacity: [0.4, 0.6, 0.4] }}
                                    transition={{ duration: 2, repeat: Infinity }}
                                    className={cn(
                                        "absolute inset-0 blur-3xl -z-10",
                                        lastRound.playerResult === 'WIN' ? "bg-green-500/30" :
                                            lastRound.playerResult === 'SAFE' ? "bg-yellow-500/30" :
                                                lastRound.playerResult === 'LOSS' ? "bg-red-500/30" : "bg-slate-500/10"
                                    )}
                                />
                                <SymbolIcon
                                    type={lastRound.worldThrow}
                                    className={cn(
                                        "w-28 h-28 drop-shadow-[0_0_20px_rgba(255,255,255,0.3)]",
                                        lastRound.playerResult === 'WIN' ? "text-green-400" :
                                            lastRound.playerResult === 'SAFE' ? "text-yellow-400" :
                                                lastRound.playerResult === 'LOSS' ? "text-red-400" : "text-slate-400"
                                    )}
                                />
                            </div>

                            <motion.div
                                initial={{ y: 10, opacity: 0 }}
                                animate={{ y: 0, opacity: 1 }}
                                exit={{ opacity: 0 }}
                                className={cn(
                                    "px-6 py-2 rounded-full font-black uppercase tracking-[0.3em] italic text-sm border-b-2 shadow-xl text-center",
                                    lastRound.playerResult === 'WIN' ? "bg-green-500/20 border-green-500/50 text-green-500 neon-border-win" :
                                        lastRound.playerResult === 'SAFE' ? "bg-yellow-500/10 border-yellow-500/50 text-yellow-500 neon-border-safe" :
                                            lastRound.playerResult === 'LOSS' ? "bg-red-500/20 border-red-500/50 text-red-500 neon-border-loss" :
                                                "bg-slate-800/40 border-slate-700/50 text-slate-500"
                                )}
                            >
                                {`World throws ${lastRound.worldThrow === 'R' ? 'Rock' : lastRound.worldThrow === 'P' ? 'Paper' : 'Scissors'}`}
                            </motion.div>

                            <motion.span
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                className={cn(
                                    "text-[20px] font-black tracking-widest uppercase tabular-nums drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]",
                                    !lastRound.playerResult ? "text-slate-500" :
                                        lastRound.pointsDelta > 0 ? "text-green-500" : "text-red-500"
                                )}
                            >
                                {!lastRound.playerResult ? 'NO THROW' :
                                    lastRound.pointsDelta > 0 ? `+${lastRound.pointsDelta} PTS` :
                                        lastRound.pointsDelta < 0 ? `${Math.abs(lastRound.pointsDelta)} Staked Points Lost` :
                                            '0 PTS'}
                            </motion.span>
                        </motion.div>

                    ) : playerThrow ? (
                        /* SELECTION / LOCKED STATE */
                        <motion.div
                            key="selection"
                            initial={{ scale: 0.9, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 1.1, opacity: 0 }}
                            className="flex flex-col items-center gap-4"
                        >
                            <div className="relative">
                                <AnimatePresence>
                                    {isLocked && (
                                        <motion.div
                                            initial={{ scale: 1, opacity: 0 }}
                                            animate={{ scale: 1.5, opacity: 0.4 }}
                                            transition={{ duration: 0.4 }}
                                            className="absolute inset-0 rounded-full blur-2xl"
                                            style={{ backgroundColor: primaryColor }}
                                        />
                                    )}
                                </AnimatePresence>
                                <SymbolIcon
                                    type={playerThrow}
                                    className={cn(
                                        "w-24 h-24 transition-all duration-500",
                                        isLocked ? "scale-110 drop-shadow-[0_0_20px_rgba(255,255,255,0.2)]" : "opacity-80"
                                    )}
                                    style={{ color: isLocked ? primaryColor : accentColor }}
                                />
                            </div>
                            <span className={cn(
                                "text-sm font-black uppercase tracking-[0.4em] italic",
                                isLocked ? "animate-pulse" : "text-slate-500"
                            )} style={{ color: isLocked ? primaryColor : undefined }}>
                                {isLocked ? `${playerName} throws ${playerThrow ? THROW_LABEL[playerThrow] : '...'}` : 'RECONNAISSANCE'}
                            </span>
                        </motion.div>

                    ) : (
                        /* IDLE STATE */
                        <motion.div
                            key="idle"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            className="flex flex-col items-center gap-2"
                        >
                            <div className="w-16 h-16 rounded-full border border-slate-800 flex items-center justify-center relative">
                                <motion.div
                                    animate={{ rotate: 360 }}
                                    transition={{ duration: 8, repeat: Infinity, ease: "linear" }}
                                    className={cn(
                                        "absolute inset-0 border-t rounded-full",
                                        gameState === 'ACTIVE' ? "opacity-40" : "opacity-20"
                                    )}
                                    style={{ borderColor: primaryColor }}
                                />
                                <span className="text-slate-600 text-xs font-black tracking-widest">
                                    {gameState === 'ACTIVE' ? '?' : '...'}
                                </span>
                            </div>
                            <p className="text-slate-600 uppercase text-[9px] font-black tracking-[0.2em] mt-2">
                                {gameState === 'ACTIVE' ? 'Choose Your Weapon' : 'Calculating...'}
                            </p>
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* ACTION MESSAGE OVERLAY */}
                <AnimatePresence>
                    {actionMessage && (
                        <motion.div
                            initial={{ scale: 0.5, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 1.5, opacity: 0 }}
                            className="absolute inset-0 flex items-center justify-center z-[100] pointer-events-none"
                        >
                            <div className="px-8 py-4 bg-slate-950/60 backdrop-blur-xl rounded-3xl border border-white/10 shadow-2xl">
                                <span className="text-[32px] font-black uppercase italic tracking-tighter text-white drop-shadow-[0_4px_10px_rgba(0,0,0,0.8)] text-center">
                                    {actionMessage}
                                </span>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>
        </div>
    )
}
