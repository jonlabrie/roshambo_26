import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import mongoose from 'mongoose';
import { connectTestDb, disconnectTestDb } from './db';

describe('test harness', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);

    it('connects to in-memory mongo', () => {
        expect(mongoose.connection.readyState).toBe(1);
    });
});
