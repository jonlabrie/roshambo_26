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
-- ahead" — a cold F&F guest needs the core context at join. Four pages, one tap each, in the
-- owner's own words (copy-workshop pass, same day): what this is / where the world throw
-- shows / how to read the crowd / the handoff into the first throw.
local WELCOME_PAGES = {
    "Welcome to Roshambo — Rock, Paper, Scissors against Everyone, Everywhere, at the same time.",
    "The Throw drum atop the Bonsho bell spins once a minute to reveal the world throw — what most people chose in the current round.",
    "You want to beat that throw, so you need to read the crowd. The last five world throws are below the throw buttons, left to right.",
    "Go ahead and try to beat the world! Choose your first throw below — Rock, Paper, or Scissors.",
}

OnboardingBeats.BEATS = {
    { id = "welcome", event = "join", copy = WELCOME_PAGES[1], pages = WELCOME_PAGES, anchor = "drum" },
    { id = "throw", event = "throwsUnlocked", copy = "Pick your throw — tap one.", anchor = "throwArea" },
    {
        id = "win",
        event = "win",
        -- Owner's words (2026-09-03 copy workshop). "POT" is deliberate: the original ruling's
        -- target was UNEXPLAINED gambling jargon ("only if you know what a 'pot' is"), and this
        -- line teaches the term in the same breath it uses it. The wager-class words (ride,
        -- stake, wager, bet) stay banned — see the vocabulary test.
        copy = "You won your first point! You can BANK it, or leave it in the POT."
            .. " If you win again (before a loss) then points in the pot are tripled!",
        anchor = "potIndicator",
    },
    {
        id = "bank",
        event = "bank",
        -- Owner's words, plus one kept sentence: the clock-gesture teach. The ring looks like
        -- a readout, not a button (spec §6 ruling), and this beat is the only surface that
        -- ever teaches the tap — the gesture test below pins it.
        copy = "You're on your way to becoming a globally ranked Roshambo player!"
            .. " Points earned always count towards leveling, but they can also be spent to buy"
            .. " stuff like fireworks and a private place to hang out with friends."
            .. " Tap the timer below to see your points, double-tap for details.",
        anchor = "wallet",
    },
    -- ===== The tour (spec §2/§4): earned by banking, walked by the beam =====
    {
        id = "shopDoor",
        event = "bankDismissed",
        copy = "You can buy fireworks with points. The Fireworks shop is highlighted for you!",
        anchor = "tour",
        advanceOn = "shellBought",
    },
    {
        id = "launchDoor",
        event = "shellBought",
        copy = "Nice! Now you need a public fireworks spot — one is highlighted for you!",
        anchor = "tour",
        advanceOn = "shellLaunched",
    },
    {
        id = "modelDoor",
        event = "shellLaunched",
        copy = "Awesome! One more stop — a teahouse is highlighted for you!",
        anchor = "tour",
        advanceOn = "modelArrival",
    },
    {
        id = "modelHome",
        event = "modelArrival",
        -- "20 points" mirrors PRICES.starter in server/src/economy.ts — a price change there
        -- must update the copy here too (see the matching comment on that constant).
        copy = "A small teahouse of your own costs 20 points.",
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
