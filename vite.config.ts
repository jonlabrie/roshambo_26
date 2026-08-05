import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    test: {
        // SCOPED TO `src/`, and this is load-bearing. `server/` is a SEPARATE codebase with its own
        // package.json and its own vitest, and its suite boots a MongoDB memory server. Left
        // unscoped, `vitest run` from the repo root discovers those files too and fails eight test
        // files that are perfectly healthy under `cd server && npm test`.
        include: ['src/**/*.test.ts'],
    },
})
