import json
import subprocess
import os
import time
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InputFile
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters
)

# Logging setup
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# States
(SELECT_TYPE, INPUT_USERNAME, INPUT_DAYS, INPUT_IP, INPUT_QUOTA,
 INPUT_TOPUP_ID, INPUT_TOPUP_AMOUNT,
 INPUT_KURANG_ID, INPUT_KURANG_AMOUNT,
 INPUT_TARIF_TYPE, INPUT_TARIF_DURATION, INPUT_TARIF_VALUE,
 INPUT_EDIT_ROLE_ID, INPUT_EDIT_ROLE_VALUE,
 INPUT_ADD_SERVER_IP, INPUT_ADD_SERVER_DESC) = range(16)

# Load config at start
def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default

def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

CONFIG_PATH = "/etc/niku-bot/config.json"
USERS_PATH = "/etc/niku-bot/users.json"
SERVER_CFG_PATH = "/etc/niku-bot/server_config.json"

config = load_json(CONFIG_PATH, {})
TOKEN = config.get("BOT_TOKEN", "")
ADMIN_IDS = config.get("ADMIN_IDS", [])
TARIF_DEFAULT = config.get("TARIF", {})

# Helper to load users & server config live
def get_users():
    return load_json(USERS_PATH, {})

def save_users(users):
    save_json(USERS_PATH, users)

def get_server_config():
    return load_json(SERVER_CFG_PATH, {})

def save_server_config(cfg):
    save_json(SERVER_CFG_PATH, cfg)

# Get user role & saldo
def get_user_info(user_id: int):
    users = get_users()
    user = users.get(str(user_id), {})
    return user.get("role", "Client"), user.get("saldo", 0)

def update_user_saldo(user_id: int, amount: int):
    users = get_users()
    uid = str(user_id)
    if uid in users:
        users[uid]["saldo"] = users[uid].get("saldo",0) + amount
        if users[uid]["saldo"] < 0:
            users[uid]["saldo"] = 0
        save_users(users)
        return True
    return False

def update_user_role(user_id: int, new_role: str):
    users = get_users()
    uid = str(user_id)
    if uid in users:
        users[uid]["role"] = new_role
        save_users(users)
        return True
    return False

# Get tarif per jenis dan durasi
def get_tarif_value(jenis: str, durasi: str) -> int:
    cfg = get_server_config()
    return cfg.get("tarif", {}).get(jenis, {}).get(durasi, TARIF_DEFAULT.get(jenis, 0))

# START handler
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    role, saldo = get_user_info(user.id)
    users = get_users()
    server_cfg = get_server_config()
    server_list = server_cfg.get("servers", [])
    uptime = time.time() - os.getpid()  # Approximate uptime
    uptime_str = time.strftime("%H:%M:%S", time.gmtime(uptime))
    text = (
        f"🛒 MERCURY VPN — Bot E-Commerce VPN & Digital\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📈 Statistik Toko:\n"
        f"• 👥 Pengguna: {len(users)}\n"
        f"• 🗄️ Jumlah Server VPN: {len(server_list)}\n"
        f"• ⏱️ Uptime Bot: {uptime_str}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👤 Akun Anda:\n"
        f"• 🆔 ID: {user.id}\n"
        f"• Username: @{user.username or '-'}\n"
        f"• Role: {role}\n"
        f"• Saldo: Rp{saldo}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"Customer Service: @mercurystore12\n"
        f"━━━━━━━━━━━━━━━━━━━━━━"
    )
    keyboard = [
        [InlineKeyboardButton("🛡️ Beli Akun VPN", callback_data="beli_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup_saldo")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")],
        [InlineKeyboardButton("👑 Admin Panel", callback_data="admin_panel")]
    ]
    await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard))

# Callback handler
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    if data == "beli_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="ssh"),
             InlineKeyboardButton("VMESS", callback_data="vmess")],
            [InlineKeyboardButton("VLESS", callback_data="vless"),
             InlineKeyboardButton("TROJAN", callback_data="trojan")]
        ]
        await query.edit_message_text("Pilih jenis akun:", reply_markup=InlineKeyboardMarkup(keyboard))
        return SELECT_TYPE

    elif data == "topup_saldo":
        text = (
            "💳 Silakan transfer ke nomor berikut:\n\n"
            "Dana: 08xxxxxx\n"
            "Gopay: 08xxxxx\n\n"
            "Setelah transfer, kirim *bukti transfer* (foto) di sini.\n"
            "Admin akan segera memprosesnya."
        )
        await query.edit_message_text(text)
        return ConversationHandler.END

    elif data == "cek_saldo":
        role, saldo = get_user_info(query.from_user.id)
        await query.edit_message_text(f"💰 Saldo: Rp{saldo}")
        return ConversationHandler.END

    elif data == "admin_panel":
        if query.from_user.id not in ADMIN_IDS:
            await query.edit_message_text("❌ Akses ditolak!")
            return ConversationHandler.END
        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="tambah_saldo")],
            [InlineKeyboardButton("➖ Kurangi Saldo", callback_data="kurangi_saldo")],
            [InlineKeyboardButton("💰 Set Tarif", callback_data="set_tarif")],
            [InlineKeyboardButton("👤 Edit Role", callback_data="edit_role")],
            [InlineKeyboardButton("🖥️ Add Server", callback_data="add_server")]
        ]
        await query.edit_message_text("👑 MENU ADMIN", reply_markup=InlineKeyboardMarkup(keyboard))
        return ConversationHandler.END

    # --- Beli akun lanjut ke select_type ---
    elif data in ("ssh", "vmess", "vless", "trojan"):
        user_id = query.from_user.id
        context.user_data["type"] = data
        await query.edit_message_text("Masukkan username:")
        return INPUT_USERNAME

    # --- Admin Tambah Saldo ---
    elif data == "tambah_saldo":
        await query.edit_message_text("Masukkan ID Telegram user yang ingin ditambah saldonya:")
        return INPUT_TOPUP_ID

    # --- Admin Kurangi Saldo ---
    elif data == "kurangi_saldo":
        await query.edit_message_text("Masukkan ID Telegram user yang ingin dikurangi saldonya:")
        return INPUT_KURANG_ID

    # --- Admin Set Tarif ---
    elif data == "set_tarif":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="tarif_ssh"),
             InlineKeyboardButton("VMESS", callback_data="tarif_vmess")],
            [InlineKeyboardButton("VLESS", callback_data="tarif_vless"),
             InlineKeyboardButton("TROJAN", callback_data="tarif_trojan")]
        ]
        await query.edit_message_text(
            "💰 Pilih jenis akun yang ingin diubah tarifnya:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return INPUT_TARIF_TYPE

    elif data.startswith("tarif_"):
        jenis = data.replace("tarif_", "")
        tarif7 = get_tarif_value(jenis, "7")
        tarif15 = get_tarif_value(jenis, "15")
        tarif30 = get_tarif_value(jenis, "30")

        keyboard = [
            [InlineKeyboardButton("7 day", callback_data=f"durasi_7")],
            [InlineKeyboardButton("15 day", callback_data=f"durasi_15")],
            [InlineKeyboardButton("30 day", callback_data=f"durasi_30")]
        ]

        await query.edit_message_text(
            f"💰 Tarif Akun {jenis.upper()}:\n\n"
            f"7 day  : Rp{tarif7}\n"
            f"15 day : Rp{tarif15}\n"
            f"30 day : Rp{tarif30}\n\n"
            "Pilih durasi yang ingin diubah tarifnya:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

        context.user_data["tarif_type"] = jenis
        return INPUT_TARIF_DURATION

    elif data.startswith("durasi_"):
        durasi = data.replace("durasi_", "")
        jenis = context.user_data.get("tarif_type", "ssh")
        await query.edit_message_text(
            f"Masukkan tarif baru untuk {jenis.upper()} dengan durasi {durasi} hari (angka tanpa Rp):"
        )
        context.user_data["tarif_duration"] = durasi
        return INPUT_TARIF_VALUE

    # --- Admin Edit Role ---
    elif data == "edit_role":
        await query.edit_message_text("Masukkan ID Telegram user yang ingin diedit rolenya:")
        return INPUT_EDIT_ROLE_ID

    # --- Admin Add Server ---
    elif data == "add_server":
        await query.edit_message_text("Masukkan IP VPS baru yang ingin ditambahkan:")
        return INPUT_ADD_SERVER_IP

    else:
        await query.edit_message_text("Perintah tidak dikenal.")
        return ConversationHandler.END


# Handlers input user data

async def select_type(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = query.from_user.id
    context.user_data["type"] = query.data
    await query.edit_message_text("Masukkan username:")
    return INPUT_USERNAME

async def input_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    context.user_data["username"] = update.message.text
    await update.message.reply_text("Masa aktif (hari):")
    return INPUT_DAYS

async def input_days(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["days"] = update.message.text
    await update.message.reply_text("Limit IP:")
    return INPUT_IP

async def input_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["ip"] = update.message.text
    await update.message.reply_text("Limit Kuota (GB):")
    return INPUT_QUOTA

async def input_quota(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_data = context.user_data

    jenis = user_data.get("type")
    tarif_cfg = get_server_config().get("tarif", {})
    tarif_per_durasi = tarif_cfg.get(jenis, {})
    days = user_data.get("days")

    try:
        days_int = int(days)
    except Exception:
        days_int = 7

    tarif = tarif_per_durasi.get(str(days_int), None)

    if tarif is None:
        tarif = TARIF_DEFAULT.get(jenis, 0)

    role, saldo = get_user_info(update.effective_user.id)
    if saldo < tarif:
        await update.message.reply_text(f"❌ Saldo tidak cukup! Butuh Rp{tarif}")
        return ConversationHandler.END

    # Jalankan script shell untuk create akun
    cmd_map = {
        "ssh": "/root/menu/menu-ssh.sh",
        "vmess": "/root/menu/menu-vmess.sh",
        "vless": "/root/menu/menu-vless.sh",
        "trojan": "/root/menu/menu-trojan.sh"
    }

    try:
        result = subprocess.run(
            ["bash", cmd_map[jenis], "add",
             user_data["username"], user_data["days"],
             user_data["ip"], user_data["quota"]],
            capture_output=True, text=True, timeout=30
        )
        output = result.stdout or result.stderr

        if "success" in output.lower():
            update_user_saldo(update.effective_user.id, -tarif)
            await update.message.reply_text(f"✅ Akun berhasil dibuat!\n{output}")
        else:
            await update.message.reply_text(f"❌ Gagal:\n{output}")

    except Exception as e:
        await update.message.reply_text(f"⚠️ Error system: {str(e)}")

    return ConversationHandler.END


# Admin tambah saldo
async def input_topup_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["topup_id"] = update.message.text
    await update.message.reply_text("Masukkan jumlah saldo yang akan ditambahkan (angka):")
    return INPUT_TOPUP_AMOUNT

async def input_topup_amount(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        user_id = context.user_data.get("topup_id")
        amount = int(update.message.text)
        if update_user_saldo(int(user_id), amount):
            await update.message.reply_text(f"✅ Saldo user {user_id} berhasil ditambah Rp{amount}")
        else:
            await update.message.reply_text("❌ User tidak ditemukan.")
    except Exception:
        await update.message.reply_text("❌ Input tidak valid.")
    return ConversationHandler.END

# Admin kurangi saldo
async def input_kurang_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["kurang_id"] = update.message.text
    await update.message.reply_text("Masukkan jumlah saldo yang akan dikurangi (angka):")
    return INPUT_KURANG_AMOUNT

async def input_kurang_amount(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        user_id = context.user_data.get("kurang_id")
        amount = int(update.message.text)
        if update_user_saldo(int(user_id), -amount):
            await update.message.reply_text(f"✅ Saldo user {user_id} berhasil dikurangi Rp{amount}")
        else:
            await update.message.reply_text("❌ User tidak ditemukan.")
    except Exception:
        await update.message.reply_text("❌ Input tidak valid.")
    return ConversationHandler.END

# Admin set tarif (input tarif value)
async def input_tarif_value(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        value = int(update.message.text)
        jenis = context.user_data.get("tarif_type", "ssh")
        durasi = context.user_data.get("tarif_duration", "7")

        cfg = get_server_config()
        if "tarif" not in cfg:
            cfg["tarif"] = {}
        if jenis not in cfg["tarif"]:
            cfg["tarif"][jenis] = {}
        cfg["tarif"][jenis][durasi] = value
        save_server_config(cfg)

        await update.message.reply_text(f"✅ Tarif {jenis.upper()} untuk {durasi} hari berhasil diubah menjadi Rp{value}")
        return ConversationHandler.END

    except ValueError:
        await update.message.reply_text("❌ Masukkan tarif dalam angka.")
        return INPUT_TARIF_VALUE

# Admin edit role
async def input_edit_role_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["edit_role_id"] = update.message.text
    await update.message.reply_text("Masukkan role baru (Client/Admin):")
    return INPUT_EDIT_ROLE_VALUE

async def input_edit_role_value(update: Update, context: ContextTypes.DEFAULT_TYPE):
    new_role = update.message.text.strip()
    user_id = context.user_data.get("edit_role_id")
    if new_role.lower() not in ["client", "admin"]:
        await update.message.reply_text("❌ Role tidak valid. Gunakan 'Client' atau 'Admin'.")
        return INPUT_EDIT_ROLE_VALUE
    if update_user_role(int(user_id), new_role.capitalize()):
        await update.message.reply_text(f"✅ Role user {user_id} berhasil diubah menjadi {new_role.capitalize()}")
    else:
        await update.message.reply_text("❌ User tidak ditemukan.")
    return ConversationHandler.END

# Admin add server (placeholder)
async def input_add_server_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["new_server_ip"] = update.message.text
    await update.message.reply_text("Masukkan deskripsi server (misal: lokasi/dll):")
    return INPUT_ADD_SERVER_DESC

async def input_add_server_desc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = context.user_data.get("new_server_ip")
    desc = update.message.text
    cfg = get_server_config()
    if "servers" not in cfg:
        cfg["servers"] = []
    cfg["servers"].append({"ip": ip, "desc": desc})
    save_server_config(cfg)
    await update.message.reply_text(f"✅ Server {ip} dengan deskripsi '{desc}' berhasil ditambahkan.")
    return ConversationHandler.END

# Cancel handler
async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("❌ Proses dibatalkan.")
    return ConversationHandler.END


def main():
    app = Application.builder().token(TOKEN).build()

    conv_handler = ConversationHandler(
        entry_points=[
            CommandHandler("start", start),
            CallbackQueryHandler(handle_callback)
        ],
        states={
            SELECT_TYPE: [CallbackQueryHandler(handle_callback, pattern="^(ssh|vmess|vless|trojan)$")],
            INPUT_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_username)],
            INPUT_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_days)],
            INPUT_IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_ip)],
            INPUT_QUOTA: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_quota)],

            INPUT_TOPUP_ID: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_topup_id)],
            INPUT_TOPUP_AMOUNT: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_topup_amount)],

            INPUT_KURANG_ID: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_kurang_id)],
            INPUT_KURANG_AMOUNT: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_kurang_amount)],

            INPUT_TARIF_TYPE: [CallbackQueryHandler(handle_callback, pattern="^tarif_")],
            INPUT_TARIF_DURATION: [CallbackQueryHandler(handle_callback, pattern="^durasi_")],
            INPUT_TARIF_VALUE: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_tarif_value)],

            INPUT_EDIT_ROLE_ID: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_edit_role_id)],
            INPUT_EDIT_ROLE_VALUE: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_edit_role_value)],

            INPUT_ADD_SERVER_IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_add_server_ip)],
            INPUT_ADD_SERVER_DESC: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_add_server_desc)],

        },
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True
    )

    app.add_handler(conv_handler)

    app.run_polling()


if __name__ == '__main__':
    main()
        
