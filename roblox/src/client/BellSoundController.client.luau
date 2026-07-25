--!strict
-- Plays the recorded Byōdō-in bonshō strike on the `gongHit` cue (the shu-moku's
-- contact moment — see HammerController). Each strike clones a fresh one-shot
-- Sound parented to the bell body, so ring tails overlap naturally if the round
-- cadence ever outruns the 20s ring; 3D rolloff carries it up-canyon (the source
-- is pre-filtered to a distant timbre, so near and far both read).
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local stage = workspace:WaitForChild("RoshamboStage")
local bell = stage:WaitForChild("BonshoBell")
local bellBody = bell:WaitForChild("BellBody") :: BasePart

local BELL_SOUND_ID = "rbxassetid://108417212310624"
local BELL_VOLUME = 1.0
local ROLLOFF_MIN = 70 -- full volume across the square; ~15-20% at the far west pads
local ROLLOFF_MAX = 2000

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind ~= "gongHit" then
        return
    end
    local s = Instance.new("Sound")
    s.SoundId = BELL_SOUND_ID
    s.Volume = (stage:GetAttribute("BellVolume") :: number?) or BELL_VOLUME
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = (stage:GetAttribute("BellRollOffMin") :: number?) or ROLLOFF_MIN
    s.RollOffMaxDistance = ROLLOFF_MAX
    s.Parent = bellBody
    s:Play()
    s.Ended:Once(function()
        s:Destroy()
    end)
    task.delay(25, function()
        -- failsafe: a clone that never reaches Ended (decode hiccup) must not leak
        if s.Parent then
            s:Destroy()
        end
    end)
end)
