import json
import subprocess
import os
import time
import logging
from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup
)
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters
)

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Load config
CONFIG_PATH = "/etc/niku-bot/config.json"
USERS_PATH = "/etc/niku-bot/users.json"
SERVER_CFG_PATH = "/etc/niku-bot/server_config.json"

def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load {path}: {e}")
        return default

def save_json(path, data):
    try:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.error(f"Failed to save {path}: {e}")

config = load_json(CONFIG_PATH, {})
TOKEN = config.get("BOT_TOKEN", "")
ADMIN_IDS = config.get("ADMIN_IDS", [])
TARIF_DEFAULT = config.get("TARIF", {})

# Conversation states
(
    MENU, SELECT_TYPE, INPUT_USERNAME, INPUT_DAYS, INPUT_IP, INPUT_QUOTA,
    INPUT_TOPUP_ID, INPUT_TOPUP_AMOUNT,
    INPUT_KURANG_ID, INPUT_KURANG_AMOUNT,
    INPUT_TARIF_TYPE, INPUT_TARIF_DURATION, INPUT_TARIF_VALUE,
    INPUT_EDIT_ROLE_ID, INPUT_EDIT_ROLE_VALUE,
    INPUT_ADD_SERVER_IP, INPUT_ADD_SERVER_DESC
) = range(17)

# Utility functions

def get_user_info(user_id: int):
    users = load_json(USERS_PATH, {})
    user = users.get(str(user_id))
    if user:
        return user.get("role", "Client"), user.get("saldo", 0)
    else:
        # Auto-register new user as Client with zero saldo
        users[str(user_id)] = {"role": "Client", "saldo": 0}
        save_json(USERS_PATH, users)
        return "Client", 0

def update_user_saldo(user_id: int, amount: int):
    users = load_json(USERS_PATH, {})
    uid = str(user_id)
    if uid in users:
        users[uid]["saldo"] = users[uid].get("saldo", 0) + amount
        if users[uid]["saldo"] < 0:
            users[uid]["saldo"] = 0
        save_json(USERS_PATH, users)
        return True
    return False

def update_user_role(user_id: int, new_role: str):
    users = load_json(USERS_PATH, {})
    uid = str(user_id)
    if uid in users:
        users[uid]["role"] = new_role
        save_json(USERS_PATH, users)
        return True
    return False

def get_server_config():
    return load_json(SERVER_CFG_PATH, {})

def save_server_config(cfg):
    save_json(SERVER_CFG_PATH, cfg)

def is_admin(user_id: int):
    return user_id in ADMIN_IDS

def validate_username(username: str):
    return username.isalnum() and 3 <= len(username) <= 20

def validate_int(text: str):
    try:
        val = int(text)
        return val > 0
    except:
        return False

def format_currency(amount):
    return f"Rp{amount:,}".replace(",", ".")

def get_uptime():
    try:
        with open("/proc/uptime") as f:
            uptime_sec = float(f.readline().split()[0])
            mins, sec = divmod(int(uptime_sec), 60)
            hour, mins = divmod(mins, 60)
            day, hour = divmod(hour, 24)
            return f"{day}d {hour}h {mins}m"
    except:
        return "N/A"

def count_users():
    users = load_json(USERS_PATH, {})
    return len(users)

def count_servers():
    cfg = get_server_config()
    servers = cfg.get("servers", [])
    return len(servers)

# Handlers

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    role, saldo = get_user_info(user.id)
    uptime = get_uptime()
    users_count = count_users()
    servers_count = count_servers()

    keyboard = [
        [InlineKeyboardButton("🛒 Beli Akun VPN", callback_data="beli_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup_saldo")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")],
    ]
    if is_admin(user.id):
        keyboard.append([InlineKeyboardButton("👑 Panel Admin", callback_data="admin_panel")])

    msg = (
        "🛒 MERCURY VPN — Bot E-Commerce VPN & Digital\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📈 Statistik Toko:\n"
        f"• 👥 Pengguna: {users_count}\n"
        f"• 🗄️ Jumlah Server VPN: {servers_count}\n"
        f"• ⏱️ Uptime Bot: {uptime}\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👤 Akun Anda:\n"
        f"• 🆔 ID: {user.id}\n"
        f"• Username: {user.username or '-'}\n"
        f"• Role: {role}\n"
        f"• Saldo: {format_currency(saldo)}\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        "Customer Service: @mercurystore12\n"
        "━━━━━━━━━━━━━━━━━━━━━━"
    )

    await update.message.reply_text(msg, reply_markup=InlineKeyboardMarkup(keyboard))
    return MENU

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = query.from_user.id
    data = query.data

    if data == "beli_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="ssh"),
             InlineKeyboardButton("VMESS", callback_data="vmess")],
            [InlineKeyboardButton("VLESS", callback_data="vless"),
             InlineKeyboardButton("TROJAN", callback_data="trojan")]
        ]
        await query.edit_message_text(
            "Pilih jenis akun VPN yang ingin dibeli:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return SELECT_TYPE

    elif data in ["ssh", "vmess", "vless", "trojan"]:
        context.user_data["type"] = data
        await query.edit_message_text("Masukkan username (alphanumeric, 3-20 karakter):")
        return INPUT_USERNAME

    elif data == "topup_saldo":
        if not is_admin(user_id):
            await query.edit_message_text("❌ Akses ditolak!")
            return ConversationHandler.END
        await query.edit_message_text("Masukkan ID user yang akan ditopup saldo:")
        return INPUT_TOPUP_ID

    elif data == "cek_saldo":
        role, saldo = get_user_info(user_id)
        await query.edit_message_text(f"💰 Saldo Anda: {format_currency(saldo)}")
        return ConversationHandler.END

    elif data == "admin_panel":
        if not is_admin(user_id):
            await query.edit_message_text("❌ Akses ditolak!")
            return ConversationHandler.END

        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="admin_tambah_saldo")],
            [InlineKeyboardButton("➖ Kurangi Saldo", callback_data="admin_kurangi_saldo")],
            [InlineKeyboardButton("⚙️ Set Tarif", callback_data="admin_set_tarif")],
            [InlineKeyboardButton("✏️ Edit Role User", callback_data="admin_edit_role")],
            [InlineKeyboardButton("📋 Daftar User", callback_data="admin_list_user")],
            [InlineKeyboardButton("➕ Tambah Server", callback_data="admin_add_server")],
            [InlineKeyboardButton("🔙 Kembali", callback_data="start")]
        ]
        await query.edit_message_text("👑 MENU ADMIN", reply_markup=InlineKeyboardMarkup(keyboard))
        return MENU

    # Admin submenu handlers
    elif data == "admin_tambah_saldo":
        await query.edit_message_text("Masukkan ID user yang saldo-nya akan ditambah:")
        return INPUT_TOPUP_ID

    elif data == "admin_kurangi_saldo":
        await query.edit_message_text("Masukkan ID user yang saldo-nya akan dikurangi:")
        return INPUT_KURANG_ID

    elif data == "admin_set_tarif":
        # Pilih jenis akun dulu
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="tarif_ssh")],
            [InlineKeyboardButton("VMESS", callback_data="tarif_vmess")],
            [InlineKeyboardButton("VLESS", callback_data="tarif_vless")],
            [InlineKeyboardButton("TROJAN", callback_data="tarif_trojan")],
            [InlineKeyboardButton("🔙 Kembali", callback_data="admin_panel")]
        ]
        await query.edit_message_text("Pilih jenis akun untuk set tarif:", reply_markup=InlineKeyboardMarkup(keyboard))
        return INPUT_TARIF_TYPE

    elif data.startswith("tarif_"):
        jenis = data.split("_")[1]
        context.user_data["tarif_type"] = jenis
        # Pilih durasi
        keyboard = [
            [InlineKeyboardButton("7 hari", callback_data="durasi_7")],
            [InlineKeyboardButton("10 hari", callback_data="durasi_10")],
            [InlineKeyboardButton("15 hari", callback_data="durasi_15")],
            [InlineKeyboardButton("30 hari", callback_data="durasi_30")],
            [InlineKeyboardButton("🔙 Kembali", callback_data="admin_set_tarif")]
        ]
        await query.edit_message_text(f"Set tarif untuk {jenis.upper()}: pilih durasi", reply_markup=InlineKeyboardMarkup(keyboard))
        return INPUT_TARIF_DURATION

    elif data.startswith("durasi_"):
        durasi = data.split("_")[1]
        context.user_data["tarif_duration"] = durasi
        await query.edit_message_text(f"Masukkan tarif baru untuk durasi {durasi} hari (dalam angka):")
        return INPUT_TARIF_VALUE

    elif data == "admin_edit_role":
        await query.edit_message_text("Masukkan ID user yang role-nya ingin diubah:")
        return INPUT_EDIT_ROLE_ID

    elif data == "admin_list_user":
        users = load_json(USERS_PATH, {})
        if not users:
            await query.edit_message_text("Belum ada user terdaftar.")
            return MENU
        text = "📋 Daftar User:\n\n"
        for uid, info in users.items():
            text += f"• ID: {uid}\n  Role: {info.get('role', 'Client')}\n  Saldo: {format_currency(info.get('saldo', 0))}\n\n"
        await query.edit_message_text(text)
        return MENU

    elif data == "admin_add_server":
        await query.edit_message_text("Masukkan IP server baru:")
        return INPUT_ADD_SERVER_IP

    elif data == "start":
        return await start(update, context)

    else:
        await query.edit_message_text("⚠️ Perintah tidak dikenali. Silakan mulai ulang dengan /start.")
        return ConversationHandler.END

async def input_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    username = update.message.text.strip()
    if not validate_username(username):
        await update.message.reply_text("❌ Username harus alphanumeric dan 3-20 karakter. Coba lagi:")
        return INPUT_USERNAME
    context.user_data["username"] = username
    await update.message.reply_text("Masukkan masa aktif (hari), misal 7, 10, 15, 30:")
    return INPUT_DAYS

async def input_days(update: Update, context: ContextTypes.DEFAULT_TYPE):
    days = update.message.text.strip()
    if not validate_int(days):
        await update.message.reply_text("❌ Masa aktif harus angka positif. Coba lagi:")
        return INPUT_DAYS
    context.user_data["days"] = days
    await update.message.reply_text("Masukkan limit IP (angka):")
    return INPUT_IP

async def input_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip_limit = update.message.text.strip()
    if not validate_int(ip_limit):
        await update.message.reply_text("❌ Limit IP harus angka positif. Coba lagi:")
        return INPUT_IP
    context.user_data["ip"] = ip_limit
    await update.message.reply_text("Masukkan limit kuota (GB):")
    return INPUT_QUOTA

async def input_quota(update: Update, context: ContextTypes.DEFAULT_TYPE):
    quota = update.message.text.strip()
    if not validate_int(quota):
        await update.message.reply_text("❌ Limit kuota harus angka positif. Coba lagi:")
        return INPUT_QUOTA

    user_data = context.user_data
    jenis = user_data.get("type")
    days = int(user_data.get("days"))
    tarif_cfg = get_server_config().get("tarif", {})
    tarif_per_durasi = tarif_cfg.get(jenis, {})
    tarif = tarif_per_durasi.get(str(days)) or TARIF_DEFAULT.get(jenis, {}).get(str(days)) or 0

    role, saldo = get_user_info(update.effective_user.id)
    if saldo < tarif:
        await update.message.reply_text(f"❌ Saldo tidak cukup! Tarif: {format_currency(tarif)}\nSaldo Anda: {format_currency(saldo)}")
        return ConversationHandler.END

    context.user_data["quota"] = quota

    # Jalankan shell script buat akun
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
            await update.message.reply_text(f"❌ Gagal membuat akun:\n{output}")
    except Exception as e:
        await update.message.reply_text(f"⚠️ Error sistem: {e}")

    return ConversationHandler.END

# Admin tambah saldo
async def input_topup_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.message.text.strip()
    if not validate_int(user_id):
        await update.message.reply_text("❌ ID user harus angka. Coba lagi:")
        return INPUT_TOPUP_ID
    context.user_data["topup_id"] = int(user_id)
    await update.message.reply_text("Masukkan jumlah saldo yang akan ditambahkan (angka):")
    return INPUT_TOPUP_AMOUNT

async def input_topup_amount(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        amount = int(update.message.text.strip())
        user_id = context.user_data.get("topup_id")
        if update_user_saldo(user_id, amount):
            await update.message.reply_text(f"✅ Saldo user {user_id} berhasil ditambah {format_currency(amount)}")
        else:
            await update.message.reply_text("❌ User tidak ditemukan.")
    except Exception:
        await update.message.reply_text("❌ Input tidak valid.")
    return ConversationHandler.END

# Admin kurangi saldo
async def input_kurang_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.message.text.strip()
    if not validate_int(user_id):
        await update.message.reply_text("❌ ID user harus angka. Coba lagi:")
        return INPUT_KURANG_ID
    context.user_data["kurang_id"] = int(user_id)
    await update.message.reply_text("Masukkan jumlah saldo yang akan dikurangi (angka):")
    return INPUT_KURANG_AMOUNT

async def input_kurang_amount(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        amount = int(update.message.text.strip())
        user_id = context.user_data.get("kurang_id")
        if update_user_saldo(user_id, -amount):
            await update.message.reply_text(f"✅ Saldo user {user_id} berhasil dikurangi {format_currency(amount)}")
        else:
            await update.message.reply_text("❌ User tidak ditemukan.")
    except Exception:
        await update.message.reply_text("❌ Input tidak valid.")
    return ConversationHandler.END

# Admin set tarif
async def input_tarif_type(update: Update, context: ContextTypes.DEFAULT_TYPE):
    jenis = update.callback_query.data.split("_")[1]
    context.user_data["tarif_type"] = jenis
    keyboard = [
        [InlineKeyboardButton("7 hari", callback_data="durasi_7")],
        [InlineKeyboardButton("10 hari", callback_data="durasi_10")],
        [InlineKeyboardButton("15 hari", callback_data="durasi_15")],
        [InlineKeyboardButton("30 hari", callback_data="durasi_30")],
        [InlineKeyboardButton("🔙 Kembali", callback_data="admin_set_tarif")]
    ]
    await update.callback_query.edit_message_text(f"Set tarif untuk {jenis.upper()}: pilih durasi", reply_markup=InlineKeyboardMarkup(keyboard))
    return INPUT_TARIF_DURATION

async def input_tarif_duration(update: Update, context: ContextTypes.DEFAULT_TYPE):
    durasi = update.callback_query.data.split("_")[1]
    context.user_data["tarif_duration"] = durasi
    await update.callback_query.edit_message_text(f"Masukkan tarif baru untuk durasi {durasi} hari (dalam angka):")
    return INPUT_TARIF_VALUE

async def input_tarif_value(update: Update, context: ContextTypes.DEFAULT_TYPE):
    val = update.message.text.strip()
    if not validate_int(val):
        await update.message.reply_text("❌ Tarif harus angka positif. Coba lagi:")
        return INPUT_TARIF_VALUE
    jenis = context.user_data.get("tarif_type")
    durasi = context.user_data.get("tarif_duration")
    tarif_cfg = get_server_config().get("tarif", {})
    if jenis not in tarif_cfg:
        tarif_cfg[jenis] = {}
    tarif_cfg[jenis][durasi] = int(val)
    cfg = get_server_config()
    cfg["tarif"] = tarif_cfg
    save_server_config(cfg)
    await update.message.reply_text(f"✅ Tarif {jenis.upper()} {durasi} hari berhasil diupdate menjadi {format_currency(int(val))}")
    return ConversationHandler.END

# Admin edit role
async def input_edit_role_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.message.text.strip()
    if not validate_int(user_id):
        await update.message.reply_text("❌ ID user harus angka. Coba lagi:")
        return INPUT_EDIT_ROLE_ID
    context.user_data["edit_role_id"] = int(user_id)
    keyboard = [
        [InlineKeyboardButton("Client", callback_data="role_Client")],
        [InlineKeyboardButton("Reseller", callback_data="role_Reseller")],
        [InlineKeyboardButton("Admin", callback_data="role_Admin")],
        [InlineKeyboardButton("🔙 Batal", callback_data="cancel")]
    ]
    await update.message.reply_text("Pilih role baru:", reply_markup=InlineKeyboardMarkup(keyboard))
    return INPUT_EDIT_ROLE_VALUE

async def input_edit_role_value(update: Update, context: ContextTypes.DEFAULT_TYPE):
    data = update.callback_query.data
    if not data.startswith("role_"):
        await update.callback_query.answer()
        return ConversationHandler.END
    new_role = data.split("_")[1]
    user_id = context.user_data.get("edit_role_id")
    if update_user_role(user_id, new_role):
        await update.callback_query.edit_message_text(f"✅ Role user {user_id} berhasil diubah menjadi {new_role}")
    else:
        await update.callback_query.edit_message_text(f"❌ User {user_id} tidak ditemukan.")
    return ConversationHandler.END

# Admin tambah server
async def input_add_server_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ip = update.message.text.strip()
    # Basic IP validation
    parts = ip.split(".")
    if len(parts) != 4 or not all(p.isdigit() and 0 <= int(p) <= 255 for p in parts):
        await update.message.reply_text("❌ IP tidak valid. Coba lagi:")
        return INPUT_ADD_SERVER_IP
    context.user_data["server_ip"] = ip
    await update.message.reply_text("Masukkan deskripsi server:")
    return INPUT_ADD_SERVER_DESC

async def input_add_server_desc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    desc = update.message.text.strip()
    cfg = get_server_config()
    servers = cfg.get("servers", [])
    servers.append({"ip": context.user_data["server_ip"], "desc": desc})
    cfg["servers"] = servers
    save_server_config(cfg)
    await update.message.reply_text(f"✅ Server baru berhasil ditambahkan:\nIP: {context.user_data['server_ip']}\nDeskripsi: {desc}")
    return ConversationHandler.END

# Cancel handler
async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("❌ Operasi dibatalkan.")
    return ConversationHandler.END

def main():
    app = Application.builder().token(TOKEN).build()

    conv_handler = ConversationHandler(
        entry_points=[
            CommandHandler("start", start),
            CallbackQueryHandler(handle_callback)
        ],
        states={
            MENU: [
                CallbackQueryHandler(handle_callb
