# Changelog - Milkshakson - Phone

## Unreleased
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
