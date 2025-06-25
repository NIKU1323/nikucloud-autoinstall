import json
import os
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackContext, CallbackQueryHandler, MessageHandler, filters, ContextTypes

# Load config
with open("/etc/niku-bot/config.json") as f:
    config = json.load(f)

TOKEN = config["bot_token"]
ADMIN_ID = config["admin_id"]

# Fungsi saat /start diketik
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_id = user.id
    username = user.username or "N/A"

    keyboard = [
        [InlineKeyboardButton("🛡️ Beli Akun VPN", callback_data="beli_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup_saldo")],
        [InlineKeyboardButton("🖥️ Registrasi IP VPS", callback_data="reg_ip")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")],
        [InlineKeyboardButton("👑 Admin Panel", callback_data="admin_panel")],
    ]

    reply_markup = InlineKeyboardMarkup(keyboard)
    text = (
        "🛒 MERCURY VPN — Bot E-Commerce VPN & Digital\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📈 Statistik Toko:\n"
        f"• 👥 Pengguna: {user_id}\n"
        f"• 🗄️ Jumlah Server VPN: -\n"
        f"• ⏱️ Uptime Bot: -\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👤 Akun Anda:\n"
        f"• 🆔 ID: {user_id}\n"
        f"• Username: @{username}\n"
        f"• Role: {'Admin' if user_id == int(ADMIN_ID) else 'Client'}\n"
        f"• Saldo: -\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"Customer Service: @mercurystore12\n"
        "━━━━━━━━━━━━━━━━━━━━━━"
    )
    await update.message.reply_text(text, reply_markup=reply_markup)

# Fungsi handle tombol
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    if data == "beli_akun":
        keyboard = [
            [InlineKeyboardButton("SSH", callback_data="beli_ssh"),
             InlineKeyboardButton("VMESS", callback_data="beli_vmess")],
            [InlineKeyboardButton("VLESS", callback_data="beli_vless"),
             InlineKeyboardButton("TROJAN", callback_data="beli_trojan")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await query.edit_message_text("Pilih jenis akun:", reply_markup=reply_markup)

    elif data == "admin_panel":
        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="tambah_saldo"),
             InlineKeyboardButton("➖ Kurangi Saldo", callback_data="kurangi_saldo")],
            [InlineKeyboardButton("📋 Daftar User", callback_data="daftar_user"),
             InlineKeyboardButton("🗑️ Hapus User", callback_data="hapus_user")],
            [InlineKeyboardButton("💰 Atur Tarif", callback_data="atur_tarif"),
             InlineKeyboardButton("🧩 Server VPN", callback_data="server_vpn")],
            [InlineKeyboardButton("📤 Upload QRIS", callback_data="upload_qris")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await query.edit_message_text("👑 Menu Admin", reply_markup=reply_markup)

    else:
        await query.edit_message_text(f"❌ Gagal: Callback `{data}` belum tersedia.")

# Jalankan bot
def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.run_polling()

if __name__ == '__main__':
    main()
  
