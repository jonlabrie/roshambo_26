### Task 7: `NetworkClient.postPowderTopup` and `postFireworkMelt`

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau` (after `postShowReserve`)
- Test: `roblox/tests/NetworkClient.spec.luau`

**Interfaces:**
- `NetworkClient.postPowderTopup(self, robloxUserId: string, points: number): Result` → `POST /api/v1/players/{id}/powder/topup { points }`
- `NetworkClient.postFireworkMelt(self, robloxUserId: string, shellId: string, count: number): Result` → `POST /api/v1/players/{id}/fireworks/melt { shellId, count }`

No caller yet (the shop's melt verb waits for the server-file split). These exist so that task is a client change only.

- [ ] **Step 1: Failing spec** — in the file's `makeDeps` style (see the `postShowReserve` test added by sub-project B):

```lua
describe("NetworkClient powder calls", function()
    test("postPowderTopup POSTs { points }", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"powder":4,"totalPoints":6}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postPowderTopup("77", 4)
        expect(res.ok).toBe(true)
        expect(res.data.powder).toBe(4)
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/77/powder/topup")
        expect(serde.decode("json", f.calls[1].body :: string).points).toBe(4)
    end)
    test("postFireworkMelt POSTs { shellId, count }", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"shellId":"peony","count":1,"powder":6,"credited":6}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postFireworkMelt("77", "peony", 2)
        expect(res.ok).toBe(true)
        expect(f.calls[1].url).toBe("http://x/api/v1/players/77/fireworks/melt")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.shellId).toBe("peony")
        expect(sent.count).toBe(2)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails; implement:**

```lua
function NetworkClient.postPowderTopup(self: any, robloxUserId: string, points: number): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/powder/topup`, { points = points })
end

function NetworkClient.postFireworkMelt(self: any, robloxUserId: string, shellId: string, count: number): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/fireworks/melt`, { shellId = shellId, count = count })
end
```

- [ ] **Step 3: Gates** — `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(powder): NetworkClient.postPowderTopup and postFireworkMelt -- the shop's melt verb is a client change once the server split lands

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

