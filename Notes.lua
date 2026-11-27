-- Release notes shown once after an update (MilkshaksonUI:WhatsNew) and by the
-- "What's new" button in Options. Newest first; en = English, pt = Portuguese.
-- At each release: add the new version on top (from CHANGELOG.md).
local ADDON, ns = ...

ns.NOTES = {
    { v = "0.6.1",
      en = {
        "**Loot chat for your addons:** Milkshakson-Ninjas now posts your good loot (BoE, upgrades, rarity) in the Loot rolls chat.",
      },
      pt = {
        "**Chat de loot para seus addons:** o Milkshakson-Ninjas agora posta seu loot bom (BoE, upgrade, raridade) no chat de Loot.",
      } },
    { v = "0.6.0",
      en = {
        "**Money in the title bar**, after the clock, with the coin icons like the bags.",
        "Money in messages shows with the coin icons.",
        "Fix: a click on the minimized “Chats” row restores the phone.",
        "**What's new** popup after an update (this window), also from Options.",
      },
      pt = {
        "**Dinheiro na barra de título**, depois do horário, com os ícones de moedas como na bolsa.",
        "Dinheiro nas mensagens aparece com os ícones de moedas.",
        "Correção: clicar na linha “Chats” minimizada restaura o phone.",
        "Janela de **novidades** depois de atualizar (esta), também pelas Opções.",
      } },
    { v = "0.5.0",
      en = {
        "**Professions in the top bar** with their levels and colors; click opens the profession.",
        "**Trainers** you visit are remembered and listed in the profession tooltip.",
        "Round profession icons; options gear button.",
      },
      pt = {
        "**Profissões na barra de cima** com nível e cores; clique abre a profissão.",
        "**Treinadores** visitados ficam salvos e aparecem no tooltip da profissão.",
        "Ícones redondos das profissões; botão de engrenagem para as opções.",
      } },
}

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, "Version") or "?"
end

function ns:ShowWhatsNew(force)
    local UI = MilkshaksonUI
    if not (UI and UI.WhatsNew) then return end
    UI:WhatsNew({ title = "Phone", version = Version(), notes = ns.NOTES,
        db = MilkshaksonPhoneDB, lang = ns.localeCode, force = force })
end

-- Options > About: the addon's description (About.lua, same text as the README / CurseForge page)
function ns:ShowAbout()
    local UI = MilkshaksonUI
    if not (UI and UI.About and ns.ABOUT) then return end
    UI:About({ title = "Phone", version = Version(), about = ns.ABOUT, lang = ns.localeCode })
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    f:UnregisterAllEvents()
    ns:ShowWhatsNew(false)
end)
