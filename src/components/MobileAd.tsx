import React from 'react'
import { motion } from 'framer-motion'
import { X, Zap } from 'lucide-react'

interface MobileAdProps {
    isVisible: boolean
}

export const MobileAd: React.FC<MobileAdProps> = ({ isVisible }) => {
    if (!isVisible) return null

    return (
        <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="absolute bottom-4 left-4 right-4 z-40"
        >
            <div className="glass-panel rounded-xl overflow-hidden shadow-2xl border border-white/5 bg-slate-900/40 backdrop-blur-md">
                <div className="flex items-center justify-between px-3 py-1 bg-white/5 border-b border-white/5">
                    <span className="text-[7px] font-black uppercase tracking-[0.2em] text-slate-500">Sponsored Intelligence</span>
                    <button className="text-slate-500 hover:text-white transition-colors">
                        <X className="w-2.5 h-2.5" />
                    </button>
                </div>

                <div className="p-3 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center shrink-0 shadow-lg">
                        <Zap className="w-6 h-6 text-white" />
                    </div>

                    <div className="flex-1 min-w-0">
                        <h4 className="text-[10px] font-black text-white uppercase tracking-wider truncate">Go Pro for No Ads</h4>
                        <p className="text-[8px] text-slate-400 font-medium leading-tight line-clamp-2">Support Roshambo and unlock exclusive arena themes & emotes.</p>
                    </div>

                    <button className="px-3 py-1.5 rounded-md bg-blue-600 hover:bg-blue-500 text-white text-[9px] font-black uppercase tracking-widest transition-all shrink-0">
                        UPGRADE
                    </button>
                </div>
            </div>
        </motion.div>
    )
}
