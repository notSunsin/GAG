local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local _CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Pembersihan instance GUI lama jika ada
if getgenv and getgenv().HiiHuu_ArchieCollector_Gui then
    pcall(function()
        getgenv().HiiHuu_ArchieCollector_Gui:Destroy()
    end)
    getgenv().HiiHuu_ArchieCollector_Gui = nil
end

pcall(function()
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local old = pgui:FindFirstChild("HiiHuu_ArchieCollector_Gui")
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
local _AncientArcOpenRemote = AncientArcFolder and AncientArcFolder:FindFirstChild("Open")
local _AncientArcRestartRemote = AncientArcFolder and AncientArcFolder:FindFirstChild("Restart")

-- Remote Crops & Selling to Sam
local CropsEvents = GameEvents and GameEvents:FindFirstChild("Crops")
local CollectRemote = CropsEvents and CropsEvents:FindFirstChild("Collect")
local SellItemRemote = GameEvents and GameEvents:FindFirstChild("Sell_Item")
local _SellInventoryRemote = GameEvents and GameEvents:FindFirstChild("Sell_Inventory")

-- Remote Trader Tina / Anubis Coin Shop
local BuyEventShopStockRemote = GameEvents and GameEvents:FindFirstChild("BuyEventShopStock")
if not BuyEventShopStockRemote then
    pcall(function()
        BuyEventShopStockRemote = ReplicatedStorage:WaitForChild("GameEvents", 5):WaitForChild("BuyEventShopStock", 5)
    end)
end
if not BuyEventShopStockRemote then
    pcall(function()
        BuyEventShopStockRemote = ReplicatedStorage:FindFirstChild("BuyEventShopStock", true)
    end)
end

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

-- 11 Item Resmi Anubis Coin Shop (NPC Trader Tina)
local TinaShopItems = {
    { Name = "Wraproot",           Price = 60,    Type = "Seed",     Rarity = "Uncommon" },
    { Name = "Hieroglyph Carpet",  Price = 150,   Type = "Cosmetic", Rarity = "Uncommon" },
    { Name = "Hieroglyphic Radar", Price = 250,   Type = "Gear",     Rarity = "Rare" },
    { Name = "Quicksand Mummy",    Price = 450,   Type = "Cosmetic", Rarity = "Rare" },
    { Name = "Anubis Crate",       Price = 500,   Type = "Crate",    Rarity = "Rare" },
    { Name = "Papyrus",            Price = 900,   Type = "Seed",     Rarity = "Legendary" },
    { Name = "Obsidian Obelisk",   Price = 1000,  Type = "Cosmetic", Rarity = "Mythical" },
    { Name = "Hieroglyphic Staff", Price = 1250,  Type = "Gear",     Rarity = "Legendary" },
    { Name = "Anubis Egg",         Price = 3000,  Type = "Egg",      Rarity = "Mythical" },
    { Name = "Pharaoh's Eye",      Price = 5000,  Type = "Seed",     Rarity = "Divine" },
    { Name = "Hiero Scorpion",     Price = 13500, Type = "Pet",      Rarity = "Prismatic" },
}

-- Warna Rarity untuk UI Shop
local RarityColorMap = {
    ["Common"]    = Color3.fromRGB(180, 180, 180),
    ["Uncommon"]  = Color3.fromRGB(46, 204, 113),
    ["Rare"]      = Color3.fromRGB(52, 152, 219),
    ["Legendary"] = Color3.fromRGB(241, 196, 15),
    ["Mythical"]  = Color3.fromRGB(155, 89, 182),
    ["Divine"]    = Color3.fromRGB(230, 126, 34),
    ["Prismatic"] = Color3.fromRGB(255, 75, 130),
}

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

    -- Trader Tina (Anubis Coin Shop)
    TinaAutoBuy = false,              -- Auto Buy selected items loop
    TinaBuyInterval = 1.5,            -- Interval loop auto buy (detik)
    TinaBuyDelay = 0.25,              -- Jeda antar pembelian remote (anti rate-limit)
    TinaSelectedItems = {
        ["Wraproot"] = false,
        ["Hieroglyph Carpet"] = false,
        ["Hieroglyphic Radar"] = false,
        ["Quicksand Mummy"] = false,
        ["Anubis Crate"] = false,
        ["Papyrus"] = false,
        ["Obsidian Obelisk"] = false,
        ["Hieroglyphic Staff"] = false,
        ["Anubis Egg"] = true,
        ["Pharaoh's Eye"] = true,
        ["Hiero Scorpion"] = true,
    },
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
    ActiveTab = "Archie",               -- Tab UI aktif ("Archie" atau "Tina")
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
local UpdateTinaCoinsDisplay
local UpdateTinaCheckboxes
local BuyAllSelectedTinaItems
local BuyTinaItem

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
        local mutMap, _mutCount = GetFruitMutations(fruitModel)
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
local _SubmitAllToArchie

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
    local _detailReason = ""

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
        if card:GetAttribute("HiiHuu_RewardHooked") then return end
        pcall(function() card:SetAttribute("HiiHuu_RewardHooked", true) end)

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
-- FITUR: AUTO BUY NPC TRADER TINA (ANUBIS COIN SHOP)
-- ========================================================================================

-- Format angka dengan koma (contoh: 13,500)
local function CommaNumber(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- Mendapatkan jumlah Anubis Coins yang dimiliki player saat ini
local function GetAnubisCoins()
    local coins = 0
    pcall(function()
        if DataService and DataService.GetData then
            local data = DataService:GetData()
            if data and data.AnubisCoins ~= nil then
                coins = tonumber(data.AnubisCoins) or 0
            end
        end
    end)
    return coins
end

-- Mendapatkan data stock item yang tersedia di shop Tina
local function GetItemStock(itemName)
    local stock = -1 -- -1 jika data stock tidak spesifik (tetap proses beli)
    pcall(function()
        if DataService and DataService.GetData then
            local data = DataService:GetData()
            local shopStock = data and data.EventShopStock and data.EventShopStock["Anubis Coin Shop"]
            if shopStock and shopStock.Stocks then
                local itemData = shopStock.Stocks[itemName]
                if itemData and itemData.Stock ~= nil then
                    stock = tonumber(itemData.Stock) or 0
                end
            end
        end
    end)
    return stock
end

-- Eksekusi pembelian 1 item spesifik ke remote resmi
BuyTinaItem = function(itemName)
    if not BuyEventShopStockRemote then
        pcall(function()
            BuyEventShopStockRemote = (GameEvents and GameEvents:FindFirstChild("BuyEventShopStock"))
                or ReplicatedStorage:FindFirstChild("BuyEventShopStock", true)
        end)
    end

    if not BuyEventShopStockRemote then
        AppendLog("[ERROR] Remote BuyEventShopStock tidak ditemukan!", Color3.fromRGB(255, 80, 80))
        return false
    end

    local ok, _err = pcall(function()
        BuyEventShopStockRemote:FireServer(itemName, "Anubis Coin Shop")
    end)
    return ok
end

-- Eksekusi pembelian 1x seluruh item yang dicentang di UI
BuyAllSelectedTinaItems = function()
    local selectedCount = 0
    for _, item in ipairs(TinaShopItems) do
        if Config.TinaSelectedItems[item.Name] then
            selectedCount = selectedCount + 1
            local success = BuyTinaItem(item.Name)
            if success then
                AppendLog(string.format("[TINA BUY] Sukses membeli %s (🪙 %s Coins)", item.Name, CommaNumber(item.Price)), Color3.fromRGB(255, 215, 0))
            end
            task.wait(Config.TinaBuyDelay or 0.25)
        end
    end

    if selectedCount == 0 then
        AppendLog("[TINA] Peringatan: Belum ada item yang dicentang!", Color3.fromRGB(240, 200, 100))
    else
        AppendLog(string.format("[TINA] Selesai mengirim pembelian %d item ke Anubis Coin Shop!", selectedCount), Color3.fromRGB(100, 255, 120))
    end

    if UpdateTinaCoinsDisplay then
        pcall(UpdateTinaCoinsDisplay)
    end
end

-- Teleport ke NPC Trader Tina
local function TeleportToTraderTina()
    local tinaModel = nil
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (string.find(obj.Name:lower(), "tina") or string.find(obj.Name:lower(), "trader")) then
                tinaModel = obj
                break
            end
        end
    end)
    if tinaModel then
        local targetPos = tinaModel:GetPivot().Position
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 4), targetPos)
            AppendLog("[TELEPORT] Berhasil teleport ke NPC Trader Tina!", Color3.fromRGB(100, 255, 150))
            return
        end
    end
    AppendLog("[INFO] Model NPC Trader Tina tidak ditemukan di workspace (Remote pembelian tetap berjalan normal)!", Color3.fromRGB(240, 200, 100))
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

-- Loop 3: Auto Buy Trader Tina (Anubis Coin Shop)
task.spawn(function()
    while true do
        task.wait(Config.TinaBuyInterval or 1.5)
        if Config.TinaAutoBuy then
            local anyAttempted = false
            for _, item in ipairs(TinaShopItems) do
                if not Config.TinaAutoBuy then break end
                if Config.TinaSelectedItems[item.Name] then
                    local stock = GetItemStock(item.Name)
                    if stock > 0 or stock == -1 then
                        local ok = BuyTinaItem(item.Name)
                        if ok then
                            anyAttempted = true
                            AppendLog(string.format("[AUTO BUY TINA] Membeli %s (🪙 %s Coins)", item.Name, CommaNumber(item.Price)), Color3.fromRGB(255, 215, 0))
                        end
                        task.wait(Config.TinaBuyDelay or 0.25)
                    end
                end
            end
            if anyAttempted and UpdateTinaCoinsDisplay then
                pcall(UpdateTinaCoinsDisplay)
            end
        end
    end
end)

-- ========================================================================================
-- 8. PEMBUATAN USER INTERFACE (HiiHuu MODERN DARK THEME)
-- ========================================================================================
local safeParent = GetSafeGuiParent()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HiiHuu_ArchieCollector_Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = safeParent

if getgenv then
    getgenv().HiiHuu_ArchieCollector_Gui = ScreenGui
end

-- Container Utama
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 520)
MainFrame.Position = UDim2.new(0.5, -190, 0.45, -260)
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

-- ========================================================================================
-- FLOATING LOGO ASSET LOADER (CLAUDE ICON / CUSTOM LINK)
-- ========================================================================================
local FLOATING_LOGO_URL = "" -- URL gambar langsung opsional
local FLOATING_LOGO_LOCAL_PATH = "HiiHuu/claude_logo.png"
local FLOATING_LOGO_FALLBACK_B64 = "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rV97rGEJGRz0rwban5MC0GoNBoeGpJH02PWxvmIlqW1W5Aavuhn0glIYhtZA4pXYeRKvuPQMWN/ad6iSHRav6ViGzpjAlh993cf28Wi2iQZN91hks3qt74WKsUYkMEKYTQN5hcl67I3IDkHuV6O3+6Sw9aLPDE62TlG/Vlo/5wSgVRC2stXMBELbP3rDeai5VD2Xi3CJKucquiw0ppgPLNZMc89nyR6n023fvrnPV5urWX58ljGVnEaGcWbCqFGLqCeOyPkacEBEXhB4HDHbFH1k48JLd7QyWfv6LL29OhcYPycFYKZr2No7LMdDxU/19eVyS5OeSKPlVuxq9bpS0ZVeWQKyCNGFqHYqlBApAHmBvKqGkhoGc7yl0amqq0clEaEG1BXqAhVFxkV1VIXDghwA3Wet2YPzO71lb06TgxtuveuHTvPQ2/osg/Bam/qzSgB+aD6iv1+2Zi3R13GdPxENUpDnfv0dOVfI5WTM5xMoaT4IfewDG2Kdb6SiIyCHNepcjEuMunygUaRJNcrWsvz12uuigRN5z8yCtXxOZQ4y/WwTgOMyd0s/snGoT7pbx6W3pufq9Z0BbVMQ+vuFoSFpHdE+NNSj23t7dcurkLefF4CTtRwt3NuypV+2cOKr77dsGdAZiFGZp3map3map3map3map3map3map3map3map3map3map3map3map3map3map3map3map3map3ma0/S/Ae7AI3Kn/1KJAAAAAElFTkSuQmCC"

local function DecodeBase64(data)
    if crypt and crypt.base64decode then
        local ok, res = pcall(function() return crypt.base64decode(data) end)
        if ok and res then return res end
    end
    if syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.decode then
        local ok, res = pcall(function() return syn.crypt.base64.decode(data) end)
        if ok and res then return res end
    end
    if base64_decode then
        local ok, res = pcall(function() return base64_decode(data) end)
        if ok and res then return res end
    end
    -- Fallback Lua Native Base64 Decoder
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    data = string.gsub(data, "[^"..b.."=]", "")
    local ok, res = pcall(function()
        return (data:gsub(".", function(x)
            if x == "=" then return "" end
            local r, f = "", (b:find(x) - 1)
            for i = 6, 1, -1 do
                r = r .. (f % 2^i - f % 2^(i - 1) > 0 and "1" or "0")
            end
            return r
        end):gsub("%d%d%d?%d?%d?%d?", function(x)
            if #x ~= 8 then return "" end
            local c = 0
            for i = 1, 8 do
                c = c + (x:sub(i, i) == "1" and 2^(8 - i) or 0)
            end
            return string.char(c)
        end))
    end)
    return (ok and res) or ""
end

local function ResolveFloatingLogoAsset()
    local customAssetFn = getcustomasset or getsynasset

    -- 1. Prioritas: Cek apakah file lokal sudah ada di workspace executor
    if customAssetFn then
        if isfile and isfile(FLOATING_LOGO_LOCAL_PATH) then
            local ok, asset = pcall(function() return customAssetFn(FLOATING_LOGO_LOCAL_PATH) end)
            if ok and asset then return asset end
        elseif isfile and isfile("claude_logo.png") then
            local ok, asset = pcall(function() return customAssetFn("claude_logo.png") end)
            if ok and asset then return asset end
        end
    end

    -- 2. Jika ada URL online langsung yang ditentukan
    if FLOATING_LOGO_URL and FLOATING_LOGO_URL ~= "" then
        local req = (syn and syn.request) or http_request or request
        if req and writefile and customAssetFn then
            local ok, resp = pcall(function()
                return req({ Url = FLOATING_LOGO_URL, Method = "GET" })
            end)
            if ok and resp and resp.Body and resp.StatusCode == 200 then
                if makefolder and not isfolder("HiiHuu") then pcall(function() makefolder("HiiHuu") end) end
                writefile(FLOATING_LOGO_LOCAL_PATH, resp.Body)
                local assetOk, asset = pcall(function() return customAssetFn(FLOATING_LOGO_LOCAL_PATH) end)
                if assetOk and asset then return asset end
            end
        end
    end

    -- 3. Ekstraksi otomatis dari Embedded Base64 jika file belum tersedia di device
    if writefile and customAssetFn and FLOATING_LOGO_FALLBACK_B64 ~= "" then
        pcall(function()
            local decodedBytes = DecodeBase64(FLOATING_LOGO_FALLBACK_B64)
            if decodedBytes and #decodedBytes > 100 then
                if makefolder and not isfolder("HiiHuu") then pcall(function() makefolder("HiiHuu") end) end
                writefile(FLOATING_LOGO_LOCAL_PATH, decodedBytes)
            end
        end)
        if isfile and isfile(FLOATING_LOGO_LOCAL_PATH) then
            local ok, asset = pcall(function() return customAssetFn(FLOATING_LOGO_LOCAL_PATH) end)
            if ok and asset then return asset end
        end
    end

    return ""
end

local FloatingLogoAsset = ResolveFloatingLogoAsset()

-- Floating Minimize Icon Button (Squircle Claude 3D Logo)
local MinimizePill = Instance.new("ImageButton")
MinimizePill.Name = "MinimizePill"
MinimizePill.Size = UDim2.new(0, 66, 0, 66)
MinimizePill.Position = UDim2.new(0, 20, 0, 80)
MinimizePill.BackgroundTransparency = 1
MinimizePill.Visible = false
MinimizePill.Active = true
MinimizePill.AutoButtonColor = false
MinimizePill.Parent = ScreenGui

if FloatingLogoAsset and FloatingLogoAsset ~= "" then
    MinimizePill.Image = FloatingLogoAsset
    MinimizePill.ScaleType = Enum.ScaleType.Fit
else
    -- Fallback visual jika getcustomasset tidak aktif
    MinimizePill.BackgroundTransparency = 0
    MinimizePill.BackgroundColor3 = Color3.fromRGB(218, 98, 62)
    local FallbackCorner = Instance.new("UICorner", MinimizePill)
    FallbackCorner.CornerRadius = UDim.new(0, 14)

    local FallbackStroke = Instance.new("UIStroke", MinimizePill)
    FallbackStroke.Color = Color3.fromRGB(240, 140, 100)
    FallbackStroke.Thickness = 1.5

    local FallbackIcon = Instance.new("TextLabel")
    FallbackIcon.Size = UDim2.new(1, 0, 1, 0)
    FallbackIcon.BackgroundTransparency = 1
    FallbackIcon.Text = "✻"
    FallbackIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    FallbackIcon.Font = Enum.Font.GothamBold
    FallbackIcon.TextSize = 28
    FallbackIcon.Parent = MinimizePill
end

-- Hover Smooth Tweening
MinimizePill.MouseEnter:Connect(function()
    pcall(function()
        TweenService:Create(MinimizePill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 58, 0, 58),
            Position = MinimizePill.Position + UDim2.new(0, -3, 0, -3)
        }):Play()
    end)
end)

MinimizePill.MouseLeave:Connect(function()
    pcall(function()
        TweenService:Create(MinimizePill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 52, 0, 52),
            Position = MinimizePill.Position + UDim2.new(0, 3, 0, 3)
        }):Play()
    end)
end)

-- Dragging Engine untuk MainFrame & MinimizePill
local function MakeDraggable(guiObject)
    local dragging = false
    local dragInput, dragStart, startPos
    local hasMoved = false

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            hasMoved = false
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
            if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
                hasMoved = true
            end
            guiObject.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    return function()
        return hasMoved
    end
end

local _isMainDragged = MakeDraggable(MainFrame)
local isPillDragged = MakeDraggable(MinimizePill)

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
HeaderTitle.TextSize = 13
HeaderTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Text = "AUTO ANUBIS EVENT"
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
    if isPillDragged and isPillDragged() then return end
    MinimizePill.Visible = false
    MainFrame.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    if getgenv then getgenv().HiiHuu_ArchieCollector_Gui = nil end
end)

-- Tab Navigation Bar (ARCHIE vs TRADER TINA)
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -16, 0, 32)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local TabArchieBtn = Instance.new("TextButton")
TabArchieBtn.Name = "TabArchieBtn"
TabArchieBtn.Size = UDim2.new(0.5, -3, 1, -4)
TabArchieBtn.Position = UDim2.new(0, 2, 0, 2)
TabArchieBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
TabArchieBtn.Font = Enum.Font.GothamBold
TabArchieBtn.TextSize = 11
TabArchieBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabArchieBtn.Text = "ARCHIE COLLECTOR"
TabArchieBtn.Parent = TabBar

local TabArchieCorner = Instance.new("UICorner")
TabArchieCorner.CornerRadius = UDim.new(0, 6)
TabArchieCorner.Parent = TabArchieBtn

local TabTinaBtn = Instance.new("TextButton")
TabTinaBtn.Name = "TabTinaBtn"
TabTinaBtn.Size = UDim2.new(0.5, -3, 1, -4)
TabTinaBtn.Position = UDim2.new(0.5, 1, 0, 2)
TabTinaBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
TabTinaBtn.Font = Enum.Font.GothamBold
TabTinaBtn.TextSize = 11
TabTinaBtn.TextColor3 = Color3.fromRGB(160, 170, 190)
TabTinaBtn.Text = "TRADER TINA"
TabTinaBtn.Parent = TabBar

local TabTinaCorner = Instance.new("UICorner")
TabTinaCorner.CornerRadius = UDim.new(0, 6)
TabTinaCorner.Parent = TabTinaBtn

-- Forward declarations untuk Tab Content ScrollingFrames
local Content
local TinaContent

local function SwitchTab(tabName)
    State.ActiveTab = tabName
    if tabName == "Archie" then
        TabArchieBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        TabArchieBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabTinaBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        TabTinaBtn.TextColor3 = Color3.fromRGB(160, 170, 190)
        if Content then Content.Visible = true end
        if TinaContent then TinaContent.Visible = false end
    else
        TabTinaBtn.BackgroundColor3 = Color3.fromRGB(212, 160, 23)
        TabTinaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabArchieBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        TabArchieBtn.TextColor3 = Color3.fromRGB(160, 170, 190)
        if Content then Content.Visible = false end
        if TinaContent then TinaContent.Visible = true end
        if UpdateTinaCoinsDisplay then UpdateTinaCoinsDisplay() end
        if UpdateTinaCheckboxes then UpdateTinaCheckboxes() end
    end
end

TabArchieBtn.MouseButton1Click:Connect(function()
    SwitchTab("Archie")
end)

TabTinaBtn.MouseButton1Click:Connect(function()
    SwitchTab("Tina")
end)

-- Content ScrollFrame (TAB 1: ARCHIE COLLECTOR)
Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -90)
Content.Position = UDim2.new(0, 8, 0, 84)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 85)
Content.CanvasSize = UDim2.new(0, 0, 0, 530)
Content.Visible = true
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

-- Log Activity dimatikan per permintaan user
AppendLog = function(msg, color)
    -- Disabled
end

-- ============================================================================
-- TAB 2: USER INTERFACE TRADER TINA (ANUBIS COIN SHOP)
-- ============================================================================
TinaContent = Instance.new("ScrollingFrame")
TinaContent.Name = "TinaContent"
TinaContent.Size = UDim2.new(1, -16, 1, -90)
TinaContent.Position = UDim2.new(0, 8, 0, 84)
TinaContent.BackgroundTransparency = 1
TinaContent.BorderSizePixel = 0
TinaContent.ScrollBarThickness = 4
TinaContent.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 85)
TinaContent.CanvasSize = UDim2.new(0, 0, 0, 540)
TinaContent.Visible = false
TinaContent.Parent = MainFrame

local TinaLayout = Instance.new("UIListLayout")
TinaLayout.SortOrder = Enum.SortOrder.LayoutOrder
TinaLayout.Padding = UDim.new(0, 8)
TinaLayout.Parent = TinaContent

local function CreateTinaSection(layoutOrder, height)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, height)
    section.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    section.BorderSizePixel = 0
    section.LayoutOrder = layoutOrder
    section.Parent = TinaContent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = section

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 42, 54)
    stroke.Thickness = 1
    stroke.Parent = section

    return section
end

-- ----------------------------------------------------------------------------
-- TINA SECTION 1: TOMBOL AKSI CEPAT (PILIH SEMUA, HAPUS SEMUA, BELI 1x)
-- ----------------------------------------------------------------------------
local TinaSection1 = CreateTinaSection(1, 44)

local function CreateTinaBtn(xPos, width, text, bgCol, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 0, 28)
    btn.Position = UDim2.new(0, xPos, 0, 8)
    btn.BackgroundColor3 = bgCol
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = TinaSection1

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

-- 3 Tombol: Pilih Semua, Hapus Semua, Beli 1x Sekarang
CreateTinaBtn(10, 105, "PILIH SEMUA", Color3.fromRGB(41, 128, 185), function()
    for _, item in ipairs(TinaShopItems) do
        Config.TinaSelectedItems[item.Name] = true
    end
    if UpdateTinaCheckboxes then UpdateTinaCheckboxes() end
end)

CreateTinaBtn(122, 105, "HAPUS SEMUA", Color3.fromRGB(140, 45, 50), function()
    for _, item in ipairs(TinaShopItems) do
        Config.TinaSelectedItems[item.Name] = false
    end
    if UpdateTinaCheckboxes then UpdateTinaCheckboxes() end
end)

CreateTinaBtn(234, 120, "BELI 1x SEKARANG", Color3.fromRGB(212, 160, 23), function()
    BuyAllSelectedTinaItems()
end)

-- ----------------------------------------------------------------------------
-- TINA SECTION 2: MULTI-SELECT CHECKBOX SELURUH 11 ITEM RESMI SHOP
-- ----------------------------------------------------------------------------
local TinaSection2 = CreateTinaSection(2, 376)

local ItemsHeader = Instance.new("TextLabel")
ItemsHeader.Size = UDim2.new(1, -20, 0, 20)
ItemsHeader.Position = UDim2.new(0, 10, 0, 6)
ItemsHeader.BackgroundTransparency = 1
ItemsHeader.Font = Enum.Font.GothamBold
ItemsHeader.TextSize = 11
ItemsHeader.TextColor3 = Color3.fromRGB(180, 190, 210)
ItemsHeader.TextXAlignment = Enum.TextXAlignment.Left
ItemsHeader.Text = "MULTI-SELECT ITEM ANUBIS SHOP (11 ITEM):"
ItemsHeader.Parent = TinaSection2

local TinaCheckboxes = {}

for idx, item in ipairs(TinaShopItems) do
    local yPos = 28 + (idx - 1) * 31
    local row = Instance.new("TextButton")
    row.Name = "ItemRow_" .. item.Name
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = (idx % 2 == 0) and Color3.fromRGB(19, 22, 28) or Color3.fromRGB(15, 17, 22)
    row.BorderSizePixel = 0
    row.Text = ""
    row.Parent = TinaSection2

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 5)
    rowCorner.Parent = row

    -- Checkbox Button
    local checkSquare = Instance.new("TextButton")
    checkSquare.Size = UDim2.new(0, 20, 0, 20)
    checkSquare.Position = UDim2.new(0, 5, 0, 4)
    local isChecked = Config.TinaSelectedItems[item.Name] == true
    checkSquare.BackgroundColor3 = isChecked and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(36, 42, 54)
    checkSquare.Font = Enum.Font.GothamBold
    checkSquare.TextSize = 13
    checkSquare.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkSquare.Text = isChecked and "✓" or ""
    checkSquare.Parent = row

    local checkCorner = Instance.new("UICorner")
    checkCorner.CornerRadius = UDim.new(0, 4)
    checkCorner.Parent = checkSquare

    TinaCheckboxes[item.Name] = checkSquare

    -- Item Name Label
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.48, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 32, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamSemibold
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = Color3.fromRGB(230, 235, 245)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Text = item.Name
    nameLbl.Parent = row

    -- Item Price & Type badge (bebas dari broken emoji)
    local priceLbl = Instance.new("TextLabel")
    priceLbl.Size = UDim2.new(0.48, -5, 1, 0)
    priceLbl.Position = UDim2.new(0.52, 0, 0, 0)
    priceLbl.BackgroundTransparency = 1
    priceLbl.Font = Enum.Font.GothamBold
    priceLbl.TextSize = 11
    local rarityCol = RarityColorMap[item.Rarity] or Color3.fromRGB(241, 196, 15)
    priceLbl.TextColor3 = rarityCol
    priceLbl.TextXAlignment = Enum.TextXAlignment.Right
    priceLbl.Text = string.format("[%s] %s Coins", item.Type, CommaNumber(item.Price))
    priceLbl.Parent = row

    -- Toggle Callback
    local function ToggleThisItem()
        local nextVal = not (Config.TinaSelectedItems[item.Name] == true)
        Config.TinaSelectedItems[item.Name] = nextVal
        checkSquare.BackgroundColor3 = nextVal and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(36, 42, 54)
        checkSquare.Text = nextVal and "✓" or ""
    end

    row.MouseButton1Click:Connect(ToggleThisItem)
    checkSquare.MouseButton1Click:Connect(ToggleThisItem)
end

UpdateTinaCheckboxes = function()
    pcall(function()
        for itemName, checkBtn in pairs(TinaCheckboxes) do
            local isSel = Config.TinaSelectedItems[itemName] == true
            checkBtn.BackgroundColor3 = isSel and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(36, 42, 54)
            checkBtn.Text = isSel and "✓" or ""
        end
    end)
end

-- ----------------------------------------------------------------------------
-- TINA SECTION 3: NAVIGASI & REFRESH SHOP
-- ----------------------------------------------------------------------------
local TinaSection3 = CreateTinaSection(3, 46)

local function CreateNavBtn(xPos, width, text, bgCol, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 0, 30)
    btn.Position = UDim2.new(0, xPos, 0, 8)
    btn.BackgroundColor3 = bgCol
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = TinaSection3

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

CreateNavBtn(10, 165, "TELEPORT KE TRADER TINA", Color3.fromRGB(142, 68, 173), function()
    TeleportToTraderTina()
end)

local RefreshCoinsBtn
RefreshCoinsBtn = CreateNavBtn(185, 165, "REFRESH KOIN & STOCK", Color3.fromRGB(52, 73, 94), function()
    if UpdateTinaCoinsDisplay then UpdateTinaCoinsDisplay() end
    if UpdateTinaCheckboxes then UpdateTinaCheckboxes() end
end)

UpdateTinaCoinsDisplay = function()
    pcall(function()
        if RefreshCoinsBtn and RefreshCoinsBtn.Parent then
            local coins = GetAnubisCoins()
            RefreshCoinsBtn.Text = string.format("REFRESH (%s COINS)", CommaNumber(coins))
        end
    end)
end

-- ----------------------------------------------------------------------------
-- TINA SECTION 4: TOGGLE AUTO BUY PINDAH KE BAWAH (TEMPAT LOG ACTIVITY LAMA)
-- ----------------------------------------------------------------------------
local TinaSection4 = CreateTinaSection(4, 46)

local AutoBuyRow = Instance.new("Frame")
AutoBuyRow.Size = UDim2.new(1, -20, 0, 30)
AutoBuyRow.Position = UDim2.new(0, 10, 0, 8)
AutoBuyRow.BackgroundTransparency = 1
AutoBuyRow.Parent = TinaSection4

local AutoBuyLbl = Instance.new("TextLabel")
AutoBuyLbl.Size = UDim2.new(1, -66, 1, 0)
AutoBuyLbl.BackgroundTransparency = 1
AutoBuyLbl.Font = Enum.Font.GothamBold
AutoBuyLbl.TextSize = 11
AutoBuyLbl.TextColor3 = Color3.fromRGB(220, 225, 235)
AutoBuyLbl.TextXAlignment = Enum.TextXAlignment.Left
AutoBuyLbl.Text = "Auto Buy Selected Stock (Loop)"
AutoBuyLbl.Parent = AutoBuyRow

local AutoBuyBtn = Instance.new("TextButton")
AutoBuyBtn.Size = UDim2.new(0, 56, 0, 26)
AutoBuyBtn.Position = UDim2.new(1, -56, 0, 2)
AutoBuyBtn.BackgroundColor3 = Config.TinaAutoBuy and Color3.fromRGB(212, 160, 23) or Color3.fromRGB(48, 54, 68)
AutoBuyBtn.Font = Enum.Font.GothamBold
AutoBuyBtn.TextSize = 11
AutoBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBuyBtn.Text = Config.TinaAutoBuy and "ON" or "OFF"
AutoBuyBtn.Parent = AutoBuyRow

local AutoBuyCorner = Instance.new("UICorner")
AutoBuyCorner.CornerRadius = UDim.new(0, 12)
AutoBuyCorner.Parent = AutoBuyBtn

AutoBuyBtn.MouseButton1Click:Connect(function()
    Config.TinaAutoBuy = not Config.TinaAutoBuy
    AutoBuyBtn.Text = Config.TinaAutoBuy and "ON" or "OFF"
    AutoBuyBtn.BackgroundColor3 = Config.TinaAutoBuy and Color3.fromRGB(212, 160, 23) or Color3.fromRGB(48, 54, 68)
end)

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
    if UpdateTinaCoinsDisplay then
        pcall(UpdateTinaCoinsDisplay)
    end
    if UpdateTinaCheckboxes then
        pcall(UpdateTinaCheckboxes)
    end
end)

