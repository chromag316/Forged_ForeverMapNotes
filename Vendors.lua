local addonName, ns = ...

-- Item class of recipes, patterns, plans, formulas, etc.
local RECIPE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9

-- A vendor note closer than this (normalized map units) is treated as the same vendor.
local DUPLICATE_RADIUS = 0.005

local merchantOpen = false

local function GetItemClassID(link)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInfo then
        return select(6, getInfo(link))
    end
end

-- Returns the recipe names the open merchant sells. Links can be nil until
-- the client has cached the item; MERCHANT_UPDATE triggers a rescan then.
local function ScanRecipes()
    local recipes = {}
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        if link and GetItemClassID(link) == RECIPE_CLASS then
            recipes[#recipes + 1] = link:match("%[(.-)%]") or link
        end
    end
    return recipes
end

-- Vendor notes are matched on the stored NPC name, so renaming a note
-- doesn't create a duplicate on the next visit.
local function FindVendorNote(mapID, x, y, vendor)
    local notes = ns:GetNotes(mapID)
    if not notes then return end
    local r2 = DUPLICATE_RADIUS * DUPLICATE_RADIUS
    for noteID, note in pairs(notes) do
        if note.category == "recipe" and note.npc == vendor then
            local dx, dy = note.x - x, note.y - y
            if dx * dx + dy * dy <= r2 then
                return noteID, note
            end
        end
    end
end

-- Adds recipes not already in the note. Known recipes are kept, so
-- limited-stock items stay listed after they sell out.
local function MergeItems(note, recipes)
    note.items = note.items or {}
    local known = {}
    for _, name in ipairs(note.items) do
        known[name] = true
    end
    local added = 0
    for _, name in ipairs(recipes) do
        if not known[name] then
            known[name] = true
            note.items[#note.items + 1] = name
            added = added + 1
        end
    end
    if added > 0 then
        table.sort(note.items)
    end
    return added
end

local function LogVendor()
    local recipes = ScanRecipes()
    if #recipes == 0 then return end

    local mapID, x, y = ns:GetPlayerPosition()
    if not mapID then return end

    local vendor = UnitName("npc") or "Recipe vendor"
    local noteID, note = FindVendorNote(mapID, x, y, vendor)
    if not note then
        noteID = ns:AddNote(mapID, x, y, vendor, "recipe")
        note = ns:GetNote(mapID, noteID)
        if not note then return end
        note.npc = vendor
        ns:Debug(("logged vendor %s at %.1f, %.1f"):format(vendor, x * 100, y * 100))
    end

    local added = MergeItems(note, recipes)
    if added > 0 then
        ns:Debug(("%s: %d new recipe(s)"):format(vendor, added))
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:RegisterEvent("MERCHANT_CLOSED")

-- Same protection as the gathering log: a bad value must not break the addon.
frame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        merchantOpen = true
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        return
    end
    if not (merchantOpen and ns.db and ns.db.autoLog) then return end
    local ok, err = pcall(LogVendor)
    if not ok then
        ns:Debug("vendor error: " .. tostring(err))
    end
end)
