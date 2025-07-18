import json, os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, \
    MessageHandler, filters, ContextTypes, ConversationHandler

# State constants
(TOPUP_AMOUNT, TOPUP_PROOF, ADD_SALDO_USERID, ADD_SALDO_AMOUNT,
 REMOVE_SALDO_USERID, REMOVE_SALDO_AMOUNT, CHANGE_PRICE,
 CHANGE_ROLE_USERID, CHANGE_ROLE_NEWROLE, BROADCAST_MSG) = range(10)

# Load data.json
DATA_FILE = "data.json"
def load(): return json.load(open(DATA_FILE))
def save(d): json.dump(d, open(DATA_FILE,"w"), indent=2)

data = load()

# Ensure user exists
def ensure_user(uid):
    users = data["users"]
    if uid not in users:
        users[uid] = {"role": "user", "saldo": 0}
        save(data)

# /start handler
async def start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    uid = str(update.effective_user.id)
    ensure_user(uid)
    user = data["users"][uid]
    text = (
        f"HAI {update.effective_user.first_name}\n"
        f"ID: {uid}\n"
        f"ROLE: {user['role'].upper()}\n"
        f"SALDO: {user['saldo']}\n"
    )
    buttons = [[InlineKeyboardButton("💰 Top Up Saldo", callback_data="topup")]]
    if user["role"] == "admin":
        buttons.append([InlineKeyboardButton("🛠️ Admin Panel", callback_data="admin")])
    await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(buttons))
    return ConversationHandler.END

# Callback handler
async def button_handler(update: Update, ctx):
    query = update.callback_query
    await query.answer()
    uid = str(query.from_user.id)
    ensure_user(uid)
    data = load()

    if query.data == "topup":
        await query.edit_message_text("Masukkan nominal top up:")
        return TOPUP_AMOUNT

    if query.data == "admin" and data["users"][uid]["role"] == "admin":
        kb = [
            [InlineKeyboardButton("➕ Tambah Saldo", callback_data="add")],
            [InlineKeyboardButton("🔖 Ubah Harga", callback_data="price")],
            [InlineKeyboardButton("🔄 Ubah Role", callback_data="changerole")],
            [InlineKeyboardButton("📢 Broadcast", callback_data="bc")],
            [InlineKeyboardButton("🚧 Maintenance", callback_data="maint")],
            [InlineKeyboardButton("🔙 Kembali", callback_data="back")]
        ]
        await query.edit_message_text("Admin Panel:", reply_markup=InlineKeyboardMarkup(kb))
        return ConversationHandler.END

    if query.data == "back":
        return await start(update, ctx)

    if query.data == "bc":
        await query.edit_message_text("Masukkan teks broadcast:")
        return BROADCAST_MSG

    if query.data == "add":
        await query.edit_message_text("Masukkan ID user:")
        return ADD_SALDO_USERID

    if query.data == "price":
        await query.edit_message_text("Masukkan harga baru per IP:")
        return CHANGE_PRICE

    if query.data == "changerole":
        await query.edit_message_text("Masukkan ID user:")
        return CHANGE_ROLE_USERID

    if query.data == "maint":
        data["maintenance"] = not data["maintenance"]
        save(data)
        await query.edit_message_text(f"Maintenance = {data['maintenance']}")
        return ConversationHandler.END

    return ConversationHandler.END

# Handlers for each state
async def topup_amt(update, ctx):
    uid = str(update.effective_user.id)
    amt = update.message.text
    data = load()
    data["topup_requests"][uid] = int(amt)
    save(data)
    await update.message.reply_text(
        f"Transfer ke Dana: {data['dana']} atau GoPay: {data['gopay']}\n"
        "Lalu kirim bukti transfer."
    )
    return TOPUP_PROOF

async def topup_proof(update, ctx):
    uid = str(update.effective_user.id)
    amt = data["topup_requests"].get(uid,0)
    for admin in [str(data["admin_id"])]:
        await ctx.bot.send_photo(
            chat_id=admin,
            photo=update.message.photo[-1].file_id,
            caption=f"Top Up by {uid}, nominal: {amt}\nConfirm?"
        )
    await update.message.reply_text("Menunggu konfirmasi admin.")
    return ConversationHandler.END

async def bc_msg(update, ctx):
    text = update.message.text
    for u in data["users"]:
        try: await ctx.bot.send_message(u, text)
        except: pass
    await update.message.reply_text("Broadcast done.")
    return ConversationHandler.END

async def add_uid(update, ctx):
    ctx.user_data["target"] = update.message.text
    await update.message.reply_text("Masukkan jumlah saldo:")
    return ADD_SALDO_AMOUNT

async def add_amt(update, ctx):
    uid = ctx.user_data["target"]
    data = load()
    data["users"][uid]["saldo"] += int(update.message.text)
    save(data)
    await update.message.reply_text("Saldo ditambahkan.")
    return ConversationHandler.END

async def change_price(update, ctx):
    data["price_per_ip"] = int(update.message.text)
    save(data)
    await update.message.reply_text("Harga diperbarui.")
    return ConversationHandler.END

async def change_role_uid(update, ctx):
    ctx.user_data["target"] = update.message.text
    await update.message.reply_text("Masukkan role baru (user/reseller/admin):")
    return CHANGE_ROLE_NEWROLE

async def change_role_new(update, ctx):
    data["users"][ctx.user_data["target"]]["role"] = update.message.text
    save(data)
    await update.message.reply_text("Role diperbarui.")
    return ConversationHandler.END

def main():
    app = Application.builder().token(data["token"]).build()
    conv = ConversationHandler(
        entry_points=[CommandHandler("start", start), CallbackQueryHandler(button_handler)],
        states={
            TOPUP_AMOUNT: [MessageHandler(filters.TEXT, topup_amt)],
            TOPUP_PROOF: [MessageHandler(filters.PHOTO, topup_proof)],
            BROADCAST_MSG: [MessageHandler(filters.TEXT, bc_msg)],
            ADD_SALDO_USERID: [MessageHandler(filters.TEXT, add_uid)],
            ADD_SALDO_AMOUNT: [MessageHandler(filters.TEXT, add_amt)],
            CHANGE_PRICE: [MessageHandler(filters.TEXT, change_price)],
            CHANGE_ROLE_USERID: [MessageHandler(filters.TEXT, change_role_uid)],
            CHANGE_ROLE_NEWROLE: [MessageHandler(filters.TEXT, change_role_new)],
        },
        fallbacks=[]
    )
    app.add_handler(conv)
    app.add_handler(CallbackQueryHandler(button_handler))
    app.run_polling()

if __name__ == "__main__":
    main()
        
