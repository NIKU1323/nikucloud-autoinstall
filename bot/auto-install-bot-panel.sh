#!/bin/bash
echo "🤖 Auto Install BOT PANEL TELEGRAM"

read -p "🔑 Token Bot Telegram: " token
read -p "👑 Chat ID Admin: " admin

mkdir -p /etc/nikucloud
echo "$token" > /etc/nikucloud/bot_token.conf
echo "$admin" > /etc/nikucloud/admin_id.conf

apt update -y && apt install -y python3 python3-pip
pip3 install telepot psutil

wget -q -O /usr/bin/bot-panel https://raw.githubusercontent.com/NIKU1323/nikucloud-menu/main/bot/bot-panel.py
chmod +x /usr/bin/bot-panel

screen -S panel -X quit 2>/dev/null
screen -dmS panel python3 /usr/bin/bot-panel

if ! grep -q "bot-panel" /etc/crontab; then
  echo "@reboot root screen -dmS panel python3 /usr/bin/bot-panel" >> /etc/crontab
fi

echo "✅ BOT PANEL aktif!"
