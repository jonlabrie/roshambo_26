import express from 'express';
import jwt from 'jsonwebtoken';
import User from '../models/User';
import { CHARACTER_CATALOG } from '../constants/characters';

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'roshambo_super_secret_1337';

// Middleware to protect routes and get user
const auth = async (req: any, res: any, next: any) => {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ message: 'Authentication required' });

    try {
        const decoded = jwt.verify(token, JWT_SECRET) as any;
        const user = await User.findById(decoded.id);
        if (!user) throw new Error();
        req.user = user;
        next();
    } catch (e) {
        res.status(401).json({ message: 'Invalid token' });
    }
};

// Get Catalog
router.get('/catalog', (req, res) => {
    res.json(CHARACTER_CATALOG);
});

// Purchase Character
router.post('/purchase', auth, async (req: any, res: any) => {
    try {
        const { characterId } = req.body;
        const character = CHARACTER_CATALOG.find(c => c.id === characterId);

        if (!character) {
            return res.status(404).json({ message: 'Character not found' });
        }

        if (req.user.inventory.includes(characterId)) {
            return res.status(400).json({ message: 'Already owned' });
        }

        if (req.user.totalPoints < character.price) {
            return res.status(400).json({ message: 'Insufficient Bank balance' });
        }

        // Deduct price and add to inventory
        req.user.totalPoints -= character.price;
        req.user.inventory.push(characterId);
        await req.user.save();

        res.json({
            message: 'Purchase successful',
            inventory: req.user.inventory,
            totalPoints: req.user.totalPoints
        });
    } catch (err) {
        res.status(500).json({ message: (err as Error).message });
    }
});

// Equip Character
router.post('/equip', auth, async (req: any, res: any) => {
    try {
        const { characterId } = req.body;

        if (!req.user.inventory.includes(characterId)) {
            return res.status(400).json({ message: 'You do not own this character' });
        }

        req.user.equippedCharacterId = characterId;
        await req.user.save();

        res.json({
            message: 'Character equipped',
            equippedCharacterId: req.user.equippedCharacterId
        });
    } catch (err) {
        res.status(500).json({ message: (err as Error).message });
    }
});

export default router;
