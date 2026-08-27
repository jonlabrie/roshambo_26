### Task 11: Extract the takeover suspension

Status: complete.

Gates: `lune run tests/run` → 921 passed, 0 failed. `stylua --check src tests tools` clean.
`selene src tools` → 0 errors, 0 warnings.

`default.project.json`: `"RoshamboClient": { "$path": "src/client" }` maps the whole directory,
confirmed by grep — `Takeover.luau` needs no project-file edit.

Deviation from the brief's literal move-list, flagged for review: `LedgerController`'s
`CharacterAdded` respawn handler (re-suspends after a mid-panel respawn) was also moved into
`Takeover.luau`, guarded on `depth > 0` instead of `isOpen`. The brief's enumerated list didn't
name it, but leaving it in `LedgerController` calling a now-nonexistent `suspend()`/`savedWalk`
would break at require time, and generalizing the guard to `depth > 0` is what makes the respawn
protection correctly cover the teahouse in Task 12 too (a respawn while the teahouse alone holds
the takeover must still re-freeze). Everything else moved verbatim, `[LEDGER]` → `[TAKEOVER]` only.

Two levels matter here: `LedgerController.open()`/`close()` are themselves idempotent (each
guarded by its own `isOpen` check), so a double `open()` or double `close()` call on ONE panel
instance reaches `Takeover.acquire()`/`release()` at most once per real transition. The sequences
below trace `Takeover.acquire()`/`release()` directly — the case that matters is two holders (e.g.
ledger + teahouse in Task 12), which is what the reference count exists for.

Trace, acquire → acquire → release → release (two holders, e.g. ledger then teahouse): acquire
(depth 0→1, `suspend()` runs — frozen); acquire (depth 1→2, no `suspend()` call — already frozen);
release #1 (depth 2→1, no `restore()` — still held by the second holder); release #2 (depth 1→0,
`restore()` runs — legs back). Correct: the player stays frozen until the LAST holder releases,
regardless of ordering.

Trace, acquire → release → release (one holder releasing twice, e.g. a stray extra call): acquire
(depth 0→1, `suspend()`); release #1 (depth 1→0, `restore()` runs — legs back); release #2: the
`depth == 0` guard fires, no-op — depth stays at 0, `restore()` is not called again. Composed with
`LedgerController.close()`'s own `isOpen` guard, a double `close()` from one panel never even
reaches the second `Takeover.release()` call — belt and braces, as required.

Concerns: none outstanding. The CharacterAdded-handler relocation is the one judgment call beyond
the brief's literal text; flagging it explicitly rather than assuming.
