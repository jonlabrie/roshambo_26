import React from 'react'
import { motion } from 'framer-motion'
import { SymbolIcon } from './Symbols'
import { cn } from '../lib/utils'

interface PieTimerProps {
    timeLeft: number
    totalTime: number
    worldThrow: 'R' | 'P' | 'S' | null
    showResult: boolean
}

export const PieTimer: React.FC<PieTimerProps> = ({
    timeLeft,
    totalTime,
    worldThrow,
    showResult
}) => {
    const radius = 23
    const circumference = 2 * Math.PI * radius
    const progress = timeLeft / totalTime
    const strokeDashoffset = circumference * (1 - progress)

    const isWarning = timeLeft <= 4

    return (
        <div className="relative w-[54px] h-[54px] flex items-center justify-center flex-shrink-0">
            {/* Background Circle */}
            <svg className="w-full h-full -rotate-90 transform" viewBox="0 0 54 54">
                <circle
                    cx="27"
                    cy="27"
                    r={radius}
                    stroke="currentColor"
                    strokeWidth="4"
                    fill="transparent"
                    className="text-slate-800"
                />
                {/* Progress Circle */}
                <motion.circle
                    cx="27"
                    cy="27"
                    r={radius}
                    stroke="currentColor"
                    strokeWidth="4"
                    fill="transparent"
                    strokeDasharray={circumference}
                    animate={{ strokeDashoffset }}
                    transition={{ duration: 0.5, ease: "linear" }}
                    className={cn(
                        "transition-colors duration-500",
                        isWarning ? "text-red-500" : "text-green-500"
                    )}
                />
            </svg>

            {/* Inner Content */}
            <div className="absolute inset-0 flex items-center justify-center">
                {showResult && worldThrow ? (
                    <motion.div
                        initial={{ scale: 0, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        className="w-7 h-7"
                    >
                        <SymbolIcon type={worldThrow} className="w-full h-full text-white" />
                    </motion.div>
                ) : (
                    <span className={cn(
                        "text-[16px] font-black tabular-nums",
                        isWarning ? "text-red-500" : "text-slate-400"
                    )}>
                        {timeLeft}
                    </span>
                )}
            </div>
        </div>
    )
}
