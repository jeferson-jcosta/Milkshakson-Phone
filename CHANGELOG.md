# Changelog - Milkshakson - Phone

## Unreleased
- `/ph test`: sends a real whisper to yourself (to try the private chat); `/ph test fake`: a whisper that exists only on the phone.
- System and NPC messages grouped in one chat, "System & NPCs", always last in the list and quiet: no unread count and no last message, open it to read. Option "Monitor the System chat" (off by default) shows the count and last message. Both kept by default again (each can be switched off); a new message in the quiet chat redraws nothing while it is closed.
- Who (/who) shows the answer on the phone (name, level, race, class, zone, guild).
- "More (game menu)" opens the game's player menu with this client's menu API (UnitPopup), with the older ones as fallback.
- Player actions that fail show the error on the phone instead of doing nothing.
- Deleting the chat that is open closes it too (the right side goes back to "pick a chat").
- Fix: right-click did nothing on messages saved before the player menu existed (no full name); bubbles highlight on mouse over. `/ph status` shows the last click on the phone (shown on the phone itself).
- Players in the chat: right-click a message (or the name) from another player for a menu like the default chat's: Whisper, Invite to group, Invite to guild (if you can), Add friend, Who (/who), Copy name, Ignore, and the game's own menu. Left-click the name: private chat on the phone. Same actions on the name at the top of a private chat and on right-click of a private chat in the list.
- Channels other addons use only to send data (HarvestMate) are hidden. Right-click a channel: Hide this channel (`/ph show channels` brings them back).
- Auto-join never touches channels in combat (the game may block the addon); it waits for the end of the fight.
- Icons: Trade channels a coin, LocalDefense a sword, General a map, Nearby a group of people (NPCs got their own icon).
- Filters (options): keep system messages / NPC messages (when off they are not kept at all).
- Text colors by chat type (on by default): guild green, party blue, raid orange, whispers pink... taken from the game's own chat colors.
- Performance: redraws are grouped (at most ~4 per second, however busy the chat is); a new message only adds its bubble; the open chat draws its last 50 messages and loads 50 more when you scroll to the top; nothing is drawn while the phone is minimized or hidden.
- Fix: nothing was drawn (list rows and messages) — on WoW: Forever a masked icon can't be cropped (SetTexCoord error). Icons are no longer masked.
- Errors are shown on the phone (red box, click to close) instead of failing silently; last one saved in the settings.
- Joined channels read with GetChannelName (works on every client version).
- Always joins General, Trade and LocalDefense on login, /reload and zone change (only the ones you are not in; names in the client's language). Option to turn it off.
- Two panes, like a desktop messenger: chats on the left, the open chat on the right (no more back button). Opens the last chat on login.
- Always at the top of the left pane: party (or raid) and guild while you are in one, then the channels you are in (General, Trade, LocalDefense, LFG...), even with no messages yet. Muted chats show a grey count of new messages.
- Fix: messages and list rows could be invisible (the scrolling area started 10 px wide).
- Default size 560 x 480.

## 0.1.0
- First version (pilot): the chat as a phone messenger. One conversation per player (whispers, Battle.net), party, raid, instance, guild, officers, nearby (say / yell / emotes), each public channel, System and NPCs.
- Chats list (last message, time, unread badge, pin, mute) and conversation view (bubbles, names in class color, time, day separators, clickable links).
- Replaces the game's chat (option, on by default): the game's chat windows are hidden, the game's typing box sits on the phone and sends to the open conversation.
- When the game hides messages from addons (combat / encounters), the game's chat comes back with a warning until it ends.
- History per character; public channels and System / NPC start muted. `/ph probe` checks the client's chat API.
