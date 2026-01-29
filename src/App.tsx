import { Wallet, Zap, BarChart3, User } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useState } from 'react'
import { useGameLoop } from './hooks/useGameLoop'
import Tape from './components/Tape'
import { SymbolIcon } from './components/Symbols'
import { PieTimer } from './components/PieTimer'
import { StatsView } from './components/StatsView'
import { ArenaVisuals } from './components/ArenaVisuals'
import { RiveArena } from './components/RiveArena'
import { VideoArena } from './components/VideoArena'
import { MobileAd } from './components/MobileAd'
import { AuthView } from './components/AuthView'
import { StoreView } from './components/StoreView'
import { cn } from './lib/utils'

const THROW_LABEL: Record<string, string> = {
    R: 'Rock',
    P: 'Paper',
    S: 'Scissors'
}

export default function App() {
    const {
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
        equippedCharacter,
        catalog,
        buyCharacter,
        equipCharacter,
        actionMessage
    } = useGameLoop()

    const [visualTier, setVisualTier] = useState<'LITE' | 'FULL' | 'ULTRA'>('FULL')
    const [currentView, setCurrentView] = useState<'GAME' | 'USER_STATS' | 'GLOBAL_STATS' | 'AUTH' | 'STORE'>('GAME')

    const currentPotential = pointsAtStake

    if (currentView === 'AUTH') {
        return (
            <AnimatePresence mode="wait">
                <AuthView
                    onBack={() => setCurrentView('GAME')}
                    onAuthSuccess={(token, user) => {
                        login(token, user)
                        setCurrentView('USER_STATS')
                    }}
                />
            </AnimatePresence>
        )
    }

    if (currentView === 'STORE') {
        return (
            <AnimatePresence mode="wait">
                <StoreView
                    onBack={() => setCurrentView('USER_STATS')}
                    catalog={catalog}
                    inventory={inventory}
                    equippedId={equippedId}
                    totalPoints={totalPoints}
                    onPurchase={buyCharacter}
                    onEquip={equipCharacter}
                    isGuest={!token}
                    onLoginRequest={() => setCurrentView('AUTH')}
                />
            </AnimatePresence>
        )
    }

    if (currentView !== 'GAME') {
        return (
            <AnimatePresence mode="wait">
                <StatsView
                    initialTab={currentView === 'USER_STATS' ? 'PROFILE' : 'GLOBAL'}
                    onBack={() => setCurrentView('GAME')}
                    serverStats={stats}
                    getStats={getStats}
                    playerStats={{
                        totalPoints,
                        bestStreak,
                        currentStreak,
                        winRate: "64%", // placeholder for now
                        totalRounds: history.length,
                        isGuest: !token
                    }}
                    onLoginRequest={() => setCurrentView('AUTH')}
                    onLogout={logout}
                    onStoreRequest={() => setCurrentView('STORE')}
                    user={user}
                />
            </AnimatePresence>
        )
    }

    return (
        <div className="flex flex-col h-full overflow-hidden font-sans max-h-screen">
            <header className="p-4 pt-[calc(1rem+env(safe-area-inset-top))] border-b border-slate-800 bg-slate-900/50 backdrop-blur-md">
                <div className="flex items-center justify-between mb-4">
                    <div className="flex flex-col leading-none">
                        <div className="flex items-baseline gap-2">
                            <h1 className="text-xl font-black tracking-tighter text-white">ROSHAMBO</h1>
                            <span className="text-[8px] font-black text-blue-500/80 uppercase tracking-[0.2em] italic">You vs World</span>
                        </div>
                        <span className="text-[8px] font-bold text-slate-500 uppercase tracking-widest mt-0.5">Global Round #{roundCount + 1042}</span>
                    </div>

                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => setCurrentView('USER_STATS')}
                            className="p-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-400 hover:text-white transition-all"
                        >
                            <User className="w-4 h-4" />
                        </button>

                        <button
                            onClick={() => setCurrentView('STORE')}
                            className="p-2 rounded-lg border border-slate-700 bg-slate-800 text-yellow-500 hover:text-yellow-400 transition-all"
                        >
                            <Zap className="w-4 h-4" />
                        </button>

                        <button
                            onClick={() => setCurrentView('GLOBAL_STATS')}
                            className="p-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-400 hover:text-white transition-all"
                        >
                            <BarChart3 className="w-4 h-4" />
                        </button>

                    </div>
                </div>
                <div className="mt-2 flex items-center gap-4">
                    <PieTimer
                        timeLeft={timeLeft}
                        totalTime={20}
                        worldThrow={lastRound?.worldThrow ?? null}
                        showResult={showResult}
                    />
                    <div className="flex-1 overflow-hidden">
                        <Tape history={history} />
                    </div>
                </div>
            </header>

            <main className="flex-1 relative bg-slate-950/20 overflow-hidden flex flex-col">
                {visualTier === 'LITE' ? (
                    <ArenaVisuals
                        gameState={gameState}
                        playerThrow={playerThrow}
                        isLocked={isLocked}
                        showResult={showResult}
                        lastRound={lastRound}
                        playerName={user?.displayName || 'Player'}
                        character={equippedCharacter}
                        actionMessage={actionMessage}
                    />
                ) : visualTier === 'FULL' ? (
                    <RiveArena
                        gameState={gameState}
                        playerThrow={playerThrow}
                        isLocked={isLocked}
                        showResult={showResult}
                        lastRound={lastRound}
                        playerName={user?.displayName || 'Player'}
                        character={equippedCharacter}
                        actionMessage={actionMessage}
                    />
                ) : (
                    <VideoArena
                        gameState={gameState}
                        playerThrow={playerThrow}
                        isLocked={isLocked}
                        showResult={showResult}
                        lastRound={lastRound}
                        playerName={user?.displayName || 'Player'}
                        character={equippedCharacter}
                        actionMessage={actionMessage}
                    />
                )}

                {/* Visual Tier Control - Moved to Arena Top Right */}
                <div className="absolute top-4 right-4 z-50">
                    <button
                        onClick={() => {
                            const tiers: ('LITE' | 'FULL' | 'ULTRA')[] = ['LITE', 'FULL', 'ULTRA']
                            const nextIndex = (tiers.indexOf(visualTier) + 1) % tiers.length
                            setVisualTier(tiers[nextIndex])
                        }}
                        className={cn(
                            "px-3 py-2 rounded-lg border text-[9px] font-black uppercase tracking-tighter transition-all flex items-center gap-2 backdrop-blur-md",
                            visualTier === 'ULTRA' ? "bg-purple-500/30 border-purple-500 text-purple-400 shadow-[0_0_10px_rgba(168,85,247,0.2)]" :
                                visualTier === 'FULL' ? "bg-blue-500/30 border-blue-500 text-blue-400 shadow-[0_0_10px_rgba(59,130,246,0.1)]" :
                                    "bg-slate-900/40 border-slate-700 text-slate-500"
                        )}
                    >
                        <span className="w-1.5 h-1.5 rounded-full animate-pulse bg-current" />
                        {visualTier}
                    </button>
                </div>

                {/* Mobile Ad Space - Hides during reveal results */}
                <MobileAd isVisible={!showResult} />

                {/* Message Area */}
                <div className="min-h-[60px] flex items-center justify-center p-4">
                    <AnimatePresence mode="wait">
                        {showDecision && roundResult ? (
                            <motion.div
                                key="decision-msg"
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -10 }}
                                className="text-center space-y-1 max-w-xs"
                            >
                                <h2 className={cn(
                                    "text-xl font-black uppercase tracking-tighter",
                                    roundResult === 'WIN' ? "text-green-500" : roundResult === 'LOSS' ? "text-red-500" : "text-yellow-500"
                                )}>
                                    {roundResult === 'WIN' ? 'Winner!' : roundResult === 'LOSS' ? 'Lose' : 'Safe Result'}
                                </h2>
                                <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">
                                    {roundResult === 'WIN' ? 'Stake current points or Points?' :
                                        roundResult === 'LOSS' ? 'Try again!' : 'Preserved. Continue playing?'}
                                </p>
                            </motion.div>
                        ) : gameState === 'REVEAL' && (lastRound?.playerResult || roundResult) !== 'LOSS' ? (
                            <motion.div
                                key="reveal-msg"
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                exit={{ opacity: 0 }}
                                className="flex flex-col items-center gap-1.5"
                            >
                                <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest text-center">World Result</p>
                                <div className={cn(
                                    "text-[10px] font-black px-4 py-1 rounded-full uppercase tracking-widest shadow-lg",
                                    !roundResult ? "bg-slate-800 text-slate-500" :
                                        roundResult === 'WIN' ? "bg-green-500 text-white" :
                                            roundResult === 'SAFE' ? "bg-yellow-500 text-black" : "bg-red-500 text-white"
                                )}>
                                    {roundResult || 'NEUTRAL'}
                                </div>
                            </motion.div>
                        ) : (
                            <motion.div
                                key="instructions-msg"
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                exit={{ opacity: 0 }}
                                className="text-center"
                            >
                                <p className="text-[10px] text-slate-500 font-black uppercase tracking-[0.2em] opacity-60">
                                    {gameState === 'ACTIVE' && isLocked ? 'Transmitting Selection...' :
                                        gameState === 'ACTIVE' && !playerThrow ? 'Select your throw below to join' :
                                            gameState === 'REVEAL' ? 'Round Over' : 'Waiting...'}
                                </p>
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </main>

            <footer className="p-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] glass-panel border-b-0 border-x-0 bg-slate-900/50 relative z-40 space-y-3">
                <div className="flex items-center justify-between px-1">
                    <div className="flex flex-col leading-tight">
                        <span className="text-[8px] font-black text-slate-500 uppercase tracking-widest">Streak</span>
                        <div className="flex items-baseline gap-1.5">
                            <span className="text-base font-black text-white">{currentStreak}x</span>
                            {bestStreak > 0 && (
                                <span className="text-[9px] font-black text-slate-600 uppercase tracking-tighter">Best {bestStreak}x</span>
                            )}
                        </div>
                    </div>

                    <div className="flex items-center gap-4 border-l border-slate-800 pl-4">
                        <div className="flex flex-col items-end leading-tight">
                            <span className="text-[8px] font-black text-slate-500 uppercase tracking-widest">Points</span>
                            <span className="text-base font-black text-blue-400 tabular-nums">
                                {totalPoints.toLocaleString()}
                            </span>
                        </div>

                        <AnimatePresence>
                            {currentStreak > 0 && !showDecision && (
                                <motion.div
                                    initial={{ opacity: 0, x: 10 }}
                                    animate={{ opacity: 1, x: 0 }}
                                    exit={{ opacity: 0, x: 10 }}
                                    className="flex flex-col items-end leading-tight border-l border-slate-800/50 pl-4"
                                >
                                    <div className="flex items-center gap-1">
                                        <Zap className="w-2 h-2 text-yellow-500 fill-yellow-500" />
                                        <span className="text-[8px] font-black text-slate-500 uppercase tracking-widest text-right">Stake</span>
                                    </div>
                                    <span className="text-base font-black text-yellow-500 tabular-nums">
                                        {currentPotential.toLocaleString()}
                                    </span>
                                </motion.div>
                            )}
                        </AnimatePresence>
                    </div>
                </div>

                {!showDecision && gameState === 'ACTIVE' && (
                    <div className="flex flex-col gap-2">
                        <div className="grid grid-cols-3 gap-2">
                            {(['R', 'P', 'S'] as const).map((t) => {
                                const isSelected = playerThrow === t;
                                const isOtherSelected = playerThrow && playerThrow !== t;

                                return (
                                    <button
                                        key={t}
                                        disabled={isLocked}
                                        onClick={() => {
                                            if (isLocked) return;
                                            if (isSelected) {
                                                setIsLocked(true);
                                            } else if (isOtherSelected) {
                                                setPlayerThrow(null);
                                            } else {
                                                setPlayerThrow(t);
                                            }
                                        }}
                                        className={cn(
                                            "flex flex-col items-center justify-center gap-0.5 py-2 rounded-xl glass-panel transition-all border-b-4",
                                            isSelected
                                                ? (isLocked ? "bg-blue-500/30 border-blue-500" : "bg-green-500/20 border-green-500 scale-[1.02]")
                                                : (isOtherSelected ? "bg-red-500/10 border-red-900/30 opacity-60" : "border-slate-800 hover:bg-slate-700"),
                                        )}
                                    >
                                        <SymbolIcon
                                            type={t}
                                            className={cn(
                                                "w-10 h-10 transition-colors",
                                                t === 'S' && "w-12 h-12",
                                                isSelected ? "text-green-400 scale-110" : "text-[#1e3a8a]/60"
                                            )}
                                        />
                                        <span className={cn(
                                            "text-[9px] font-black uppercase tracking-widest",
                                            isSelected && isLocked ? "text-blue-400" :
                                                isSelected && !isLocked ? "text-green-500" :
                                                    isOtherSelected && !isLocked ? "text-red-500" : "text-slate-500"
                                        )}>
                                            {isSelected && isLocked ? 'LOCKED' :
                                                isSelected && !isLocked ? 'Confirm' :
                                                    isOtherSelected && !isLocked ? 'Cancel' :
                                                        THROW_LABEL[t]}
                                        </span>
                                    </button>
                                );
                            })}
                        </div>
                    </div>
                )}

                {showDecision && (
                    <div className="flex flex-col gap-3 h-full">
                        {(roundResult === 'WIN' || roundResult === 'SAFE') ? (
                            <div className="grid grid-cols-2 gap-4 flex-1">
                                <button
                                    onClick={bank}
                                    className="flex flex-col items-center justify-center gap-2 py-4 rounded-xl bg-slate-800 border-2 border-slate-700 hover:bg-slate-700 transition-all font-black uppercase tracking-widest text-[11px]"
                                >
                                    <Wallet className="w-6 h-6 text-blue-400" />
                                    Bank {currentPotential.toLocaleString()} pts
                                </button>
                                <button
                                    onClick={stake}
                                    className={cn(
                                        "flex flex-col items-center justify-center gap-2 py-4 rounded-xl transition-all font-black uppercase tracking-widest text-[11px]",
                                        roundResult === 'WIN' ? "bg-blue-600 hover:bg-blue-500 shadow-lg shadow-blue-500/20" : "bg-slate-700 hover:bg-slate-600"
                                    )}
                                >
                                    <Zap className={cn("w-6 h-6", roundResult === 'WIN' ? "text-white" : "text-slate-400")} />
                                    {roundResult === 'WIN' ? `Stake ${currentPotential.toLocaleString()} pts` : 'Next Round'}
                                </button>
                            </div>
                        ) : (
                            <button
                                onClick={stake}
                                className="w-full py-4 flex items-center justify-center gap-3 rounded-xl bg-slate-800 text-slate-400 font-black uppercase tracking-widest text-xs shadow-xl active:scale-95 transition-all"
                            >
                                Return to Arena
                            </button>
                        )}
                    </div>
                )}
            </footer>
        </div >
    )
}
