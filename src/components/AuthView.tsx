import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, Mail, Lock, LogIn, Chrome, Cloud, Facebook, Instagram } from 'lucide-react'
import { cn } from '../lib/utils'

interface AuthViewProps {
    onBack: () => void
    onAuthSuccess: (token: string, user: any) => void
    initialMode?: 'LOGIN' | 'SIGNUP'
}

export const AuthView: React.FC<AuthViewProps> = ({ onBack, onAuthSuccess, initialMode = 'LOGIN' }) => {
    const [mode, setMode] = React.useState<'LOGIN' | 'SIGNUP'>(initialMode)
    const [email, setEmail] = React.useState('')
    const [password, setPassword] = React.useState('')
    const [displayName, setDisplayName] = React.useState('')
    const [loading, setLoading] = React.useState(false)
    const [error, setError] = React.useState<string | null>(null)

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        setError(null)

        try {
            const endpoint = mode === 'LOGIN' ? '/auth/login' : '/auth/register'
            const body = mode === 'LOGIN'
                ? { email, password }
                : { email, password, displayName, deviceId: localStorage.getItem('deviceId') }

            const response = await fetch(`${window.location.protocol}//${window.location.hostname}:3001${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            })

            const data = await response.json()
            if (!response.ok) throw new Error(data.message || 'Authentication failed')

            onAuthSuccess(data.token, data.user)
        } catch (err) {
            setError((err as Error).message)
        } finally {
            setLoading(false)
        }
    }

    const handleSSO = async (provider: string) => {
        // Simplified SSO mock for demonstration
        // In a real app, this would trigger the OAuth flow
        console.log(`Triggering SSO flow for ${provider}...`)
        setError(`SSO for ${provider} requires developer console configuration.`)
    }

    return (
        <motion.div
            initial={{ opacity: 0, scale: 1.05 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="fixed inset-0 z-[100] bg-slate-950 flex flex-col items-center overflow-y-auto py-12 px-6"
        >
            <div className="w-full max-w-md space-y-8">
                {/* Header */}
                <div className="flex flex-col items-center gap-2">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-1bg-blue-600 rounded-full" />
                        <h1 className="text-3xl font-black italic tracking-tighter text-white">ROSHAMBO</h1>
                        <div className="w-10 h-1bg-blue-600 rounded-full" />
                    </div>
                    <p className="text-[10px] font-black uppercase tracking-[0.4em] text-slate-500">Identity Protocol</p>
                </div>

                {/* Form Card */}
                <div className="glass-panel p-8 rounded-3xl border border-white/5 shadow-2xl relative overflow-hidden">
                    <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-blue-500 to-purple-500" />

                    {/* Mode Toggle */}
                    <div className="flex p-1 bg-slate-900 rounded-xl mb-8">
                        <button
                            onClick={() => setMode('LOGIN')}
                            className={cn(
                                "flex-1 py-2 text-[10px] font-black uppercase tracking-widest transition-all",
                                mode === 'LOGIN' ? "bg-white/10 text-white rounded-lg shadow-inner" : "text-slate-500"
                            )}
                        >
                            Login
                        </button>
                        <button
                            onClick={() => setMode('SIGNUP')}
                            className={cn(
                                "flex-1 py-2 text-[10px] font-black uppercase tracking-widest transition-all",
                                mode === 'SIGNUP' ? "bg-white/10 text-white rounded-lg shadow-inner" : "text-slate-500"
                            )}
                        >
                            Sign up
                        </button>
                    </div>

                    <form onSubmit={handleSubmit} className="space-y-4">
                        <AnimatePresence mode="wait">
                            {mode === 'SIGNUP' && (
                                <motion.div
                                    initial={{ height: 0, opacity: 0 }}
                                    animate={{ height: 'auto', opacity: 1 }}
                                    exit={{ height: 0, opacity: 0 }}
                                    className="overflow-hidden"
                                >
                                    <div className="relative">
                                        <LogIn className="absolute left-3 top-3.5 w-4 h-4 text-slate-500" />
                                        <input
                                            type="text"
                                            placeholder="DISPLAY NAME"
                                            value={displayName}
                                            onChange={(e) => setDisplayName(e.target.value)}
                                            className="w-full bg-slate-900 border border-white/5 rounded-xl py-3 pl-10 pr-4 text-sm font-bold uppercase tracking-widest focus:border-blue-500/50 outline-none transition-all"
                                            required={mode === 'SIGNUP'}
                                        />
                                    </div>
                                </motion.div>
                            )}
                        </AnimatePresence>

                        <div className="relative">
                            <Mail className="absolute left-3 top-3.5 w-4 h-4 text-slate-500" />
                            <input
                                type="email"
                                placeholder="EMAIL ADDRESS"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full bg-slate-900 border border-white/5 rounded-xl py-3 pl-10 pr-4 text-sm font-bold uppercase tracking-widest focus:border-blue-500/50 outline-none transition-all"
                                required
                            />
                        </div>

                        <div className="relative">
                            <Lock className="absolute left-3 top-3.5 w-4 h-4 text-slate-500" />
                            <input
                                type="password"
                                placeholder="PASSWORD"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                className="w-full bg-slate-900 border border-white/5 rounded-xl py-3 pl-10 pr-4 text-sm font-bold uppercase tracking-widest focus:border-blue-500/50 outline-none transition-all"
                                required
                            />
                        </div>

                        {error && (
                            <p className="text-red-500 text-[10px] font-black uppercase text-center mt-2">{error}</p>
                        )}

                        <button
                            disabled={loading}
                            className="w-full py-4 bg-blue-600 hover:bg-blue-500 rounded-xl font-black uppercase tracking-[0.3em] text-xs transition-all shadow-lg shadow-blue-500/20 active:scale-95 disabled:opacity-50"
                        >
                            {loading ? 'PROCESSING...' : mode === 'LOGIN' ? 'AUTHENTICATE' : 'INITIALIZE ACCOUNT'}
                        </button>
                    </form>

                    <div className="relative my-8">
                        <div className="absolute inset-0 flex items-center">
                            <div className="w-full border-t border-white/5"></div>
                        </div>
                        <div className="relative flex justify-center text-[10px] font-black uppercase tracking-[0.4em]">
                            <span className="px-4 bg-slate-950/20 backdrop-blur-xl text-slate-600">SSO UNLOCKS</span>
                        </div>
                    </div>

                    <div className="grid grid-cols-4 gap-3">
                        <SSOButton icon={<Chrome className="w-5 h-5 text-red-500" />} onClick={() => handleSSO('google')} />
                        <SSOButton icon={<Cloud className="w-5 h-5 text-white" />} onClick={() => handleSSO('apple')} />
                        <SSOButton icon={<Facebook className="w-5 h-5 text-blue-500" />} onClick={() => handleSSO('facebook')} />
                        <SSOButton icon={<Instagram className="w-5 h-5 text-pink-500" />} onClick={() => handleSSO('instagram')} />
                    </div>
                </div>

                <button
                    onClick={onBack}
                    className="flex items-center gap-2 text-slate-500 hover:text-white transition-all mx-auto text-[10px] font-black uppercase tracking-[0.2em]"
                >
                    <ArrowLeft className="w-4 h-4" />
                    Continue as Guest
                </button>
            </div>
        </motion.div>
    )
}

function SSOButton({ icon, onClick }: { icon: React.ReactNode, onClick: () => void }) {
    return (
        <button
            onClick={onClick}
            className="flex items-center justify-center py-3 bg-slate-900 hover:bg-slate-800 border border-white/5 rounded-xl transition-all hover:scale-105 active:scale-95"
        >
            {icon}
        </button>
    )
}
