-- Combat chat: summary of your biggest hit per spell (from the combat log, when
-- the game gives it to addons) + the game's own Combat Log window embedded below.
local _, ns = ...
local L = ns.L
local C = {}
ns.Combat = C

local ROW = 30
local DAMAGE = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
    SWING_DAMAGE = true, DAMAGE_SHIELD = true, SPELL_BUILDING_DAMAGE = true }
local COL = { bg = { 0.043, 0.078, 0.098 }, head = { 0.122, 0.173, 0.2 }, text = { 0.91, 0.93, 0.94 },
    sub = { 0.53, 0.59, 0.63 }, accent = { 0.145, 0.827, 0.4 }, crit = { 1, 0.82, 0.2 }, sep = { 0.14, 0.19, 0.21 } }

local me, pet
C.status = "off" -- off / waiting / ok / blocked / secret / no-api

local function Num(v, d) return type(v) == "number" and v or d end
local function Short(n)
    n = math.floor(n + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

function C:Data()
    local c = ns.Store:Char()
    c.dmg = c.dmg or {}
    return c.dmg
end

-- Sorted list of { name, id, max, crit, target, hits, pet }: the biggest hit per spell.
function C:List()
    local t = {}
    for _, d in pairs(self:Data()) do t[#t + 1] = d end
    table.sort(t, function(a, b) if a.max ~= b.max then return a.max > b.max end return (a.name or "") < (b.name or "") end)
    return t
end

function C:Reset()
    wipe(self:Data())
    self:Render()
    if ns.Refresh then ns:Refresh() end
end

-- One line for the chats list.
function C:Preview()
    local top = self:List()[1]
    if top then return L.CL_PREVIEW:format(top.name or "?", Short(top.max)) end
    return L.CL_NONE
end

---------------------------------------------------------------------------
-- Capture
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local redraw

local function Changed()
    if redraw then return end
    redraw = true
    local function go() redraw = false; if C.view and C.view:IsShown() then C:Render() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, go) else go() end
end

function C:OnCLEU()
    local ok, _, sub, _, src, _, _, _, _, dstName, _, _, p12, p13, _, p15, _, _, p18, _, _, p21 =
        pcall(CombatLogGetCurrentEventInfo)
    if not ok then
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        C:StartLog()
        return
    end
    if issecretvalue and (issecretvalue(sub) or issecretvalue(src)) then C.status = "secret" return end
    if C.status ~= "ok" then C.status = "ok" end
    if not DAMAGE[sub] then return end
    me = me or (UnitGUID and UnitGUID("player"))
    if src ~= me and (not pet or src ~= pet) then return end
    local id, name, amount, crit
    if sub == "SWING_DAMAGE" then
        id, name, amount, crit = 0, L.MELEE, p12, p18
    else
        id, name, amount, crit = p12, p13, p15, p21
    end
    if issecretvalue and issecretvalue(amount) then C.status = "secret" return end
    C:Record(id, name, amount, crit, dstName, pet ~= nil and src == pet)
end

-- One hit of mine (or my pet's): keeps the biggest per spell.
function C:Record(id, name, amount, crit, dstName, isPet)
    if type(amount) ~= "number" or amount <= 0 or not name then return end
    local key = (isPet and "pet:" or "") .. tostring((id and id ~= 0) and id or name)
    local data = C:Data()
    local d = data[key]
    if not d then
        d = { id = id, name = name, max = 0, hits = 0, total = 0, pet = isPet or nil }
        data[key] = d
    end
    d.hits = d.hits + 1
    d.total = d.total + amount
    if amount > d.max then
        d.max, d.crit, d.target, d.t = amount, crit and true or nil, dstName, time()
    end
    Changed()
end

frame:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if ns.Safe then ns.Safe(C.OnCLEU, C) else C:OnCLEU() end
    elseif event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" then
        pet = UnitGUID and UnitGUID("pet")
        me = UnitGUID and UnitGUID("player")
    end
end)

-- The game may refuse the combat log to addons (Midnight-based clients): then
-- the summary says so; the game's own Combat Log window still works below.
function C:Start()
    pcall(frame.RegisterEvent, frame, "UNIT_PET")
    pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
    me = UnitGUID and UnitGUID("player")
    pet = UnitGUID and UnitGUID("pet")
    if ns.settings and ns.settings.clMode == "log" then C:StartLog() return end -- learned: no CLEU here
    if not CombatLogGetCurrentEventInfo then C:StartLog() return end
    local ok = pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")
    if not ok then C:StartLog() return end
    C.status = "waiting"
end

---------------------------------------------------------------------------
-- Without the combat log API: read the lines of the game's Combat Log window
-- (ChatFrame2). Its lines carry links: |Hunit:GUID:...|h name |h (who),
-- |Hspell:ID...|h name |h (what), |Haction:EVENT...|h word |h (what happened).
---------------------------------------------------------------------------
local LOG_DAMAGE = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
    SWING_DAMAGE = true, DAMAGE_SHIELD = true, SPELL_BUILDING_DAMAGE = true }

local function G(name) local v = _G[name]; return type(v) == "string" and v ~= "" and v or nil end

-- "Your" / "You" at the start of a line (client language), when units are not links.
local function StartsWithMe(plain)
    for _, k in ipairs({ "UNIT_YOU_SOURCE_POSSESSIVE", "UNIT_YOU_SOURCE", "UNIT_YOU" }) do
        local w = G(k)
        if w and plain:sub(1, #w) == w then return true end
    end
    return plain:sub(1, 5) == "Your " or plain:sub(1, 4) == "You "
end

local function IsCrit(raw, plain)
    for _, k in ipairs({ "TEXT_MODE_A_STRING_RESULT_CRITICAL", "TEXT_MODE_A_STRING_RESULT_CRITICAL_SPELL",
        "ACTION_SPELL_DAMAGE_CRITICAL", "ACTION_SWING_DAMAGE_CRITICAL", "ACTION_RANGE_DAMAGE_CRITICAL" }) do
        local w = G(k)
        if w and not w:find("%%") and plain:find(w, 1, true) then return true end
    end
    return plain:find(" crit ", 1, true) ~= nil or plain:find("(Critical)", 1, true) ~= nil
end

-- Lines without links: "Your Frostbolt hit Grunt 223 Frost." / "You crit Grunt 45."
local function ActionWords()
    local t = {}
    for _, k in ipairs({ "ACTION_SPELL_DAMAGE", "ACTION_SWING_DAMAGE", "ACTION_RANGE_DAMAGE",
        "ACTION_SPELL_PERIODIC_DAMAGE", "ACTION_SPELL_DAMAGE_CRITICAL", "ACTION_SWING_DAMAGE_CRITICAL" }) do
        local w = G(k)
        if w and not w:find("%%") then t[#t + 1] = w end
    end
    for _, w in ipairs({ "hit", "hits", "crit", "crits" }) do t[#t + 1] = w end
    return t
end

function C:ParsePlain(text)
    local poss = G("UNIT_YOU_SOURCE_POSSESSIVE") or "Your"
    local you = G("UNIT_YOU_SOURCE") or "You"
    local best, bestW
    for _, w in ipairs(ActionWords()) do
        local p = text:find(" " .. w .. " ", 1, true)
        if p and (not best or p < best) then best, bestW = p, w end
    end
    if not best then return nil end
    local before, after = text:sub(1, best - 1), text:sub(best + #bestW + 2)
    local name
    if before:sub(1, #poss + 1) == poss .. " " then
        name = before:sub(#poss + 2)
    elseif before == you then
        name = L.MELEE
    else
        return nil
    end
    local target, num = after:match("^(.-) (%d[%d,%.]*)")
    if not num then return nil end
    local amount = tonumber((num:gsub("[^%d]", "")))
    if not amount then return nil end
    local crit = bestW:find("crit", 1, true) ~= nil or IsCrit(text, text)
    return { id = 0, name = name, amount = amount, crit = crit, target = target, pet = false }
end

-- Returns { id, name, amount, crit, target, pet } for a damage line of mine, or nil.
function C:ParseLine(raw)
    if type(raw) ~= "string" then return nil end
    me = me or (UnitGUID and UnitGUID("player"))
    -- who: the first unit link; target: the second
    local units = {}
    for guid, name in raw:gmatch("|Hunit:([^:|]+)[^|]*|h(.-)|h") do units[#units + 1] = { guid = guid, name = name } end
    local action = raw:match("|Haction:([%u_]+)")
    local spellId, spellName = raw:match("|Hspell:(%d+)[^|]*|h(.-)|h")
    local function Clean(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("^%[", ""):gsub("%]$", "")) end
    if spellName then spellName = Clean(spellName) end
    for _, u in ipairs(units) do u.name = Clean(u.name) end
    -- plain text: links -> their text (except units and spells, whose names may have digits), no colors / icons
    local plain = raw:gsub("|Hunit:.-|h.-|h", ""):gsub("|Hspell:.-|h.-|h", "")
    plain = plain:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    local isPet = false
    if units[1] then
        if units[1].guid == me then
        elseif pet and units[1].guid == pet then isPet = true
        else return nil end
    else
        local text = raw:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        if not StartsWithMe(text) then return nil end
        if not spellId and not action then return C:ParsePlain(text) end -- no links at all
    end
    if action and not LOG_DAMAGE[action] then return nil end
    local isSwing = action == "SWING_DAMAGE" or (not spellId and not action)
    if not spellId and not isSwing then return nil end
    -- the amount: first number left once names are out ("... hit Grunt 223 Frost. (63 Overkill)")
    local num = plain:match("(%d[%d,%. ]*%d)") or plain:match("(%d+)")
    if not num then return nil end
    local amount = tonumber((num:gsub("[^%d]", "")))
    if not amount then return nil end
    if not action then
        -- no action link: only lines that read like a hit (not heals / energize)
        local heal = G("ACTION_SPELL_HEAL")
        if heal and plain:find(" " .. heal .. " ", 1, true) then return nil end
        if plain:find(" heal", 1, true) or plain:find(" gain", 1, true) then return nil end
    end
    local target = units[2] and units[2].name
    if not target and spellName then target = nil end
    return { id = tonumber(spellId) or 0, name = spellName or L.MELEE, amount = amount, crit = IsCrit(raw, plain),
        target = target, pet = isPet }
end

-- A line of the game's Combat Log window: count it, read it, keep a few samples.
local function TakeLine(text)
        C.seen = (C.seen or 0) + 1
        if issecretvalue and issecretvalue(text) then C.status = "secret"; C.lastRaw = "(secret)"; Changed() return end
        C.lastRaw = tostring(text)
        local ok, h = pcall(C.ParseLine, C, text)
        local st = ns.settings
        if st then -- a few raw lines, to adjust the reader if needed (/ph combat sample)
            st.clSamples = st.clSamples or {}
            if (ok and h) or #st.clSamples < 3 then
                table.insert(st.clSamples, 1, (tostring(text):gsub("|", "||")))
                while #st.clSamples > 8 do table.remove(st.clSamples) end
            end
        end
        if ok and h then
            C.matched = (C.matched or 0) + 1
            if C.status ~= "log" then C.status = "log" end
            C:Record(h.id, h.name, h.amount, h.crit, h.target, h.pet)
        elseif not ok then
            C.lastErr = tostring(h)
        end
        if (C.matched or 0) == 0 then Changed() end -- keep the diagnostic line fresh
end
C.TakeLine = TakeLine

-- The window's lines are also read from its history (the game may add them
-- without going through AddMessage): every entry once, by identity.
local seenEntry = setmetatable({}, { __mode = "k" })
local lastN = 0
function C:Poll()
    local cf = _G.ChatFrame2
    if not cf then return end
    local hb = cf.historyBuffer
    if hb and hb.GetNumElements and hb.GetEntryAtIndex then
        local n = hb:GetNumElements() or 0
        for i = 1, n do
            local e = hb:GetEntryAtIndex(i)
            if type(e) == "table" and not seenEntry[e] then
                seenEntry[e] = true
                C.viaPoll = true
                TakeLine(e.message)
            end
        end
    elseif cf.GetNumMessages and cf.GetMessageInfo then
        local n = cf:GetNumMessages() or 0
        if n < lastN then lastN = 0 end
        for i = lastN + 1, n do
            C.viaPoll = true
            TakeLine((cf:GetMessageInfo(i)))
        end
        lastN = n
    end
end

local hooked
function C:StartLog()
    C.status = "log"
    if ns.settings then ns.settings.clMode = "log" end
    local cf = _G.ChatFrame2
    if hooked or not cf then return end
    hooked = true
    C.seen, C.matched, C.hookOk = 0, 0, true
    -- what is already in the window counts as seen (old lines, other sessions)
    pcall(C.Poll, C)
    C.seen, C.matched = 0, 0
    if hooksecurefunc and cf.AddMessage then
        hooksecurefunc(cf, "AddMessage", function(self, text)
            -- the hook and the poll would both see this line: the poll marks it
            local hb = self.historyBuffer
            if hb and hb.GetEntryAtIndex then return end
            TakeLine(text)
        end)
    end
    local acc = 0
    local poller = CreateFrame("Frame")
    poller:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.3 then return end
        acc = 0
        if ns.Safe then ns.Safe(C.Poll, C) else pcall(C.Poll, C) end
    end)
end

---------------------------------------------------------------------------
-- View (right pane, in place of the conversation)
---------------------------------------------------------------------------
local rows = {}

local function Font(parent, template, c, justify)
    local f = ns.Font and ns.Font(parent, template, c, justify) or parent:CreateFontString(nil, "OVERLAY", template)
    if not ns.Font then
        if c then f:SetTextColor(c[1], c[2], c[3]) end
        f:SetJustifyH(justify or "LEFT")
    end
    return f
end

local function Tex(parent, layer, c, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    return t
end

function C:Build(phone, left, bottomOffset, headH)
    local v = CreateFrame("Frame", nil, phone)
    v:SetPoint("TOPLEFT", left, "TOPRIGHT")
    v:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT", 0, bottomOffset)
    Tex(v, "BACKGROUND", COL.bg, 0.0):SetAllPoints()
    local div = Tex(v, "BORDER", COL.sep)
    div:SetWidth(1)
    div:SetPoint("TOPLEFT")
    div:SetPoint("BOTTOMLEFT")
    -- header
    local h = CreateFrame("Frame", nil, v)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:SetHeight(headH)
    Tex(h, "BACKGROUND", COL.head):SetAllPoints()
    v.head = h
    local icon = h:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\Icons\\Ability_DualWield")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = Font(h, "GameFontHighlight", COL.text)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    title:SetText(L.K_combat)
    v.title = title
    local sub = Font(h, "GameFontHighlightSmall", COL.sub)
    sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
    sub:SetPoint("RIGHT", h, "RIGHT", -120, 0)
    sub:SetWordWrap(false)
    v.sub = sub
    local reset = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    reset:SetSize(64, 20)
    reset:SetPoint("RIGHT", -34, 0)
    reset:SetText(L.CL_RESET)
    reset:SetScript("OnClick", function() C:Reset() end)
    v.reset = reset
    local copy = CreateFrame("Button", nil, h)
    copy:SetSize(20, 20)
    copy:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    copy:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    copy:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up", "ADD")
    copy:SetScript("OnClick", function() if ns.ShowCopy then ns:ShowCopy(L.K_combat, C:CopyText()) end end)
    copy:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.COPY_CONV)
        GameTooltip:Show()
    end)
    copy:SetScript("OnLeave", GameTooltip_Hide)
    -- summary list (top half)
    local box = CreateFrame("Frame", nil, v)
    box:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -2)
    box:SetPoint("RIGHT", v, "RIGHT")
    box:SetHeight(200)
    v.box = box
    local cap = Font(box, "GameFontNormalSmall", COL.accent)
    cap:SetPoint("TOPLEFT", 10, -4)
    cap:SetText(L.CL_SUMMARY)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 0, -20)
    scroll:SetPoint("BOTTOMRIGHT")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, d)
        local max = Num(self:GetVerticalScrollRange(), 0)
        self:SetVerticalScroll(math.max(0, math.min(max, Num(self:GetVerticalScroll(), 0) - d * ROW * 2)))
    end)
    v.scroll, v.content = scroll, content
    local note = Font(content, "GameFontHighlightSmall", COL.sub)
    note:SetPoint("TOPLEFT", 10, -4)
    note:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    v.note = note
    -- the game's Combat Log (bottom)
    local logBox = CreateFrame("Frame", nil, v)
    logBox:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    logBox:SetPoint("BOTTOMRIGHT")
    local line = Tex(logBox, "BORDER", COL.sep)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    local lcap = Font(logBox, "GameFontNormalSmall", COL.accent)
    lcap:SetPoint("TOPLEFT", 10, -4)
    lcap:SetText(L.CL_GAMELOG)
    local holder = CreateFrame("Frame", nil, logBox)
    holder:SetPoint("TOPLEFT", 6, -20)
    holder:SetPoint("BOTTOMRIGHT", -6, 4)
    v.holder = holder
    v.logNote = Font(logBox, "GameFontHighlightSmall", COL.sub)
    v.logNote:SetPoint("TOPLEFT", 10, -24)
    v.logNote:SetPoint("RIGHT", logBox, "RIGHT", -10, 0)
    v:Hide()
    v:SetScript("OnSizeChanged", function(self, _, hgt)
        local avail = Num(hgt, 300) - headH
        box:SetHeight(math.max(80, math.floor(avail * 0.5)))
    end)
    self.view = v
    return v
end

local function Row(i)
    if rows[i] then return rows[i] end
    local v = C.view
    local r = CreateFrame("Frame", nil, v.content)
    r:SetHeight(ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 10, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.amount = Font(r, "GameFontHighlight", COL.text, "RIGHT")
    r.amount:SetPoint("TOPRIGHT", -10, -2)
    r.name = Font(r, "GameFontHighlight", COL.text)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1)
    r.name:SetPoint("RIGHT", r.amount, "LEFT", -6, 0)
    r.name:SetWordWrap(false)
    r.detail = Font(r, "GameFontHighlightSmall", COL.sub)
    r.detail:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, -2)
    r.detail:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r.detail:SetWordWrap(false)
    rows[i] = r
    return r
end

local function SpellIcon(id)
    if not id or id == 0 then return "Interface\\Icons\\INV_Sword_04" end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t then return t end
    end
    if GetSpellTexture then
        local ok, t = pcall(GetSpellTexture, id)
        if ok and t then return t end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function C:Render()
    local v = self.view
    if not v then return 0 end
    local list = self:List()
    local w = Num(v.scroll:GetWidth(), 0)
    if w <= 1 then w = Num(v:GetWidth(), 300) end
    v.content:SetWidth(w)
    for i, d in ipairs(list) do
        local r = Row(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", v.content, "TOPLEFT", 0, -(i - 1) * ROW)
        r:SetPoint("RIGHT", v.content, "RIGHT")
        r.icon:SetTexture(SpellIcon(d.id))
        r.name:SetText((d.name or "?") .. (d.pet and (" (" .. L.PET .. ")") or ""))
        r.amount:SetText(Short(d.max) .. (d.crit and (" |cffffd133" .. L.CRIT .. "|r") or ""))
        r.detail:SetText(L.CL_DETAIL:format(d.target or "?", d.hits or 0))
        r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    v.content:SetHeight(math.max(1, #list * ROW))
    local msg
    if self.status == "blocked" or self.status == "no-api" then msg = L.CL_BLOCKED
    elseif self.status == "secret" then msg = L.CL_SECRET
    elseif #list == 0 and self.status == "log" then msg = L.CL_LOG
    elseif #list == 0 then msg = L.CL_WAIT end
    if #list == 0 and self.status == "log" then
        -- diagnostic while nothing is recognized: lines seen / recognized / the last one, raw
        msg = msg .. "\n\n" .. L.CL_DIAG:format(self.seen or 0, self.matched or 0, tostring(self.hookOk))
        if self.lastRaw then msg = msg .. "\n" .. self.lastRaw:gsub("|", "||"):sub(1, 400) end
        if self.lastErr then msg = msg .. "\n" .. self.lastErr end
    end
    v.note:SetText(#list == 0 and msg or "")
    v.sub:SetText(L.CL_SUB:format(#list) .. (self.status == "log" and ("  -  " .. L.CL_FROMLOG) or ""))
    return #list
end

---------------------------------------------------------------------------
-- The game's Combat Log window (ChatFrame2) shown inside, while the phone
-- replaces the game's chat (otherwise it is in the game's chat as usual).
---------------------------------------------------------------------------
function C:Embed(on)
    local cf = _G.ChatFrame2
    local v = self.view
    if not (cf and v) then return end
    if on then
        if not ns.replacing then
            v.logNote:SetText(L.CL_INCHAT)
            return
        end
        v.logNote:SetText("")
        if not self.home then
            self.home = { parent = cf:GetParent(), points = {} }
            for i = 1, Num(cf:GetNumPoints(), 0) do self.home.points[i] = { cf:GetPoint(i) } end
        end
        cf:SetParent(v.holder)
        cf:ClearAllPoints()
        cf:SetPoint("TOPLEFT", v.holder, "TOPLEFT")
        cf:SetPoint("BOTTOMRIGHT", v.holder, "BOTTOMRIGHT")
        cf:Show()
        self.embedded = true
    elseif self.embedded then
        cf:SetParent(self.home.parent)
        cf:ClearAllPoints()
        for _, p in ipairs(self.home.points) do cf:SetPoint(unpack(p)) end
        self.home = nil
        self.embedded = false
    end
end

-- Text for the copy window: the summary, the reader's state and the last lines
-- of the game's Combat Log window as the game wrote them.
function C:CopyText()
    local out = { L.CL_SUMMARY }
    for _, d in ipairs(self:List()) do
        out[#out + 1] = (d.name or "?") .. (d.pet and (" (" .. L.PET .. ")") or "") .. ": " .. Short(d.max)
            .. (d.crit and (" " .. L.CRIT) or "") .. "  -  " .. L.CL_DETAIL:format(d.target or "?", d.hits or 0)
    end
    out[#out + 1] = ""
    out[#out + 1] = "read by poll: " .. tostring(self.viaPoll)
    out[#out + 1] = "status: " .. tostring(self.status) .. "  -  " .. L.CL_DIAG:format(self.seen or 0, self.matched or 0, tostring(self.hookOk))
    if self.lastRaw then out[#out + 1] = (self.lastRaw:gsub("|", "||")) end
    if self.lastErr then out[#out + 1] = self.lastErr end
    local cf = _G.ChatFrame2
    if cf and cf.GetNumMessages and cf.GetMessageInfo then
        out[#out + 1] = ""
        out[#out + 1] = L.CL_GAMELOG .. ":"
        local ok, n = pcall(cf.GetNumMessages, cf)
        n = ok and Num(n, 0) or 0
        for i = math.max(1, n - 39), n do
            local ok2, text = pcall(cf.GetMessageInfo, cf, i)
            if ok2 and text then
                if issecretvalue and issecretvalue(text) then text = "(secret)" end
                out[#out + 1] = (tostring(text):gsub("|", "||"))
            end
        end
    end
    return table.concat(out, "\n")
end

function C:Show()
    if not self.view then return end
    self.view:Show()
    self:Render()
    self:Embed(true)
end

function C:Hide()
    if not self.view then return end
    self:Embed(false)
    self.view:Hide()
end
