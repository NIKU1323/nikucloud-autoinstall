# NIKU BOT FINAL v1.1 - FIXED VERSION
import logging, json, os, time, paramiko
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    ApplicationBuilder, CommandHandler, MessageHandler, CallbackQueryHandler,
    filters, ContextTypes, ConversationHandler
)

# Logging
logging.basicConfig(level=logging.INFO)

# Path
CONFIG_PATH = "/etc/niku-bot/config.json"
SERVER_PATH = "/etc/niku-bot/server_config.json"
USER_DB = "/etc/niku-bot/users.json"
QRIS_FOLDER = "/var/www/html/qris"

# ===== Load Config =====
try:
    with open(CONFIG_PATH) as f:
        config = json.load(f)
        BOT_TOKEN = config["bot_token"]
        ADMIN_IDS = config["admin_ids"]
        TARIF = config["tarif"]
except Exception as e:
    print(f"❌ Gagal load config.json: {e}")
    exit(1)

# Conversation state
(JENIS, USERNAME, AKTIF, ADMIN_PANEL, ADMIN_MENU) = range(5)

# Utility
def load_users():
    if os.path.exists(USER_DB):
        with open(USER_DB) as f:
            return json.load(f)
    return {}

def save_users(data):
    with open(USER_DB, "w") as f:
        json.dump(data, f, indent=2)

def load_servers():
    if os.path.exists(SERVER_PATH):
        with open(SERVER_PATH) as f:
            return json.load(f)
    return []

def save_servers(data):
    with open(SERVER_PATH, "w") as f:
        json.dump(data, f, indent=2)

def remote_exec(ip, user, passwd, perintah):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username=user, password=passwd, timeout=10)
    stdin, stdout, stderr = ssh.exec_command(perintah)
    out = stdout.read().decode()
    ssh.close()
    return out

def cek_saldo(uid, tarif):
    db = load_users()
    return db.get(str(uid), {}).get("saldo", 0) >= tarif

def kurangi_saldo(uid, jumlah):
    db = load_users()
    if str(uid) in db:
        db[str(uid)]["saldo"] -= jumlah
        save_users(db)

# ===== START COMMAND =====
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    keyboard = [
        [InlineKeyboardButton("📦 Buat Akun", callback_data="buat_akun")],
        [InlineKeyboardButton("🔐 Daftar IP VPS", callback_data="daftar_ip")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup")],
        [InlineKeyboardButton("📊 Cek Saldo", callback_data="cek_saldo")],
        [InlineKeyboardButton("🧾 Riwayat Akun", callback_data="riwayat")]
    ]
    if uid in ADMIN_IDS:
        keyboard.append([InlineKeyboardButton("👑 Admin Panel", callback_data="admin_menu")])

    if update.message:
        await update.message.reply_text("Selamat datang di NIKU TUNNEL Bot", reply_markup=InlineKeyboardMarkup(keyboard))
    else:
        await update.callback_query.message.reply_text("Selamat datang di NIKU TUNNEL Bot", reply_markup=InlineKeyboardMarkup(keyboard))

# ===== CALLBACK BUTTON =====
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    uid = query.from_user.id
    data = query.data

    if data == "cek_saldo":
        db = load_users()
        saldo = db.get(str(uid), {}).get("saldo", 0)
        await query.edit_message_text(f"💰 Saldo kamu: Rp {saldo}")

    elif data == "topup":
        images = os.listdir(QRIS_FOLDER)
        if not images:
            await query.edit_message_text("❌ QRIS belum tersedia.")
            return
        for img in images:
            await query.message.reply_photo(photo=open(f"{QRIS_FOLDER}/{img}", "rb"))
        await query.message.reply_text("Silakan scan QRIS di atas, lalu hubungi admin untuk konfirmasi topup.")

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
        await query.message.reply_text(f"Masukkan username akun {jenis.upper()}:")
        return USERNAME

    elif data == "daftar_ip":
        await query.message.reply_text("Masukkan IP VPS yang akan kamu gunakan:")
        return ADMIN_PANEL

    elif data == "admin_menu" and uid in ADMIN_IDS:
        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="tambah_saldo"),
             InlineKeyboardButton("➖ Kurangi Saldo", callback_data="kurangi_saldo")],
            [InlineKeyboardButton("📋 Lihat Semua User", callback_data="lihat_user"),
             InlineKeyboardButton("🗑️ Hapus User", callback_data="hapus_user")],
            [InlineKeyboardButton("💰 Atur Tarif", callback_data="tarif"),
             InlineKeyboardButton("🧩 Kelola Server", callback_data="kelola_server")],
            [InlineKeyboardButton("📤 Upload QRIS", callback_data="upload_qris"),
             InlineKeyboardButton("🧾 Riwayat Semua Akun", callback_data="riwayat_all")]
        ]
        await query.edit_message_text("👑 Admin Panel Lengkap", reply_markup=InlineKeyboardMarkup(keyboard))
        return ADMIN_MENU

# ===== CONVERSATION =====
async def input_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["username"] = update.message.text.strip()
    await update.message.reply_text("Masukkan masa aktif akun (dalam hari):")
    return AKTIF

async def input_aktif(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    user = context.user_data.get("username")
    jenis = context.user_data.get("jenis")
    hari = update.message.text.strip()

    tarif = TARIF.get(jenis, 2000)
    if not cek_saldo(uid, tarif):
        await update.message.reply_text("❌ Saldo tidak cukup.")
        return ConversationHandler.END

    server = next((s for s in load_servers() if jenis in s["layanan"]), None)
    if not server:
        await update.message.reply_text("❌ Server tidak tersedia.")
        return ConversationHandler.END

    cmd = f"bash /root/menu/{jenis}/create.sh {user} {hari}"
    try:
        hasil = remote_exec(server["ip"], server["username"], server["password"], cmd)
        kurangi_saldo(uid, tarif)
        await update.message.reply_text(f"✅ Akun berhasil dibuat:\n{hasil}")
    except Exception as e:
        await update.message.reply_text(f"❌ Gagal membuat akun:\n{e}")
    return ConversationHandler.END

async def input_ip_vps(update: Update, context: ContextTypes.DEFAULT_TYPE):
    uid = update.effective_user.id
    ip = update.message.text.strip()
    tarif = TARIF.get("ipreg", 5000)

    if not cek_saldo(uid, tarif):
        await update.message.reply_text("❌ Saldo tidak cukup.")
        return ConversationHandler.END

    servers = load_servers()
    servers.append({"id": f"ip{int(time.time())}", "ip": ip, "username": "root", "password": "vpspass", "layanan": ["ssh"]})
    save_servers(servers)
    kurangi_saldo(uid, tarif)
    await update.message.reply_text(f"✅ IP VPS {ip} berhasil didaftarkan!")
    return ConversationHandler.END

# ===== MAIN =====
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_username)],
            AKTIF: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_aktif)],
            ADMIN_PANEL: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_ip_vps)],
            ADMIN_MENU: [MessageHandler(filters.TEXT & ~filters.COMMAND, lambda u, c: u.message.reply_text("🔧 Fitur admin sedang dikembangkan."))]
        },
        fallbacks=[]
    )

    app.add_handler(conv)
    app.add_handler(CallbackQueryHandler(button_handler))
    app.add_handler(CommandHandler("start", start))
    app.run_polling()

if __name__ == "__main__":
    main()
  
