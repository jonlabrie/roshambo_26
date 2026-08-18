import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import authRouter from './auth';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'roshambo_super_secret_1337';
const deviceTokenFor = (did: string) => jwt.sign({ typ: 'device', did }, JWT_SECRET);

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

    it('register with an unknown device stamps identityTier email', async () => {
        await request(app).post('/auth/register')
            .send({ email: 'b@b.c', password: 'pw123456', displayName: 'B', deviceToken: deviceTokenFor('noSuchDevice') })
            .expect(201);
        const u = await User.findOne({ email: 'b@b.c' });
        expect(u?.identityTier).toBe('email');
    });

    it('register migrating an anonymous device stamps identityTier email', async () => {
        await User.create({ deviceId: 'devA' });
        await request(app).post('/auth/register')
            .send({ email: 'c@b.c', password: 'pw123456', displayName: 'C', deviceToken: deviceTokenFor('devA') })
            .expect(201);
        const u = await User.findOne({ email: 'c@b.c' });
        expect(u?.identityTier).toBe('email');
    });

    // ===== the REST half of the deviceId-as-password hole (2026-08-18) =====
    // The socket path stopped taking identity from payloads; this route was still taking a
    // bare `deviceId` and handing over whatever guest owned it — points, streaks and all —
    // to anyone who could type it into a registration form. The device must PROVE itself
    // here too, with the same signed token the socket handshake carries.
    it('a bare deviceId no longer claims a guest account', async () => {
        const guest = await User.create({ deviceId: 'devVictim', totalPoints: 700 });
        await request(app).post('/auth/register')
            .send({ email: 'thief@b.c', password: 'pw123456', displayName: 'T', deviceId: 'devVictim' })
            .expect(201);
        const thief = await User.findOne({ email: 'thief@b.c' });
        expect(thief!._id.toString()).not.toBe(guest._id.toString()); // a fresh account, not theirs
        const stillTheirs = await User.findById(guest._id);
        expect(stillTheirs!.totalPoints).toBe(700);
        expect(stillTheirs!.deviceId).toBe('devVictim'); // untouched, still theirs to claim
    });

    it('a forged device token claims nothing either', async () => {
        const guest = await User.create({ deviceId: 'devVictim2', totalPoints: 400 });
        const forged = jwt.sign({ typ: 'device', did: 'devVictim2' }, 'not-the-secret');
        await request(app).post('/auth/register')
            .send({ email: 'forger@b.c', password: 'pw123456', displayName: 'F', deviceToken: forged })
            .expect(201);
        const stillTheirs = await User.findById(guest._id);
        expect(stillTheirs!.totalPoints).toBe(400);
        expect(stillTheirs!.deviceId).toBe('devVictim2');
    });

    it('a real device token brings that guest\'s progress into the account', async () => {
        const guest = await User.create({ deviceId: 'devMine', totalPoints: 250, bestStreak: 4 });
        await request(app).post('/auth/register')
            .send({ email: 'mine@b.c', password: 'pw123456', displayName: 'M', deviceToken: deviceTokenFor('devMine') })
            .expect(201);
        const account = await User.findOne({ email: 'mine@b.c' });
        expect(account!._id.toString()).toBe(guest._id.toString()); // the SAME record, promoted
        expect(account!.totalPoints).toBe(250);
        expect(account!.bestStreak).toBe(4);
        expect(account!.deviceId).toBeUndefined(); // no longer reachable as a guest
    });
});
