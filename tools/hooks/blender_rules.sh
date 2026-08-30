#!/bin/bash
# Fired before any Blender MCP tool call. Puts the working rules in front of the model at the
# MOMENT OF ACTION, rather than trusting that it read them earlier in the session.
#
# ⚠ WHY THIS EXISTS. Asked "when would you re-read those rules", the honest answer was: never
# spontaneously. Pages get read when something prompts a lookup — a grep, a wikilink, an error —
# and nothing signals "you are re-entering Blender". Worse, a long session compacts: text read
# early degrades to a summary line saying it was read. On 2026-08-30 the rules were quoted back to
# the owner and then broken for the rest of the session, so re-reading is not even sufficient.
# A hook is the one mechanism that does not rely on remembering.
#
# ⚠ ONCE PER SESSION, NOT PER CALL. Twenty Blender calls in a row each carrying nine rules is noise,
# and noise is ignored. The marker is keyed on the session id from the hook's own stdin payload.

RULES="docs/wiki/practice/blender-working-rules.md"
payload=$(cat)
session=$(printf '%s' "$payload" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("session_id","nosession"))' 2>/dev/null || echo nosession)
marker="${TMPDIR:-/tmp}/roshambo-blender-rules-${session}"

repo=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# ⚠ A DURABLE, CHECKABLE RECORD. Whether hook output reaches the transcript depends on the client,
# and "ask the model whether it saw the rules" is exactly the report you should not have to trust.
# This log is a filesystem fact: `cat .blender-rules.log` shows every session that was served, and
# every Blender call that was not the first. Gitignored -- it is local evidence, not project truth.
log="$repo/.blender-rules.log"
stamp=$(date "+%Y-%m-%d %H:%M:%S")
if [ -f "$marker" ]; then
  echo "$stamp  session ${session:0:8}  (already served this session)" >> "$log"
  exit 0
fi
touch "$marker"
echo "$stamp  session ${session:0:8}  RULES INJECTED before first Blender call" >> "$log"
[ -f "$repo/$RULES" ] || exit 0

echo "=== Blender working rules (docs/wiki/practice/blender-working-rules.md) ==="
echo "Injected once per session, before the first Blender operation. Read them now."
echo
sed -n '/^## 1\./,$p' "$repo/$RULES" | grep -E '^## |^⚠ \*\*' | sed 's/\*\*//g'
echo
echo "The two the owner ruled on: no Studio until something can ONLY be judged there;"
echo "an approach is abandoned when the OWNER says it is. Full text is in the file above."
