# ======================
# NIKU TUNNEL TELEGRAM BOT (bot.py)
# Brand: MERCURYVPN / NIKU TUNNEL
# ======================
import logging
import json
import os
import time
import paramiko
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (ApplicationBuilder, CommandHandler, MessageHandler, CallbackQueryHandler,
                          filters, ContextTypes, ConversationHandler)

# === Logging ===
logging.basicConfig(level=logging.INFO)

# === State ===
(JENIS, USERNAME, AKTIF, ADMIN_PANEL, ADMIN_TAMBAH_SALDO, ADMIN_KURANGI_SALDO, 
ADMIN_ATUR_TARIF, KONFIRM_TOPUP, ADMIN_MENU, ADMIN_LIHAT_USER, ADMIN_HAPUS_USER, 
ADMIN_UPLOAD_QRIS, ADMIN_TAMBAH_SERVER, ADMIN_HAPUS_SERVER) = range(14)

CONFIG_PATH = "/etc/niku-bot/config.json"
SERVER_PATH = "/etc/niku-bot/server_config.json"
USER_DB = "/etc/niku-bot/users.json"
QRIS_FOLDER = "/var/www/html/qris"

with open(CONFIG_PATH) as f:
    BOT_CONFIG = json.load(f)
BOT_TOKEN = BOT_CONFIG["BOT_TOKEN"]
ADMIN_IDS = BOT_CONFIG["ADMIN_IDS"]

# === Utility ===
def load_users():
    try:
        with open(USER_DB) as f:
            return json.load(f)
    except:
        return {}

def save_users(data):
    with open(USER_DB, 'w') as f:
        json.dump(data, f, indent=2)

def load_servers():
    try:
        with open(SERVER_PATH) as f:
            return json.load(f)
    except:
        return []

def save_servers(data):
    with open(SERVER_PATH, 'w') as f:
        json.dump(data, f, indent=2)

def remote_exec(ip, user, password, command):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username=user, password=password, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(command)
    output = stdout.read().decode()
    ssh.close()
    return output

# === Menu Start ===
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    uname = update.effective_user.username or "-"
    role = "admin" if uid in ADMIN_IDS else "client"
    db = load_users()
    saldo = db.get(str(uid), {}).get("saldo", 0)

    total_user = len(db)
    total_server = len(load_servers())
    uptime = os.popen('uptime -p').read().strip()

    msg = f"""
🛒 MERCURY VPN — Bot E-Commerce VPN & Digital
━━━━━━━━━━━━━━━━━━━━━━
📈 Statistik Toko:
• 👥 Pengguna: {total_user}
• 🗄️ Jumlah Server VPN: {total_server}
• ⏱️ Uptime Bot: {uptime}
━━━━━━━━━━━━━━━━━━━━━━
👤 Akun Anda:
• 🆔 ID: {uid}
• Username: @{uname}
• Role: {role}
• Saldo: Rp {saldo}
━━━━━━━━━━━━━━━━━━━━━━
🛍️ Menu Utama:
• 🛡️ Beli Akun VPN (SSH, VMess, VLESS, Trojan)
• 💳 Topup Saldo Otomatis via QRIS
• 🖥️ Registrasi IP VPS
━━━━━━━━━━━━━━━━━━━━━━
Customer Service: @mercurystore12
━━━━━━━━━━━━━━━━━━━━━━
"""
    keyboard = [
        [InlineKeyboardButton("🛡️ Beli Akun VPN", callback_data="buat_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup")],
        [InlineKeyboardButton("🖥️ Registrasi IP VPS", callback_data="daftar_ip")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")]
    ]
    if uid in ADMIN_IDS:
        keyboard.append([InlineKeyboardButton("👑 Admin Panel", callback_data="admin_menu")])

    await update.message.reply_text(msg, reply_markup=InlineKeyboardMarkup(keyboard))

# === Button Handler ===
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data
    uid = query.from_user.id

    if data == "cek_saldo":
        db = load_users()
        saldo = db.get(str(uid), {}).get("saldo", 0)
        await query.edit_message_text(f"💰 Saldo kamu: Rp {saldo}")

    elif data == "topup":
        qris = os.listdir(QRIS_FOLDER)
        if not qris:
            await query.edit_message_text("❌ QRIS belum tersedia.")
            return
        for img in qris:
            await query.message.reply_photo(photo=open(f"{QRIS_FOLDER}/{img}", 'rb'))
        await query.message.reply_text("Silakan scan QRIS & hubungi admin untuk konfirmasi.")

    elif data == "buat_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="jenis_ssh"),
             InlineKeyboardButton("VMESS", callback_data="jenis_vmess")],
            [InlineKeyboardButton("VLESS", callback_data="jenis_vless"),
             InlineKeyboardButton("TROJAN", callback_data="jenis_trojan")]
        ]
        await query.edit_message_text("Pilih jenis akun:", reply_markup=InlineKeyboardMarkup(keyboard))

    elif data.startswith("jenis_"):
        jenis = data.split("_")[1]
        context.user_data["jenis"] = jenis
        await query.message.reply_text("Masukkan username akun:")
        return USERNAME

    elif data == "daftar_ip":
        await query.message.reply_text("Masukkan IP VPS:")
        return ADMIN_PANEL

    elif data == "admin_menu" and uid in ADMIN_IDS:
        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="admin_tambah_saldo"),
             InlineKeyboardButton("➖ Kurangi Saldo", callback_data="admin_kurangi_saldo")],
            [InlineKeyboardButton("📋 Daftar User", callback_data="admin_lihat_user"),
             InlineKeyboardButton("🗑️ Hapus User", callback_data="admin_hapus_user")],
            [InlineKeyboardButton("💰 Atur Tarif", callback_data="admin_tarif"),
             InlineKeyboardButton("🧩 Server VPN", callback_data="admin_server")],
            [InlineKeyboardButton("📤 Upload QRIS", callback_data="admin_qris")]
        ]
        await query.edit_message_text("👑 Menu Admin", reply_markup=InlineKeyboardMarkup(keyboard))
        return ADMIN_MENU

# === Conversation States ===
async def input_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["username"] = update.message.text.strip()
    await update.message.reply_text("Masukkan masa aktif (hari):")
    return AKTIF

async def input_aktif(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    username = context.user_data["username"]
    jenis = context.user_data["jenis"]
    hari = update.message.text.strip()
    tarif = BOT_CONFIG.get("TARIF", {}).get(jenis, 2000)

    saldo = load_users().get(str(uid), {}).get("saldo", 0)
    if saldo < tarif:
        await update.message.reply_text("❌ Saldo tidak cukup.")
        return ConversationHandler.END

    servers = load_servers()
    server = next((s for s in servers if jenis in s["layanan"]), None)
    if not server:
        await update.message.reply_text("❌ Server tidak tersedia.")
        return ConversationHandler.END

    try:
        hasil = remote_exec(server["ip"], server["username"], server["password"], f"bash /root/menu/{jenis}/create.sh {username} {hari}")
        db = load_users()
        db[str(uid)]["saldo"] -= tarif
        save_users(db)
        await update.message.reply_text(f"✅ Akun berhasil dibuat:\n{hasil}")
    except Exception as e:
        await update.message.reply_text(f"❌ Gagal:
{e}")
    return ConversationHandler.END

async def input_ip_vps(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    ip = update.message.text.strip()
    tarif = BOT_CONFIG.get("TARIF", {}).get("ipreg", 5000)
    saldo = load_users().get(str(uid), {}).get("saldo", 0)

    if saldo < tarif:
        await update.message.reply_text("❌ Saldo tidak cukup.")
        return ConversationHandler.END

    servers = load_servers()
    servers.append({"id": f"srv{int(time.time())}", "ip": ip, "username": "root", "password": "vpspass", "layanan": ["ssh"]})
    save_servers(servers)

    db = load_users()
    db[str(uid)]["saldo"] -= tarif
    save_users(db)
    await update.message.reply_text(f"✅ IP {ip} berhasil ditambahkan.")
    return ConversationHandler.END

# === Main ===
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_username)],
            AKTIF: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_aktif)],
            ADMIN_PANEL: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_ip_vps)],
        },
        fallbacks=[]
    )

    app.add_handler(conv)
    app.add_handler(CallbackQueryHandler(button_handler))
    app.run_polling()

if __name__ == '__main__':
    main()
                                  
