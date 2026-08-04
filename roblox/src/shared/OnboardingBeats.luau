--!strict
-- Onboarding beats. Each is fired by the event it explains rather than queued at join, so a
-- first-timer never reads ahead of themselves — the win beat appears at their first win, not
-- before they know what a win is. Bones, not a tutorial: the owner is narrating in person.
--
-- There is deliberately NO beat about movement or exploration. The HUD is designed to
-- de-emphasise movement, and a beat pointing at the thumbstick would undo that.
local OnboardingBeats = {}

export type Beat = { id: string, event: string, copy: string, anchor: string }

OnboardingBeats.BEATS = {
    { id = "drum", event = "join", copy = "The drum throws every minute. Beat it.", anchor = "drum" },
    { id = "throw", event = "throwsUnlocked", copy = "Tap a throw.", anchor = "throwArea" },
    {
        id = "win",
        event = "win",
        copy = "You won. Take it, or ride it — a win triples your pot.",
        -- Was "choiceOverlay": the blocking RISK/BANK overlay this pointed at was withdrawn
        -- (spec "Decisions taken" #6/7) and replaced by the persistent pot indicator in the slot
        -- above the throw row. Renamed to name what is actually on screen today.
        anchor = "potIndicator",
    },
    -- Was anchored "plate": the plate moved into the bottom row (spec §2, 2026-08-03) and is
    -- normally hidden, so a card can no longer point at where it used to sit. "wallet" names what
    -- this beat actually explains — the balance the plate displays — not a screen position.
    --
    -- Was "Banked. That's yours to keep." — the hamburger was deleted and the round-timer ring
    -- inherited its two-stage gesture (spec §6, Task 5), but a ring that looks like a readout
    -- does not invite a tap. The bank TOAST already says "banked" (main.client.luau), so this
    -- beat's copy no longer needs to; its job is teaching the gesture, at the moment it becomes
    -- useful — the first time there is a balance worth checking.
    {
        id = "bank",
        event = "bank",
        copy = "Tap the clock for your points. Tap again for everything.",
        anchor = "wallet",
    },
} :: { Beat }

function OnboardingBeats.next(seen: { string }, event: string): Beat?
    local seenSet: { [string]: boolean } = {}
    for _, id in seen do
        seenSet[id] = true
    end
    for _, beat in OnboardingBeats.BEATS do
        if beat.event == event and not seenSet[beat.id] then
            return beat
        end
    end
    return nil
end

return OnboardingBeats
