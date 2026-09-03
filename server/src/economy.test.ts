import { describe, it, expect } from 'vitest';
import {
  validatePurchase, applyPurchase, PRICES, EconomyState, validateDisplay,
  MAX_DECORATIONS, DECORATION_PROPS, nextDecorationId, appendDecoration, DeckDecoration,
  MAX_INVITED, ACCESS_MODES, DEFAULT_ACCESS,
} from './economy';

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

describe('validateDisplay', () => {
  const st = (over: Partial<EconomyState> = {}): EconomyState =>
    ({ totalPoints: 0, maxDeckSize: 'L', teahouseSizes: ['S', 'M', 'L'], ...over });

  it('accepts null/null (default = biggest owned)', () => {
    expect(validateDisplay(st(), null, null)).toEqual({ ok: true, deckDisplay: null, teahouseDisplay: null });
  });
  it('accepts a deck display <= owned and a teahouse display <= owned', () => {
    expect(validateDisplay(st(), 'M', 'S')).toEqual({ ok: true, deckDisplay: 'M', teahouseDisplay: 'S' });
  });
  it("accepts teahouse 'none'", () => {
    expect(validateDisplay(st(), 'S', 'none')).toEqual({ ok: true, deckDisplay: 'S', teahouseDisplay: 'none' });
  });
  it('rejects a deck display larger than owned', () => {
    expect(validateDisplay(st({ maxDeckSize: 'M' }), 'L', null)).toEqual({ ok: false, error: 'DISPLAY_UNOWNED' });
  });
  it('rejects a teahouse display larger than owned', () => {
    expect(validateDisplay(st({ teahouseSizes: ['S'] }), null, 'M')).toEqual({ ok: false, error: 'DISPLAY_UNOWNED' });
  });
  it("rejects 'none' for the deck", () => {
    expect(validateDisplay(st(), 'none' as unknown, null)).toEqual({ ok: false, error: 'BAD_DISPLAY' });
  });
  it('rejects garbage values', () => {
    expect(validateDisplay(st(), 'XL' as unknown, null)).toEqual({ ok: false, error: 'BAD_DISPLAY' });
    expect(validateDisplay(st(), null, 42 as unknown)).toEqual({ ok: false, error: 'BAD_DISPLAY' });
  });
  it('rejects a deck display when the player owns no deck', () => {
    expect(validateDisplay(st({ maxDeckSize: null }), 'S', null)).toEqual({ ok: false, error: 'DISPLAY_UNOWNED' });
  });
});

describe('portal purchase', () => {
  const base = (over: Partial<EconomyState> = {}): EconomyState =>
    ({ totalPoints: 1000, maxDeckSize: 'S', teahouseSizes: [], portalOwned: false, ...over });

  it('accepts a portal when a deck is owned and affordable', () => {
    expect(validatePurchase(base(), 'portal')).toEqual({ ok: true, cost: PRICES.portal });
  });
  it('rejects a portal with no deck', () => {
    expect(validatePurchase(base({ maxDeckSize: null }), 'portal')).toEqual({ ok: false, error: 'NEEDS_DECK' });
  });
  it('rejects a portal already owned', () => {
    expect(validatePurchase(base({ portalOwned: true }), 'portal')).toEqual({ ok: false, error: 'ALREADY_OWNED' });
  });
  it('rejects a portal when too poor', () => {
    expect(validatePurchase(base({ totalPoints: 0 }), 'portal')).toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
  });
  it('applyPurchase sets portalOwned and spends the cost', () => {
    const after = applyPurchase(base({ totalPoints: 700 }), 'portal');
    expect(after.portalOwned).toBe(true);
    expect(after.totalPoints).toBe(700 - PRICES.portal);
  });
});

describe('validatePurchase — decorations', () => {
    it('rejects a decoration when no deck is owned', () => {
        expect(validatePurchase(fresh(), 'decoration:bonsai')).toEqual({ ok: false, error: 'NEEDS_DECK' });
    });
    it('accepts a known decoration on a claimed deck and charges its price', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'decoration:bonsai'))
            .toEqual({ ok: true, cost: PRICES.decoration.bonsai });
    });
    it('rejects an unknown propId', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'decoration:dragon'))
            .toEqual({ ok: false, error: 'BAD_ITEM' });
    });
    it('rejects at the decoration cap', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S', deckDecorationCount: MAX_DECORATIONS }), 'decoration:bench'))
            .toEqual({ ok: false, error: 'DECOR_CAP' });
    });
    it('rejects when unaffordable', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S', totalPoints: 0 }), 'decoration:tsukubai'))
            .toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
    });
    it('DECORATION_PROPS holds exactly the four launch props', () => {
        expect([...DECORATION_PROPS].sort()).toEqual(['bench', 'bonsai', 'ishidoro', 'tsukubai']);
    });
});

describe('applyPurchase — decorations charge points only', () => {
    it('deducts the price and leaves tiers untouched', () => {
        const s = applyPurchase(fresh({ totalPoints: 1000, maxDeckSize: 'S' }), 'decoration:ishidoro');
        expect(s.totalPoints).toBe(1000 - PRICES.decoration.ishidoro);
        expect(s.maxDeckSize).toBe('S');
        expect(s.teahouseSizes).toEqual([]);
    });
});

describe('decoration id authority', () => {
    it('nextDecorationId starts at 1 on an empty list', () => {
        expect(nextDecorationId([])).toBe(1);
    });
    it('nextDecorationId is max(id)+1, robust to gaps', () => {
        const list: DeckDecoration[] = [
            { id: 3, propId: 'bench', offset: [0, 0], facing: 'N' },
            { id: 7, propId: 'bonsai', offset: [1, 2], facing: 'E' },
        ];
        expect(nextDecorationId(list)).toBe(8);
    });
    it('appendDecoration appends a centered N instance with the next id, without mutating input', () => {
        const list: DeckDecoration[] = [{ id: 5, propId: 'bench', offset: [1, 1], facing: 'S' }];
        const { list: next, instance } = appendDecoration(list, 'bonsai');
        expect(instance).toEqual({ id: 6, propId: 'bonsai', offset: [0, 0], facing: 'N' });
        expect(next).toHaveLength(2);
        expect(list).toHaveLength(1); // input untouched
    });
});

describe('access constants', () => {
    it('MAX_INVITED is 50', () => {
        expect(MAX_INVITED).toBe(50);
    });
    it('ACCESS_MODES holds exactly the three modes', () => {
        expect([...ACCESS_MODES].sort()).toEqual(['friends', 'private', 'public']);
    });
    it('DEFAULT_ACCESS is public with an empty list', () => {
        expect(DEFAULT_ACCESS).toEqual({ mode: 'public', invited: [] });
    });
});

describe('validatePurchase — the starter bundle', () => {
    it('starter needs no property and costs 20', () => {
        expect(validatePurchase(fresh(), 'starter')).toEqual({ ok: true, cost: PRICES.starter });
        expect(PRICES.starter).toBe(20);
    });
    it('rejects starter for anyone who already owns a deck', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'starter')).toEqual({ ok: false, error: 'ALREADY_OWNED' });
        expect(validatePurchase(fresh({ maxDeckSize: 'L' }), 'starter')).toEqual({ ok: false, error: 'ALREADY_OWNED' });
    });
    it('rejects starter when unaffordable', () => {
        expect(validatePurchase(fresh({ totalPoints: 19 }), 'starter')).toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
    });
    it('applyPurchase grants deck S + teahouse S atomically and deducts 20', () => {
        const next = applyPurchase(fresh({ totalPoints: 25 }), 'starter');
        expect(next.maxDeckSize).toBe('S');
        expect(next.teahouseSizes).toEqual(['S']);
        expect(next.totalPoints).toBe(5);
    });
    it('the ladder is untouched: an owner still upgrades at full price', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:M')).toEqual({ ok: true, cost: PRICES.deck.M });
    });
});
