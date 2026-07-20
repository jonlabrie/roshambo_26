--!strict
-- Pure access decision for teahouse access control (2026-07-19). No Roblox datatypes -> Lune-tested.
-- isFriend is resolved on the Roblox server (viewer:IsFriendsWith(ownerId)) and passed in, so this
-- stays pure. The owner always passes their own gate.
local AccessPolicy = {}

function AccessPolicy.canEnter(
    mode: string,
    invited: { number },
    viewerId: number,
    ownerId: number,
    isFriend: boolean
): boolean
    if viewerId == ownerId then
        return true
    end
    if mode == "public" then
        return true
    elseif mode == "friends" then
        return isFriend
    elseif mode == "private" then
        for _, id in invited do
            if id == viewerId then
                return true
            end
        end
        return false
    end
    return false -- unknown mode: fail closed
end

return AccessPolicy
