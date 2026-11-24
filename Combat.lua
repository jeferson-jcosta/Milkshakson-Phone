-- Combat chat: the game's own Combat Log window (ChatFrame2) shown inside the
-- phone. On WoW: Forever addons can't read the combat log (no API, and the
-- window's lines are protected strings), so this is the game's window itself.
local _, ns = ...
local L = ns.L
local C = {}
ns.Combat = C

local COL = { head = { 0.122, 0.173, 0.2 }, text = { 0.91, 0.93, 0.94 }, sub = { 0.53, 0.59, 0.63 }, sep = { 0.14, 0.19, 0.21 } }

local function Num(v, d) return type(v) == "number" and v or d end

local function Font(parent, template, c, justify)
    if ns.Font then return ns.Font(parent, template, c, justify) end
    local f = parent:CreateFontString(nil, "OVERLAY", template)
    if c then f:SetTextColor(c[1], c[2], c[3]) end
    f:SetJustifyH(justify or "LEFT")
    return f
end

local function Tex(parent, layer, c, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    return t
end

-- Line in the chats list.
function C:Preview() return L.CL_NONE end

function C:Build(phone, left, bottomOffset, headH)
    local v = CreateFrame("Frame", nil, phone)
    v:SetPoint("TOPLEFT", left, "TOPRIGHT")
    v:SetPoint("BOTTOMRIGHT", phone, "BOTTOMRIGHT", 0, bottomOffset)
    local div = Tex(v, "BORDER", COL.sep)
    div:SetWidth(1)
    div:SetPoint("TOPLEFT")
    div:SetPoint("BOTTOMLEFT")
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
    sub:SetPoint("RIGHT", h, "RIGHT", -40, 0)
    sub:SetWordWrap(false)
    sub:SetText(L.CL_GAMELOG)
    v.sub = sub
    local holder = CreateFrame("Frame", nil, v)
    holder:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 8, -6)
    holder:SetPoint("BOTTOMRIGHT", -6, 4)
    v.holder = holder
    v.logNote = Font(v, "GameFontHighlightSmall", COL.sub)
    v.logNote:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 10, -10)
    v.logNote:SetPoint("RIGHT", v, "RIGHT", -10, 0)
    v:Hide()
    self.view = v
    return v
end

-- The game's Combat Log window (ChatFrame2) inside the phone, while the phone
-- replaces the game's chat (otherwise it is in the game's chat as usual).
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

function C:Show()
    if not self.view then return end
    self.view:Show()
    self:Embed(true)
end

function C:Hide()
    if not self.view then return end
    self:Embed(false)
    self.view:Hide()
end

-- (kept for old calls: nothing to start, the window is the game's)
function C:Start() end
