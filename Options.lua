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
    UI:Slider(p, L.CFG_FONT, 0.8, 1.6, 0.05, "%.2fx", function() return db.fontScale end,
        function(v) db.fontScale = math.floor(v * 100 + 0.5) / 100; if ns.ApplyFontScale then ns:ApplyFontScale() end end, L.CFG_FONT_TIP)
    UI:Note(p, L.CFG_ALIGN)
    UI:Radio(p, { { "messenger", L.ALIGN_MESSENGER }, { "left", L.ALIGN_LEFT }, { "right", L.ALIGN_RIGHT } },
        function() return db.align end, function(v) db.align = v; if ns.Redraw then ns:Redraw() end end)
    UI:Check(p, L.CFG_COMBAT, L.CFG_COMBAT_TIP, function() return db.combatMinimize end, function(v) db.combatMinimize = v end)
    UI:Check(p, L.CFG_HOVER, L.CFG_HOVER_TIP, function() return db.hoverExpand end, function(v) db.hoverExpand = v end)
    UI:Check(p, L.CFG_ANIMATE, nil, function() return db.animate end, function(v) db.animate = v end)
    UI:Slider(p, L.CFG_ANIM_TIME, 0.05, 1, 0.05, "%.2f s", function() return db.animTime end,
        function(v) db.animTime = math.floor(v * 100 + 0.5) / 100 end, L.CFG_ANIM_TIME_TIP)
    UI:Check(p, L.CFG_LOCK, nil, function() return db.locked end, function(v) db.locked = v or nil; ns:Layout() end)
    UI:Buttons(p, {
        { L.CFG_RESET, function() SlashCmdList.MILKSHAKSONPHONE("reset") end },
    })

    UI:Section(p, L.CFG_CONVS)
    UI:Check(p, L.CFG_AUTOJOIN, L.CFG_AUTOJOIN_TIP, function() return db.autoJoin end, function(v) db.autoJoin = v; if v then ns:AutoJoin() end end)
    UI:Section(p, L.CFG_FILTERS)
    local function Hide(kind, on) if not on and ns.CloseKind then ns:CloseKind(kind) end R() end
    UI:Check(p, L.CFG_SYSTEM, L.CFG_SYSTEM_TIP, function() return db.showSystem end, function(v) db.showSystem = v; if not v and not db.showNPC then Hide("system", v) end; R() end)
    UI:Check(p, L.CFG_NPC, nil, function() return db.showNPC end, function(v) db.showNPC = v; if not v and not db.showSystem then Hide("system", v) end; R() end)
    UI:Check(p, L.CFG_MONITOR, L.CFG_MONITOR_TIP, function() return db.monitorSystem end, function(v) db.monitorSystem = v; R() end)
    UI:Check(p, L.CFG_COLORS, L.CFG_COLORS_TIP, function() return db.typeColors end, function(v) db.typeColors = v; if ns.Redraw then ns:Redraw() end end)
    p.y = p.y - 8
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
