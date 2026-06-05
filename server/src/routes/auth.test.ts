import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import authRouter from './auth';

const app = express();
app.use(express.json());
app.use('/auth', authRouter);

describe('auth identity tiers', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('register without deviceId stamps identityTier email', async () => {
        await request(app).post('/auth/register')
            .send({ email: 'a@b.c', password: 'pw123456', displayName: 'A' })
            .expect(201);
        const u = await User.findOne({ email: 'a@b.c' });
        expect(u?.identityTier).toBe('email');
    });

    it('register with unknown deviceId stamps identityTier email', async () => {
        await request(app).post('/auth/register')
            .send({ email: 'b@b.c', password: 'pw123456', displayName: 'B', deviceId: 'noSuchDevice' })
            .expect(201);
        const u = await User.findOne({ email: 'b@b.c' });
        expect(u?.identityTier).toBe('email');
    });

    it('register migrating an anonymous device stamps identityTier email', async () => {
        await User.create({ deviceId: 'devA' });
        await request(app).post('/auth/register')
            .send({ email: 'c@b.c', password: 'pw123456', displayName: 'C', deviceId: 'devA' })
            .expect(201);
        const u = await User.findOne({ email: 'c@b.c' });
        expect(u?.identityTier).toBe('email');
    });
});
