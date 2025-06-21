#!/bin/bash
# AUTO INSTALL VPN + SSL + BOT TELEGRAM
# Author: NIKU TUNNEL / MERCURYVPN

clear
echo "=========================================="
echo "         AUTO INSTALL VPN SCRIPT          "
echo "=========================================="

MYIP=$(curl -s ipv4.icanhazip.com)
mkdir -p /etc/niku

# Input domain pointing ke VPS
read -rp "Masukkan domain (yang sudah dipointing ke IP VPS ini): " domain
domain_ip=$(ping -c1 "$domain" | grep -oP '(\d{1,3}\.){3}\d{1,3}' | head -n1)

if [[ "$domain_ip" != "$MYIP" ]]; then
  echo "=========================================="
  echo " DOMAIN LUH POINTING DULU KONTOL"
  echo " VPS IP : $MYIP"
  echo " DOMAIN : $domain → IP: $domain_ip"
  echo "=========================================="
  exit 1
fi

# Simpan domain
echo "$domain" > /etc/niku/domain

# Install dependensi SSL CE
apt update -y
apt install -y socat netcat curl cron gnupg

# Install acme.sh
curl https://acme-install.netlify.app/acme.sh -o acme.sh && bash acme.sh && rm acme.sh

# Issue SSL cert
~/.acme.sh/acme.sh --issue --standalone -d "$domain" --force
~/.acme.sh/acme.sh --install-cert -d "$domain" \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key

# Install software VPN lainnya
apt install -y nginx git screen unzip python3 python3-pip python3-venv dropbear squid haproxy openvpn

# Setup allowed.json
mkdir -p /var/www/html
echo "[\"$MYIP\"]" > /var/www/html/allowed.json
chmod 644 /var/www/html/allowed.json

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

# Validasi IP allowed.json
sleep 2
TRIES=5
while [[ $TRIES -gt 0 ]]; do
  IZIN=$(curl -s http://127.0.0.1/allowed.json | grep -w "$MYIP")
  [[ $IZIN != "" ]] && break
  echo "Retrying access check..."
  sleep 1
  TRIES=$((TRIES - 1))
done

if [[ $IZIN == "" ]]; then
  echo "[ ACCESS DENIED - IP NOT REGISTERED ]"
  exit 1
fi

# Install BadVPN
wget -O /usr/bin/badvpn-udpgw https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/media/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100

# Install Xray Core
bash <(curl -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

# Setup rc.local
cat <<EOF >/etc/rc.local
#!/bin/sh -e
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100
exit 0
EOF
chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local

# Menu CLI
mkdir -p /root/menu/
cd /root/menu/
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/add-domain.sh
chmod +x /root/menu/*
ln -s /root/menu/menu.sh /usr/bin/menu
chmod +x /usr/bin/menu

# Telegram Bot
mkdir -p /root/bot/
cd /root/bot/

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

cat <<EOF >config.json
{
  "token": "ISI_TOKEN_BOT",
  "admin_id": YOUR_ADMIN_ID
}
EOF

cp /var/www/html/allowed.json /root/bot/allowed.json

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

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable bot
systemctl start bot

clear
echo "=========================================="
echo "      INSTALASI SELESAI ✅                "
echo " Jalankan menu: menu                      "
echo " Bot Telegram aktif dan berjalan otomatis "
echo "=========================================="
read -p "Reboot sekarang? (y/n): " rebootnow
[[ $rebootnow == "y" || $rebootnow == "Y" ]] && reboot

