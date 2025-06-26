#!/bin/bash
clear
echo -e "\e[36m⬇️ INSTALL BOT TELEGRAM REGISTRASI IP VPS — NIKU TUNNEL\e[0m"

# Persiapan direktori
mkdir -p /root/niku-bot
cd /root/niku-bot

# Install dependensi
apt update -y
apt install -y python3 python3-pip nginx curl jq
pip3 install python-telegram-bot==20.7

# config.json
cat > config.json <<EOF
{
  "BOT_TOKEN": "ISI_TOKEN_BOT_KAMU",
  "ADMIN_IDS": [123456789],
  "TARIF": {
    "ipreg": 5000
  }
}
EOF

# allowed.json (kosong di awal)
echo "[]" > allowed.json

# bot.py
cat > bot.py <<'EOF'
import json, logging, os
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
  Application, CommandHandler, CallbackQueryHandler,
  MessageHandler, ContextTypes, ConversationHandler, filters
)

logging.basicConfig(level=logging.INFO)
MENU, IP, CLIENT_NAME, MASA_AKTIF, TOPUP, RENEW_IP = range(6)

def load_json(file):
  if not os.path.exists(file):
    with open(file, 'w') as f: f.write('{}' if 'saldo' in file else '[]')
  with open(file) as f: return json.load(f)

def save_json(file, data):
  with open(file, 'w') as f: json.dump(data, f, indent=2)

def load_config(): return load_json("config.json")
def load_allowed(): return load_json("allowed.json")
def save_allowed(data): save_json("allowed.json", data)
def load_saldo(): return load_json("saldo.json")
def save_saldo(data): save_json("saldo.json", data)

def is_admin(uid): return uid in load_config().get("ADMIN_IDS", [])

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
  uid = str(update.effective_user.id)
  saldo = load_saldo().get(uid, 0)
  keyboard = [
    [InlineKeyboardButton("📥 Register IP", callback_data="reg_ip")],
    [InlineKeyboardButton("🔄 Renew IP", callback_data="renew_ip")],
    [InlineKeyboardButton("📋 List IP", callback_data="list_ip")],
    [InlineKeyboardButton("❌ Hapus IP", callback_data="hapus_ip")],
    [InlineKeyboardButton("💰 Topup Saldo", callback_data="topup")]
  ]
  if is_admin(update.effective_user.id):
    keyboard.append([
      InlineKeyboardButton("➕ Tambah Saldo", callback_data="tambah_saldo"),
      InlineKeyboardButton("➖ Kurangi Saldo", callback_data="kurangi_saldo")
    ])
  reply_markup = InlineKeyboardMarkup(keyboard)
  await update.message.reply_text(
    f"🛡️ *NIKU IP REGISTRASI BOT*\nSaldo kamu: Rp {saldo}\nPilih menu:",
    parse_mode='Markdown', reply_markup=reply_markup)
  return MENU

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
  q = update.callback_query
  await q.answer()
  context.user_data['menu'] = q.data

  if q.data == "reg_ip":
    await q.edit_message_text("🧠 Masukkan IP VPS yang ingin diregistrasi:")
    return IP
  elif q.data == "renew_ip":
    await q.edit_message_text("🔄 Masukkan IP VPS yang ingin diperpanjang:")
    return RENEW_IP
  elif q.data == "list_ip":
    data = load_allowed()
    msg = "\n".join([f"{i+1}. {x['ip']} ({x['client']}) Exp: {x['exp']}" for i,x in enumerate(data)]) or "❌ Tidak ada data."
    await q.edit_message_text("📋 *Daftar IP Terdaftar:*\n" + msg, parse_mode='Markdown')
  elif q.data == "hapus_ip":
    await q.edit_message_text("🧹 Masukkan IP VPS yang ingin dihapus:")
    return IP
  elif q.data in ("topup", "tambah_saldo", "kurangi_saldo"):
    await q.edit_message_text("💬 Masukkan format: `id jumlah` (contoh: 123456789 5000)", parse_mode='Markdown')
    return TOPUP
  return MENU

async def handle_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
  menu = context.user_data.get('menu')
  msg = update.message.text.strip()
  uid = str(update.effective_user.id)
  saldo = load_saldo()
  allowed = load_allowed()

  if menu == "reg_ip":
    context.user_data["ip"] = msg
    await update.message.reply_text("📝 Masukkan nama client:")
    return CLIENT_NAME

  elif menu == "hapus_ip":
    allowed = [x for x in allowed if x["ip"] != msg]
    save_allowed(allowed)
    await update.message.reply_text("✅ IP berhasil dihapus.")
    return MENU

  elif menu == "renew_ip":
    context.user_data["ip"] = msg
    await update.message.reply_text("🕒 Masukkan jumlah hari perpanjangan (1-60):")
    return MASA_AKTIF

  elif menu in ("topup", "tambah_saldo", "kurangi_saldo"):
    try:
      id_str, jumlah_str = msg.split()
      jumlah = int(jumlah_str)
      if not is_admin(update.effective_user.id) and menu != "topup":
        await update.message.reply_text("❌ Akses ditolak.")
        return MENU
      if menu == "topup":
        saldo[uid] = saldo.get(uid, 0) + jumlah
        await update.message.reply_text(f"✅ Saldo berhasil ditambahkan Rp {jumlah}. Total saldo: Rp {saldo[uid]}")
      elif menu == "tambah_saldo":
        saldo[id_str] = saldo.get(id_str, 0) + jumlah
        await update.message.reply_text(f"✅ Saldo user {id_str} ditambah Rp {jumlah}.")
      elif menu == "kurangi_saldo":
        saldo[id_str] = max(0, saldo.get(id_str, 0) - jumlah)
        await update.message.reply_text(f"✅ Saldo user {id_str} dikurangi Rp {jumlah}.")
      save_saldo(saldo)
    except:
      await update.message.reply_text("❌ Format salah. Contoh: `123456789 5000`")
    return MENU
  return MENU

async def handle_client_name(update: Update, context: ContextTypes.DEFAULT_TYPE):
  context.user_data["client"] = update.message.text.strip()
  await update.message.reply_text("📅 Masukkan masa aktif (1-60 hari):")
  return MASA_AKTIF

async def handle_exp(update: Update, context: ContextTypes.DEFAULT_TYPE):
  try:
    days = int(update.message.text.strip())
    if not (1 <= days <= 60): raise ValueError()
    uid = str(update.effective_user.id)
    saldo = load_saldo()
    tarif = load_config()["TARIF"].get("ipreg", 0)
    if saldo.get(uid, 0) < tarif:
      await update.message.reply_text(f"❌ Saldo tidak cukup. Dibutuhkan: Rp {tarif}")
      return MENU
    saldo[uid] -= tarif
    save_saldo(saldo)

    ip = context.user_data["ip"]
    client = context.user_data.get("client", f"user_{uid}")
    exp = (datetime.now() + timedelta(days=days)).strftime("%Y-%m-%d")
    data = load_allowed()
    for d in data:
      if d["ip"] == ip:
        d["exp"] = exp
        break
    else:
      data.append({"ip": ip, "client": client, "exp": exp})
    save_allowed(data)
    await update.message.reply_text(f"✅ IP `{ip}` didaftarkan hingga {exp}.\nSaldo tersisa: Rp {saldo[uid]}", parse_mode='Markdown')
  except:
    await update.message.reply_text("❌ Input tidak valid atau saldo kurang.")
  return MENU

def main():
  app = Application.builder().token(load_config()["BOT_TOKEN"]).build()
  conv_handler = ConversationHandler(
    entry_points=[CommandHandler("start", start)],
    states={
      MENU: [CallbackQueryHandler(handle_callback)],
      IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_input)],
      CLIENT_NAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_client_name)],
      MASA_AKTIF: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_exp)],
      TOPUP: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_input)],
      RENEW_IP: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_input)],
    },
    fallbacks=[CommandHandler("start", start)],
  )
  app.add_handler(conv_handler)
  app.run_polling()

if __name__ == '__main__':
  main()
EOF

# Systemd service
cat > /etc/systemd/system/niku-bot.service <<EOF
[Unit]
Description=NIKU TUNNEL TELEGRAM BOT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/niku-bot/bot.py
WorkingDirectory=/root/niku-bot
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Nginx link
mkdir -p /var/www/html/data
ln -sf /root/niku-bot/allowed.json /var/www/html/data/allowed.json
systemctl restart nginx

# Enable bot service
systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

# Done
IPV4=$(curl -s ipv4.icanhazip.com)
echo -e "\n\e[32m✅ INSTALLASI SELESAI.\e[0m"
echo -e "➡️ Edit \e[33m/root/niku-bot/config.json\e[0m untuk masukkan token & admin ID"
echo -e "🌐 File allowed.json publik: https://$IPV4/data/allowed.json"
echo -e "🔁 Restart bot: \e[36msystemctl restart niku-bot\e[0m"
