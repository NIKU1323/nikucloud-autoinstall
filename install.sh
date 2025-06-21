#!/bin/bash
# ==========================================
# AUTO INSTALL VPN + BOT TELEGRAM
# ==========================================
# Author   : NIKU TUNNEL / MERCURYVPN
# GitHub   : https://github.com/NIKU1323/nikucloud-autoinstall
# ==========================================

clear
echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[1;32m        AUTO INSTALL VPN SCRIPT        \e[0m"
echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

# SET DOMAIN DAN IP
MYIP=$(curl -s ipv4.icanhazip.com)
mkdir -p /etc/niku

# CEK IP DI IZINKAN
echo -e "[ CHECKING IP AUTHORIZATION... ]"
IZIN=$(curl -s http://YOUR_NGINX_SERVER/allowed.json | grep -w "$MYIP")

if [[ $IZIN == "" ]]; then
    echo -e "\e[1;31m[ ACCESS DENIED - IP NOT REGISTERED ]\e[0m"
    exit 1
fi

# UPDATE & INSTALL DEPENDENSI
apt update -y && apt upgrade -y
apt install -y curl socat git nginx screen cron net-tools unzip python3 python3-pip python3-venv

# INSTALL SSL ACME.SH
curl https://acme-install.netlify.app/acme.sh -o acme.sh && bash acme.sh && rm acme.sh

# INSTALL XRAY CORE
bash <(curl -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

# INSTALL BADVPN
wget -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/v1.999.130/badvpn-udpgw && \
chmod +x /usr/bin/badvpn-udpgw && \
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100

# SETUP NGINX UNTUK allowed.json
mkdir -p /var/www/html/
cat <<EOF >/etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root /var/www/html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
systemctl restart nginx

# CREATE allowed.json
mkdir -p /root/bot/
cat <<EOF >/root/bot/allowed.json
[
  "$MYIP"
]
EOF
cp /root/bot/allowed.json /var/www/html/

# CLONE MENU
mkdir -p /root/menu/
cd /root/menu/
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/add-domain.sh
chmod +x menu/*

# INSTALL SERVICE PENDUKUNG SSH
apt install -y dropbear squid haproxy openvpn
systemctl enable dropbear
systemctl enable squid
systemctl enable haproxy

# BOT TELEGRAM
mkdir -p /root/bot/
cd /root/bot/

# BOT.PY
cat <<EOF >bot.py
import json, time
import telebot

with open("config.json") as f:
    cfg = json.load(f)

bot = telebot.TeleBot(cfg["token"])
admin = cfg["admin_id"]

def load_ip():
    with open("allowed.json") as f:
        return json.load(f)

def save_ip(data):
    with open("allowed.json", "w") as f:
        json.dump(data, f, indent=2)

@bot.message_handler(commands=["start"])
def start(msg):
    if msg.chat.id == admin:
        bot.reply_to(msg, "✅ Admin Menu:\n/addip <IP>\n/delip <IP>\n/listip\n/renewip <IP>")
    else:
        bot.reply_to(msg, "⛔️ Akses Ditolak.")

@bot.message_handler(func=lambda m: True)
def handler(msg):
    if msg.chat.id != admin: return
    text = msg.text.split()
    cmd = text[0].lower()
    if cmd == "/addip" and len(text) > 1:
        ip = text[1]
        data = load_ip()
        if ip in data:
            bot.reply_to(msg, f"⚠️ IP {ip} sudah terdaftar.")
        else:
            data.append(ip)
            save_ip(data)
            bot.reply_to(msg, f"✅ IP {ip} berhasil ditambahkan.")
    elif cmd == "/delip" and len(text) > 1:
        ip = text[1]
        data = load_ip()
        if ip in data:
            data.remove(ip)
            save_ip(data)
            bot.reply_to(msg, f"🗑️ IP {ip} dihapus.")
        else:
            bot.reply_to(msg, f"⚠️ IP {ip} tidak ditemukan.")
    elif cmd == "/listip":
        data = load_ip()
        bot.reply_to(msg, "📄 Daftar IP:\n" + "\n".join(data))
    elif cmd == "/renewip" and len(text) > 1:
        ip = text[1]
        data = load_ip()
        if ip in data:
            save_ip(data)
            bot.reply_to(msg, f"♻️ IP {ip} diperbarui.")
        else:
            bot.reply_to(msg, f"❌ IP {ip} tidak terdaftar.")

bot.polling()
EOF

# CONFIG.JSON
cat <<EOF >config.json
{
  "token": "ISI_TOKEN_BOT",
  "admin_id": YOUR_ADMIN_ID
}
EOF

# SYSTEMD BOT SERVICE
cat <<EOF >/etc/systemd/system/bot.service
[Unit]
Description=Bot Telegram VPN
After=network.target

[Service]
WorkingDirectory=/root/bot
ExecStart=/usr/bin/python3 bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ENABLE DAN START SERVICE
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable bot
systemctl start bot

# RC.LOCAL UNTUK BADVPN
cat <<EOF >/etc/rc.local
#!/bin/sh -e
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100
exit 0
EOF
chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local

# MENU UTAMA
ln -s /root/menu/menu.sh /usr/bin/menu
chmod +x /usr/bin/menu

clear
echo -e "\e[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "✅ INSTALASI SELESAI!"
echo -e "🛡️  Jalankan menu: \e[1;36mmenu\e[0m"
echo -e "🤖 Bot Telegram berjalan di background."
echo -e "\e[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
read -p "Reboot sekarang? (y/n): " rebootnow
[[ $rebootnow == "y" || $rebootnow == "Y" ]] && reboot
