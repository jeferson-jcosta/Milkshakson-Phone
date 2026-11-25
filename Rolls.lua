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
local issecret = issecretvalue or function() return false end

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

local function Find(item)
    local c = ns.Store:Get(KEY)
    if not c then return nil end
    local now = time()
    for i = #c.msgs, math.max(1, #c.msgs - 30), -1 do
        local m = c.msgs[i]
        local e = m.roll
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

local f = CreateFrame("Frame")
function R:Start()
    pcall(f.RegisterEvent, f, "CHAT_MSG_LOOT")
    f:SetScript("OnEvent", function(_, _, text)
        local ok, err = pcall(R.OnLoot, R, text)
        if not ok then geterrorhandler()(err) end
    end)
end
