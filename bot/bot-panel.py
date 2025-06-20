#!/usr/bin/env python3
import telepot, os, subprocess
from telepot.loop import MessageLoop

TOKEN = open('/etc/nikucloud/bot_token.conf').read().strip()
ADMIN = open('/etc/nikucloud/admin_id.conf').read().strip()

bot = telepot.Bot(TOKEN)

def handle(msg):
    chat_id = str(msg['chat']['id'])
    text = msg.get('text', '')

    if chat_id != ADMIN:
        bot.sendMessage(chat_id, "❌ Kamu bukan admin!")
        return

    if text == "/start":
        bot.sendMessage(chat_id, "👋 Selamat datang di Bot Panel VPN!

Perintah:
/status
/online
/sshlist
/xraylist
/reboot")
    elif text == "/status":
        uptime = subprocess.getoutput("uptime -p")
        ram = subprocess.getoutput("free -h | grep Mem")
        bot.sendMessage(chat_id, f"🖥 VPS Status:\nUptime: {uptime}\nRAM: {ram}")
    elif text == "/online":
        who = subprocess.getoutput("who")
        bot.sendMessage(chat_id, f"👥 Online:\n{who}")
    elif text == "/sshlist":
        ssh = subprocess.getoutput("grep '^###' /etc/ssh/akun.conf")
        bot.sendMessage(chat_id, f"🔐 SSH Aktif:\n{ssh}")
    elif text == "/xraylist":
        xray = subprocess.getoutput("grep '^###' /etc/xray/*.json")
        bot.sendMessage(chat_id, f"📡 XRAY Aktif:\n{xray}")
    elif text == "/reboot":
        bot.sendMessage(chat_id, "♻️ VPS akan direboot...")
        os.system("reboot")
    else:
        bot.sendMessage(chat_id, "❓ Perintah tidak dikenali. Gunakan /start untuk lihat menu.")

MessageLoop(bot, handle).run_as_thread()

print("🤖 Bot Panel aktif... tekan Ctrl+C untuk keluar.")
import time
while 1:
    time.sleep(10)
