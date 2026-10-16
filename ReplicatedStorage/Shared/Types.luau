--!strict
-- Tipe bersama server & client. Semua Config dan modul lain mengimpor tipe dari sini.
--
-- Catatan: tipe "enum" di bawah sengaja berupa alias `string`. Solver tipe Luau yang baru melebarkan
-- singleton union (mis. "Common" | "Rare") menjadi `string` saat nilainya melewati properti tabel modul,
-- sehingga union ketat menimbulkan error palsu lintas modul. Nilai yang valid didokumentasikan di sini,
-- divalidasi di server lewat Guard (allowlist Config) dan dicek otomatis oleh Tests/Specs/ConfigSpec.

-- "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type Rarity = string
-- "None" | "Berkilau" | "Albino" | "Emas" | "Pelangi"
export type Mutation = string
-- "Any" | "Day" | "Night"
export type TimeReq = string
-- "Cerah" | "Berawan" | "Hujan" | "Badai"
export type WeatherId = string
-- "None" | "JamEmas" | "MusimIkan" | "BulanPurnama"
export type EventId = string
-- "Ramping" | "Gemuk" | "Pipih" | "Belut" | "Paruh" | "Kepiting" | "Cumi" | "Lobster" | "Naga" | "Kristal"
export type FishShape = string
-- "Hat" | "Accessory" | "RodSkin" | "Bobber" | "Trail" | "Aura" | "Title"
export type CosmeticSlot = string
-- "Starter" | "Shop" | "Points" | "Barter" | "Quest" | "Achievement" | "Fishdex"
export type ItemSource = string

export type FishSpecies = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	Zones: { string },
	Time: TimeReq,
	Weather: WeatherId?,
	Event: EventId?,
	MinWeight: number,
	MaxWeight: number,
	BasePrice: number,
	Protected: boolean?,
	ProtectedPoints: number?,
	Shape: FishShape,
	Primary: Color3,
	Secondary: Color3,
	Hint: string,
	Fact: string?,
	SpawnWeight: number?,
}

export type FishItem = {
	Uid: string,
	SpeciesId: string,
	Weight: number,
	Mutation: Mutation,
	Zone: string,
	CaughtAt: number,
	Locked: boolean,
}

export type RodDef = {
	Id: string,
	Name: string,
	Price: number?,
	Level: number,
	Luck: number,
	WaitMul: number,
	Control: number,
	ReelSpeed: number,
	MaxWeight: number,
	CastDistance: number,
	MutationMul: number?,
	Source: ItemSource,
	Order: number,
	Description: string,
	Colors: { Shaft: Color3, Grip: Color3, Accent: Color3 },
	Material: Enum.Material,
}

export type BaitDef = {
	Id: string,
	Name: string,
	Price: number?,
	Luck: number,
	WaitMul: number,
	NightLuck: number?,
	MutationMul: number?,
	Source: ItemSource,
	Order: number,
	Description: string,
	Color: Color3,
}

export type BagTier = {
	Capacity: number,
	Price: number,
}

export type CosmeticDef = {
	Id: string,
	Name: string,
	Slot: CosmeticSlot,
	Price: number?,
	PointsPrice: number?,
	Source: ItemSource,
	Order: number,
	Description: string,
	Style: string,
	Colors: { Color3 },
	NightOnly: boolean?,
}

export type ZoneDef = {
	Id: string,
	Name: string,
	Level: number,
	Order: number,
	FishdexReward: number,
	FishdexTitle: string,
	Description: string,
	LuckBonus: number?,
}

-- "Quest" | "ShopFishing" | "ShopCosmetic" | "Buyer" | "Barter" | "FerryOut" | "FerryBack" | "Conservation" | "Fishdex" | "Ambient"
export type NpcRole = string

-- "Caping" | "Celemek" | "TopiKapten" | "TopiRanger" | "Kacamata" | "Peci" | "Topi" | "None"
export type NpcOutfit = string

export type NpcDef = {
	Id: string,
	Name: string,
	Title: string,
	Role: NpcRole,
	Greeting: string,
	Lines: { string }?,
	Skin: Color3,
	Shirt: Color3,
	Pants: Color3,
	Outfit: { NpcOutfit },
	Pose: string, -- "Idle" | "Fishing" | "Sitting" | "Lounging"
	Menu: { string }?,
	ShopCategories: { string }?,
}

-- "TalkNpc" | "BuyBait" | "CatchFish" | "SellCoins" | "BuyCosmetic" | "CatchInZone" | "DiscoverSpecies" | "Ferry"
-- | "ReleaseProtected" | "CatchRarity" | "CatchRarityAtLeast" | "CatchWeightAtLeast" | "CatchAtNight" | "UseBait"
-- | "ReleaseFish" | "CatchMutated"
export type QuestObjectiveType = string

export type QuestObjective = {
	Type: QuestObjectiveType,
	Count: number,
	Npc: string?,
	Bait: string?,
	Zone: string?,
	Rarity: Rarity?,
	Weight: number?,
	Destination: string?,
}

export type QuestReward = {
	Coins: number?,
	XP: number?,
	Title: string?,
	ConservationPoints: number?,
}

export type QuestDef = {
	Id: string,
	Title: string,
	Description: string,
	Objective: QuestObjective,
	Reward: QuestReward,
	Level: number?,
}

export type DailyQuestDef = {
	Id: string,
	Title: string,
	Objective: QuestObjective,
}

export type AchievementDef = {
	Id: string,
	Name: string,
	Description: string,
	Title: string,
	Stat: string, -- "TotalCaught" | "FishdexZone" | "CaughtMutation" | "TotalEarned" | "TotalConservation" | "CaughtSpecies"
	Count: number,
	Arg: string?,
}

export type BarterRecipe = {
	Id: string,
	Name: string,
	Description: string,
	Rarity: Rarity,
	Count: number,
	Coins: number?,
	Level: number?,
	Once: boolean?,
	ExcludeProtected: boolean,
	GiveBait: string?,
	GiveBaitQty: number?,
	GiveRod: string?,
	GiveCosmetic: string?,
	Order: number,
}

export type DailyQuestState = {
	Id: string,
	Progress: number,
	Done: boolean,
}

export type QuestState = {
	StoryIndex: number,
	StoryProgress: number,
	StoryAccepted: boolean,
	DailyDay: number,
	Daily: { DailyQuestState },
}

export type FishdexEntry = {
	Count: number,
	BestWeight: number,
	FirstAt: number,
}

export type CosmeticEquipped = {
	Hat: string,
	Accessory: string,
	RodSkin: string,
	Bobber: string,
	Trail: string,
	Aura: string,
	Title: string,
}

export type ProfileStats = {
	TotalCaught: number,
	TotalEarned: number,
	TotalReleased: number,
	HeaviestKg: number,
	TotalConservation: number,
	TotalSold: number,
	MutatedCaught: number,
}

export type PlayerSettings = {
	Music: number,
	Sfx: number,
	LowGfx: boolean,
	UiScale: number,
}

export type CoinLogEntry = {
	T: number,
	D: number,
	R: string,
}

export type TradeLogEntry = {
	Id: string,
	T: number,
	With: number,
	Gave: string,
	Got: string,
}

export type ProfileData = {
	Version: number,
	Coins: number,
	Level: number,
	XP: number,
	ConservationPoints: number,
	BagCapacity: number,
	Fish: { FishItem },
	Rods: { string },
	EquippedRod: string,
	Bait: { [string]: number },
	EquippedBait: string,
	Cosmetics: { Owned: { [string]: boolean }, Equipped: CosmeticEquipped },
	Quests: QuestState,
	Fishdex: { [string]: FishdexEntry },
	FishdexClaimed: { [string]: boolean },
	Achievements: { [string]: number },
	Stats: ProfileStats,
	BarterOnce: { [string]: boolean },
	Settings: PlayerSettings,
	LastLogin: number,
	CoinLog: { CoinLogEntry },
	TradeLog: { TradeLogEntry },
}

export type Snapshot = {
	Data: ProfileData,
	IsMock: boolean,
	ServerNow: number,
}

-- Konteks lingkungan saat roll ikan (dihitung server).
export type RollContext = {
	Zone: string,
	IsNight: boolean,
	Weather: WeatherId,
	Event: EventId,
	Luck: number,
	MutationMul: number,
}

export type CatchInfo = {
	Fish: FishItem,
	IsNew: boolean,
	Price: number,
	XP: number,
	Protected: boolean,
	Points: number,
	Hard: boolean,
}

export type MinigameParams = {
	SessionId: string,
	Seed: number,
	Pattern: Rarity,
	Hard: boolean,
	Control: number,
	ReelSpeed: number,
	StartProgress: number,
	Gain: number,
	Loss: number,
	TimeLimit: number,
}

export type TradeOffer = {
	Fish: { string },
	Bait: { [string]: number },
	Coins: number,
}

export type TradeSide = {
	UserId: number,
	Name: string,
	Offer: TradeOffer,
	Ready: boolean,
	Value: number,
	FishItems: { FishItem },
}

export type TradeView = {
	Id: string,
	A: TradeSide,
	B: TradeSide,
	CountdownEndsAt: number?,
	Warning: string?,
}

export type BarterPreview = {
	Ok: boolean,
	Reason: string?,
	Fish: { FishItem },
	Coins: number,
}

return {}
