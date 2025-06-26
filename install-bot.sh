#!/bin/bash
# File: install-bot.sh
# Auto setup Telegram bot registrasi IP VPS via Docker + systemd

set -e

BOT_DIR="/opt/niku-bot"
BOT_IMAGE="python:3.11"
SERVICE_NAME="niku-bot.service"

# Install Docker
if ! command -v docker &>/dev/null; then
  echo -e "[INFO] Menginstall Docker..."
  apt update && apt install -y docker.io
  systemctl enable docker --now
fi

# Buat direktori dan file config
mkdir -p $BOT_DIR
cd $BOT_DIR

cat > config.json <<EOF
{
  "token": "ISI_TOKEN_BOT_TELEGRAM"
}
EOF

cat > allowed.json <<EOF
{
  "authorized_ips": []
}
EOF

cat > users.json <<EOF
{}
EOF

# Unduh bot.py
cat > bot.py <<'EOF'
import json, logging, ipaddress, os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ContextTypes, filters, ConversationHandler
)

logging.basicConfig(format="%(asctime)s - %(message)s", level=logging.INFO)

CONFIG_FILE = "config.json"
ALLOWED_FILE = "allowed.json"
USERS_FILE = "users.json"

with open(CONFIG_FILE) as f:
    config = json.load(f)

if not os.path.exists(ALLOWED_FILE):
    with open(ALLOWED_FILE, 'w') as f:
        json.dump({"authorized_ips": []}, f)

if not os.path.exists(USERS_FILE):
    with open(USERS_FILE, 'w') as f:
        json.dump({}, f)

(REGISTER_IP, INPUT_NAME, INPUT_DAY, TOPUP_SALDO, TARGET_USER,
 ROLE_SELECT, BROADCAST_MSG, REMOVE_IP, RENEW_IP) = range(9)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    users = load_users()
    role = users.get(user_id, {}).get("role", "user")

    buttons = [
        [InlineKeyboardButton("🔐 Registrasi IP", callback_data="regip")],
        [InlineKeyboardButton("💰 Top Up Saldo", callback_data="topup")],
        [InlineKeyboardButton("♻️ Renew IP", callback_data="renew")],
        [InlineKeyboardButton("❌ Hapus IP", callback_data="delip")],
    ]
    if role in ["admin", "reseller"]:
        buttons += [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="addsaldo"),
             InlineKeyboardButton("➖ Kurangi Saldo", callback_data="remsaldo")],
            [InlineKeyboardButton("🔄 Edit Role", callback_data="editrole")],
            [InlineKeyboardButton("⚙️ Maintenance Mode", callback_data="maint")],
            [InlineKeyboardButton("📢 Broadcast Pesan", callback_data="broadcast")],
        ]

    await update.message.reply_text(
        "🛡️ *MERCURY VPN — Panel IP VPS*

Silakan pilih menu:",
        reply_markup=InlineKeyboardMarkup(buttons), parse_mode="Markdown"
    )

def load_users():
    with open(USERS_FILE) as f:
        return json.load(f)

def save_users(users):
    with open(USERS_FILE, 'w') as f:
        json.dump(users, f, indent=2)

def load_allowed():
    with open(ALLOWED_FILE) as f:
        return json.load(f)

def save_allowed(data):
    with open(ALLOWED_FILE, 'w') as f:
        json.dump(data, f, indent=2)

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    if data == "regip":
        context.user_data["reg_step"] = "ip"
        await query.message.reply_text("🔐 Masukkan IP VPS yang ingin diregistrasikan:")
        return REGISTER_IP
    elif data == "topup":
        context.user_data["topup"] = True
        await query.message.reply_text("💰 Masukkan jumlah saldo:")
        return TOPUP_SALDO
    elif data == "delip":
        context.user_data["delip"] = True
        await query.message.reply_text("❌ Masukkan IP yang ingin dihapus:")
        return REMOVE_IP
    elif data == "renew":
        context.user_data["renew"] = True
        await query.message.reply_text("♻️ Masukkan IP yang ingin diperpanjang:")
        return RENEW_IP
    elif data == "broadcast":
        context.user_data["broadcast_msg"] = True
        await query.message.reply_text("📢 Ketik pesan broadcast:")
        return BROADCAST_MSG
    elif data == "addsaldo":
        context.user_data["modsaldo"] = "add"
        await query.message.reply_text("🟢 Format: IDTelegram Nominal
Contoh: 12345678 5000")
        return TARGET_USER
    elif data == "remsaldo":
        context.user_data["modsaldo"] = "rem"
        await query.message.reply_text("🔴 Format: IDTelegram Nominal
Contoh: 12345678 500")
        return TARGET_USER
    elif data == "editrole":
        context.user_data["role_select"] = True
        await query.message.reply_text("🔄 Format: IDTelegram RoleBaru
Contoh: 12345678 reseller")
        return ROLE_SELECT
    elif data == "maint":
        context.bot_data['maintenance'] = not context.bot_data.get('maintenance', False)
        await query.message.reply_text(f"⚙️ Maintenance Mode: {'AKTIF' if context.bot_data['maintenance'] else 'NONAKTIF'}")
        return ConversationHandler.END

async def message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    text = update.message.text.strip()
    users = load_users()
    allowed = load_allowed()

    if context.user_data.get("reg_step") == "ip":
        try:
            ipaddress.ip_address(text)
            context.user_data["ip"] = text
            context.user_data["reg_step"] = "name"
            await update.message.reply_text("📝 Masukkan nama client:")
        except:
            await update.message.reply_text("❌ IP tidak valid.")
        return
    if context.user_data.get("reg_step") == "name":
        context.user_data["name"] = text
        context.user_data["reg_step"] = "day"
        await update.message.reply_text("📅 Masukkan masa aktif (1-60 hari):")
        return
    if context.user_data.get("reg_step") == "day":
        try:
            days = int(text)
            ip = context.user_data["ip"]
            name = context.user_data["name"]
            allowed["authorized_ips"].append({"ip": ip, "name": name, "days": days})
            save_allowed(allowed)
            context.user_data.clear()
            await update.message.reply_text(f"✅ IP *{ip}* berhasil diregistrasi atas nama *{name}* selama *{days}* hari", parse_mode="Markdown")
        except:
            await update.message.reply_text("❌ Masukkan angka 1-60.")
        return

    if context.user_data.get("topup"):
        try:
            amount = int(text)
            users.setdefault(user_id, {"saldo": 0, "role": "user"})
            users[user_id]["saldo"] += amount
            save_users(users)
            context.user_data.pop("topup")
            await update.message.reply_text(f"✅ Saldo berhasil ditambah: {amount}.")
        except:
            await update.message.reply_text("❌ Format tidak valid.")
        return

    if context.user_data.get("modsaldo"):
        try:
            target, nominal = text.split()
            nominal = int(nominal)
            users.setdefault(target, {"saldo": 0, "role": "user"})
            if context.user_data["modsaldo"] == "add":
                users[target]["saldo"] += nominal
            else:
                users[target]["saldo"] = max(0, users[target]["saldo"] - nominal)
            save_users(users)
            context.user_data.pop("modsaldo")
            await update.message.reply_text(f"✅ Sukses update saldo untuk {target}.")
        except:
            await update.message.reply_text("❌ Format salah. Contoh: 12345678 500")
        return

    if context.user_data.get("role_select"):
        try:
            target, role = text.split()
            if role not in ["user", "reseller", "admin"]:
                raise Exception()
            users.setdefault(target, {"saldo": 0, "role": "user"})
            users[target]["role"] = role
            save_users(users)
            context.user_data.pop("role_select")
            await update.message.reply_text(f"🔄 Role {target} diubah menjadi {role}.")
        except:
            await update.message.reply_text("❌ Format: 12345678 reseller")
        return

    if context.user_data.get("broadcast_msg"):
        context.user_data.pop("broadcast_msg")
        for uid in users.keys():
            try:
                await context.bot.send_message(chat_id=uid, text=text)
            except:
                pass
        await update.message.reply_text("📢 Pesan broadcast berhasil dikirim.")
        return

    if context.user_data.get("delip"):
        context.user_data.pop("delip")
        before = len(allowed["authorized_ips"])
        allowed["authorized_ips"] = [x for x in allowed["authorized_ips"] if x["ip"] != text]
        after = len(allowed["authorized_ips"])
        if before == after:
            await update.message.reply_text("❌ IP tidak ditemukan.")
        else:
            save_allowed(allowed)
            await update.message.reply_text("✅ IP berhasil dihapus.")
        return

    if context.user_data.get("renew"):
        context.user_data.pop("renew")
        found = False
        for x in allowed["authorized_ips"]:
            if x["ip"] == text:
                x["days"] += 30
                found = True
                break
        if found:
            save_allowed(allowed)
            await update.message.reply_text("♻️ Masa aktif IP diperpanjang 30 hari.")
        else:
            await update.message.reply_text("❌ IP tidak ditemukan.")
        return

def main():
    app = Application.builder().token(config["token"]).build()
    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start), CallbackQueryHandler(handle_callback)],
        states={}, fallbacks=[]
    )
    app.add_handler(conv)
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, message_handler))
    app.run_polling()

if __name__ == '__main__':
    main()
# Akan digabung otomatis oleh script setelah ini
EOF

# Masukkan full isi script bot.py dari file sebelumnya ke sini nanti

# Buat Dockerfile
cat > Dockerfile <<EOF
FROM python:3.11
WORKDIR /app
COPY . /app
RUN pip install python-telegram-bot ipaddress
CMD ["python", "bot.py"]
EOF

# Build dan run container
docker build -t niku-bot .
docker rm -f niku-bot 2>/dev/null || true
docker run -d --name niku-bot \
  -v $BOT_DIR:/app \
  --restart unless-stopped \
  niku-bot

# Buat systemd service
cat > /etc/systemd/system/$SERVICE_NAME <<EOF
[Unit]
Description=NIKU BOT Telegram Service
After=network.target docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker start -a niku-bot
ExecStop=/usr/bin/docker stop -t 2 niku-bot
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Aktifkan service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable $SERVICE_NAME --now

clear
echo -e "✅ Bot Telegram berhasil diinstal dan berjalan di Docker."
echo -e "📁 Lokasi file: $BOT_DIR"
echo -e "🔧 Edit token bot di: $BOT_DIR/config.json"
echo -e "📦 Gunakan \`docker logs niku-bot\` untuk melihat log"
