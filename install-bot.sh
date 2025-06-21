#!/bin/bash
# INSTALLER BOT TELEGRAM REGISTRASI IP - NIKU TUNNEL (FINAL FIX)

clear
echo "🚀 Install bot Telegram registrasi IP..."

# =============== INPUT TOKEN & ADMIN ID ==================
read -p "Masukkan Token Bot Telegram: " token
read -p "Masukkan Admin ID Telegram: " admin_id

# =============== INSTALL PYTHON DEPENDENSI ===============
apt update -y
apt install -y python3 python3-pip nginx curl
pip3 install python-telegram-bot==13.15

mkdir -p /root/bot
cd /root/bot

# =============== SIMPAN config.json ======================
cat > config.json << EOF
{
  "token": "$token",
  "admin_id": $admin_id
}
EOF

# =============== SIMPAN bot.py ===========================
cat > bot.py << 'EOF'
import json
import logging
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import Updater, CommandHandler, CallbackContext, MessageHandler, Filters, CallbackQueryHandler, ConversationHandler

with open('config.json') as config_file:
    config = json.load(config_file)

TOKEN = config['token']
ADMIN_ID = config['admin_id']
ALLOWED_FILE = '/var/www/html/allowed.json'

logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)

def init_allowed():
    try:
        with open(ALLOWED_FILE, 'r') as f:
            data = json.load(f)
        if 'allowed_ips' not in data:
            raise ValueError("Format salah")
    except:
        with open(ALLOWED_FILE, 'w') as f:
            json.dump({"allowed_ips": []}, f)

def start(update: Update, context: CallbackContext):
    if update.effective_user.id != ADMIN_ID:
        return
    keyboard = [
        [InlineKeyboardButton("📥 Registrasi IP", callback_data='register')],
        [InlineKeyboardButton("📄 List IP", callback_data='list')],
        [InlineKeyboardButton("🗑️ Remove IP", callback_data='remove')],
        [InlineKeyboardButton("♻️ Renew IP", callback_data='renew')]
    ]
    update.message.reply_text("🔧 MENU BOT REGISTRASI IP:", reply_markup=InlineKeyboardMarkup(keyboard))

def button_handler(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    action = query.data

    if action == 'register':
        context.user_data.clear()
        query.message.reply_text("📝 Masukkan IP VPS:")
        return REG_IP
    elif action == 'list':
        with open(ALLOWED_FILE) as f:
            data = json.load(f)
        if not data['allowed_ips']:
            query.message.reply_text("📭 Tidak ada IP yang terdaftar.")
        else:
            msg = "📄 IP Teregistrasi:\n"
            for i, entry in enumerate(data['allowed_ips'], 1):
                msg += f"{i}. {entry['ip']} ({entry['name']}) - Exp: {entry['expired']}\n"
            query.message.reply_text(msg)
    elif action == 'remove':
        with open(ALLOWED_FILE) as f:
            data = json.load(f)
        if not data['allowed_ips']:
            query.message.reply_text("📭 Tidak ada IP yang bisa dihapus.")
            return
        keyboard = [[InlineKeyboardButton(entry['ip'], callback_data=f"del:{entry['ip']}")] for entry in data['allowed_ips']]
        query.message.reply_text("🗑️ Pilih IP yang ingin dihapus:", reply_markup=InlineKeyboardMarkup(keyboard))
    elif action == 'renew':
        context.user_data.clear()
        query.message.reply_text("♻️ Masukkan IP yang ingin diperpanjang:")
        return RENEW_IP

def delete_ip(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
#!/usr/bin/python3
import json, os, logging
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import (
    ApplicationBuilder, CommandHandler, MessageHandler, filters,
    CallbackQueryHandler, ConversationHandler, ContextTypes
)

TOKEN = "ISI_TOKEN_BOT"
ADMIN_ID = 123456789
ALLOWED_JSON = "/var/www/html/allowed.json"

logging.basicConfig(level=logging.INFO)

REGISTER_IP, REGISTER_CLIENT, REGISTER_LIMIT = range(3)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID: return
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
    if update.effective_user.id != ADMIN_ID: return
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
                return
            msg = "📄 IP Teregistrasi:\n\n"
            for entry in data:
                msg += f"• `{entry['ip']}` | 📌 {entry['client']} | ⏳ {entry['expired']}\n"
            await query.message.reply_text(msg, parse_mode="Markdown")
        else:
            await query.message.reply_text("❌ File allowed.json tidak ditemukan.")
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
                await update.message.reply_text(f"🗑️ IP `{ip}` dihapus.", parse_mode="Markdown")
            elif context.user_data["mode"] == "renew":
                context.user_data["renew_ip"] = ip
                await update.message.reply_text("⏳ Masukkan tambahan hari:")
                return REGISTER_LIMIT
            break
    if not found:
        await update.message.reply_text("❌ IP tidak ditemukan.")
    with open(ALLOWED_JSON, "w") as f:
        json.dump(data, f, indent=2)
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
            REGISTER_IP: [MessageHandler(filters.TEXT, handle_ip_based_on_mode)],
            REGISTER_CLIENT: [MessageHandler(filters.TEXT, handle_register_client)],
            REGISTER_LIMIT: [MessageHandler(filters.TEXT, handle_register_limit), MessageHandler(filters.TEXT, handle_renew_limit)],
        },
        fallbacks=[],
    )
    app.add_handler(CommandHandler("start", start))
    app.add_handler(conv_handler)
    app.run_polling()

if __name__ == "__main__":
    main()
EOF

# =============== BUAT allowed.json ========================
mkdir -p /var/www/html
cat > /var/www/html/allowed.json << EOF
{
  "allowed_ips": []
}
EOF

# =============== SYSTEMD bot.service ======================
cat > /etc/systemd/system/bot.service << EOF
[Unit]
Description=Telegram Bot Registrasi IP
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/bot/bot.py
WorkingDirectory=/root/bot
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# =============== AKTIFKAN BOT =============================
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable bot
systemctl start bot

# =============== SELESAI ===========================
echo ""
echo "✅ Bot Telegram berhasil dipasang dan aktif!"
echo "🔎 Cek status dengan: systemctl status bot"
