import User, { IUser } from './models/User';

export interface Identifier {
    userId?: string;
    deviceId?: string;
    robloxUserId?: string;
}

export async function resolveUser(identifier: Identifier): Promise<IUser | null> {
    // 0. Roblox identity (server-to-server, highest trust)
    if (identifier.robloxUserId) {
        return User.findOneAndUpdate(
            { robloxId: identifier.robloxUserId },
            { $setOnInsert: { robloxId: identifier.robloxUserId, identityTier: 'roblox' } },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );
    }

    let user = null;

    // 1. Try Authenticated User First
    if (identifier.userId) {
        user = await User.findById(identifier.userId);
        if (user) {
            // Greedy Cleanup: If we also have a deviceId, ensure it's not tied to some other stale guest record
            if (identifier.deviceId) {
                const collisions = await User.find({
                    deviceId: identifier.deviceId,
                    _id: { $ne: user._id }
                });
                if (collisions.length > 0) {
                    console.log(`[SYNC-CLEANUP] Moving deviceId ${identifier.deviceId} from ${collisions.length} stale records to favor Auth User ${user._id}`);
                    try {
                        // Instead of $unset (which might collide on null if index not sparse), use a unique stale identifier
                        await Promise.all(collisions.map(c =>
                            User.findByIdAndUpdate(c._id, {
                                $set: { deviceId: `stale_${Date.now()}_${c._id}` }
                            })
                        ));
                    } catch (cleanupErr) {
                        console.error('[SYNC-CLEANUP-ERROR] Failed to dissociate stale records:', (cleanupErr as Error).message);
                    }
                }
            }
            return user;
        }
    }

    // 2. Fallback to Device ID (Guest)
    if (identifier.deviceId) {
        // Find all records claiming this deviceId, sorted by most recently updated
        const records = await User.find({ deviceId: identifier.deviceId }).sort({ updatedAt: -1 });

        if (records.length > 0) {
            user = records[0];
            // If there are multiple guest records, keep the most recent one as the device owner
            // and move the others to avoid "past state" confusion.
            if (records.length > 1) {
                console.warn(`[SYNC-COLLISION] Found ${records.length} records for device ${identifier.deviceId}. Picking most recent (${user._id}).`);
                try {
                    const others = records.slice(1);
                    await Promise.all(others.map(o =>
                        User.findByIdAndUpdate(o._id, {
                            $set: { deviceId: `stale_${Date.now()}_${o._id}` }
                        })
                    ));
                } catch (cleanupErr) {
                    console.error('[SYNC-COLLISION-ERROR] Failed to clean duplicates:', (cleanupErr as Error).message);
                }
            }
            return user;
        }

        // 3. Create new Guest if none exist
        const created = await User.findOneAndUpdate(
            { deviceId: identifier.deviceId },
            { $setOnInsert: { deviceId: identifier.deviceId } },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );
        return created;
    }

    return null;
}
