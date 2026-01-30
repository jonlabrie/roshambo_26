import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, ShoppingBag, Check, User, Wallet } from 'lucide-react'
import { cn } from '../lib/utils'

interface StoreViewProps {
    onBack: () => void
    catalog: any[]
    inventory: string[]
    equippedId: string
    totalPoints: number
    onPurchase: (id: string) => Promise<{ success: boolean; message?: string }>
    onEquip: (id: string) => Promise<{ success: boolean; message?: string }>
    isGuest: boolean
    onLoginRequest: () => void
}

export const StoreView: React.FC<StoreViewProps> = ({
    onBack,
    catalog,
    inventory,
    equippedId,
    totalPoints,
    onPurchase,
    onEquip,
    isGuest,
    onLoginRequest
}) => {
    const [selectedId, setSelectedId] = React.useState<string | null>(null)
    const [status, setStatus] = React.useState<{ type: 'success' | 'error', message: string } | null>(null)

    const selectedChar = catalog.find(c => c.id === (selectedId || equippedId))

    const handleAction = async () => {
        if (!selectedChar) return
        if (isGuest) {
            onLoginRequest()
            return
        }

        const isOwned = inventory.includes(selectedChar.id)
        if (isOwned) {
            const res = await onEquip(selectedChar.id)
            if (res.success) {
                setStatus({ type: 'success', message: 'Themed equipped!' })
            } else {
                setStatus({ type: 'error', message: res.message || 'Equip failed' })
            }
        } else {
            const res = await onPurchase(selectedChar.id)
            if (res.success) {
                setStatus({ type: 'success', message: 'Themed unlocked!' })
            } else {
                setStatus({ type: 'error', message: res.message || 'Purchase failed' })
            }
        }

        setTimeout(() => setStatus(null), 3000)
    }

    return (
        <motion.div
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -50 }}
            className="fixed inset-0 z-[100] bg-slate-950 flex flex-col"
        >
            {/* Header */}
            <header className="p-6 pt-[calc(1.5rem+env(safe-area-inset-top))] border-b border-white/5 flex items-center justify-between">
                <button onClick={onBack} className="p-2 hover:bg-white/5 rounded-xl transition-all">
                    <ArrowLeft className="w-5 h-5 text-slate-400" />
                </button>
                <div className="flex flex-col items-center">
                    <span className="text-[10px] font-black uppercase tracking-[0.4em] text-blue-500">The Emporium</span>
                    <h1 className="text-xl font-black italic tracking-tighter">CHARACTER SHOP</h1>
                </div>
                <div className="flex items-center gap-2 px-3 py-1.5 bg-slate-900 rounded-full border border-white/5">
                    <Wallet className="w-3 h-3 text-yellow-500" />
                    <span className="text-xs font-black tabular-nums">{totalPoints.toLocaleString()}</span>
                </div>
            </header>

            <main className="flex-1 overflow-y-auto flex flex-col md:flex-row pb-10">
                {/* Catalog Grid */}
                <div className="flex-1 md:overflow-y-auto p-4 md:p-8 space-y-6 shrink-0">
                    <div className="grid grid-cols-1 gap-4">
                        {catalog.map((char) => {
                            const isOwned = inventory.includes(char.id)
                            const isEquipped = equippedId === char.id
                            const isSelected = selectedId === char.id || (!selectedId && equippedId === char.id)

                            return (
                                <button
                                    key={char.id}
                                    onClick={() => setSelectedId(char.id)}
                                    className={cn(
                                        "group relative flex items-center gap-6 p-4 rounded-3xl border transition-all duration-300",
                                        isSelected
                                            ? "bg-white/5 border-blue-500/50 shadow-lg shadow-blue-500/10"
                                            : "bg-slate-900/50 border-white/5 hover:border-white/10"
                                    )}
                                >
                                    <div
                                        className="w-16 h-16 rounded-2xl flex items-center justify-center relative overflow-hidden shrink-0"
                                        style={{ backgroundColor: `${char.lite.primaryColor}22` }}
                                    >
                                        <div
                                            className="absolute inset-0 blur-xl opacity-50"
                                            style={{ backgroundColor: char.lite.primaryColor }}
                                        />
                                        <User className="w-8 h-8 relative z-10" style={{ color: char.lite.primaryColor }} />
                                    </div>

                                    <div className="flex-1 flex flex-col items-start gap-1">
                                        <div className="flex items-baseline gap-2">
                                            <h3 className="font-black italic text-lg">{char.name}</h3>
                                            {isEquipped && <span className="text-[8px] font-black uppercase tracking-widest text-blue-500">Equipped</span>}
                                        </div>
                                        <p className="text-[10px] text-slate-500 font-medium line-clamp-1">{char.description}</p>
                                    </div>

                                    <div className="flex flex-col items-end gap-1">
                                        {isOwned ? (
                                            <div className="w-8 h-8 rounded-full bg-green-500/20 flex items-center justify-center">
                                                <Check className="w-4 h-4 text-green-500" />
                                            </div>
                                        ) : (
                                            <div className="flex items-center gap-1.5 px-3 py-1 bg-slate-800 rounded-lg border border-white/5">
                                                <span className="text-[10px] font-black tabular-nums">{char.price}</span>
                                                <div className="w-1.5 h-1.5 rounded-full bg-yellow-500" />
                                            </div>
                                        )}
                                    </div>
                                </button>
                            )
                        })}
                    </div>
                </div>

                {/* Preview / Detail Panel */}
                <div className="w-full md:w-96 bg-slate-900/30 border-l border-white/5 p-8 flex flex-col gap-8 shrink-0">
                    {selectedChar && (
                        <AnimatePresence mode="wait">
                            <motion.div
                                key={selectedChar.id}
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, scale: 0.95 }}
                                className="flex-1 flex flex-col"
                            >
                                {/* Preview Card */}
                                <div className="aspect-square rounded-3xl bg-slate-900 border border-white/5 relative overflow-hidden mb-8 shadow-2xl">
                                    <div
                                        className="absolute inset-0 opacity-20 blur-3xl animate-pulse"
                                        style={{ backgroundColor: selectedChar.lite.primaryColor }}
                                    />
                                    <div className="absolute inset-0 flex items-center justify-center p-12">
                                        {/* Mock Arena Preview */}
                                        <div className="w-full h-full rounded-2xl border-2 border-dashed border-white/10 flex items-center justify-center relative">
                                            <div
                                                className="w-20 h-20 rounded-full blur-2xl animate-ping"
                                                style={{ backgroundColor: selectedChar.lite.primaryColor, opacity: 0.2 }}
                                            />
                                            <div
                                                className="w-24 h-24 rounded-full flex items-center justify-center border-4"
                                                style={{ borderColor: selectedChar.lite.primaryColor, color: selectedChar.lite.primaryColor }}
                                            >
                                                <User className="w-12 h-12" />
                                            </div>
                                        </div>
                                    </div>
                                    <div className="absolute bottom-4 left-0 right-0 text-center">
                                        <span className="text-[8px] font-black uppercase tracking-[0.4em] text-slate-500">Live Preview</span>
                                    </div>
                                </div>

                                <div className="space-y-4">
                                    <div className="space-y-1">
                                        <h2 className="text-2xl font-black italic tracking-tight">{selectedChar.name}</h2>
                                        <p className="text-xs text-slate-400 leading-relaxed font-medium">{selectedChar.description}</p>
                                    </div>

                                    {status && (
                                        <motion.div
                                            initial={{ opacity: 0, height: 0 }}
                                            animate={{ opacity: 1, height: 'auto' }}
                                            className={cn(
                                                "p-3 rounded-xl border text-[10px] font-black uppercase text-center",
                                                status.type === 'success' ? "bg-green-500/10 border-green-500/30 text-green-500" : "bg-red-500/10 border-red-500/30 text-red-500"
                                            )}
                                        >
                                            {status.message}
                                        </motion.div>
                                    )}

                                    <button
                                        onClick={handleAction}
                                        disabled={equippedId === selectedChar.id}
                                        className={cn(
                                            "w-full py-5 rounded-2xl font-black uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-3",
                                            inventory.includes(selectedChar.id)
                                                ? (equippedId === selectedChar.id ? "bg-slate-800 text-slate-500 cursor-default" : "bg-white text-black hover:scale-[1.02] active:scale-95")
                                                : (totalPoints >= selectedChar.price ? "bg-blue-600 hover:bg-blue-500 shadow-xl shadow-blue-500/20 active:scale-95" : "bg-slate-800 text-slate-500 opacity-50")
                                        )}
                                    >
                                        {inventory.includes(selectedChar.id) ? (
                                            equippedId === selectedChar.id ? 'Equipped' : 'Equip Character'
                                        ) : (
                                            <>
                                                <ShoppingBag className="w-4 h-4" />
                                                Redeem for {selectedChar.price} pts
                                            </>
                                        )}
                                    </button>

                                    {!inventory.includes(selectedChar.id) && totalPoints < selectedChar.price && (
                                        <p className="text-[9px] font-black uppercase tracking-widest text-center text-red-500/70">
                                            Need {(selectedChar.price - totalPoints).toLocaleString()} more points
                                        </p>
                                    )}
                                </div>
                            </motion.div>
                        </AnimatePresence>
                    )}
                </div>
            </main>
        </motion.div>
    )
}
