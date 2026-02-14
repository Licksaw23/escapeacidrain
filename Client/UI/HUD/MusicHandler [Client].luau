-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries
local orderRemote = RS.Remotes.Order
local spawnRemote = RS.Remotes.Spawn
local NewTS = require(Utilities.Tweener)
-- modules --
local Spring = require(Utilities.Tweener.Spring)
local ItemLibrary = require(Libraries.ItemsData)
local flowUtil = require(Utilities.flowUtil)
local ViewportFitter = require(Utilities.ViewportFitter)
local LerpMover = require(Utilities.LerpMover)
local MutationsData = require(Libraries.MutationsData)
local CalculateMoney = require(Utilities.Calculator)
local GetScale = require(script.Parent.Parent.Parent.Handlers.VFX.Scale)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local VFX = require(script.Parent.Parent.Parent.Handlers.VFX)
local Zone = require(Utilities.Zone)
local NumberShortener = require(Utilities.NumberShortener)
-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data
local module = {}
repeat task.wait() until Player:GetAttribute("CPS")
local Plot = Player:GetAttribute("Plot")
local PlotFolder = workspace.Plots[Plot]
local CPSUI = Player.PlayerGui.MainUI:WaitForChild("CashPerSecond")
local brainrotZone = Zone.new(PlotFolder.CPSZone)


-- u can prob add support for changing music here for different events / themes later, for nwo it will just laod default

-- ^ by support i mean fading out / into new music, and playing new music entirely sinceyou can just update the soundID


local soundService = game:GetService("SoundService")
soundService.Music:Play()



return module