-- Chat events -> conversations. Uses only the event arguments the game gives:
-- text, sender, ..., channelIndex (8), channelBaseName (9), ..., guid (12), bnSenderID (13).
local _, ns = ...
local R = {}
ns.Route = R

-- Group / shared conversations: event suffix -> conversation kind (= key).
local KIND = {
    PARTY = "party", PARTY_LEADER = "party",
    RAID = "raid", RAID_LEADER = "raid", RAID_WARNING = "raid",
    INSTANCE_CHAT = "instance", INSTANCE_CHAT_LEADER = "instance",
    GUILD = "guild", GUILD_ACHIEVEMENT = "guild", OFFICER = "officer",
    SAY = "local", YELL = "local", EMOTE = "local", TEXT_EMOTE = "local",
    MONSTER_SAY = "npc", MONSTER_YELL = "npc", MONSTER_EMOTE = "npc", MONSTER_WHISPER = "npc",
    MONSTER_PARTY = "npc", RAID_BOSS_EMOTE = "npc", RAID_BOSS_WHISPER = "npc",
    SYSTEM = "system", LOOT = "system", MONEY = "system", CURRENCY = "system", SKILL = "system",
    TRADESKILLS = "system", OPENING = "system", ACHIEVEMENT = "system",
    COMBAT_XP_GAIN = "system", COMBAT_FACTION_CHANGE = "system", COMBAT_HONOR_GAIN = "system",
    BG_SYSTEM_NEUTRAL = "system", BG_SYSTEM_ALLIANCE = "system", BG_SYSTEM_HORDE = "system",
}
local WHISPER = { WHISPER = "in", WHISPER_INFORM = "out", AFK = "in", DND = "in" }
local BN = { BN_WHISPER = "in", BN_WHISPER_INFORM = "out" }
-- Lines shown as a centered note instead of a bubble.
local INFO = { EMOTE = true, TEXT_EMOTE = true, MONSTER_EMOTE = true, RAID_BOSS_EMOTE = true, GUILD_ACHIEVEMENT = true }
local TAG = {
    PARTY_LEADER = "leader", RAID_LEADER = "leader", INSTANCE_CHAT_LEADER = "leader",
    RAID_WARNING = "warning", YELL = "yell", MONSTER_YELL = "yell", AFK = "afk", DND = "dnd",
}

R.EVENTS = { "CHAT_MSG_CHANNEL" }
for _, t in ipairs({ KIND, WHISPER, BN }) do
    for k in pairs(t) do R.EVENTS[#R.EVENTS + 1] = "CHAT_MSG_" .. k end
end
table.sort(R.EVENTS)

-- Midnight-based clients can hand addons "secret" values (combat / encounters).
function R.Secret(...)
    if not issecretvalue then return false end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end

local function Full(name)
    if type(name) ~= "string" or name == "" then return nil end
    if Ambiguate then return Ambiguate(name, "none") end
    return name
end
local function Short(name)
    if type(name) ~= "string" or name == "" then return nil end
    if Ambiguate then return Ambiguate(name, "short") end
    return (name:gsub("%-.*$", ""))
end
R.Short = Short

local function Class(guid)
    if type(guid) ~= "string" or guid == "" or not GetPlayerInfoByGUID then return nil end
    local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
    return ok and cls or nil
end

-- Returns { key, kind, name, target, chan, cls, msg } or nil[, "secret"].
function R:Classify(event, text, sender, _, chanName, _, _, _, chanIndex, chanBase, _, lineID, guid, bnID)
    local t = (event or ""):gsub("^CHAT_MSG_", "")
    if R.Secret(text, sender, guid, chanIndex) then return nil, "secret" end
    local me = UnitName and UnitName("player")
    local msg = { t = time(), text = text or "", ev = t, tag = TAG[t], info = INFO[t] }
    local who = Short(sender)
    -- full name + line id: what the game's player menu needs (whisper, invite, report...)
    msg.full = Full(sender)
    msg.line = tonumber(lineID)

    if WHISPER[t] then
        local full = Full(sender) or "?"
        msg.out = WHISPER[t] == "out" or nil
        msg.from = msg.out and me or who
        local cls = Class(guid)
        return { key = "w:" .. full:lower(), kind = "whisper", name = who or full, target = full, cls = cls, msg = msg }
    end

    if BN[t] then
        local tag, account
        if bnID and C_BattleNet and C_BattleNet.GetAccountInfoByID then
            local ok, info = pcall(C_BattleNet.GetAccountInfoByID, bnID)
            if ok and type(info) == "table" then tag, account = info.battleTag, info.accountName end
        end
        local name = (type(tag) == "string" and tag:match("^[^#]+")) or sender
        msg.out = BN[t] == "out" or nil
        msg.from = msg.out and me or name
        local id = (type(tag) == "string" and tag) or tostring(bnID or sender or "?")
        return { key = "bn:" .. id:lower(), kind = "bn", name = name, target = account or sender, msg = msg }
    end

    if t == "CHANNEL" then
        local base = (type(chanBase) == "string" and chanBase ~= "" and chanBase) or chanName or "?"
        base = base:match("^(.-) %- ") or base -- "Trade - City" -> "Trade"
        msg.from = who
        msg.out = (who ~= nil and who == me) or nil
        msg.cls = Class(guid)
        return { key = "c:" .. base:lower(), kind = "channel", name = base, chan = tonumber(chanIndex), msg = msg }
    end

    local kind = KIND[t]
    if not kind then return nil end
    if kind == "system" then
        msg.info = true
    elseif kind == "npc" then
        -- NPCs share the System conversation; their name is not a player
        msg.from, msg.full, msg.line, msg.npc = who, nil, nil, true
        return { key = "system", kind = "system", msg = msg }
    else
        msg.from = who
        msg.out = (who ~= nil and who == me) or nil
        msg.cls = Class(guid)
    end
    return { key = kind, kind = kind, msg = msg }
end
