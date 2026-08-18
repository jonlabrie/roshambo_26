import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User';

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'roshambo_super_secret_1337';

// Generate JWT
const generateToken = (userId: string) => {
    return jwt.sign({ id: userId }, JWT_SECRET, { expiresIn: '30d' });
};

// A guest's device, proved rather than asserted (2026-08-18). This route used to take a bare
// `deviceId` from the form body and hand over whatever guest owned it — points, streaks and all
// — to anyone who could type the string in. It is the same hole the socket handlers had, in the
// REST path, and it has to close the same way: the client presents the signed device token it
// was issued, and only a token this server signed identifies a device.
const deviceFromToken = (deviceToken: unknown): string | null => {
    if (typeof deviceToken !== 'string' || !deviceToken) return null;
    try {
        const d = jwt.verify(deviceToken, JWT_SECRET) as { typ?: string; did?: string };
        return d.typ === 'device' && d.did ? d.did : null;
    } catch {
        return null;
    }
};

// Register
router.post('/register', async (req, res) => {
    try {
        const { email, password, displayName } = req.body;
        // NOTE the asymmetry with what this used to accept: `req.body.deviceId` is ignored
        // outright. A caller that still sends one simply gets a fresh account.
        const deviceId = deviceFromToken(req.body.deviceToken);

        // Check if user exists
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'User already exists' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 12);

        // Create user
        // We also check if we can migrate from an anonymous deviceId
        let user;
        if (deviceId) {
            user = await User.findOne({ deviceId });
            if (user && !user.email) {
                // Migrate anonymous user
                user.email = email;
                user.password = hashedPassword;
                user.displayName = displayName;
                user.identityTier = 'email';
                user.set('deviceId', undefined); // Explicitly remove to prevent guest collisions
                await user.save();
                console.log(`[AUTH] Migrated anonymous device ${deviceId} to registered user ${user._id}`);
            } else {
                user = new User({ email, password: hashedPassword, displayName, identityTier: 'email' });
                await user.save();
            }
        } else {
            user = new User({ email, password: hashedPassword, displayName, identityTier: 'email' });
            await user.save();
        }

        const token = generateToken(user._id.toString());
        res.status(201).json({ token, user: { id: user._id, email: user.email, displayName: user.displayName, totalPoints: user.totalPoints } });
    } catch (err) {
        res.status(500).json({ message: (err as Error).message });
    }
});

// Login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        const user = await User.findOne({ email }).select('+password');
        if (!user || !user.password) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const token = generateToken(user._id.toString());
        res.json({ token, user: { id: user._id, email: user.email, displayName: user.displayName, totalPoints: user.totalPoints } });
    } catch (err) {
        res.status(500).json({ message: (err as Error).message });
    }
});

// Simplified SSO Login (accepts provider info and ID)
// Real implementation would verify the token from Google/Meta/Apple
router.post('/sso', async (req, res) => {
    try {
        const { provider, providerId, email, displayName } = req.body;
        // Same rule as /register: a device is identified by a token this server signed, never
        // by a string in the body. (This route is still the stubbed SSO the client has never
        // called — its provider assertion is unverified — but there is no reason to leave a
        // second copy of the closed hole lying in it.)
        const deviceId = deviceFromToken(req.body.deviceToken);

        const query: any = {};
        if (provider === 'google') query.googleId = providerId;
        else if (provider === 'apple') query.appleId = providerId;
        else if (provider === 'facebook') query.facebookId = providerId;
        else if (provider === 'instagram') query.instagramId = providerId;
        else return res.status(400).json({ message: 'Invalid provider' });

        let user = await User.findOne(query);

        if (!user) {
            // Check if we can migrate from anonymous or link if email exists
            if (email) {
                user = await User.findOne({ email });
            }

            if (!user && deviceId) {
                user = await User.findOne({ deviceId });
            }

            if (user) {
                // Update / Link existing user
                if (provider === 'google') user.googleId = providerId;
                else if (provider === 'apple') user.appleId = providerId;
                else if (provider === 'facebook') user.facebookId = providerId;
                else if (provider === 'instagram') user.instagramId = providerId;

                if (!user.displayName) user.displayName = displayName;
                if (!user.email) user.email = email;
                user.identityTier = 'email';
                user.set('deviceId', undefined); // Explicitly remove to prevent guest collisions
                await user.save();
                console.log(`[SSO] Merged/Linked device ${deviceId} to user ${user._id}`);
            } else {
                // Create new SSO user
                user = new User({
                    ...query,
                    email,
                    displayName,
                    totalPoints: 0,
                    identityTier: 'email'
                });
                await user.save();
            }
        }

        const token = generateToken(user._id.toString());
        res.json({ token, user: { id: user._id, email: user.email, displayName: user.displayName, totalPoints: user.totalPoints } });
    } catch (err) {
        res.status(500).json({ message: (err as Error).message });
    }
});

export default router;
