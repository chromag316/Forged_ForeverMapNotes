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

-- Two logs of the same node closer than this (normalized map units) are merged.
local DUPLICATE_RADIUS = 0.005

local pending = {} -- [castGUID] = target name from UNIT_SPELLCAST_SENT

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
end

local function LogGather(target, spellID)
    local spellName = GetSpellName(spellID)
    ns:Debug(("cast %s (%s) on %s"):format(tostring(spellName), tostring(spellID), tostring(target)))
    if not spellName then return end

    local category = SPELL_CATEGORIES[spellName:lower()]
    if not category then return end

    local mapID, x, y = ns:GetPlayerPosition()
    if not mapID then return end

    local title = (target and target ~= "") and target or ns.CATEGORY_BY_KEY[category].label
    if ns:HasNoteNear(mapID, x, y, category, title, DUPLICATE_RADIUS) then
        ns:Debug("already logged nearby: " .. title)
        return
    end
    ns:AddNote(mapID, x, y, title, category)
    ns:Debug(("logged %s at %.1f, %.1f"):format(title, x * 100, y * 100))
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
