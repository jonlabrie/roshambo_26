### Task 11: Extract the takeover suspension

`LedgerController:74–150` is the only hardened movement-suspension in the codebase. The
teahouse needs it in Task 12, and a copy would duplicate the bug surface and let one panel
restore what the other suspended.

**Files:**
- Create: `roblox/src/client/Takeover.luau`
- Modify: `roblox/src/client/LedgerController.client.luau`

**Interfaces:**
- Produces: `Takeover.acquire()`, `Takeover.release()` — reference-counted; the freeze applies
  on 0→1 and lifts on 1→0.

- [ ] **Step 1: Create the module**

Move `LedgerController`'s `controls` resolution block, `suspendedVia`, `savedWalk`,
`currentHumanoid`, `setControlsEnabled`, `suspend` and `restore` verbatim into
`roblox/src/client/Takeover.luau`, changing the `[LEDGER]` log prefix to `[TAKEOVER]` and
wrapping them:

```luau
--!strict
-- Movement suspension for the takeover panels (the ledger and the teahouse).
--
-- WHY THIS IS A MODULE AND NOT A COPY IN EACH PANEL. What is below is hardened rather than
-- obvious: it prefers PlayerModule's control stack, falls back to WalkSpeed when that is
-- absent or refuses, and LATCHES which mechanism it used so a late-resolving PlayerModule
-- cannot restore a freeze the other path applied — which is what leaves someone at WalkSpeed 0
-- for good. A second copy would be a second place for that to go wrong, and with two panels
-- that hand off to each other it would also let one restore what the other suspended.
--
-- REFERENCE-COUNTED. The freeze applies on the first acquire and lifts on the last release, so
-- an ordering change (opening the teahouse before closing the ledger, rather than after) can
-- never thaw a player who is still inside a panel.
local Takeover = {}

local depth = 0

-- … moved code …

function Takeover.acquire()
    depth += 1
    if depth == 1 then
        suspend()
    end
end

function Takeover.release()
    if depth == 0 then
        return
    end
    depth -= 1
    if depth == 0 then
        restore()
    end
end

return Takeover
```

- [ ] **Step 2: Point the ledger at it**

In `LedgerController`, delete the moved code and add
`local Takeover = require(script.Parent:WaitForChild("Takeover"))` beside the `EventBus`
require. Replace the `suspend()` call in `open()` with `Takeover.acquire()` and the
`restore()` call in `close()` with `Takeover.release()`.

`close()` must stay idempotent — guard the release with the existing `isOpen` check so a
double close cannot drive the count negative (the module guards this too; both is deliberate).

- [ ] **Step 3: Confirm `default.project.json` needs no change**

`Takeover.luau` is a sibling of `EventBus.luau` inside the client folder, which the project
file maps as a directory. Verify:

```bash
grep -n "RoshamboClient" -A6 roblox/default.project.json
```
Expected: a `$path` pointing at `src/client`, so the new module is picked up with no edit.

- [ ] **Step 4: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "suspendedVia\|savedWalk\|setControlsEnabled" src/client/LedgerController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/Takeover.luau roblox/src/client/LedgerController.client.luau
git commit -m "refactor(roblox): one place knows how to give a player their legs back"
```

---

