#!/bin/bash
# ===============================================
# MERCURYVPN Telegram Bot Installer - Docker Based
# ===============================================

clear
echo -e "\033[1;32mInstalling Telegram Bot...\033[0m"

# Install docker jika belum ada
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt update -y
    apt install -y docker.io
    systemctl enable docker
    systemctl start docker
fi

# Buat direktori
BOT_DIR="/root/bot-telegram"
mkdir -p $BOT_DIR/config
cd $BOT_DIR

# Simpan bot.py
cat > bot.py << 'EOF'
import json, ipaddress
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, CallbackQueryHandler, ContextTypes, filters, ConversationHandler

# Load & Save
def load_users():
    with open("config/users.json") as f:
        return json.load(f)

def save_users(users):
    with open("config/users.json", "w") as f:
        json.dump(users, f, indent=2)

def load_config():
    with open("config/config.json") as f:
        return json.load(f)

def load_allowed():
    with open("config/allowed.json") as f:
        return json.load(f)

def save_allowed(allowed):
    with open("config/allowed.json", "w") as f:
        json.dump(allowed, f, indent=2)

# Start command
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    username = update.effective_user.username or "-"
    users = load_users()
    config = load_config()

    if user_id not in users:
        users[user_id] = {
            "username": username,
            "role": "reseller",
            "saldo": 0
        }
        save_users(users)

    user = users[user_id]
    total_user = len(users)
    uptime = "Aktif"

    text = (
        "🛒 *MERCURY VPN — Bot E-Commerce VPN & Digital*\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📈 Statistik Toko:\n"
        f"• 👥 Pengguna: {total_user}\n"
        f"• ⏱️ Uptime Bot: {uptime}\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👤 Akun Anda:\n"
        f"• 🆔 ID: `{user_id}`\n"
        f"• Username: @{username}\n"
        f"• Role: {user['role']}\n"
        f"• Saldo: {user['saldo']}\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "• 🖥️ Registrasi IP VPS\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        "Customer Service: @mercurystore12"
    )

    keyboard = [
        [InlineKeyboardButton("🖥️ Registrasi IP VPS", callback_data="regip")]
    ]
    await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode="Markdown")

# Callback
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = str(query.from_user.id)

    if query.data == "regip":
        context.user_data["current_action"] = "regip"
        await query.message.reply_text("Masukkan IP VPS:")
        return

# Message Handler
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
                        await update.message.reply_text("❌ Saldo tidak cukup.")
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

    except Exception as e:
        await update.message.reply_text(f"Error: {e}")

# Main
def main():
    config = load_config()
    app = Application.builder().token(config["token"]).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, message_handler))

    app.run_polling()

if __name__ == "__main__":
    main()
    
EOF

# Simpan Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
CMD ["python", "bot.py"]
EOF

# Simpan requirements.txt
cat > requirements.txt << 'EOF'
python-telegram-bot==20.6
EOF

# Simpan config/config.json
cat > config/config.json << 'EOF'
{
  "token": "7992850329:AAH-aVvsPg5Sflv4zIJixUsuTDyW7aCB5PI",
  "admin": ["8060554197"]
}
EOF

# Simpan config/users.json
cat > config/users.json << 'EOF'
{
  "8060554197": {
    "username": "admin",
    "role": "admin",
    "saldo": 999999999
  }
}
EOF

# Simpan config/allowed.json
cat > config/allowed.json << 'EOF'
{
  "authorized_ips": []
}
EOF

# Build dan run docker
docker rm -f niku-bot > /dev/null 2>&1
docker build -t niku-bot .
docker run -d --name niku-bot -v $(pwd)/config:/app/config niku-bot

echo -e "\033[1;32m✅ Bot berhasil dijalankan di Docker!\033[0m"
echo -e "Gunakan perintah: \033[1;33mdocker logs -f niku-bot\033[0m untuk melihat log."
