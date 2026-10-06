local addonName, ns = ...

ns.CATEGORIES = {
    { key = "note",     label = "Notes",     icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "mining",   label = "Mining",    icon = "Interface\\Icons\\Trade_Mining" },
    { key = "herb",     label = "Herbalism", icon = "Interface\\Icons\\Trade_Herbalism" },
    { key = "treasure", label = "Treasure",  icon = "Interface\\Icons\\INV_Box_01" },
}

ns.CATEGORY_BY_KEY = {}
for _, category in ipairs(ns.CATEGORIES) do
    ns.CATEGORY_BY_KEY[category.key] = category
end

local DEFAULTS = {
    version = 1,
    nextID = 1,
    notes = {},   -- [mapID] = { [noteID] = { x, y, title, category, created } }
    hidden = {},  -- [categoryKey] = true when hidden on the map
    autoLog = true,
    debug = false,
}

function ns:Print(msg)
    print("|cff66ccffForgedForeverMapNotes|r: " .. tostring(msg))
end

function ns:Debug(msg)
    if ns.db and ns.db.debug then
        ns:Print("|cff999999" .. tostring(msg) .. "|r")
    end
end

local function InitDB()
    ForgedForeverMapNotesDB = ForgedForeverMapNotesDB or {}
    for key, value in pairs(DEFAULTS) do
        if ForgedForeverMapNotesDB[key] == nil then
            ForgedForeverMapNotesDB[key] = type(value) == "table" and {} or value
        end
    end
    ns.db = ForgedForeverMapNotesDB
end

-- Notes ---------------------------------------------------------------------

function ns:GetNotes(mapID)
    return mapID and ns.db.notes[mapID] or nil
end

function ns:GetNote(mapID, noteID)
    local notes = ns:GetNotes(mapID)
    return notes and notes[noteID] or nil
end

function ns:AddNote(mapID, x, y, title, category)
    if not (mapID and x and y) then return end
    local noteID = ns.db.nextID
    ns.db.nextID = noteID + 1
    ns.db.notes[mapID] = ns.db.notes[mapID] or {}
    ns.db.notes[mapID][noteID] = {
        x = x,
        y = y,
        title = title or "",
        category = category or "note",
        created = time(),
    }
    ns:RefreshPins()
    return noteID
end

function ns:UpdateNote(mapID, noteID, title)
    local note = ns:GetNote(mapID, noteID)
    if not note then return end
    note.title = title
    ns:RefreshPins()
end

function ns:DeleteNote(mapID, noteID)
    local notes = ns:GetNotes(mapID)
    if not (notes and notes[noteID]) then return end
    notes[noteID] = nil
    if next(notes) == nil then
        ns.db.notes[mapID] = nil
    end
    ns:RefreshPins()
end

-- Returns true if a note of the same category and title already sits within
-- radius (in normalized map units) of x, y.
function ns:HasNoteNear(mapID, x, y, category, title, radius)
    local notes = ns:GetNotes(mapID)
    if not notes then return false end
    local r2 = radius * radius
    for _, note in pairs(notes) do
        if note.category == category and note.title == title then
            local dx, dy = note.x - x, note.y - y
            if dx * dx + dy * dy <= r2 then
                return true
            end
        end
    end
    return false
end

function ns:GetPlayerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end -- e.g. inside instances
    local x, y = pos:GetXY()
    return mapID, x, y
end

-- Filters -------------------------------------------------------------------

function ns:IsCategoryShown(key)
    return not ns.db.hidden[key]
end

function ns:SetCategoryShown(key, shown)
    ns.db.hidden[key] = (not shown) or nil
    ns:RefreshPins()
end

-- Slash commands ------------------------------------------------------------

local function PrintHelp()
    ns:Print("Ctrl+Right-click the world map to add a note. Right-click a note to edit or delete it.")
    print("  /fmn add <text>  - add a note at your position")
    print("  /fmn show|hide <notes|mining|herb|treasure>")
    print("  /fmn auto on|off - toggle automatic gathering log")
    print("  /fmn debug       - toggle debug output (shows spell names/IDs)")
    print("  /fmn count       - number of stored notes")
end

SLASH_FORGEDFOREVERMAPNOTES1 = "/fmn"
SLASH_FORGEDFOREVERMAPNOTES2 = "/forgedforevermapnotes"
SlashCmdList.FORGEDFOREVERMAPNOTES = function(input)
    local cmd, rest = strsplit(" ", strtrim(input or ""), 2)
    cmd = (cmd or ""):lower()
    rest = rest and strtrim(rest) or ""

    if cmd == "add" then
        local mapID, x, y = ns:GetPlayerPosition()
        if not mapID then
            ns:Print("Can't determine your map position here.")
            return
        end
        ns:AddNote(mapID, x, y, rest ~= "" and rest or "Note", "note")
        ns:Print(("Note added at %.1f, %.1f."):format(x * 100, y * 100))
    elseif cmd == "show" or cmd == "hide" then
        local key = rest:lower()
        if key == "notes" then key = "note" end
        if not ns.CATEGORY_BY_KEY[key] then
            ns:Print("Unknown category. Use notes, mining, herb or treasure.")
            return
        end
        ns:SetCategoryShown(key, cmd == "show")
        ns:Print(("%s %s."):format(ns.CATEGORY_BY_KEY[key].label, cmd == "show" and "shown" or "hidden"))
    elseif cmd == "auto" then
        ns.db.autoLog = rest:lower() ~= "off"
        ns:Print("Automatic gathering log " .. (ns.db.autoLog and "on." or "off."))
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("Debug " .. (ns.db.debug and "on." or "off."))
    elseif cmd == "count" then
        local total = 0
        for _, notes in pairs(ns.db.notes) do
            for _ in pairs(notes) do total = total + 1 end
        end
        ns:Print(total .. " notes stored.")
    else
        PrintHelp()
    end
end

-- Startup -------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        InitDB()
        if WorldMapFrame then
            ns:SetupMap()
        end
    elseif name == "Blizzard_WorldMap" and ns.db then
        ns:SetupMap()
    end
    if ns.db and ns.mapReady then
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
