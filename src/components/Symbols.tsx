export const RockIcon = ({ className, style }: { className?: string; style?: React.CSSProperties }) => (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} style={style}>
        <circle cx="12" cy="12" r="8" stroke="white" strokeWidth="4.5" />
        <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="2.5" />
    </svg>
)

export const PaperIcon = ({ className, style }: { className?: string; style?: React.CSSProperties }) => (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} style={style}>
        <path d="M5 12H19" stroke="white" strokeWidth="5" strokeLinecap="round" />
        <path d="M5 12H19" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
    </svg>
)

export const ScissorsIcon = ({ className, style }: { className?: string; style?: React.CSSProperties }) => (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className={className} style={style}>
        <path d="M6 15L12 9L18 15" stroke="white" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M6 15L12 9L18 15" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
)

export const SymbolIcon = ({ type, className, style }: { type: 'R' | 'P' | 'S' | null | string, className?: string, style?: React.CSSProperties }) => {
    switch (type) {
        case 'R': return <RockIcon className={className} style={style} />
        case 'P': return <PaperIcon className={className} style={style} />
        case 'S': return <ScissorsIcon className={className} style={style} />
        default: return <span className={className} style={style}>?</span>
    }
}
