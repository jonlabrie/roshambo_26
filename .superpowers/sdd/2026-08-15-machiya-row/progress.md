# SDD ledger — plan: docs/superpowers/plans/2026-08-15-machiya-row.md

Spec: docs/superpowers/specs/2026-08-15-machiya-row-design.md
Branch: m4b-zendojo-art-pass (BASE at start: 5cbb9f7). No worktree — established
project convention (prior ruling, wiki-plan ledger), and owner gates need the live
Studio place anyway.

## Pre-flight conflict scan (2026-08-15)

| Pair / task | Produces vs consumes | Finding |
| T1→T2/T3 | Shop type fields (name/envelope/yaw/frontage/interior/storeys/identity) | consistent across all tasks |
| T1 assert vs T2 | T1 rejects non-hanabiya configs; T2 Step 6 explicitly avoids calling build() on new shops | clean |
| T3→T4/5/6 | Dressing child model name "Dressing"; board→"SignBoard"; koshi→"KoshiFront_<i>" | test names match emissions |
| T3 identity nil | hanabiya has identity=nil; kit fields all optional | clean — implementer must nil-guard |
| T6 yaw vs guard tests | subordination unaffected by yaw (topY invariant); containment done in local frame per plan | clean |
| T4-6 tests in MachiyaShops.spec | that file (from T1) requires only MachiyaShops; guard tests need Machiya+ZenDojo+ArenaLayout requires added | NOT in plan text — carry in T4 dispatch context |
| T7 | Chaya.build 2-arg matches genmodels entry; ChayaKeeperSlot dims consistent | clean |
| Names in project.json | MachiyaApparel/MachiyaAccessories/MachiyaEast/Chaya vs existing children | no collisions |
| T8 | wiki files exist (item-4, arena-square, log) | clean |

Ruling: none needed from scan; the T4 requires-note is dispatch context, not a plan defect.

Model plan: T1 sonnet (mechanical extraction, byte gate catches errors); T2 sonnet
(survey); T3 fable (builder variants); T4 fable (first shell sets the pattern);
T5/T6 sonnet (pattern repeats); T7 fable (new builder); T8 sonnet. Reviews sonnet,
re-reviews haiku.

OWNER GATES: tasks 4,5,6,7 each end stopped, waiting for the owner in Studio. Do not
chain past a gate.

Task 1: complete (commits 5cbb9f7..7d3600b, review clean; byte gate verified independently)

Task 2: implementer DONE (546629e). Survey findings to carry:
- Machiya_East: AABB intersects 18 built Overlook parts (UpperDeck, girder, 16 railings);
  terrain front-spread 6.32 studs; floorY 109.74 (below square grade). RAISE WITH OWNER
  BEFORE Task 6 dispatch — do not build a first attempt that interpenetrates the Overlook.
- All three envelopes 13.24 deep (same tightness hanabiya had pre-deepening) — owner corrects at gates.
- Machiya_2 rotated -97 deg — Task 7 must re-survey in the block's LOCAL frame (carry into T7 dispatch).
Task 2: complete (commits 7d3600b..546629e, review clean; Overlook collision + terrain findings verified live)
Task 2: minor (deferred): MachiyaShops.luau:71 vs :78 — same corner labeled 49.58 (envelope) and 49.59 (probe table), 0.005 rounding artifact
Task 3: fix round 1/5 (2 addressed, 0 open — kit-field coverage test + koshi/full assert; commits c173cb1..33195e9)
Task 3: complete (commits 546629e..33195e9, review clean after round 1)
Task 3: minor (deferred): chochin port halves slice/rib counts vs the Studio tool (10/8 vs 18/16) — visual density check lands at the Task 4 gate anyway
Task 4: implementation + review complete (commits 33195e9..48a15ea, review clean — independent AABB walk reproduced the self-review exactly). STOPPED AT OWNER GATE.
Gate issue (T4): rojo serve snapshot error — project.json was registered BEFORE genmodels wrote the asset (plan's own step order), and a failed serve snapshot doesn't recover when the file appears. Fix: owner restarts rojo serve. RULING: Tasks 5-7 dispatches must run genmodels BEFORE touching default.project.json (swap of plan steps 4/5). Cost if wrong: none — order is otherwise indifferent.
Task 4: gate correction round 1 applied (48a15ea..94d7882) — apparel x1 2.30→-3.17, registers to hanabiya west face -1.67 with 1.5 roji gap; relationship test pins it; suite 1122/1122, byte gate clean. AWAITING OWNER RE-LOOK (rojo already serving; asset change syncs live, no reconnect needed).
Checkpoint: no scoped re-review dispatched for this correction round yet — owner's eye is the pending gate; run a scoped re-review only if further code rounds accumulate.
Gate correction round 2 DISPATCHED (owner: kit chochin diverged from the canyon-wide pattern): extract canonical recipe from buildHanabiyaChochin.luau into builders/Chochin.luau, shared by tool + kit, full fidelity (18/16), trig permitted per existing precedent. Agent working in background at checkpoint. On resume: collect its report, then owner re-looks at apparel (cloths-width judgment also pending).
Chochin correction re-dispatched after prior agent died on session limit (no work lost — tree was clean).
CORRECTED my own earlier instruction: (1) glyph plates are FUNCTIONAL (carry RoundLantern tag for
LanternController + PaperLanternDayNight) — must NOT be optional/dropped; (2) studio tools CANNOT
require builders (pasted whole into Studio), so the tool stays standalone and a text-parsing DRIFT
TEST guards the two copies instead. Agent also investigating whether Rojo/JsonEmit can emit the tag.
Chochin correction COMPLETE (94d7882..3381f29, scoped re-review ADDRESSED): builders/Chochin.luau
ports the canonical lantern at full fidelity (18 slices/centerIdx 9, 16 ribs, 14-seg ring, all
constants verified equal to the tool); RoundLantern tags emit correctly (4 plates); text-parsing
drift test proven honest by reviewer; Machiya restatement deleted; 1143/1143, assets deterministic.
AWAITING OWNER RE-LOOK at apparel (overlap fix + canonical lanterns + cloth-width judgment).
Apparel gate correction round 2 (3381f29..0726013): racks off the frontage, flanking the fold table
at cx±4.5, splayed -35/+35; 2 cloths/rack at 1.95; rotation via Spec.rotY (arch-stable); rotation-aware
extent audit clean; clearances frontage→group 3.05, group→counter 1.85, wall channels 2.31.
1143/1143, byte gate clean. AWAITING OWNER RE-LOOK (round 3).
Apparel round 3 (0726013..2de7496): owner hand-placed racks BAKED as APPAREL_RACK_OVERRIDES
(rail-centre rel offsets + per-rack yaw -105.86/+129.97, asymmetry preserved deliberately);
reproduction worst delta 0.0008 studs. Clearances frontage→table 3.23, table→counter 2.03.
Chochin tints (2de7496..19e35bc): Chochin.build gains optional paperRGB255 (default canonical);
identity.chochin accepts {paper={r,g,b}}; apparel = pale indigo {170,178,200} lum 0.698;
LEGIBILITY GUARD test walks every MachiyaShops entry, floor 0.55 relative luminance (canonical
cream 0.684) — a future dark lantern fails CI. Reserved palette commented for accessories
(moss), chaya (persimmon), hanabiya (cream); true red excluded (izakaya signal). 1149/1149.
OWNER RULE RECORDED: paths uniform (wayfinding), merchant row varies (commerce).
AWAITING OWNER LOOK (apparel round 4: baked racks + pale indigo lanterns).
Task 5 (accessories) implementation complete (19e35bc..bd6f90b): envelope 17.76 (pre-caught the
mirror stale-massing defect BEFORE building — saved a gate round), moss tint {168,180,152} lum 0.688,
shelf walls + plinth + counter, 1153/1153, both prior shells byte-clean. Registration ordered
OUTPUTS→genmodels→$path (serve-safe). STOPPED AT OWNER GATE. No task-review dispatched yet.
Accessories gate round 1 (bd6f90b..90d0c4b): noren → prussian navy {0.07,0.15,0.32} (halves apparel's
red to kill its violet lean), perBay=2 via new optional identity.noren.perBay field (defaults to the
shared NOREN_PER_BAY, so hanabiya+apparel byte gates stayed clean — the real proof); panel width
0.918→1.456, slit 0.16. Tests pin the per-shop divergence both ways. 1155/1155. AWAITING OWNER LOOK.
KIT DEFECT found at accessories gate by owner ("you do not have a kanban"): the kit's board emitted a
frameless 1.8-tall slab at the kamoi line, INSIDE the eave's z-span (eave y121.93-122.18 over z32.71-35.26,
board z35.11-35.23) — physically hidden under the soffit. Diagnosed from the live place, not guessed.
FIXED (90d0c4b..b79a872): full framed kanban (panel + 4 members, -15 deg tilt) on the UPPER STOREY centred
on the mushiko-mado band, 0.95 proud of the upper wall, 1.107 clear above the eave; blank pending naming.
OCCLUSION GUARD test added (panel extent must not intersect Eave in y∧z) — RED at old placement, GREEN now.
1157/1157, hanabiya byte gate clean. LESSON: the kit's board was never visually verified — a part existing
is not a part reading ([[roblox-visible-is-not-pixels]] class).
AWAITING OWNER LOOK; naming style question still open (asked, owner wants to see the board first).
SIGNAGE PASS (b79a872..0db82e5), owner-directed: sign TYPES per shop + per-character lettering.
MEASURED FACT recorded: no Roblox font has CJK glyphs (all 53 Enum.Font return identical metrics
for 花火屋) — font variety is impossible for kanji; variety must come from type/orientation/colour.
- shared kanjiFace helper (one TextLabel per kanji, 花火屋's proven canvas, horizontal or tategaki)
- 花火屋: geometry untouched, spacing 1.55→2.6 centre-to-centre. BYTE GATE DELIBERATELY RE-BASELINED;
  containment proven by structural deep-compare: exactly 4 diffs, all Kanban>Face>children, 0 outside.
- apparel: 袖看板 blade, 呉服屋 tategaki both faces, gold on black lacquer
- accessories: 掛看板 plaque on hooks under eave, 小間物屋, sumi on bare cedar
- MachiyaEast: blank childless board, unnamed (wager-language ruling)
1169/1169. Owner flag: plaque hangs 0.17 over head line (deliberately low) — judge in game.
Signage round 3 (0db82e5..90a9eed): blade DELETED as anachronistic (owner: perpendicular high signs
read Showa, not Edo/Meiji); replaced by 幟 nobori (cypress pole + yokobo + 3-seg cloth chain, 呉服屋
both faces), planted INSIDE the envelope (promenade inviolable rule) with 0.395 z-margin, 0.139 clear
of the noren's 1.85x sway. Mon 丸に花/呉/小 on every noren, hosted on the tagged Seg2's own SurfaceGui
so the sway carries them. Hanabiya containment: 2 diffs, both Noren*_2>Seg2>children; 0 outside.
1173/1173; rojo build added to the gate run.
NEW TRAP FOUND (record in practice/ later): UDim2 offsets are Int32 in rbx-dom — a FLOAT pixel offset
makes rojo reject the ENTIRE model file. This is the same failure class as the earlier serve error.
Open for owner: nobori sway needs a NorenSway client change (offered as its own gate, not taken);
apparel mon is smallest (5-seg noren caps the ring); accessories mon sits on the west panel.
Signage round 4 (90a9eed..7c59f61): OWNER RULE CLARIFICATION recorded in code — the promenade bars
BUILDINGS, not signage (my earlier reading was too literal). Nobori replanted OUT FRONT on the
promenade at the west (closed) end, 0.18 beyond the drip line, walking lane 2.68, zero overlap with
any building part (open-sky guard added). Apparel noren 5→4 segments so its mon grows 36%→45.1%;
uniform sizing rule min(60% panel width, 90% segment height) — hanabiya 59.4%, accessories 39.7%.
Accessories mon PAIR now flanks the central post (Noren2_2/Seg2 + Noren3_1/Seg2). 1174/1174.
Hanabiya byte-IDENTICAL this round (its ring was already at cap).
STATS false front BUILT (7c59f61..824f53e, docs at 87fa22b): re-sited west of apparel per owner
(Machiya_East siting DROPPED; massing parked). x[-33.92,-23.92] z[35.23,43.23] floor 113.30,
frontPosts=3 (new per-shop field, default 5 proven inert by all 3 protected byte gates), open
frontage + shallow vestibule, pine-green noren + 丸に番, celadon chochin (WEST corner only —
east would collide with apparel's lantern across the roji), kanban 番付. 1188/1188.
TERRAIN CUT DONE in Studio (place-only, untestable): footprint + ~1 stud apron to 113.30.
OWNER RULING RECORDED: "sports book" BARRED as product usage (design discussion only); room is
Stats; sign reads 番付. Filed to practice/owner-rulings.md + spec amended + log entry.
AWAITING OWNER LOOK. Four flags: west interior strip clamps <=0.7 proud (voxel render clamp);
collateral hill bench x-38..-34 by ~1-1.6 from a resampled FillBlock (this terrain's voxel grid is
offset by 2 — 4k-aligned ops RESAMPLE: worth a practice/ note); rock toe at vestibule back is by
design; kanban shares hanabiya's cream+sumi ground.
NEXT: owner gate on Stats → then Task 7 (Chaya + DockDeck; block rotated -97deg, needs local-frame
re-survey) → Task 8 wiki close-out + push + final whole-branch review.
Stats rear doorway + cavern markers (824f53e..f36b05a): 6.0 clear opening centred x[-31.92,-25.92],
head 120.10 (floor+6.8), floor continuous 113.30, framed posts+lintel flush on WallBack's outer face
(z42.93), pine-green 3-panel noren on the vestibule side, NorenSeg-tagged (sway yaw-0 assumption
verified safe here). rearDoor is a per-shop opt-in — all 3 protected assets diff clean. 1195/1195.
draftStatsCavern.luau committed + RUN: Route_01..05 + Room NW/NE/SW/SE under Workspace.PathDraft.
StatsCavern, DevMarker-tagged, REBUILD=false guard (re-run refuses to clobber owner-dragged positions).
CARRIED RISK (pre-existing, will bite Task 7): NorenSway client rebuilds tagged segments assuming
yaw-0 panels — the chaya sits at yaw -97, so its cloth would snap flat. Fix = client change, own gate.
AWAITING: owner terrain shaping + marker dragging, THEN the bore.

=== REBOOT CHECKPOINT (2026-08-16) ===
All 21 commits PUSHED (121e157..f36b05a). Working tree clean. Nothing at risk in git.
AT RISK IF THE PLACE IS NOT SAVED: the Stats footprint terrain cut; Workspace.PathDraft.StatsCavern
markers; and the older place-only carry-forwards (NorenCloth, BronzePatinaFine, Chochin_Hanabiya,
BellRingAnchor). Terrain + markers are place-only and git cannot see them.
ON RESUME: (1) owner restarts `rojo serve` from roblox/ and reconnects the Studio plugin;
(2) owner's terrain shaping behind Stats + marker dragging is the pending gate; (3) then the bore
(recipe: practice/misc-engine-traps.md — 4-stud voxels, boxes >=5-6 every dim, carve H>=12,
verify by occupancy column not raycast, owner's own backup is the only reliable undo);
(4) then Task 7 chaya+dock (block yaw -97, needs local-frame re-survey; NorenSway yaw-0 bug will
bite its cloth); (5) then Task 8 wiki close-out + whole-branch final review.
