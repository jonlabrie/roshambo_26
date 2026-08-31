---
shelf: practice
updated: 2026-08-15
checked: 2026-08-31
---

# Replication Races

Three flavours of one underlying truth: **server→client replication is asynchronous
and unordered**, and client code that assumes otherwise fails intermittently or
silently.

## 1. Startup lookup: WaitForChild, not FindFirstChild

A client `LocalScript` (StarterPlayerScripts) that reaches into `workspace` for
server-built geometry must use `:WaitForChild(name, timeout)`, NOT
`:FindFirstChild(name)`. Workspace geometry replicates asynchronously, so at
script-start the target often hasn't arrived yet. `FindFirstChild` returns nil → an
early `return` → the script silently does nothing. It's a RACE: sometimes the script
loses (no effect), sometimes wins (works) — maddening **intermittent** behaviour, not
a hard failure.

Diagnosed 2026-06-22 on `ChannelFlowAnim` (channel water): the UV-scroll animation
"wasn't running" some Plays. `[CFA] static channel not found` logged at startup, yet a
few seconds later the same Client datamodel showed the ribbon present. The "it worked
once" sessions simply won the race. Fix: `WaitForChild(name, 30)` per path node.
General rule: any client-side `workspace.Foo.Bar` walk at startup → WaitForChild with
a timeout. (Tag-driven discovery via `CollectionService:GetTagged` +
`GetInstanceAddedSignal` avoids the race entirely — see the FlowRibbon animator on
[[blender-pipeline]].)

## 2. RemoteEvents are NOT ordered vs instance replication

When the server rebuilds geometry (destroy children + adopt staged children) and then
fires a RemoteEvent referencing it, the event can reach the client while the **doomed
old instances are still visible** — an event-time `FindFirstChild`/`WaitForChild`
happily returns the old structure, the client binds ProximityPrompts/UI to parts that
die moments later, and the net result is "nothing appeared" with no error. Discovered
in B3 (2026-07-16): back-door F prompts never re-armed after mid-session teahouse
rebuilds; firing the event at every rebuild site was necessary but insufficient — the
binding itself was the race.

**How to apply:** drive client binding from **geometry arrival, not event timing**.
Pattern (see `roblox/src/client/BackDoorController.client.luau`, rewritten `c7a9214`):

- keep a persistent `ChildAdded` watch on the STABLE parent (e.g. the
  `MaterializedSite_<padId>` folder — `TreatmentApplier` swaps children but never the
  folder);
- on a matching child, rebind with **instance-identity** checks (new instance →
  disconnect per-structure connections, reset the prompt/UI cache, rebind; same
  instance → relabel only);
- also watch the new structure's own `ChildAdded` for late-replicating descendants;
- the RemoteEvent then only carries *data* (which folder to watch, active state),
  never the trigger to look up geometry.

## 3. ParticleEmitter:Emit() does not replicate at all

**`ParticleEmitter:Emit(n)` called on the SERVER renders nothing on clients.** Learned
building the fireworks bench (2026-07-20): a burst created + `:Emit()`'d in the Server
datamodel was invisible on the client, while the same shell's **Trail and neon Part
showed fine**. Instance *property changes* replicate (a server-created Trail, Part, or
an emitter with `Rate>0` all render); `:Emit()` is a one-shot **method call**, and
method calls are NOT replicated. Not a race — the emit simply never crosses the wire.

**Fix / rule:** burst VFX (`:Emit`, and anything triggered via a method rather than a
property) must run **client-side** — a LocalScript per client, or the server fires a
lightweight RemoteEvent carrying position/type/color/seed and each client renders its
own local VFX. This is also the production architecture for [[fireworks]].

**Debug tell:** "streak/trail + a frozen dot, but no burst" = the property-driven
parts replicated but the method-driven emit didn't.

**Related gotchas:** a `ParticleEmitter` created via `Instance.new` has
`Texture == ""`, which renders **nothing** — always set a texture (built-in
`rbxasset://textures/particles/sparkles_main.dds` works but is soft; a crisp round-dot
upload reads sharper and cuts overdraw). Driving Studio via MCP: `execute_luau` takes
a `datamodel_type` (`Edit`/`Client`/`Server`) — use `Client` to make `:Emit` actually
render ([[studio-tooling]]).
