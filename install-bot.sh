#!/bin/bash
# INSTALL BOT TELEGRAM REGISTRASI IP VPS
# Author: MERCURYVPN / NIKU TUNNEL

clear
echo -e "\e[32m[•] Install Bot Telegram Registrasi IP VPS...\e[0m"

# Buat folder
mkdir -p /root/bot

# Install pip & dependensi python
apt update -y
apt install -y python3-pip
pip3 install --upgrade pip
pip3 install python-telegram-bot==20.3

# === FILE: /root/bot/config.json ===
cat > /root/bot/config.json <<EOF
{
  "token": "ISI_TOKEN_BOT_ANDA",
  "admin_id": 123456789,
  "allowed_file": "/root/bot/allowed.json"
}
EOF

# === FILE: /root/bot/allowed.json ===
cat > /root/bot/allowed.json <<EOF
[]
EOF

# === FILE: /root/bot/bot.py ===
cat > /root/bot/bot.py <<'EOF'
#!/usr/bin/env python3
import json, logging
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    CallbackQueryHandler,
    MessageHandler,
    filters,
    ConversationHandler,
)

logging.basicConfig(level=logging.INFO)

with open("/root/bot/config.json") as f:
    config = json.load(f)

TOKEN = config["token"]
ADMIN_ID = config["admin_id"]
FILE = config["allowed_file"]

data_temp = {}

def save(data):
    with open(FILE, "w") as f:
        json.dump(data, f, indent=2)

def load():
    with open(FILE) as f:
        return json.load(f)

def find_ip(data, ip):
    for i, entry in enumerate(data):
        if entry["ip"] == ip:
            return i
    return -1

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    keyboard = [
        [InlineKeyboardButton("➕ Tambah IP", callback_data="addip")],
        [InlineKeyboardButton("📄 List IP", callback_data="listip")],
        [
            InlineKeyboardButton("✏️ Edit Client", callback_data="editclient"),
            InlineKeyboardButton("🔁 Renew Expired", callback_data="renewip")
        ],
        [InlineKeyboardButton("🗑️ Hapus IP", callback_data="removeip")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text("🤖 Silakan pilih menu:", reply_markup=reply_markup)

async def handle_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    cmd = query.data
    if cmd == "addip":
        await query.edit_message_text("🖥️ Kirim IP VPS:")
        return 1
    elif cmd == "listip":
        return await listip_query(query, context)
    elif cmd == "editclient":
        await query.edit_message_text("✏️ Kirim IP yang mau diubah client-nya:")
        return 10
    elif cmd == "renewip":
        await query.edit_message_text("🔁 Kirim IP yang mau diperpanjang expired-nya:")
        return 20
    elif cmd == "removeip":
        await query.edit_message_text("🗑️ Kirim IP yang mau dihapus:")
        return 30

async def get_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    data_temp["ip"] = update.message.text.strip()
    await update.message.reply_text("✍️ Kirim nama client:")
    return 2

async def get_client(update: Update, context: ContextTypes.DEFAULT_TYPE):
    data_temp["client"] = update.message.text.strip()
    await update.message.reply_text("🕐 Kirim expired (jumlah hari atau YYYY-MM-DD):")
    return 3

async def get_expired(update: Update, context: ContextTypes.DEFAULT_TYPE):
    exp_input = update.message.text.strip()
    try:
        if exp_input.isdigit():
            exp = (datetime.now() + timedelta(days=int(exp_input))).strftime("%Y-%m-%d")
        else:
            exp = datetime.strptime(exp_input, "%Y-%m-%d").strftime("%Y-%m-%d")
    except:
        await update.message.reply_text("❌ Format salah. Contoh: 30 atau 2025-07-10")
        return 3
    ip = data_temp["ip"]
    client = data_temp["client"]
    data = load()
    if find_ip(data, ip) != -1:
        await update.message.reply_text("❌ IP sudah terdaftar.")
        return ConversationHandler.END
    data.append({"ip": ip, "client": client, "expired": exp})
    save(data)
    await update.message.reply_text(f"✅ IP {ip} ditambahkan.\nClient: {client}\nExpired: {exp}")
    return ConversationHandler.END

async def listip_query(query, context):
    data = load()
    if not data:
        await query.edit_message_text("❌ Belum ada IP terdaftar.")
        return ConversationHandler.END
    msg = "📋 Daftar IP Terdaftar:\n"
    for i, d in enumerate(data, 1):
        msg += f"{i}. {d['ip']} | {d['client']} | Exp: {d['expired']}\n"
    await query.edit_message_text(msg)
    return ConversationHandler.END

async def get_ip_edit(update: Update, context: ContextTypes.DEFAULT_TYPE):
    data_temp["ip"] = update.message.text.strip()
    await update.message.reply_text("🆕 Kirim nama client baru:")
    return 11

async def get_client_edit(update: Update, context: ContextTypes.DEFAULT_TYPE):
    new_client = update.message.text.strip()
    data = load()
    i = find_ip(data, data_temp["ip"])
    if i == -1:
        await update.message.reply_text("❌ IP tidak ditemukan.")
        return ConversationHandler.END
    data[i]["client"] = new_client
    save(data)
    await update.message.reply_text(f"✅ Client IP {data_temp['ip']} diubah ke {new_client}.")
    return ConversationHandler.END

async def get_ip_renew(update: Update, context: ContextTypes.DEFAULT_TYPE):
    data_temp["ip"] = update.message.text.strip()
    await update.message.reply_text("⏳ Kirim jumlah hari perpanjangan atau YYYY-MM-DD:")
    return 21

async def get_exp_renew(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = data_temp["ip"]
    data = load()
    i = find_ip(data, ip)
    if i == -1:
        await update.message.reply_text("❌ IP tidak ditemukan.")
        return ConversationHandler.END
    exp_input = update.message.text.strip()
    try:
        if exp_input.isdigit():
            exp = (datetime.now() + timedelta(days=int(exp_input))).strftime("%Y-%m-%d")
        else:
            exp = datetime.strptime(exp_input, "%Y-%m-%d").strftime("%Y-%m-%d")
    except:
        await update.message.reply_text("❌ Format salah. Contoh: 30 atau 2025-07-10")
        return 21
    data[i]["expired"] = exp
    save(data)
    await update.message.reply_text(f"✅ Expired IP {ip} diperpanjang ke {exp}.")
    return ConversationHandler.END

async def get_ip_remove(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = update.message.text.strip()
    data = load()
    i = find_ip(data, ip)
    if i == -1:
        await update.message.reply_text("❌ IP tidak ditemukan.")
        return ConversationHandler.END
    data.pop(i)
    save(data)
    await update.message.reply_text(f"🗑️ IP {ip} berhasil dihapus.")
    return ConversationHandler.END

def main():
    app = ApplicationBuilder().token(TOKEN).build()
    conv = ConversationHandler(
        entry_points=[CallbackQueryHandler(handle_menu)],
        states={
            1: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ip)],
            2: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_client)],
            3: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_expired)],
            10: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ip_edit)],
            11: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_client_edit)],
            20: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ip_renew)],
            21: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_exp_renew)],
            30: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_ip_remove)],
        },
        fallbacks=[],
        per_message=True,
    )
    app.add_handler(CommandHandler("start", start))
    app.add_handler(conv)
    print("✅ Bot polling dimulai...")
    app.run_polling()

if __name__ == "__main__":
    main()
EOF

# === FILE: /etc/systemd/system/bot.service ===
cat > /etc/systemd/system/bot.service <<EOF
[Unit]
Description=Bot Telegram Registrasi IP
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/bot/bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Set permission
chmod +x /root/bot/bot.py

# Enable & start service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable bot
systemctl restart bot

echo -e "\e[32m✅ BOT TELEGRAM SIAP DIGUNAKAN!\e[0m"
echo -e "\e[33mSilakan edit /root/bot/config.json dan isi token serta admin_id Anda.\e[0m"
