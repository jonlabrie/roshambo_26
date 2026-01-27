import { motion } from 'framer-motion'
import { Check, X } from 'lucide-react'
import { SymbolIcon } from './Symbols'
import { cn } from '../lib/utils'

interface RoundData {
    id: string
    worldThrow: 'R' | 'P' | 'S' | null
    playerResult?: 'WIN' | 'LOSS' | 'SAFE' | null
}

interface TapeProps {
    history: RoundData[]
}

export default function Tape({ history }: TapeProps) {
    return (
        <div className="w-full">
            <div className="flex items-center text-slate-500 mb-1.5 px-1">
                <span className="text-[8px] font-black uppercase tracking-[0.2em]">World Throw History</span>
            </div>

            <div className="flex gap-1 overflow-x-auto pb-1 no-scrollbar">
                {history.length === 0 && (
                    <div className="w-full py-2.5 text-center text-slate-700 text-[7px] uppercase font-bold tracking-[0.2em] italic glass-panel rounded-lg">
                        Waiting...
                    </div>
                )}
                {history.slice(0, 10).map((round) => (
                    <motion.div
                        key={round.id}
                        initial={{ opacity: 0, x: -10 }}
                        animate={{ opacity: 1, x: 0 }}
                        className="flex-shrink-0 w-10 h-10 rounded-lg glass-panel flex items-center justify-center relative border-b-2 border-slate-700"
                    >
                        <SymbolIcon
                            type={round.worldThrow}
                            className={cn(
                                "w-5 h-5 text-white/90",
                                round.worldThrow === 'P' && "w-6 h-6",
                                round.worldThrow === 'S' && "w-5 h-5"
                            )}
                        />

                        {/* Result Indicator Tag */}
                        {round.playerResult && (
                            <div className="absolute -top-0.5 -right-0.5">
                                <div className={cn(
                                    "rounded-full p-0.5 shadow-sm border border-slate-900",
                                    round.playerResult === 'WIN' ? "bg-green-500" :
                                        round.playerResult === 'LOSS' ? "bg-red-500" : "bg-yellow-500"
                                )}>
                                    {round.playerResult === 'WIN' ? (
                                        <Check className="w-1.5 h-1.5 text-white stroke-[4]" />
                                    ) : (
                                        <X className="w-1.5 h-1.5 text-white stroke-[4]" />
                                    )}
                                </div>
                            </div>
                        )}
                    </motion.div>
                ))}
            </div>
        </div>
    )
}


