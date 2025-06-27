#!/bin/bash
# MERCURY VPN — Installer Bot Telegram (Auto GitHub Pull + Listener Setup)

clear
echo -e "\e[1;32mMERCURY VPN — Telegram Bot Installer (with Listener)\e[0m"

# Update & install Node.js
echo -e "\e[1;33m[INFO] Updating & Installing Node.js...\e[0m"
apt update -y && apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs git
npm install -g pm2

# Prepare directory
echo -e "\e[1;33m[INFO] Preparing directories...\e[0m"
mkdir -p /root/niku-bot/data
cd /root/niku-bot || exit

# Download bot.js from GitHub
echo -e "\e[1;33m[INFO] Downloading bot.js from GitHub...\e[0m"
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/bot.js -O /root/niku-bot/bot.js

# Create default data files
echo -e "\e[1;33m[INFO] Creating default data files...\e[0m"
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

# Install dependencies
echo -e "\e[1;33m[INFO] Installing Node.js dependencies...\e[0m"
npm install telegraf axios uuid dotenv

# Systemd + pm2 setup
echo -e "\e[1;33m[INFO] Configuring PM2 service...\e[0m"

# Create PM2 startup script
cat <<EOF > /root/niku-bot/start.sh
#!/bin/bash
cd /root/niku-bot
node bot.js
EOF

chmod +x /root/niku-bot/start.sh

# Initialize PM2
pm2 start /root/niku-bot/start.sh --name "niku-bot" --watch
pm2 save
pm2 startup

# Create environment file
echo -e "\e[1;33m[INFO] Creating .env file...\e[0m"
cat <<EOF > /root/niku-bot/.env
BOT_TOKEN=your_bot_token_here
ADMIN_ID=your_admin_id_here
EOF

# Final notification
echo -e "\n\e[1;32m[✔] INSTALLATION COMPLETE!\e[0m"
echo -e "📂 Location: /root/niku-bot"
echo -e "🚀 Bot Status: pm2 list"
echo -e "🔄 Restart: pm2 restart niku-bot"
echo -e "📝 Edit Config: nano /root/niku-bot/bot.js"
echo -e "\e[1;33mDon't forget to edit .env file with your actual bot token!\e[0m\n"

# Show PM2 status
pm2 list
