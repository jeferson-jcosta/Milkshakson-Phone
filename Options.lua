-- Options panel: Options > AddOns > Milkshakson > Phone
local _, ns = ...
local L = ns.L

function ns:BuildOptions(db)
    local UI = MilkshaksonUI
    if not UI then return end
    local R = function() if ns.Refresh then ns:Refresh() end end

    local p = UI:NewPanel("Phone", L.CFG_DESC)

    UI:Section(p, L.CFG_CHAT_SECTION)
    UI:Check(p, L.CFG_CHAT, L.CFG_CHAT_TIP, function() return db.replaceChat end, function(v) ns:SetReplace(v) end)
    UI:Check(p, L.CFG_LOCK, nil, function() return db.locked end, function(v) db.locked = v or nil; ns:Layout() end)
    UI:Buttons(p, {
        { L.CFG_RESET, function() SlashCmdList.MILKSHAKSONPHONE("reset") end },
    })

    UI:Section(p, L.CFG_CONVS)
    UI:Check(p, L.CFG_MUTE_CH, nil, function() return db.muteChannels end, function(v) db.muteChannels = v end)
    UI:Check(p, L.CFG_MUTE_SYS, nil, function() return db.muteSystem end, function(v) db.muteSystem = v end)
    UI:Slider(p, L.CFG_MAX, 50, 1000, 50, "%d", function() return db.maxMsgs end,
        function(v) db.maxMsgs = v end, L.CFG_MAX_TIP)
    UI:Buttons(p, {
        { L.CFG_CLEAR, function() SlashCmdList.MILKSHAKSONPHONE("clear") end },
    })

    UI:Section(p, L.CFG_DATA)
    UI:Note(p, L.CFG_DATA_NOTE)
    p.y = p.y - 12

    UI:Section(p, L.CFG_LANGUAGE)
    UI:Language(p, ns, db, R)

    UI:Support(p)

    ns.optionsPanel = p
    ns.optionsCategory = UI:Register(p, "Phone")
end

function ns:OpenOptions()
    if MilkshaksonUI then MilkshaksonUI:Open(ns.optionsCategory) end
end
