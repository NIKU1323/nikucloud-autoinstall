#!/bin/bash
# AUTO INSTALL VPN + BOT TELEGRAM
# Author: NIKU TUNNEL / MERCURYVPN

clear
echo "=========================================="
echo "         AUTO INSTALL VPN SCRIPT          "
echo "=========================================="

MYIP=$(curl -s ipv4.icanhazip.com)
mkdir -p /etc/niku

echo "[ CHECKING IP AUTHORIZATION... ]"

# Buat allowed.json otomatis
mkdir -p /var/www/html
echo "[\"$MYIP\"]" > /var/www/html/allowed.json

# Install Nginx dan validasi IP
apt update -y && apt install -y nginx
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

# Cek izin IP (localhost nginx)
IZIN=$(curl -s http://127.0.0.1/allowed.json | grep -w "$MYIP")
if [[ $IZIN == "" ]]; then
    echo "[ ACCESS DENIED - IP NOT REGISTERED ]"
    exit 1
fi

# Install dasar
apt install -y curl socat git screen cron net-tools unzip python3 python3-pip python3-venv dropbear squid haproxy openvpn

# Install BadVPN
wget -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/v1.999.130/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100

# Install Xray
bash <(curl -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

# Install ACME SSL
curl https://acme-install.netlify.app/acme.sh -o acme.sh && bash acme.sh && rm acme.sh

# Setup rc.local untuk badvpn
cat <<EOF >/etc/rc.local
#!/bin/sh -e
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100
exit 0
EOF
chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local

# Clone file menu
mkdir -p /root/menu/
cd /root/menu/
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoininstall/main/menu/menu-trojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/add-domain.sh
chmod +x menu/*

# Setup symlink menu
ln -s /root/menu/menu.sh /usr/bin/menu
chmod +x /usr/bin/menu

# Bot Telegram
mkdir -p /root/bot/
cd /root/bot/

# File bot.py
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
        bot.reply_to(msg, "Admin Menu:\\n/addip <IP>\\n/delip <IP>\\n/listip\\n/renewip <IP>")
    else:
        bot.reply_to(msg, "Akses Ditolak.")

@bot.message_handler(func=lambda m: True)
def handler(msg):
    if msg.chat.id != admin: return
    text = msg.text.split()
    cmd = text[0].lower()
    if cmd == "/addip" and len(text) > 1:
        ip = text[1]
        data = load_ip()
        if ip in data:
            bot.reply_to(msg, f"IP {ip} sudah terdaftar.")
        else:
            data.append(ip)
            save_ip(data)
            bot.reply_to(msg, f"IP {ip} berhasil ditambahkan.")
    elif cmd == "/delip" and len(text) > 1:
        ip = text[1]
        data = load_ip()
        if ip in data:
            data.remove(ip)
            save_ip(data)
            bot.reply_to(msg, f"IP {ip} dihapus.")
        else:
            bot.reply_to(msg, f"IP {ip} tidak ditemukan.")
    elif cmd == "/listip":
        data = load_ip()
        bot.reply_to(msg, "Daftar IP:\\n" + "\\n".join(data))
    elif cmd == "/renewip" and len(text) > 1:
        ip = text[1]
        data = load_ip()
        if ip in data:
            save_ip(data)
            bot.reply_to(msg, f"IP {ip} diperbarui.")
        else:
            bot.reply_to(msg, f"IP {ip} tidak terdaftar.")

bot.polling()
EOF

# File config.json
cat <<EOF >config.json
{
  "token": "ISI_TOKEN_BOT",
  "admin_id": YOUR_ADMIN_ID
}
EOF

# File allowed.json untuk bot
cp /var/www/html/allowed.json /root/bot/allowed.json

# Systemd service bot
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

# Aktifkan service bot
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable bot
systemctl start bot

clear
echo "=========================================="
echo "         INSTALASI SELESAI                "
echo " Jalankan menu: menu                      "
echo " Bot Telegram berjalan otomatis           "
echo "=========================================="
read -p "Reboot sekarang? (y/n): " rebootnow
[[ $rebootnow == "y" || $rebootnow == "Y" ]] && reboot
