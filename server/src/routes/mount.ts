import { Express } from 'express';
import { createApiV1 } from './apiV1';
import { createStatsV1 } from './statsV1';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';

// THE '/api/v1' MOUNTS, IN THE ORDER THEY MUST BE REGISTERED.
//
// ORDER IS LOAD-BEARING. Stats is mounted separately from createApiV1 (these boards need
// neither the engine nor the store, and are readable without the X-API-Key gate that guards
// player mutation) — but Express matches middleware by REGISTRATION order, not path
// specificity, and createApiV1's router.use(requireApiKey) runs unconditionally for every
// path under the '/api/v1' prefix, matched route or not. '/api/v1/stats' is itself prefixed
// by '/api/v1', so if the general mount were registered first, every stats request would hit
// requireApiKey and 503/401 before ever reaching the stats router. Stats MUST be mounted
// first so its more specific prefix is tried first.
//
// This lives in its own function so the mount-order test can BIND TO THE REAL THING rather
// than re-declaring the order in the test and proving only that the property is achievable.
// index.ts cannot be imported by a test — it connects to Mongo and listens at import time —
// so the order it depends on is extracted to here, where both callers share one definition.
export function mountRoutes(app: Express, engine: RoundEngine, store: ResultsStore): void {
    app.use('/api/v1/stats', createStatsV1());
    app.use('/api/v1', createApiV1(engine, store));
}
