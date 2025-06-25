import json
import os
import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ContextTypes, filters
)

# Load config
with open("/etc/niku-bot/config.json") as f:
    config = json.load(f)

TOKEN = config["BOT_TOKEN"]
ADMIN_ID = config["ADMIN_IDS"][0] if isinstance(config["ADMIN_IDS"], list) else config["ADMIN_ID"]

# Sesi input user
session_data = {}

# /start
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    keyboard = [
        [InlineKeyboardButton("🛡️ Beli Akun VPN", callback_data="beli_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup_saldo")],
        [InlineKeyboardButton("🖥️ Registrasi IP VPS", callback_data="reg_ip")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")],
        [InlineKeyboardButton("👑 Admin Panel", callback_data="admin_panel")],
    ]
    await update.message.reply_text("Selamat datang di MERCURY VPN 👑", reply_markup=InlineKeyboardMarkup(keyboard))

# Handle tombol
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user_id = query.from_user.id
    await query.answer()
    data = query.data

    if data == "beli_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="beli_ssh"),
             InlineKeyboardButton("VMESS", callback_data="beli_vmess")],
            [InlineKeyboardButton("VLESS", callback_data="beli_vless"),
             InlineKeyboardButton("TROJAN", callback_data="beli_trojan")]
        ]
        await query.edit_message_text("Pilih jenis akun VPN:", reply_markup=InlineKeyboardMarkup(keyboard))

    elif data in ["beli_ssh", "beli_vmess", "beli_vless", "beli_trojan"]:
        jenis = data.replace("beli_", "")
        session_data[user_id] = {"step": "username", "jenis": jenis}
        await query.edit_message_text(f"🧾 Masukkan username akun {jenis.upper()}:")

    elif data == "reg_ip":
        ip = os.popen("curl -s ipv4.icanhazip.com").read().strip()
        allowed_path = "/var/www/html/allowed.json"
        try:
            if not os.path.exists(allowed_path):
                with open(allowed_path, "w") as f:
                    json.dump([], f)
            with open(allowed_path, "r+") as f:
                allowed = json.load(f)
                if ip not in allowed:
                    allowed.append(ip)
                    f.seek(0)
                    json.dump(allowed, f, indent=2)
                    f.truncate()
            await query.edit_message_text(f"✅ IP VPS {ip} berhasil diregistrasi.")
        except Exception as e:
            await query.edit_message_text(f"❌ Gagal registrasi IP: {e}")

    else:
        await query.edit_message_text("❌ Menu belum tersedia.")

# Input bertahap semua jenis akun
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text.strip()

    if user_id not in session_data:
        await update.message.reply_text("❗ Tidak ada proses aktif. Klik tombol menu terlebih dahulu.")
        return

    data = session_data[user_id]
    step = data.get("step")
    jenis = data.get("jenis", "ssh")

    if step == "username":
        data["username"] = text
        data["step"] = "hari"
        await update.message.reply_text("⏳ Masukkan masa aktif akun (hari):")
    elif step == "hari":
        if not text.isdigit():
            await update.message.reply_text("❌ Harus angka. Masukkan masa aktif:")
            return
        data["hari"] = text
        data["step"] = "iplimit"
        await update.message.reply_text("🔢 Masukkan limit IP login:")
    elif step == "iplimit":
        if not text.isdigit():
            await update.message.reply_text("❌ Harus angka. Masukkan IP limit:")
            return
        data["iplimit"] = text
        data["step"] = "kuota"
        await update.message.reply_text("📦 Masukkan kuota akun (dalam GB):")
    elif step == "kuota":
        if not text.isdigit():
            await update.message.reply_text("❌ Harus angka. Masukkan kuota GB:")
            return
        data["kuota"] = text

        # Eksekusi perintah
        username = data["username"]
        hari = data["hari"]
        iplimit = data["iplimit"]
        kuota = data["kuota"]
        command = f"bash /root/menu/menu-{jenis}.sh add {username} {hari} {iplimit} {kuota}"

        try:
            output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT, text=True)
        except subprocess.CalledProcessError as e:
            output = f"❌ Gagal membuat akun:\n{e.output}"

        await update.message.reply_text(f"✅ Akun {jenis.upper()} berhasil dibuat:\n\n<code>{output}</code>", parse_mode="HTML")
        session_data.pop(user_id)
    else:
        await update.message.reply_text("❗ Sesi tidak valid. Mulai ulang.")
        session_data.pop(user_id, None)

# Main bot
def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.run_polling()

if __name__ == '__main__':
    main()
    
