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
    instance = "Interface\\Icons\\INV_Misc_Key_03", ["local"] = "Interface\\Icons\\INV_Misc_GroupNeedMore",
    channel = "Interface\\Icons\\INV_Letter_15", system = "Interface\\Icons\\INV_Misc_Gear_01",
    npc = "Interface\\Icons\\Ability_Hunter_BeastCall",
}
-- Channel icons by name (any client language): business, defense, zone map.
local CHANNEL_ICON = {
    { "Interface\\Icons\\INV_Misc_Coin_01", { "trade", "comércio", "comercio", "handel", "commerce" } },
    { "Interface\\Icons\\INV_Sword_04", { "defense", "defesa", "defensa", "verteidigung", "défense" } },
    { "Interface\\Icons\\INV_Misc_Map_01", { "general", "geral", "allgemein", "général" } },
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
local listView, listTitle, listScroll, listContent, emptyText, listHead
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

-- Information on the phone (same box, not an error).
local function Notice(title, text)
    if errorBox then
        errorBox.text:SetText("|cff25d366" .. title .. "|r\n\n" .. text .. "\n\n|cff888888(click to close)|r")
        errorBox:Show()
    end
end
ns.Notice = Notice

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

-- Every text of the phone, with its template size, so the font size option
-- (settings.fontScale) can be applied to all of them at once.
local fonts = {}
local function FontScale() return tonumber(settings and settings.fontScale) or 1 end

local function ScaleFont(f)
    local path, size, flags = f:GetFont()
    if type(size) ~= "number" or not path then return end
    f.baseSize = rawget(f, "baseSize") or size
    f:SetFont(path, f.baseSize * FontScale(), flags or "")
end

local function Font(parent, template, c, justify)
    local f = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if c then f:SetTextColor(c[1], c[2], c[3]) end
    f:SetJustifyH(justify or "LEFT")
    fonts[#fonts + 1] = f
    if FontScale() ~= 1 then ScaleFont(f) end
    return f
end

local function RowH() return math.floor(ROW_H * math.max(1, FontScale()) + 0.5) end
ns.Fonts, ns.RowH = fonts, RowH

local function ClassColor(cls)
    if not cls then return nil end
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
end

-- Color of a chat's name (list and header): class color for a player, the
-- chat type's color for groups and channels (guild green, party blue...).
local KIND_EV = { guild = "GUILD", officer = "OFFICER", party = "PARTY", raid = "RAID",
    instance = "INSTANCE_CHAT", bn = "BN_WHISPER" }
local function NameColor(c)
    if c.kind == "whisper" then
        return ClassColor(c.cls) or (settings.typeColors and TypeColor({ ev = "WHISPER" }, c)) or COL.text
    end
    if not settings.typeColors then return COL.text end
    if c.kind == "channel" then return TypeColor({ ev = "CHANNEL" }, c) or COL.text end
    local ev = KIND_EV[c.kind]
    return ev and TypeColor({ ev = ev }, c) or COL.text
end
ns.NameColor = NameColor

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

-- Collapse / expand button (the game's -/+ buttons, as in ReadyQuests).
local minButtons = {}
local function MinButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    b:SetScript("OnClick", function() ns:Minimize() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TIP_MIN)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    minButtons[#minButtons + 1] = b
    return b
end

-- "-" while open, "+" while minimized.
local function UpdateMinButtons(min)
    local tex = min and "Interface\\Buttons\\UI-PlusButton-" or "Interface\\Buttons\\UI-MinusButton-"
    for _, b in ipairs(minButtons) do
        b:SetNormalTexture(tex .. "Up")
        b:SetPushedTexture(tex .. "Down")
    end
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

-- Where the docked typing box sits: on the input bar, or (minimized) below the
-- phone, outside its clipped area, so it covers neither the pills nor the + button.
function ns:PlaceEditBox(min)
    local e = ns.docked and EditBox()
    if not e then return end
    e:ClearAllPoints()
    if min == "header" then -- typing while minimized: over the header, the phone stays small
        e:SetPoint("TOPLEFT", phone, "TOPLEFT", 4, -STATUS_H - 4)
        e:SetPoint("BOTTOMRIGHT", phone, "TOPRIGHT", -4, -STATUS_H - HEAD_H + 4)
    elseif min then
        e:SetPoint("TOPLEFT", phone, "BOTTOMLEFT", 0, -40)
        e:SetPoint("TOPRIGHT", phone, "BOTTOMRIGHT", 0, -40)
    else
        e:SetPoint("TOPLEFT", inputBar, "TOPLEFT", -2, 2)
        e:SetPoint("BOTTOMRIGHT", inputBar, "BOTTOMRIGHT", 2, -2)
    end
end

-- Typing box for the current state: on the bar (open), over the header (minimized
-- and typing), or out of the way (minimized, not typing).
function ns:SyncEditBox(min)
    local e = ns.docked and EditBox()
    if not e then return end
    if min == nil then min = settings.min and not ns.peek end
    local typing = e.HasFocus and e:HasFocus()
    if not min then
        ns:PlaceEditBox(false)
    elseif typing then
        ns:PlaceEditBox("header")
    else
        ns:PlaceEditBox(true)
    end
    local hide = min and not typing
    e:SetAlpha(hide and 0 or 1)
    if e.EnableMouse then e:EnableMouse(not hide) end
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
        ns.docked = true
        ns:PlaceEditBox(false)
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
    -- npc: older separate NPC chat (NPCs now go to System); system: listed apart, at the end
    return { system = true, npc = true }
end

-- System (+ NPCs): quiet unless monitored — no badge, no last message.
local function Quiet(c) return c and c.kind == "system" and not settings.monitorSystem end
ns.Quiet = Quiet
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

-- Channels used by other addons only to send data (no chat): hidden.
local ADDON_CHANNELS = { harvestmate = true, harvestmateb = true, harvestmatec = true }
function ns:ChannelHidden(name)
    local n = (name or ""):lower()
    return ADDON_CHANNELS[n] or (settings.hiddenChannels and settings.hiddenChannels[n]) or false
end

-- Channels the character is in (GetChannelList: id, name, disabled, ...),
-- then channel conversations with messages that are not joined now.
local function Channels()
    local t, seen = {}, {}
    local function add(id, name)
        if type(name) ~= "string" or name == "" or (tonumber(id) or 0) <= 0 then return end
        name = name:match("^(.-) %- ") or name
        if ns:ChannelHidden(name) then return end
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
        if c.kind == "channel" and not seen[c.key] and #c.msgs > 0 and not ns:ChannelHidden(c.name) then rest[#rest + 1] = { conv = c } end
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
    -- never touch channels in combat (the game may block the addon); retry after
    if InCombatLockdown and InCombatLockdown() then ns.joinAfterCombat = true return end
    ns.joinAfterCombat = nil
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
            if c.kind == "whisper" and c.target then
                for _, a in ipairs(ns.ACTIONS) do
                    if a[1] ~= "WHISPER" and (not a[3] or a[3]()) then
                        root:CreateButton(L["ACT_" .. a[1]], function() Safe(a[2], c.target) end)
                    end
                end
                root:CreateDivider()
            end
            root:CreateButton(c.pinned and L.UNPIN or L.PIN, function() Store:SetPinned(c.key, not c.pinned) end)
            root:CreateButton(c.muted and L.UNMUTE or L.MUTE, function() Store:SetMuted(c.key, not c.muted) end)
            if c.kind == "channel" then
                root:CreateButton(L.HIDE_CHANNEL, function()
                    settings.hiddenChannels = settings.hiddenChannels or {}
                    settings.hiddenChannels[(c.name or ""):lower()] = true
                    if openKey == c.key then ns:CloseChat() end
                    ns:Refresh()
                end)
            end
            root:CreateButton(L.CLEAR_CONV, function() Store:ClearConv(c.key) end)
            root:CreateButton(L.DELETE_CONV, function() Safe(ns.DeleteConv, ns, c.key) end)
        end)
    else
        Store:SetMuted(c.key, not c.muted)
    end
end

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, listContent)
    r:SetHeight(RowH())
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
    local list = {}
    for _, c in ipairs(Store:List(TopKeys(), HiddenKinds())) do
        if not (c.kind == "channel" and ns:ChannelHidden(c.name)) then list[#list + 1] = c end
    end
    if settings.showSystem or settings.showNPC then -- always last
        list[#list + 1] = Store:Ensure("system", "system")
    end
    for i, c in ipairs(list) do
        local r = Row(i)
        r.conv = c
        r:ClearAllPoints()
        r:SetHeight(RowH())
        r:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * RowH())
        r:SetPoint("RIGHT", listContent, "RIGHT")
        SetIcon(r.icon, c)
        r.name:SetText(Title(c))
        local cc = NameColor(c)
        r.name:SetTextColor(cc[1], cc[2], cc[3])
        local m = c.msgs[#c.msgs]
        local quiet = Quiet(c)
        if quiet then m = nil end
        r.time:SetText(m and ListTime(m.t) or "")
        r.prev:SetText(m and Preview(c, m) or (quiet and L.QUIET or L.NO_MSGS))
        local pc = TypeColor(m, c) or COL.sub
        r.prev:SetTextColor(pc[1], pc[2], pc[3])
        local n = quiet and 0 or (c.muted and (c.unseen or 0) or (c.unread or 0))
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
    listContent:SetHeight(math.max(1, #list * RowH()))
    emptyText:SetShown(#list == 0)
    return #list
end

---------------------------------------------------------------------------
-- Conversation view
---------------------------------------------------------------------------
-- Sender name as the game's player link: |Hplayer:Name-Realm:lineID|h Name |h
local function PlayerLink(m)
    if m.out or not m.from or m.npc then return m.from or "" end
    return "|Hplayer:" .. (m.full or m.from) .. (m.line and (":" .. m.line) or "") .. "|h" .. m.from .. "|h"
end
ns.PlayerLink = PlayerLink

-- Opens (or creates) the private chat with a player and starts typing to them.
function ns:Whisper(full)
    if not full or full == "" then return end
    local short = full:gsub("%-.*$", "")
    if Ambiguate then short = Ambiguate(full, "short") end
    local c = Store:Ensure("w:" .. full:lower(), "whisper", short)
    c.target = full
    ns:Open(c.key)
    ns:Compose()
end

-- The game's own player menu (report, etc.). Tries the menu API of this client,
-- then the older ones; settings.lastMenu says which one ran.
local function GameMenu(full, line, chatType)
    local name, server = full:match("^([^%-]+)%-?(.*)$")
    local used
    if UnitPopup_OpenMenu then
        local ok = pcall(UnitPopup_OpenMenu, "FRIEND", { name = name, server = server ~= "" and server or nil,
            lineID = line, chatType = chatType or "WHISPER", chatFrame = ChatFrame1 })
        if ok then used = "UnitPopup_OpenMenu" end
    end
    if not used and FriendsFrame_ShowDropdown then
        if pcall(FriendsFrame_ShowDropdown, full, 1, line, chatType, ChatFrame1) then used = "FriendsFrame_ShowDropdown" end
    end
    if not used and SetItemRef then
        if pcall(SetItemRef, "player:" .. full .. (line and (":" .. line) or ""), name, "RightButton", ChatFrame1) then used = "SetItemRef" end
    end
    settings.lastMenu = used or "none"
end
ns.GameMenu = GameMenu

-- Calls a game function; a failure is shown on the phone (never silent).
local function Call(f, ...)
    if type(f) ~= "function" then ShowError("function not available in this client") return end
    local ok, err = pcall(f, ...)
    if not ok then ShowError(err) end
end

-- /who on a player: the answer is shown on the phone (System may be off and
-- the game's chat hidden). Results come by WHO_LIST_UPDATE (to the Who list)
-- or as a system line; both are watched for a few seconds.
local whoWait
function ns:Who(full)
    whoWait = { name = (full:gsub("%-.*$", "")):lower(), t = GetTime() }
    local FL = C_FriendList
    if FL and FL.SetWhoToUi then pcall(FL.SetWhoToUi, true) end
    local q = 'n-"' .. full:gsub("%-.*$", "") .. '"'
    if FL and FL.SendWho then
        local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Chat
        Call(FL.SendWho, q, origin)
    else
        Call(SendWho, q)
    end
end

function ns:WhoResult()
    if not whoWait or GetTime() - whoWait.t > 10 then return end
    local FL = C_FriendList
    if not (FL and FL.GetNumWhoResults and FL.GetWhoInfo) then return end
    local n = FL.GetNumWhoResults() or 0
    local lines = {}
    for i = 1, n do
        local w = FL.GetWhoInfo(i)
        if type(w) == "table" and w.fullName then
            lines[#lines + 1] = L.WHO_LINE:format(w.fullName, w.level or 0, w.raceStr or "", w.classStr or "",
                w.area or "", (w.fullGuildName and w.fullGuildName ~= "") and ("<" .. w.fullGuildName .. ">") or "")
        end
    end
    whoWait = nil
    Notice(L.ACT_WHO, #lines > 0 and table.concat(lines, "\n") or L.WHO_NONE)
end

-- The system line of a /who sent to the chat ("Name: Level 20 ..."), if any.
function ns:WhoSystem(text)
    if not whoWait or GetTime() - whoWait.t > 10 or type(text) ~= "string" then return end
    if text:lower():find(whoWait.name, 1, true) then
        whoWait = nil
        Notice(L.ACT_WHO, text)
    end
end

ns.ACTIONS = {
    { "WHISPER", function(n) ns:Whisper(n) end },
    { "INVITE", function(n) Call((C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit, n) end },
    { "GUILD_INVITE", function(n) Call((C_GuildInfo and C_GuildInfo.Invite) or GuildInvite, n) end,
        function() return IsInGuild and IsInGuild() and (not CanGuildInvite or CanGuildInvite()) end },
    { "ADD_FRIEND", function(n) Call((C_FriendList and C_FriendList.AddFriend) or AddFriend, n) end },
    { "WHO", function(n) ns:Who(n) end },
    { "COPY_NAME", function(n) if MilkshaksonUI then MilkshaksonUI:CopyLink(n, n) end end },
    { "IGNORE", function(n) Call((C_FriendList and C_FriendList.AddIgnore) or AddIgnore, n) end },
}

-- Right-click on a player (bubble, name or private chat): the actions of the
-- game's chat menu, plus the game's own menu at the end.
function ns:PlayerMenu(owner, full, line, chatType)
    if not full or full == "" then return end
    local short = (Ambiguate and Ambiguate(full, "short")) or full:gsub("%-.*$", "")
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        GameMenu(full, line, chatType)
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(short)
        for _, a in ipairs(ns.ACTIONS) do
            if not a[3] or a[3]() then
                root:CreateButton(L["ACT_" .. a[1]], function() Safe(a[2], full) end)
            end
        end
        root:CreateButton(L.ACT_MORE, function() Safe(GameMenu, full, line, chatType) end)
    end)
end

-- Click on a link in a bubble. Player name: left = private chat on the phone,
-- right = game's player menu, shift / ctrl = the game's own behavior (/who...).
function ns:OnLink(link, text, button)
    local kind, rest = (link or ""):match("^(%a+):(.*)$")
    if kind == "player" then
        local name, line = rest:match("^([^:]+):?(%d*)")
        local mod = (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) or (IsAltKeyDown and IsAltKeyDown())
        if button == "RightButton" then
            ns:PlayerMenu(ns.linkOwner, name, tonumber(line))
            return
        end
        if button == "LeftButton" and not mod then
            ns:Whisper(name)
            return
        end
    end
    if SetItemRef then SetItemRef(link, text, button, ChatFrame1) end
end

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
    b:EnableMouse(true)
    if b.SetHyperlinksEnabled then
        b:SetHyperlinksEnabled(true)
        b:SetScript("OnHyperlinkClick", function(self, link, text, button)
            ns.linkOwner = self
            Safe(ns.OnLink, ns, link, text, button)
        end)
    end
    -- right-click anywhere on a message from another player: player menu
    b:SetScript("OnMouseUp", function(self, button)
        local m = self.msg
        local who = m and not m.out and not m.info and not m.npc and (m.full or m.from) -- older messages have no full name
        settings.lastClick = { button = tostring(button), who = who or "-", menu = (MenuUtil and MenuUtil.CreateContextMenu) and "yes" or "no" }
        if button == "RightButton" and who then
            Safe(ns.PlayerMenu, ns, self, who, m.line, m.ev)
        end
    end)
    -- hover: shows the message is clickable
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.06)
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
            b.name:SetText(PlayerLink(m) .. (m.tag == "leader" and (" (" .. L.LEADER .. ")") or ""))
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
    b.msg = m
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
    local cc = NameColor(c)
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
-- Height transition (minimize / restore): eased, content fades in
---------------------------------------------------------------------------
local anim = CreateFrame("Frame", nil, UIParent)
anim:Hide()
local function Fade(a)
    for _, f in ipairs({ listScroll, chatView, inputBar }) do if f then f:SetAlpha(a) end end
end
local function Finish(self)
    self:Hide()
    local done = self.done
    self.done = nil
    Fade(1)
    if done then done() end
end
anim:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local p = math.min(1, self.t / self.dur)
    local e = p * p * (3 - 2 * p) -- smoothstep
    phone:SetHeight(self.from + (self.to - self.from) * e)
    if self.mode == "in" then Fade(e) elseif self.mode == "out" then Fade(1 - e) end
    if p >= 1 then Safe(Finish, self) end
end)

-- mode "in": content fades in; "out": fades out, then done() hides it.
function ns:AnimateHeight(target, mode, done)
    local cur = Num(phone:GetHeight(), target)
    local dur = tonumber(settings.animTime) or 0.25
    if not settings.animate or dur <= 0 or math.abs(cur - target) < 1 or not phone:IsShown() then
        anim:Hide()
        anim.done = nil
        phone:SetHeight(target)
        Fade(1)
        if done then done() end
        return
    end
    if anim:IsShown() and anim.to == target then return end -- already going there
    anim.from, anim.to, anim.t, anim.mode, anim.dur, anim.done = cur, target, 0, mode, dur, done
    if mode == "in" then Fade(0) end
    anim:Show()
end

---------------------------------------------------------------------------
-- Layout / refresh
---------------------------------------------------------------------------
function ns:Layout()
    if not phone then return end
    local min = settings.min and not ns.peek -- peek: minimized, opened by the mouse
    local inChat = openKey ~= nil and not min
    UpdateMinButtons(min)
    -- Minimized: the game's typing box (always shown with some chat styles) would sit
    -- over the header and take the mouse from the pills: invisible and click-through.
    ns:SyncEditBox(min)
    -- Two panes, like a desktop messenger: chats on the left, the open chat on the right.
    local function Panes(m)
        listView:ClearAllPoints()
        listView:SetPoint("TOPLEFT", phone, "TOPLEFT", 0, -STATUS_H)
        if m then
            listView:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT")
        else
            listView:SetPoint("BOTTOMLEFT", phone, "BOTTOMLEFT", 0, INPUT_H + 10)
            listView:SetWidth(LIST_W)
        end
        listView:Show()
        listScroll:SetShown(not m)
        chatView:SetShown(not m)
        inputBar:SetShown(not m)
        grip:SetShown(not m and not settings.locked)
    end
    if min then
        -- minimizing: the content fades out while the height goes down, then it is hidden
        ns:AnimateHeight(STATUS_H + HEAD_H, "out", function() Panes(true) end)
    else
        Panes(false)
        ns:AnimateHeight(settings.h, "in")
    end
    local c = Store:Get(openKey)
    if inChat and c and ChatTarget(c) then
        inputText:SetText(L.INPUT_TO:format(Title(c)))
    elseif inChat then
        inputText:SetText(L.INPUT_READONLY)
    else
        inputText:SetText(L.INPUT_NONE)
    end
end

-- Minimized: colored count pills for guild, party / raid and whispers.
local pills = {}

-- The game's own color for a chat type (whatever the text color option says).
local function GameColor(ev)
    local info = ChatTypeInfo and ChatTypeInfo[ev]
    if info and info.r then return { info.r, info.g, info.b } end
    return TYPE_COL[ev] or COL.accent
end

-- { id, label, color, count, key = chat to open } for what has unread messages.
function ns:MiniCounts()
    local convs = Store:Char().convs
    local out = {}
    local g = convs.guild
    if g and not g.muted and (g.unread or 0) > 0 then
        out[#out + 1] = { id = "guild", label = L.K_guild, ev = "GUILD", n = g.unread, key = "guild" }
    end
    local best, n, ev, label = nil, 0, "PARTY", L.K_party
    for _, k in ipairs({ "party", "raid", "instance" }) do
        local c = convs[k]
        if c and not c.muted and (c.unread or 0) > 0 then
            n = n + c.unread
            if not best or (c.last or 0) > (convs[best].last or 0) then best = k end
        end
    end
    if best == "raid" then ev, label = "RAID", L.K_raid elseif best == "instance" then ev, label = "INSTANCE_CHAT", L.K_instance end
    if n > 0 then out[#out + 1] = { id = "party", label = label, ev = ev, n = n, key = best } end
    local wn, wkey, wlast = 0, nil, -1
    for key, c in pairs(convs) do
        if (c.kind == "whisper" or c.kind == "bn") and not c.muted and (c.unread or 0) > 0 then
            wn = wn + c.unread
            if (c.last or 0) > wlast then wkey, wlast = key, c.last or 0 end
        end
    end
    if wn > 0 then out[#out + 1] = { id = "whisper", label = L.WHISPERS, ev = "WHISPER", n = wn, key = wkey } end
    return out
end

local function Pill(i)
    if pills[i] then return pills[i] end
    local b = CreateFrame("Button", nil, listHead)
    b:SetHeight(22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.text = Font(b, "GameFontHighlightSmall", { 0.05, 0.08, 0.1 }, "CENTER")
    b.text:SetPoint("CENTER")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnClick", function(self) if self.key then ns:Open(self.key) end end)
    -- mouse over a pill (option): open the phone on that chat until the mouse leaves
    b:SetScript("OnEnter", function(self)
        if self.key and settings.hoverExpand and not ns.holdPeek then Safe(ns.Peek, ns, self.key) end
    end)
    pills[i] = b
    return b
end

local function UpdatePills()
    local list = (settings.min and not ns.peek) and ns:MiniCounts() or {}
    local prev
    for i, x in ipairs(list) do
        local b = Pill(i)
        local c = GameColor(x.ev)
        b.bg:SetColorTexture(c[1], c[2], c[3], 1)
        b.text:SetText(x.label .. "  " .. (x.n > 99 and "99+" or x.n))
        b:SetWidth(Num(b.text:GetUnboundedStringWidth(), 60) + 16)
        b.key = x.key
        b:ClearAllPoints()
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT", listTitle, "RIGHT", 12, 0) end
        b:Show()
        prev = b
    end
    for i = #list + 1, #pills do pills[i]:Hide() end
    return #list
end
ns.UpdatePills = UpdatePills

local function UpdateTitle()
    local n = Store:Unread({ npc = true, system = not settings.monitorSystem or nil })
    listTitle:SetText(n > 0 and L.CHATS_N:format(n) or L.CHATS)
    UpdatePills()
end

local pending
local function DoRefresh(_, key)
    if not phone then return end
    UpdateTitle()
    if not phone:IsShown() or (settings.min and not ns.peek) then return end -- drawn when shown again
    RenderList()
    if openKey and (key == nil or key == openKey) then
        if not Store:Get(openKey) then ns:CloseChat() else RenderChat() end
    end
end

local function Later()
    if pending then return end
    pending = true
    local function run() pending = false; ns:Refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end

-- Opens the phone on a chat while it stays minimized (mouse over a pill).
function ns:Peek(key)
    if not (settings.min and not ns.peek) then return end
    ns.peek = true
    openKey = key
    Store:Read(key)
    local c = Store:Get(key)
    if c then ns:SetSticky(c) end
    ns:Layout()
    RenderChat("open")
    UpdateTitle()
    RenderList()
end

local function DoOpen(_, key)
    openKey = key
    settings.lastOpen = key
    settings.min = false
    ns.peek = false -- a click on a chat restores the phone for good
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

-- Close the open chat (right pane back to "pick a chat").
function ns:CloseChat()
    openKey = nil
    if settings.lastOpen then settings.lastOpen = nil end
    ns:Layout()
    RenderChat()
end

-- Delete a chat; if it is the open one, close it too.
function ns:DeleteConv(key)
    if openKey == key then ns:CloseChat() end
    Store:Delete(key)
    ns:Refresh()
end

-- A kind was switched off: leave its conversation if it is open.
function ns:CloseKind(kind)
    local c = Store:Get(openKey)
    if c and c.kind == kind then ns:CloseChat() end
end

-- Font size changed: every text, then everything drawn again.
function ns:ApplyFontScale()
    for _, f in ipairs(fonts) do ScaleFont(f) end
    ns:Redraw()
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
    return phone and phone:IsShown() and (not settings.min or ns.peek) and openKey == key
end

function ns:Minimize(v)
    if ns.peek then -- "_" while opened by the mouse: back to minimized
        ns.peek = false
        ns.holdPeek = true -- not again until the mouse leaves
        settings.min = true
        ns:Layout()
        UpdatePills()
        return
    end
    if v == nil then v = not settings.min end
    settings.min = v and true or false
    if v then ns.holdPeek = true end -- minimized by hand: no hover-open until the mouse leaves
    ns:Layout()
    UpdatePills()
    if not v then ns:Refresh() end
end

-- Minimized + option: the mouse over the phone opens it, leaving closes it again
-- (not while typing or with a menu open). Polled: child frames eat OnEnter/OnLeave.
local hover = CreateFrame("Frame", nil, UIParent)
local acc, outFor = 0, 0
local function MenuOpen()
    if Menu and Menu.GetManager then
        local ok, m = pcall(function() return Menu.GetManager():GetOpenMenu() end)
        return ok and m ~= nil
    end
end
function ns:HoverTick(dt)
    if not phone then return end
    ns.hoverTicks = (ns.hoverTicks or 0) + 1
    if not (settings.min and settings.hoverExpand and phone:IsShown()) then
        if ns.peek then ns.peek = false; ns:Layout() end
        return
    end
    local over
    if phone.IsMouseOver then over = phone:IsMouseOver() elseif MouseIsOver then over = MouseIsOver(phone) end
    if not over then ns.holdPeek = nil end
    if over and ns.peek and IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
        -- a click while it is open by the mouse: restored for good
        ns.peek = false
        settings.min = false
        ns:Layout()
        ns:Refresh()
        return
    end
    if over then
        outFor = 0 -- (opening is done by the pills: mouse over a pill)
    elseif ns.peek then
        local e = EditBox()
        if (e and e.HasFocus and e:HasFocus()) or MenuOpen() then outFor = 0 return end
        outFor = outFor + dt
        if outFor >= 0.5 then
            outFor = 0
            ns.peek = false
            ns:Layout()
            UpdateTitle()
        end
    end
end
hover:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    local dt = acc
    acc = 0
    Safe(ns.HoverTick, ns, dt)
end)

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
-- onClick: a left click that was not a drag.
local function Drag(f, onClick)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        self.dragged = true
        if not settings.locked then phone:StartMoving() end
    end)
    f:SetScript("OnDragStop", function() phone:StopMovingOrSizing(); SavePoint() end)
    if onClick then
        f:SetScript("OnMouseDown", function(self) self.dragged = false end)
        f:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and not self.dragged then Safe(onClick) end
            self.dragged = false
        end)
    end
end

local function Header(parent, onClick)
    local h = CreateFrame("Frame", nil, parent)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:SetHeight(HEAD_H)
    Tex(h, "BACKGROUND", COL.head):SetAllPoints()
    Drag(h, onClick)
    return h
end

local function Build()
    phone = CreateFrame("Frame", "MilkshaksonPhoneFrame", UIParent)
    phone:SetFrameStrata("LOW")
    phone:SetClampedToScreen(true)
    phone:SetMovable(true)
    phone:SetResizable(true)
    if phone.SetClipsChildren then phone:SetClipsChildren(true) end -- content stays inside while the height moves
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
    -- minimized: a click on "Chats" restores the phone
    local lh = Header(listView, function()
        if settings.min then
            ns.peek = false
            ns:Minimize(false)
        end
    end)
    listHead = lh
    listTitle = Font(lh, "GameFontNormalLarge", COL.text)
    listTitle:SetPoint("LEFT", 12, 0)
    local minB = MinButton(lh)
    minB:SetPoint("RIGHT", -10, 0)
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
    local minC = MinButton(ch)
    minC:SetPoint("RIGHT", -10, 0)
    local cfgC = TextButton(ch, "...", function() ns:OpenOptions() end, L.TIP_OPTIONS)
    cfgC:SetPoint("RIGHT", minC, "LEFT", -2, 0)
    chatTitle = Font(ch, "GameFontHighlight", COL.text)
    chatTitle:SetPoint("TOPLEFT", chatIcon, "TOPRIGHT", 8, -1)
    chatTitle:SetPoint("RIGHT", cfgC, "LEFT", -4, 0)
    chatTitle:SetWordWrap(false)
    -- Click the name of a private chat: the game's player menu.
    local who = CreateFrame("Button", nil, ch)
    who:SetPoint("TOPLEFT", chatIcon, "TOPLEFT")
    who:SetPoint("BOTTOMRIGHT", chatTitle, "BOTTOMRIGHT", 0, -16)
    who:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    who:SetScript("OnClick", function(self, button)
        local c = Store:Get(openKey)
        if c and c.kind == "whisper" and c.target then
            Safe(ns.PlayerMenu, ns, self, c.target)
        end
    end)
    who:SetScript("OnEnter", function(self)
        local c = Store:Get(openKey)
        if c and c.kind == "whisper" then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L.TIP_PLAYER)
            GameTooltip:Show()
        end
    end)
    who:SetScript("OnLeave", GameTooltip_Hide)
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
        -- Typing (Enter, "/", "r"...) never restores a minimized phone: the box shows
        -- over the header while typing and goes away after sending / Escape.
        local function Typing()
            if not ns.docked then return end
            if not phone:IsShown() then phone:Show() end
            Safe(ns.SyncEditBox, ns)
        end
        e:HookScript("OnShow", Typing)
        e:HookScript("OnEditFocusGained", Typing) -- box always shown (chat style): Enter only focuses it
        e:HookScript("OnEditFocusLost", function()
            if ns.docked and C_Timer and C_Timer.After then C_Timer.After(0, function() Safe(ns.SyncEditBox, ns) end)
            elseif ns.docked then Safe(ns.SyncEditBox, ns) end
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
    "C_BattleNet.GetAccountInfoByID", "UnitPopup_OpenMenu", "FriendsFrame_ShowDropdown", "C_FriendList.SendWho", "C_FriendList.SetWhoToUi", "C_FriendList.GetWhoInfo", "GetChannelList", "GetChannelName", "JoinChannelByName", "EnumerateServerChannels", "IsInGroup", "IsInRaid", "IsInGuild", "MenuUtil.CreateContextMenu", "SetItemRef", "issecretvalue", "hooksecurefunc", "MouseIsOver",
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
---------------------------------------------------------------------------
-- /ph test: a real whisper to yourself, with a report of what came back
---------------------------------------------------------------------------
local testLog
local TEST_EVENTS = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "CHAT_MSG_AFK", "CHAT_MSG_DND" }
local testFrame = CreateFrame("Frame")
testFrame:SetScript("OnEvent", function(_, event, a1, a2)
    if not testLog then return end
    local txt = (issecretvalue and issecretvalue(a1)) and "(secret)" or tostring(a1 or "")
    if event == "UI_ERROR_MESSAGE" then txt = tostring(a2 or a1 or "") end
    testLog[#testLog + 1] = event:gsub("^CHAT_MSG_", "") .. ": " .. txt:sub(1, 80)
end)

function ns:TestWhisper()
    local me = UnitName("player")
    local fn, name
    if C_ChatInfo and C_ChatInfo.SendChatMessage then fn, name = C_ChatInfo.SendChatMessage, "C_ChatInfo.SendChatMessage"
    elseif SendChatMessage then fn, name = SendChatMessage, "SendChatMessage" end
    testLog = {}
    for _, e in ipairs(TEST_EVENTS) do pcall(testFrame.RegisterEvent, testFrame, e) end
    local head = "to: " .. tostring(me) .. "\nfunction: " .. tostring(name)
    if not fn then Notice("/ph test", head .. "\nno send function in this client") return end
    local ok, err = pcall(fn, L.TEST_TEXT, "WHISPER", nil, me)
    head = head .. "\ncall: " .. (ok and "accepted" or ("error: " .. tostring(err)))
    local function report()
        testFrame:UnregisterAllEvents()
        local lines = testLog or {}
        testLog = nil
        settings.lastTest = head .. "\n" .. table.concat(lines, "\n")
        Notice("/ph test", head .. "\n\n" .. L.TEST_BACK .. "\n" .. (#lines > 0 and table.concat(lines, "\n") or L.TEST_NOTHING))
    end
    if C_Timer and C_Timer.After then C_Timer.After(3, report) else report() end
end

local chat = CreateFrame("Frame")
chat:SetScript("OnEvent", function(_, event, ...)
    if event == "WHO_LIST_UPDATE" then Safe(ns.WhoResult, ns) return end
    if event == "CHAT_MSG_SYSTEM" then Safe(ns.WhoSystem, ns, (...)) end
    local r, why = Route:Classify(event, ...)
    if not r then
        if why == "secret" then ns:Blocked(event) end
        return
    end
    if r.kind == "system" and not (r.msg.npc and settings.showNPC or (not r.msg.npc and settings.showSystem)) then return end
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
        Store:OnChange(function(key)
            -- many messages per second become one redraw; the quiet System chat redraws nothing while closed
            if key == "system" and key ~= openKey and Quiet(Store:Get(key)) then return end
            Later()
        end)
        for _, e in ipairs(Route.EVENTS) do pcall(chat.RegisterEvent, chat, e) end
        pcall(chat.RegisterEvent, chat, "WHO_LIST_UPDATE")
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
        if event == "PLAYER_REGEN_ENABLED" and ns.joinAfterCombat then ns:AutoJoin(); Later() end
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
    elseif msg == "test" then
        Safe(ns.TestWhisper, ns)
    elseif msg == "test fake" then
        -- a whisper that only exists on the phone (nothing is sent)
        local r = Route:Classify("CHAT_MSG_WHISPER", L.TEST_TEXT, L.TEST_FROM, "", "", L.TEST_FROM, "", 0, 0, "", 0, 0, "")
        if r then Safe(Store.Add, Store, r, ns:IsOpen(r.key)) end
    elseif msg == "show channels" then
        settings.hiddenChannels = nil
        ns:Refresh()
        print(PREFIX .. L.CHANNELS_SHOWN)
    elseif msg == "status" then
        local convs, msgs = Store:Counts()
        print(PREFIX .. L.STATUS:format(convs, msgs, Store:Unread(), ns.replacing and L.ON or L.OFF))
        local k = settings.lastClick
        local line = (k and ("last click: " .. k.button .. " on " .. k.who .. ", menu API: " .. k.menu) or "last click: none")
            .. "\ngame menu: " .. tostring(settings.lastMenu or "-")
            .. "\nhover: option " .. tostring(settings.hoverExpand) .. ", minimized " .. tostring(settings.min)
            .. ", mouse over " .. tostring(phone.IsMouseOver and phone:IsMouseOver()) .. ", ticks " .. tostring(ns.hoverTicks or 0)
        print(PREFIX .. line)
        if errorBox then errorBox.text:SetText(L.STATUS:format(convs, msgs, Store:Unread(), ns.replacing and L.ON or L.OFF) .. "\n" .. line .. "\n\n(click to close)"); errorBox:Show() end
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
