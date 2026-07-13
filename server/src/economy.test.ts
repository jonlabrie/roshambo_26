import { describe, it, expect } from 'vitest';
import { validatePurchase, applyPurchase, PRICES, EconomyState } from './economy';

const fresh = (over: Partial<EconomyState> = {}): EconomyState =>
    ({ totalPoints: 100000, maxDeckSize: null, teahouseSizes: [], ...over });

describe('validatePurchase — decks (linear ladder)', () => {
    it('gateway deck:S needs no deck and deducts its price', () => {
        expect(validatePurchase(fresh(), 'deck:S')).toEqual({ ok: true, cost: PRICES.deck.S });
    });
    it('rejects deck:S when a deck is already owned', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:S')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
    });
    it('rejects deck:M without S, accepts deck:M with S', () => {
        expect(validatePurchase(fresh(), 'deck:M').ok).toBe(false);
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:M')).toEqual({ ok: true, cost: PRICES.deck.M });
    });
    it('rejects deck:L skipping M', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:L')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
    });
});

describe('validatePurchase — teahouses (linear + deck gate)', () => {
    it('teahouse:S needs an S+ deck', () => {
        expect(validatePurchase(fresh(), 'teahouse:S')).toEqual({ ok: false, error: 'DECK_TOO_SMALL' });
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'teahouse:S')).toEqual({ ok: true, cost: PRICES.teahouse.S });
    });
    it('teahouse:M needs teahouse:S AND an M+ deck', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'M', teahouseSizes: [] }), 'teahouse:M')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
        expect(validatePurchase(fresh({ maxDeckSize: 'S', teahouseSizes: ['S'] }), 'teahouse:M')).toEqual({ ok: false, error: 'DECK_TOO_SMALL' });
        expect(validatePurchase(fresh({ maxDeckSize: 'M', teahouseSizes: ['S'] }), 'teahouse:M')).toEqual({ ok: true, cost: PRICES.teahouse.M });
    });
    it('rejects re-buying an owned teahouse size', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'M', teahouseSizes: ['S', 'M'] }), 'teahouse:M')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
    });
});

describe('validatePurchase — money + bad input', () => {
    it('rejects when unaffordable', () => {
        expect(validatePurchase(fresh({ totalPoints: 0 }), 'deck:S')).toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
    });
    it('rejects an unknown item id', () => {
        expect(validatePurchase(fresh(), 'deck:XL')).toEqual({ ok: false, error: 'BAD_ITEM' });
        expect(validatePurchase(fresh(), 'garden:S')).toEqual({ ok: false, error: 'BAD_ITEM' });
    });
});

describe('applyPurchase', () => {
    it('grants a deck tier and deducts points', () => {
        const s = applyPurchase(fresh({ totalPoints: 1000, maxDeckSize: 'S' }), 'deck:M');
        expect(s.maxDeckSize).toBe('M');
        expect(s.totalPoints).toBe(1000 - PRICES.deck.M);
    });
    it('grants a teahouse size (appended) and deducts points', () => {
        const s = applyPurchase(fresh({ totalPoints: 1000, maxDeckSize: 'M', teahouseSizes: ['S'] }), 'teahouse:M');
        expect(s.teahouseSizes).toEqual(['S', 'M']);
        expect(s.totalPoints).toBe(1000 - PRICES.teahouse.M);
    });
});
