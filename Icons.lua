local addonName, ns = ...

-- Per-resource icons for gathered nodes, keyed by the node/herb name that
-- appears in the note title (e.g. "Copper Vein", "Peacebloom").
local MINING_ICONS = {
    ["Copper"] = "Interface\\Icons\\INV_Ore_Copper_01",
    ["Tin"] = "Interface\\Icons\\INV_Ore_Tin_01",
    ["Silver"] = "Interface\\Icons\\INV_Stone_16",
    ["Iron"] = "Interface\\Icons\\INV_Ore_Iron_01",
    ["Gold"] = "Interface\\Icons\\INV_Ore_Copper_01",
    ["Mithril"] = "Interface\\Icons\\INV_Ore_Mithril_02",
    ["Truesilver"] = "Interface\\Icons\\INV_Ore_TrueSilver_01",
    ["Small Thorium"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Thorium"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Rich Thorium"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Dark Iron"] = "Interface\\Icons\\INV_Ore_Mithril_01",
    ["Fel Iron"] = "Interface\\Icons\\INV_Ore_FelIron",
    ["Adamantite"] = "Interface\\Icons\\INV_Ore_Adamantium",
    ["Rich Adamantite"] = "Interface\\Icons\\INV_Ore_Adamantium_01",
    ["Khorium"] = "Interface\\Icons\\INV_Ore_Khorium",
    ["Gemstone"] = "Interface\\Icons\\INV_Misc_Gem_01",
}

local HERB_ICONS = {
    ["Black Lotus"] = "Interface\\Icons\\INV_Misc_Herb_BlackLotus",
    ["Blindweed"] = "Interface\\Icons\\INV_Misc_Herb_14",
    ["Briarthorn"] = "Interface\\Icons\\INV_Misc_Root_01",
    ["Bruiseweed"] = "Interface\\Icons\\INV_Misc_Herb_01",
    ["Dreamfoil"] = "Interface\\Icons\\INV_Misc_Herb_DreamFoil",
    ["Earthroot"] = "Interface\\Icons\\INV_Misc_Herb_07",
    ["Fadeleaf"] = "Interface\\Icons\\INV_Misc_Herb_12",
    ["Felweed"] = "Interface\\Icons\\INV_Misc_Herb_Felweed",
    ["Firebloom"] = "Interface\\Icons\\INV_Misc_Herb_19",
    ["Goldthorn"] = "Interface\\Icons\\INV_Misc_Herb_15",
    ["Grave Moss"] = "Interface\\Icons\\INV_Misc_Dust_02",
    ["Gromsblood"] = "Interface\\Icons\\INV_Misc_Herb_16",
    ["Icecap"] = "Interface\\Icons\\INV_Misc_Herb_IceCap",
    ["Kingsblood"] = "Interface\\Icons\\INV_Misc_Herb_03",
    ["Liferoot"] = "Interface\\Icons\\INV_Misc_Root_02",
    ["Mageroyal"] = "Interface\\Icons\\INV_Jewelry_Talisman_03",
    ["Peacebloom"] = "Interface\\Icons\\INV_Misc_Flower_02",
    ["Plaguebloom"] = "Interface\\Icons\\INV_Misc_Herb_PlagueBloom",
    ["Silverleaf"] = "Interface\\Icons\\INV_Misc_Herb_10",
    ["Stranglekelp"] = "Interface\\Icons\\INV_Misc_Herb_11",
    ["Sungrass"] = "Interface\\Icons\\INV_Misc_Herb_18",
    ["Swiftthistle"] = "Interface\\Icons\\INV_Misc_Herb_04",
    ["Wildvine"] = "Interface\\Icons\\INV_Misc_Herb_03",
    ["Wintersbite"] = "Interface\\Icons\\INV_Misc_Flower_03",
    ["Arthas' Tears"] = "Interface\\Icons\\INV_Misc_Herb_13",
    ["Ghost Mushroom"] = "Interface\\Icons\\INV_Mushroom_08",
    ["Golden Sansam"] = "Interface\\Icons\\INV_Misc_Herb_SansamRoot",
    ["Khadgar's Whisker"] = "Interface\\Icons\\INV_Misc_Herb_08",
    ["Mountain Silversage"] = "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage",
    ["Purple Lotus"] = "Interface\\Icons\\INV_Misc_Herb_17",
    ["Wild Steelbloom"] = "Interface\\Icons\\INV_Misc_Flower_01",
    ["Blood Thistle"] = "Interface\\Icons\\INV_Misc_Herb_Nightmareseed",
    ["Mana Thistle"] = "Interface\\Icons\\INV_Misc_Herb_Manathistle",
    ["Netherbloom"] = "Interface\\Icons\\INV_Misc_Herb_Netherbloom",
    ["Nightmare Vine"] = "Interface\\Icons\\INV_Misc_Herb_Nightmarevine",
    ["Ragveil"] = "Interface\\Icons\\INV_Misc_Herb_Ragveil",
    ["Terocone"] = "Interface\\Icons\\INV_Misc_Herb_Terrocone",
    ["Flame Cap"] = "Interface\\Icons\\INV_Misc_Herb_Flamecap",
    ["Dreaming Glory"] = "Interface\\Icons\\INV_Misc_Herb_Dreamingglory",
    ["Fel Lotus"] = "Interface\\Icons\\INV_Misc_Herb_FelLotus",
    ["Ancient Lichen"] = "Interface\\Icons\\INV_Misc_Herb_AncientLichen",
}

-- Returns the icon of the longest key contained in name, so "Dark Iron
-- Deposit" picks Dark Iron rather than Iron.
local function FindIcon(icons, name)
    local exact = icons[name]
    if exact then return exact end
    local best, bestLen
    for key, path in pairs(icons) do
        if (not bestLen or #key > bestLen) and name:find(key, 1, true) then
            best, bestLen = path, #key
        end
    end
    return best
end

-- Which tables each category searches; others always use the category icon.
local LOOKUPS = {
    mining = { MINING_ICONS },
    herb   = { HERB_ICONS },
    note   = { MINING_ICONS, HERB_ICONS },
}

-- [category] = { [title] = icon or false }. Titles repeat a lot (every
-- "Copper Vein"), and the map redraws pins on every refresh.
local cache = {}

function ns:GetNoteIcon(note)
    local category = ns.CATEGORY_BY_KEY[note.category] or ns.CATEGORY_BY_KEY.note
    local lookups = LOOKUPS[category.key]
    local title = note.title
    if not lookups or type(title) ~= "string" or title == "" then
        return category.icon
    end

    local byTitle = cache[category.key]
    if not byTitle then
        byTitle = {}
        cache[category.key] = byTitle
    end
    local icon = byTitle[title]
    if icon == nil then
        icon = false
        for _, icons in ipairs(lookups) do
            local found = FindIcon(icons, title)
            if found then
                icon = found
                break
            end
        end
        byTitle[title] = icon
    end
    return icon or category.icon
end
