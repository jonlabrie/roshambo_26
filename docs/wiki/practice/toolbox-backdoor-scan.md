---
shelf: practice
updated: 2026-08-15
checked: 2026-08-31
---

# Toolbox Backdoor Scan

Standing rule: treat every free-toolbox / marketplace Roblox model as untrusted until
scanned. On 2026-07-08 the `VibrantNature` rock/foliage pack (2767 instances, staged
in the place) carried a **require-backdoor virus** — deleted whole; the place had never
been published so it never ran.

## The rule

**Why:** infected toolbox models are the #1 backdoor vector in Roblox, and this place
imports such packs.

**How to apply — scan any import before publishing** (runnable via Studio MCP
`execute_luau`): walk `GetDescendants()` for `LuaSourceContainer`s outside our Rojo
trees (`RoshamboShared`/`RoshamboClient`/`Roshambo`), and read `.Source` for tells.

**The backdoor's obfuscation (learn the shape, not just the strings):**

- Payload was ONE line — `require(script.X:GetAttribute("Version"))` — buried ~12
  levels deep in a `PalmTree` mesh, under fake-benign names (`CoreTextureSystem`,
  `TextureUtility`, `cTextureManager`), wrapped in ~200 lines of real-looking "light
  management" camouflage.
- The asset ID (`119562760813431`, signed `@ovenv3`) lived in an **Instance ATTRIBUTE,
  not the source** — so a naive `require%s*%(%s*%d` source-regex MISSES it.
  `require(<var>)` where the var resolves to an attribute/config value is the
  giveaway, not a literal number.
- `if RunService:IsStudio() then return end` — dormant in Studio (incl. Play-test),
  fires ONLY on a live published server. So it's invisible in dev; catch it BEFORE
  publishing.

**Scan for:** `require(` with a non-`script`/non-`game` argument (esp. reading an
attribute/config), `loadstring`, `getfenv`, `HttpService`/`HttpGet`/`GetAsync`,
`InsertService`/`GetObjects`, `:IsStudio()` early-returns, and author-signature
comments. A hit set of just an author handle (`ovenv`) already caught this one. Also
inspect suspicious Instance attributes (that's where the asset ID hid).

The scan belongs in the pre-publish checklist on [[place-state]].
