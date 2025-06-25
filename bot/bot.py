import json
import subprocess
import os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InputFile
from telegram.ext import (Application, CommandHandler, CallbackQueryHandler,
                          MessageHandler, ConversationHandler, ContextTypes, filters)

# Load config
with open("/etc/niku-bot/config.json") as f:
    config = json.load(f)

TOKEN = config["BOT_TOKEN"]
ADMIN_IDS = config["ADMIN_IDS"]

# State untuk ConversationHandler
(SELECT_TYPE, INPUT_USERNAME, INPUT_DAYS, INPUT_IP, INPUT_QUOTA) = range(5)
user_data_map = {}

# Fungsi tambahan

def get_user_info(user_id: int):
    try:
        with open("/etc/niku-bot/users.json") as f:
            users = json.load(f)
        user = users.get(str(user_id), {})
        role = user.get("role", "Client")
        saldo = user.get("saldo", 0)
        return role, saldo
    except:
        return "Client", 0

def count_users():
    try:
        with open("/etc/niku-bot/users.json") as f:
            users = json.load(f)
        return len(users)
    except:
        return 0

def count_servers():
    try:
        with open("/etc/niku-bot/server_config.json") as f:
            servers = json.load(f)
        return len(servers)
    except:
        return 0

def get_uptime():
    try:
        with open("/proc/uptime", "r") as f:
            seconds = float(f.readline().split()[0])
        minutes = int(seconds // 60)
        hours = minutes // 60
        days = hours // 24
        return f"{days}d {hours%24}h {minutes%60}m"
    except:
        return "-"

# Start command
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_id = user.id
    username = user.username or "N/A"

    role, saldo = get_user_info(user_id)
    jumlah_user = count_users()
    jumlah_server = count_servers()
    uptime_bot = get_uptime()

    keyboard = [
        [InlineKeyboardButton("🛡️ Beli Akun VPN", callback_data="beli_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup_saldo")],
        [InlineKeyboardButton("🖥️ Registrasi IP VPS", callback_data="reg_ip")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")],
        [InlineKeyboardButton("👑 Admin Panel", callback_data="admin_panel")]
    ]

    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text(
        f"🛒 MERCURY VPN — Bot E-Commerce VPN & Digital\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📈 Statistik Toko:\n"
        f"• 👥 Pengguna: {jumlah_user}\n"
        f"• 🗄️ Jumlah Server VPN: {jumlah_server}\n"
        f"• ⏱️ Uptime Bot: {uptime_bot}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👤 Akun Anda:\n"
        f"• 🆔 ID: {user_id}\n"
        f"• Username: @{username}\n"
        f"• Role: {role}\n"
        f"• Saldo: Rp{saldo}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"Customer Service: @mercurystore12\n"
        f"━━━━━━━━━━━━━━━━━━━━━━",
        reply_markup=reply_markup
    )

# Callback utama
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data
    user_id = query.from_user.id

    if data == "beli_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="ssh"),
             InlineKeyboardButton("VMESS", callback_data="vmess")],
            [InlineKeyboardButton("VLESS", callback_data="vless"),
             InlineKeyboardButton("TROJAN", callback_data="trojan")]
        ]
        await query.edit_message_text("Pilih jenis akun:", reply_markup=InlineKeyboardMarkup(keyboard))
        return SELECT_TYPE

    elif data == "admin_panel":
        if user_id not in ADMIN_IDS:
            await query.edit_message_text("❌ Anda bukan admin.")
            return ConversationHandler.END

        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="tambah_saldo"),
             InlineKeyboardButton("➖ Kurangi Saldo", callback_data="kurangi_saldo")],
            [InlineKeyboardButton("📋 Daftar User", callback_data="daftar_user"),
             InlineKeyboardButton("🗑️ Hapus User", callback_data="hapus_user")],
            [InlineKeyboardButton("📤 Upload QRIS", callback_data="upload_qris")]
        ]
        await query.edit_message_text("👑 Menu Admin:", reply_markup=InlineKeyboardMarkup(keyboard))
        return ConversationHandler.END

    elif data == "cek_saldo":
        role, saldo = get_user_info(user_id)
        await query.edit_message_text(f"👤 Role: {role}\n💰 Saldo Anda: Rp{saldo}")
        return ConversationHandler.END

    else:
        await query.edit_message_text(f"❌ Callback `{data}` belum tersedia.")
        return ConversationHandler.END

# Proses pembuatan akun VPN
async def select_type(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = query.from_user.id
    user_data_map[user_id] = {"type": query.data}
    await query.edit_message_text("Masukkan username:")
    return INPUT_USERNAME

async def input_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_data_map[user_id]["username"] = update.message.text
    await update.message.reply_text("Masa aktif (hari):")
    return INPUT_DAYS

async def input_days(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_data_map[user_id]["days"] = update.message.text
    await update.message.reply_text("Limit IP:")
    return INPUT_IP

async def input_ip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_data_map[user_id]["ip"] = update.message.text
    await update.message.reply_text("Limit Kuota (GB):")
    return INPUT_QUOTA

async def input_quota(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_data = user_data_map[user_id]
    user_data["quota"] = update.message.text

    jenis = user_data["type"]
    username = user_data["username"]
    days = user_data["days"]
    iplimit = user_data["ip"]
    quota = user_data["quota"]

    cmd_map = {
        "ssh": "/root/menu/menu-ssh.sh",
        "vmess": "/root/menu/menu-vmess.sh",
        "vless": "/root/menu/menu-vless.sh",
        "trojan": "/root/menu/menu-trojan.sh",
    }

    cmd = ["bash", cmd_map[jenis], "add", username, days, iplimit, quota]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        output = result.stdout or result.stderr
    except Exception as e:
        output = f"❌ Gagal menjalankan script: {e}"

    await update.message.reply_text(f"✅ Hasil:\n```
{output}
```", parse_mode="Markdown")
    return ConversationHandler.END

async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("❌ Dibatalkan oleh pengguna.")
    return ConversationHandler.END

# Main
def main():
    app = Application.builder().token(TOKEN).build()

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            SELECT_TYPE: [CallbackQueryHandler(select_type)],
            INPUT_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_username)],
            INPUT_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_days)],
            INPUT_IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_ip)],
            INPUT_QUOTA: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_quota)],
        },
        fallbacks=[CommandHandler("cancel", cancel)]
    )

    app.add_handler(conv_handler)
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.run_polling()

if __name__ == '__main__':
    main()
    
