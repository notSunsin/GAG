
-- ========================================================================================
-- 1. SERVICE & INISIALISASI DASAR
-- ========================================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Pembersihan instance GUI lama jika ada
if getgenv and getgenv().HUKI_ArchieCollector_Gui then
    pcall(function()
        getgenv().HUKI_ArchieCollector_Gui:Destroy()
    end)
    getgenv().HUKI_ArchieCollector_Gui = nil
end

pcall(function()
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local old = pgui:FindFirstChild("HUKI_ArchieCollector_Gui")
        if old then old:Destroy() end
    end
end)

-- Deteksi Container GUI yang Aman (PlayerGui lebih aman dari capability isolation)
local function GetSafeGuiParent()
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then return pgui end

    local ok, res = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
    if ok and res then return res end

    if gethui then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ========================================================================================
-- 2. REFERENSI REMOTE & MODUL GAME GAG
-- ========================================================================================
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 10)
local EventsFolder = GameEvents and GameEvents:FindFirstChild("Events")
local AnubisEventFolder = EventsFolder and EventsFolder:FindFirstChild("AnubisEvent")
local AncientArcFolder = AnubisEventFolder and AnubisEventFolder:FindFirstChild("AncientArc")

-- Remote Archeologist Archie
local AncientArcSubmitRemote = AncientArcFolder and AncientArcFolder:FindFirstChild("Submit")
local AncientArcOpenRemote = AncientArcFolder and AncientArcFolder:FindFirstChild("Open")
local AncientArcRestartRemote = AncientArcFolder and AncientArcFolder:FindFirstChild("Restart")

-- Remote Crops & Selling to Sam
local CropsEvents = GameEvents and GameEvents:FindFirstChild("Crops")
local CollectRemote = CropsEvents and CropsEvents:FindFirstChild("Collect")
local SellItemRemote = GameEvents and GameEvents:FindFirstChild("Sell_Item")
local SellInventoryRemote = GameEvents and GameEvents:FindFirstChild("Sell_Inventory")

-- Resolusi Modul Internal Game
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules", 10)
local DataService = nil
local PlantTraitsData = nil
local AncientArcConfig = nil
local AncientArcController = nil
local GetFarmModule = nil
local FruitUtils = nil
local MutationHandler = nil
local InventoryService = nil
local CountDictionary = nil

pcall(function()
    DataService = require(ModulesFolder:WaitForChild("DataService", 5))
end)
pcall(function()
    PlantTraitsData = require(ModulesFolder:WaitForChild("PlantTraitsData", 5))
end)
pcall(function()
    AncientArcConfig = require(ReplicatedStorage.Data.Events.AnubisEvent.AncientArcConfig)
end)
pcall(function()
    AncientArcController = require(ModulesFolder.Events.AnubisEvent.AncientArcController)
end)
pcall(function()
    GetFarmModule = require(ModulesFolder:WaitForChild("GetFarm", 5))
end)
pcall(function()
    FruitUtils = require(ModulesFolder:WaitForChild("FruitUtils", 5))
end)
pcall(function()
    MutationHandler = require(ModulesFolder:WaitForChild("MutationHandler", 5))
end)
pcall(function()
    InventoryService = require(ModulesFolder:WaitForChild("InventoryService", 5))
end)
pcall(function()
    CountDictionary = require(ModulesFolder:WaitForChild("CountDictionary", 5))
end)

-- Daftar Trait Resmi Archeologist Archie
local ArchieTraits = {
    "Fruit", "Berry", "Flower", "Vegetable", "Tropical", 
    "Prickly", "Woody", "Leafy", "Stalky", "Root", "Sweet", "Sour"
}

-- Warna default per Trait untuk UI Badge
local TraitColorMap = {
    ["Fruit"]     = Color3.fromRGB(39, 174, 96),   -- Emerald Green
    ["Berry"]     = Color3.fromRGB(155, 89, 182),  -- Purple
    ["Flower"]    = Color3.fromRGB(255, 105, 180), -- Hot Pink
    ["Vegetable"] = Color3.fromRGB(46, 204, 113),  -- Green
    ["Tropical"]  = Color3.fromRGB(243, 156, 18),  -- Orange
    ["Prickly"]   = Color3.fromRGB(211, 84, 0),   -- Rust
    ["Woody"]     = Color3.fromRGB(160, 82, 45),   -- Sienna Brown
    ["Leafy"]     = Color3.fromRGB(34, 139, 34),   -- Forest Green
    ["Stalky"]    = Color3.fromRGB(189, 195, 199), -- Silver Grey
    ["Root"]      = Color3.fromRGB(139, 69, 19),   -- Saddle Brown
    ["Sweet"]     = Color3.fromRGB(255, 182, 193), -- Light Pink
    ["Sour"]      = Color3.fromRGB(241, 196, 15),  -- Bright Yellow
}

-- Muat warna resmi dari PlantTraitsData jika tersedia
pcall(function()
    if PlantTraitsData and PlantTraitsData.TraitColors then
        for tName, cTable in pairs(PlantTraitsData.TraitColors) do
            if type(cTable) == "table" and #cTable >= 3 then
                TraitColorMap[tName] = Color3.fromRGB(cTable[1], cTable[2], cTable[3])
            end
        end
    end
end)

-- ========================================================================================
-- 3. STATE & KONFIGURASI APLIKASI
-- ========================================================================================
local Config = {
    AutoCollect = false,              -- Auto collect loop
    AutoSyncArchie = true,            -- Otomatis ikuti trait Archie secara real-time
    ManualTrait = "Fruit",            -- Trait manual jika AutoSync dimatikan
    AutoSubmitArchieBackpack = false, -- Otomatis submit buah bertipe Archie di backpack (loop 5s)
    AutoRestartEvent = true,          -- Otomatis restart event jika 20/20 finds selesai (1T Sheckles)
    AutoSellFruitsToSamOnTraitChange = true, -- Otomatis jual seluruh buah di tas ke NPC Sam saat trait Archie berubah
    SkipRewardAnimation = true,       -- Hilangkan/skip animasi opening reward Archie secara instan ("Brushed Up")
    BackpackCheckInterval = 5.0,      -- Interval cek & refresh backpack (5 detik)
    CollectInterval = 1.0,            -- Jeda antar siklus cek kebun (detik)
    BatchDelay = 0.08,                -- Jeda antar remote collect (anti-throttle)
    ProtectSoloNightmare = true,      -- Lewatkan jika hanya memiliki mutasi Nightmare polos
    SkipFavorited = true,             -- Lewatkan tanaman/buah yang di-favoritkan
    CheckBackpack = true,             -- Berhenti panen jika ransel sudah penuh
}

local State = {
    CurrentArchieTrait = "Checking...", -- Trait Archie yang terdeteksi
    ActiveTargetTrait = "Fruit",         -- Trait yang sedang dipanen saat ini
    TotalHarvested = 0,                 -- Total buah yang berhasil dipanen
    ReadyMatching = 0,                  -- Jumlah tanaman cocok yang siap panen
    BackpackMatchingCount = 0,          -- Jumlah buah cocok yang ada di tas saat ini
    IsCollecting = false,               -- Mutex status panen sedang berjalan
    IsSubmittingBackpack = false,       -- Mutex status auto submit tas
    IsRestarting = false,               -- Mutex proses restart event
    IsSellingToSam = false,             -- Mutex proses jual ke Sam
    ArchieModel = nil,                  -- Instance model Archie di workspace
}

-- Forward declarations untuk UI updater & Logger
local AppendLog
local UpdateTraitDisplay
local UpdateStatsDisplay
local CheckAndSubmitBackpackFruits
local CheckAndAutoRestartArchie
local SellAllFruitsToSam
local PatchRevealConfig
local DismissActiveRewardCard
local SetupRewardAnimationSkipper

-- ========================================================================================
-- 4. LOGIKA PENDETEKSI KEBUTUHAN NPC ARCHIE (REAL-TIME SYNC)
-- ========================================================================================

-- Ambil trait Archie langsung dari Remote Attribute / Module / Model Archie
local function DetectArchieTrait()
    local detectedTrait = nil

    -- Sumber 1: Attribute resmi di ReplicatedStorage AncientArc
    if AncientArcFolder then
        local attr = AncientArcFolder:GetAttribute("Trait")
        if attr and attr ~= "" then
            detectedTrait = tostring(attr)
        end
    end

    -- Sumber 2: Melalui AncientArcController game
    if not detectedTrait and AncientArcController and AncientArcController.GetTrait then
        pcall(function()
            local t = AncientArcController:GetTrait()
            if t and t ~= "" then
                detectedTrait = tostring(t)
            end
        end)
    end

    -- Sumber 3: Inspeksi ThoughtBubblePart pada Model NPC Archie di Workspace
    if not detectedTrait then
        pcall(function()
            for _, tagModel in ipairs(CollectionService:GetTagged("AncientArcModel")) do
                local thought = tagModel:FindFirstChild("ThoughtBubblePart", true)
                if thought then
                    local bb = thought:FindFirstChildWhichIsA("BillboardGui", true)
                    local lbl = bb and bb:FindFirstChild("Trait", true)
                    if lbl and lbl:IsA("TextLabel") and lbl.Text ~= "" then
                        local clean = lbl.Text:gsub("<[^>]*>", ""):gsub("Looking for ", ""):gsub(" plants!", ""):gsub("%s+", "")
                        if clean and clean ~= "" then
                            detectedTrait = clean
                        end
                    end
                end
            end
        end)
    end

    -- Sumber 4: Fallback scan model Archie manual di workspace
    if not detectedTrait then
        pcall(function()
            local archie = workspace:FindFirstChild("Archeologist Archie", true) or workspace:FindFirstChild("Archie", true)
            if archie then
                local bb = archie:FindFirstChildWhichIsA("BillboardGui", true)
                if bb then
                    for _, child in ipairs(bb:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text:find("Looking for") then
                            for _, opt in ipairs(ArchieTraits) do
                                if child.Text:lower():find(opt:lower()) then
                                    detectedTrait = opt
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    return detectedTrait
end

-- Update trait & picu event perubahan jika ada pergantian kebutuhan
local function CheckAndUpdateArchieTrait()
    -- Cek apakah Archie siap di-restart
    if CheckAndAutoRestartArchie then
        pcall(CheckAndAutoRestartArchie)
    end

    local newTrait = DetectArchieTrait()
    if not newTrait or newTrait == "" then return end

    if newTrait ~= State.CurrentArchieTrait then
        local oldTrait = State.CurrentArchieTrait
        State.CurrentArchieTrait = newTrait

        if Config.AutoSyncArchie then
            State.ActiveTargetTrait = newTrait
            AppendLog(string.format("[NPC SYNC] Archie berganti trait: [%s] -> [%s]! Filter panen & tas langsung diubah.", oldTrait, newTrait), TraitColorMap[newTrait] or Color3.fromRGB(0, 255, 170))
        else
            AppendLog(string.format("[NPC INFO] Archie sekarang mencari: [%s] (Mode Manual Aktif)", newTrait), Color3.fromRGB(220, 220, 100))
        end

        UpdateTraitDisplay()

        -- FITUR: Ketika Fruit type yang diinginkan berubah, Buah yang ada di tas otomatis terjual semua ke NPC Sam!
        if Config.AutoSellFruitsToSamOnTraitChange and SellAllFruitsToSam then
            task.spawn(SellAllFruitsToSam)
        end

        if CheckAndSubmitBackpackFruits then
            task.delay(1.2, function()
                CheckAndSubmitBackpackFruits()
            end)
        end
    end
end

-- Pasang Listener AttributeChangedSignal pada AncientArc instance untuk deteksi instan (0 latency)
if AncientArcFolder then
    AncientArcFolder:GetAttributeChangedSignal("Trait"):Connect(function()
        local trait = AncientArcFolder:GetAttribute("Trait")
        if trait and trait ~= "" then
            local old = State.CurrentArchieTrait
            State.CurrentArchieTrait = tostring(trait)
            if Config.AutoSyncArchie then
                State.ActiveTargetTrait = tostring(trait)
                AppendLog(string.format("[INSTANT SYNC] Archie berganti permintaan: [%s] -> [%s]!", old, trait), TraitColorMap[trait] or Color3.fromRGB(0, 255, 170))
            end
            UpdateTraitDisplay()

            -- Jual sisa buah ke NPC Sam jika trait berubah
            if Config.AutoSellFruitsToSamOnTraitChange and SellAllFruitsToSam then
                task.spawn(SellAllFruitsToSam)
            end

            if CheckAndSubmitBackpackFruits then
                task.delay(1.2, function()
                    CheckAndSubmitBackpackFruits()
                end)
            end
        end
    end)
end

-- Background poll untuk memastikan sinkronisasi selalu aktif
task.spawn(function()
    while true do
        pcall(CheckAndUpdateArchieTrait)
        task.wait(0.5)
    end
end)

-- ========================================================================================
-- 5. LOGIKA KEBUN & IDENTIFIKASI TRAIT BUAH (CORE ENGINE)
-- ========================================================================================

-- Dapatkan instance Farm player
local function GetPlayerFarm()
    if GetFarmModule then
        local success, farm = pcall(function()
            return GetFarmModule(LocalPlayer)
        end)
        if success and farm and farm:IsDescendantOf(workspace) then
            return farm
        end
    end

    local FarmFolder = workspace:FindFirstChild("Farm")
    if FarmFolder then
        for _, farm in ipairs(FarmFolder:GetChildren()) do
            local Important = farm:FindFirstChild("Important")
            if Important then
                local Data = Important:FindFirstChild("Data")
                if Data and Data:FindFirstChild("Owner") and Data.Owner.Value == LocalPlayer.Name then
                    return farm
                end
            end
        end
    end

    return nil
end

-- Deteksi apakah tanaman / buah memiliki trait yang dicari
local function CheckPlantHasTrait(fruitModel, targetTrait)
    if not targetTrait or targetTrait == "" or targetTrait == "Checking..." then
        return false
    end

    -- Kumpulkan kandidat nama tanaman
    local candidates = {}

    local rawName = fruitModel.Name
    table.insert(candidates, rawName)

    local itemStr = fruitModel:FindFirstChild("Item_String")
    if itemStr and itemStr.Value and itemStr.Value ~= "" then
        table.insert(candidates, itemStr.Value)
    end

    for _, attrName in ipairs({ "ItemName", "Item_Name", "PlantType", "FruitType", "Seed", "DisplayName", "f" }) do
        local val = fruitModel:GetAttribute(attrName)
        if val and type(val) == "string" and val ~= "" then
            table.insert(candidates, val)
        end
    end

    -- Jika buah ada di dalam folder 'Fruits', periksa nama parent pohon / tanaman induknya
    if fruitModel.Parent and fruitModel.Parent.Name == "Fruits" and fruitModel.Parent.Parent then
        local parentPlant = fruitModel.Parent.Parent
        table.insert(candidates, parentPlant.Name)
        local pItemStr = parentPlant:FindFirstChild("Item_String")
        if pItemStr and pItemStr.Value and pItemStr.Value ~= "" then
            table.insert(candidates, pItemStr.Value)
        end
        for _, attrName in ipairs({ "ItemName", "Item_Name", "PlantType", "FruitType", "Seed", "DisplayName" }) do
            local val = parentPlant:GetAttribute(attrName)
            if val and type(val) == "string" and val ~= "" then
                table.insert(candidates, val)
            end
        end
    end

    -- Bersihkan nama dari tag mutasi dan spasi ekstra
    local cleanedNames = {}
    for _, raw in ipairs(candidates) do
        local cleaned = raw:gsub("%b[]", "")
            :gsub("Hieroglyphic", "")
            :gsub("Gold", "")
            :gsub("Rainbow", "")
            :gsub("Nightmare", "")
            :gsub("Wet", "")
            :gsub("Tree", "")
            :gsub("Plant", "")
            :gsub("Bush", "")
            :gsub("^%s+", "")
            :gsub("%s+$", "")
        if cleaned ~= "" then
            cleanedNames[cleaned] = true
            cleanedNames[raw] = true
        end
    end

    -- 1. Evaluasi dengan PlantTraitsData resmi game
    if PlantTraitsData and PlantTraitsData.HasTrait then
        for cName, _ in pairs(cleanedNames) do
            local ok, hasTrait = pcall(function()
                return PlantTraitsData.HasTrait(cName, targetTrait)
            end)
            if ok and hasTrait == true then
                return true, cName
            end
        end
    end

    -- 2. Fallback: Cek folder modul PlantTraitsData langsung jika ada
    pcall(function()
        if PlantTraitsData and ModulesFolder then
            local ptdFolder = ModulesFolder:FindFirstChild("PlantTraitsData")
            if ptdFolder then
                local traitModule = ptdFolder:FindFirstChild(targetTrait)
                if traitModule then
                    local data = require(traitModule)
                    if data and data.Plants then
                        for _, pName in ipairs(data.Plants) do
                            for cName, _ in pairs(cleanedNames) do
                                if cName:lower() == pName:lower() or cName:lower():find(pName:lower()) then
                                    return true, cName
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    return false, nil
end

-- Deteksi apakah buah matang / siap panen
local function IsFruitHarvestable(fruitModel, myFarm)
    if not fruitModel or not fruitModel:IsDescendantOf(workspace) then
        return false
    end
    if myFarm and not fruitModel:IsDescendantOf(myFarm) then
        return false
    end
    if fruitModel:GetAttribute("Collected") == true then
        return false
    end

    if FruitUtils and FruitUtils.IsFruitGrown then
        local success, grown = pcall(function()
            return FruitUtils:IsFruitGrown(fruitModel)
        end)
        if success and grown ~= nil then
            return grown
        end
    end

    local maxAge = fruitModel:GetAttribute("MaxAge")
    local grow = fruitModel:FindFirstChild("Grow")
    local ageVal = grow and grow:FindFirstChild("Age")
    if maxAge and ageVal then
        return ageVal.Value >= maxAge
    end

    if CollectionService:HasTag(fruitModel, "Harvestable") then
        local prompt = fruitModel:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Enabled then
            return true
        end
        return true
    end

    return false
end

-- Deteksi mutasi buah
local function GetFruitMutations(fruitModel)
    local mutMap = {}
    local count = 0

    local function inspect(inst)
        if not inst then return end
        if MutationHandler and MutationHandler.GetPlantMutations then
            local success, _list, _cnt, names = pcall(function()
                return MutationHandler:GetPlantMutations(inst, true)
            end)
            if success and type(names) == "table" then
                for _, name in ipairs(names) do
                    if not mutMap[name] then
                        mutMap[name] = true
                        count = count + 1
                    end
                end
                return
            end
        end

        for attr, val in pairs(inst:GetAttributes()) do
            if val == true then
                if not mutMap[attr] then
                    mutMap[attr] = true
                    count = count + 1
                end
            end
        end
    end

    inspect(fruitModel)
    if count == 0 and fruitModel.Parent and fruitModel.Parent.Name == "Fruits" and fruitModel.Parent.Parent then
        inspect(fruitModel.Parent.Parent)
    end

    return mutMap, count
end

-- Evaluasi apakah buah boleh dipanen
local function ShouldCollectMatchingFruit(fruitModel)
    -- 1. Proteksi Favorited
    if Config.SkipFavorited and fruitModel:GetAttribute("Favorited") == true then
        return false, "Skip (Favorited)"
    end

    -- 2. Proteksi Solo Nightmare
    if Config.ProtectSoloNightmare then
        local mutMap, mutCount = GetFruitMutations(fruitModel)
        local hasNightmare = mutMap["Nightmare"] or fruitModel:GetAttribute("Nightmare") == true
        local hasWet = mutMap["Wet"] or fruitModel:GetAttribute("Wet") == true
        if hasNightmare and not hasWet then
            return false, "Skip (Proteksi Solo Nightmare)"
        end
    end

    -- 3. Cek Trait yang sesuai dengan Archie
    local targetTrait = Config.AutoSyncArchie and State.CurrentArchieTrait or Config.ManualTrait
    local hasTrait, matchedName = CheckPlantHasTrait(fruitModel, targetTrait)
    if not hasTrait then
        return false, "Trait tidak cocok"
    end

    return true, matchedName or fruitModel.Name
end

-- Ambil semua buah di kebun player yang cocok dengan Trait Archie
local function GetMatchingHarvestables()
    local myFarm = GetPlayerFarm()
    if not myFarm then return {}, nil end

    local matchedList = {}
    local candidateMap = {}

    local function checkAndAdd(model)
        if model and model:IsA("Model") and not candidateMap[model] then
            if IsFruitHarvestable(model, myFarm) then
                local shouldCollect, plantName = ShouldCollectMatchingFruit(model)
                if shouldCollect then
                    candidateMap[model] = true
                    table.insert(matchedList, { Model = model, PlantName = plantName })
                end
            end
        end
    end

    -- Scan CollectionService "Harvestable"
    for _, item in ipairs(CollectionService:GetTagged("Harvestable")) do
        if item:IsA("Model") and item:IsDescendantOf(myFarm) then
            checkAndAdd(item)
        end
    end

    -- Scan Plants_Physical di Farm
    local Plants_Physical = myFarm:FindFirstChild("Plants_Physical", true)
    if Plants_Physical then
        for _, plant in ipairs(Plants_Physical:GetChildren()) do
            if plant:IsA("Model") then
                checkAndAdd(plant)
                local fruitsFolder = plant:FindFirstChild("Fruits")
                if fruitsFolder then
                    for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                        if fruit:IsA("Model") then
                            checkAndAdd(fruit)
                        end
                    end
                end
            end
        end
    end

    State.ReadyMatching = #matchedList
    UpdateStatsDisplay()
    return matchedList, myFarm
end

-- Cek apakah ransel penuh
local function IsBackpackFull()
    local full = false
    pcall(function()
        if InventoryService then
            if InventoryService.IsMaxInventory then
                full = InventoryService.IsMaxInventory(LocalPlayer)
                return
            end
            if CountDictionary and InventoryService.Find then
                local holdables = InventoryService:Find("Holdable")
                local count = CountDictionary(holdables)
                local bonus = LocalPlayer:GetAttribute("BonusBackpackSize") or 0
                if count >= (200 + bonus) then
                    full = true
                end
            end
        end
    end)
    return full
end

-- Deteksi semua buah di Backpack / Tas yang sesuai dengan Trait Archie
local function GetMatchingFruitsInBackpack(targetTrait)
    targetTrait = targetTrait or (Config.AutoSyncArchie and State.CurrentArchieTrait or Config.ManualTrait)
    if not targetTrait or targetTrait == "Checking..." or targetTrait == "Unknown" then
        return {}
    end

    local matching = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character

    local function inspectContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local isFav = item:GetAttribute("Favorite") == true
                    or item:GetAttribute("Favorited") == true
                    or item:GetAttribute("IsFavorite") == true
                    or item:GetAttribute("d") == true
                
                if not (Config.SkipFavorited and isFav) then
                    local hasTrait, pName = CheckPlantHasTrait(item, targetTrait)
                    if hasTrait then
                        table.insert(matching, { Tool = item, PlantName = pName or item.Name })
                    end
                end
            end
        end
    end

    inspectContainer(backpack)
    inspectContainer(character)

    return matching
end

-- Forward declaration fungsi SubmitAllToArchie
local SubmitAllToArchie

-- Periksa dan Auto Submit Buah di Backpack ke Archie
local function CheckAndSubmitBackpackFruits()
    if State.IsSubmittingBackpack then return end
    State.IsSubmittingBackpack = true

    local targetTrait = Config.AutoSyncArchie and State.CurrentArchieTrait or Config.ManualTrait
    if not targetTrait or targetTrait == "Checking..." or targetTrait == "Unknown" then
        State.IsSubmittingBackpack = false
        return
    end

    local matching = GetMatchingFruitsInBackpack(targetTrait)
    State.BackpackMatchingCount = #matching
    UpdateStatsDisplay()

    if Config.AutoSubmitArchieBackpack and #matching > 0 then
        AppendLog(string.format("[AUTO SUBMIT] Ditemukan %d buah bertipe [%s] di tas! Mengirim ke Archie...", #matching, targetTrait), TraitColorMap[targetTrait] or Color3.fromRGB(0, 220, 255))
        
        local success = false
        if AncientArcSubmitRemote then
            local ok, _ = pcall(function()
                AncientArcSubmitRemote:FireServer({ Token = 1, Mode = "All" })
            end)
            if ok then success = true end
        end

        if not success and AncientArcController and AncientArcController.Submit then
            pcall(function()
                AncientArcController:Submit("All")
                success = true
            end)
        end

        if success then
            task.wait(1.0)
            local remaining = GetMatchingFruitsInBackpack(targetTrait)
            State.BackpackMatchingCount = #remaining
            UpdateStatsDisplay()
            AppendLog(string.format("[AUTO SUBMIT] Selesai! Sisa buah cocok di tas: %d.", #remaining), Color3.fromRGB(120, 255, 180))
        end
    end

    State.IsSubmittingBackpack = false
end

-- ========================================================================================
-- FITUR: VALIDASI BUAH & JUAL OTOMATIS KE NPC SAM SAAT TRAIT GANTI
-- ========================================================================================

-- Filter Ketat: Pastikan HANYA buah/tanaman panen yang dijual (TIDAK menjual gear, tools, benih, pet, dll)
local function IsFruitOnly(tool)
    if not (tool and tool:IsA("Tool")) then return false end

    -- 1. Jangan jual jika difavoritkan
    if tool:GetAttribute("Favorite") == true 
       or tool:GetAttribute("Favorited") == true 
       or tool:GetAttribute("IsFavorite") == true 
       or tool:GetAttribute("d") == true then
        return false
    end

    -- 2. Jangan jual jika Pet
    if tool:GetAttribute("PET_UUID") or tool:GetAttribute("PetUUID") or tool:HasTag("PetTool") then
        return false
    end

    local rawName = tool.Name
    local lowerName = string.lower(rawName)

    -- 3. Blacklist nama alat/gear/benih/telur/pet
    local blacklist = {
        "watering", "can", "sprinkler", "shears", "shovel", "radar", "staff",
        "fertilizer", "potion", "rod", "egg", "seed", "crate", "trowel", "basket", "ticket"
    }
    for _, word in ipairs(blacklist) do
        if string.find(lowerName, word, 1, true) then
            return false
        end
    end

    -- 4. Cek Item_String (Ciri khas utama buah/hasil panen di GAG)
    local itemStr = tool:FindFirstChild("Item_String")
    if itemStr and itemStr.Value and itemStr.Value ~= "" then
        return true, itemStr.Value
    end

    -- 5. Cek atribut berat / tanaman
    if tool:GetAttribute("Weight") or tool:GetAttribute("FruitWeight") or tool:GetAttribute("BaseWeight") or tool:GetAttribute("PlantType") then
        return true, tool.Name
    end

    -- 6. Cek nama buah di PlantTraitsData
    local cleanName = rawName:gsub("%b[]", ""):gsub("Hieroglyphic", ""):gsub("Gold", ""):gsub("Rainbow", ""):gsub("Nightmare", ""):gsub("Wet", ""):gsub("%d+.*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if PlantTraitsData and PlantTraitsData.GetTraits and #PlantTraitsData.GetTraits(cleanName) > 0 then
        return true, cleanName
    end

    return false
end

-- Temukan model NPC Sam di workspace
local function GetSamNPC()
    local sam = workspace:FindFirstChild("Sam", true)
        or workspace:FindFirstChild("NPC_Sam", true)
        or workspace:FindFirstChild("Sammy", true)
    if not sam then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == "Sam" or obj.Name == "NPC_Sam") then
                sam = obj
                break
            end
        end
    end
    return sam
end

-- Jual semua buah yang ada di tas ke NPC Sam
SellAllFruitsToSam = function()
    if State.IsSellingToSam then return end
    State.IsSellingToSam = true

    local fruitTools = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character

    local function collectFruitsFrom(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if IsFruitOnly(item) then
                table.insert(fruitTools, item)
            end
        end
    end

    collectFruitsFrom(backpack)
    collectFruitsFrom(character)

    if #fruitTools == 0 then
        AppendLog("[SELL SAM] Tidak ada buah tersisa di tas untuk dijual ke Sam.", Color3.fromRGB(200, 200, 150))
        State.IsSellingToSam = false
        return
    end

    AppendLog(string.format("[SELL SAM] Trait berganti! Menjual %d buah di tas ke NPC Sam...", #fruitTools), Color3.fromRGB(255, 180, 50))

    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local soldCount = 0

    for _, tool in ipairs(fruitTools) do
        if tool and tool.Parent then
            -- 1. Panggil Remote Sell_Item
            if SellItemRemote then
                pcall(function()
                    SellItemRemote:FireServer(tool)
                end)
            end

            -- 2. Fallback Equip tool & panggil Sell_Item
            if humanoid and tool.Parent == backpack then
                pcall(function()
                    humanoid:EquipTool(tool)
                    task.wait(0.04)
                    if SellItemRemote then
                        SellItemRemote:FireServer(tool)
                    end
                end)
            end

            soldCount = soldCount + 1
            task.wait(0.05) -- Anti-throttle delay
        end
    end

    -- 3. Trigger ProximityPrompt pada Sam jika tersedia
    local sam = GetSamNPC()
    if sam then
        pcall(function()
            for _, prompt in ipairs(sam:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled and (prompt.ActionText:lower():find("sell") or prompt.ObjectText:lower():find("sell")) then
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    end
                end
            end
        end)
    end

    AppendLog(string.format("[SELL SAM] Sukses menjual %d buah ke NPC Sam!", soldCount), Color3.fromRGB(100, 255, 120))
    State.IsSellingToSam = false

    task.wait(0.5)
    if CheckAndSubmitBackpackFruits then
        CheckAndSubmitBackpackFruits()
    end
end

-- ========================================================================================
-- FITUR: AUTO RESTART EVENT DENGAN 1T SHECKLES (SETELAH 20x SUBMIT / EXCAVATION COMPLETE)
-- ========================================================================================
CheckAndAutoRestartArchie = function()
    if not Config.AutoRestartEvent then return false end
    if State.IsRestarting then return false end

    local canRestart = false
    local detailReason = ""

    -- 1. Evaluasi melalui modul resmi AncientArcController
    if AncientArcController then
        pcall(function()
            if AncientArcController.CanRestart and AncientArcController:CanRestart() then
                canRestart = true
                detailReason = "AncientArcController:CanRestart() = true"
            elseif AncientArcController.GetProgress then
                local prog = AncientArcController:GetProgress()
                if prog and prog.Done then
                    canRestart = true
                    detailReason = "GetProgress().Done = true"
                end
            end
        end)
    end

    -- 2. Evaluasi melalui DataService game
    if not canRestart and DataService and DataService.GetData then
        pcall(function()
            local data = DataService:GetData()
            if data and data.AncientArcData and data.AncientArcData.Stage then
                local stage = tonumber(data.AncientArcData.Stage) or 1
                if stage > 20 then
                    canRestart = true
                    detailReason = string.format("Stage selesai (%d/20)", stage)
                end
            end
        end)
    end

    -- 3. Evaluasi melalui Visual Billboard/ThoughtBubble Archie ("Talk to me to restart!")
    if not canRestart then
        pcall(function()
            for _, tagModel in ipairs(CollectionService:GetTagged("AncientArcModel")) do
                local thought = tagModel:FindFirstChild("ThoughtBubblePart", true)
                if thought then
                    local bb = thought:FindFirstChildWhichIsA("BillboardGui", true)
                    for _, lbl in ipairs(bb:GetDescendants()) do
                        if lbl:IsA("TextLabel") and (lbl.Text:find("restart") or lbl.Text:find("every find") or lbl.Text:find("Complete")) then
                            canRestart = true
                            detailReason = "ThoughtBubble: " .. lbl.Text
                            break
                        end
                    end
                end
            end
        end)
    end

    if canRestart then
        State.IsRestarting = true
        AppendLog("[AUTO RESTART] Excavation Complete (20/20)! Me-restart event Archie dengan Sheckles (1T)...", Color3.fromRGB(255, 215, 0))

        local restartSuccess = false

        -- 1. Invoke RemoteFunction AncientArc.Restart
        local restartRemote = AncientArcFolder and AncientArcFolder:FindFirstChild("Restart")
        if not restartRemote then
            pcall(function()
                restartRemote = ReplicatedStorage.GameEvents.Events.AnubisEvent.AncientArc.Restart
            end)
        end

        if restartRemote and restartRemote:IsA("RemoteFunction") then
            local ok, res = pcall(function()
                return restartRemote:InvokeServer()
            end)
            if ok then
                if type(res) == "table" and res.Success == false then
                    AppendLog("[AUTO RESTART] Respon: " .. tostring(res.Reason or "Sheckles tidak mencukupi / Cooldown"), Color3.fromRGB(255, 100, 100))
                else
                    restartSuccess = true
                end
            end
        end

        -- 2. Fallback via Controller RestartWithSheckles
        if not restartSuccess and AncientArcController and AncientArcController.RestartWithSheckles then
            local ok, res = pcall(function()
                return AncientArcController:RestartWithSheckles()
            end)
            if ok and (type(res) ~= "table" or res.Success ~= false) then
                restartSuccess = true
            end
        end

        if restartSuccess then
            AppendLog("[AUTO RESTART] SUKSES! Event Archie berhasil di-restart ke Stage 1!", Color3.fromRGB(0, 255, 170))
            task.wait(1.5)
            CheckAndUpdateArchieTrait()
            GetMatchingHarvestables()
            if CheckAndSubmitBackpackFruits then
                CheckAndSubmitBackpackFruits()
            end
            State.IsRestarting = false
            return true
        end

        State.IsRestarting = false
    end

    return false
end


-- ========================================================================================
-- FITUR: HILANGKAN / SKIP ANIMASI OPENING REWARD ("Brushed Up" / Dug Up / 3D Model Spin)
-- ========================================================================================

-- Patch in-memory Game Config agar durasi reveal menjadi instan (0 detik)
PatchRevealConfig = function()
    pcall(function()
        if AncientArcConfig then
            AncientArcConfig.REVEAL_FLY_TIME = 0.001
            AncientArcConfig.REVEAL_HOLD_TIME = 0
            AncientArcConfig.REVEAL_SHAKE = 0
            AncientArcConfig.REVEAL_POPUP_TIME = 0.001
        end
    end)
    pcall(function()
        local GameConfigController = ModulesFolder and require(ModulesFolder:WaitForChild("GameConfigController", 2))
        if GameConfigController and GameConfigController.GetConfig then
            local cfg = GameConfigController:GetConfig("AncientArcConfig")
            if cfg then
                cfg.REVEAL_FLY_TIME = 0.001
                cfg.REVEAL_HOLD_TIME = 0
                cfg.REVEAL_SHAKE = 0
                cfg.REVEAL_POPUP_TIME = 0.001
            end
        end
    end)
end

-- Helper untuk menutup card popup reward secara instan melalui klik sensor / visible = false
local function DismissRewardCard(card)
    if not card or not card:IsA("GuiObject") then return end
    pcall(function()
        local sensor = card:FindFirstChild("SENSOR", true)
        if sensor and sensor:IsA("GuiButton") then
            local clicked = false
            if firesignal then
                pcall(function() firesignal(sensor.Activated); clicked = true end)
            end
            if not clicked and getconnections then
                pcall(function()
                    for _, conn in ipairs(getconnections(sensor.Activated)) do
                        pcall(function() conn:Fire(); clicked = true end)
                    end
                end)
            end
            if not clicked and sensor.Activate then
                pcall(function() sensor:Activate(); clicked = true end)
            end
        end
        card.Visible = false
    end)
end

-- Cari dan tutup reward popup yang sedang terbuka di PlayerGui
DismissActiveRewardCard = function()
    pcall(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return end
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc.Name == "AncientArcEventReward" and desc:IsA("GuiObject") and desc.Visible then
                DismissRewardCard(desc)
                if AppendLog then
                    AppendLog("[REWARD] Animasi reward ('Brushed Up') berhasil dilewati instan!", Color3.fromRGB(255, 215, 0))
                end
            elseif desc.Name == "AncientArcReveal_UI" and desc:IsA("ScreenGui") then
                desc.Enabled = false
                pcall(function() desc:Destroy() end)
            end
        end
    end)
end

-- Pasang listener pemantau reward & model 3D di PlayerGui & Workspace
SetupRewardAnimationSkipper = function()
    PatchRevealConfig()

    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pgui then return end

    local function HookRewardCard(card)
        if not card or not card:IsA("GuiObject") then return end
        if card:GetAttribute("HUKI_RewardHooked") then return end
        pcall(function() card:SetAttribute("HUKI_RewardHooked", true) end)

        if Config.SkipRewardAnimation and card.Visible then
            task.defer(function()
                DismissRewardCard(card)
                if AppendLog then
                    AppendLog("[REWARD] Animasi reward ('Brushed Up') dilewati instan!", Color3.fromRGB(255, 215, 0))
                end
            end)
        end

        card:GetPropertyChangedSignal("Visible"):Connect(function()
            if Config.SkipRewardAnimation and card.Visible then
                task.defer(function()
                    DismissRewardCard(card)
                    if AppendLog then
                        AppendLog("[REWARD] Animasi reward ('Brushed Up') dilewati instan!", Color3.fromRGB(255, 215, 0))
                    end
                end)
            end
        end)
    end

    -- Hook card yang sudah ada di PlayerGui
    pcall(function()
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc.Name == "AncientArcEventReward" and desc:IsA("GuiObject") then
                HookRewardCard(desc)
            elseif desc.Name == "AncientArcReveal_UI" and desc:IsA("ScreenGui") then
                if Config.SkipRewardAnimation then
                    desc.Enabled = false
                    pcall(function() desc:Destroy() end)
                end
            end
        end
    end)

    -- Hook card atau ScreenGui baru yang ditambahkan kemudian
    pgui.DescendantAdded:Connect(function(desc)
        if not Config.SkipRewardAnimation then return end
        pcall(function()
            if desc.Name == "AncientArcEventReward" and desc:IsA("GuiObject") then
                HookRewardCard(desc)
                task.defer(function()
                    if Config.SkipRewardAnimation and desc.Visible then
                        DismissRewardCard(desc)
                        if AppendLog then
                            AppendLog("[REWARD] Animasi reward ('Brushed Up') dilewati instan!", Color3.fromRGB(255, 215, 0))
                        end
                    end
                end)
            elseif desc.Name == "AncientArcReveal_UI" and desc:IsA("ScreenGui") then
                desc.Enabled = false
                task.defer(function()
                    pcall(function() desc:Destroy() end)
                end)
            end
        end)
    end)

    -- Sembunyikan model 3D spin crate/urn yang berputar di depan kamera
    workspace.DescendantAdded:Connect(function(desc)
        if not Config.SkipRewardAnimation then return end
        pcall(function()
            if desc.Name == "CentralWeldPart" and desc:IsA("BasePart") then
                local model = desc.Parent
                if model and model:IsA("Model") then
                    for _, p in ipairs(model:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.Transparency = 1
                        end
                    end
                end
            end
        end)
    end)

    -- Hook AncientArcController.Open jika tersedia agar invoke server langsung cepat
    pcall(function()
        if AncientArcController and type(AncientArcController.Open) == "function" then
            local oldOpen = AncientArcController.Open
            AncientArcController.Open = function(self, ...)
                if Config.SkipRewardAnimation then
                    PatchRevealConfig()
                end
                local res = oldOpen(self, ...)
                if Config.SkipRewardAnimation then
                    task.defer(function()
                        DismissActiveRewardCard()
                    end)
                end
                return res
            end
        end
    end)

    -- Periodic background loop pengaman
    task.spawn(function()
        while true do
            task.wait(0.5)
            if Config.SkipRewardAnimation then
                pcall(DismissActiveRewardCard)
                pcall(PatchRevealConfig)
            end
        end
    end)
end

-- ========================================================================================
-- 6. EKSEKUSI PEMANENAN & SUBMIT ARCHIE
-- ========================================================================================

-- Eksekusi panen 1 buah secara instan
local function HarvestSingleFruit(fruitModel)
    local fired = false

    -- 1. Crops.Collect RemoteEvent
    if CollectRemote then
        local ok, _ = pcall(function()
            CollectRemote:FireServer({ fruitModel })
        end)
        if ok then fired = true end
    end

    -- 2. Fallback ProximityPrompt
    if not fired or fireproximityprompt then
        pcall(function()
            for _, prompt in ipairs(fruitModel:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                        fired = true
                    end
                end
            end
        end)
    end

    -- Beri tag sementara agar tidak terpanen ganda dalam satu frame
    pcall(function()
        fruitModel:SetAttribute("Collected", true)
        task.delay(1.5, function()
            if fruitModel and fruitModel.Parent then
                fruitModel:SetAttribute("Collected", nil)
            end
        end)
    end)

    return fired
end

-- Eksekusi panen seluruh buah yang cocok dengan Archie
local function ExecuteCollectMatchingFruits()
    if State.IsCollecting then return end
    State.IsCollecting = true

    local targetTrait = Config.AutoSyncArchie and State.CurrentArchieTrait or Config.ManualTrait

    if targetTrait == "Checking..." or targetTrait == "Unknown" or not targetTrait then
        AppendLog("[WARNING] Sedang mendeteksi permintaan Archie... Menunggu sinkronisasi.", Color3.fromRGB(240, 200, 80))
        State.IsCollecting = false
        return
    end

    if Config.CheckBackpack and IsBackpackFull() then
        AppendLog("[WARNING] Tas/Backpack PENUH! Jual atau serahkan buah ke Archie.", Color3.fromRGB(255, 120, 50))
        
        -- Jika Auto Submit aktif, langsung serahkan ke Archie!
        if Config.AutoSubmitToArchie then
            AppendLog("[AUTO SUBMIT] Menyerahkan hasil panen ke Archeologist Archie...", Color3.fromRGB(0, 220, 255))
            pcall(function()
                if AncientArcSubmitRemote then
                    AncientArcSubmitRemote:FireServer({ Token = 1, Mode = "All" })
                end
            end)
        end
        State.IsCollecting = false
        return
    end

    local matchingItems, myFarm = GetMatchingHarvestables()

    if not myFarm then
        AppendLog("[ERROR] Kebun (Farm) tidak ditemukan! Berdirilah di kebun Anda.", Color3.fromRGB(255, 80, 80))
        State.IsCollecting = false
        return
    end

    if #matchingItems == 0 then
        State.IsCollecting = false
        return
    end

    AppendLog(string.format("[HARVEST] Memanen %d tanaman bertipe [%s]...", #matchingItems, targetTrait), TraitColorMap[targetTrait] or Color3.fromRGB(100, 255, 100))

    local harvestedInThisCycle = 0
    for _, item in ipairs(matchingItems) do
        if Config.CheckBackpack and IsBackpackFull() then
            AppendLog("[WARNING] Tas penuh saat panen berlangsung!", Color3.fromRGB(255, 120, 50))
            break
        end

        if item.Model and item.Model:IsDescendantOf(workspace) then
            local success = HarvestSingleFruit(item.Model)
            if success then
                harvestedInThisCycle = harvestedInThisCycle + 1
                State.TotalHarvested = State.TotalHarvested + 1
            end
            task.wait(Config.BatchDelay)
        end
    end

    if harvestedInThisCycle > 0 then
        AppendLog(string.format("[SELESAI] Sukses memanen %d buah bertrait [%s]!", harvestedInThisCycle, targetTrait), Color3.fromRGB(100, 255, 120))
        UpdateStatsDisplay()
    end

    -- Auto Submit opsional setelah selesai panen
    if Config.AutoSubmitToArchie and harvestedInThisCycle > 0 then
        task.wait(0.5)
        pcall(function()
            if AncientArcSubmitRemote then
                AncientArcSubmitRemote:FireServer({ Token = 1, Mode = "All" })
                AppendLog("[AUTO SUBMIT] Menyerahkan buah ke Archie!", Color3.fromRGB(100, 220, 255))
            end
        end)
    end

    State.IsCollecting = false
end

-- Submit Manual ke Archie
local function SubmitAllToArchie()
    if not AncientArcSubmitRemote then
        pcall(function()
            AncientArcSubmitRemote = ReplicatedStorage.GameEvents.Events.AnubisEvent.AncientArc.Submit
        end)
    end

    if not AncientArcSubmitRemote then
        AppendLog("[ERROR] Remote Submit Archie tidak ditemukan!", Color3.fromRGB(255, 80, 80))
        return
    end

    local ok, err = pcall(function()
        AncientArcSubmitRemote:FireServer({ Token = 1, Mode = "All" })
    end)

    if ok then
        AppendLog("[SUBMIT] Sukses memanggil Submit All ke Archeologist Archie!", Color3.fromRGB(100, 255, 200))
    else
        AppendLog("[ERROR] Gagal submit ke Archie: " .. tostring(err), Color3.fromRGB(255, 80, 80))
    end
end

-- Teleport ke NPC Archie
local function TeleportToArchie()
    local archieModel = nil
    pcall(function()
        for _, tagModel in ipairs(CollectionService:GetTagged("AncientArcModel")) do
            if tagModel:IsA("Model") and tagModel:IsDescendantOf(workspace) then
                local npc = tagModel:FindFirstChild("Important") and tagModel.Important:FindFirstChild("NPC")
                archieModel = npc or tagModel:FindFirstChild("NPC", true) or tagModel
                break
            end
        end
    end)
    if not archieModel then
        archieModel = workspace:FindFirstChild("Archeologist Archie", true) or workspace:FindFirstChild("Archie", true)
    end

    if archieModel then
        local targetPos = archieModel:GetPivot().Position
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 4), targetPos)
            AppendLog("[TELEPORT] Berhasil teleport ke Archeologist Archie!", Color3.fromRGB(100, 255, 150))
            return
        end
    end
    AppendLog("[ERROR] Model NPC Archeologist Archie tidak ditemukan di workspace!", Color3.fromRGB(255, 80, 80))
end

-- ========================================================================================
-- 7. AUTO COLLECT & BACKPACK MONITOR LOOPS
-- ========================================================================================

-- Loop 1: Auto Collect Kebun Player
task.spawn(function()
    while true do
        if Config.AutoCollect then
            pcall(ExecuteCollectMatchingFruits)
        else
            -- Perbarui hitungan tanaman cocok di background agar stats tetap akurat
            pcall(GetMatchingHarvestables)
        end
        task.wait(Config.CollectInterval)
    end
end)

-- Loop 2: Auto Submit Buah Archie & Auto Restart (Interval 5 Detik)
task.spawn(function()
    while true do
        task.wait(Config.BackpackCheckInterval or 5.0)
        if CheckAndAutoRestartArchie then
            pcall(CheckAndAutoRestartArchie)
        end
        if CheckAndSubmitBackpackFruits then
            pcall(CheckAndSubmitBackpackFruits)
        end
    end
end)

-- ========================================================================================
-- 8. PEMBUATAN USER INTERFACE (HUKI MODERN DARK THEME)
-- ========================================================================================
local safeParent = GetSafeGuiParent()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HUKI_ArchieCollector_Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = safeParent

if getgenv then
    getgenv().HUKI_ArchieCollector_Gui = ScreenGui
end

-- Container Utama
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 480)
MainFrame.Position = UDim2.new(0.5, -190, 0.45, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.2
MainStroke.Color = Color3.fromRGB(45, 52, 65)
MainStroke.Parent = MainFrame

-- Floating Minimize Pill (Tombol restore saat di-minimize)
local MinimizePill = Instance.new("TextButton")
MinimizePill.Name = "MinimizePill"
MinimizePill.Size = UDim2.new(0, 160, 0, 36)
MinimizePill.Position = UDim2.new(0, 20, 0, 80)
MinimizePill.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
MinimizePill.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizePill.Font = Enum.Font.GothamBold
MinimizePill.TextSize = 13
MinimizePill.Text = "HiiiHuuu"
MinimizePill.Visible = false
MinimizePill.Parent = ScreenGui

local PillCorner = Instance.new("UICorner")
PillCorner.CornerRadius = UDim.new(0, 18)
PillCorner.Parent = MinimizePill

local PillStroke = Instance.new("UIStroke")
PillStroke.Color = Color3.fromRGB(39, 174, 96)
PillStroke.Thickness = 1.5
PillStroke.Parent = MinimizePill

-- Dragging Engine untuk MainFrame & MinimizePill
local function MakeDraggable(guiObject)
    local dragging = false
    local dragInput, dragStart, startPos

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(MainFrame)
MakeDraggable(MinimizePill)

-- Header Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -80, 1, 0)
HeaderTitle.Position = UDim2.new(0, 12, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 14
HeaderTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Text = "HiiiHuuu ANUBIS EVENT"
HeaderTitle.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -66, 0, 7)
MinBtn.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(200, 210, 230)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.Parent = Header
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 28, 30)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Header
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinimizePill.Visible = true
end)

MinimizePill.MouseButton1Click:Connect(function()
    MinimizePill.Visible = false
    MainFrame.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    if getgenv then getgenv().HUKI_ArchieCollector_Gui = nil end
end)

-- Content ScrollFrame
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -50)
Content.Position = UDim2.new(0, 8, 0, 46)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 85)
Content.CanvasSize = UDim2.new(0, 0, 0, 720)
Content.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.Parent = Content

-- Helper Card Box
local function CreateSection(layoutOrder, height)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, height)
    section.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    section.BorderSizePixel = 0
    section.LayoutOrder = layoutOrder
    section.Parent = Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = section

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 42, 54)
    stroke.Thickness = 1
    stroke.Parent = section

    return section
end

-- ============================================================================
-- SECTION 1: ARCHIE LIVE TRAIT MONITOR
-- ============================================================================
local Section1 = CreateSection(1, 90)

local ArchieLabel = Instance.new("TextLabel")
ArchieLabel.Size = UDim2.new(1, -16, 0, 20)
ArchieLabel.Position = UDim2.new(0, 10, 0, 8)
ArchieLabel.BackgroundTransparency = 1
ArchieLabel.Font = Enum.Font.GothamBold
ArchieLabel.TextSize = 12
ArchieLabel.TextColor3 = Color3.fromRGB(170, 180, 200)
ArchieLabel.TextXAlignment = Enum.TextXAlignment.Left
ArchieLabel.Text = "NPC ARCHEOLOGIST ARCHIE STATUS"
ArchieLabel.Parent = Section1

local TraitCard = Instance.new("Frame")
TraitCard.Size = UDim2.new(1, -20, 0, 50)
TraitCard.Position = UDim2.new(0, 10, 0, 32)
TraitCard.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
TraitCard.BorderSizePixel = 0
TraitCard.Parent = Section1

local TraitCardCorner = Instance.new("UICorner")
TraitCardCorner.CornerRadius = UDim.new(0, 6)
TraitCardCorner.Parent = TraitCard

local LookingForLabel = Instance.new("TextLabel")
LookingForLabel.Size = UDim2.new(0.48, 0, 1, 0)
LookingForLabel.Position = UDim2.new(0, 8, 0, 0)
LookingForLabel.BackgroundTransparency = 1
LookingForLabel.Font = Enum.Font.GothamMedium
LookingForLabel.TextSize = 12
LookingForLabel.TextColor3 = Color3.fromRGB(200, 210, 220)
LookingForLabel.TextXAlignment = Enum.TextXAlignment.Left
LookingForLabel.Text = "Archie Looking for:"
LookingForLabel.Parent = TraitCard

local TraitBadge = Instance.new("TextLabel")
TraitBadge.Size = UDim2.new(0.48, -10, 0, 32)
TraitBadge.Position = UDim2.new(0.52, 0, 0.5, -16)
TraitBadge.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
TraitBadge.Font = Enum.Font.GothamBold
TraitBadge.TextSize = 14
TraitBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
TraitBadge.Text = "Fruit"
TraitBadge.Parent = TraitCard

local TraitBadgeCorner = Instance.new("UICorner")
TraitBadgeCorner.CornerRadius = UDim.new(0, 6)
TraitBadgeCorner.Parent = TraitBadge

UpdateTraitDisplay = function()
    pcall(function()
        local trait = State.CurrentArchieTrait or "Fruit"
        local color = TraitColorMap[trait] or Color3.fromRGB(39, 174, 96)
        if TraitBadge and TraitBadge.Parent then
            TraitBadge.Text = trait .. " Plants"
            TraitBadge.BackgroundColor3 = color
        end
        if PillStroke and PillStroke.Parent then
            PillStroke.Color = color
        end
    end)
end

-- ============================================================================
-- SECTION 2: KONTROL AUTO COLLECT & TOGGLES (7 TOGGLES)
-- ============================================================================
local Section2 = CreateSection(2, 226)

local function CreateToggleRow(yPos, titleText, initialVal, onToggleCallback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 26)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = Section2

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = titleText
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 52, 0, 24)
    btn.Position = UDim2.new(1, -52, 0, 1)
    btn.BackgroundColor3 = initialVal and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(48, 54, 68)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = initialVal and "ON" or "OFF"
    btn.Parent = row

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        task.spawn(function()
            local current = (btn.Text == "ON")
            local nextVal = not current
            btn.Text = nextVal and "ON" or "OFF"
            btn.BackgroundColor3 = nextVal and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(48, 54, 68)
            onToggleCallback(nextVal)
        end)
    end)

    return row, btn
end

-- Toggle 1: Auto Collect Loop
CreateToggleRow(8, "Auto Collect Matching Fruits", Config.AutoCollect, function(val)
    Config.AutoCollect = val
    if val then
        AppendLog("[LOOP] Auto Collect AKTIF! Memanen buah sesuai kebutuhan Archie...", Color3.fromRGB(100, 255, 120))
    else
        AppendLog("[LOOP] Auto Collect DIMATIKAN.", Color3.fromRGB(255, 150, 150))
    end
end)

-- Toggle 2: Auto Sync Archie Trait (Real-Time Switch)
CreateToggleRow(38, "Auto Sync Archie Trait (Real-Time)", Config.AutoSyncArchie, function(val)
    Config.AutoSyncArchie = val
    if val then
        State.ActiveTargetTrait = State.CurrentArchieTrait
        AppendLog("[SYNC] Sinkronisasi real-time Archie DIAKTIFKAN.", Color3.fromRGB(0, 220, 255))
        UpdateTraitDisplay()
    else
        AppendLog("[SYNC] Mode manual diaktifkan (Pilih trait sendiri).", Color3.fromRGB(240, 200, 100))
    end
end)

-- Toggle 3: Auto Submit Buah Archie dari Backpack (Loop 5s)
CreateToggleRow(68, "Auto Submit Buah di Tas (Loop 5s)", Config.AutoSubmitArchieBackpack, function(val)
    Config.AutoSubmitArchieBackpack = val
    if val then
        AppendLog("[CONFIG] Auto Submit Buah Archie di Tas (Interval 5 Detik) AKTIF.", Color3.fromRGB(0, 220, 255))
        if CheckAndSubmitBackpackFruits then
            task.spawn(CheckAndSubmitBackpackFruits)
        end
    else
        AppendLog("[CONFIG] Auto Submit Buah Archie di Tas NONAKTIF.", Color3.fromRGB(200, 200, 200))
    end
end)

-- Toggle 4: Auto Restart Event (1T Sheckles setelah 20x submit)
CreateToggleRow(98, "Auto Restart Event (1T¢ / Max 20x)", Config.AutoRestartEvent, function(val)
    Config.AutoRestartEvent = val
    if val then
        AppendLog("[CONFIG] Auto Restart Event Archie (1T Sheckles) DIAKTIFKAN.", Color3.fromRGB(255, 215, 0))
        if CheckAndAutoRestartArchie then
            task.spawn(CheckAndAutoRestartArchie)
        end
    else
        AppendLog("[CONFIG] Auto Restart Event Archie NONAKTIF.", Color3.fromRGB(200, 200, 200))
    end
end)

-- Toggle 5: Auto Jual Buah ke Sam saat Trait Berubah
CreateToggleRow(128, "Auto Jual Buah ke Sam saat Trait Ganti", Config.AutoSellFruitsToSamOnTraitChange, function(val)
    Config.AutoSellFruitsToSamOnTraitChange = val
    if val then
        AppendLog("[CONFIG] Auto Jual Buah ke NPC Sam saat Trait Berubah DIAKTIFKAN.", Color3.fromRGB(255, 180, 50))
    else
        AppendLog("[CONFIG] Auto Jual Buah ke NPC Sam NONAKTIF.", Color3.fromRGB(200, 200, 200))
    end
end)

-- Toggle 6: Proteksi Solo Nightmare
CreateToggleRow(158, "Proteksi Solo Nightmare (Jangan Panen)", Config.ProtectSoloNightmare, function(val)
    Config.ProtectSoloNightmare = val
    AppendLog(val and "[CONFIG] Proteksi Solo Nightmare AKTIF." or "[CONFIG] Proteksi Solo Nightmare NONAKTIF.", Color3.fromRGB(200, 200, 200))
end)

-- Toggle 7: Skip Animasi Opening Reward ("Brushed Up")
CreateToggleRow(188, "Skip Opening Reward Animation", Config.SkipRewardAnimation, function(val)
    Config.SkipRewardAnimation = val
    if val then
        if PatchRevealConfig then PatchRevealConfig() end
        if DismissActiveRewardCard then DismissActiveRewardCard() end
        AppendLog("[REWARD] Skip Animasi Opening Reward DIAKTIFKAN.", Color3.fromRGB(255, 215, 0))
    else
        AppendLog("[REWARD] Skip Animasi Opening Reward NONAKTIF.", Color3.fromRGB(200, 200, 200))
    end
end)

-- ============================================================================
-- SECTION 3: TOMBOL AKSI CEPAT (QUICK ACTIONS - 6 BUTTONS)
-- ============================================================================
local Section3 = CreateSection(3, 126)

local function CreateActionBtn(xPos, yPos, width, height, text, bgCol, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 0, height)
    btn.Position = UDim2.new(0, xPos, 0, yPos)
    btn.BackgroundColor3 = bgCol
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = Section3

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        task.spawn(function()
            pcall(onClick)
        end)
    end)
    return btn
end

-- Baris 1: Panen & Submit Archie
CreateActionBtn(10, 8, 165, 32, "PANEN COCOK SEKARANG", Color3.fromRGB(39, 174, 96), function()
    AppendLog("[MANUAL] Memicu panen instan seluruh buah yang cocok...", Color3.fromRGB(100, 255, 120))
    ExecuteCollectMatchingFruits()
end)

CreateActionBtn(185, 8, 165, 32, "SUBMIT ALL KE ARCHIE", Color3.fromRGB(41, 128, 185), function()
    SubmitAllToArchie()
end)

-- Baris 2: Teleport & Refresh
CreateActionBtn(10, 46, 165, 32, "TELEPORT KE ARCHIE", Color3.fromRGB(142, 68, 173), function()
    TeleportToArchie()
end)

CreateActionBtn(185, 46, 165, 32, "REFRESH KEBUN & TAS", Color3.fromRGB(52, 73, 94), function()
    CheckAndUpdateArchieTrait()
    GetMatchingHarvestables()
    if CheckAndSubmitBackpackFruits then
        CheckAndSubmitBackpackFruits()
    end
    AppendLog("[SCAN] Status kebun, tas, dan permintaan Archie diperbarui.", Color3.fromRGB(200, 220, 255))
end)

-- Baris 3: Restart Archie (1T) & Jual Buah ke Sam
CreateActionBtn(10, 84, 165, 32, "RESTART EVENT (1T¢)", Color3.fromRGB(212, 160, 23), function()
    AppendLog("[MANUAL] Memicu Restart Event Archie dengan 1T Sheckles...", Color3.fromRGB(255, 215, 0))
    if CheckAndAutoRestartArchie then
        CheckAndAutoRestartArchie()
    end
end)

CreateActionBtn(185, 84, 165, 32, "JUAL SEMUA BUAH KE SAM", Color3.fromRGB(230, 126, 34), function()
    AppendLog("[MANUAL] Memicu penjualan seluruh buah di tas ke NPC Sam...", Color3.fromRGB(255, 180, 50))
    if SellAllFruitsToSam then
        SellAllFruitsToSam()
    end
end)

-- ============================================================================
-- SECTION 4: LIVE STATS DASHBOARD
-- ============================================================================
local Section4 = CreateSection(4, 52)

local StatsLabel1 = Instance.new("TextLabel")
StatsLabel1.Size = UDim2.new(0.5, -12, 1, 0)
StatsLabel1.Position = UDim2.new(0, 10, 0, 0)
StatsLabel1.BackgroundTransparency = 1
StatsLabel1.Font = Enum.Font.GothamSemibold
StatsLabel1.TextSize = 11
StatsLabel1.TextColor3 = Color3.fromRGB(200, 215, 230)
StatsLabel1.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel1.Text = "Panen: 0 | Kebun: 0"
StatsLabel1.Parent = Section4

local StatsLabel2 = Instance.new("TextLabel")
StatsLabel2.Size = UDim2.new(0.5, -12, 1, 0)
StatsLabel2.Position = UDim2.new(0.5, 2, 0, 0)
StatsLabel2.BackgroundTransparency = 1
StatsLabel2.Font = Enum.Font.GothamSemibold
StatsLabel2.TextSize = 11
StatsLabel2.TextColor3 = Color3.fromRGB(200, 215, 230)
StatsLabel2.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel2.Text = "Cocok di Tas: 0 buah"
StatsLabel2.Parent = Section4

UpdateStatsDisplay = function()
    pcall(function()
        if StatsLabel1 and StatsLabel1.Parent then
            StatsLabel1.Text = string.format("Panen: %d | Kebun: %d", State.TotalHarvested, State.ReadyMatching)
        end
        if StatsLabel2 and StatsLabel2.Parent then
            StatsLabel2.Text = string.format("Cocok di Tas: %d buah", State.BackpackMatchingCount or 0)
        end
    end)
end

-- ============================================================================
-- SECTION 5: REAL-TIME ACTIVITY LOG VIEWER
-- ============================================================================
local Section5 = CreateSection(5, 140)

local LogTitle = Instance.new("TextLabel")
LogTitle.Size = UDim2.new(1, -20, 0, 18)
LogTitle.Position = UDim2.new(0, 10, 0, 6)
LogTitle.BackgroundTransparency = 1
LogTitle.Font = Enum.Font.GothamBold
LogTitle.TextSize = 11
LogTitle.TextColor3 = Color3.fromRGB(150, 165, 185)
LogTitle.TextXAlignment = Enum.TextXAlignment.Left
LogTitle.Text = "ACTIVITY LOG CONSOLE"
LogTitle.Parent = Section5

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -20, 0, 106)
LogScroll.Position = UDim2.new(0, 10, 0, 26)
LogScroll.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 3
LogScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 85)
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.Parent = Section5

local LogScrollCorner = Instance.new("UICorner")
LogScrollCorner.CornerRadius = UDim.new(0, 6)
LogScrollCorner.Parent = LogScroll

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 2)
LogLayout.Parent = LogScroll

local logEntries = {}
local maxLogEntries = 50

AppendLog = function(msg, color)
    pcall(function()
        if not LogScroll or not LogScroll.Parent then return end
        local timeStr = os.date("%H:%M:%S")
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, -6, 0, 16)
        entry.BackgroundTransparency = 1
        entry.Font = Enum.Font.Code
        entry.TextSize = 10
        entry.TextColor3 = color or Color3.fromRGB(220, 225, 235)
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.Text = string.format("[%s] %s", timeStr, msg)
        entry.LayoutOrder = #logEntries + 1
        entry.Parent = LogScroll

        table.insert(logEntries, entry)
        if #logEntries > maxLogEntries then
            local old = table.remove(logEntries, 1)
            if old then old:Destroy() end
        end

        LogScroll.CanvasSize = UDim2.new(0, 0, 0, #logEntries * 18)
        LogScroll.CanvasPosition = Vector2.new(0, math.max(0, #logEntries * 18 - 106))
    end)
end

-- Inisialisasi Pertama
task.spawn(function()
    task.wait(0.2)
    if SetupRewardAnimationSkipper then
        pcall(SetupRewardAnimationSkipper)
    end
    CheckAndUpdateArchieTrait()
    UpdateTraitDisplay()
    GetMatchingHarvestables()
    if CheckAndSubmitBackpackFruits then
        CheckAndSubmitBackpackFruits()
    end
    AppendLog("Script Auto Collect Archie siap digunakan!", Color3.fromRGB(0, 255, 170))
    AppendLog(string.format("Kebutuhan Archie saat ini: [%s]", State.CurrentArchieTrait or "Fruit"), TraitColorMap[State.CurrentArchieTrait] or Color3.fromRGB(255, 255, 255))
    if Config.SkipRewardAnimation then
        AppendLog("[REWARD] Bypass animasi opening reward ('Brushed Up') aktif!", Color3.fromRGB(255, 215, 0))
    end
end)

