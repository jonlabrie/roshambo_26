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

// Register
router.post('/register', async (req, res) => {
    try {
        const { email, password, displayName, deviceId } = req.body;

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
                user.deviceId = undefined; // No longer anonymous
                await user.save();
            } else {
                user = new User({ email, password: hashedPassword, displayName });
                await user.save();
            }
        } else {
            user = new User({ email, password: hashedPassword, displayName });
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
        const { provider, providerId, email, displayName, deviceId } = req.body;

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
                user.deviceId = undefined;
                await user.save();
            } else {
                // Create new SSO user
                user = new User({
                    ...query,
                    email,
                    displayName,
                    totalPoints: 0
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
