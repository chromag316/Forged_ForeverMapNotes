local addonName, ns = ...

-- Shows the notes of the player's current map on the minimap.

local PIN_SIZE = 12
local DOT_SIZE = 5
local DOT_TEXTURE = "Interface\\AddOns\\" .. addonName .. "\\Textures\\Dot"
local UPDATE_INTERVAL = 0.05 -- seconds between position updates

-- Mining and herb notes are drawn as small colored dots, like the game's own
-- Find Minerals / Find Herbs dots; other notes show their icon.
local DOT_COLORS = {
    mining = { 0.93, 0.71, 0 }, -- the mining tracking dot's gold
    herb   = { 0, 1, 0 },
}

-- Minimap diameter in yards per zoom level (Minimap:GetZoom() + 1).
local MINIMAP_YARDS = {
    indoor  = { 300, 240, 180, 120, 80, 50 },
    outdoor = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}

local pins = {}        -- reusable pin frames
local shown = {}       -- notes on the current map in shown categories
local currentMapID     -- map the shown list was built for
local dirty = true     -- rebuild the shown list on the next update
local mapSizes = {}    -- [mapID] = { width, height } in yards, or false if unknown

-- Pin frames -------------------------------------------------------------------

local function OnPinEnter(self)
    ns:ShowNoteTooltip(self, self.note, true)
end

local function GetPin(index)
    local pin = pins[index]
    if not pin then
        pin = CreateFrame("Frame", nil, Minimap)
        pin:SetSize(PIN_SIZE, PIN_SIZE)
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        pin.Icon = pin:CreateTexture(nil, "ARTWORK")
        pin.Icon:SetAllPoints()
        pin.Dot = pin:CreateTexture(nil, "ARTWORK")
        pin.Dot:SetAllPoints()
        pin.Dot:SetTexture(DOT_TEXTURE)
        pin.Dot:Hide()
        -- Hover only (tooltip); clicks go through to the minimap (e.g. ping).
        pin:EnableMouse(true)
        if pin.SetMouseClickEnabled then
            pin:SetMouseClickEnabled(false)
        end
        pin:SetScript("OnEnter", OnPinEnter)
        pin:SetScript("OnLeave", GameTooltip_Hide)
        pins[index] = pin
    end
    return pin
end

local function HideAllPins()
    for _, pin in ipairs(pins) do
        pin:Hide()
    end
end

-- Geometry ---------------------------------------------------------------------

-- Width and height of a map in yards, from the world positions of its corners.
local function GetMapSize(mapID)
    local size = mapSizes[mapID]
    if size == nil then
        size = false
        if C_Map.GetWorldPosFromMapPos and CreateVector2D then
            local _, origin = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
            local _, right = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 0))
            local _, bottom = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 1))
            if origin and right and bottom then
                local w = math.sqrt((right.x - origin.x) ^ 2 + (right.y - origin.y) ^ 2)
                local h = math.sqrt((bottom.x - origin.x) ^ 2 + (bottom.y - origin.y) ^ 2)
                if w > 0 and h > 0 then
                    size = { w, h }
                end
            end
        end
        mapSizes[mapID] = size
    end
    return size
end

local function GetMinimapYards()
    local zoom = Minimap:GetZoom() + 1
    local sizes = IsIndoors() and MINIMAP_YARDS.indoor or MINIMAP_YARDS.outdoor
    return sizes[zoom] or sizes[1]
end

local function IsSquareMinimap()
    return GetMinimapShape and GetMinimapShape() == "SQUARE"
end

-- Update -------------------------------------------------------------------------

local function RebuildShown(mapID)
    wipe(shown)
    currentMapID = mapID
    dirty = false
    local notes = mapID and ns:GetNotes(mapID)
    if not notes then return end
    for _, note in pairs(notes) do
        if ns:IsCategoryShown(note.category) then
            shown[#shown + 1] = note
        end
    end
end

local function UpdatePins()
    if not (ns.db and ns.db.minimap) then
        HideAllPins()
        return
    end

    local mapID, px, py = ns:GetPlayerPosition()
    if mapID ~= currentMapID or dirty then
        RebuildShown(mapID)
    end
    local size = mapID and GetMapSize(mapID)
    if not (size and px) or #shown == 0 then
        HideAllPins()
        return
    end

    local radius = Minimap:GetWidth() / 2
    local scale = Minimap:GetWidth() / GetMinimapYards() -- pixels per yard
    local square = IsSquareMinimap()

    -- With a rotating minimap the player's facing points up.
    local rotate = GetCVar("rotateMinimap") == "1"
    local cos, sin = 1, 0
    if rotate then
        local facing = GetPlayerFacing()
        if facing then
            cos, sin = math.cos(facing), math.sin(facing)
        end
    end

    local active = 0
    for _, note in ipairs(shown) do
        -- Offset in pixels, x to the east and y to the north.
        local x = (note.x - px) * size[1] * scale
        local y = (py - note.y) * size[2] * scale
        if rotate then
            x, y = x * cos + y * sin, y * cos - x * sin
        end
        local inside
        if square then
            inside = math.abs(x) <= radius and math.abs(y) <= radius
        else
            inside = x * x + y * y <= radius * radius
        end
        if inside then
            active = active + 1
            local pin = GetPin(active)
            if pin.note ~= note then
                pin.note = note
                local dot = DOT_COLORS[note.category]
                if dot then
                    pin:SetSize(DOT_SIZE, DOT_SIZE)
                    pin.Dot:SetVertexColor(dot[1], dot[2], dot[3])
                    pin.Dot:Show()
                    pin.Icon:Hide()
                else
                    pin:SetSize(PIN_SIZE, PIN_SIZE)
                    pin.Icon:SetTexture(ns:GetNoteIcon(note))
                    pin.Icon:Show()
                    pin.Dot:Hide()
                end
            end
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
            pin:Show()
        end
    end
    for i = active + 1, #pins do
        pins[i]:Hide()
    end
end

-- Notes, filters or the setting changed.
function ns:RefreshMinimap()
    dirty = true
    -- A renamed note keeps its pin, so drop the cached note to reload icons.
    for _, pin in ipairs(pins) do
        pin.note = nil
    end
end

local driver = CreateFrame("Frame")
local elapsed = 0
local lastError
driver:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0
    if not (Minimap and Minimap:IsVisible()) then return end
    local ok, err = pcall(UpdatePins)
    if not ok then
        HideAllPins()
        if err ~= lastError then
            lastError = err
            ns:Debug("minimap error: " .. tostring(err))
        end
    end
end)
