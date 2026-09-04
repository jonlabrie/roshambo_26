### Task 5: Tube render — the decoration pass grows a gear pass

**Files:**
- Modify: `roblox/src/client/DecorationController.client.luau`

**Interfaces:**
- Consumes: the state tables from Task 4 (`mortarPlacements`, `mortars`, alongside `deckDecorations`), `MortarPlacement.resolve/TUBE/MORTAR_ORDER`, the controller's existing rebuild triggers and deck-bounds derivation.
- Produces: visible tubes on every deck with owned mortars; later Task 6 overlays prompts on these models.

Behavior contract:
- In the same rebuild that redraws decorations for a pad, additionally render one Model per owned mortar at `MortarPlacement.resolve(...)` positions (pass the built teahouse footprint the decoration pass already computes, so the nudge rule engages).
- Tube geometry per tier from `MortarPlacement.TUBE` (bore/length): a vertical metal cylinder (`Size = Vector3.new(length, bore*3, bore*3)` with the CylinderMesh-free `Shape = Cylinder` + `CFrame.Angles(0, 0, math.rad(90))` axis fix, OR match however `DecorationCatalog`'s builders orient cylinders — read `tsukubai`'s builder and copy the idiom) on a `0.5`-tall timber base (`Color3.fromRGB(216, 214, 206)`, `Enum.Material.Wood`), anchored, non-interactive, Model named `Mortar_S/M/L` with PrimaryPart the tube.
- Tag each Model the way decoration models are tagged, PLUS an attribute `MortarId` (string) so the editor can find them.
- Rebuild on the same events decorations rebuild on (placement echo included).

- [ ] **Step 1: Read the controller's decoration rebuild pass fully; implement the mortar pass beside it.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/DecorationController.client.luau
git commit -m "feat(mortars): tubes render on every deck -- one per owned tier, default or placed"
```

---

