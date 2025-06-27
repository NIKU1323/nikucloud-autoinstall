#!/bin/bash

clear
echo "🔧 Menginstall Telegram Bot Registrasi IP VPS..."

BOT_FOLDER="/opt/niku-bot"
mkdir -p $BOT_FOLDER
cd $BOT_FOLDER || exit

# Token
read -p "Masukkan TOKEN Bot Telegram: " TOKEN

# Buat config.json
cat > config.json <<EOF
{
  "token": "$TOKEN"
}
EOF

# Buat allowed.json
cat > allowed.json <<EOF
{
  "authorized_ips": []
}
EOF

# Buat users.json dengan kamu sebagai admin
cat > users.json <<EOF
{
  "8060554197": {
    "saldo": 999999999,
    "role": "admin"
  }
}
EOF

# Buat Dockerfile
cat > Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir python-telegram-bot==20.3
CMD ["python", "bot.py"]
EOF

# Buat bot.py
cat > bot.py <<'EOF'
import json, logging, ipaddress, os, datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ContextTypes, filters, ConversationHandler
)

# Logging detail ke terminal
logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    level=logging.INFO
)

CONFIG_FILE = "config.json"
ALLOWED_FILE = "allowed.json"
USERS_FILE = "users.json"

# Load config
with open(CONFIG_FILE) as f:
    config = json.load(f)

# Pastikan file users dan allowed ada
if not os.path.exists(ALLOWED_FILE):
    with open(ALLOWED_FILE, 'w') as f:
        json.dump({ "authorized_ips": [] }, f)

if not os.path.exists(USERS_FILE):
    with open(USERS_FILE, 'w') as f:
        json.dump({}, f)

(REGISTER_IP, INPUT_NAME, INPUT_DAY, TARGET_USER,
 ROLE_SELECT, BROADCAST_MSG, REMOVE_IP, RENEW_IP) = range(8)

start_time = datetime.datetime.now()

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    username = update.effective_user.username or "-"
    users = load_users()
    user_data = users.get(user_id, {"saldo": 0, "role": "user"})
    role = user_data.get("role", "user")
    saldo = user_data.get("saldo", 0)

    uptime = datetime.datetime.now() - start_time
    uptime_text = f"{uptime.days} hari {uptime.seconds//3600} jam {(uptime.seconds//60)%60} menit"
    total_users = len(users)

    text = f"""🛒 MERCURY VPN — Bot E-Commerce VPN & Digital
━━━━━━━━━━━━━━━━━━━━━━
📈 Statistik Toko:
• 👥 Pengguna: {total_users}
• ⏱️ Uptime Bot: {uptime_text}
━━━━━━━━━━━━━━━━━━━━━━
👤 Akun Anda:
• 🆔 ID: {user_id}
• Username: @{username}
• Role: {role}
• Saldo: {saldo}
━━━━━━━━━━━━━━━━━━━━
• 🖥️ Registrasi IP VPS
━━━━━━━━━━━━━━━━━━━━━━
Customer Service: @mercurystore12
━━━━━━━━━━━━━━━━━━━━━━"""

    buttons = [
        [InlineKeyboardButton("Registrasi IP", callback_data="regip")],
        [InlineKeyboardButton("Renew IP", callback_data="renew")],
        [InlineKeyboardButton("Hapus IP", callback_data="delip")],
    ]
    if role in ["admin", "reseller"]:
        buttons += [
            [InlineKeyboardButton("Tambah Saldo", callback_data="addsaldo"),
             InlineKeyboardButton("Kurangi Saldo", callback_data="remsaldo")],
            [InlineKeyboardButton("Edit Role", callback_data="editrole")],
            [InlineKeyboardButton("Maintenance Mode", callback_data="maint")],
            [InlineKeyboardButton("Broadcast", callback_data="broadcast")],
        ]

    await update.message.reply_text(
        text,
        reply_markup=InlineKeyboardMarkup(buttons),
        parse_mode="Markdown"
    )

# Util functions
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

# Callback handler utama
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        query = update.callback_query
        await query.answer()
        data = query.data
        context.user_data["current_action"] = data

        if data == "regip":
            await query.message.reply_text("Masukkan IP VPS yang ingin diregistrasikan:")
            return REGISTER_IP
        elif data == "delip":
            await query.message.reply_text("Masukkan IP yang ingin dihapus:")
            return REMOVE_IP
        elif data == "renew":
            await query.message.reply_text("Masukkan IP yang ingin diperpanjang:")
            return RENEW_IP
        elif data == "broadcast":
            await query.message.reply_text("Ketik pesan broadcast:")
            return BROADCAST_MSG
        elif data == "addsaldo":
            await query.message.reply_text("Format: IDTelegram Nominal (contoh: 12345678 5000)")
            return TARGET_USER
        elif data == "remsaldo":
            await query.message.reply_text("Format: IDTelegram Nominal (contoh: 12345678 500)")
            return TARGET_USER
        elif data == "editrole":
            await query.message.reply_text("Format: IDTelegram RoleBaru (contoh: 12345678 reseller)")
            return ROLE_SELECT
        elif data == "maint":
            context.bot_data['maintenance'] = not context.bot_data.get('maintenance', False)
            await query.message.reply_text(f"Maintenance Mode: {'AKTIF' if context.bot_data['maintenance'] else 'NONAKTIF'}")
    except Exception as e:
        logging.error(f"handle_callback error: {e}")

# Handle input teks user
async def message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        user_id = str(update.effective_user.id)
        text = update.message.text.strip()
        users = load_users()
        allowed = load_allowed()

        action = context.user_data.get("current_action")

        if action == "regip":
            try:
                ipaddress.ip_address(text)
                context.user_data["ip"] = text
                context.user_data["current_action"] = "regname"
                await update.message.reply_text("Masukkan nama client:")
            except:
                await update.message.reply_text("IP tidak valid.")
            return

        if action == "regname":
            context.user_data["name"] = text
            context.user_data["current_action"] = "regday"
            await update.message.reply_text("Masukkan masa aktif (1–60 hari):")
            return

       if action == "regday":
    try:
        days = int(text)
        if not (1 <= days <= 60):
            await update.message.reply_text("❌ Masukkan antara 1–60 hari.")
            return

        ip = context.user_data["ip"]
        name = context.user_data["name"]

        user = users.get(user_id)
        if not user:
            await update.message.reply_text("❌ Data user tidak ditemukan.")
            return

        HARGA_IP = 5000
        if user["role"] != "admin":
            if user["saldo"] < HARGA_IP:
                await update.message.reply_text("❌ Saldo tidak cukup untuk registrasi IP VPS.")
                return
            else:
                user["saldo"] -= HARGA_IP
                users[user_id] = user
                save_users(users)

        allowed["authorized_ips"].append({
            "ip": ip,
            "name": name,
            "days": days
        })
        save_allowed(allowed)
        context.user_data.clear()
        await update.message.reply_text(
            f"✅ IP `{ip}` berhasil diregistrasi.\n🧾 Saldo telah dipotong {HARGA_IP}."
        )
        return

    except ValueError:
        await update.message.reply_text("❌ Input harus berupa angka.")
        return


        if action in ["addsaldo", "remsaldo"]:
            target, nominal = text.split()
            nominal = int(nominal)
            users.setdefault(target, {"saldo": 0, "role": "user"})
            if action == "addsaldo":
                users[target]["saldo"] += nominal
            else:
                users[target]["saldo"] = max(0, users[target]["saldo"] - nominal)
            save_users(users)
            await update.message.reply_text(f"Saldo {action} berhasil.")
            context.user_data.clear()
            return

        if action == "editrole":
            target, role = text.split()
            if role not in ["user", "reseller", "admin"]:
                raise Exception()
            users.setdefault(target, {"saldo": 0, "role": "user"})
            users[target]["role"] = role
            save_users(users)
            await update.message.reply_text("Role berhasil diubah.")
            context.user_data.clear()
            return

        if action == "broadcast":
            for uid in users.keys():
                try:
                    await context.bot.send_message(chat_id=uid, text=text)
                except:
                    pass
            await update.message.reply_text("Broadcast terkirim.")
            context.user_data.clear()
            return

        if action == "delip":
            before = len(allowed["authorized_ips"])
            allowed["authorized_ips"] = [x for x in allowed["authorized_ips"] if x["ip"] != text]
            after = len(allowed["authorized_ips"])
            if before == after:
                await update.message.reply_text("IP tidak ditemukan.")
            else:
                save_allowed(allowed)
                await update.message.reply_text("IP berhasil dihapus.")
            context.user_data.clear()
            return

        if action == "renew":
            found = False
            for x in allowed["authorized_ips"]:
                if x["ip"] == text:
                    x["days"] += 30
                    found = True
                    break
            if found:
                save_allowed(allowed)
                await update.message.reply_text("IP diperpanjang 30 hari.")
            else:
                await update.message.reply_text("IP tidak ditemukan.")
            context.user_data.clear()
            return

    except Exception as e:
        logging.error(f"message_handler error: {e}")

# GLOBAL ERROR HANDLER
async def error_handler(update, context):
    logging.error(msg="Exception caught:", exc_info=context.error)

# Main
def main():
    app = Application.builder().token(config["token"]).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, message_handler))

    app.add_error_handler(error_handler)

    logging.info("Bot started... polling...")
    app.run_polling()

if __name__ == "__main__":
    main()
    
EOF

# Ganti ini dengan isi bot.py yang sudah kamu dapat sebelumnya.
# Karena karakter terlalu panjang, saya akan siapkan versi siap paste lengkap jika kamu mau.

# Buat service systemd
cat > /etc/systemd/system/niku-bot.service <<EOF
[Unit]
Description=Telegram Bot NIKU
After=network.target

[Service]
Restart=always
ExecStart=/usr/bin/docker run --rm --name niku-bot -v $BOT_FOLDER:/app niku-bot
ExecStop=/usr/bin/docker stop niku-bot

[Install]
WantedBy=multi-user.target
EOF

# Install docker jika belum
if ! command -v docker &>/dev/null; then
  echo "📦 Menginstall Docker..."
  apt update
  apt install -y docker.io
  systemctl enable --now docker
fi

# Build docker image
docker rm -f niku-bot &>/dev/null
docker build -t niku-bot .

# Enable service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now niku-bot

echo "✅ Bot berhasil diinstal dan dijalankan!"
echo "🔁 Jika ingin restart: systemctl restart niku-bot"
