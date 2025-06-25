#!/bin/bash
# AUTO INSTALL NIKU TELEGRAM BOT - DENGAN INPUT TOKEN MANUAL
# Brand: MERCURYVPN / NIKU TUNNEL

# Warna
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'
log() { echo -e "${YELLOW}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

clear
log "📦 Memulai instalasi NIKU TELEGRAM BOT..."

# Cek root
if [[ $EUID -ne 0 ]]; then
  error "Harus dijalankan sebagai root"
  exit 1
fi

# === MASUKKAN BOT TOKEN & ADMIN ID SAAT INSTALL ===
read -p "Masukkan BOT TOKEN dari @BotFather: " BOT_TOKEN
read -p "Masukkan Telegram USER ID Admin: " ADMIN_ID

# Install dependensi
log "Menginstall Python & dependensi bot..."
apt update -y && apt install -y python3 python3-pip nginx jq curl unzip git
pip3 install --no-cache-dir python-telegram-bot==13.15 paramiko

# Buat direktori bot
mkdir -p /etc/niku-bot
cd /etc/niku-bot || exit

# Ambil file bot.py dari repo GitHub
curl -s https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/bot/bot.py -o bot.py
chmod +x bot.py

# Buat config.json berdasarkan input
cat > config.json <<EOF
{
  "bot_token": "$BOT_TOKEN",
  "admin_ids": [$ADMIN_ID],
  "tarif": {
    "ssh": 1000,
    "vmess": 2000,
    "vless": 2000,
    "trojan": 2000,
    "ipreg": 5000
  }
}
EOF

# File database kosong
echo '{}' > users.json
echo '[]' > server_config.json

# Folder QRIS (untuk upload QR bayar)
mkdir -p /var/www/html/qris
chmod -R 755 /var/www/html/qris

# Buat service systemd
cat > /etc/systemd/system/niku-bot.service <<EOF
[Unit]
Description=NIKU TUNNEL TELEGRAM BOT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/niku-bot/bot.py
WorkingDirectory=/etc/niku-bot
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Jalankan bot
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

success "✅ Bot Telegram berhasil diinstal & dijalankan!"

