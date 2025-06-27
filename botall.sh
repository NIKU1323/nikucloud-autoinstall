#!/bin/bash
# MERCURY VPN — Installer Bot Telegram (Auto GitHub Pull + Listener Setup)

clear
echo -e "\e[1;32mMERCURY VPN — Telegram Bot Installer (with Listener)\e[0m"

# Update & install Node.js
echo -e "\e[1;33m[INFO] Updating & Installing Node.js...\e[0m"
apt update -y && apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
npm install -g pm2

# Siapkan folder
mkdir -p /root/niku-bot/data
cd /root/niku-bot

# Download bot.js dari GitHub
echo -e "\e[1;33m[INFO] Downloading bot.js from GitHub...\e[0m"
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/bot.js -O /root/nikucloud-autoinstall//bot.js
# File default data
[[ ! -f data/users.json ]] && echo "{}" > data/users.json

cat <<EOF > data/prices.json
{
  "ssh": 334,
  "vmess": 334,
  "vless": 334,
  "trojan": 334,
  "reg_ip": 2000,
  "buyvps": 30000
}
EOF

cat <<EOF > data/servers.json
{
  "Server 1": "example.com"
}
EOF

# Systemd + pm2 setup
echo -e "\e[1;33m[INFO] Configuring systemd service for bot.js...\e[0m"
cat <<EOF > /etc/systemd/system/niku-bot.service
[Unit]
Description=MERCURY VPN Telegram Bot
After=network.target

[Service]
WorkingDirectory=/root/niku-bot
ExecStart=/usr/bin/pm2 start bot.js --name=niku-bot --watch
Restart=always
User=root
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable niku-bot
systemctl start niku-bot

# Notif akhir
echo -e "\n\e[1;32m[✔] BOT SIAP JALAN BRO!\e[0m"
echo -e "📂 Lokasi: /root/niku-bot"
echo -e "📜 File: bot.js dari GitHub"
echo -e "🚀 Jalankan ulang: pm2 restart niku-bot\n"
