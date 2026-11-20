-- CharacterData: the snack-brainrot roster for Steal a Snackrot.
-- Every character has a rarity, a claim cost, an income per second, a
-- display color, a size scale and a spawn weight. The spawner picks
-- characters by weight; the shop and the UI read the same table so the
-- numbers always agree.

local CharacterData = {}

CharacterData.List = {
	{
		Name = "Choco Croissant",
		Rarity = "Common",
		Cost = 100,
		Income = 2,
		Color = Color3.fromRGB(176, 124, 64),
		Accent = Color3.fromRGB(240, 205, 140),
		Scale = 1.0,
		Weight = 25,
	},
	{
		Name = "Boba Brain",
		Rarity = "Common",
		Cost = 250,
		Income = 5,
		Color = Color3.fromRGB(210, 160, 120),
		Accent = Color3.fromRGB(120, 70, 40),
		Scale = 1.0,
		Weight = 20,
	},
	{
		Name = "Pizza Pal",
		Rarity = "Rare",
		Cost = 600,
		Income = 12,
		Color = Color3.fromRGB(235, 170, 60),
		Accent = Color3.fromRGB(200, 60, 50),
		Scale = 1.1,
		Weight = 15,
	},
	{
		Name = "Donut Dude",
		Rarity = "Rare",
		Cost = 1200,
		Income = 25,
		Color = Color3.fromRGB(240, 150, 200),
		Accent = Color3.fromRGB(255, 240, 245),
		Scale = 1.1,
		Weight = 12,
	},
	{
		Name = "Sushi Sam",
		Rarity = "Epic",
		Cost = 3000,
		Income = 60,
		Color = Color3.fromRGB(250, 250, 250),
		Accent = Color3.fromRGB(230, 90, 90),
		Scale = 1.2,
		Weight = 10,
	},
	{
		Name = "Taco Titan",
		Rarity = "Epic",
		Cost = 7500,
		Income = 150,
		Color = Color3.fromRGB(240, 200, 80),
		Accent = Color3.fromRGB(90, 160, 70),
		Scale = 1.25,
		Weight = 7,
	},
	{
		Name = "Noodle Ninja",
		Rarity = "Legendary",
		Cost = 20000,
		Income = 400,
		Color = Color3.fromRGB(250, 220, 120),
		Accent = Color3.fromRGB(60, 60, 60),
		Scale = 1.35,
		Weight = 5,
	},
	{
		Name = "Ice Cream Imp",
		Rarity = "Legendary",
		Cost = 50000,
		Income = 1000,
		Color = Color3.fromRGB(255, 255, 255),
		Accent = Color3.fromRGB(150, 210, 255),
		Scale = 1.4,
		Weight = 3,
	},
	{
		Name = "Burger Boss",
		Rarity = "Mythic",
		Cost = 150000,
		Income = 3000,
		Color = Color3.fromRGB(160, 90, 40),
		Accent = Color3.fromRGB(250, 220, 90),
		Scale = 1.55,
		Weight = 2,
	},
	{
		Name = "Candy King",
		Rarity = "Mythic",
		Cost = 500000,
		Income = 10000,
		Color = Color3.fromRGB(255, 90, 180),
		Accent = Color3.fromRGB(255, 230, 90),
		Scale = 1.7,
		Weight = 1,
	},
}

-- Rarity display colors, used by the name tags and the UI.
CharacterData.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 180, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 60, 120),
}

-- Fast lookup by name.
local byName = {}
for _, entry in ipairs(CharacterData.List) do
	byName[entry.Name] = entry
end

function CharacterData.GetByName(name)
	return byName[name]
end

-- All characters of one rarity, for the UI and the shop.
function CharacterData.GetByRarity(rarity)
	local out = {}
	for _, entry in ipairs(CharacterData.List) do
		if entry.Rarity == rarity then
			table.insert(out, entry)
		end
	end
	return out
end

function CharacterData.Count()
	return #CharacterData.List
end

-- Total spawn weight, computed once.
local totalWeight = 0
for _, entry in ipairs(CharacterData.List) do
	totalWeight = totalWeight + entry.Weight
end

-- Pick one character by weight. When boosted is true, only Epic and
-- better rarities are in the pool (the shop's Spawn Boost).
function CharacterData.PickWeighted(boosted)
	local pool = {}
	local poolWeight = 0
	for _, entry in ipairs(CharacterData.List) do
		if not boosted
			or entry.Rarity == "Epic"
			or entry.Rarity == "Legendary"
			or entry.Rarity == "Mythic"
		then
			table.insert(pool, entry)
			poolWeight = poolWeight + entry.Weight
		end
	end
	local roll = math.random() * poolWeight
	local running = 0
	for _, entry in ipairs(pool) do
		running = running + entry.Weight
		if roll <= running then
			return entry
		end
	end
	return pool[#pool]
end

function CharacterData.TotalWeight()
	return totalWeight
end

return CharacterData
