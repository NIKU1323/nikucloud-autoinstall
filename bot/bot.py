import json
import subprocess
import os
import time
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InputFile
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters
)

with open("/etc/niku-bot/config.json") as f:
    config = json.load(f)

TOKEN = config["BOT_TOKEN"]
ADMIN_IDS = config["ADMIN_IDS"]
TARIF = config["TARIF"]

(SELECT_TYPE, INPUT_USERNAME, INPUT_DAYS, INPUT_IP, INPUT_QUOTA) = range(5)
user_data_map = {}

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

def update_user_saldo(user_id: int, amount: int):
    try:
        with open("/etc/niku-bot/users.json") as f:
            users = json.load(f)
        uid = str(user_id)
        if uid in users:
            users[uid]["saldo"] -= amount
            with open("/etc/niku-bot/users.json", "w") as f:
                json.dump(users, f, indent=2)
            return True
    except:
        pass
    return False

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

    elif data == "tambah_saldo":
        await query.edit_message_text("📥 Masukkan ID dan jumlah saldo (contoh: `123456 5000`):", parse_mode="Markdown")
        context.user_data["mode"] = "tambah"
        return ConversationHandler.END

    elif data == "kurangi_saldo":
        await query.edit_message_text("📤 Masukkan ID dan jumlah saldo yang dikurangi (contoh: `123456 5000`):", parse_mode="Markdown")
        context.user_data["mode"] = "kurangi"
        return ConversationHandler.END

    elif data == "upload_qris":
        await query.edit_message_text("📤 Silakan kirim file gambar QRIS:")
        context.user_data["mode"] = "upload_qris"
        return ConversationHandler.END

    elif data == "daftar_user":
        try:
            with open("/etc/niku-bot/users.json") as f:
                users = json.load(f)
            teks = "📋 Daftar User:\n"
            for uid, info in users.items():
                teks += f"• {uid} (@{info.get('username','-')}) — Rp{info.get('saldo',0)} [{info.get('role','Client')}]\n"
            await query.edit_message_text(teks)
        except:
            await query.edit_message_text("❌ Gagal membaca data user.")
        return ConversationHandler.END

    elif data == "hapus_user":
        await query.edit_message_text("🗑️ Kirim ID user yang ingin dihapus:")
        context.user_data["mode"] = "hapus_user"
        return ConversationHandler.END

    else:
        await query.edit_message_text(f"❌ Callback `{data}` belum tersedia.")
        return ConversationHandler.END

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

    tarif = TARIF.get(jenis, 0)
    role, saldo = get_user_info(user_id)

    if saldo < tarif:
        await update.message.reply_text(f"❌ Saldo tidak cukup. Tarif: Rp{tarif}, Saldo Anda: Rp{saldo}")
        return ConversationHandler.END

    update_user_saldo(user_id, tarif)

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

    await update.message.reply_text(f"✅ Hasil:\n```\n{output}\n```", parse_mode="Markdown")
    return ConversationHandler.END

async def handle_admin_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    mode = context.user_data.get("mode")
    text = update.message.text.strip()

    if mode == "tambah" or mode == "kurangi":
        if " " not in text:
            await update.message.reply_text("❌ Format salah. Gunakan: `id jumlah`")
            return
        uid, amount = text.split()
        uid = str(uid)
        amount = int(amount)
        with open("/etc/niku-bot/users.json") as f:
            users = json.load(f)
        if uid not in users:
            await update.message.reply_text("❌ ID user tidak ditemukan.")
            return
        if mode == "tambah":
            users[uid]["saldo"] += amount
        else:
            users[uid]["saldo"] -= amount
        with open("/etc/niku-bot/users.json", "w") as f:
            json.dump(users, f, indent=2)
        await update.message.reply_text("✅ Saldo berhasil diperbarui.")
        context.user_data["mode"] = None

    elif mode == "hapus_user":
        uid = text.strip()
        with open("/etc/niku-bot/users.json") as f:
            users = json.load(f)
        if uid in users:
            del users[uid]
            with open("/etc/niku-bot/users.json", "w") as f:
                json.dump(users, f, indent=2)
            await update.message.reply_text(f"✅ User {uid} telah dihapus.")
        else:
            await update.message.reply_text("❌ ID user tidak ditemukan.")
        context.user_data["mode"] = None

async def handle_upload_qris(update: Update, context: ContextTypes.DEFAULT_TYPE):
    mode = context.user_data.get("mode")
    if mode == "upload_qris" and update.message.document:
        file = await update.message.document.get_file()
        await file.download_to_drive("/etc/niku-bot/qris.png")
        await update.message.reply_text("✅ QRIS berhasil diunggah.")
        context.user_data["mode"] = None

async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("❌ Dibatalkan.")
    return ConversationHandler.END

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
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_admin_input))
    app.add_handler(MessageHandler(filters.Document.ALL, handle_upload_qris))
    app.run_polling()

if __name__ == '__main__':
    main()
  
