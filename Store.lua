-- Data layer: conversations (per character) and settings (account).
-- MilkshaksonPhoneCharDB.convs[key] = { key, kind, name, target, chan, cls,
--   msgs = { { t, text, from, out, cls, ev, tag, info } }, unread, last, pinned, muted }
local _, ns = ...
local S = {}
ns.Store = S

S.DEFAULTS = {
    replaceChat = true,   -- the phone takes the place of the game's chat
    muteChannels = true,  -- new public channels (Trade, General...) start muted
    muteSystem = true,    -- System / NPC conversations start muted
    autoJoin = true,      -- join General / Trade / LocalDefense on login and zone change
    showSystem = true,    -- system messages kept in the System chat (loot, XP, crafting...)
    showNPC = true,       -- NPC messages kept in the System chat too
    monitorSystem = false,
    combatLog = true,
    showRolls = true,     -- Rolls chat: Need / Greed / Pass per item and the winner
    archiveDays = 3,
    staleHours = 2,       -- private chats with nothing new for this many hours go after the channels (0 = off)      -- private chats with nothing new for this many days go to Archived (0 = never)
    resetParty = true,    -- joining a new group clears the group chat     -- Combat chat: biggest hit per spell + the game's combat log
    hoverExpand = true,
    combatMinimize = true,
    idleMinutes = 5,      -- minimize when not used for this many minutes (0 = off) -- minimize when combat starts, restore when it ends
    animate = true,       -- smooth minimize / restore
    animTime = 0.25,      -- seconds   -- minimized: the mouse over the phone opens it, leaving minimizes it -- System chat shows no badge / last message unless monitored
    typeColors = true,
    fontScale = 1,
    fitBubbles = false,   -- bubbles fit their text (off: whole width, edges line up)
    align = "messenger", -- messages: messenger (yours right) / left / right        -- font size of the phone (0.8 - 1.6)    -- text colored by chat type (guild green, party blue...)
    maxMsgs = 200,        -- messages kept per conversation
    listCollapsed = true, -- chats list as icons (drawer); the arrow in its header opens it
    w = 560, h = 480,
}

local listeners = {}

function S:Init()
    MilkshaksonPhoneDB = type(MilkshaksonPhoneDB) == "table" and MilkshaksonPhoneDB or {}
    local db = MilkshaksonPhoneDB
    if (tonumber(db.w) or 0) < 500 then db.w = 560 end -- two panes need the room
    for k, v in pairs(S.DEFAULTS) do if db[k] == nil then db[k] = v end end
    if not db.v2 then -- 2026-11-23: System + NPCs grouped in one quiet chat, kept by default
        db.v2 = true
        db.showSystem, db.showNPC = true, true
    end
    MilkshaksonPhoneCharDB = type(MilkshaksonPhoneCharDB) == "table" and MilkshaksonPhoneCharDB or {}
    local c = MilkshaksonPhoneCharDB
    c.v = 1
    c.convs = c.convs or {}
    c.dmg = nil -- (old combat summary: the combat log can't be read on Forever)
    db.clSamples, db.clMode = nil, nil
end

function S:Settings() return MilkshaksonPhoneDB end
function S:Char() return MilkshaksonPhoneCharDB end
function S:Get(key) return key and self:Char().convs[key] end

function S:OnChange(f) listeners[#listeners + 1] = f end
function S:Changed(key) for _, f in ipairs(listeners) do f(key) end end

function S:DefaultMuted(kind)
    local s = self:Settings()
    if kind == "channel" then return s.muteChannels and true or false end
    if kind == "system" or kind == "npc" then return s.muteSystem and true or false end
    return false
end

-- r = { key, kind, name, target, chan, cls, msg } from Route:Classify.
-- active = the conversation is open on screen (the message is read).
-- Creates the conversation if needed (also for empty ones: party, guild, channels).
function S:Ensure(key, kind, name)
    local convs = self:Char().convs
    local c = convs[key]
    if not c then
        c = { key = key, kind = kind, msgs = {}, unread = 0, unseen = 0, last = 0 }
        c.muted = self:DefaultMuted(kind)
        convs[key] = c
    end
    if name and name ~= "" then c.name = name end
    return c
end

function S:Add(r, active)
    local c = self:Ensure(r.key, r.kind)
    if r.name and r.name ~= "" then c.name = r.name end
    if r.target then c.target = r.target end
    if r.chan then c.chan = r.chan end
    if r.cls then c.cls = r.cls end
    local m = r.msg
    c.msgs[#c.msgs + 1] = m
    local max = tonumber(self:Settings().maxMsgs) or 200
    while #c.msgs > max do table.remove(c.msgs, 1) end
    c.last = m.t or 0
    if m.out or active then
        c.unread, c.unseen = 0, 0 -- open, or answering: read
    else
        c.unseen = math.min((c.unseen or 0) + 1, #c.msgs) -- also for muted (grey count)
        if not c.muted then c.unread = math.min((c.unread or 0) + 1, #c.msgs) end
    end
    self:Changed(r.key)
    return c
end

function S:Read(key)
    local c = self:Get(key)
    if c and ((c.unread or 0) > 0 or (c.unseen or 0) > 0) then c.unread, c.unseen = 0, 0; self:Changed(key) end
end

local function B(v) return v and 1 or 0 end

-- Conversations with messages (or pinned): `top` keys first (in that order,
-- even when empty), then pinned, then newest first. hide = { kind = true }:
-- kinds switched off in the options.
function S:List(top, hide)
    hide = hide or {}
    local rank = {}
    for i, k in ipairs(top or {}) do rank[k] = i end
    local t = {}
    for _, c in pairs(self:Char().convs) do
        if not hide[c.kind] and (rank[c.key] or #c.msgs > 0 or c.pinned) then
            t[#t + 1] = c
        end
    end
    table.sort(t, function(a, b)
        local ra, rb = rank[a.key] or 999, rank[b.key] or 999
        if ra ~= rb then return ra < rb end
        if B(a.pinned) ~= B(b.pinned) then return B(a.pinned) > B(b.pinned) end
        if (a.last or 0) ~= (b.last or 0) then return (a.last or 0) > (b.last or 0) end
        return a.key < b.key
    end)
    return t
end

function S:Unread(hide)
    hide = hide or {}
    local n = 0
    for _, c in pairs(self:Char().convs) do
        if not c.muted and not hide[c.kind] then n = n + (c.unread or 0) end
    end
    return n
end

function S:Counts()
    local convs, msgs = 0, 0
    for _, c in pairs(self:Char().convs) do convs = convs + 1; msgs = msgs + #c.msgs end
    return convs, msgs
end

function S:SetPinned(key, v) local c = self:Get(key) if c then c.pinned = v or nil; self:Changed(key) end end
function S:SetMuted(key, v)
    local c = self:Get(key)
    if c then c.muted = v and true or false; if v then c.unread = 0 elseif (c.unseen or 0) > 0 then c.unread = c.unseen end; self:Changed(key) end
end
function S:ClearConv(key) local c = self:Get(key) if c then wipe(c.msgs); c.unread, c.unseen = 0, 0; self:Changed(key) end end
function S:Delete(key) local convs = self:Char().convs if convs[key] then convs[key] = nil; self:Changed(key) end end
function S:Clear() wipe(self:Char().convs); self:Changed(nil) end
