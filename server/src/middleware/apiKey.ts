import { Request, Response, NextFunction } from 'express';

export function requireApiKey(req: Request, res: Response, next: NextFunction): void {
    const configured = process.env.API_KEY;
    if (!configured) {
        res.status(503).json({ error: 'API_NOT_CONFIGURED' });
        return;
    }
    if (req.header('X-API-Key') !== configured) {
        res.status(401).json({ error: 'UNAUTHORIZED' });
        return;
    }
    next();
}
