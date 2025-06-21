#!/bin/bash
# INSTALLER BOT TELEGRAM REGISTRASI IP - NIKU TUNNEL

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
from telegram.ext import (
    Updater, CommandHandler, CallbackContext, MessageHandler, Filters,
    CallbackQueryHandler, ConversationHandler
)

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
            msg = "📄 IP Teregistrasi:
"
            for i, entry in enumerate(data['allowed_ips'], 1):
                msg += f"{i}. {entry['ip']} ({entry['name']}) - Exp: {entry['expired']}
"
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
    ip_to_delete = query.data.split(":")[1]
    with open(ALLOWED_FILE) as f:
        data = json.load(f)
    data['allowed_ips'] = [entry for entry in data['allowed_ips'] if entry['ip'] != ip_to_delete]
    with open(ALLOWED_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    query.message.reply_text(f"✅ IP {ip_to_delete} berhasil dihapus.")

REG_IP, REG_NAME, REG_LIMIT = range(3)

def reg_ip(update: Update, context: CallbackContext):
    context.user_data['ip'] = update.message.text
    update.message.reply_text("🧾 Masukkan nama client:")
    return REG_NAME

def reg_name(update: Update, context: CallbackContext):
    context.user_data['name'] = update.message.text
    update.message.reply_text("📅 Masukkan durasi hari (7/15/30):")
    return REG_LIMIT

def reg_limit(update: Update, context: CallbackContext):
    try:
        days = int(update.message.text)
        if days not in [7, 15, 30]:
            raise ValueError()
    except:
        update.message.reply_text("⚠️ Masukkan angka hari yang valid (7/15/30):")
        return REG_LIMIT
    expire_date = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
    new_entry = {
        "ip": context.user_data['ip'],
        "name": context.user_data['name'],
        "expired": expire_date
    }
    with open(ALLOWED_FILE) as f:
        data = json.load(f)
    data['allowed_ips'].append(new_entry)
    with open(ALLOWED_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    update.message.reply_text(f"✅ IP {new_entry['ip']} berhasil diregistrasi hingga {expire_date}.")
    return ConversationHandler.END

RENEW_IP, RENEW_LIMIT = range(2)

def renew_ip(update: Update, context: CallbackContext):
    context.user_data['renew_ip'] = update.message.text
    update.message.reply_text("🕒 Masukkan durasi perpanjangan (7/15/30):")
    return RENEW_LIMIT

def renew_limit(update: Update, context: CallbackContext):
    try:
        days = int(update.message.text)
        if days not in [7, 15, 30]:
            raise ValueError()
    except:
        update.message.reply_text("⚠️ Masukkan angka hari yang valid (7/15/30):")
        return RENEW_LIMIT
    new_exp = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
    with open(ALLOWED_FILE) as f:
        data = json.load(f)
    found = False
    for entry in data['allowed_ips']:
        if entry['ip'] == context.user_data['renew_ip']:
            entry['expired'] = new_exp
            found = True
            break
    if not found:
        update.message.reply_text("❌ IP tidak ditemukan.")
        return ConversationHandler.END
    with open(ALLOWED_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    update.message.reply_text(f"♻️ IP berhasil diperpanjang hingga {new_exp}.")
    return ConversationHandler.END

def cancel(update: Update, context: CallbackContext):
    update.message.reply_text("❌ Dibatalkan.")
    return ConversationHandler.END

def main():
    init_allowed()
    updater = Updater(token=TOKEN, use_context=True)
    dp = updater.dispatcher

    dp.add_handler(CommandHandler("start", start))
    dp.add_handler(CallbackQueryHandler(button_handler, pattern="^(register|list|remove|renew)$"))
    dp.add_handler(CallbackQueryHandler(delete_ip, pattern="^del:"))

    dp.add_handler(ConversationHandler(
        entry_points=[CallbackQueryHandler(button_handler, pattern='^register$')],
        states={
            REG_IP: [MessageHandler(Filters.text & ~Filters.command, reg_ip)],
            REG_NAME: [MessageHandler(Filters.text & ~Filters.command, reg_name)],
            REG_LIMIT: [MessageHandler(Filters.text & ~Filters.command, reg_limit)],
        },
        fallbacks=[CommandHandler('cancel', cancel)]
    ))

    dp.add_handler(ConversationHandler(
        entry_points=[CallbackQueryHandler(button_handler, pattern='^renew$')],
        states={
            RENEW_IP: [MessageHandler(Filters.text & ~Filters.command, renew_ip)],
            RENEW_LIMIT: [MessageHandler(Filters.text & ~Filters.command, renew_limit)],
        },
        fallbacks=[CommandHandler('cancel', cancel)]
    ))

    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
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
