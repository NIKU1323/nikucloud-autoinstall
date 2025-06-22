#!/bin/bash
# AUTO INSTALL TELEGRAM BOT REGISTRASI IP VPS
# Author: NIKU TUNNEL / MERCURYVPN

GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

echo -e "${YELLOW}[INFO] Install dependensi Python...${NC}"
apt install -y python3 python3-pip
pip3 install python-telegram-bot --quiet

mkdir -p /root/bot

echo -e "${YELLOW}[INFO] Membuat file config.json...${NC}"
cat <<EOF > /root/bot/config.json
{
  "token": "ISI_TOKEN_BOT_KAMU",
  "admin_id": 123456789,
  "allowed_file": "/root/bot/allowed.json"
}
EOF

echo -e "${YELLOW}[INFO] Membuat allowed.json kosong...${NC}"
echo "[]" > /root/bot/allowed.json

echo -e "${YELLOW}[INFO] Membuat bot.py...${NC}"
cat <<'EOF' > /root/bot/bot.py
import json, logging
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes
import os

with open("/root/bot/config.json") as f:
    config = json.load(f)

TOKEN = config["token"]
ADMIN_ID = config["admin_id"]
FILE = config["allowed_file"]

def save(data):
    with open(FILE, "w") as f:
        json.dump(data, f, indent=2)

def load():
    with open(FILE) as f:
        return json.load(f)

def find_ip(data, ip):
    for i, entry in enumerate(data):
        if entry["ip"] == ip:
            return i
    return -1

async def addip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    try:
        ip, client, expired = context.args
    except:
        await update.message.reply_text("Usage:\n/addip ip client expired\nExample:\n/addip 1.2.3.4 MercuryVPN 2025-07-01")
        return
    data = load()
    if find_ip(data, ip) != -1:
        await update.message.reply_text("IP sudah terdaftar.")
        return
    data.append({"ip": ip, "client": client, "expired": expired})
    save(data)
    await update.message.reply_text(f"✅ IP {ip} berhasil ditambahkan.")

async def listip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    data = load()
    if not data:
        await update.message.reply_text("❌ Belum ada IP terdaftar.")
        return
    msg = "📋 Daftar IP Terdaftar:\n"
    for i, d in enumerate(data, 1):
        msg += f"{i}. {d['ip']} | {d['client']} | Exp: {d['expired']}\n"
    await update.message.reply_text(msg)

async def renewip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    try:
        ip, new_exp = context.args
    except:
        await update.message.reply_text("Usage:\n/renewip ip yyyy-mm-dd")
        return
    data = load()
    i = find_ip(data, ip)
    if i == -1:
        await update.message.reply_text("❌ IP tidak ditemukan.")
        return
    data[i]["expired"] = new_exp
    save(data)
    await update.message.reply_text(f"✅ Expired IP {ip} diperbarui ke {new_exp}.")

async def editclient(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    try:
        ip, new_name = context.args
    except:
        await update.message.reply_text("Usage:\n/editclient ip nama_baru")
        return
    data = load()
    i = find_ip(data, ip)
    if i == -1:
        await update.message.reply_text("❌ IP tidak ditemukan.")
        return
    data[i]["client"] = new_name
    save(data)
    await update.message.reply_text(f"✅ Client IP {ip} diubah ke {new_name}.")

async def removeip(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    try:
        ip = context.args[0]
    except:
        await update.message.reply_text("Usage:\n/removeip ip")
        return
    data = load()
    i = find_ip(data, ip)
    if i == -1:
        await update.message.reply_text("❌ IP tidak ditemukan.")
        return
    data.pop(i)
    save(data)
    await update.message.reply_text(f"🗑️ IP {ip} berhasil dihapus.")

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    await update.message.reply_text("🤖 Bot Siap!\nPerintah:\n/addip\n/listip\n/renewip\n/editclient\n/removeip")

def main():
    app = ApplicationBuilder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("addip", addip))
    app.add_handler(CommandHandler("listip", listip))
    app.add_handler(CommandHandler("renewip", renewip))
    app.add_handler(CommandHandler("editclient", editclient))
    app.add_handler(CommandHandler("removeip", removeip))
    app.run_polling()

if __name__ == "__main__":
    main()
EOF

echo -e "${YELLOW}[INFO] Membuat service bot.service...${NC}"
cat <<EOF > /etc/systemd/system/bot.service
[Unit]
Description=Bot Telegram Registrasi IP
After=network.target

[Service]
WorkingDirectory=/root/bot
ExecStart=/usr/bin/python3 /root/bot/bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable bot
systemctl start bot

echo -e "${GREEN}[SELESAI] Bot Telegram berhasil diinstal dan aktif.${NC}"
echo -e "Silakan edit file: /root/bot/config.json"
echo -e "Ganti token dan admin_id sesuai Bot Telegram kamu"
