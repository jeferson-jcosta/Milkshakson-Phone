# Milkshakson - Phone

Your chat as a **phone messenger**. Instead of one stream mixing whispers, guild, party, trade and loot, every player, group and channel gets its **own conversation**:

- **Two panes**: chats on the left, the open chat on the right.
- **Always on top**: party / raid and guild while you are in one, then the channels you are in (General, Trade, LocalDefense, LFG...).
- **Chats list**: one line per conversation with the last message, the time and an unread badge. Newest first; pin the ones you care about to the top.
- **Conversation**: bubbles (yours on the right, theirs on the left), sender name in group chats (class color), time on each message, day separators (Today, Yesterday, date). Item / quest links stay clickable.
- **Replaces the game's chat** (on by default): the game's chat windows are hidden and the typing box sits on the phone. Open a conversation and press Enter, or click the bottom bar: you type straight to that player / group / channel. Slash commands work as usual.
- Public channels (Trade, General...) and System / NPC messages are saved but **muted** by default (no badge). Right-click a chat: pin, mute, clear, delete.
- History per character, kept between sessions.

Only the game API is used; no other addon needed.

**The game hides chat messages from addons in some situations** (combat / encounters on this client). When that happens the phone shows a warning and the game's own chat comes back until it ends, so no message is lost.

## Commands

| Command | |
| --- | --- |
| `/ph` (also `/mph`, `/phone`, `/mphone`) | Minimize / restore |
| `/ph chat on` / `off` | Replace the game's chat, or keep it and use the phone as an extra window |
| `/ph config` | Options |
| `/ph status` | Chats, messages, unread |
| `/ph probe` | Checks the chat API this game client has |
| `/ph reset` | Reset position and size |
| `/ph clear` | Delete all chats of this character (asks first) |
| `/ph lang <code\|auto>` | Language |

## License

MIT
