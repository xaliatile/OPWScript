-- // This script will never be obfuscated by me \\--
const CloneReference = cloneref or clonereference
local ExecutorID = typeof(identifyexecutor) == "function" and identifyexecutor

if typeof(CloneReference) ~= "function" then
    warn(
        "Cannot load script, Executor doesnt support clonereference."
    )

    return
end

if typeof(ExecutorID) ~= "function" then
    warn(
        "Executor doesnt support identify executor, using fallback."
    )

    ExecutorID = "EX_UID"
else
    ExecutorID = ExecutorIDCallback()
end

--// Services \\--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService") 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

ReplicatedStorage = CloneReference(ReplicatedStorage)
UserInputService = CloneReference(UserInputService)
HttpService = CloneReference(HttpService)
RunService = CloneReference(RunService)
Players = CloneReference(Players)
CoreGui = CloneReference(CoreGui)

--// Variables \\--
const Player = CloneReference(
    Players.LocalPlayer
)

local Character = CloneReference(Player.Character or Player.CharacterAdded:Wait())
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

if Humanoid then Humanoid = CloneReference(Humanoid) end if HumanoidRootPart then HumanoidRootPart = CloneReference(HumanoidRootPart) end

const StateReplicators = ReplicatedStorage:WaitForChild("State Replicators")
const CompassVotes = StateReplicators:WaitForChild("Compass")
const RoundStats = StateReplicators:WaitForChild("Round")

const StructureFolder = workspace:WaitForChild("Structure")
const WaterLevel = workspace:WaitForChild("WaterLevel")

const Island = workspace:WaitForChild("Island")

local Script = {
    ScriptData = {
        Version = "1.0.0",
        ScriptGUID = HttpService:GenerateGUID(true),
        ScriptEnvironment = "__opScript",
        ScriptWatermark = "NDS Script | 10/26/26",
        ScriptPool = {},

        Executor = ExecutorID,
        Errors = {},

        IsUnloading = false,

        BootFinishTime = -1,
        BootTime = os.clock(),
        Debug = true,
    },

    Library = {
        __DO_NOT_RECURSIVE = true,

        LoadingBar = nil,
        KeybindList = nil,

        Notified = false,

        VibeUI = nil,
        LibraryFlags = nil,

        Window = nil,
        Tabs = nil
    },

    Instances = {
        WaterCollisionPart = nil,
        IslandHoverPart = nil,

        Externals = {
            WaterLevelPart = nil
        }
    },

    Configuration = {
        InputConfiguration = {},

        TeleportsConfiguration = {
            IslandTeleportPosition = CFrame.new(
                -116, 47, 2.5
            ),

            TowerTeleportPosition = CFrame.new(
                -280, 175, 341
            )
        },

        LibraryConfiguration = {
            DefaultWindowSize = UDim2.fromOffset(800, 552),
            MinimumWindowSize = Vector2.new(270, 150),
            WindowCustomCursor = true,
            WindowRounded = true,
            WindowGlass = true
        }
    },

	StateValues = {
        LastVelocityUpdate = os.clock(),
        InitialVelocity = HumanoidRootPart.AssemblyLinearVelocity,

        AnonymousReset = false,
        RecordedSurvivalTag = nil
	}
}

--// Script Utilities \\--
const function Output(Callback : any, ThreadTag : string, Message : string)
    local Success, Result = pcall(Callback, `[{Script.ScriptData.ScriptEnvironment} :: {ThreadTag}]: {Message}`)
    if not Success then
        Output(
            warn,
            "__output",
            `Failed to output, {Result}`
        )
    end
end

const function ProtectCallback(Callback, ThreadTag : string, PackArguments : boolean?, ... : any?)
    local Arguments = {...}
    local Success, Result = pcall(Callback, (PackArguments and Arguments or table.unpack(Arguments)))

    if not Success then
        Output(
            warn,
            `__protectCallback -> {ThreadTag}`,
            `Failed to protect callback for {ThreadTag}, {Result}`
        )

        table.insert(Script.ScriptData.Errors, {
            Result = Result,
            Success = Success
        })
    end

    return Success, Result
end

const function CheckInputEquality(NewInput : Enum.KeyCode | Enum.UserInputType, Input : Enum.KeyCode | Enum.UserInputType)
    local Success, Result = ProtectCallback(function()
        local InputEnumType = tostring(Input.EnumType)

        if NewInput[InputEnumType] == Input then
            return true
        else
            return false
        end
    end, "__checkInputEquality")

    if not Success then
        Result = Success
    end
    
    return Result
end

const function Decimate(Number : number, PlaceValues : number)
    if typeof(Number) ~= "number" or typeof(PlaceValues) ~= "number" then
        return
    end

    return math.floor(Number * PlaceValues) / PlaceValues
end

const function UnloadScript()
    pcall(function()
        Script.ScriptData.IsUnloading = true

        if Script.ScriptData.Debug then
            local ElapsedTime = (os.clock() - Script.ScriptData.BootTime)
            Output(
                print,
                "__unloadScript",
                `Unloading script ran for {
                    Decimate(ElapsedTime, 1000)
                } second(s) and experienced {#Script.ScriptData.Errors} Errors.`
            )
        end
        
        if Script and Script.Library and Script.Library.VibeUI then
            Script.Library.VibeUI:Unload()
        end

        for Idx, Entry in Script.ScriptData.ScriptPool do
            if typeof(Entry) == "string" then
                RunService:UnbindFromRenderStep(Entry)
            elseif typeof(Entry) == "RBXScriptConnection" then
                Entry:Disconnect()
            elseif typeof(Entry) == "Instance" then
                Entry:Destroy()
            elseif typeof(Entry) == "thread" then
                task.spawn(function()
                    while coroutine.status(Entry) ~= "suspended" do
                        pcall(task.cancel, Entry)
                    end
                end)
            end
        end

        local function EvaluateEntry(Entry : {any?}?, CallingMultEval : boolean?)
            if Entry then
                for Idx, TableEntry in Entry do
                    if typeof(TableEntry) == "table" and not TableEntry.__DO_NOT_RECURSIVE then
                        EvaluateEntry(TableEntry, true)
                    end

                    if CallingMultEval then
                        Entry[Idx] = nil
                    end
                end

                if CallingMultEval then
                    task.defer(table.clear, Entry)
                    Entry = nil
                end
            end
        end

        EvaluateEntry(Script)
        
        task.defer(function()
            table.clear(Script)
            Script = nil
        end)
    end)
end

const function HandlePropertiesOfDescendants(Type : "Set" | "Reset"?, Ancestor : Instance, Properties : {[any] : any?})
    ProtectCallback(function()
        if typeof(Ancestor) == "Instance" and typeof(Properties) == "table" then
            if Type == "Set" or not Type then
                for Property, Value in Properties do
                    if typeof(Ancestor[Property]) ~= "nil" then
                        Ancestor:SetAttribute(
                            Property, 
                            Ancestor[Property]
                        )

                        pcall(function()
                            Ancestor[Property] = Value
                        end)
                    end
                end

                for _, Descendant in Ancestor:GetDescendants() do
                    if Descendant:IsA("Model") then
                        SetPropertiesOfDescendants("Set", Descendant, Properties)
                    elseif Descendant:IsA("BasePart") then
                        for Property, Value in Properties do
                            if typeof(Descendant[Property]) ~= "nil" then
                                Descendant:SetAttribute(
                                    Property, 
                                    Descendant[Property]
                                )

                                pcall(function()
                                    Descendant[Property] = Value
                                end)
                            end
                        end
                    end
                end
            elseif Type == "Reset" then
                local AncestorAttributes = Ancestor:GetAttributes()

                for Attribute, Value in AncestorAttributes do
                    local Success = pcall(function()
                        Ancestor[Attribute] = Value
                    end)

                    if Success then
                        Ancestor:SetAttribute(Attribute, nil)
                    end
                end

                for _, Descendant in Ancestor:GetDescendants() do
                    if Descendant:IsA("Model") then
                        SetPropertiesOfDescendants("Reset", Descendant, Properties)
                    elseif Descendant:IsA("BasePart") then
                        local Attributes = Descendant:GetAttributes()

                        for Attribute, Value in Attributes do
                            local Success = pcall(function()
                                Descendant[Attribute] = Value
                            end)

                            if Success then
                                Descendant:SetAttribute(Attribute, nil)
                            end
                        end
                    end
                end
            end
        end
    end, "__setPropertiesOfDescendants")
end

--// UI Interaction Definitions \\--
const function OnDirtCollisionToggled(Value : boolean?)
    ProtectCallback(function()
        local IslandChildren = Island and Island:GetChildren() or {}
    
        for _, Part in IslandChildren do
            if Part:IsA("BasePart") then
                if Part.Name ~= "Grass" then
                    Part.CanCollide = (Value or false)
                end
            end
        end
    end, "__onDirtCollisionToggled")
end

const function OnRemoveNoBarbedWireToggled(Value : boolean)
    ProtectCallback(function()
        if Value then
            local function EvalulateDescendants(Ancestor : Instance)
                local AncestorChildren = (Ancestor and Ancestor:GetDescendants() or {})

                for _, Entry in AncestorChildren do
                    if Entry:IsA("Model") then
                        EvalulateDescendants(Entry)
                    elseif Entry:IsA("BasePart") then
                        if Entry.Name == "BarbedWire" then
                            Entry:Destroy()
                        end
                    end
                end
            end

            EvalulateDescendants(PotentialMap)
        end
    end, "__onRemoveNoBarbedWireToggled")
end

const function OnAnonymousModeToggled(Value)
    ProtectCallback(function()
        if Value and not Script.Library.Notified then
            Script.Library.Notified = true

            Script.Library.VibeUI:Notification({
                Title = "Notice",
                Description = "This doesnt make your username dissapear. Using this feature attempts to remove you from the survivals list to remain somewhat anonymous, in order to do so it needs to reset you.",
                Type = "warning",  -- info | success | warning | error
                Duration = 12,
            })
        else
            return
        end
    end, "__onAnonymousModeToggled")
end

const function OnNotifyDisaster()
    ProtectCallback(function()
        local SurvivalTag = Character:FindFirstChild("SurvivalTag")

        if SurvivalTag then
            Script.StateValues.RecordedSurvivalTag = SurvivalTag
            
            Script.Library.VibeUI:Notification({
                Title = "Incoming Disaster",
                Description = `Disaster is {SurvivalTag.Value}`,
                Type = "warning",  -- info | success | warning | error
                Duration = 20,
            })
        else
            if Script.StateValues.RecordedSurvivalTag then
                Script.Library.VibeUI:Notification({
                    Title = "Incoming Disaster",
                    Description = `Disaster is {Script.StateValues.RecordedSurvivalTag.Value}`,
                    Type = "warning",  -- info | success | warning | error
                    Duration = 20,
                })
            else
                const AllPlayers = Players:GetPlayers()

                for Idx, OtherPlayer in AllPlayers do
                    const OtherCharacter = OtherPlayer.Character

                    if OtherCharacter then
                        const PotentialSurvivorTag = OtherCharacter:FindFirstChild("SurvivalTag")

                        if PotentialSurvivorTag then
                            Script.StateValues.RecordedSurvivalTag = PotentialSurvivorTag

                            Script.Library.VibeUI:Notification({
                                Title = "Incoming Disaster",
                                Description = `Disaster is {PotentialSurvivorTag.Value}`,
                                Type = "warning",  -- info | success | warning | error
                                Duration = 20,
                            })
                        else
                            if Idx > (#AllPlayers) then
                                Script.Library.VibeUI:Notification({
                                    Title = "Error",
                                    Description = "Failed to find tag, You may not be in an active round",
                                    Type = "error",  -- info | success | warning | error
                                    Duration = 12,
                                })
                            end
                        end
                    end
                end
            end
        end
    end, "__onNotifyDisaster")
end

const function OnTeleportToIsland()
    ProtectCallback(function()
        if HumanoidRootPart and HumanoidRootPart.Parent ~= nil then
            const IslandPosition = Script.Configuration.TeleportsConfiguration.IslandTeleportPosition
            const WaterPartPosition = Script.Instances.WaterCollisionPart and Script.Instances.WaterCollisionPart.Position or Vector3.zero

            local NewPosition

            if WaterPartPosition.Y > IslandPosition.Y then
                NewPosition = CFrame.new(
                    IslandPosition.X,
                    WaterPartPosition.Y + 5,
                    IslandPosition.Z
                )
            else
                NewPosition = IslandPosition
            end

            HumanoidRootPart.CFrame = NewPosition
        end
    end, "__onTeleportToIsland")
end

const function OnTeleportToTower()
    ProtectCallback(function()
        if HumanoidRootPart and HumanoidRootPart.Parent ~= nil then
            HumanoidRootPart.CFrame = Script.Configuration.TeleportsConfiguration.TowerTeleportPosition
        end
    end, "__onTeleportToTower")
end

const function OnLoadIY()
    ProtectCallback(function()
        return loadstring(
            game:HttpGet(
                "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
            )
        )()
    end, "__onLoadInfiniteYield")
end

--// Main Script Definitions \\--
const function DetectUIExit()
    ProtectCallback(function()
        local HiddenUI = typeof(gethui) == "function" and gethui() or CoreGui:FindFirstChild("RobloxGui")

        for _, UIEntry in HiddenUI:GetChildren() do
            if UIEntry:IsA("ScreenGui") and UIEntry:GetAttribute("VibeUIHolder") then
                table.insert(
                    Script.ScriptData.ScriptPool,
                    UIEntry:GetPropertyChangedSignal("Parent"):Once(function()
                        if Script.ScriptData.IsUnloading then return end
                        if UIEntry.Parent ~= HiddenUI then
                            UnloadScript()
                        end
                    end)
                )
            end
        end
    end, "__detectUIExit")
end

const function LoadVisualUIConfig()
    ProtectCallback(function()
        Script.Library.VibeUI.Rounded = Script.Configuration.LibraryConfiguration.WindowRounded
        Script.Library.VibeUI.Glass = Script.Configuration.LibraryConfiguration.WindowGlass
        Script.Library.VibeUI.CustomCursor = Script.Configuration.LibraryConfiguration.WindowCustomCursor 
    end, "__loadVisualUIConfig")
end

-- Handles script dependencies
const function CreateScriptDependencies()
    if Script.ScriptData.Debug then
        Output(
            print,
            "__createScriptDependencies",
            "Creating Script Dependencies.."
        )
    end

    ProtectCallback(function()``
        if Script.ScriptData.Debug then
            Output(
                print,
                "__createScriptDependencies",
                "Creating Script Dependencies.."
            )
        end

        do
            local WaterCollisionPart = Instance.new("Part")
            WaterCollisionPart.Name = Script.ScriptData.ScriptGUID
            WaterCollisionPart.CanCollide = true
            WaterCollisionPart.Anchored = true
            WaterCollisionPart.Transparency = 0.5
            WaterCollisionPart.CastShadow = false
            WaterCollisionPart.Parent = nil
            WaterCollisionPart.Size = Vector3.new(16, 2, 16)
            Script.Instances.WaterCollisionPart = WaterCollisionPart
            table.insert(Script.ScriptData.ScriptPool, WaterCollisionPart)

            if WaterLevel then
                Script.Instances.Externals.WaterLevelPart = WaterLevel
            else
                Output(
                    warn,
                    "__createScriptDependencies",
                    "Failed to find game's water level part, attempting to use fallback Y Level"
                )
            end

            table.insert(
                Script.ScriptData.ScriptPool,
                RoundStats:GetAttributeChangedSignal("Round_State"):Connect(function()
                    if (Script and Script.Library == nil) or (Script and Script.Library and Script.Library.VibeUI == nil) or not Script then return end

                    local RoundState = RoundStats:GetAttribute("Round_State")
                    local Flags = Script.Library.VibeUI.Flags

                    if RoundState == "Start Round" and Flags.__disasterNotifications then
                        task.delay(0.5, function()
                            OnNotifyDisaster()
                            OnRemoveNoBarbedWireToggled(Flags.__removeBarbwires)

                            if Flags.__anonymousMode then
                                Script.StateValues.AnonymousReset = true
                            
                                Humanoid.Health = -1
                                Humanoid.MaxHealth = -1
                            end
                        end)
                    end
                end)
            )
        end

        do
            Script.Library.VibeUI = loadstring(
                game:HttpGet("https://sirmemegithub.com/RealSlimShady2000/VibeUI/raw/branch/main/VibeUI.luau")
            )()

            LoadVisualUIConfig()
            DetectUIExit()

            Script.Library.Window = Script.Library.VibeUI:Window({
                Title = `Natural Disaster Survival Script | {Script.ScriptData.Version}`,
                Layout = "Side",
                Size = Script.Configuration.LibraryConfiguration.DefaultWindowSize
            })

            Script.Library.LoadingBar = Script.Library.VibeUI:Loader({ 
                Title = "Natural Disaster Script", 
                Status = "Preparing Script" 
            })

            Script.Library.Tabs = {
                MainTab = {
                    Tab = Script.Library.Window:Tab({
                        Name = "Main",
                    }),

                    TabContents = {}
                },
                
                Teleports = {
                    Tab = Script.Library.Window:Tab({
                        Name = "Teleports",
                    }),

                    TabContents = {}
                },

                Scripts = {
                    Tab = Script.Library.Window:Tab({
                        Name = "Scripts",
                    }),

                    TabContents = {}
                },
                
                Settings = {
                    Tab = nil,
                    TabContents = {} -- only contains contents generated by this script only
                }
            }

            -- // Keybind List
            Script.Library.KeybindList = Script.Library.VibeUI:KeybindList({
                Title = "Keybinds", 
                ShowTitle = true, 
                RichText = false
            })

            Script.Library.Tabs.Settings.Tab = Script.Library.VibeUI:CreateSettingsPage(
                Script.Library.Window,
                Script.ScriptData.ScriptWatermark,
                Script.Library.KeybindList
            )

            Script.Library.LoadingBar:SetProgress(0.5)

            --// Main Section Defs
            Script.Library.Tabs.MainTab.TabContents.PlayerSection = Script.Library.Tabs.MainTab.Tab:Section({
                Name = "Player",
                Side = 1
            })
            
            --// Map Section Defs
            Script.Library.Tabs.MainTab.TabContents.MapSection = Script.Library.Tabs.MainTab.Tab:Section({
                Name = "Map",
                Side = 2
            })

            --// Game Section Defs
            Script.Library.Tabs.MainTab.TabContents.GameSection = Script.Library.Tabs.MainTab.Tab:Section({
                Name = "Game",
                Side = 1
            })

            --// Game Section Defs
            Script.Library.Tabs.MainTab.TabContents.NotificationsSection = Script.Library.Tabs.MainTab.Tab:Section({
                Name = "Notifications",
                Side = 2
            })

             --// Game Section Defs
            Script.Library.Tabs.MainTab.TabContents.AntisSection = Script.Library.Tabs.MainTab.Tab:Section({
                Name = "Antis",
                Side = 1
            })

            --// Teleports Section Defs
            Script.Library.Tabs.Teleports.TabContents.TeleportsSection = Script.Library.Tabs.Teleports.Tab:Section({
                Name = "Teleports",
                Side = 1
            })

            --// Scripts Section Defs
            Script.Library.Tabs.Scripts.TabContents.ScriptsSection = Script.Library.Tabs.Scripts.Tab:Section({
                Name = "Scripts",
                Side = 1
            })

             --// Main Script Section Defs
            Script.Library.Tabs.Settings.TabContents.MainScriptSection = Script.Library.Tabs.Settings.Tab:Section({
                Name = "Script",
                Side = 2
            })

            --// Toggles
            Script.Library.Tabs.MainTab.TabContents.WaterCollisionToggle = Script.Library.Tabs.MainTab.TabContents.PlayerSection:Toggle({
                Name = "Water Collision",
                Flag = "__waterCollision",
            })

            Script.Library.Tabs.MainTab.TabContents.NoFallDamageToggle = Script.Library.Tabs.MainTab.TabContents.PlayerSection:Toggle({
                Name = "No Fall Damage",
                Flag = "__noFallDamage",
            })

            Script.Library.Tabs.MainTab.TabContents.NoFallDamageToggle = Script.Library.Tabs.MainTab.TabContents.MapSection:Toggle({
                Name = "No Earthquake Shake",
                Flag = "__noEarthquakeShake",
            })

            Script.Library.Tabs.MainTab.TabContents.MapSection:Toggle({
                Name = "Island Dirt Collision",
                Flag = "__dirtCollision",
                Callback = OnDirtCollisionToggled
            })

            Script.Library.Tabs.MainTab.TabContents.MapSection:Toggle({
                Name = "No Barbed Wire",
                Flag = "__removeBarbwires",
                Callback = OnRemoveNoBarbedWireToggled
            })

            Script.Library.Tabs.MainTab.TabContents.GameSection:Toggle({
                Name = "Upcoming Disaster Notifications",
                Flag = "__disasterNotifications",
            })

            Script.Library.Tabs.MainTab.TabContents.AntisSection:Toggle({
                Name = "Semi-Anonymous-Mode",
                Flag = "__anonymousMode",
                Callback = OnAnonymousModeToggled
            })

            --// Buttons
            Script.Library.Tabs.MainTab.TabContents.TeleportButtons = Script.Library.Tabs.Teleports.TabContents.TeleportsSection:Button()
            Script.Library.Tabs.MainTab.TabContents.TeleportButtons:Add("Teleport To Island", OnTeleportToIsland)
            Script.Library.Tabs.MainTab.TabContents.TeleportButtons:Add("Teleport To Tower", OnTeleportToTower)

            Script.Library.Tabs.MainTab.TabContents.NotificationButtons = Script.Library.Tabs.MainTab.TabContents.NotificationsSection:Button()
            Script.Library.Tabs.MainTab.TabContents.NotificationButtons:Add("Notify Current Disaster", OnNotifyDisaster)

            Script.Library.Tabs.Scripts.TabContents.ScriptButtons = Script.Library.Tabs.Scripts.TabContents.ScriptsSection:Button()
            Script.Library.Tabs.Scripts.TabContents.ScriptButtons:Add("Infinite Yield", OnLoadIY)

            --// Paragraphs
            Script.Library.Tabs.Settings.TabContents.StartupInfoParagraph = Script.Library.Tabs.Settings.TabContents.MainScriptSection:Paragraph({
                Name = "Startup Info",
                Content = ""
            })

            --// UI Setup Finished \\--
        end

        Script.Library.VibeUI:Notification({
            Title = (#Script.ScriptData.Errors == 0 and "Success" or "Errors Occured"),
            Description = (#Script.ScriptData.Errors == 0 and "Script loaded with no errrors" or "Script loaded with errors, functionality could be limited."),
            Type = (#Script.ScriptData.Errors == 0 and "success" or "error"),  -- info | success | warning | error
            Duration = 4,
        })
    end, "__createScriptDependencies")
end

-- Handles all main input events
const function UserInputBegan(Input, GPE)
    if GPE then return end
end

-- Handles all main input events
const function UserInputEnded(Input, GPE)
    if GPE then return end
end

-- Handles character pointer evaulation
const function OnUserCharacterAdded(NewCharacter : Model)
    Character = CloneReference(NewCharacter)
    HumanoidRootPart = NewCharacter:WaitForChild("HumanoidRootPart", 2)
    Humanoid = NewCharacter:WaitForChild("Humanoid", 2)

    if Script.Library.VibeUI.Flags.__anonymousMode and Script.StateValues.AnonymousReset then Script.StateValues.AnonymousReset = false; OnTeleportToIsland() end
end

-- Handles looped script states
const function RenderSteppedCompute(Delta : number)
    const Flags = Script.Library.VibeUI.Flags

    if Character and HumanoidRootPart then
        if Script.Instances.WaterCollisionPart then
            if Flags.__waterCollision then
                if Script.Instances.WaterCollisionPart.Parent ~= workspace then
                    Script.Instances.WaterCollisionPart.Parent = workspace
                end
                
                local PotentialFloodPart = StructureFolder:FindFirstChild("FloodLevel")
                local WaterLevelPart = (PotentialFloodPart and PotentialFloodPart or Script.Instances.Externals.WaterLevelPart)

                local RootPosition = HumanoidRootPart.Position
                
                if WaterLevelPart then
                    local WaterLevelPosition = WaterLevelPart.Position

                    local NewPosition = Vector3.new(
                        RootPosition.X,
                        WaterLevelPosition.Y,
                        RootPosition.Z
                    )

                    Script.Instances.WaterCollisionPart.Position = NewPosition
                else
                    local NewPosition = Vector3.new(
                        RootPosition.X,
                        20,
                        RootPosition.Z
                    )

                    Script.Instances.WaterCollisionPart.Position = NewPosition
                end
            else
                if Script.Instances.WaterCollisionPart.Parent ~= nil then
                    Script.Instances.WaterCollisionPart.Parent = nil
                end
            end
        end

        if Flags.__noFallDamage then
            HumanoidRootPart.AssemblyLinearVelocity = Script.StateValues.InitialVelocity
        end
    end
end

-- Handles looped script states at 60 FPS
const function HeartbeatCompute()
    const Flags = Script.Library.VibeUI.Flags

    if Island then
        if Flags.__noEarthquakeShake then
            local IslandChildren = (Island and Island:GetChildren() or {})

            for _, Entry in IslandChildren do
                if Entry:IsA("BasePart") and Entry.AssemblyLinearVelocity.Magnitude >= 2 then
                    Entry.AssemblyLinearVelocity = Vector3.zero                
                end
            end
        end
    end

    if Character and HumanoidRootPart then
        if Flags.__noFallDamage then
            Script.StateValues.InitialVelocity = HumanoidRootPart.AssemblyLinearVelocity
            HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

-- Handles all events including starting themDW
const function StartScriptEvents()
    ProtectCallback(function()
        table.insert(
            Script.ScriptData.ScriptPool, 
            UserInputService.InputBegan:Connect(UserInputBegan)
        )

        table.insert(
            Script.ScriptData.ScriptPool, 
            UserInputService.InputEnded:Connect(UserInputEnded)
        )

        table.insert(
            Script.ScriptData.ScriptPool, 
            Player.CharacterAdded:Connect(OnUserCharacterAdded)
        )

        table.insert(
            Script.ScriptData.ScriptPool, 
            RunService.RenderStepped:Connect(RenderSteppedCompute)
        )

        table.insert(
            Script.ScriptData.ScriptPool, 
            RunService.Heartbeat:Connect(HeartbeatCompute)
        )
    end, "__startScriptEvents")
end

--// (Main) Boot Process \\--
ProtectCallback(function()
    local GlobalEnvironment = typeof(getgenv) == "function" and getgenv()

    if not GlobalEnvironment then
        Output(
            print,
            "__mainBootProcess",
            `{Script.ScriptData.Executor} Doesnt appear to support getgenv, Exiting.`
        )

        UnloadScript()

        return
    end

    if typeof(GlobalEnvironment[Script.ScriptData.ScriptEnvironment]) == "table" then
        local ScriptEnvironment = GlobalEnvironment[Script.ScriptData.ScriptEnvironment]

        if Script.ScriptData.Debug then
            Output(
                print,
                "__mainBootProcess",
                "Found potential old/duplicate script"
            )
        end
        
        if typeof(ScriptEnvironment.UnloadScript) == "function" then
            pcall(ScriptEnvironment.UnloadScript)

            if Script.ScriptData.Debug then
                Output(
                    print,
                    "__mainBootProcess",
                    "Attempting to unload the previous script"
                )
            end
        end
    end

    Script.UnloadScript = UnloadScript
    GlobalEnvironment[Script.ScriptData.ScriptEnvironment] = Script

    CreateScriptDependencies()
    StartScriptEvents()

    task.defer(function()
        if Script.ScriptData.Debug then
            local ElapsedTime = (os.clock() - Script.ScriptData.BootTime)
            Script.ScriptData.BootFinishTime = ElapsedTime

            Output(
                print,
                "__mainBootProcess",
                `Finished boot sequence with {
                    identifyexecutor()
                }, Took {
                    Decimate(ElapsedTime, 1000)
                } second(s).`
            )

            repeat
                task.wait(1)
            until Script.Library.LoadingBar ~= nil and Script.Library.Tabs.Settings.TabContents.StartupInfoParagraph ~= nil

            Script.Library.LoadingBar:Finish(0.2)
            Script.Library.Tabs.Settings.TabContents.StartupInfoParagraph:SetText(
                `Identified Executor as {
                    Script.ScriptData.Executor
                }. Loaded in Approximately {
                    Decimate(ElapsedTime, 1000)
                } second(s)`
            )
        end
    end)
end, "__mainBootProcess")
