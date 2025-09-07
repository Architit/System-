from telethon import TelegramClient, events
import asyncio
from pathlib import Path

# === Telegram System Bridge (v2) ===
#
# This script connects your Telegram account to your system and allows two-way
# communication. It listens for messages in a designated chat and responds
# appropriately. It supports basic commands:
#   /status - Check if the system is active
#   /sync   - Trigger a mock synchronization process
#   /exit   - Gracefully stop the bridge
# For all other messages, it will acknowledge receipt.

# ---- YOUR API CREDENTIALS ----
# Replace these values with the API ID and API hash you obtained from
# https://my.telegram.org/apps
api_id = 29733161  # your api_id (integer)
api_hash = "5e20b318c6ca61baba3229fcf35e85ca"  # your api_hash (string)

session_name = "system_channel"  # session file name (.session will be created)

# File used to remember the selected system chat. The chat ID of the first chat
# that sends a message to the bridge will be stored here. Subsequent messages
# from other chats will be ignored unless this file is deleted.
CHAT_FILE = Path("system_chat.txt")

# Initialize the Telegram client
client = TelegramClient(session_name, api_id, api_hash)


async def get_saved_chat_id():
    """Read the saved chat ID from CHAT_FILE if it exists."""
    if CHAT_FILE.exists():
        try:
            return int(CHAT_FILE.read_text().strip())
        except Exception:
            return None
    return None


async def set_saved_chat_id(chat_id: int):
    """Persist the selected chat ID to CHAT_FILE."""
    CHAT_FILE.write_text(str(chat_id))


@client.on(events.NewMessage)
async def on_message(event):
    """Handle incoming messages from Telegram."""
    # Retrieve the stored chat ID, if any
    saved_chat_id = await get_saved_chat_id()

    # If no chat has been selected yet, use the first incoming chat
    if saved_chat_id is None:
        await set_saved_chat_id(event.chat_id)
        await event.reply("🛰️ Канал системы привязан к этому чату.")
        print(f"[init] Selected system chat_id: {event.chat_id}")
        return

    # Ignore messages from other chats
    if event.chat_id != saved_chat_id:
        return

    # Normalize the message text
    text = (event.raw_text or "").strip()
    print(f"[in] {text}")

    # Command handling
    lower_text = text.lower()
    if lower_text == "/status":
        await event.reply("⚡ Система активна и на связи ✅")
    elif lower_text == "/sync":
        await event.reply("🔄 Синхронизация запущена…")
    elif lower_text == "/exit":
        # Gracefully stop the client
        await event.reply("⛔ Останавливаю мост…")
        await asyncio.sleep(0.5)
        await client.disconnect()
    else:
        # Acknowledge receipt of any other message
        await event.reply("✅ Получено")


def main():
    """Start the Telegram client and run until disconnected."""
    print("=== Telegram System Bridge (v2) ===")
    client.start()
    client.run_until_disconnected()


if __name__ == "__main__":
    main()