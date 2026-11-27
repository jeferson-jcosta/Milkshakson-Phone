# Changelog - Milkshakson - Phone

## Unreleased
- Drawer initials: joined words count as words ("LocalDefense" -> LD, not LO; "LookingForGroup" -> LF).
- **Professions** chat: every skill up ("Tailoring rose to 45") gets its own conversation with a badge and preview, and a pill while the phone is minimized (they used to go to the quiet System chat). Option "Professions chat (skill ups)" (on); any client language.
- New layout: one **top bar** across the whole phone (drawer arrow over the icons column, search, options, -/+); the open chat's header (icon, name, copy) sits inside the chat pane, under it. The minimized phone is a bit lower (34 px bar).
- Chats have a thin **scroll bar** on the right (drag the thumb or click the track; dragging to the top loads older messages, like the wheel). Hidden when everything fits.
- **Message text size** option, separate from the phone's font size (list, headers, typing bar). Until you change it, it follows the phone's size.
- **Drawer:** the chats list starts collapsed to its icons (64 px) with each chat's initials on the icon (hover: name and last message); the arrow in the chats header opens / collapses it (the game's arrow icons). Slides when animations are on. Also in Options and `/ph drawer` (`/ph gaveta`).
- The search box moved up into the top bar (where "Chats" is shown while minimized); it also works with the list collapsed.
- **Loot rolls** chat: one message per item rolled on in your group — who chose Need, Greed, Disenchant or Pass (with the roll numbers, highest first) and who won it ("Everyone passed" too). Read from the game's loot messages in any client language. Option "Loot rolls chat" (on). In a dungeon or raid it sits right under the group chat.
- The Milkshakson addons show their messages in one "Milkshakson-Addons" conversation on the phone, each line tagged with the addon: `MilkshaksonPhone_AddonMessage(addon, text)` (used by Milkshakson-Trader). The game's chat window is hidden while the phone replaces it, so their chat messages were lost.

## 0.3.4
- Fix: "Milkshakson-Phone has been blocked from an action" on ESC (SpellStopCasting / SpellStopTargeting). Phone re-assigned the game's `StaticPopupDialogs` table at login, which tainted every dialog check the game does on ESC. Now it only adds its own dialog to it.

## 0.3.3
- Fix: pressing ESC could make the game block "SpellStopCasting" and offer to disable addons (seen in dungeons). The phone no longer opens the game's own player menu ("More (game menu)" removed; shift/ctrl-click on a name does nothing): opening it from addon code tainted the game's ESC handling. The phone's player menu keeps whisper, invite, guild invite, add friend, /who, copy name and ignore.
- While the phone replaces the chat, no other chat shows: the game's chat no longer comes back during combat / encounters (only the banner; messages the game hides from addons are not shown then), and **EllesmereUI Chat**'s panels are hidden too (through its own visibility rule, its settings are not changed).
- Auto-join (General/Trade/LocalDefense) is skipped inside instances and while the game locks chat.
- Resize the phone by dragging any border or corner (not only the grip at the bottom right). Off while "Lock position and size" is on or the phone is minimized.

## 0.3.2
- Fix: the **Archived** folder did not open (clicking it raised an error).

## 0.3.1
- Option: minimize when not used for 5 minutes (0 - 30, 0 = off). Not used = no mouse over the phone, no typing, no menu open; new messages do not count.

## 0.3.0
- Private chats with nothing new for 2 hours (option, 0 = off) go after the channels (General, Trade...); a new message brings them back up; unread ones stay up.
- Options and -/+ only in the chats header (always there, also minimized); the chat header keeps just the copy button.
- Fix: the Combat chat said the phone was not replacing the game's chat when it was open on /reload (the log now goes in when the phone takes the chat).
- New "Combat" chat (before System in the list): the game's own Combat Log window inside the phone. On WoW: Forever addons can't read the combat log (no API, and its lines are protected), so there is no summary. Option, on by default.
- Search box at the top of the chats list: shows the chats whose name or messages match (newest match first, with the count), and an opened chat shows only the matching messages, with the term highlighted. x or Esc clears it.
- Copy: the copy button at the top of a chat (or right-click a chat in the list) opens the whole chat as plain text, selected, in a window - Ctrl+C copies it. Right-click a message: Copy message (also for your own). Links become plain text.
- Archived: private chats with nothing new for 3 days (option, 0 = never) go to "Archived (N)" at the end of the list (with their unread count); click it to see them, "Back" to return. A new message brings a chat back. Right-click a private chat: Archive / Unarchive.
- Joining a new group clears the group chat (party, raid, instance). Option, on by default.
- Option (on by default): minimize when combat starts; it opens again when the fight ends, if combat was what minimized it.
- Every bubble uses the whole width of the chat (same margin on both sides), so the edges line up; your messages keep the text on the right. Option "Bubbles fit their text" for the previous look.
- Fix: your own messages in channels, guild and group showed as someone else's (left side, with your name). On Forever names have a last name, so you are now recognized by your GUID; old saved messages are fixed by your full name.
- Option: message alignment - Messenger (yours on the right, default), All on the left, All on the right. Your bubbles stay green.
- Option: font size of the phone (0.80x - 1.60x of the game's size), for every text; list rows grow with it; applied at once.
- Minimized: a click on the "Chats" header restores the phone (dragging it still moves it).
- Typing while minimized (Enter, "/" for a command, "r" to reply) no longer restores the phone: the typing box shows over the header while you type and goes away after sending or Escape.

## 0.2.1
- Fix: minimized, the game's typing box (always shown with some chat styles) covered the count pills, so the mouse over a pill did nothing. While minimized it is moved below the phone (outside its area), invisible and click-through, so it covers neither the pills nor the + button; Enter restores the phone.
- Chat names in the list and at the top of the open chat colored by type: Guild green, Party blue, Raid orange, Officers, channels in their own color (players keep their class color). Follows the "text colors by chat type" option.

## 0.2.0
- Minimize / restore buttons are the game's - / + buttons (as in Ready Quests).
- Smooth transition when minimizing / restoring: the height eases, the content fades in when restoring and fades out (before hiding) when minimizing. Option, on by default, with the time set by a slider (0.05 - 1 s, default 0.25 s).
- Option (on by default): when minimized, the mouse over a count pill (Guild, Party, Whispers) opens the phone right on that chat; leaving minimizes it again (after half a second; not while typing or with a menu open). A click on it while it is open this way restores it for good; - minimizes it until the mouse leaves.
- Minimized: colored count pills for Guild (green), Party / Raid (blue / orange) and Whispers (pink), in the game's chat colors, only when there is something unread. Click one to open that chat (whispers: the latest).

## 0.1.0
First version: the chat as a phone messenger.
- Two panes: chats on the left, the open chat on the right, in bubbles (yours on the right), with sender names in class color, time, day separators and clickable links.
- One chat per player (whispers, Battle.net), party, raid, instance, guild, officers, nearby (say / yell / emotes) and each channel.
- Always on top: party / raid and guild while you are in one, then General, Trade, LocalDefense and the other channels you are in. Joins General, Trade and LocalDefense by itself on login, /reload and zone change (never in combat; option).
- Replaces the game's chat (option, on by default): the game's typing box sits on the phone and types to the open chat; slash commands work as usual.
- System and NPC messages in one quiet chat at the end of the list (no count, no last message unless you monitor it); each can be switched off.
- Text colored by chat type (game's chat colors); icons for Trade (coin), LocalDefense (sword), General (map), Nearby (people).
- Players: right-click a message for whisper, invite to group / guild, add friend, /who (answer on the phone), copy name, ignore and the game's own menu; click a name for a private chat.
- Unread counts (grey for muted chats), pin, mute, clear, delete; channels used only by other addons (HarvestMate) are hidden, and any channel can be hidden.
- When the game hides messages from addons (combat / encounters), the game's chat comes back with a warning until it ends.
- Light on performance: grouped redraws, new messages only add their bubble, 50 messages at a time, nothing drawn while minimized.
- Errors are shown on the phone. `/ph probe`, `/ph status`, `/ph test` for diagnostics.
