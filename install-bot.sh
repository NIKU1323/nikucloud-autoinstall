#!/bin/bash

BOT_DIR="/root/bot"
ALLOWED_JSON="/var/www/html/allowed.json"
SERVICE_FILE="/etc/systemd/system/bot.service"

echo "Starting install Telegram bot registrasi IP..."

apt update -y
apt install -y python3 python3-pip

mkdir -p $BOT_DIR

pip3 install python-telegram-bot==20.8

cat > $BOT_DIR/bot.py <<'EOF'
#!/usr/bin/python3
import json, os, logging
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import (
    ApplicationBuilder, CommandHandler, MessageHandler, filters,
    CallbackQueryHandler, ConversationHandler, ContextTypes
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")
ALLOWED_JSON = "/var/www/html/allowed.json"

logging.basicConfig(level=logging.INFO)

with open(CONFIG_PATH) as config_file:
    config = json.load(config_file)

TOKEN = config.get("token", "")
ADMIN_ID = config.get("admin_id", 0)

REGISTER_IP, REGISTER_CLIENT, REGISTER_LIMIT, RENEW_LIMIT = range(4)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    keyboard = [
        [InlineKeyboardButton("📝 REGISTRASI IP", callback_data="register")],
        [InlineKeyboardButton("📃 LIST IP", callback_data="list")],
        [InlineKeyboardButton("🗑️ REMOVE IP", callback_data="remove")],
        [InlineKeyboardButton("🔁 RENEW IP", callback_data="renew")],
    ]
    await update.message.reply_text("📡 *MENU REGISTRASI IP VPS*", parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard))

async def menu_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if update.effective_user.id != ADMIN_ID:
        return
    if query.data == "register":
        context.user_data["mode"] = "register"
        await query.message.reply_text("📥 Masukkan IP VPS:")
        return REGISTER_IP
    elif query.data == "list":
        if os.path.exists(ALLOWED_JSON):
            with open(ALLOWED_JSON, "r") as f:
                data = json.load(f)
            if not data:
                await query.message.reply_text("📂 Belum ada IP yang teregistrasi.")
                return ConversationHandler.END
            msg = "📄 IP Teregistrasi:\n\n"
            for entry in data:
                msg += f"• `{entry['ip']}` | 📌 {entry['client']} | ⏳ {entry['expired']}\n"
            await query.message.reply_text(msg, parse_mode="Markdown")
        else:
            await query.message.reply_text("❌ File allowed.json tidak ditemukan.")
        return ConversationHandler.END
    elif query.data == "remove":
        context.user_data["mode"] = "remove"
        await query.message.reply_text("🗑️ Masukkan IP yang ingin dihapus:")
        return REGISTER_IP
    elif query.data == "renew":
        context.user_data["mode"] = "renew"
        await query.message.reply_text("♻️ Masukkan IP yang ingin diperpanjang:")
        return REGISTER_IP

async def handle_ip_based_on_mode(update: Update, context: ContextTypes.DEFAULT_TYPE):
    mode = context.user_data.get("mode")
    if mode == "remove" or mode == "renew":
        return await handle_remove_or_renew(update, context)
    else:
        return await handle_register_ip(update, context)

async def handle_register_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["ip"] = update.message.text.strip()
    await update.message.reply_text("✏️ Masukkan nama client:")
    return REGISTER_CLIENT

async def handle_register_client(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["client"] = update.message.text.strip()
    await update.message.reply_text("⏳ Masukkan masa aktif (hari):")
    return REGISTER_LIMIT

async def handle_register_limit(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = context.user_data["ip"]
    client = context.user_data["client"]
    try:
        days = int(update.message.text.strip())
        expired = (datetime.now() + timedelta(days=days)).strftime("%Y-%m-%d")
        data = []
        if os.path.exists(ALLOWED_JSON):
            with open(ALLOWED_JSON, "r") as f:
                data = json.load(f)
        updated = False
        for entry in data:
            if entry["ip"] == ip:
                entry["client"] = client
                entry["expired"] = expired
                updated = True
                break
        if not updated:
            data.append({"ip": ip, "client": client, "expired": expired})
        with open(ALLOWED_JSON, "w") as f:
            json.dump(data, f, indent=2)
        await update.message.reply_text(f"✅ IP `{ip}` didaftarkan\n📌 {client} ⏳ {expired}", parse_mode="Markdown")
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {e}")
    return ConversationHandler.END

async def handle_remove_or_renew(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = update.message.text.strip()
    if not os.path.exists(ALLOWED_JSON):
        await update.message.reply_text("❌ File not found.")
        return ConversationHandler.END

    with open(ALLOWED_JSON, "r") as f:
        data = json.load(f)

    found = False
    for entry in data:
        if entry["ip"] == ip:
            found = True
            if context.user_data["mode"] == "remove":
                data.remove(entry)
                with open(ALLOWED_JSON, "w") as f:
                    json.dump(data, f, indent=2)
                await update.message.reply_text(f"🗑️ IP `{ip}` berhasil dihapus.", parse_mode="Markdown")
                return ConversationHandler.END
            elif context.user_data["mode"] == "renew":
                context.user_data["renew_ip"] = ip
                await update.message.reply_text("⏳ Masukkan tambahan hari:")
                return RENEW_LIMIT
            break

    if not found:
        await update.message.reply_text("❌ IP tidak ditemukan.")
    return ConversationHandler.END

async def handle_renew_limit(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        days = int(update.message.text.strip())
        ip = context.user_data["renew_ip"]
        with open(ALLOWED_JSON, "r") as f:
            data = json.load(f)
        for entry in data:
            if entry["ip"] == ip:
                entry["expired"] = (datetime.now() + timedelta(days=days)).strftime("%Y-%m-%d")
        with open(ALLOWED_JSON, "w") as f:
            json.dump(data, f, indent=2)
        await update.message.reply_text(f"♻️ IP `{ip}` diperpanjang.", parse_mode="Markdown")
    except Exception as e:
        await update.message.reply_text(f"❌ Gagal: {e}")
    return ConversationHandler.END

def main():
    app = ApplicationBuilder().token(TOKEN).build()
    conv_handler = ConversationHandler(
        entry_points=[CallbackQueryHandler(menu_callback)],
        states={
            REGISTER_IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_ip_based_on_mode)],
            REGISTER_CLIENT: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_register_client)],
            REGISTER_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_register_limit)],
            RENEW_LIMIT: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_renew_limit)],
        },
        fallbacks=[],
    )
    app.add_handler(CommandHandler("start", start))
    app.add_handler(conv_handler)
    app.run_polling()

if __name__ == "__main__":
    main()
EOF

cat > $BOT_DIR/config.json <<EOF
{
  "token": "ISI_TOKEN_BOT",
  "admin_id": 123456789
}
EOF

mkdir -p /var/www/html
touch $ALLOWED_JSON
echo "[]" > $ALLOWED_JSON
chmod 666 $ALLOWED_JSON

cat > $SERVICE_FILE <<EOF
[Unit]
Description=Telegram Bot Registrasi IP
After=network.target

[Service]
ExecStart=/usr/bin/python3 $BOT_DIR/bot.py
WorkingDirectory=$BOT_DIR
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bot.service
systemctl restart bot.service

echo "Install selesai! Jangan lupa edit $BOT_DIR/config.json untuk token dan admin_id."
echo "Service bot sudah berjalan."
