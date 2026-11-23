# Changelog - Milkshakson - Phone

## Unreleased
- Option (on by default; uses the frame's own IsMouseOver): when minimized, the mouse over the phone opens it and leaving minimizes it again (after half a second; not while typing or with a menu open). Clicking _ while it is open this way minimizes it until the mouse leaves.
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
