--!strict
-- SoundController: memutar suara dari Config/Sounds. ID kosong = diam tanpa error. Dua SoundGroup
-- (Musik & Efek) mengikuti pengaturan volume pemain.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local SoundController = {}

local musicGroup: SoundGroup? = nil
local sfxGroup: SoundGroup? = nil
local loops: { [string]: Sound } = {}
local rng = Random.new()

local function idOf(key: string): string
	local id = (Sounds.Ids :: any)[key]
	return if type(id) == "string" then id else ""
end

local function baseVolume(key: string): number
	local v = (Sounds.Volume :: any)[key]
	return if type(v) == "number" then v else 0.5
end

-- Memutar efek sekali. position (opsional) = suara 3D di dunia.
function SoundController.Play(key: string, pitchJitter: number?, position: Vector3?)
	local id = idOf(key)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = baseVolume(key)
	sound.SoundGroup = sfxGroup
	local jitter = pitchJitter or 0
	if jitter > 0 then
		sound.PlaybackSpeed = 1 + rng:NextNumber(-jitter, jitter)
	end
	if position then
		local att = Instance.new("Attachment")
		att.WorldPosition = position
		att.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 120
		sound.Parent = att
		sound.Ended:Once(function()
			att:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

-- Musik/ambience berulang (satu instance per kunci).
function SoundController.SetLoop(key: string, playing: boolean)
	local existing = loops[key]
	if not playing then
		if existing then
			existing:Stop()
		end
		return
	end
	if existing then
		if not existing.IsPlaying then
			existing:Play()
		end
		return
	end
	local id = idOf(key)
	if id == "" then
		return
	end
	local isMusic = table.find(Sounds.MusicKeys, key) ~= nil
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = baseVolume(key)
	sound.SoundGroup = if isMusic then musicGroup else sfxGroup
	sound.Parent = SoundService
	sound:Play()
	loops[key] = sound
end

function SoundController.SetVolumes(music: number, sfx: number)
	if musicGroup then
		musicGroup.Volume = math.clamp(music, 0, 1)
	end
	if sfxGroup then
		sfxGroup.Volume = math.clamp(sfx, 0, 1)
	end
end

function SoundController.Init()
	local m = Instance.new("SoundGroup")
	m.Name = "PMN_Musik"
	m.Volume = 0.6
	m.Parent = SoundService
	musicGroup = m
	local s = Instance.new("SoundGroup")
	s.Name = "PMN_Efek"
	s.Volume = 0.8
	s.Parent = SoundService
	sfxGroup = s
end

function SoundController.Start()
	SoundController.SetLoop("Music", true)
	SoundController.SetLoop("Waves", true)
end

return SoundController
