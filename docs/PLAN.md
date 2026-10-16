# Implementation Plan + Task List — Pantai Mancing Nusantara

Status fase & bukti verifikasi: `docs/PROGRESS.md`. Aturan: `AGENTS.md`. Desain: `docs/GDD.md`.
Dokumen ini adalah **kontrak** antar-modul: nama file, API publik, Remote, Signal, skema data, dan kontrak dunia.

## 0. Keputusan dasar

| Hal | Keputusan |
|---|---|
| Sinkronisasi | Script Sync (default) atau Rojo 7.7.1 (`default.project.json`). `scripts/build.ps1` menghasilkan `build/PantaiMancing.rbxl` yang langsung bisa di-Play. |
| Verifikasi tanpa Studio | `scripts/check.ps1` (luau-lsp 1.70.1 strict + definisi Roblox resmi), `scripts/test.ps1` (Lune 0.10.5 menjalankan spesifikasi yang sama dengan SelfTest), `scripts/build.ps1`. |
| Verifikasi dengan Studio | MCP bawaan Studio (`.mcp.json` → `mcp.bat`), atau jembatan `python scripts/studio_mcp.py`. |
| Data | ProfileStore (commit `45c9847`, Apache-2.0). Mock otomatis bila Studio tanpa akses API. |
| Arah visual dunia | Stylized tropis membulat (dikonfirmasi pemilik 2026-10-16). Lihat `docs/UI-DIRECTION.md`. |
| Target perangkat | Rilis publik: HP, tablet, PC, konsol setara. |
| API deprecated di spek | `CreateHumanoidModelFromDescription` → `CreateHumanoidModelFromDescriptionAsync`; `ApplyDescription` → `ApplyDescriptionAsync`. |
| "Joran ke-5" (GDD 4.2) | Ditafsirkan sebagai joran ke-5 yang **dibeli**: Legenda Nusantara (bambu → fiber → karbon → samudra → legenda). Emas Bahari adalah jalur barter sampingan. BalanceSim melaporkan keduanya. |
| Quest cerita | Diterima di Pak Lurah (tanda "!" bila ada quest siap diterima); hadiah otomatis saat selesai; quest berikutnya siap diterima. Quest 1 selesai saat diterima (bicara). |
| Ikan Protected | Masuk tas (dapat XP + Fishdex), tidak bisa dijual/ditukar/dibarter; popup & tas punya tombol "Lepaskan". |
| Rata-rata berat (harga) | `(min + max) / 2`. |
| Malam | ClockTime ≥ 18,5 atau < 5,5. Satu hari game 15 menit; mulai ClockTime 14. |

## 1. Struktur folder final

```
E:\roblox\                      (root proyek = "pantai-mancing")
├─ AGENTS.md  CLAUDE.md  PRODUCT.md  README.md  default.project.json  rokit.toml  selene.toml  stylua.toml  .luaurc
├─ .claude/       settings.json, skills/, commands/, agents/, hooks/   (alur kerja Claude Code)
├─ .mcp.json      server MCP Roblox_Studio
├─ docs/          GDD.md  PLAN.md  PROGRESS.md  TESTING.md  UI-DIRECTION.md  licenses/
├─ scripts/       setup-tools.ps1  check.ps1  build.ps1  test.ps1  api.sh  studio_mcp.py  bake-command.luau  lune/run.luau
├─ ServerScriptService/
│  ├─ Main.server.luau
│  ├─ Services/   DataService EconomyService InventoryService WorldService NPCService LevelService
│  │              ConservationService FishingService ShopService SellService BarterService FishdexService
│  │              FerryService CosmeticService TradeService QuestService AchievementService
│  │              LeaderboardService DebugService
│  ├─ World/      MapBuilder MapConfig Geo Terrain Plaza Pier Palms Mangroves Boats Pinisi Lighthouse
│  │              BeachProps Underwater Zones Lighting
│  ├─ Packages/   ProfileStore
│  └─ Tests/      SelfTest.server.luau  TestRunner  BalanceSim  Specs/*
├─ ReplicatedStorage/Shared/
│  ├─ Config/     Fish Rods Bait Bags Cosmetics Zones NPCs Quests Achievements Barter Balance Sounds Theme Strings
│  ├─ Models/     FishModel RodModel BobberModel CosmeticModels
│  ├─ Util/       Signal Trove RateLimiter WeightedRandom Format TweenUtil Guard
│  └─ Net  Types  Formulas  ProfileSchema  TradeLogic
└─ StarterPlayerScripts/
   ├─ Main.client.luau
   ├─ Controllers/ DataController UIController HUDController InputController FishingController
   │               MinigameController CatchPopupController ShopController BagController SellController
   │               BarterController TradeController QuestController FishdexController DialogController
   │               NotificationController AmbientController WeatherFXController DayNightController
   │               SoundController SettingsController FerryController NPCController
   └─ UI/          Style Icon Button IconButton Modal Tabs ItemCard StatRow ProgressBar Toast ConfirmDialog
                   ViewportPreview QuantityPicker Slider Toggle
```
Tambahan dibanding spek (boleh ditambah): Util/Guard, ProfileSchema, TradeLogic, World/Geo, DataController,
CatchPopupController, FerryController, NPCController, UI/Style, UI/Icon, UI/Slider, UI/Toggle.

## 2. Lapisan service & aturan require (anti-siklus)

Service hanya me-require service di lapisan **lebih rendah** di top-level modul. Komunikasi ke atas lewat Signal.

| Lapisan | Service |
|---|---|
| L0 | DataService |
| L1 | EconomyService, InventoryService, WorldService, NPCService |
| L2 | LevelService, ConservationService |
| L3 | FishingService |
| L4 | ShopService, SellService, BarterService, FishdexService, FerryService, CosmeticService, TradeService |
| L5 | QuestService, AchievementService, LeaderboardService |
| L6 | DebugService |

Client: DataController (L0) → UIController/Settings/Notification/Sound (L1) → controller lain. Controller
saling memanggil hanya ke lapisan yang lebih rendah; ke atas lewat Signal.

## 3. Modul server & API publik

Semua service: `Init()` (tanpa yield) dan `Start()`.

- **DataService** — ProfileStore + mock, remote `GetInitialData` & `SaveSettings`. `GetData(player): ProfileData?`, `WaitForData(player, timeout): ProfileData?`,
  `IsMock(): boolean`, `Replicate(player, ...keys: string)` (kirim `DataChanged("Set", {key=value})`),
  `FishAdded(player, fish)`, `FishRemoved(player, uids)`, `FishUpdated(player, fish)`, `Save(player)`.
  Signal: `ProfileLoaded(player, data)`, `ProfileReleasing(player, data)`. Remote: `GetInitialData`.
  Leaderstats "Koin" & "Level" dibuat di sini dan disinkronkan oleh Economy/Level.
- **EconomyService** — `Get(player)`, `Add(player, amount, reason, opts?) -> boolean`, `TrySpend(player, amount, reason) -> boolean`.
  Koin tidak pernah negatif; setiap mutasi masuk `CoinLog` (30 terakhir). Alasan berawalan `trade:` tidak dihitung
  sebagai pendapatan (`Stats.TotalEarned`). Signal: `CoinsChanged(player, newValue, delta, reason)`,
  `Earned(player, amount, reason)`.
- **InventoryService** — `AddFish(player, item) -> boolean`, `RemoveFish(player, uids) -> {FishItem}`,
  `FindFish(player, uid)`, `FishCount(player)`, `IsBagFull(player)`, `SetLock(player, uid, locked)`,
  `AddBait(player, id, qty)`, `ConsumeBait(player, id, qty) -> boolean`, `GiveRod(player, id)`, `HasRod`,
  `GiveCosmetic(player, id)`, `HasCosmetic`, `SetBagCapacity(player, cap)`, `NewUid()`.
  Remote: `SetFishLock`. Signal: `CosmeticGranted(player, id)`.
- **WorldService** — memastikan map (`World/MapBuilder.EnsureBuilt`), siang–malam, cuaca, event, zona.
  `GetClockTime()`, `IsNight()`, `GetWeather(): WeatherId`, `GetEvent(): EventId`, `GetZoneAt(pos): string?`,
  `GetPoint(name): CFrame?`, `SetWeather(id, duration?)`, `StartEvent(id, duration?)`, `SetClockTime(t)`,
  `MapReady: Signal<>`, `IsMapReady()`. Atribut di ReplicatedStorage: `DayRefTime`, `DayRefClock`, `DayLength`,
  `Weather`, `WeatherEndsAt`, `Event`, `EventEndsAt`.
- **NPCService** — membangun NPC dari `NPCs` + penanda `NPCSpawn_<Id>`. `GetNpcCFrame(id)`,
  `IsNear(player, npcId, range?) -> boolean`. Remote keluar: `OpenNpc(npcId)`. Signal: `Talked(player, npcId)`.
  Ambient NPC mendapat ember bertag `FishBucket` (atribut `NpcId`) bila pose Fishing.
- **LevelService** — `AddXP(player, amount, reason)`, `GetLevel(player)`, nametag "Lv N · Nama" + gelar (dipakai
  CosmeticService). Remote keluar: `LevelUp(level, coins)`. Signal: `LevelChanged(player, level, oldLevel)`.
- **ConservationService** — Remote `ReleaseFish(uids)`. `AddPoints(player, n, reason)`, `TrySpendPoints(player, n, reason)`.
  Signal: `Released(player, item, species, points)`, `PointsChanged(player, value)`.
- **FishingService** — state machine per pemain (Idle→Casting→Waiting→Bite→Reeling→Idle), Tool joran, pelampung,
  Beam tali. Remote masuk: `CastLine(power, dirX, dirZ)`, `HookFish(sessionId)`, `ReelFinished(sessionId, success)`,
  `CancelFishing()`. Remote keluar: `FishingEvent(kind, data)` dengan kind `Casted|Bite|Reel|Caught|Escaped|Cancelled`.
  `IsFishing(player)`, `Cancel(player, reason)`, `RefreshRod(player)`. Signal: `FishCaught(player, item, species, ctx)`,
  `BaitUsed(player, baitId)`, `CastStarted(player)`.
- **ShopService** — Remote `Purchase(npcId, category, itemId, qty?)` (qty umpan 1/10/50, 0 = maks).
  Signal: `Purchased(player, category, itemId, qty, price, currency)`.
- **SellService** — Remote `SellFish(npcId, mode, arg)` (`Selected` + {uid} | `AllUnlocked` | `Rarity` + rarity).
  Signal: `Sold(player, coins, count, npcId)`.
- **BarterService** — Remote `BarterPreview(recipeId) -> BarterPreview`, `BarterExecute(recipeId) -> (ok, msg)`.
  Signal: `Bartered(player, recipeId)`.
- **FishdexService** — mendengar `FishCaught` → `Record(player, species, weight)` (juga dipakai `/semua`). Remote
  `ClaimFishdex(zoneId)`. `ZoneComplete(player, zoneId)`, `DiscoveredCount(player)`. Signal: `Discovered(player,
  speciesId)`, `ZoneCompleted(player, zoneId)`.
- **FerryService** — Remote `FerryTravel(destination)` (`DeepSea` dari Nahkoda Jaka, `Shore` dari Awak Kapal).
  Remote keluar `FerryEvent(kind, data)`. Signal: `Traveled(player, destination)`.
- **CosmeticService** — Remote `Equip(slot, itemId)` untuk Rod/Bait/7 slot kosmetik (string kosong = lepas);
  menerapkan kosmetik ke karakter (Accessory via `Humanoid:AddAccessory`, Trail, Aura), nametag + gelar, skin joran &
  pelampung (dibaca FishingService dari data). Mendengar `LevelChanged`.
- **TradeService** — undangan (≤ 30 stud, kedaluwarsa 20 dtk, cooldown 10 dtk), ProximityPrompt "Ajak Tukar" di
  karakter, sesi `TradeLogic`, hitung mundur 5 dtk, validasi ulang `Formulas.ValidateTrade`, tukar atomik, simpan,
  log. Remote: `TradeInvite`, `TradeRespond`, `TradeUpdateOffer`, `TradeSetReady`, `TradeCancel`, keluar `TradeEvent`.
- **QuestService** — cerita & harian (reset 00:00 WIB). Remote `AcceptStoryQuest()`. Mendengar Fishing, Shop, Sell,
  Conservation, NPC, Ferry, Fishdex. Signal: `QuestCompleted(player, questId, kind)`.
- **AchievementService** — mendengar Fishing, Economy, Conservation, Fishdex; memberi gelar via Inventory.
- **LeaderboardService** — OrderedDataStore `Heaviest`/`TotalCoins`, refresh 5 menit, SurfaceGui di papan plaza;
  nonaktif + tulisan "Papan peringkat aktif setelah dipublish" di mode mock.
- **DebugService** — hanya `RunService:IsStudio()`: TextChatCommand `/koin n`, `/level n`, `/cuaca id`, `/event id`,
  `/waktu jam`, `/isitas`, `/semua [paksa]` (buka semua untuk uji; di luar mode uji wajib `paksa`). Juga
  `ServerStorage.Debug` (BindableFunction, hanya Studio) untuk konsol F9 tab Server.

## 4. Remote (semua didefinisikan di `Shared/Net.luau`)

| Nama | Arah | Jenis | Payload → hasil |
|---|---|---|---|
| GetInitialData | C→S | Function | () → `Snapshot?` (nil bila profil belum siap) |
| DataChanged | S→C | Event | (`"Set"`, {Key=value}) · (`"FishAdd"`, FishItem) · (`"FishRemove"`, {uid}) · (`"FishUpdate"`, FishItem) |
| Notify | S→C | Event | (kind: `Info|Success|Warning|Error|Reward|Achievement|Event`, text) |
| CastLine | C→S | Event | (power 0..1, dirX, dirZ) |
| HookFish | C→S | Event | (sessionId) |
| ReelFinished | C→S | Event | (sessionId, success) |
| CancelFishing | C→S | Event | () |
| FishingEvent | S→C | Event | (`Casted`, {SessionId, LandPos, FlightTime, Zone}) · (`Bite`, {SessionId, Window}) · (`Reel`, MinigameParams) · (`Caught`, CatchInfo) · (`Escaped`, {Reason}) · (`Cancelled`, {Reason}) |
| Purchase | C→S | Function | (npcId, category `Rod|Bait|Bag|Cosmetic`, itemId, qty?) → (ok, msg) |
| Equip | C→S | Function | (slot `Rod|Bait|Hat|Accessory|RodSkin|Bobber|Trail|Aura|Title`, itemId) → (ok, msg) |
| SellFish | C→S | Function | (npcId, mode, arg) → (ok, msg, coins) |
| ReleaseFish | C→S | Function | ({uid}) → (ok, msg, points) |
| SetFishLock | C→S | Function | (uid, locked) → ok |
| BarterPreview | C→S | Function | (recipeId) → BarterPreview |
| BarterExecute | C→S | Function | (recipeId) → (ok, msg) |
| AcceptStoryQuest | C→S | Function | () → (ok, msg) |
| ClaimFishdex | C→S | Function | (zoneId) → (ok, msg) |
| FerryTravel | C→S | Function | (destination `DeepSea|Shore`) → (ok, msg) |
| SaveSettings | C→S | Function | ({Music, Sfx, LowGfx, UiScale}) → ok |
| OpenNpc | S→C | Event | (npcId) |
| LevelUp | S→C | Event | (level, coins) |
| FerryEvent | S→C | Event | (`Depart`, {Destination}) · (`Arrive`, {Destination}) |
| TradeInvite | C→S | Function | (targetUserId) → (ok, msg) |
| TradeRespond | C→S | Function | (inviteId, accept) → (ok, msg) |
| TradeUpdateOffer | C→S | Function | (TradeOffer) → (ok, msg) |
| TradeSetReady | C→S | Function | (ready) → (ok, msg) |
| TradeCancel | C→S | Function | () → (ok, msg) |
| TradeEvent | S→C | Event | (`Invite`, {InviteId, FromUserId, FromName, ExpiresAt}) · (`Open`/`State`, TradeView) · (`Completed`, {}) · (`Cancelled`, {Reason}) |

Rate limit token bucket per remote ada di `Net.Specs`.

## 5. Skema data pemain (`Shared/ProfileSchema.luau`, Version 1)

`Coins=50, Level=1, XP=0, ConservationPoints=0, BagCapacity=20, Fish={FishItem}, Rods={"bambu"}, EquippedRod="bambu",
Bait={[id]=qty}, EquippedBait="", Cosmetics={Owned={[id]=true}, Equipped={Hat,Accessory,RodSkin,Bobber,Trail,Aura,Title}},
Quests={StoryIndex, StoryProgress, StoryAccepted, DailyDay, Daily={{Id,Progress,Done}}}, Fishdex={[id]={Count,BestWeight,FirstAt}},
FishdexClaimed={[zone]=true}, Achievements={[id]=unix}, Stats={TotalCaught, TotalEarned, TotalReleased, HeaviestKg,
TotalConservation, TotalSold, MutatedCaught}, BarterOnce={[recipe]=true}, Settings={Music, Sfx, LowGfx, UiScale},
LastLogin, CoinLog={{T,D,R}}, TradeLog={{Id,T,With,Gave,Got}}`. String kosong = slot kosong.

## 6. Kontrak dunia (`Workspace.BeachMap`)

| Path | Isi |
|---|---|
| `BeachMap.Spawn` | SpawnLocation (0, 7, −40) menghadap +Z, Neutral, tanpa ForceField |
| `BeachMap.FishingZones/FishingZone_<ZoneId>` | Part tak terlihat (Transparency 1, CanCollide/CanQuery/CanTouch false), atribut `ZoneId` |
| `BeachMap.NPCSpawns/NPCSpawn_<NpcId>` | Part penanda tak terlihat; CFrame = posisi kaki + arah hadap NPC |
| `BeachMap.Points/<Nama>` | Part penanda: `FerryArrival_DeepSea`, `FerryArrival_Shore`, `Leaderboard_Heaviest`, `Leaderboard_Coins` (permukaan depan = SurfaceGui) |
| `BeachMap.AmbientPoints/*` | Part penanda dengan atribut `Kind` (`Seagulls`, `Crabs`, `FishSchool`, `Fireflies`) dan `Radius` |
| `BeachMap.Boundary` | Dinding tak terlihat radius 1.150 |
| Tag `Bobbing` | Model perahu/pinisi/feri/pelampung; atribut opsional `Amplitude`, `Speed`, `Phase`, `Tilt` |
| Tag `Flicker` | Part/Light lentera & api unggun (client memvariasikan Brightness) |
| Tag `NightLight` | Light yang menyala hanya malam (lampu taman, mercusuar, lentera) |
| Tag `Spin` | Model lampu mercusuar; atribut `SpinSpeed` (derajat/dtk) |
| Tag `Seagull` / `Crab` | Dibuat client oleh AmbientController di sekitar AmbientPoints (bukan bagian map) |

Model NPC & kios: `ModelStreamingMode = Persistent`. Part dekorasi: Anchored, tanpa collision/query/touch bila tidak perlu.

## 7. Fase & Task List

- [x] **Fase 0 Fondasi** — struktur, AGENTS/CLAUDE/PRODUCT/docs, `.claude/`, toolchain & skrip, Util, Types, Net,
  Formulas, ProfileSchema, TradeLogic, semua Config, Main server/client, TestRunner + Specs (Lune 178/178).
  Studio: panduan Script Sync + skrip uji cetak (menunggu MCP).
- [ ] **Fase 1 Map** — Terrain (pulau, pasir, laguna, kanal, batu), plaza & kios, dermaga T, gubuk barter, dermaga
  kapal, platform Laut Dalam, mercusuar, pinisi, jukung, kelapa (Poisson-disk), bakau, properti santai, bawah laut,
  jalur & papan arah, zona, titik NPC, batas dunia, Lighting. Bake + review 6 sudut.
- [ ] **Fase 2 Data & ekonomi** — DataService, Economy, Inventory, leaderstats, DataController, UIController, HUD dasar, toast.
- [ ] **Fase 3 Memancing** — RodModel/BobberModel/FishModel, FishingService, Input/Fishing/Minigame/CatchPopup controller.
- [ ] **Fase 4 NPC & toko** — NPCService, Dialog, Shop (joran/umpan/tas/kosmetik/poin), Sell, Cosmetic + equip.
- [ ] **Fase 5 RPG** — Level/XP + gating, Quest cerita & harian, Fishdex + hadiah, Achievement → gelar, Konservasi.
- [ ] **Fase 6 Dunia hidup** — siang–malam, cuaca + FX, event, kapal, ambient, suara, papan peringkat.
- [ ] **Fase 7 Barter & trade** — BarterService/Controller, TradeService/Controller + log + peringatan timpang.
- [ ] **Fase 8 Polish** — mobile/gamepad, pengaturan + grafis rendah, performa, BalanceSim + penyetelan, SelfTest lengkap, README final.

## 8. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| MCP Studio belum terhubung → tidak ada bukti eksekusi | Verifikasi statis + Lune; `.mcp.json` + `scripts/studio_mcp.py`; laporan memisahkan "dicek statis" vs "dieksekusi". |
| Build map saat runtime lambat (terrain besar) | Laut = `FillBlock` besar; `WriteVoxels` hanya area pulau/lereng per chunk 64³; `task.wait()` antar chunk; CharacterAutoLoads ditahan sampai siap. |
| Jumlah part > 6.000 | Anggaran per modul (MapConfig.Budget) + hitungan dicetak MapBuilder; detail kecil `CastShadow=false`. |
| Exploit (klaim minigame, harga, trade) | Server memutuskan; validasi berlapis + rate limit; durasi minimum minigame; trade atomik tanpa yield. |
| Kehilangan data | ProfileStore session lock; `EndSession` saat keluar; BindToClose ditangani ProfileStore. |
| Solver tipe baru melebarkan singleton | Cast eksplisit di titik pakai (`x :: Rarity`); `pcall` pada fungsi `-> ...any`. |
| UI terpotong di ponsel 844×390 | Layout Scale + UISizeConstraint; UIScale global 0,75–1,25; uji Device Emulator. |
| API Roblox berubah | `scripts/api.sh` + luau-lsp mendeteksi API deprecated/hilang. |
