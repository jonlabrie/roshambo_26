---
shelf: world
updated: 2026-08-18
---

# Stats Room (番付) — the cavern

The excavated hall behind [[hanabiya]]'s neighbour, the Stats false front. Bored
2026-08-16 and saved to the place. What goes ON its walls is specced separately
(`docs/superpowers/specs/2026-08-16-stats-room-design.md`); this page is the rock.

## As-built

Terrain is **place-only** — git cannot see it. `roblox/tools/studio/boreStatsCavern.luau`
records the surveyed geometry and re-measures the as-built; it defaults to
`MODE = "VERIFY"` and writes nothing.

| | |
|---|---|
| Chamber | x[−58.0, −18.0] · 40 wide × 25 deep, entered from the north at ~x −28 |
| Floor | **114.00**, flat (interior range 113.16–114.00) against the shop sill at 113.30 |
| Ceiling | **134.00** — ~19 studs clear |
| Rock cover | 17.9 studs at the thinnest over the interior |
| Tunnel | 8-stud bore (≈6–7 net), floor 113.12–114.00, min clear **7.67** |
| Breaches to sky | none |

The tunnel roof is pinned to the **top of the rear-door lintel (120.60)** at the mouth so
it meets the doorway without a step, then ramps 0.85/stud to 124.3 once there is rock
overhead. The chamber ceiling opens ~5 studs above the tunnel, so the hall reveals itself
on arrival.

## The berm — why the hillside was raised

There was **no rock to bore through**. Natural grade behind the rear doorway topped out at
**120.29** — the door head (120.10) exactly — so the first ~8 studs of tunnel would have
been an open trench. The hillside behind the shop was raised to 125.0 at z ≤ 44.3, climbing
0.96/stud to 129.5 where it meets the natural slope.

That berm is threaded under a hard ceiling: **`RoofSouth`'s lowest corner sits at 127.20**,
and terrain must stay clear of it. Note that corner is at 127.20, not the 129.3 a naive
`Position.Y − Size.Y/2` reports — the part is rotated, and the 2.1-stud error would have
driven the berm through the roof. Clearance as saved: **+2.45** (the owner hand-shaped the
mouth further after the bore).

## Display siting and the flap module (owner, 2026-08-17)

Settled at the first Studio look, after the boards were built. Supersedes the
one-room assumption in the design spec: the displays now occupy **two sites**, the
cavern and the [[hanabiya]] row's Stats vestibule above it.

**A flap is a physical module, and boards are built FROM flaps.** The first build got
this backwards — each board declared a *column count* and inherited its cell size from
whatever its surveyed width happened to be, so flap width ranged from 0.375 studs on
`fuda` to 2.375 on the long band segments. A six-fold spread across one room, in
equipment meant to read as one machine. **Board physical size is now DERIVED**
(`cols × FLAP_W` by `rows × FLAP_H`); the grid is the input, the dimensions are the
result.

**Two flap sizes, for two viewing distances — and only two.** Wall boards read from
across a room and share the standard flap. The personal slip is read standing in front
of it and gets a deliberately finer module. That is a design; six accidental sizes was
the defect.

| | flap | why |
|---|---|---|
| Wall boards | **0.615 × 0.72** | `banzuke`'s proportions, which the owner approved |
| Personal slips | **0.34 × 0.40** | 16 columns at 5.44 studs on a 7.40 wall — a stud of quiet either side |

The slip started at 0.425 × 0.50 and was cut a further 20% at the owner's look: the
first fit *filled* its wall, and a slip that fills its wall reads as a board rather than
as the small personal thing it is.

**Every board is framed in the same dark wood** (owner, 2026-08-17). The vestibule pair
briefly got a pale frame, reaching for §6.2's "paper-and-wood against stone" — but the
paper is the ivory flap face, which every board already has, and the wood is what
surrounds it. Two frame colours made the room read as two rooms. The slips stay distinct
by being a finer module, which is the honest difference.

**And every board is CASED in an inch of it** (owner, 2026-08-17). Four rails per board,
a shade darker than the board itself (RGB 52,40,27, plain `Wood` — a plank texture tiled
onto a one-inch face is noise), built by `tools/studio/buildStatsBoards.luau`. An inch is
a *twelfth* of a stud here. The rails sit OUTSIDE the board's footprint, never over it:
the flap grid runs edge to edge, so a frame laid on the face would eat a strip of the
first and last cell in every row. Depth is cut to whatever stands furthest forward on
that board — the board face for a GUI board, `FlapUnit`'s leaf face (0.37) for the round
display, the padlock (0.56) for the shuttered panel — so the moulding reads as a case
around the mechanism rather than a line painted on the wall behind it. Place-only parts:
save/publish, never `rojo build`.

### Typography

Two faces, and they are chosen for different jobs rather than for consistency.

| | face | why |
|---|---|---|
| Wall board lettering | **TitilliumWeb Bold** | Owner, 2026-08-17, chosen by eye against JosefinSans and Oswald. |
| Clock numerals | **Oswald Bold** | Owner, 2026-08-17. Condensed — the classic departure-board answer. |

JosefinSans held the walls until then: gate-picked 2026-06-07 (`77d8940`), quietly replaced
by Merriweather two hours later the same evening with no gate note, restored on 2026-08-17
when the owner looked at the built room and said the typeface was wrong, then superseded by
TitilliumWeb once it could be compared live.

**Two faces for two jobs, and that is deliberate.** The timer shows four big numerals read
at a glance; the walls show lines of lettering read as text. A condensed display face is
right for the first and not automatically for the second.

`FontFace`, not the legacy `Font` enum, because the enum carries no weight. Bold is the
heaviest REAL face in both families: probing all nine `FontWeight` values in Studio,
`Thin`..`Bold` each measure differently while `ExtraBold` and `Heavy` return `Bold`'s
exact bounds, so anything above Bold silently falls back.

The clock's family is live on `workspace:SetAttribute("ClockFont", …)` and applies to
flaps already built, so faces can be auditioned without restarting Play. A name that will
not construct falls back rather than erroring — so a typo reads as "nothing changed",
not as a broken display.

⚠ **Oswald is condensed** (342 wide for ten digits against RobotoMono's 455), so a digit
fills about half its cell rather than two thirds. If it reads narrow that is the face, not
a defect: widen the cell or lift `CLOCK_CHAR_FRACTION`.

⚠ **A LIVE-TUNING ATTRIBUTE OUTLIVES THE SESSION AND SILENTLY BEATS THE DEFAULT.** Workspace
attributes are saved place data, so a value set while auditioning persists — and every one
of these knobs is written to be overridden by exactly that. On 2026-08-17 the timer came up
in Inconsolata after Oswald had been made the default, and it read as the code resetting
itself; the attribute set an hour earlier was simply still there and still winning.

**Before treating a default as broken, check `Workspace` → Attributes for a leftover.**
Clear the attribute to hand control back to the code. The knobs: `ClockFont`,
`ClockFontWeight`, `BoardFont`, `BoardFontWeight`, `BoardTextNudge`, `GlyphNudgeP`,
`StatsFixtures`.

⚠ **Optical centring is per-face.** An all-caps line rides high because the line box reserves
descender space the capitals never use, so it is nudged down — but by how much depends
entirely on the font's metrics. 0.1 suited JosefinSans and sat TitilliumWeb visibly low.
Live on `BoardTextNudge`.

⚠ **Every size constant here is a TextSize, and the eye reads INK.** A digit's drawn height
is only ~0.72 of its TextSize — the rest of the em is leading and room for ascenders and
descenders a numeral never uses. Setting it above 1.0 is safe and often correct.

### The drums

Every flap cell rolls forward through a character drum, and which drum it uses is settled
differently on the two kinds of display here — because the two kinds differ in a way that
decides it.

**The round display bolts a drum to each COLUMN.** Its column 3 is always a tens digit, so the
drum is a property of the position, exactly as on a physical board where the seconds flap has ten
digits on it and has never had a `U` to roll past. `RoundDisplayModel.DIGITS` is `"9876543210 "`
— descending, so counting down is one step forward; blank last, so `0 → blank` at round end and
`blank → 9` at round start are each one step too.

**The wall boards choose from the TRANSITION** (owner, 2026-08-18; gated the same day), because their columns have no
fixed kind: `1. JONNY        1,234` holds a digit in one row, a space in the next and a letter in
the third, and it all moves when the window changes. `FlapScheduler.drumFor(cur, tgt)` returns the
smallest drum carrying both characters, over a three-rung ladder:

| rung | drum | carries |
|---|---|---|
| 1 | `0123456789` | digit-to-digit — the overwhelming majority |
| 2 | `0123456789+-.,%/ ` | a figure meeting its punctuation, e.g. the comma walking across `1,234 → 12,345` |
| 3 | the full 49 | names, labels, throw glyphs |

⚠ **A SMALLER DRUM DOES NOT REMOVE THE 9-STEP CAP, IT ONLY FIRES IT LESS — and the shrink has to
be big to pay.** `7 → 3` is 45 steps on the full drum and **still 11** on a 15-character numeric
one, capped either way. At TEN characters it is 6, and the greatest distance possible is 9 —
exactly the cap — so no digit transition is ever truncated and the jump-cut cheat goes quiet.
This is why digits get a rung to themselves: every character added to a rung is paid for by every
transition that uses it. `+` and `.` sit on rung 2 as headroom (nothing prints them today) which
costs rung 1 nothing.

`FlapBoard.drums` accepts a table (bolted per column) or a function (chosen per transition), which
is what lets one renderer serve both. `FlapScheduler.plan` caches each drum's character array and
reverse index, because a per-transition caller plans one cell per call rather than one line.

### What the boards measure (built 2026-08-18, not yet gated)

Three numbers, from rows the server already wrote — no schema change, no new capture. Basis and
evidence: `docs/superpowers/specs/2026-08-18-player-measurement-design.md`.

| board says | is | source |
|---|---|---|
| `BEAT WORLD` | wins ÷ throws. A blind player scores **33.3%** exactly, so anything above is edge | `PlayerRound.playerResult` |
| `PER THROW` | points banked ÷ throws — **what the banzuke ranks on** | `BankEvent.amount` |
| `YOU BANK AT` | median `streakAtBank` — how deep you ride before collecting | `BankEvent.streakAtBank` |

**Yield ranks; the read sits beside it.** Yield is the only figure that captures the compounding
— a strong reader riding deep earns many times what a blind one riding as deep does, a gap win
rate alone shows as a few percentage points. The read column is what says whether someone is up
there on skill or on nerve.

**Bank depth is never ranked.** A leaderboard of "who rides deepest" crowns the player who rides
past their own read and banks nothing. It is a histogram on `skillFuture` (which is no longer
shuttered) and one row on the 札.

**Two gates, and both must hold before the read column renders:**

1. `TEST_MODE` off — otherwise the World Throw is a fixed R→P→S cycle and a win rate measures who
   spotted the pattern. **Closed in every environment today**, so the column ships blank.
2. **360 throws in a rolling 7 days** to appear at all. Rounds are 60s exactly, so that is six
   hours of throwing. Printed on the board as the rule: `360 THROWS PUTS YOU HERE`.

⚠ **The window is ROLLING, not calendar** (owner, 2026-08-18) — a Monday boundary would wipe a
run that started Sunday evening. This overrides the older "RANK uses calendar windows" doctrine;
records boards stay calendar, because "biggest bank of the day" names a day.

The 札 carries `RANK 14 OF 22`, because the banzuke is ten rows and the reader who most wants to
know is the one in eleventh.

### Where things go

The vestibule's two interior side walls are better real estate than the cavern's
north-east corner: **7.40 long (z 35.53–42.93) × 9.00 tall (113.30–122.30)**, identical
on both sides, posts embedded outboard so the faces are clean.

| Display | Site | Wall |
|---|---|---|
| Personal 札 (`fuda`) | vestibule | interior **west**, face x −33.12 |
| Summary — the round's throw, players, R/P/S distribution | vestibule | interior **east**, face x −24.72 |
| Rotating avatar display — current world/server leaders | cavern | north-**east**, the wall `fuda` vacated |

The **tape** — the last ten World Throws — was a printed row on the form-guide board and moved
to the round display as real flaps at the owner's word (2026-08-17): "that should be a display
of its own, up there with the throw display and timer." It is gated on `drumRest` like every
other surface that names a throw. It had to leave the board rather than be duplicated: the same
ten throws on two surfaces, one gated on the drum and one not, would visibly disagree for the
3.45 seconds the drum takes to settle. The form-guide board is heat alone now.
| Round display — throw flipper, `0:00` countdown, and a ten-flap throw tape | cavern | west, replacing the four-segment band |
| 番付 standings, records | cavern | south / west / east as specced |

**The summary board names the throw** (owner, 2026-08-17): the World Throw glyph rides the
far right of its TOP line, in the same ○ ─ ∧ images the drum, lanterns, HUD and round display
wear. Its four rows were all *about* the throw without ever saying it, leaving a reader to infer
it from percentages. Carried by `Section.titleRight` — a raw string joined AFTER `sanitize`,
because the glyphs are multibyte and the sanitizer must stay byte-wise (display names are
external input; `utf8.codes` does not survive malformed bytes). The title yields to the glyph if
a board is ever too narrow for both. Safe against the drum for the same reason the percentages
are: this is the last CLOSED round, and `StatsController` holds a tape whose newest entry the
drum has not finished announcing.

**Neither new board needs server work, which is why they are cheap.** `GlobalResult`
already carries `distribution: { R, P, S }` and `totalPlayers`, and the ten-round tape
reaches the Roblox server on `/api/v1/state` and is already forwarded in `StatsData` —
the summary board's figures are sitting on the wire unused. And `robloxId` survives the
name filter (`filterTop` does `table.clone` and overwrites only `displayName`), so the
avatar display can read it straight off `StatsData.leaders`.

The avatar display closes a deferral rather than adding scope: the design spec §6.2 asked
for "avatar plinths, top three only", and the plan deferred them for want of a home.

**Still open:** whether the cavern's remaining wall boards become horizontal ticker tape
rather than flappers (owner, "probably"). Not decided, not built.

## Performance — measured on the A13, 2026-08-17

Owner walked the finished room on the Samsung A13 (the device that governs the F&F floor):
**CPU/GPU load in the room is neither better nor worse than the arena square outside**, with
roughly 8,400 GUI instances across the wall boards and no `MaxDistance` cull. No budget work is
owed; the cull idea can stay parked.

Open, cosmetic: **the physical flaps (clock, tape, throw flipper) read as ragged there.** That is
arithmetic, not load. `FlapUnit`'s half-turn is `DEFAULT_HALF` 0.055 s and the tape's is 0.0825 s
— at the ~30 fps the A13 holds, a half spans **under two frames**, so a tween has nowhere to
interpolate and the swing reads as a jump-cut. Lengthening the halves for the clock and tape is a
constant each; the throw flipper is different, because during the reel it is driven at
`ReelStep`'s interval and a longer turn there means MORE abandoned mid-turns (blur), not a
smoother one. Owner's verdict for now: "they read, essentially."

## Owner gates

- **2026-08-16** — bore accepted ("Tunnel looks good"), place saved.
- **2026-08-16** — room doubled: the west wall pushed −38 → −58 on the owner's call.
  Finished floor area ≈ 2.15× the original.
- **2026-08-16** — ceiling raised 129 → **135 carve / 134 as-built** ("raise the ceiling to
  135"). Held flat wherever the rock allowed, under a rule that the ceiling never comes
  closer than 11 studs to the hillside; only the thin north-east entry corner steps down.

The chamber is the bounding box of four owner-dragged corner markers, not their irregular
quad — the stated default, and the owner did not ask for the quad. Markers survive at
`Workspace.PathDraft.StatsCavern` (tagged `DevMarker`, hidden in Play).

## Raw layer

`roblox/tools/studio/boreStatsCavern.luau`, `roblox/tools/studio/draftStatsCavern.luau`,
`docs/superpowers/specs/2026-08-16-stats-room-design.md`, [[misc-engine-traps]] (bore
technique), [[place-state]].
