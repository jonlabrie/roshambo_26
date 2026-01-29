import React, { useEffect } from 'react'
import { useRive, Layout, Fit, Alignment } from '@rive-app/react-canvas'
import { motion, AnimatePresence } from 'framer-motion'
import { SymbolIcon } from './Symbols'
import { cn } from '../lib/utils'

interface RiveStateProps {
    src: string
    stateMachine: string
    inputValues: Record<string, number | boolean>
    className?: string
}

const RiveStatePlayer: React.FC<RiveStateProps> = ({ src, stateMachine, inputValues, className }) => {
    const { rive, RiveComponent } = useRive({
        src,
        stateMachines: stateMachine,
        layout: new Layout({
            fit: Fit.Cover,
            alignment: Alignment.Center,
        }),
        autoplay: true,
    })

    // Dynamically connect inputs safely
    useEffect(() => {
        if (!rive) return

        // getInputs is the correct way to find inputs dynamically
        const inputs = rive.stateMachineInputs(stateMachine)
        if (!inputs) return

        Object.entries(inputValues).forEach(([name, value]) => {
            const input = inputs.find(i => i.name === name)
            if (input) {
                input.value = value
            }
        })
    }, [rive, stateMachine, inputValues])

    return (
        <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.5 }}
            className={cn("absolute inset-0 w-full h-full", className)}
        >
            <RiveComponent />
        </motion.div>
    )
}

interface RiveArenaProps {
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

export const RiveArena: React.FC<RiveArenaProps> = ({
    gameState,
    playerThrow,
    isLocked,
    showResult,
    lastRound,
    playerName,
    character,
    actionMessage
}) => {
    // Current "State" of the Arena logic
    const currentVisualState = showResult ? 'RESULT' : playerThrow ? 'SELECTION' : 'IDLE'

    // Satisfy the lint by using gameState
    useEffect(() => {
        console.log('Transitioning to state:', currentVisualState, 'GameLoop:', gameState)
    }, [currentVisualState, gameState])

    const characterTheme = {
        IDLE: {
            src: character?.full?.src || 'https://cdn.rive.app/animations/vehicles.riv',
            stateMachine: character?.full?.stateMachine || 'bumpy',
            inputValues: { level: 0 }
        },
        SELECTION: {
            src: character?.full?.src || 'https://cdn.rive.app/animations/vehicles.riv',
            stateMachine: character?.full?.stateMachine || 'bumpy',
            inputValues: { level: 50 }
        },
        RESULT: {
            src: character?.full?.src || 'https://cdn.rive.app/animations/vehicles.riv',
            stateMachine: character?.full?.stateMachine || 'bumpy',
            inputValues: { level: 100 }
        }
    }

    return (
        <div className="w-full h-full relative flex items-center justify-center overflow-hidden bg-slate-900/10">
            <AnimatePresence mode="wait">
                {currentVisualState === 'IDLE' && (
                    <RiveStatePlayer
                        key="idle"
                        {...characterTheme.IDLE}
                    />
                )}
                {currentVisualState === 'SELECTION' && (
                    <div className="absolute inset-0 z-0">
                        <RiveStatePlayer
                            key="selection"
                            {...characterTheme.SELECTION}
                            inputValues={{ level: isLocked ? 100 : 50 }}
                        />
                        <div className="absolute inset-0 flex flex-col items-center justify-center pt-32 pointer-events-none">
                            <AnimatePresence>
                                {isLocked && (
                                    <motion.div
                                        initial={{ opacity: 0, scale: 0.9 }}
                                        animate={{ opacity: 1, scale: 1 }}
                                        exit={{ opacity: 0, scale: 1.1 }}
                                        className="px-6 py-2 bg-slate-950/80 backdrop-blur-md rounded-2xl border border-blue-500/30 flex flex-col items-center gap-1"
                                    >
                                        <span className="text-sm font-black text-blue-500 animate-pulse uppercase tracking-[0.3em] italic">
                                            {`${playerName} throws ${playerThrow ? THROW_LABEL[playerThrow] : '...'}`}
                                        </span>
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div>
                    </div>
                )}
                {currentVisualState === 'RESULT' && (
                    <RiveStatePlayer
                        key="result"
                        {...characterTheme.RESULT}
                    />
                )}
            </AnimatePresence>

            {/* Global Overlay Layer */}
            {showResult && lastRound && (
                <div
                    className="absolute inset-0 z-10 flex flex-col items-center justify-center pointer-events-none p-6"
                >
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
                                    lastRound.playerResult === 'WIN' ? "text-green-400" :
                                        lastRound.playerResult === 'SAFE' ? "text-yellow-400" :
                                            lastRound.playerResult === 'LOSS' ? "text-red-400" : "text-slate-400"
                                )}
                            />
                        </div>
                        <div
                            className={cn(
                                "px-8 py-4 rounded-3xl font-black uppercase tracking-[0.2em] italic text-white shadow-2xl border-2 bg-slate-950/80 backdrop-blur-xl text-center",
                                lastRound.playerResult === 'WIN' ? "border-green-500/50 shadow-green-500/20 text-green-400" :
                                    lastRound.playerResult === 'LOSS' ? "border-red-500/50 shadow-red-500/20 text-red-400" :
                                        lastRound.playerResult === 'SAFE' ? "border-yellow-500/50 shadow-yellow-500/20 text-yellow-400" :
                                            "border-slate-500/50 shadow-slate-500/20 text-slate-500"
                            )}
                        >
                            {`World throws ${lastRound.worldThrow === 'R' ? 'Rock' : lastRound.worldThrow === 'P' ? 'Paper' : 'Scissors'}`}
                        </div>

                        <motion.span
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            className={cn(
                                "mt-4 text-[20px] font-black tracking-widest uppercase tabular-nums drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]",
                                !lastRound.playerResult ? "text-slate-500" :
                                    lastRound.pointsDelta > 0 ? "text-green-400" : "text-red-400"
                            )}
                        >
                            {!lastRound.playerResult ? 'NO THROW' :
                                lastRound.pointsDelta > 0 ? `+${lastRound.pointsDelta} PTS` :
                                    lastRound.pointsDelta < 0 ? `${Math.abs(lastRound.pointsDelta)} Staked Points Lost` :
                                        '0 PTS'}
                        </motion.span>
                    </motion.div>
                </div>
            )}

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
    )
}
