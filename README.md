# Milkshakson - Phone

Your chat as a **phone messenger**. Instead of one stream mixing whispers, guild, party, trade and loot, every player, group and channel gets its **own conversation**:

- **Always in General, Trade and LocalDefense**: joins them by itself on login, /reload and zone change (option).
- **Two panes**: chats on the left, the open chat on the right.
- **Always on top**: party / raid and guild while you are in one, then the channels you are in (General, Trade, LocalDefense, LFG...).
- **Chats list**: one line per conversation with the last message, the time and an unread badge. Newest first; pin the ones you care about to the top.
- **Conversation**: bubbles (yours on the right, theirs on the left), sender name in group chats (class color), time on each message, day separators (Today, Yesterday, date). Item / quest links stay clickable.
- **Replaces the game's chat** (on by default): the game's chat windows are hidden and the typing box sits on the phone. Open a conversation and press Enter, or click the bottom bar: you type straight to that player / group / channel. Slash commands work as usual.
- **Combat**: your biggest hit per spell (and your pet's), plus the game's combat log.
- **System & NPCs** in one quiet chat at the end of the list (no badge, no last message; option to monitor it). Each can be switched off.
- **Search**: find chats and messages (name or text), matches highlighted.
- **Colors**: text colored by chat type (guild green, party blue...), using the game's chat colors.
- **Players**: right-click a message for whisper, invite to group / guild, add friend, /who, copy name, ignore (and the game's own menu). Click a name to talk to them privately.
- Public channels (Trade, General...) start **muted** (grey count instead of a green badge). Right-click a chat: pin, mute, clear, delete.
- History per character, kept between sessions.

Light on performance: redraws are grouped, new messages only add their bubble, 50 messages at a time (scroll up for more), nothing drawn while minimized.

Only the game API is used; no other addon needed.

**The game hides chat messages from addons in some situations** (combat / encounters on this client). When that happens the phone shows a warning and the game's own chat comes back until it ends, so no message is lost.

## Commands

| Command | |
| --- | --- |
| `/ph` (also `/mph`, `/phone`, `/mphone`) | Minimize / restore |
| `/ph chat on` / `off` | Replace the game's chat, or keep it and use the phone as an extra window |
| `/ph config` | Options |
| `/ph test` / `/ph test fake` | A real whisper to yourself / a pretend one (only on the phone), to try it |
| `/ph status` | Chats, messages, unread |
| `/ph probe` | Checks the chat API this game client has |
| `/ph reset` | Reset position and size |
| `/ph clear` | Delete all chats of this character (asks first) |
| `/ph lang <code\|auto>` | Language |

## License

MIT
