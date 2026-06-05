import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongod: MongoMemoryServer | undefined;

export async function connectTestDb(): Promise<void> {
    mongod = await MongoMemoryServer.create({
        instance: { startupTimeout: 60000 },
    });
    await mongoose.connect(mongod.getUri());
}

export async function clearTestDb(): Promise<void> {
    const collections = await mongoose.connection.db!.collections();
    for (const c of collections) await c.deleteMany({});
}

export async function disconnectTestDb(): Promise<void> {
    await mongoose.disconnect();
    if (mongod) await mongod.stop();
}
