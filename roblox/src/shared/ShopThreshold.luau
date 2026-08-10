--!strict
-- AM I IN THE SHOP? Pure and Roblox-free (positions are plain {x,y,z} tables) so it runs under
-- Lune — the client controller converts Vector3 at the boundary.
--
-- This exists as its own module for one reason: no harness in this repo loads a `.client.luau`.
-- A rule embedded in the controller could not be tested at all, and the rule here is not
-- obvious — see FRONT_INSET.
local ShopThreshold = {}

export type Vec = { x: number, y: number, z: number }
export type Box = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number }

-- THE WHOLE DESIGN, IN ONE NUMBER. The shop's frontage is open — there is no door — so the
-- trigger volume starts one stud INSIDE the building rather than on the frontage line. A volume
-- flush with the frontage would fire on every player walking the promenade past the shop, and
-- "walk in, the panel opens" would become "cross the square, the panel flickers".
ShopThreshold.FRONT_INSET = 1

function ShopThreshold.isInside(pos: Vec, box: Box): boolean
    return pos.x >= box.x0
        and pos.x <= box.x1
        and pos.y >= box.y0
        and pos.y <= box.y1
        and pos.z >= box.z0
        and pos.z <= box.z1
end

return ShopThreshold
