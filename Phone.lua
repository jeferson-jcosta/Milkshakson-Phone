-- Milkshakson - Phone
-- The chat as a phone messenger: a list of conversations (players, group,
-- guild, channels) and one conversation open at a time, in bubbles.
local ADDON, ns = ...
local L = ns.L
local Store, Route = ns.Store, ns.Route

local PREFIX = "|cff25d366[Phone]|r "
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local STATUS_H, HEAD_H, INPUT_H, ROW_H, LIST_W = 18, 42, 30, 46, 200
local PAGE = 50 -- messages drawn at first; more when scrolling to the top

-- Dark messenger palette.
local COL = {
    bg = { 0.043, 0.078, 0.098 }, status = { 0.02, 0.04, 0.05 }, head = { 0.122, 0.173, 0.2 },
    inB = { 0.122, 0.173, 0.2 }, outB = { 0.0, 0.361, 0.294 }, info = { 0.09, 0.14, 0.16 },
    text = { 0.91, 0.93, 0.94 }, sub = { 0.53, 0.59, 0.63 }, accent = { 0.145, 0.827, 0.4 },
    sep = { 0.14, 0.19, 0.21 }, input = { 0.165, 0.224, 0.259 }, warn = { 0.55, 0.32, 0.05 },
}
local settings

-- Text colors per chat type: the game's own (ChatTypeInfo, follows the
-- player's chat color settings), with the default colors as fallback.
local TYPE_COL = {
    GUILD = { 0.25, 1, 0.25 }, GUILD_ACHIEVEMENT = { 0.25, 1, 0.25 }, OFFICER = { 0.25, 0.75, 0.25 },
    PARTY = { 0.67, 0.67, 1 }, PARTY_LEADER = { 0.46, 0.78, 1 },
    RAID = { 1, 0.5, 0 }, RAID_LEADER = { 1, 0.28, 0.04 }, RAID_WARNING = { 1, 0.28, 0 },
    INSTANCE_CHAT = { 1, 0.5, 0 }, INSTANCE_CHAT_LEADER = { 1, 0.86, 0.73 },
    WHISPER = { 1, 0.5, 1 }, WHISPER_INFORM = { 1, 0.5, 1 }, AFK = { 1, 0.5, 1 }, DND = { 1, 0.5, 1 },
    BN_WHISPER = { 0, 1, 0.96 }, BN_WHISPER_INFORM = { 0, 1, 0.96 },
    SAY = { 1, 1, 1 }, YELL = { 1, 0.25, 0.25 }, EMOTE = { 1, 0.5, 0.25 }, TEXT_EMOTE = { 1, 0.5, 0.25 },
    CHANNEL = { 1, 0.75, 0.75 }, SYSTEM = { 1, 1, 0 },
    MONSTER_SAY = { 1, 1, 0.62 }, MONSTER_YELL = { 1, 0.25, 0.25 }, MONSTER_EMOTE = { 1, 0.5, 0.25 },
}

local function TypeColor(m, c)
    if not (settings and settings.typeColors) or not m then return nil end
    local ev = m.ev or ""
    if ev == "CHANNEL" and c and c.chan then
        local info = ChatTypeInfo and ChatTypeInfo["CHANNEL" .. c.chan]
        if info and info.r then return { info.r, info.g, info.b } end
    end
    local info = ChatTypeInfo and ChatTypeInfo[ev]
    if info and info.r then return { info.r, info.g, info.b } end
    if TYPE_COL[ev] then return TYPE_COL[ev] end
    if c and c.kind == "system" then return TYPE_COL.SYSTEM end
end
ns.TypeColor = TypeColor

local KIND_ICON = {
    whisper = "Interface\\Icons\\INV_Misc_QuestionMark", bn = "Interface\\Icons\\INV_Misc_Note_06",
    guild = "Interface\\Icons\\INV_Shirt_GuildTabard_01", officer = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    party = "Interface\\Icons\\Ability_Warrior_RallyingCry", raid = "Interface\\Icons\\Ability_Warrior_BattleShout",
    instance = "Interface\\Icons\\INV_Misc_Key_03", ["local"] = "Interface\\Icons\\INV_Misc_Head_Human_01",
    channel = "Interface\\Icons\\INV_Letter_15", system = "Interface\\Icons\\INV_Misc_Gear_01",
    npc = "Interface\\Icons\\Ability_Hunter_BeastCall",
}
-- Channel icons by name (any client language): business, defense.
local CHANNEL_ICON = {
    { "Interface\\Icons\\INV_Misc_Coin_01", { "trade", "comércio", "comercio", "handel", "commerce" } },
    { "Interface\\Icons\\INV_Sword_04", { "defense", "defesa", "defensa", "verteidigung", "défense" } },
}
local function ChannelIcon(name)
    name = (name or ""):lower()
    for _, x in ipairs(CHANNEL_ICON) do
        for _, w in ipairs(x[2]) do
            if name:find(w, 1, true) then return x[1] end
        end
    end
end
local SEND_TYPE = { party = "PARTY", raid = "RAID", instance = "INSTANCE_CHAT", guild = "GUILD", officer = "OFFICER", ["local"] = "SAY" }

local phone, clockText, zoneText, banner, grip
local listView, listTitle, listScroll, listContent, emptyText
local chatView, chatTitle, chatSub, chatIcon, chatScroll, chatContent
local inputBar, inputText
local rows, bubbles, seps = {}, {}, {}
local openKey

local function Num(v, d) return type(v) == "number" and v or d end

-- Errors are shown on the phone itself (the game's chat may be hidden and
-- script errors are often turned off): red text over the chat, click to close.
local errorBox
local function ShowError(err)
    err = tostring(err)
    if settings then
        settings.errors = (settings.errors or 0) + 1
        settings.lastError = err
    end
    if errorBox then
        errorBox.text:SetText("|cffff5050Milkshakson-Phone error|r (click to close)\n" .. err)
        errorBox:Show()
    else
        print("|cffff5050[Phone] error:|r " .. err)
    end
end
ns.ShowError = ShowError

local function Trace(e)
    return tostring(e) .. "\n" .. ((debugstack and debugstack(2, 8, 0)) or "")
end

-- Runs f(...) and shows any error instead of failing silently.
local function Safe(f, ...)
    local ok, err = xpcall(f, Trace, ...)
    if not ok then ShowError(err) end
    return ok
end
ns.Safe = Safe

local function Tex(parent, layer, c, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    return t
end

local function Font(parent, template, c, justify)
    local f = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if c then f:SetTextColor(c[1], c[2], c[3]) end
    f:SetJustifyH(justify or "LEFT")
    return f
end

local function ClassColor(cls)
    if not cls then return nil end
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
end

local function Title(c)
    if c.kind == "whisper" or c.kind == "bn" or c.kind == "channel" then return c.name or "?" end
    return L["K_" .. c.kind]
end

local function IsGroup(kind) return kind ~= "whisper" and kind ~= "bn" end

local function Sub(c)
    local s
    if c.kind == "whisper" then s = L.SUB_WHISPER
    elseif c.kind == "bn" then s = L.SUB_BN
    elseif c.kind == "channel" then s = c.chan and L.SUB_CHANNEL:format(c.chan) or L.SUB_GROUP
    elseif c.kind == "system" or c.kind == "npc" then s = L.SUB_READONLY
    else s = L.SUB_GROUP end
    if c.muted then s = s .. "  -  " .. L.MUTED end
    return s
end

local function Today(t) return date("%Y%m%d", t) end
local function Clock(t) return date("%H:%M", t) end
local function DayLabel(t)
    local d = Today(t)
    if d == Today(time()) then return L.TODAY end
    if d == Today(time() - 86400) then return L.YESTERDAY end
    return date("%d/%m/%Y", t)
end
local function ListTime(t)
    local d = Today(t)
    if d == Today(time()) then return Clock(t) end
    if d == Today(time() - 86400) then return L.YESTERDAY end
    return date("%d/%m", t)
end

local function OneLine(s) return ((s or ""):gsub("[\r\n]+", " ")) end

-- Message text with its tag ([!], [AFK]...).
local function Body(m)
    local s = m.text or ""
    if m.ev == "EMOTE" and m.from then s = m.from .. " " .. s end
    if m.tag == "warning" then s = "|cffff8000" .. L.TAG_WARNING .. "|r " .. s
    elseif m.tag == "afk" then s = L.TAG_AFK .. " " .. s
    elseif m.tag == "dnd" then s = L.TAG_DND .. " " .. s
    elseif m.tag == "yell" then s = "|cffff5050" .. s .. "|r" end
    return s
end

local function Preview(c, m)
    local s = OneLine(Body(m))
    if m.out then return L.YOU .. ": " .. s end
    if IsGroup(c.kind) and m.from and not m.info then return m.from .. ": " .. s end
    return s
end

local function SetIcon(tex, c)
    local coords = c.cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c.cls]
    if coords and c.kind == "whisper" then
        tex:SetTexture(CLASS_TEX)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        tex:SetTexture((c.kind == "channel" and ChannelIcon(c.name)) or KIND_ICON[c.kind] or KIND_ICON.whisper)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

ns.SetIcon = SetIcon

local function Round(tex) if tex.SetMask then pcall(tex.SetMask, tex, MASK) end end

local function TextButton(parent, label, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    b.fs = fs
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end
    return b
end

local function Scroller(parent, onTop)
    local s = CreateFrame("ScrollFrame", nil, parent)
    local c = CreateFrame("Frame", nil, s)
    c:SetSize(10, 10)
    s:SetScrollChild(c)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d)
        local max = Num(self:GetVerticalScrollRange(), 0)
        local v = Num(self:GetVerticalScroll(), 0)
        if d > 0 and v <= 0 and onTop then onTop() return end
        self:SetVerticalScroll(math.max(0, math.min(max, v - d * 48)))
    end)
    s:SetScript("OnSizeChanged", function(_, w) if Num(w, 0) > 1 then c:SetWidth(w) end end)
    return s, c
end

---------------------------------------------------------------------------
-- The game's edit box (typing stays with the game: slash commands, links,
-- channels and whisper targets all work as usual)
---------------------------------------------------------------------------
local function EditBox() return (ChatFrame1 and ChatFrame1.editBox) or _G.ChatFrame1EditBox end

local function ChatTarget(c)
    if not c then return end
    if c.kind == "whisper" then return "WHISPER", c.target or c.name end
    if c.kind == "bn" then return "BN_WHISPER", c.target or c.name end
    if c.kind == "channel" then if c.chan then return "CHANNEL", c.chan end return end
    return SEND_TYPE[c.kind]
end
ns.ChatTarget = ChatTarget

-- Make the open conversation the edit box's current/sticky target.
function ns:SetSticky(c)
    local e = EditBox()
    local t, target = ChatTarget(c)
    if not (e and t) then return false end
    e:SetAttribute("chatType", t)
    e:SetAttribute("stickyType", t)
    if t == "WHISPER" or t == "BN_WHISPER" then e:SetAttribute("tellTarget", target) end
    if t == "CHANNEL" then e:SetAttribute("channelTarget", target) end
    local upd = ChatEdit_UpdateHeader or (ChatFrameUtil and ChatFrameUtil.UpdateHeader)
    if upd and e:IsShown() then pcall(upd, e) end
    return true
end

function ns:Compose()
    local c = Store:Get(openKey)
    if c then ns:SetSticky(c) end
    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
    if open then pcall(open, "", ChatFrame1) end
end

local ebHome -- { parent, points } of the edit box before docking
local function DockEditBox(on)
    local e = EditBox()
    if not e then return end
    if on then
        if not ebHome then
            ebHome = { parent = e:GetParent(), points = {} }
            for i = 1, Num(e:GetNumPoints(), 0) do ebHome.points[i] = { e:GetPoint(i) } end
        end
        e:SetParent(phone)
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", inputBar, "TOPLEFT", -2, 2)
        e:SetPoint("BOTTOMRIGHT", inputBar, "BOTTOMRIGHT", 2, -2)
        ns.docked = true
    elseif ebHome then
        e:SetParent(ebHome.parent)
        e:ClearAllPoints()
        for _, p in ipairs(ebHome.points) do e:SetPoint(unpack(p)) end
        ebHome = nil
        ns.docked = false
    end
end

---------------------------------------------------------------------------
-- Replacing the game's chat: its windows (and any chat addon built on them)
-- are parked under a hidden frame; they keep working, just not visible.
---------------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()
local parked = {}
local CHAT_PARTS = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
    "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatAlertFrame" }

local function Park(f)
    if type(f) ~= "table" or parked[f] or not f.SetParent then return end
    parked[f] = f:GetParent() or UIParent
    f:SetParent(hider)
end

local function ParkAll()
    for i = 1, math.max(Num(NUM_CHAT_WINDOWS, 10), 20) do
        Park(_G["ChatFrame" .. i])
        Park(_G["ChatFrame" .. i .. "Tab"])
        Park(_G["ChatFrame" .. i .. "ButtonFrame"])
    end
    for _, n in ipairs(CHAT_PARTS) do Park(_G[n]) end
end

local function ApplyReplace(on)
    if on then
        DockEditBox(true) -- before parking ChatFrame1 (its parent)
        ParkAll()
    else
        for f, p in pairs(parked) do f:SetParent(p) end
        wipe(parked)
        DockEditBox(false)
    end
    ns.replacing = on and true or false
end
ns.ApplyReplace = ApplyReplace

function ns:SetReplace(on)
    settings.replaceChat = on and true or false
    if not ns.blocked then ApplyReplace(settings.replaceChat) end
    if settings.replaceChat then settings.shown = true; phone:Show() end
    ns:Layout()
end

-- The game hid a message from addons: show its chat until that ends.
function ns:Blocked(event)
    local inst = IsInInstance and select(2, IsInInstance()) or nil
    local n = (settings.secret and settings.secret.n or 0) + 1
    settings.secret = { n = n, t = time(), ev = event, combat = (InCombatLockdown and InCombatLockdown()) and true or false, instance = inst }
    if ns.blocked then return end
    ns.blocked = true
    if ns.replacing then ApplyReplace(false) end
    banner:Show()
end

function ns:Unblock()
    if not ns.blocked then return end
    ns.blocked = false
    banner:Hide()
    if settings.replaceChat then ApplyReplace(true) end
end

---------------------------------------------------------------------------
-- Fixed conversations (party / guild on top) and joined channels
---------------------------------------------------------------------------
-- Conversations switched off in the options (not stored, not listed).
local function HiddenKinds()
    return { system = not settings.showSystem or nil, npc = not settings.showNPC or nil }
end
ns.HiddenKinds = HiddenKinds

local function TopKeys()
    local t = {}
    if IsInRaid and IsInRaid() then t[#t + 1] = "raid"
    elseif IsInGroup and IsInGroup() then t[#t + 1] = "party" end
    if IsInGuild and IsInGuild() then t[#t + 1] = "guild" end
    for _, k in ipairs(t) do Store:Ensure(k, k) end
    for _, x in ipairs(ns.Channels()) do
        if x.joined then t[#t + 1] = x.conv.key end
    end
    return t
end
ns.TopKeys = TopKeys

local function ChanKey(name) return "c:" .. name:lower() end

-- Channels the character is in (GetChannelList: id, name, disabled, ...),
-- then channel conversations with messages that are not joined now.
local function Channels()
    local t, seen = {}, {}
    local function add(id, name)
        if type(name) ~= "string" or name == "" or (tonumber(id) or 0) <= 0 then return end
        name = name:match("^(.-) %- ") or name
        local c = Store:Ensure(ChanKey(name), "channel", name)
        c.chan = tonumber(id)
        if not seen[c.key] then seen[c.key] = true; t[#t + 1] = { conv = c, joined = true } end
    end
    -- GetChannelName(n) -> id, name: the same on every client version.
    if GetChannelName then
        for n = 1, 20 do
            local id, name = GetChannelName(n)
            add(id, name)
        end
    end
    if #t == 0 and GetChannelList then
        local list = { GetChannelList() }
        for i = 1, #list, 3 do add(list[i], list[i + 1]) end
    end
    local rest = {}
    for _, c in pairs(Store:Char().convs) do
        if c.kind == "channel" and not seen[c.key] and #c.msgs > 0 then rest[#rest + 1] = { conv = c } end
    end
    table.sort(rest, function(a, b) return a.conv.key < b.conv.key end)
    for _, x in ipairs(rest) do t[#t + 1] = x end
    return t
end
ns.Channels = Channels

---------------------------------------------------------------------------
-- Auto-join General, Trade and LocalDefense (names are localized: the
-- server's own channel list is used, matched against known names)
---------------------------------------------------------------------------
local WANTED = {
    general = true, geral = true, allgemein = true, ["général"] = true,
    trade = true, ["comércio"] = true, comercio = true, handel = true, commerce = true,
    localdefense = true, defesalocal = true, defensalocal = true, lokaleverteidigung = true, ["défenselocale"] = true,
}
ns.WANTED = WANTED

local function Joined(name)
    if not GetChannelName then return false end
    local id = GetChannelName(name)
    return (tonumber(id) or 0) > 0
end

function ns:AutoJoin()
    if not settings.autoJoin or not JoinChannelByName then return end
    local names = {}
    if EnumerateServerChannels then
        for _, n in ipairs({ EnumerateServerChannels() }) do
            if type(n) == "string" and WANTED[n:lower():gsub("%s", "")] then names[#names + 1] = n end
        end
    end
    if #names == 0 then names = { "General", "Trade", "LocalDefense" } end
    local done = {}
    for _, n in ipairs(names) do
        if not Joined(n) then
            local ok = pcall(JoinChannelByName, n)
            done[#done + 1] = n .. (ok and "" or "(error)")
        end
    end
    settings.lastJoin = { t = time(), tried = table.concat(names, ", "), joined = table.concat(done, ", ") }
    return done
end

---------------------------------------------------------------------------
-- List view
---------------------------------------------------------------------------
local function RowMenu(owner, c)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(Title(c))
            root:CreateButton(c.pinned and L.UNPIN or L.PIN, function() Store:SetPinned(c.key, not c.pinned) end)
            root:CreateButton(c.muted and L.UNMUTE or L.MUTE, function() Store:SetMuted(c.key, not c.muted) end)
            root:CreateButton(L.CLEAR_CONV, function() Store:ClearConv(c.key) end)
            root:CreateButton(L.DELETE_CONV, function() Store:Delete(c.key) end)
        end)
    else
        Store:SetMuted(c.key, not c.muted)
    end
end

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, listContent)
    r:SetHeight(ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.sel = Tex(r, "BACKGROUND", COL.head)
    r.sel:SetAllPoints()
    r.sel:Hide()
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(32, 32)
    r.icon:SetPoint("LEFT", 8, 0)
    -- no mask: on this client a masked texture refuses SetTexCoord (class / icon crops)
    r.time = Font(r, "GameFontHighlightSmall", COL.sub, "RIGHT")
    r.time:SetPoint("TOPRIGHT", -8, -8)
    r.name = Font(r, "GameFontHighlight", COL.text)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.name:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
    r.name:SetWordWrap(false)
    r.prev = Font(r, "GameFontHighlightSmall", COL.sub)
    r.prev:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 2)
    r.prev:SetPoint("RIGHT", r, "RIGHT", -30, 0)
    r.prev:SetWordWrap(false)
    r.badge = CreateFrame("Frame", nil, r)
    r.badge:SetSize(18, 18)
    r.badge:SetPoint("BOTTOMRIGHT", -8, 6)
    local bg = Tex(r.badge, "ARTWORK", COL.accent)
    bg:SetAllPoints()
    Round(bg)
    r.badge.bg = bg
    r.badge.n = Font(r.badge, "GameFontHighlightSmall", { 0.05, 0.08, 0.1 }, "CENTER")
    r.badge.n:SetPoint("CENTER")
    local line = Tex(r, "BORDER", COL.sep)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, -6)
    line:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
    r:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then RowMenu(self, self.conv) else ns:Open(self.conv.key) end
    end)
    rows[i] = r
    return r
end

-- The scroll child does not follow the scroll frame's width by itself, and the
-- frame can still be 0 wide before the first layout: fall back to the phone size.
local function FitWidth(scroll, content, fallback)
    local w = Num(scroll:GetWidth(), 0)
    if w <= 1 then w = fallback end
    content:SetWidth(w)
    return w
end

local function RenderList()
    FitWidth(listScroll, listContent, LIST_W)
    local list = Store:List(TopKeys(), HiddenKinds())
    for i, c in ipairs(list) do
        local r = Row(i)
        r.conv = c
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT", listContent, "RIGHT")
        SetIcon(r.icon, c)
        r.name:SetText(Title(c))
        local cc = (c.kind == "whisper" and ClassColor(c.cls)) or COL.text
        r.name:SetTextColor(cc[1], cc[2], cc[3])
        local m = c.msgs[#c.msgs]
        r.time:SetText(m and ListTime(m.t) or "")
        r.prev:SetText(m and Preview(c, m) or L.NO_MSGS)
        local pc = TypeColor(m, c) or COL.sub
        r.prev:SetTextColor(pc[1], pc[2], pc[3])
        local n = c.muted and (c.unseen or 0) or (c.unread or 0)
        r.sel:SetShown(openKey == c.key)
        if n > 0 then
            r.badge.n:SetText(n > 99 and "99+" or tostring(n))
            local bc = c.muted and COL.sub or COL.accent
            r.badge.bg:SetColorTexture(bc[1], bc[2], bc[3], 1)
            r.badge:Show()
            r.time:SetTextColor(bc[1], bc[2], bc[3])
        else
            r.badge:Hide()
            r.time:SetTextColor(COL.sub[1], COL.sub[2], COL.sub[3])
        end
        r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    listContent:SetHeight(math.max(1, #list * ROW_H))
    emptyText:SetShown(#list == 0)
    return #list
end

---------------------------------------------------------------------------
-- Conversation view
---------------------------------------------------------------------------
local function Bubble(i)
    if bubbles[i] then return bubbles[i] end
    local b = CreateFrame("Frame", nil, chatContent)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.name = Font(b, "GameFontNormalSmall")
    b.name:SetPoint("TOPLEFT", 8, -5)
    b.text = Font(b, "GameFontHighlight", COL.text)
    b.time = Font(b, "GameFontHighlightSmall", COL.sub, "RIGHT")
    b.time:SetPoint("BOTTOMRIGHT", -7, 4)
    if b.SetHyperlinksEnabled then
        b:SetHyperlinksEnabled(true)
        b:SetScript("OnHyperlinkClick", function(_, link, text, button)
            if SetItemRef then pcall(SetItemRef, link, text, button) end
        end)
    end
    bubbles[i] = b
    return b
end

local function Sep(i)
    if seps[i] then return seps[i] end
    local s = CreateFrame("Frame", nil, chatContent)
    Tex(s, "BACKGROUND", COL.info):SetAllPoints()
    s.text = Font(s, "GameFontHighlightSmall", COL.sub, "CENTER")
    s.text:SetPoint("CENTER")
    seps[i] = s
    return s
end

local function ScrollBottom()
    local function go()
        if chatScroll.UpdateScrollChildRect then chatScroll:UpdateScrollChildRect() end
        local r = chatScroll:GetVerticalScrollRange()
        if type(r) == "number" then chatScroll:SetVerticalScroll(r) end
    end
    go()
    if C_Timer and C_Timer.After then C_Timer.After(0, go) end
end

local function AtBottom()
    local r, v = chatScroll:GetVerticalScrollRange(), chatScroll:GetVerticalScroll()
    if type(r) ~= "number" or type(v) ~= "number" then return true end
    return r - v < 30
end

-- What is drawn now, so a new message only adds its own bubble.
local view = { show = PAGE }

local function ResetView(key, width)
    for _, b in ipairs(bubbles) do b:Hide() end
    for _, x in ipairs(seps) do x:Hide() end
    view.key, view.width, view.y, view.nb, view.nsep, view.lastDay, view.last, view.count, view.first =
        key, width, 8, 0, 0, nil, nil, 0, nil
end

local function PlaceMsg(c, m, maxW, group)
    local day = Today(m.t)
    if day ~= view.lastDay then
        view.lastDay = day
        view.nsep = view.nsep + 1
        local x = Sep(view.nsep)
        x.text:SetText(DayLabel(m.t))
        x:SetSize(Num(x.text:GetUnboundedStringWidth(), 60) + 18, 18)
        x:ClearAllPoints()
        x:SetPoint("TOP", chatContent, "TOP", 0, -view.y)
        x:Show()
        view.y = view.y + 26
    end
    view.nb = view.nb + 1
    local b = Bubble(view.nb)
    local tc = TypeColor(m, c)
    b.text:ClearAllPoints()
    b.text:SetWidth(maxW)
    b.text:SetText(Body(m))
    local tw = math.min(maxW, Num(b.text:GetUnboundedStringWidth(), maxW))
    local w, h
    b:ClearAllPoints()
    if m.info then
        local t = COL.info
        b.bg:SetColorTexture(t[1], t[2], t[3], 1)
        local fc = tc or COL.sub
        b.text:SetTextColor(fc[1], fc[2], fc[3])
        b.text:SetJustifyH("CENTER")
        b.name:Hide()
        b.time:Hide()
        b.text:SetWidth(tw + 2)
        b.text:SetPoint("TOPLEFT", 8, -5)
        w, h = tw + 18, Num(b.text:GetStringHeight(), 14) + 10
        b:SetPoint("TOP", chatContent, "TOP", 0, -view.y)
    else
        local t = m.out and COL.outB or COL.inB
        b.bg:SetColorTexture(t[1], t[2], t[3], 1)
        local fc = tc or COL.text
        b.text:SetTextColor(fc[1], fc[2], fc[3])
        b.text:SetJustifyH("LEFT")
        local showName = group and not m.out and m.from
        local nw = 0
        if showName then
            local nc = ClassColor(m.cls) or COL.accent
            b.name:SetText(m.from .. (m.tag == "leader" and (" (" .. L.LEADER .. ")") or ""))
            b.name:SetTextColor(nc[1], nc[2], nc[3])
            b.name:Show()
            nw = Num(b.name:GetUnboundedStringWidth(), 0)
        else
            b.name:Hide()
        end
        b.time:SetText(Clock(m.t))
        b.time:Show()
        local inner = math.max(tw, math.min(nw, maxW), Num(b.time:GetUnboundedStringWidth(), 30))
        b.text:SetWidth(inner + 2)
        local top = showName and 19 or 6
        b.text:SetPoint("TOPLEFT", 8, -top)
        w, h = inner + 18, top + Num(b.text:GetStringHeight(), 14) + 17
        if m.out then
            b:SetPoint("TOPRIGHT", chatContent, "TOPRIGHT", -8, -view.y)
        else
            b:SetPoint("TOPLEFT", chatContent, "TOPLEFT", 8, -view.y)
        end
    end
    b:SetSize(w, h)
    b:Show()
    view.y = view.y + h + 5
    view.count = view.count + 1
end

-- mode: "open" (full, scroll to the end), "more" (full, keep the place),
-- nil (only add what is new; full when the size changed or it grew too much).
local function RenderChat(mode)
    local c = Store:Get(openKey)
    if not c then
        ResetView(nil, 0)
        chatTitle:SetText(L.PICK)
        chatTitle:SetTextColor(COL.sub[1], COL.sub[2], COL.sub[3])
        chatSub:SetText("")
        chatIcon:SetTexture(KIND_ICON.channel)
        return 0
    end
    chatTitle:SetText(Title(c))
    local cc = (c.kind == "whisper" and ClassColor(c.cls)) or COL.text
    chatTitle:SetTextColor(cc[1], cc[2], cc[3])
    chatSub:SetText(Sub(c))
    SetIcon(chatIcon, c)

    local width = FitWidth(chatScroll, chatContent, Num(phone:GetWidth(), settings.w) - LIST_W)
    local maxW = math.floor(width * 0.8) - 16
    local msgs = c.msgs
    local stick = mode == "open" or (mode == nil and AtBottom())
    local from
    if mode == nil and view.key == c.key and view.width == width then
        if view.last == nil and #msgs == 0 then return view.count end
        for i = #msgs, 1, -1 do
            if msgs[i] == view.last then from = i + 1 break end
        end
        if from and view.count + (#msgs - from + 1) > view.show + PAGE then from = nil end
    end
    if not from then
        ResetView(c.key, width)
        from = math.max(1, #msgs - view.show + 1)
        view.first = from
    end
    local group = IsGroup(c.kind)
    for i = from, #msgs do PlaceMsg(c, msgs[i], maxW, group) end
    view.last = msgs[#msgs]
    chatContent:SetHeight(view.y + 4)
    if stick then ScrollBottom() end
    return view.count
end
ns.View = view

-- Scrolled to the top: draw an older page, keeping the same message on screen.
function ns:More()
    local c = Store:Get(openKey)
    if not c or not view.first or view.first <= 1 then return end
    local oldH, oldV = view.y, Num(chatScroll:GetVerticalScroll(), 0)
    view.show = view.show + PAGE
    RenderChat("more")
    if chatScroll.UpdateScrollChildRect then chatScroll:UpdateScrollChildRect() end
    chatScroll:SetVerticalScroll(oldV + (view.y - oldH))
end

---------------------------------------------------------------------------
-- Layout / refresh
---------------------------------------------------------------------------
function ns:Layout()
    if not phone then return end
    local min = settings.min
    local inChat = openKey ~= nil and not min
    -- Two panes, like a desktop messenger: chats on the left, the open chat on the right.
    listView:ClearAllPoints()
    listView:SetPoint("TOPLEFT", phone, "TOPLEFT", 0, -STATUS_H)
    if min then
        listView:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT")
    else
        listView:SetPoint("BOTTOMLEFT", phone, "BOTTOMLEFT", 0, INPUT_H + 10)
        listView:SetWidth(LIST_W)
    end
    listView:Show()
    listScroll:SetShown(not min)
    chatView:SetShown(not min)
    inputBar:SetShown(not min)
    grip:SetShown(not min and not settings.locked)
    phone:SetHeight(min and (STATUS_H + HEAD_H) or settings.h)
    local c = Store:Get(openKey)
    if inChat and c and ChatTarget(c) then
        inputText:SetText(L.INPUT_TO:format(Title(c)))
    elseif inChat then
        inputText:SetText(L.INPUT_READONLY)
    else
        inputText:SetText(L.INPUT_NONE)
    end
end

local function UpdateTitle()
    local n = Store:Unread(HiddenKinds())
    listTitle:SetText(n > 0 and L.CHATS_N:format(n) or L.CHATS)
end

local pending
local function DoRefresh(_, key)
    if not phone then return end
    UpdateTitle()
    if not phone:IsShown() or settings.min then return end -- drawn when shown again
    RenderList()
    if openKey and (key == nil or key == openKey) then
        if not Store:Get(openKey) then openKey = nil; ns:Layout() else RenderChat() end
    end
end

local function Later()
    if pending then return end
    pending = true
    local function run() pending = false; ns:Refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end

local function DoOpen(_, key)
    openKey = key
    settings.lastOpen = key
    settings.min = false
    Store:Read(key)
    local c = Store:Get(key)
    if c then ns:SetSticky(c) end
    if view.key ~= key then view.show = PAGE end
    ns:Layout()
    RenderChat("open")
    UpdateTitle()
    RenderList()
end

function ns:Refresh(key) return Safe(DoRefresh, ns, key) end
ns.Later = Later
function ns:Open(key) return Safe(DoOpen, ns, key) end

-- A kind was switched off: leave its conversation if it is open.
function ns:CloseKind(kind)
    local c = Store:Get(openKey)
    if c and c.kind == kind then openKey = nil; ns:Layout() end
end

-- Draw everything again (colors changed).
function ns:Redraw()
    view.key = nil
    ns:Refresh()
end

function ns:Back()
    openKey = nil
    ns:Layout()
    ns:Refresh()
end

function ns:IsOpen(key)
    return phone and phone:IsShown() and not settings.min and openKey == key
end

function ns:Minimize(v)
    if v == nil then v = not settings.min end
    settings.min = v and true or false
    ns:Layout()
    if not v then ns:Refresh() end
end

function ns:Toggle()
    if settings.replaceChat then
        ns:Minimize()
    else
        settings.shown = not phone:IsShown()
        phone:SetShown(settings.shown)
    end
end

local function UpdateStatus()
    if not phone then return end
    clockText:SetText(date("%H:%M"))
    zoneText:SetText((GetMinimapZoneText and GetMinimapZoneText()) or (GetRealZoneText and GetRealZoneText()) or "")
end

local function SavePoint()
    local p, _, rp, x, y = phone:GetPoint(1)
    if type(p) == "string" then settings.point = { p, rp, x, y } end
end

local function Place()
    phone:ClearAllPoints()
    local pt = settings.point
    if pt then
        phone:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
    else
        phone:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 96)
    end
    phone:SetSize(settings.w, settings.min and (STATUS_H + HEAD_H) or settings.h)
end
ns.Place = Place

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function Drag(f)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if not settings.locked then phone:StartMoving() end end)
    f:SetScript("OnDragStop", function() phone:StopMovingOrSizing(); SavePoint() end)
end

local function Header(parent)
    local h = CreateFrame("Frame", nil, parent)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:SetHeight(HEAD_H)
    Tex(h, "BACKGROUND", COL.head):SetAllPoints()
    Drag(h)
    return h
end

local function Build()
    phone = CreateFrame("Frame", "MilkshaksonPhoneFrame", UIParent)
    phone:SetFrameStrata("LOW")
    phone:SetClampedToScreen(true)
    phone:SetMovable(true)
    phone:SetResizable(true)
    phone:EnableMouse(true)
    if phone.SetResizeBounds then phone:SetResizeBounds(250, 260, 700, 1000) end
    Tex(phone, "BACKGROUND", COL.bg, 0.97):SetAllPoints()

    local status = CreateFrame("Frame", nil, phone)
    status:SetPoint("TOPLEFT")
    status:SetPoint("TOPRIGHT")
    status:SetHeight(STATUS_H)
    Tex(status, "BACKGROUND", COL.status):SetAllPoints()
    Drag(status)
    clockText = Font(status, "GameFontHighlightSmall", COL.text)
    clockText:SetPoint("LEFT", 10, 0)
    zoneText = Font(status, "GameFontHighlightSmall", COL.sub, "RIGHT")
    zoneText:SetPoint("RIGHT", -10, 0)
    zoneText:SetPoint("LEFT", clockText, "RIGHT", 10, 0)
    zoneText:SetWordWrap(false)

    -- Bottom: the bar the game's edit box sits on.
    inputBar = CreateFrame("Button", nil, phone)
    inputBar:SetPoint("BOTTOMLEFT", 6, 6)
    inputBar:SetPoint("BOTTOMRIGHT", -20, 6)
    inputBar:SetHeight(INPUT_H)
    Tex(inputBar, "BACKGROUND", COL.input):SetAllPoints()
    inputText = Font(inputBar, "GameFontHighlight", COL.sub)
    inputText:SetPoint("LEFT", 12, 0)
    inputText:SetPoint("RIGHT", -8, 0)
    inputText:SetWordWrap(false)
    inputBar:SetScript("OnClick", function() ns:Compose() end)

    -- List
    listView = CreateFrame("Frame", nil, phone)
    listView:SetPoint("TOPLEFT", status, "BOTTOMLEFT")
    listView:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT", 0, INPUT_H + 10)
    local lh = Header(listView)
    listTitle = Font(lh, "GameFontNormalLarge", COL.text)
    listTitle:SetPoint("LEFT", 12, 0)
    local minB = TextButton(lh, "_", function() ns:Minimize() end, L.TIP_MIN)
    minB:SetPoint("RIGHT", -6, 0)
    listScroll, listContent = Scroller(listView)
    listScroll:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", 0, -2)
    listScroll:SetPoint("BOTTOMRIGHT")
    emptyText = Font(listContent, "GameFontHighlightSmall", COL.sub, "CENTER")
    emptyText:SetPoint("TOPLEFT", 20, -30)
    emptyText:SetPoint("TOPRIGHT", -20, -30)
    emptyText:SetText(L.EMPTY)

    -- Conversation
    chatView = CreateFrame("Frame", nil, phone)
    chatView:SetPoint("TOPLEFT", listView, "TOPRIGHT")
    chatView:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT", 0, INPUT_H + 10)
    local divider = Tex(chatView, "BORDER", COL.sep)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT")
    divider:SetPoint("BOTTOMLEFT")
    local ch = Header(chatView)
    chatIcon = ch:CreateTexture(nil, "ARTWORK")
    chatIcon:SetSize(30, 30)
    chatIcon:SetPoint("LEFT", 10, 0)
    -- no mask here either (SetTexCoord is used on it)
    local minC = TextButton(ch, "_", function() ns:Minimize() end, L.TIP_MIN)
    minC:SetPoint("RIGHT", -6, 0)
    local cfgC = TextButton(ch, "...", function() ns:OpenOptions() end, L.TIP_OPTIONS)
    cfgC:SetPoint("RIGHT", minC, "LEFT", -2, 0)
    chatTitle = Font(ch, "GameFontHighlight", COL.text)
    chatTitle:SetPoint("TOPLEFT", chatIcon, "TOPRIGHT", 8, -1)
    chatTitle:SetPoint("RIGHT", cfgC, "LEFT", -4, 0)
    chatTitle:SetWordWrap(false)
    chatSub = Font(ch, "GameFontHighlightSmall", COL.sub)
    chatSub:SetPoint("BOTTOMLEFT", chatIcon, "BOTTOMRIGHT", 8, 1)
    chatSub:SetPoint("RIGHT", cfgC, "LEFT", -4, 0)
    chatSub:SetWordWrap(false)
    chatScroll, chatContent = Scroller(chatView, function() Safe(ns.More, ns) end)
    chatScroll:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -2)
    chatScroll:SetPoint("BOTTOMRIGHT")

    -- Shown while the game hides messages from addons.
    banner = CreateFrame("Frame", nil, phone)
    banner:SetPoint("TOPLEFT", status, "BOTTOMLEFT")
    banner:SetPoint("TOPRIGHT", status, "BOTTOMRIGHT")
    banner:SetHeight(44)
    banner:SetFrameLevel(phone:GetFrameLevel() + 20)
    Tex(banner, "BACKGROUND", COL.warn, 0.95):SetAllPoints()
    local bt = Font(banner, "GameFontHighlightSmall", COL.text)
    bt:SetPoint("TOPLEFT", 8, -4)
    bt:SetPoint("BOTTOMRIGHT", -8, 4)
    bt:SetText(L.BLOCKED)
    banner:Hide()

    errorBox = CreateFrame("Button", nil, phone)
    errorBox:SetPoint("TOPLEFT", phone, "TOPLEFT", 6, -STATUS_H - 6)
    errorBox:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT", -6, INPUT_H + 14)
    errorBox:SetFrameLevel(phone:GetFrameLevel() + 40)
    Tex(errorBox, "BACKGROUND", { 0.1, 0, 0 }, 0.95):SetAllPoints()
    errorBox.text = Font(errorBox, "GameFontHighlightSmall", COL.text)
    errorBox.text:SetPoint("TOPLEFT", 8, -8)
    errorBox.text:SetPoint("BOTTOMRIGHT", -8, 8)
    errorBox.text:SetJustifyV("TOP")
    errorBox:SetScript("OnClick", function(self) self:Hide() end)
    errorBox:Hide()

    grip = CreateFrame("Button", nil, phone)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() phone:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        phone:StopMovingOrSizing()
        settings.w, settings.h = math.floor(Num(phone:GetWidth(), settings.w)), math.floor(Num(phone:GetHeight(), settings.h))
        SavePoint()
        ns:Refresh()
    end)
    phone:SetScript("OnSizeChanged", function() Later() end)
    phone:SetScript("OnShow", function() Later() end)

    -- Typing (Enter) while minimized / hidden opens the phone.
    local e = EditBox()
    if e and e.HookScript then
        e:HookScript("OnShow", function()
            if not ns.docked then return end
            if not phone:IsShown() then phone:Show() end
            if settings.min then ns:Minimize(false) end
        end)
    end
    if hooksecurefunc and FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() if ns.replacing then ParkAll() end end)
    end
end

---------------------------------------------------------------------------
-- /ph probe
---------------------------------------------------------------------------
ns.PROBE = {
    "ChatFrame1", "ChatFrame1.editBox", "ChatFrame1EditBox", "GeneralDockManager", "NUM_CHAT_WINDOWS",
    "ChatFrame_OpenChat", "ChatFrameUtil.OpenChat", "ChatEdit_UpdateHeader", "ChatFrameUtil.UpdateHeader",
    "ChatEdit_ActivateChat", "FCF_OpenTemporaryWindow", "SendChatMessage", "C_ChatInfo.SendChatMessage",
    "Ambiguate", "GetPlayerInfoByGUID", "C_ClassColor.GetClassColor", "CLASS_ICON_TCOORDS",
    "C_BattleNet.GetAccountInfoByID", "GetChannelList", "GetChannelName", "JoinChannelByName", "EnumerateServerChannels", "IsInGroup", "IsInRaid", "IsInGuild", "MenuUtil.CreateContextMenu", "SetItemRef", "issecretvalue", "hooksecurefunc",
}

local function Lookup(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

function ns:Probe()
    local ok, missing = {}, {}
    for _, p in ipairs(ns.PROBE) do
        if Lookup(p) ~= nil then ok[#ok + 1] = p else missing[#missing + 1] = p end
    end
    local f = CreateFrame("Frame")
    for _, ev in ipairs(Route.EVENTS) do
        local valid
        if C_EventUtils and C_EventUtils.IsEventValid then valid = C_EventUtils.IsEventValid(ev)
        else valid = pcall(f.RegisterEvent, f, ev) end
        if not valid then missing[#missing + 1] = ev end
    end
    f:UnregisterAllEvents()
    settings.lastProbe = { t = time(), ok = table.concat(ok, ", "), missing = table.concat(missing, ", "),
        events = #Route.EVENTS, replacing = ns.replacing, docked = ns.docked }
    return ok, missing
end

---------------------------------------------------------------------------
-- Events / slash
---------------------------------------------------------------------------
local chat = CreateFrame("Frame")
chat:SetScript("OnEvent", function(_, event, ...)
    local r, why = Route:Classify(event, ...)
    if not r then
        if why == "secret" then ns:Blocked(event) end
        return
    end
    if (r.kind == "system" and not settings.showSystem) or (r.kind == "npc" and not settings.showNPC) then return end
    Safe(Store.Add, Store, r, ns:IsOpen(r.key))
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        Store:Init()
        settings = Store:Settings()
        ns.settings = settings
        ns:ApplyLocale(settings.locale)
        Build()
        Place()
        StaticPopupDialogs = StaticPopupDialogs or {}
        StaticPopupDialogs.MILKSHAKSON_PHONE_CLEAR = {
            text = "%s", button1 = YES or "Yes", button2 = NO or "No",
            timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
            OnAccept = function() openKey = nil; Store:Clear(); ns:Layout(); print(PREFIX .. L.CLEARED) end,
        }
        Store:OnChange(function() Later() end) -- many messages per second become one redraw
        for _, e in ipairs(Route.EVENTS) do pcall(chat.RegisterEvent, chat, e) end
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA",
            "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ENCOUNTER_END",
            "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE", "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" }) do
            pcall(self.RegisterEvent, self, e)
        end
        ns:BuildOptions(settings)
        if settings.replaceChat or settings.shown ~= false then phone:Show() else phone:Hide() end
        local first = settings.lastOpen or "guild"
        if Store:Get(first) or first == "guild" and IsInGuild and IsInGuild() then openKey = first end
        ns:Layout()
        ns:Refresh()
        if openKey then ns:Open(openKey) end
        UpdateStatus()
        if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(10, UpdateStatus) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.blocked = false
        banner:Hide()
        if settings.replaceChat then ApplyReplace(true) end
        UpdateStatus()
        Later()
        -- the game joins its own channels a moment after loading: join what is missing after that
        if C_Timer and C_Timer.After then
            C_Timer.After(4, function() ns:AutoJoin(); Later() end)
        else
            ns:AutoJoin()
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_END" or event == "ZONE_CHANGED_NEW_AREA" then
        ns:Unblock()
        UpdateStatus()
        if event == "ZONE_CHANGED_NEW_AREA" then
            if C_Timer and C_Timer.After then C_Timer.After(3, function() ns:AutoJoin(); Later() end) else ns:AutoJoin() end
            Later()
        end
    elseif event == "CHANNEL_UI_UPDATE" or event == "CHAT_MSG_CHANNEL_NOTICE" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        Later()
    else
        UpdateStatus()
    end
end
ev:SetScript("OnEvent", function(self, event, ...) Safe(OnEvent, self, event, ...) end)

SLASH_MILKSHAKSONPHONE1 = "/phone"
SLASH_MILKSHAKSONPHONE2 = "/mphone"
SLASH_MILKSHAKSONPHONE3 = "/ph"
SLASH_MILKSHAKSONPHONE4 = "/mph"
SlashCmdList.MILKSHAKSONPHONE = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "" or msg == "show" then
        ns:Toggle()
    elseif msg == "config" or msg == "options" then
        ns:OpenOptions()
    elseif msg == "chat on" or msg == "chat off" or msg == "chat" then
        local on = msg == "chat on" or (msg == "chat" and not settings.replaceChat)
        ns:SetReplace(on)
        print(PREFIX .. (on and L.CHAT_ON or L.CHAT_OFF))
    elseif msg == "reset" then
        settings.point, settings.w, settings.h, settings.min = nil, Store.DEFAULTS.w, Store.DEFAULTS.h, false
        Place()
        ns:Layout()
        print(PREFIX .. L.RESET)
    elseif msg == "clear" then
        if StaticPopup_Show then StaticPopup_Show("MILKSHAKSON_PHONE_CLEAR", L.POPUP_CLEAR) end
    elseif msg == "status" then
        local convs, msgs = Store:Counts()
        print(PREFIX .. L.STATUS:format(convs, msgs, Store:Unread(), ns.replacing and L.ON or L.OFF))
    elseif msg == "probe" then
        local ok, missing = ns:Probe()
        print(PREFIX .. L.PROBE_OK:format(#ok, table.concat(ok, ", ")))
        print(PREFIX .. L.PROBE_MISSING:format(#missing, #missing > 0 and table.concat(missing, ", ") or "-"))
        local j = settings.lastJoin
        if j then print(PREFIX .. L.PROBE_JOIN:format(j.tried, j.joined ~= "" and j.joined or "-")) end
        local s = settings.secret
        if s then
            print(PREFIX .. L.PROBE_SECRET:format(s.n, s.ev or "?", date("%d/%m %H:%M", s.t or 0),
                s.combat and L.ON or L.OFF, tostring(s.instance or "-")))
        else
            print(PREFIX .. L.PROBE_NOSECRET)
        end
    elseif msg:match("^lang") then
        local arg = strtrim(msg:sub(5))
        local available = table.concat(ns:AvailableLocales(), ", ")
        if arg == "" or arg == "auto" then
            settings.locale = nil
            local code = ns:ApplyLocale(nil)
            print(PREFIX .. L.LANG_AUTO:format(ns.Locales[code]._name, code))
        else
            local code
            for c in pairs(ns.Locales) do if c:lower() == arg then code = c end end
            if code then
                settings.locale = code
                ns:ApplyLocale(code)
                print(PREFIX .. L.LANG_SET:format(ns.Locales[code]._name, code))
            else
                print(PREFIX .. L.LANG_UNKNOWN:format(arg, available))
            end
        end
        emptyText:SetText(L.EMPTY)
        ns:Layout()
        ns:Refresh()
    else
        print(PREFIX .. L.HELP1)
        print(PREFIX .. L.HELP2)
        print(PREFIX .. L.HELP3:format(table.concat(ns:AvailableLocales(), ", ")))
    end
end

function MilkshaksonPhone_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns:OpenOptions() else ns:Toggle() end
end
