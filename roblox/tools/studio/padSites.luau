--!strict
-- Surveyed cliff PadSpec(s) for the pad-system A<->B proof. Baked coordinates
-- (recipe rule: never depend on draft markers). mountCF is in Spec.cframe /
-- CFrame:GetComponents order (pos + row-major rotation); the datum plane is the
-- structure's floor-underside; footprint read from the teahouse-1story prefab's
-- Perim extents (tools/studio/captureTeahouseBase.luau).
--
-- cliff_proof: an empty promontory shelf (gapB, ~ -60,105) where the ground drops
-- toward the veranda (front -Z + right +X) and rises toward the cliff/back (+Z).
-- All 6 support posts hit terrain (back short, front long over the drop).
return {
	cliff_proof = {
		mountCF = { -60, 274, 105, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		hand = "right",
		footprint = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 },
	},
}
