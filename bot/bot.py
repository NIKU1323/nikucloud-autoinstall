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

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Load config
with open("/etc/niku-bot/config.json") as f:
    config = json.load(f)

TOKEN = config["BOT_TOKEN"]
ADMIN_IDS = config["ADMIN_IDS"]
TARIF = config["TARIF"]

# State definitions
(SELECT_TYPE, INPUT_USERNAME, INPUT_DAYS, INPUT_IP, INPUT_QUOTA) = range(5)
user_data_map = {}

def get_user_info(user_id: int):
    try:
        with open("/etc/niku-bot/users.json") as f:
            users = json.load(f)
        user = users.get(str(user_id), {})
        return user.get("role", "Client"), user.get("saldo", 0)
    except Exception as e:
        logger.error(f"Error reading user info: {e}")
        return "Client", 0

def update_user_saldo(user_id: int, amount: int):
    try:
        with open("/etc/niku-bot/users.json", "r+") as f:
            users = json.load(f)
            uid = str(user_id)
            if uid in users:
                users[uid]["saldo"] -= amount
                f.seek(0)
                json.dump(users, f, indent=2)
                f.truncate()
                return True
    except Exception as e:
        logger.error(f"Error updating saldo: {e}")
    return False

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    role, saldo = get_user_info(user.id)
    
    keyboard = [
        [InlineKeyboardButton("🛡️ Beli Akun VPN", callback_data="beli_akun")],
        [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup_saldo")],
        [InlineKeyboardButton("💰 Cek Saldo", callback_data="cek_saldo")],
        [InlineKeyboardButton("👑 Admin Panel", callback_data="admin_panel")]
    ]
    
    await update.message.reply_text(
        f"🛒 MERCURY VPN BOT\n"
        f"━━━━━━━━━━━━━━━━━━\n"
        f"👤 Akun Anda:\n"
        f"• Role: {role}\n"
        f"• Saldo: Rp{saldo}\n",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

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
        await query.edit_message_text(
            "Pilih jenis akun:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        return SELECT_TYPE
        
    elif data == "admin_panel":
        if query.from_user.id not in ADMIN_IDS:
            await query.edit_message_text("❌ Akses ditolak!")
            return ConversationHandler.END
            
        keyboard = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="tambah_saldo")],
            [InlineKeyboardButton("📋 Daftar User", callback_data="daftar_user")]
        ]
        await query.edit_message_text(
            "👑 MENU ADMIN",
            reply_markup=InlineKeyboardMarkup(keyboard))
        return ConversationHandler.END
        
    elif data == "cek_saldo":
        role, saldo = get_user_info(query.from_user.id)
        await query.edit_message_text(f"💰 Saldo: Rp{saldo}")
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
    
    # Process payment
    jenis = user_data["type"]
    tarif = TARIF.get(jenis, 0)
    role, saldo = get_user_info(user_id)
    
    if saldo < tarif:
        await update.message.reply_text(f"❌ Saldo tidak cukup! Butuh Rp{tarif}")
        return ConversationHandler.END
    
    # Execute creation script
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
            update_user_saldo(user_id, tarif)
            await update.message.reply_text(f"✅ Akun berhasil dibuat!\n{output}")
        else:
            await update.message.reply_text(f"❌ Gagal:\n{output}")
            
    except Exception as e:
        await update.message.reply_text(f"⚠️ Error system: {str(e)}")
    
    return ConversationHandler.END

def main():
    app = Application.builder().token(TOKEN).build()
    
    # Main conversation handler
    conv_handler = ConversationHandler(
        entry_points=[
            CommandHandler("start", start),
            CallbackQueryHandler(handle_callback)
        ],
        states={
            SELECT_TYPE: [CallbackQueryHandler(select_type)],
            INPUT_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_username)],
            INPUT_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_days)],
            INPUT_IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_ip)],
            INPUT_QUOTA: [MessageHandler(filters.TEXT & ~filters.COMMAND, input_quota)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True
    )
    
    app.add_handler(conv_handler)
    app.run_polling()

if __name__ == '__main__':
    main()
