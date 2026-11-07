local addonName, ns = ...

-- The edit box field has been renamed across client versions; try each.
local function GetEditBox(dialog)
    return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox or dialog.EditBox
end

local function GetText(dialog)
    local editBox = GetEditBox(dialog)
    return strtrim(editBox and editBox:GetText() or "")
end

local function SaveNew(dialog, data)
    local text = GetText(dialog)
    if text ~= "" then
        ns:AddNote(data.mapID, data.x, data.y, text, "note")
    end
end

local function SaveEdit(dialog, data)
    local text = GetText(dialog)
    if text ~= "" then
        ns:UpdateNote(data.mapID, data.noteID, text)
    end
end

StaticPopupDialogs["FORGEDFOREVERMAPNOTES_ADD"] = {
    text = "New map note:",
    -- Buttons are laid out left to right: Cancel, Accept. Accept sits in the
    -- button3 slot (-> OnAlt) so it is never triggered by Escape, which runs
    -- OnCancel.
    button1 = CANCEL,
    button3 = ACCEPT,
    hasEditBox = true,
    maxLetters = 200,
    editBoxWidth = 260,
    OnShow = function(self)
        local editBox = GetEditBox(self)
        editBox:SetText("")
        editBox:SetFocus()
    end,
    OnAlt = SaveNew,
    EditBoxOnEnterPressed = function(editBox, data)
        local dialog = editBox:GetParent()
        SaveNew(dialog, data)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["FORGEDFOREVERMAPNOTES_EDIT"] = {
    text = "Edit map note:",
    -- Buttons are laid out left to right: Delete, Cancel, Save.
    -- button1 -> OnAccept, button2 -> OnCancel, button3 -> OnAlt.
    button1 = DELETE,
    button2 = CANCEL,
    button3 = SAVE,
    hasEditBox = true,
    maxLetters = 200,
    editBoxWidth = 260,
    OnShow = function(self, data)
        local note = ns:GetNote(data.mapID, data.noteID)
        local editBox = GetEditBox(self)
        editBox:SetText(note and note.title or "")
        editBox:SetFocus()
        editBox:HighlightText()
    end,
    OnAccept = function(self, data)
        local note = ns:GetNote(data.mapID, data.noteID)
        -- Close the edit dialog first so the confirmation takes its place
        -- instead of stacking below it. Returning true keeps the popup code
        -- from hiding the frame again (it may now hold the confirmation).
        self:Hide()
        StaticPopup_Show("FORGEDFOREVERMAPNOTES_DELETE", note and note.title or "", nil, data)
        return true
    end,
    OnAlt = SaveEdit,
    EditBoxOnEnterPressed = function(editBox, data)
        local dialog = editBox:GetParent()
        SaveEdit(dialog, data)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["FORGEDFOREVERMAPNOTES_DELETE"] = {
    text = "Delete note \"%s\"?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        ns:DeleteNote(data.mapID, data.noteID)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

function ns:ShowAddDialog(mapID, x, y)
    if not (mapID and x and y) then return end
    StaticPopup_Show("FORGEDFOREVERMAPNOTES_ADD", nil, nil, { mapID = mapID, x = x, y = y })
end

function ns:ShowEditDialog(mapID, noteID)
    if not ns:GetNote(mapID, noteID) then return end
    StaticPopup_Show("FORGEDFOREVERMAPNOTES_EDIT", nil, nil, { mapID = mapID, noteID = noteID })
end
