-- Auction House chat: your purchases, sales, auctions created / expired /
-- cancelled and outbids, in one conversation (key "auction"). From the game
-- alone: the AH notification events (the game prints them with
-- ChatFrameUtil.AddSystemMessage, which no chat event carries) and the
-- system messages built from ERR_AUCTION_* strings. Other addons (e.g.
-- Milkshakson-Trader) may add lines with prices: MilkshaksonPhone_AuctionMessage(text).
local _, ns = ...
local A = {}
ns.Auction = A

local KEY = "auction"
local DEDUPE = 5            -- the same text twice within this many seconds = once
A.KEY = KEY
A.EVENTS = { "AUCTION_HOUSE_SHOW_NOTIFICATION", "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION",
    "AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION", "AUCTION_HOUSE_AUCTION_CREATED" }

local recent = {}
local function Dup(text)
    local now = GetTime and GetTime() or time()
    local t = recent[text]
    recent[text] = now
    return t ~= nil and now - t < DEDUPE
end
A.Dup = Dup

local function On() return not (ns.settings and ns.settings.showAuction == false) end

-- Game strings that are AH messages (any client language).
local NAMES = { "ERR_AUCTION_WON_S", "ERR_AUCTION_SOLD_S", "ERR_AUCTION_EXPIRED_S", "ERR_AUCTION_OUTBID_S",
    "ERR_AUCTION_REMOVED_S", "ERR_AUCTION_COMMODITY_WON_S", "ERR_AUCTION_STARTED", "ERR_AUCTION_REMOVED",
    "ERR_AUCTION_BID_PLACED", "ERR_AUCTION_WON_DOUBLE_S" }
local pats
local function Patterns()
    if pats then return pats end
    pats = {}
    for _, n in ipairs(NAMES) do
        local f = _G[n]
        local p = type(f) == "string" and ns.Route and ns.Route.PatternFrom(f)
        if p then pats[#pats + 1] = p end
    end
    return pats
end

function A:Matches(text)
    if type(text) ~= "string" or not On() then return false end
    for _, p in ipairs(Patterns()) do
        if text:match(p) then return true end
    end
    return false
end

function A:Add(text)
    if type(text) ~= "string" or text == "" or not On() or not ns.Store then return false end
    if Dup(text) then return false end
    ns.Store:Ensure(KEY, KEY)
    ns.Store:Add({ key = KEY, kind = KEY, msg = { t = time(), text = text, info = true, ev = "SYSTEM" } },
        ns.IsOpen and ns:IsOpen(KEY))
    return true
end

-- Notification text the way the game writes it.
local FALLBACK = { [0] = "ERR_AUCTION_BID_PLACED", [1] = "ERR_AUCTION_REMOVED_S", [2] = "ERR_AUCTION_WON_S", [3] = "ERR_AUCTION_OUTBID_S" }
function A.NotificationText(n, arg)
    local U = ChatFrameUtil
    if U and U.GetAuctionHouseNotificationText then
        local ok, t = pcall(U.GetAuctionHouseNotificationText, n, arg)
        if ok and type(t) == "string" and t ~= "" then return t end
    end
    local f = _G[FALLBACK[n] or ""]
    if type(f) ~= "string" then return nil end
    if f:find("%%") then
        local ok, t = pcall(string.format, f, tostring(arg or ""))
        return ok and t or nil
    end
    return f
end

function A:OnEvent(event, ...)
    if event == "AUCTION_HOUSE_SHOW_NOTIFICATION" or event == "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION" then
        A:Add(A.NotificationText(...))
    elseif event == "AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION" then
        local name, qty = ...
        local f = ERR_AUCTION_COMMODITY_WON_S
        local ok, t = pcall(string.format, type(f) == "string" and f or "%s x%d", tostring(name or "?"), tonumber(qty) or 1)
        A:Add(ok and t or tostring(name))
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        A:Add(ERR_AUCTION_STARTED or "Auction created.")
    end
end

local frame
function A:Start()
    if frame or not CreateFrame then return end
    frame = CreateFrame("Frame")
    for _, e in ipairs(A.EVENTS) do pcall(frame.RegisterEvent, frame, e) end
    frame:SetScript("OnEvent", function(_, event, ...) A:OnEvent(event, ...) end)
end

-- Public: lines from other addons (Trader: "Bought 20 Linen Cloth for 5s 20c").
function MilkshaksonPhone_AuctionMessage(text)
    return A:Add(text)
end
