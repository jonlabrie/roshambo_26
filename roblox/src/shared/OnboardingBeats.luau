--!strict
-- Onboarding beats. Each is fired by the event it explains rather than queued at join, so a
-- first-timer never reads ahead of themselves — the win beat appears at their first win, not
-- before they know what a win is. Bones, not a tutorial: the owner is narrating in person.
--
-- There is deliberately NO beat about movement or exploration. The HUD is designed to
-- de-emphasise movement DURING PLAY; tour beats direct travel between stops, which is a tour's
-- job, but none of them may point at the thumbstick itself.
local OnboardingBeats = {}

export type Beat = {
    id: string,
    event: string,
    copy: string,
    anchor: string,
    -- The welcome's tap-through pages (copy == pages[1]); nil for every single-card beat.
    pages: { string }?,
    -- The tour's advance-through hook: an event arriving while THIS beat's card is still up
    -- normally drops (never stack) — but if it equals advanceOn, the controller dismisses this
    -- card (the guest has plainly done the thing) and shows the next. Without it a guest who
    -- launched before dismissing "follow the light to the river" would strand the tour: the
    -- modelDoor beat would report "dropped" and shellLaunched may never fire again.
    advanceOn: string?,
}

-- The welcome sequence (owner, 2026-09-03): the one deliberate exception to "never read
-- ahead" — a cold F&F guest needs the core context at join. Three pages, one tap each:
-- the new kind of RPS / the world throw's source + streaks / what points are for.
local WELCOME_PAGES = {
    "This is Roshambo — Rock, Paper, Scissors, but you're playing against the whole world at once.",
    "Every minute the big drum throws what most of the world picked. Beat it and your pile grows — every win in a row triples it. Read the crowd.",
    "Bank your points and they're yours — for fireworks, and one day a teahouse of your own. The drum's about to throw.",
}

OnboardingBeats.BEATS = {
    { id = "welcome", event = "join", copy = WELCOME_PAGES[1], pages = WELCOME_PAGES, anchor = "drum" },
    { id = "throw", event = "throwsUnlocked", copy = "Pick your throw — tap one.", anchor = "throwArea" },
    {
        id = "win",
        event = "win",
        copy = "You won! Every win triples your pile — or BANK THESE keeps it forever.",
        anchor = "potIndicator",
    },
    {
        id = "bank",
        event = "bank",
        copy = "Yours forever! Tap the clock to see your points. Tap again for everything.",
        anchor = "wallet",
    },
    -- ===== The tour (spec §2/§4): earned by banking, walked by the beam =====
    {
        id = "shopDoor",
        event = "bankDismissed",
        copy = "Points buy fireworks. Follow the light!",
        anchor = "tour",
        advanceOn = "shellBought",
    },
    {
        id = "launchDoor",
        event = "shellBought",
        copy = "A firecracker! Follow the light to the river.",
        anchor = "tour",
        advanceOn = "shellLaunched",
    },
    {
        id = "modelDoor",
        event = "shellLaunched",
        copy = "Beautiful. One more stop — follow the light.",
        anchor = "tour",
        advanceOn = "modelArrival",
    },
    {
        id = "modelHome",
        event = "modelArrival",
        copy = "A teahouse of your very own — 20 points. Every win gets you closer.",
        anchor = "tour",
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
