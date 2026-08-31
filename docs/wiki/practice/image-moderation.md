---
shelf: practice
updated: 2026-08-15
checked: 2026-08-31
---

# Image Moderation

What Roblox's image moderation does to this project's uploads — one confirmed
takedown, plus the upload-pipeline behaviours everything image-based has to work
around.

## Never upload green palmate foliage (confirmed takedown, 2026-08-01)

The xFrog maple leaf atlas was recoloured into green/gold/red variants and all three
uploaded. Roblox **removed the GREEN one** (`113908195064379`) within hours. Gold
(`111846883522531`) and red (`138457704702807`) — the *same leaf shape*, same upload
batch — were untouched.

**Cause:** a palmate, serrated, **green** leaf matches cannabis to automated image
moderation. The colour completes the match, which is exactly why only green was
pulled.

**Rules:**

- **Never upload green palmate foliage.** You essentially never need to — the vendor's
  own green colormap is already uploaded and working (XfMapleA sits on
  `140172233879343`, live for weeks).
- **Autumn recolours are safe** for the identical leaf shape. Gold/red/bronze pass.
- **Do not re-upload a removed asset** — that invites escalation against the account.
  Drop the variant and point the model at the original.
- A takedown breaks any model referencing that ID, so check
  `SurfaceAppearance.ColorMap` on anything that used it.

Tool: `roblox/tools/textures/recolor_leaves.py`. See [[foliage]].

## Upload-pipeline behaviours (from the glyph work, 2026-07-21)

- MCP `upload_image` needs **http/https URLs** (not local paths) and only accepts
  trusted URLs → serve the dir with `python3 -m http.server PORT` and pass
  `http://localhost:PORT/x.png`. Returns `{url: rbxassetid://…}`.
- **Every freshly-uploaded image renders BLANK until Roblox approves it** (minutes;
  texture assets ~20–60s). `IsLoaded=true` even while blank. Confirm it's moderation
  (not a bug) by swapping in a known-good asset. Batch uploads up front.
- Superseded image assets STAY LIVE — an A/B rig can sit an old and new version side
  by side with zero re-uploads ([[material-and-mesh-traps]] §9 used this to revert
  nine atlases).

Related: [[blender-pipeline]] (the SDF glyph pipeline these lessons came from),
[[rojo-meshpart-rbxm]] (the ambientCG material upload path).
