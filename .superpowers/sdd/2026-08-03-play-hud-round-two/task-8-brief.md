### Task 8: `resultSplash`, the second preference

**Files:** Modify `server/src/models/User.ts`, `server/src/routes/apiV1.ts`,
`server/src/routes/apiV1.test.ts`, `roblox/src/server/main.server.luau`,
`roblox/src/client/main.client.luau`, `roblox/src/client/LedgerController.client.luau`,
`roblox/src/client/SplashController.client.luau`.

**This is the mirror of Task 14 on the previous branch, which retired `confirmThrows`.** Read that
task's diff (`git log --oneline --all -- server/src/routes/apiV1.ts`) and follow the same seams —
they are the same five files plus the Roblox server's `HudPrefs`, which that task's brief missed
and its implementer had to find.

- [ ] **Step 1: Failing server test**

In `server/src/routes/apiV1.test.ts`, reusing the file's existing scaffolding: `PUT
/players/:id/preferences-hud` accepts and persists `resultSplash`, and `buildProfilePayload`
ships it, defaulting **true**.

- [ ] **Step 2: Run, confirm failure, implement**

`User.ts` gains `resultSplash: { type: Boolean, default: true }`. `apiV1.ts` accepts it in the PUT
and emits it from `buildProfilePayload`.

- [ ] **Step 3: The Roblox server**

`HudPrefs`, `prefsFor`, `prefsFromProfile`, the `fireProfile` payload and the `SetHudPreference`
handler all carry `resultSplash` beside `escalationPrompts`. **Every producer must emit both keys
and every consumer read both** — a partial preferences object is how one switch ends up
resetting the other.

- [ ] **Step 4: The client**

`main.client.luau` holds `resultSplash`, applies it locally on `EventBus.HudPreference` and from
`ProfileUpdate`, and includes it in `publishLedger`. `LedgerController` gains the second switch —
the footer's two-column layout was built for exactly this, so restore the `column` argument that
Task 14 removed when it dropped to one occupant. `SplashController` reads it from the same
`LedgerState` channel and simply does not show when it is off.

- [ ] **Step 5: Verify and commit**

Both suites. Confirm both switches round-trip independently: toggle one, confirm the other's value
survives the echo. Trace it and say so.

```bash
git commit -am "feat: the result splash is a preference, not a fixture"
```

---

