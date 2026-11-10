local addonName, ns = ...

ns.CATEGORIES = {
    { key = "note",     label = "Notes",     icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "mining",   label = "Mining",    icon = "Interface\\Icons\\Trade_Mining" },
    { key = "herb",     label = "Herbalism", icon = "Interface\\Icons\\Trade_Herbalism" },
    { key = "treasure", label = "Treasure",  icon = "Interface\\Icons\\INV_Box_01" },
    { key = "recipe",   label = "Recipe Vendors", icon = "Interface\\Icons\\INV_Scroll_03" },
}

ns.CATEGORY_BY_KEY = {}
for _, category in ipairs(ns.CATEGORIES) do
    ns.CATEGORY_BY_KEY[category.key] = category
end

-- Account-wide data (ForgedForeverMapNotesDB).
local DEFAULTS = {
    version = 1,
    nextID = 1,
    notes = {},   -- [mapID] = { [noteID] = { x, y, title, category, created, npc?, items? } }
    hidden = {},  -- [categoryKey] = true when hidden on the map
    autoLog = true,
    debug = false,
    minimap = true, -- show notes on the minimap
    knownBatch = 0, -- last Data/KnownNodes.lua batch imported
}

-- Per-character data (ForgedForeverMapNotesCharDB).
local CHAR_DEFAULTS = {
    nextID = 1,
    notes = {},   -- same shape as DEFAULTS.notes
}

-- Categories stored per character; everything else is account-wide.
local CHAR_CATEGORIES = { recipe = true }

-- Per-character note IDs are strings ("c1", "c2", ...) so they never clash
-- with the numeric account-wide IDs and the owning store follows from the ID.
local CHAR_ID_PREFIX = "c"

function ns:Print(msg)
    print("|cff66ccffForgedForeverMapNotes|r: " .. tostring(msg))
end

function ns:Debug(msg)
    if ns.db and ns.db.debug then
        ns:Print("|cff999999" .. tostring(msg) .. "|r")
    end
end

local function ApplyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = type(value) == "table" and {} or value
        end
    end
    return db
end

local function StoreForCategory(category)
    return CHAR_CATEGORIES[category] and ns.charDB or ns.db
end

local function StoreForID(noteID)
    return type(noteID) == "string" and ns.charDB or ns.db
end

local function NewNoteID(store)
    local n = store.nextID
    store.nextID = n + 1
    return store == ns.charDB and (CHAR_ID_PREFIX .. n) or n
end

-- Moves notes between stores when their category's scope doesn't match
-- (e.g. recipe vendors logged account-wide before 1.0.1 go to the first
-- character that logs in). Runs every load; it's a no-op once settled.
local function MigrateNotes()
    for mapID, notes in pairs(ns.db.notes) do
        for noteID, note in pairs(notes) do
            if CHAR_CATEGORIES[note.category] then
                notes[noteID] = nil
                ns.charDB.notes[mapID] = ns.charDB.notes[mapID] or {}
                ns.charDB.notes[mapID][NewNoteID(ns.charDB)] = note
            end
        end
        if next(notes) == nil then
            ns.db.notes[mapID] = nil
        end
    end
end

local ImportKnownNodes -- defined below, after the note helpers it uses

local function InitDB()
    ForgedForeverMapNotesDB = ApplyDefaults(ForgedForeverMapNotesDB or {}, DEFAULTS)
    ForgedForeverMapNotesCharDB = ApplyDefaults(ForgedForeverMapNotesCharDB or {}, CHAR_DEFAULTS)
    ns.db = ForgedForeverMapNotesDB
    ns.charDB = ForgedForeverMapNotesCharDB
    MigrateNotes()
    ImportKnownNodes()
end

-- Notes ---------------------------------------------------------------------

-- Returns all notes on mapID from both stores as { [noteID] = note }, or nil.
-- The table is new; the notes in it are the stored ones.
function ns:GetNotes(mapID)
    if not mapID then return end
    local account, char = ns.db.notes[mapID], ns.charDB.notes[mapID]
    if not char then return account end
    if not account then return char end
    local merged = {}
    for noteID, note in pairs(account) do merged[noteID] = note end
    for noteID, note in pairs(char) do merged[noteID] = note end
    return merged
end

function ns:GetNote(mapID, noteID)
    local notes = mapID and noteID and StoreForID(noteID).notes[mapID]
    return notes and notes[noteID] or nil
end

local function InsertNote(mapID, x, y, title, category)
    category = category or "note"
    local store = StoreForCategory(category)
    local noteID = NewNoteID(store)
    local note = {
        x = x,
        y = y,
        title = title or "",
        category = category,
        created = time(),
    }
    store.notes[mapID] = store.notes[mapID] or {}
    store.notes[mapID][noteID] = note
    return noteID, note
end

function ns:AddNote(mapID, x, y, title, category)
    if not (mapID and x and y) then return end
    local noteID = InsertNote(mapID, x, y, title, category)
    ns:RefreshPins()
    return noteID
end

-- Known nodes ---------------------------------------------------------------

-- Same radius the gathering log uses to treat two logs as one node.
local KNOWN_DUPLICATE_RADIUS = 0.005

-- Copies shipped nodes (Data/KnownNodes.lua) into the account notes. Each
-- batch is imported once, so a node the player deletes stays deleted and a
-- new addon version only brings in the batches added since. Nodes already
-- noted nearby are skipped.
function ImportKnownNodes()
    local known = ns.KNOWN_NODES
    if not known then return end
    local done = ns.db.knownBatch
    local latest, added = done, 0
    for batch, maps in pairs(known) do
        if batch > done then
            for mapID, nodes in pairs(maps) do
                for _, node in ipairs(nodes) do
                    local x, y, category, title = node[1], node[2], node[3], node[4]
                    if not ns:HasNoteNear(mapID, x, y, category, title, KNOWN_DUPLICATE_RADIUS) then
                        local _, note = InsertNote(mapID, x, y, title, category)
                        note.known = true
                        added = added + 1
                    end
                end
            end
            if batch > latest then latest = batch end
        end
    end
    ns.db.knownBatch = latest
    if added > 0 then
        ns:Print(("Added %d known gathering node(s) to the map."):format(added))
    end
end

function ns:UpdateNote(mapID, noteID, title)
    local note = ns:GetNote(mapID, noteID)
    if not note then return end
    note.title = title
    ns:RefreshPins()
end

function ns:DeleteNote(mapID, noteID)
    local store = StoreForID(noteID)
    local notes = mapID and store.notes[mapID]
    if not (notes and notes[noteID]) then return end
    notes[noteID] = nil
    if next(notes) == nil then
        store.notes[mapID] = nil
    end
    ns:RefreshPins()
end

function ns:CountNotes()
    local total = 0
    for _, store in ipairs({ ns.db, ns.charDB }) do
        for _, notes in pairs(store.notes) do
            for _ in pairs(notes) do total = total + 1 end
        end
    end
    return total
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
    print("  /fmn show|hide <notes|mining|herb|treasure|recipes>")
    print("  /fmn auto on|off - toggle automatic gathering and recipe vendor log")
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
        if key == "recipes" then key = "recipe" end
        if not ns.CATEGORY_BY_KEY[key] then
            ns:Print("Unknown category. Use notes, mining, herb, treasure or recipes.")
            return
        end
        ns:SetCategoryShown(key, cmd == "show")
        ns:Print(("%s %s."):format(ns.CATEGORY_BY_KEY[key].label, cmd == "show" and "shown" or "hidden"))
    elseif cmd == "auto" then
        ns.db.autoLog = rest:lower() ~= "off"
        ns:Print("Automatic gathering and vendor log " .. (ns.db.autoLog and "on." or "off."))
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("Debug " .. (ns.db.debug and "on." or "off."))
    elseif cmd == "count" then
        ns:Print(ns:CountNotes() .. " notes stored.")
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
