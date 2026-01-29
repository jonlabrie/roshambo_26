import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, Trophy, Zap } from 'lucide-react'
import { cn } from '../lib/utils'

interface StatsViewProps {
    onBack: () => void
    serverStats: any
    getStats: (timeframe: 'hour' | 'day' | 'week' | 'all') => void
    initialTab?: 'PROFILE' | 'GLOBAL'
    playerStats: {
        totalPoints: number
        bestStreak: number
        currentStreak: number
        winRate: string
        totalRounds: number
        isGuest: boolean
    }
    onLoginRequest: () => void
    onLogout: () => void
    onStoreRequest: () => void
    user: any
}

export const StatsView: React.FC<StatsViewProps> = ({
    onBack,
    serverStats,
    getStats,
    playerStats,
    initialTab = 'PROFILE',
    onLoginRequest,
    onLogout,
    onStoreRequest,
    user
}) => {
    const [tab, setTab] = React.useState<'PROFILE' | 'GLOBAL'>(initialTab)
    const [timeframe, setTimeframe] = React.useState<'hour' | 'day' | 'week' | 'all'>('hour')
    const [subView, setSubView] = React.useState<'MAIN' | 'POINTS' | 'WINS'>('MAIN')

    React.useEffect(() => {
        getStats(timeframe)
    }, [timeframe, getStats])

    const distribution = serverStats?.globalDistribution || { avgR: 33, avgP: 33, avgS: 33 }

    const toggleSubView = (view: 'MAIN' | 'POINTS' | 'WINS') => {
        setSubView(view)
    }

    const renderProfile = () => (
        <main className="flex-1 overflow-y-auto p-4 space-y-8">
            {/* Identity Banner */}
            <div className="flex items-center justify-between px-1">
                <div className="flex flex-col">
                    <span className="text-[10px] font-black text-blue-500 uppercase tracking-[0.3em]">Identity</span>
                    <h3 className="text-xl font-black italic tracking-tight">{user?.displayName || 'Anonymous Player'}</h3>
                    <span className="text-[9px] font-bold text-slate-500 uppercase tracking-widest">
                        {playerStats.isGuest ? 'Guest Session' : user?.email}
                    </span>
                </div>
                {playerStats.isGuest ? (
                    <button
                        onClick={onLoginRequest}
                        className="px-4 py-2 bg-blue-600 rounded-lg text-[10px] font-black uppercase tracking-widest active:scale-95 transition-all"
                    >
                        Login
                    </button>
                ) : (
                    <button
                        onClick={onLogout}
                        className="px-4 py-2 border border-slate-700 bg-slate-900 rounded-lg text-[10px] font-black uppercase tracking-widest text-slate-400 hover:text-white transition-all"
                    >
                        Logout
                    </button>
                )}
            </div>

            {/* Store Entry Button */}
            <button
                onClick={onStoreRequest}
                className="w-full relative flex items-center justify-between p-5 bg-gradient-to-r from-blue-600/20 to-purple-600/20 rounded-2xl border border-white/5 hover:border-white/10 transition-all group overflow-hidden"
            >
                <div className="absolute inset-0 bg-blue-500/10 blur-3xl opacity-0 group-hover:opacity-100 transition-opacity" />
                <div className="flex items-center gap-4 relative z-10">
                    <div className="w-10 h-10 rounded-xl bg-slate-900 border border-white/5 flex items-center justify-center">
                        <Zap className="w-5 h-5 text-yellow-500" />
                    </div>
                    <div className="flex flex-col items-start leading-tight">
                        <span className="text-[10px] font-black uppercase tracking-[0.2em] text-blue-500">The Emporium</span>
                        <h4 className="text-sm font-black italic uppercase italic">Character Store</h4>
                    </div>
                </div>
                <div className="px-3 py-1 bg-white/10 rounded-lg text-[10px] font-black uppercase tracking-widest relative z-10">
                    Browse
                </div>
            </button>

            {/* Hero Stats (Personal) */}
            <div className="grid grid-cols-2 gap-3">
                <div className="glass-panel p-4 rounded-2xl flex flex-col gap-1 border-b-4 border-blue-500/50">
                    <div className="flex items-center gap-2 text-blue-400">
                        <Trophy className="w-4 h-4" />
                        <span className="text-[10px] font-black uppercase tracking-widest">Your Points</span>
                    </div>
                    <span className="text-2xl font-black tabular-nums">{playerStats.totalPoints.toLocaleString()}</span>
                </div>
                <div className="glass-panel p-4 rounded-2xl flex flex-col gap-1 border-b-4 border-yellow-500/50">
                    <div className="flex items-center gap-2 text-yellow-500">
                        <Zap className="w-4 h-4" />
                        <span className="text-[10px] font-black uppercase tracking-widest">Best Streak</span>
                    </div>
                    <span className="text-2xl font-black tabular-nums">{playerStats.bestStreak}x</span>
                </div>
            </div>

            {/* Performance Details */}
            <div className="space-y-4">
                <h3 className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Performance Details</h3>
                <div className="space-y-2">
                    <StatRow label="Win rate" value={playerStats.winRate} />
                    <StatRow label="Current Streak" value={`${playerStats.currentStreak}x`} />
                    <StatRow label="Participation" value={`${playerStats.totalRounds} Rounds`} />
                </div>
            </div>

            {/* Placeholder Chart */}
            <div className="space-y-4 pt-4">
                <h3 className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Activity Evolution</h3>
                <div className="h-32 w-full glass-panel rounded-2xl flex items-end justify-between p-4 gap-1 border-b border-slate-800">
                    {[40, 70, 45, 90, 65, 80, 50, 95, 30, 60].map((h, i) => (
                        <motion.div
                            key={i}
                            initial={{ height: 0 }}
                            animate={{ height: `${h}%` }}
                            transition={{ delay: i * 0.05, duration: 0.5 }}
                            className={cn(
                                "w-full rounded-t-sm",
                                i === 7 ? "bg-blue-500 shadow-[0_0_10px_rgba(59,130,246,0.5)]" : "bg-slate-800/50"
                            )}
                        />
                    ))}
                </div>
            </div>
        </main>
    )

    const renderGlobalMain = () => (
        <main className="flex-1 overflow-y-auto p-4 space-y-8">
            {/* Global Sentiment */}
            <section className="space-y-3">
                <h3 className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Global Sentiment</h3>
                <div className="grid grid-cols-3 gap-2">
                    <SentimentCard label="Rock" value={distribution.avgR} color="text-red-400" bgColor="bg-red-400/10" />
                    <SentimentCard label="Paper" value={distribution.avgP} color="text-blue-400" bgColor="bg-blue-400/10" />
                    <SentimentCard label="Scissors" value={distribution.avgS} color="text-green-400" bgColor="bg-green-400/10" />
                </div>
            </section>

            {/* Leaderboard: High Points (Top 3) */}
            <section className="space-y-3">
                <div className="flex items-center justify-between px-1">
                    <h3 className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">Top Total Points</h3>
                    <Trophy className="w-3 h-3 text-yellow-500" />
                </div>
                <div className="space-y-2">
                    {serverStats?.topPoints?.slice(0, 3).map((user: any, i: number) => (
                        <LeaderboardRow
                            key={user.deviceId || i}
                            rank={i + 1}
                            label={(user.deviceId || '........').substring(0, 8)}
                            value={`${user.totalPoints?.toLocaleString() || 0} PTS`}
                            highlight={i < 3}
                        />
                    ))}
                </div>
                {serverStats?.topPoints?.length > 3 && (
                    <button
                        onClick={() => toggleSubView('POINTS')}
                        className="w-full py-3 text-[10px] font-black uppercase text-blue-400 hover:text-blue-300 tracking-widest border border-blue-500/20 rounded-xl hover:bg-blue-500/5 transition-all mt-2"
                    >
                        View Full Leaderboard
                    </button>
                )}
            </section>

            {/* Leaderboard: Biggest Wins (Top 3) */}
            <section className="space-y-3">
                <div className="flex items-center justify-between px-1">
                    <h3 className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">Biggest Payouts</h3>
                    <Zap className="w-3 h-3 text-blue-500" />
                </div>
                <div className="space-y-2">
                    {serverStats?.biggestWins?.slice(0, 3).map((win: any, i: number) => (
                        <LeaderboardRow
                            key={win._id || i}
                            rank={i + 1}
                            label={(win.deviceId || '........').substring(0, 8)}
                            value={`+${win.pointsDelta?.toLocaleString() || 0} PTS`}
                            highlight={i < 1}
                        />
                    ))}
                    {(!serverStats?.biggestWins || serverStats.biggestWins.length === 0) && (
                        <div className="text-center py-6 text-slate-700 text-[11px] font-black uppercase tracking-widest italic border border-dashed border-slate-800 rounded-2xl">
                            No wins recorded
                        </div>
                    )}
                </div>
                {serverStats?.biggestWins?.length > 3 && (
                    <button
                        onClick={() => toggleSubView('WINS')}
                        className="w-full py-3 text-[10px] font-black uppercase text-blue-400 hover:text-blue-300 tracking-widest border border-blue-500/20 rounded-xl hover:bg-blue-500/5 transition-all mt-2"
                    >
                        View All Payouts
                    </button>
                )}
            </section>
        </main>
    )

    const renderSubPage = (type: 'POINTS' | 'WINS') => {
        const list = type === 'POINTS' ? serverStats?.topPoints : serverStats?.biggestWins
        const title = type === 'POINTS' ? 'Total Points Records' : 'Massive Wins Hall'
        const icon = type === 'POINTS' ? <Trophy className="w-4 h-4 text-yellow-500" /> : <Zap className="w-4 h-4 text-blue-500" />

        return (
            <main className="flex-1 overflow-y-auto px-4 pt-4">
                <div className="flex items-center gap-3 mb-6 px-1">
                    {icon}
                    <h3 className="text-[12px] font-black text-white uppercase tracking-[0.3em]">{title}</h3>
                </div>
                <div className="space-y-2 pb-20">
                    {list?.map((item: any, i: number) => (
                        <LeaderboardRow
                            key={type === 'POINTS' ? (item.deviceId || i) : (item._id || i)}
                            rank={i + 1}
                            label={(item.deviceId || '........').substring(0, 8)}
                            value={type === 'POINTS' ? `${item.totalPoints?.toLocaleString() || 0} PTS` : `+${item.pointsDelta?.toLocaleString() || 0} PTS`}
                            highlight={i < 3}
                        />
                    ))}
                </div>
            </main>
        )
    }

    return (
        <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="flex-1 flex flex-col bg-slate-950 text-white overflow-hidden"
        >
            {/* Header */}
            <header className="p-4 pt-[calc(1rem+env(safe-area-inset-top))] border-b border-slate-800 bg-slate-900/50 backdrop-blur-md flex items-center justify-between shrink-0">
                <button
                    onClick={subView === 'MAIN' ? onBack : () => setSubView('MAIN')}
                    className="p-2 -ml-2 rounded-full hover:bg-slate-800 transition-colors text-slate-400 hover:text-white"
                >
                    <ArrowLeft className="w-5 h-5" />
                </button>
                <h2 className="text-lg font-black tracking-tighter uppercase italic">
                    {subView !== 'MAIN' ? (subView === 'POINTS' ? 'High Scores' : 'Massive Wins') :
                        tab === 'PROFILE' ? 'Player Profile' : 'World Analytics'}
                </h2>
                <div className="w-9" />
            </header>

            {/* Primary Tab Bar (Only if not in subview) */}
            {subView === 'MAIN' && (
                <div className="flex p-1 bg-slate-900 border-b border-slate-800 shrink-0">
                    {(['PROFILE', 'GLOBAL'] as const).map((t) => (
                        <button
                            key={t}
                            onClick={() => setTab(t)}
                            className={cn(
                                "flex-1 py-3 rounded-lg text-[11px] font-black uppercase tracking-[0.2em] transition-all",
                                tab === t ? "bg-white/10 text-white shadow-inner" : "text-slate-500 hover:bg-slate-800"
                            )}
                        >
                            {t === 'PROFILE' ? 'User' : 'World'}
                        </button>
                    ))}
                </div>
            )}

            {/* Timeframe Selector (Only on global/wins) */}
            {subView !== 'POINTS' && (tab === 'GLOBAL' || subView !== 'MAIN') && (
                <div className="flex p-2 gap-1 bg-black/40 border-b border-slate-800/50 shrink-0">
                    {(['hour', 'day', 'week', 'all'] as const).map((t) => (
                        <button
                            key={t}
                            onClick={() => setTimeframe(t)}
                            className={cn(
                                "flex-1 py-2 rounded-lg text-[9px] font-black uppercase tracking-[0.2em] transition-all",
                                timeframe === t ? "bg-blue-600 text-white shadow-xl" : "text-slate-600 hover:bg-slate-900"
                            )}
                        >
                            {t}
                        </button>
                    ))}
                </div>
            )}

            <AnimatePresence mode="wait">
                <motion.div
                    key={`${tab}-${subView}`}
                    initial={{ opacity: 0, scale: 0.98 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 1.02 }}
                    className="flex-1 flex flex-col overflow-hidden"
                >
                    {subView !== 'MAIN' ? renderSubPage(subView) :
                        tab === 'PROFILE' ? renderProfile() : renderGlobalMain()}
                </motion.div>
            </AnimatePresence>

            <footer className="p-4 border-t border-slate-800 bg-slate-950 shrink-0">
                <button
                    onClick={onBack}
                    className="w-full py-4 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 transition-all font-black uppercase tracking-widest text-[11px] active:scale-95"
                >
                    Return to Arena
                </button>
            </footer>
        </motion.div>
    )
}

function StatRow({ label, value }: { label: string, value: string }) {
    return (
        <div className="flex items-center justify-between p-4 glass-panel rounded-xl border border-white/5">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">{label}</span>
            <span className="text-sm font-black text-white">{value}</span>
        </div>
    )
}

function SentimentCard({ label, value, color, bgColor }: { label: string, value: number, color: string, bgColor: string }) {
    return (
        <div className={cn("p-2.5 rounded-xl flex flex-col items-center gap-1 border border-white/5", bgColor)}>
            <span className="text-[8px] font-black text-slate-500 uppercase tracking-widest">{label}</span>
            <span className={cn("text-sm font-black tabular-nums", color)}>{Math.round(value)}%</span>
            <div className="w-full h-1 bg-white/5 rounded-full overflow-hidden mt-1">
                <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${value}%` }}
                    className={cn("h-full", color.replace('text', 'bg'))}
                />
            </div>
        </div>
    )
}

function LeaderboardRow({ rank, label, value, highlight }: { rank: number, label: string, value: string, highlight: boolean }) {
    return (
        <div className={cn(
            "flex items-center justify-between p-2.5 rounded-lg border transition-all",
            highlight ? "bg-slate-800/50 border-blue-500/30" : "bg-slate-900/40 border-slate-800/50"
        )}>
            <div className="flex items-center gap-3">
                <span className={cn(
                    "w-5 h-5 flex items-center justify-center rounded text-[9px] font-black",
                    rank === 1 ? "bg-yellow-500 text-black" :
                        rank === 2 ? "bg-slate-400 text-black" :
                            rank === 3 ? "bg-orange-600 text-white" : "bg-slate-800 text-slate-500"
                )}>{rank}</span>
                <span className="text-[10px] font-bold text-slate-300 tracking-wider">USER_{label}</span>
            </div>
            <span className={cn("text-[10px] font-black", highlight ? "text-blue-400" : "text-slate-400")}>{value}</span>
        </div>
    )
}

