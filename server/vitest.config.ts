import { defineConfig } from 'vitest/config';

export default defineConfig({
    test: {
        include: ['src/**/*.test.ts'],
        hookTimeout: 60000, // mongodb-memory-server first download/boot can be slow
        testTimeout: 20000,
    },
});
