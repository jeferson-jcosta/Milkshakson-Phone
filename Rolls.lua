-- Rolls chat: one message per item rolled on (Need / Greed / Disenchant / Pass),
-- updated as the rolls come in, with the winner at the end. From the game's own
-- loot messages (CHAT_MSG_LOOT), read with the game's own format strings, so it
-- works in any client language.
local _, ns = ...
local L = ns.L
local R = {}
ns.Rolls = R

local KEY = "rolls"
local OPEN_TIME = 600          -- an item's rolls stay open this long (seconds)
local function issecret(v) local f = issecretvalue return f ~= nil and f(v) or false end

-- global format string -> what each argument is (by argument number)
local FORMATS = {
    { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", "need", { "player", "roll", "item" } },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", "greed", { "player", "roll", "item" } },
    { "LOOT_ROLL_WON_NO_SPAM_DE", "won", "de", { "player", "roll", "item" } },
    { "LOOT_ROLL_WON_NO_SPAM_TRANSMOG", "won", "transmog", { "player", "roll", "item" } },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "won", "need", { "roll", "item" }, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "won", "greed", { "roll", "item" }, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "won", "de", { "roll", "item" }, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_TRANSMOG", "won", "transmog", { "roll", "item" }, true },
    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "roll", "need", { "roll", "item", "player" } },
    { "LOOT_ROLL_ROLLED_NEED", "roll", "need", { "roll", "item", "player" } },
    { "LOOT_ROLL_ROLLED_GREED", "roll", "greed", { "roll", "item", "player" } },
    { "LOOT_ROLL_ROLLED_DE", "roll", "de", { "roll", "item", "player" } },
    { "LOOT_ROLL_ROLLED_TRANSMOG", "roll", "transmog", { "roll", "item", "player" } },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", "choice", "pass", { "player", "item" } },
    { "LOOT_ROLL_PASSED_AUTO", "choice", "pass", { "player", "item" } },
    { "LOOT_ROLL_NEED_SELF", "choice", "need", { "item" }, true },
    { "LOOT_ROLL_GREED_SELF", "choice", "greed", { "item" }, true },
    { "LOOT_ROLL_DISENCHANT_SELF", "choice", "de", { "item" }, true },
    { "LOOT_ROLL_TRANSMOG_SELF", "choice", "transmog", { "item" }, true },
    { "LOOT_ROLL_PASSED_SELF_AUTO", "choice", "pass", { "item" }, true },
    { "LOOT_ROLL_PASSED_SELF", "choice", "pass", { "item" }, true },
    { "LOOT_ROLL_NEED", "choice", "need", { "player", "item" } },
    { "LOOT_ROLL_GREED", "choice", "greed", { "player", "item" } },
    { "LOOT_ROLL_DISENCHANT", "choice", "de", { "player", "item" } },
    { "LOOT_ROLL_TRANSMOG", "choice", "transmog", { "player", "item" } },
    { "LOOT_ROLL_PASSED", "choice", "pass", { "player", "item" } },
    { "LOOT_ROLL_ALL_PASSED", "allpass", nil, { "item" } },
    { "LOOT_ROLL_YOU_WON", "won", nil, { "item" }, true },
    { "LOOT_ROLL_WON", "won", nil, { "player", "item" } },
}

-- "%1$s won: %3$s (%2$d)" -> pattern + which argument each capture is
local function Compile(fmt)
    local order, n = {}, 0
    local p = fmt:gsub("%%(%d?)%$?([sd])", function(pos, kind)
        n = n + 1
        order[#order + 1] = tonumber(pos) or n
        return kind == "d" and "\2" or "\1"
    end)
    p = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("\1", "(.-)"):gsub("\2", "(%%d+)")
    return "^" .. p .. "$", order
end
R.Compile = Compile

local compiled
local function Patterns()
    if compiled then return compiled end
    compiled = {}
    for _, f in ipairs(FORMATS) do
        local fmt = _G[f[1]]
        if type(fmt) == "string" and fmt ~= "" then
            local pat, order = Compile(fmt)
            compiled[#compiled + 1] = { pat = pat, order = order, what = f[2], kind = f[3], roles = f[4], self = f[5], len = #fmt }
        end
    end
    -- longest formats first: "X won: item (Need - 87)" before "X won: item"
    table.sort(compiled, function(a, b) return a.len > b.len end)
    return compiled
end

-- Parses one loot line: { what, kind, player, item, roll } or nil
function R:Parse(text)
    if type(text) ~= "string" or issecret(text) or not text:find("|Hitem:") then return nil end
    for _, c in ipairs(Patterns()) do
        local caps = { text:match(c.pat) }
        if #caps > 0 then
            local r = { what = c.what, kind = c.kind }
            for i, v in ipairs(caps) do
                local role = c.roles[c.order[i]]
                if role then r[role] = v end
            end
            if c.self then r.player = (ns.Route and ns.Route.myName) or (UnitName and UnitName("player")) end
            if r.roll then r.roll = tonumber(r.roll) end
            if r.item and r.item:find("|Hitem:") then return r end
        end
    end
end

local ORDER = { "need", "greed", "de", "transmog", "pass" }
local KIND_COL = { need = "ff8040", greed = "40c0ff", de = "c080ff", transmog = "ff80ff", pass = "909090" }

-- Builds the message text of one item: item, one line per roll type, winner.
function R:Text(e)
    local lines = { e.item }
    for _, k in ipairs(ORDER) do
        local who = {}
        for name, r in pairs(e.rolls) do
            if r.kind == k then who[#who + 1] = { name = name, roll = r.roll } end
        end
        if #who > 0 then
            table.sort(who, function(a, b) return (a.roll or -1) > (b.roll or -1) end)
            local parts = {}
            for _, w in ipairs(who) do parts[#parts + 1] = w.name .. (w.roll and (" (" .. w.roll .. ")") or "") end
            lines[#lines + 1] = "|cff" .. KIND_COL[k] .. L["ROLL_" .. k] .. ":|r " .. table.concat(parts, ", ")
        end
    end
    if e.winner then
        lines[#lines + 1] = "|cff40ff40" .. L.ROLL_WON:format(e.winner) .. "|r"
            .. ((e.winKind or e.winRoll) and (" (" .. (e.winKind and L["ROLL_" .. e.winKind] or "") .. (e.winRoll and (" " .. e.winRoll) or "") .. ")") or "")
    elseif e.allpass then
        lines[#lines + 1] = "|cff909090" .. L.ROLL_ALLPASS .. "|r"
    end
    return table.concat(lines, "\n")
end

-- The open message of this item; a loot-history drop (id) also finds its own
-- message after it was won, so later updates of that drop don't repeat it.
local function Find(item, id)
    local c = ns.Store:Get(KEY)
    if not c then return nil end
    local now = time()
    for i = #c.msgs, math.max(1, #c.msgs - 30), -1 do
        local m = c.msgs[i]
        local e = m.roll
        if e and id and e.id == id then return m end
        if e and e.item == item and not e.done and now - (m.t or 0) < OPEN_TIME then return m end
    end
end

function R:OnLoot(text)
    local s = ns.settings
    if not (s and s.showRolls) then return end
    local r = R:Parse(text)
    if not r then return end
    local m = Find(r.item)
    local new = not m
    if new then
        m = { t = time(), info = true, ev = "LOOT", roll = { item = r.item, rolls = {} } }
    end
    local e = m.roll
    if r.what == "choice" or r.what == "roll" then
        if r.player then
            local old = e.rolls[r.player] or {}
            e.rolls[r.player] = { kind = r.kind or old.kind, roll = r.roll or old.roll }
        end
    elseif r.what == "won" then
        e.winner, e.done = r.player or "?", true
        e.winKind = r.kind or (e.rolls[e.winner] and e.rolls[e.winner].kind)
        e.winRoll = r.roll or (e.rolls[e.winner] and e.rolls[e.winner].roll)
    elseif r.what == "allpass" then
        e.allpass, e.done = true, true
    end
    m.text = R:Text(e)
    if new then
        ns.Store:Ensure(KEY, "rolls")
        ns.Store:Add({ key = KEY, kind = "rolls", msg = m }, ns.IsOpen and ns:IsOpen(KEY))
    else
        if ns.RedrawKey then ns:RedrawKey(KEY) end
        ns.Store:Changed(KEY)
    end
    return m
end

---------------------------------------------------------------------------
-- Second source: the game's loot history (C_LootHistory, the "Loot" window).
-- Works even when the loot chat lines are hidden (secret) inside instances.
---------------------------------------------------------------------------
local STATE = { [0] = "need", [1] = "need", [2] = "transmog", [3] = "greed", [5] = "pass" }
local function Plain(v) return v ~= nil and not issecret(v) end

function R:FromDrop(info, id)
    local s = ns.settings
    if not (s and s.showRolls) or type(info) ~= "table" then return end
    local item = info.itemHyperlink
    if not Plain(item) or type(item) ~= "string" or item == "" then return end
    local m = Find(item, id)
    local new = not m
    if new then m = { t = time(), info = true, ev = "LOOT", roll = { item = item, rolls = {} } } end
    local e = m.roll
    e.id = e.id or id
    for _, ri in ipairs(info.rollInfos or {}) do
        local name = ri.playerName
        local kind = STATE[ri.state]
        if Plain(name) and kind then
            local roll = Plain(ri.roll) and ri.roll or nil
            local old = e.rolls[name] or {}
            e.rolls[name] = { kind = kind, roll = roll or old.roll }
        end
    end
    local w = info.winner
    if type(w) == "table" and Plain(w.playerName) then
        e.winner, e.done = w.playerName, true
        e.winKind = STATE[w.state] or (e.rolls[w.playerName] and e.rolls[w.playerName].kind)
        e.winRoll = Plain(w.roll) and w.roll or (e.rolls[w.playerName] and e.rolls[w.playerName].roll)
    elseif info.allPassed then
        e.allpass, e.done = true, true
    end
    m.text = R:Text(e)
    if new then
        ns.Store:Ensure(KEY, "rolls")
        ns.Store:Add({ key = KEY, kind = "rolls", msg = m }, ns.IsOpen and ns:IsOpen(KEY))
    else
        if ns.RedrawKey then ns:RedrawKey(KEY) end
        ns.Store:Changed(KEY)
    end
    return m
end

local function Drop(enc, list)
    local H = C_LootHistory
    if not (H and H.GetSortedInfoForDrop) then return nil end
    local ok, info = pcall(H.GetSortedInfoForDrop, enc, list)
    return ok and info or nil
end

---------------------------------------------------------------------------
-- Diagnostics: last loot events, kept account-wide (MilkshaksonPhoneDB.rollsLog)
-- so they can be read from SavedVariables and shown with /phone rolls.
---------------------------------------------------------------------------
local function Log(entry)
    local s = ns.settings
    if not s then return end
    s.rollsLog = s.rollsLog or {}
    entry.t = time()
    local inst = IsInInstance and select(2, IsInInstance()) or nil
    entry.i = inst
    entry.c = InCombatLockdown and InCombatLockdown() or nil
    table.insert(s.rollsLog, entry)
    while #s.rollsLog > 40 do table.remove(s.rollsLog, 1) end
end

local function Esc(t) return (tostring(t):gsub("|", "||")) end

function R:Report()
    local s = ns.settings or {}
    local log = s.rollsLog or {}
    local H = C_LootHistory
    local lines = {}
    lines[#lines + 1] = ("events: %d - C_LootHistory: %s - formats: %d"):format(#log,
        (H and H.GetSortedInfoForDrop) and "yes" or "no", #Patterns())
    for i = math.max(1, #log - 9), #log do
        local e = log[i]
        lines[#lines + 1] = date("%H:%M:%S", e.t or 0) .. " " .. (e.ev or "?") .. " [" .. tostring(e.i or "-") .. (e.c and ",combat" or "") .. "] "
            .. (e.secret and "SECRET" or (e.text or e.h or "")) .. (e.m and (" -> " .. e.m) or (e.ev == "CHAT_MSG_LOOT" and " -> no match" or ""))
    end
    return lines
end

local f = CreateFrame("Frame")
function R:Start()
    for _, e in ipairs({ "CHAT_MSG_LOOT", "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "START_LOOT_ROLL" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function(_, event, a, b)
        local ok, err = pcall(function()
            if event == "CHAT_MSG_LOOT" then
                local secret = issecret(a)
                local r = not secret and R:Parse(a) or nil
                if secret or (type(a) == "string" and a:find("|Hitem:")) then
                    Log({ ev = event, secret = secret or nil, text = not secret and Esc(a):sub(1, 160) or nil,
                        m = r and (r.what .. (r.kind and ("/" .. r.kind) or "")) or nil })
                end
                if r then R:OnLoot(a) end
            elseif event == "LOOT_HISTORY_UPDATE_DROP" then
                local info = Drop(a, b)
                Log({ ev = event, h = tostring(a) .. ":" .. tostring(b) .. (info and (" rolls=" .. #(info.rollInfos or {})) or " no info") })
                if info then R:FromDrop(info, tostring(a) .. ":" .. tostring(b)) end
            elseif event == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
                local H = C_LootHistory
                local drops = H and H.GetSortedDropsForEncounter and select(2, pcall(H.GetSortedDropsForEncounter, a))
                Log({ ev = event, h = tostring(a) .. (type(drops) == "table" and (" drops=" .. #drops) or " no drops") })
                if type(drops) == "table" then
                    for _, d in ipairs(drops) do
                        local info = (d.rollInfos and d) or Drop(a, d.lootListID)
                        if info then R:FromDrop(info, tostring(a) .. ":" .. tostring(info.lootListID or d.lootListID)) end
                    end
                end
            elseif event == "START_LOOT_ROLL" then
                local link = GetLootRollItemLink and select(2, pcall(GetLootRollItemLink, a))
                Log({ ev = event, h = tostring(a) .. " " .. (Plain(link) and Esc(link) or "?") })
            end
        end)
        if not ok then geterrorhandler()(err) end
    end)
end
