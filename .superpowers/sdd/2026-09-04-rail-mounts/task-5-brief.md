### Task 5: FireworkController — flight along the heading

**Files:**
- Modify: `roblox/src/client/FireworkController.client.luau`

**Interfaces:**
- Consumes: `payload.heading` (Task 4), the existing flight code: `apex = origin + Vector3.new(rng(-8,8), 60 + rng(-6,6), rng(-8,8))` (~line 353), bezier `control = origin + Vector3.new(0, (apex.Y - origin.Y) * 0.9, 0)` (~line 433), bonus `apex = origin + (apex - origin) * Vector3.new(1, BONUS.apexScale, 1)` (~line 375).
- Produces: the generalized flight later shells inherit for free.

Behavior contract (exact formulas — generalize, do not fork):

1. `local dir = if payload.heading then Vector3.new(payload.heading.x, payload.heading.y, payload.heading.z).Unit else Vector3.new(0, 1, 0)` — computed once beside `origin`.
2. Apex: `apex = origin + dir * (60 + rng:NextNumber(-6, 6)) + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))` — same scatter magnitudes, axis-aligned run replaced by the heading run. With `dir = (0,1,0)` this is EXACTLY the current expression (same rng draw ORDER matters for cross-client determinism: keep the draws in the current order — height jitter first or lateral first, whichever the current code does — state it in the report).
3. Bonus: `apex = origin + (apex - origin) + dir * ((apex - origin):Dot(dir) * (BurstStyles.BONUS.apexScale - 1))` — stretches the along-heading component by apexScale, leaves scatter alone. With vertical dir this reproduces the old Y-scaling to within the scatter's tiny contribution; state the equivalence check in the report.
4. Bezier control: `local run = (apex - origin):Dot(dir)` then `control = origin + dir * (run * 0.9)` — with vertical dir this is byte-equivalent to the current vertical control.
5. Everything else (sound timing, muzzle flash at `origin`, trail, LOD) unchanged — they key off `origin` and the bezier, which is the point.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/FireworkController.client.luau
git commit -m "feat(fireworks): the arc follows the heading -- vertical stays the nil default"
```

---

