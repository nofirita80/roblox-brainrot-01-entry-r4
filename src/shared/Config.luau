-- Config: every tunable number for Steal a Snackrot in one place.
-- The server modules and the client UI all read from here, so a
-- balance change only ever touches this file.

local Config = {}

-- Money
Config.StartCash = 100 -- cash a new player spawns with
Config.MaxCash = 100000000 -- sanity cap on a leaderstats value

-- Map
Config.PlotCount = 6 -- player bases around the conveyor
Config.SlotsPerBase = 8 -- character slots in each base
Config.PlotRadius = 42 -- distance from the map center to a plot
Config.PlotSize = Vector3.new(24, 1, 18) -- the base platform

-- Conveyor: a rectangular loop. Characters walk its edges and
-- despawn after one full lap or after ConveyorLifetime seconds.
Config.ConveyorHalf = 18 -- half side of the rectangular loop
Config.ConveyorHeight = 2 -- the track's top surface (y)
Config.ConveyorSpeed = 8 -- studs per second
Config.ConveyorLifetime = 90 -- seconds before an unclaimed one despawns
Config.SpawnInterval = 4 -- seconds between spawns

-- Base lock: the owner can lock their base for this long, then the
-- button needs LockCooldown seconds before it works again.
Config.LockDuration = 60
Config.LockCooldown = 120

-- Steal and slap
Config.SlapRange = 9 -- studs; how close a thief must be to be slapped
Config.SlapCooldown = 1 -- seconds between slaps
Config.SlapImpulse = 60 -- knockback strength
Config.CarryHeight = 4 -- studs above the carrier's head while carried

-- Shop: two real items, both bought with Cash.
Config.Shop = {
	{
		Id = "boost",
		Name = "Spawn Boost",
		Description = "Next character on the conveyor is Epic or better.",
		Cost = 500,
	},
	{
		Id = "coil",
		Name = "Speed Coil",
		Description = "+50% walk speed for 60 seconds.",
		Cost = 1000,
		Duration = 60,
	},
}

-- Walk speeds
Config.NormalWalkSpeed = 16
Config.CoilWalkSpeed = 24

-- Find a shop item by id, or nil.
function Config.GetShopItem(id)
	for _, item in ipairs(Config.Shop) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

-- Income tick
Config.IncomeTick = 1 -- seconds between income payouts

return Config
