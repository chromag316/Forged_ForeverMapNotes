local addonName, ns = ...

local PIN_TEMPLATE = "ForgedForeverMapNotesPinTemplate"
local MAX_TOOLTIP_ITEMS = 20

-- Pin ------------------------------------------------------------------------

ForgedForeverMapNotesPinMixin = CreateFromMixins(MapCanvasPinMixin)

function ForgedForeverMapNotesPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
end

function ForgedForeverMapNotesPinMixin:OnAcquired(mapID, noteID, note)
    self.mapID, self.noteID, self.note = mapID, noteID, note
    self.Icon:SetTexture(ns:GetNoteIcon(note))
    self:SetPosition(note.x, note.y)
end

-- Shared by the world map and minimap pins.
function ns:ShowNoteTooltip(owner, note)
    local category = ns.CATEGORY_BY_KEY[note.category] or ns.CATEGORY_BY_KEY.note
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(note.title ~= "" and note.title or category.label, 1, 1, 1)
    GameTooltip:AddLine(category.label, 0.6, 0.8, 1)
    if note.items then
        for i, name in ipairs(note.items) do
            if i > MAX_TOOLTIP_ITEMS then
                GameTooltip:AddLine(("+%d more"):format(#note.items - MAX_TOOLTIP_ITEMS), 0.7, 0.7, 0.7)
                break
            end
            GameTooltip:AddLine(name, 1, 0.82, 0)
        end
    end
    GameTooltip:AddLine(("%.1f, %.1f"):format(note.x * 100, note.y * 100), 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click to edit", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function ForgedForeverMapNotesPinMixin:OnMouseEnter()
    ns:ShowNoteTooltip(self, self.note)
    ns.hoveredPin = self
end

function ForgedForeverMapNotesPinMixin:OnMouseLeave()
    GameTooltip:Hide()
    if ns.hoveredPin == self then
        ns.hoveredPin = nil
    end
end

function ForgedForeverMapNotesPinMixin:OnReleased()
    if ns.hoveredPin == self then
        ns.hoveredPin = nil
        GameTooltip:Hide()
    end
end

function ForgedForeverMapNotesPinMixin:OnMouseUp(button)
    if button == "RightButton" then
        ns:ShowEditDialog(self.mapID, self.noteID)
    end
end

-- Data provider ----------------------------------------------------------------

local provider = CreateFromMixins(MapCanvasDataProviderMixin)

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
end

function provider:RefreshAllData(fromOnShow)
    self:RemoveAllData()
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local notes = ns:GetNotes(mapID)
    if not notes then return end
    for noteID, note in pairs(notes) do
        if ns:IsCategoryShown(note.category) then
            map:AcquirePin(PIN_TEMPLATE, mapID, noteID, note)
        end
    end
end

-- The map makes pins pass right-clicks through to the canvas (where they zoom
-- out), so a right-click on one of our pins arrives here: open its editor.
-- Ctrl+Right-click elsewhere on the canvas opens the "new note" dialog.
-- Returning true stops the default right-click (zoom out).
local function OnCanvasClick(canvas, button, cursorX, cursorY)
    if button ~= "RightButton" then
        return false
    end
    local pin = ns.hoveredPin
    if pin and pin:IsShown() and pin:IsMouseOver() then
        ns:ShowEditDialog(pin.mapID, pin.noteID)
        return true
    end
    if not IsControlKeyDown() then
        return false
    end
    if not (cursorX and cursorY) then
        cursorX, cursorY = canvas:GetNormalizedCursorPosition()
    end
    ns:ShowAddDialog(canvas:GetMapID(), cursorX, cursorY)
    return true
end

function ns:SetupMap()
    if ns.mapReady or not WorldMapFrame then return end
    WorldMapFrame:AddDataProvider(provider)
    WorldMapFrame:AddCanvasClickHandler(OnCanvasClick, 100)
    ns.mapReady = true
    ns:SetupFilterButton()
end

function ns:RefreshPins()
    if ns.mapReady and WorldMapFrame:IsShown() then
        provider:RefreshAllData()
    end
    if ns.RefreshMinimap then
        ns:RefreshMinimap()
    end
end
