local addonName, ns = ...

local function ShowFilterMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns:Print("Filter menu unavailable. Use /fmn show|hide <category>.")
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Forever Map Notes")
        for _, category in ipairs(ns.CATEGORIES) do
            root:CreateCheckbox(category.label,
                function() return ns:IsCategoryShown(category.key) end,
                function() ns:SetCategoryShown(category.key, not ns:IsCategoryShown(category.key)) end)
        end
        root:CreateDivider()
        root:CreateCheckbox("Auto-log gathering and vendors",
            function() return ns.db.autoLog end,
            function() ns.db.autoLog = not ns.db.autoLog end)
    end)
end

-- Small button in the bottom-left corner of the world map.
function ns:SetupFilterButton()
    if ns.filterButton then return end
    local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    button:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_01")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", ShowFilterMenu)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Forever Map Notes", 1, 1, 1)
        GameTooltip:AddLine("Click to filter notes.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Ctrl+Right-click the map to add a note.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    ns.filterButton = button
end
