#!/bin/bash
# AUTO INSTALL TELEGRAM BOT NIKU TUNNEL - FINAL ALL-IN-ONE

echo -e "\e[33m[•] Instalasi Bot Telegram NIKU TUNNEL dimulai...\e[0m"

# ==== INPUT TOKEN DAN ADMIN ID ====
read -p "Masukkan Bot Token Telegram: " TOKEN
read -p "Masukkan Telegram Admin ID: " ADMIN_ID

# ==== INSTALL PYTHON & DEPENDENSI ====
apt update -y
apt install python3 python3-pip -y

# Pastikan pip3 versi terbaru
pip3 install --upgrade pip
pip3 install python-telegram-bot==20.3 paramiko

# ==== BUAT FOLDER ====
mkdir -p /etc/niku-bot /var/www/html/qris

# ==== BUAT FILE config.json ====
cat > /etc/niku-bot/config.json <<EOF
{
  "BOT_TOKEN": "$TOKEN",
  "ADMIN_IDS": [$ADMIN_ID],
  "TARIF": {
    "ssh": 1000,
    "vmess": 2000,
    "vless": 2000,
    "trojan": 2000,
    "ipreg": 5000
  }
}
EOF

# ==== BUAT FILE users.json & server_config.json ====
echo '{}' > /etc/niku-bot/users.json
echo '[]' > /etc/niku-bot/server_config.json

# ==== BUAT FILE bot.py ====
cat > /etc/niku-bot/bot.py <<'EOF'
import logging, json, os, time, paramiko
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, CallbackQueryHandler, filters, ContextTypes, ConversationHandler

# Logging
logging.basicConfig(level=logging.INFO)

# Path
CONFIG_PATH = "/etc/niku-bot/config.json"
SERVER_PATH = "/etc/niku-bot/server_config.json"
USER_DB = "/etc/niku-bot/users.json"
QRIS_FOLDER = "/var/www/html/qris"

# Load config
with open(CONFIG_PATH, "r") as f:
    BOT_CONFIG = json.load(f)

ADMIN_IDS = BOT_CONFIG["ADMIN_IDS"]
BOT_TOKEN = BOT_CONFIG["BOT_TOKEN"]

# Global state
(JENIS, USERNAME, AKTIF, ADMIN_PANEL, ADMIN_MENU) = range(5)
USER_DATA = {}

def load_servers():
    try:
        with open(SERVER_PATH, "r") as f:
            return json.load(f)
    except: return []

def save_servers(data):
    with open(SERVER_PATH, "w") as f:
        json.dump(data, f, indent=2)

def load_users():
    try:
        with open(USER_DB, "r") as f:
            return json.load(f)
    except: return {}

def save_users(data):
    with open(USER_DB, "w") as f:
        json.dump(data, f, indent=2)

def remote_exec(ip, user, password, perintah):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username=user, password=password, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(perintah)
    output = stdout.read().decode()
    ssh.close()
    return output

def cek_saldo(uid, tarif):
    db = load_users()
    saldo = db.get(str(uid), {}).get("saldo", 0)
    return saldo >= tarif

def kurangi_saldo(uid, jumlah):
    db = load_users()
    if str(uid) in db:
        db[str(uid)]["saldo"] = db[str(uid)].get("saldo", 0) - jumlah
        save_users(db)

# Start command
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    keyboard = [
        [InlineKeyboardButton("📦 Buat Akun", callback_data="buat_akun")],
        [InlineKeyboardButton("🔐 Daftar IP VPS", callback_data="daftar_ip")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup")],
        [InlineKeyboardButton("📊 Cek Saldo", callback_data="cek_saldo")]
    ]
    if uid in ADMIN_IDS:
        keyboard.append([InlineKeyboardButton("👑 Admin Panel", callback_data="admin_menu")])
    await update.message.reply_text("Selamat datang di NIKU TUNNEL Bot", reply_markup=InlineKeyboardMarkup(keyboard))

# Button handler
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data
    uid = query.from_user.id

    if data == "cek_saldo":
        saldo = load_users().get(str(uid), {}).get("saldo", 0)
        await query.edit_message_text(f"💰 Saldo kamu: Rp {saldo}")

    elif data == "topup":
        images = os.listdir(QRIS_FOLDER)
        if not images:
            await query.edit_message_text("❌ QRIS belum tersedia.")
            return
        for img in images:
            await query.message.reply_photo(photo=open(f"{QRIS_FOLDER}/{img}", "rb"))
        await query.message.reply_text("Silakan scan QRIS lalu hubungi admin.")

    elif data == "buat_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="jenis_ssh"), InlineKeyboardButton("VMESS", callback_data="jenis_vmess")],
            [InlineKeyboardButton("VLESS", callback_data="jenis_vless"), InlineKeyboardButton("TROJAN", callback_data="jenis_trojan")]
        ]
        await query.edit_message_text("Pilih jenis akun:", reply_markup=InlineKeyboardMarkup(keyboard))

    elif data.startswith("jenis_"):
        context.user_data["jenis"] = data.split("_")[1]
        await query.message.reply_text("Masukkan username akun:")
        return USERNAME

    elif data == "daftar_ip":
        await query.message.reply_text("Masukkan IP VPS yang ingin kamu daftarkan:")
        return ADMIN_PANEL

    elif data == "admin_menu":
        if uid not in ADMIN_IDS:
            await query.edit_message_text("❌ Kamu bukan admin.")
            return
        await query.edit_message_text("👑 Admin Panel: Masih dikembangkan")

# Input username
async def input_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["username"] = update.message.text.strip()
    await update.message.reply_text("Masukkan masa aktif (hari):")
    return AKTIF

# Input aktif
async def input_aktif(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    username = context.user_data["username"]
    jenis = context.user_data["jenis"]
    hari = update.message.text.strip()
    tarif = BOT_CONFIG.get("TARIF", {}).get(jenis, 2000)

    if not cek_saldo(uid, tarif):
        await update.message.reply_text("❌ Saldo tidak cukup.")
        return ConversationHandler.END

    server = next((s for s in load_servers() if jenis in s["layanan"]), None)
    if not server:
        await update.message.reply_text("❌ Server tidak ditemukan.")
        return ConversationHandler.END

    try:
        cmd = f"bash /root/menu/{jenis}/create.sh {username} {hari}"
        hasil = remote_exec(server["ip"], server["username"], server["password"], cmd)
        kurangi_saldo(uid, tarif)
        await update.message.reply_text(f"✅ Akun berhasil dibuat:\n{hasil}")
    except Exception as e:
        await update.message.reply_text(f"❌ Gagal:\n{e}")
    return ConversationHandler.END

# Input IP VPS
async def input_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = update.message.text.strip()
    uid = update.effective_user.id
    tarif = BOT_CONFIG.get("TARIF", {}).get("ipreg", 5000)

    if not cek_saldo(uid, tarif):
        await update.message.reply_text("❌ Saldo tidak cukup.")
        return ConversationHandler.END

    servers = load_servers()
    servers.append({"id": f"ip{int(time.time())}", "ip": ip, "username": "root", "password": "vpspass", "layanan": ["ssh"]})
    save_servers(servers)
    kurangi_saldo(uid, tarif)
    await update.message.reply_text(f"✅ IP {ip} berhasil didaftarkan.")
    return ConversationHandler.END

# Main function
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_username)],
            AKTIF: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_aktif)],
            ADMIN_PANEL: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_ip)]
        },
        fallbacks=[]
    )
    app.add_handler(conv)
    app.add_handler(CallbackQueryHandler(button_handler))
    app.run_polling()

if __name__ == '__main__':
    main()
EOF

# ==== SYSTEMD SERVICE ====
cat > /etc/systemd/system/niku-bot.service <<EOF
[Unit]
Description=NIKU TUNNEL TELEGRAM BOT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/niku-bot/bot.py
WorkingDirectory=/etc/niku-bot/
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# ==== ENABLE & START ====
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

echo -e "\e[32m[SUKSES] Bot Telegram berhasil diinstall & dijalankan!\e[0m"
