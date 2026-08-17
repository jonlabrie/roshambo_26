import { describe, it, expect } from 'vitest'
import { blendOffset, secondsLeftAt, DEFAULT_ALPHA } from './roundClock'

describe('blendOffset', () => {
    it('seeds from the first sample, because there is nothing to blend with', () => {
        expect(blendOffset(null, 4000)).toBe(4000)
    })

    it('eases toward later samples so network jitter does not jerk the countdown', () => {
        const first = blendOffset(null, 4000)
        const jittered = blendOffset(first, 4100)
        expect(jittered).toBeGreaterThan(4000)
        expect(jittered).toBeLessThan(4100)
        expect(jittered).toBeCloseTo(4000 + 100 * DEFAULT_ALPHA, 6)
    })

    it('converges on a sustained shift rather than chasing or ignoring it', () => {
        let o = blendOffset(null, 0)
        for (let i = 0; i < 60; i++) o = blendOffset(o, 5000)
        expect(o).toBeGreaterThan(4990)
    })
})

describe('secondsLeftAt', () => {
    // THE POINT OF THE OFFSET. A browser clock can be minutes off; subtracting a raw
    // Date.now() from a server deadline would then read wildly wrong. The offset is what
    // makes an absolute server timestamp usable on a client that disagrees about now.
    it('is correct even when the local clock is minutes wrong', () => {
        const serverNow = 1_000_000
        const localNow = serverNow - 300_000 // browser five minutes slow
        const offset = blendOffset(null, serverNow - localNow)
        expect(secondsLeftAt(serverNow + 12_000, offset, localNow)).toBe(12)
    })

    it('rounds up, so a partial second still reads as that second', () => {
        expect(secondsLeftAt(10_400, 0, 0)).toBe(11)
        expect(secondsLeftAt(10_000, 0, 0)).toBe(10)
    })

    it('never goes negative once the deadline passes', () => {
        expect(secondsLeftAt(1000, 0, 9000)).toBe(0)
    })

    it('reads zero exactly at the boundary', () => {
        expect(secondsLeftAt(5000, 0, 5000)).toBe(0)
    })
})
