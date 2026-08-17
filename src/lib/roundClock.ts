// THE PWA'S ROUND CLOCK — pure, so it can be tested without a socket.
//
// WHY THIS EXISTS (owner, 2026-08-17: "the PWA and the Roblox place are on different clocks").
// The Roblox client has always been handed an ABSOLUTE phase boundary and slews against it
// (RoundScheduleConfig -> RoundMetronome). The PWA got only `timeLeft`: an integer decremented
// once per server tick, with no timestamp to correct client drift against. Even pointed at the
// same backend the two read differently, because one derived from a deadline and the other from
// a counter that the network could delay.
//
// The server now publishes `phaseEndsAtMs` and `serverTimeMs` together on `init` and `sync`.
// They travel as a pair on purpose: an absolute deadline is useless to a client that disagrees
// about what time it is, and browser clocks are routinely minutes off. The offset between them
// is what makes the deadline usable.

// Smoothing on the offset. Every `sync` gives a fresh sample whose error is the one-way network
// delay, which is noisy; adopting each sample raw would make the countdown twitch. 0.2 settles
// within a few seconds of joining and damps a lone slow packet to a fifth of its error.
export const DEFAULT_ALPHA = 0.2

/**
 * Fold a new (serverTimeMs - localNowMs) sample into the running offset.
 * The first sample is adopted whole: there is nothing to blend with, and a client that
 * has just joined needs a usable clock immediately rather than one that eases into place.
 */
export function blendOffset(previous: number | null, sampleMs: number, alpha = DEFAULT_ALPHA): number {
    if (previous === null) return sampleMs
    return previous + (sampleMs - previous) * alpha
}

/**
 * Whole seconds remaining until an absolute server deadline, as the client should display it.
 * Rounds UP so a partial second still reads as that second — a countdown that shows 0 while
 * a second of play remains is worse than one that shows 1 for a fraction too long.
 */
export function secondsLeftAt(phaseEndsAtMs: number, offsetMs: number, localNowMs: number): number {
    const remainingMs = phaseEndsAtMs - (localNowMs + offsetMs)
    if (remainingMs <= 0) return 0
    return Math.ceil(remainingMs / 1000)
}
