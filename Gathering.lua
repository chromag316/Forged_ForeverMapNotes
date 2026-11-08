local addonName, ns = ...

-- Lowercase spell name -> category. English client names; if a gather isn't
-- logged, turn on /fmn debug, gather once, and add the printed spell name here.
local SPELL_CATEGORIES = {
    ["mining"] = "mining",
    ["herb gathering"] = "herb",
    ["herbalism"] = "herb",
    ["opening"] = "treasure",
    ["opening - no text"] = "treasure",
}

-- "Opening" is also cast on crates, barrels, quest objects, lockboxes, etc.
-- Only targets whose lowercase name contains one of these count as treasure.
local TREASURE_KEYWORDS = {
    "chest",
    "coffer",
    "strongbox",
    "footlocker",
}

local function IsTreasure(target)
    if not target or target == "" then return false end
    local name = target:lower()
    for _, keyword in ipairs(TREASURE_KEYWORDS) do
        if name:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

-- Two logs of the same node closer than this (normalized map units) are merged.
local DUPLICATE_RADIUS = 0.005

local pending = {} -- [castGUID] = target name from UNIT_SPELLCAST_SENT

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
end

local function LogNode(category, title)
    local mapID, x, y = ns:GetPlayerPosition()
    if not mapID then return end

    if ns:HasNoteNear(mapID, x, y, category, title, DUPLICATE_RADIUS) then
        ns:Debug("already logged nearby: " .. title)
        return
    end
    ns:AddNote(mapID, x, y, title, category)
    ns:Debug(("logged %s at %.1f, %.1f"):format(title, x * 100, y * 100))
end

local function LogGather(target, spellID)
    local spellName = GetSpellName(spellID)
    ns:Debug(("cast %s (%s) on %s"):format(tostring(spellName), tostring(spellID), tostring(target)))
    if not spellName then return end

    local category = SPELL_CATEGORIES[spellName:lower()]
    if not category then return end
    if category == "treasure" and not IsTreasure(target) then
        ns:Debug("not a treasure chest: " .. tostring(target))
        return
    end

    LogNode(category, (target and target ~= "") and target or ns.CATEGORY_BY_KEY[category].label)
end

local frame = CreateFrame("Frame")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")

local function OnEvent(event, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local _, target, castGUID = ...
        if castGUID then
            pending[castGUID] = target or ""
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        local target = castGUID and pending[castGUID]
        if target == nil then return end
        pending[castGUID] = nil
        LogGather(target, spellID)
    else
        local _, castGUID = ...
        if castGUID then
            pending[castGUID] = nil
        end
    end
end

-- The client may hand addons protected ("secret") values that error when
-- compared, so never let a bad event break the addon.
frame:SetScript("OnEvent", function(self, event, ...)
    if not (ns.db and ns.db.autoLog) then return end
    local ok, err = pcall(OnEvent, event, ...)
    if not ok then
        ns:Debug("gathering error: " .. tostring(err))
    end
end)

-- Without the skill (or with too little of it) right-clicking a node casts
-- nothing; the client only shows an error such as "Requires Mining" or
-- "Requires Herbalism 75". The node is still under the cursor then, so its
-- name is read from the world-object tooltip. English client text, like the
-- spell names above.
local REQUIRES_CATEGORIES = {
    ["mining"] = "mining",
    ["herbalism"] = "herb",
}

local function GetErrorCategory(message)
    local text = message:lower()
    if not text:find("requires", 1, true) then return end
    for skill, category in pairs(REQUIRES_CATEGORIES) do
        if text:find(skill, 1, true) then
            return category
        end
    end
end

-- Name of the world object under the cursor, from GameTooltip line 1. Unit
-- and item tooltips are ignored.
local function GetHoveredObjectName()
    if not (GameTooltip and GameTooltip:IsShown()) then return end
    if GameTooltip:GetUnit() or GameTooltip:GetItem() then return end
    local line = _G.GameTooltipTextLeft1
    local name = line and line:GetText()
    if type(name) == "string" and name ~= "" then
        return name
    end
end

local function OnErrorMessage(...)
    -- Newer clients pass (errorType, message), older ones (message).
    local message
    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        if type(arg) == "string" then
            message = arg
            break
        end
    end
    if not message then return end

    local category = GetErrorCategory(message)
    if not category then return end

    local name = GetHoveredObjectName()
    ns:Debug(("%s on %s"):format(message, tostring(name)))
    if not name then return end
    LogNode(category, name)
end

local errorFrame = CreateFrame("Frame")
errorFrame:RegisterEvent("UI_ERROR_MESSAGE")
errorFrame:SetScript("OnEvent", function(self, event, ...)
    if not (ns.db and ns.db.autoLog) then return end
    local ok, err = pcall(OnErrorMessage, ...)
    if not ok then
        ns:Debug("gathering error: " .. tostring(err))
    end
end)
