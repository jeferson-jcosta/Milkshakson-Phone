-- Profession trainers the player has visited: where they are and which ranks
-- they teach. The game has no list of trainers, so the phone remembers each one
-- when its training window opens (TRAINER_SHOW), account-wide per faction, and
-- the profession tooltip in the top bar shows them (same zone first).
local _, ns = ...
local T = {}
ns.Trainers = T

local function Call(f, ...)
    if type(f) ~= "function" then return nil end
    local r = { pcall(f, ...) }
    if not r[1] then return nil end
    return unpack(r, 2, table.maxn and table.maxn(r) or #r)
end

local function DB()
    local s = MilkshaksonPhoneDB
    if not s then return nil end
    s.trainers = s.trainers or {}
    local f = (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
    s.trainers[f] = s.trainers[f] or {}
    return s.trainers[f]
end

local function Where()
    local zone = (GetRealZoneText and GetRealZoneText()) or "?"
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local map = C_Map and C_Map.GetBestMapForUnit and Call(C_Map.GetBestMapForUnit, "player")
    local x, y
    if map and C_Map.GetPlayerMapPosition then
        local pos = Call(C_Map.GetPlayerMapPosition, map, "player")
        if pos and pos.GetXY then
            local ok, px, py = pcall(pos.GetXY, pos)
            if ok and px and py then x, y = math.floor(px * 1000 + 0.5) / 10, math.floor(py * 1000 + 0.5) / 10 end
        end
    end
    return zone, sub ~= zone and sub or "", map, x, y
end

-- Training window open: which professions this NPC teaches (services' skill
-- line / skill requirement) and the rank names it offers ("Journeyman", ...).
function T:Learn(professions)
    local db = DB()
    if not db then return end
    local npc = UnitName and UnitName("npc")
    if not npc then return end
    local profs, ranks = {}, {}
    local known = {}
    for _, p in ipairs(professions or {}) do known[p] = true end
    local n = Call(GetNumTrainerServices) or 0
    for i = 1, n do
        local name, sub, status = Call(GetTrainerServiceInfo, i)
        if name and status ~= "header" then
            local line = Call(GetTrainerServiceSkillLine, i)
            local skill = Call(GetTrainerServiceSkillReq, i)
            local p = (type(line) == "string" and line ~= "" and line) or (type(skill) == "string" and skill ~= "" and skill)
            if p then profs[p] = true end
            -- the rank itself is a service named like the profession, its sub text is the rank
            if known[name] and type(sub) == "string" and sub ~= "" then
                ranks[name] = ranks[name] or {}
                ranks[name][sub] = true
            end
        end
    end
    -- nothing from the services: the NPC's title ("Cooking Trainer") names it
    if not next(profs) and C_TooltipInfo and C_TooltipInfo.GetUnit then
        local data = Call(C_TooltipInfo.GetUnit, "npc")
        local l2 = data and data.lines and data.lines[2] and data.lines[2].leftText
        if type(l2) == "string" then
            for p in pairs(known) do if l2:find(p, 1, true) then profs[p] = true end end
        end
    end
    local zone, sub, map, x, y = Where()
    for p in pairs(profs) do
        db[p] = db[p] or {}
        local old = db[p][npc] or {}
        local r = old.ranks or {}
        for k in pairs(ranks[p] or {}) do r[k] = true end
        db[p][npc] = { zone = zone, sub = sub, map = map, x = x, y = y, ranks = r, t = time and time() or 0 }
    end
end

-- Lines for the tooltip: "Name - Zone, Sub (x, y)" plus the ranks taught,
-- the ones in the current zone first, at most `max`.
function T:Lines(profession, max)
    local db = DB()
    local list = {}
    local here = GetRealZoneText and GetRealZoneText()
    for npc, v in pairs(db and db[profession] or {}) do
        list[#list + 1] = { npc = npc, v = v, here = v.zone == here }
    end
    table.sort(list, function(a, b)
        if a.here ~= b.here then return a.here end
        return (a.v.t or 0) > (b.v.t or 0)
    end)
    local out = {}
    for i = 1, math.min(#list, max or 3) do
        local e = list[i]
        local place = e.v.zone .. ((e.v.sub and e.v.sub ~= "") and (", " .. e.v.sub) or "")
        if e.v.x then place = place .. (" (%.1f, %.1f)"):format(e.v.x, e.v.y) end
        local r = {}
        for k in pairs(e.v.ranks or {}) do r[#r + 1] = k end
        table.sort(r)
        out[#out + 1] = { e.npc .. " - " .. place, #r > 0 and table.concat(r, ", ") or nil }
    end
    return out, #list
end
