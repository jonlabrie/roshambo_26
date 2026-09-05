---
shelf: practice
updated: 2026-08-15
checked: 2026-09-04
---

# Modal Cursor Grip

Recipe for letting a player use a modal ScreenGui in first person / shift-lock — and
the `DevEnableMouseLock` permissions trap that breaks the obvious attempt.

## The problem

A ScreenGui that opens on walking into a volume **traps a first-person player**: the
cursor is pinned to screen centre, which is where a centred panel sits, so the close
button cannot be clicked and the scroll that would zoom back out is eaten by the panel
under the pinned cursor. Shift-lock does the same thing in third person.

## The working recipe

Shipped in `roblox/src/client/ShopController.client.luau` (花火屋, [[hanabiya]]):

1. `RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, …)`
   setting `UserInputService.MouseBehavior = Enum.MouseBehavior.Default`. **Priority
   is the whole trick** — the camera module writes MouseBehavior during its own render
   step, so anything written earlier is overwritten before the engine reads it.
   Verified: at Camera+1 it stays `Default`, and reverts to `LockCenter` the frame it
   unbinds.
2. Pair grip/release with a single `gui.Enabled` writer and a `holding` flag.
   `BindToRenderStep` on an already-bound name replaces it quietly, but `Unbind` on a
   name never bound **throws** — and that throw lands in the middle of closing the
   panel.

**DO NOT ALSO MOVE THE CAMERA.** The first working version raised
`CameraMinZoomDistance` to walk the player out to third person (it does work). The
owner: *"your fix essentially forces me into third person when I enter the shop?"*
**The trap is about the cursor, not the camera**, and moving the camera takes away a
choice the player made deliberately. Measured with the camera pinned in first person,
the override ALONE gives `MouseBehavior=Default`, `MouseIconEnabled=true`, and the
close button topmost under the cursor. The camera simply stops turning while the panel
is open, which is what a modal should do.

**Confirm a button is really hittable** with
`PlayerGui:GetGuiObjectsAtPosition(x, y)[1]` at the button's own centre — a free
cursor is not proof of a usable one. See [[visible-is-not-pixels]].

## The trap that cost the first attempt

**`Player.DevEnableMouseLock` is NOT settable from a LocalScript.** It throws
`Insufficent permissions to set DevEnableMouseLockOption` (Roblox's own typo). It looks
like the right switch for shift-lock, the property exists, the assignment type-checks,
and stylua/selene/`--!strict` are all clean. Nothing on disk shows it.

Worse than not working: it threw as the **first statement** of the grip function, so
everything after it never ran, and the same line in the release function took
`gui.Enabled` with it, so the panel also stopped closing. **One unsettable property,
two unrelated-looking symptoms.**

## How to apply

- No harness in this repo loads a `.client.luau`, and a permissions boundary is
  invisible in the source anyway. **Run it in Play and read the console** before
  claiming a client fix works — the console said "Insufficent permissions" plainly.
  See [[visible-is-not-pixels]] and the one-attempt rule on [[owner-rulings]].
- Probe pattern that found it: drive the character into the volume with `root.CFrame`,
  then print camera distance / `CameraMinZoomDistance` / `gui.Enabled` /
  `MouseBehavior` on one line before, during and after. The "after" row is what
  exposed the release path failing too.
- **Fix only the thing that is broken.** Two mechanisms both "worked", and shipping
  both meant shipping an unnecessary side effect the owner noticed immediately. Once
  one is verified sufficient, delete the other — a tested module nobody calls reads as
  load-bearing.
- Reuse this for any future modal opened by proximity — the decoration catalog and
  teahouse editor panels have the same shape ([[friends-family-baseline]]).
