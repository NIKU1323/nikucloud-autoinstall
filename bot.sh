#!/bin/bash
# AUTO INSTALL NIKU TUNNEL TELEGRAM BOT
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
log "Memulai instalasi bot Telegram..."

# Cek root
if [[ $EUID -ne 0 ]]; then
  error "Harus dijalankan sebagai root"
  exit 1
fi

# Install dependensi
log "Menginstall Python & dependensi bot..."
apt update -y && apt install -y python3 python3-pip nginx jq curl unzip git
pip3 install --no-cache-dir python-telegram-bot==13.15 paramiko

# Buat direktori bot
mkdir -p /etc/niku-bot
cd /etc/niku-bot || exit

# Buat bot.py dari script utama
curl -s https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/bot/bot.py -o bot.py
chmod +x bot.py

# Buat file config default
cat > config.json <<EOF
{
  "BOT_TOKEN": "ISI_TOKEN_BOT_DISINI",
  "ADMIN_IDS": [123456789],
  "TARIF": {
    "ssh": 1000,
    "vmess": 2000,
    "vless": 2000,
    "trojan": 2000,
    "ipreg": 5000
  }
}
EOF

# Buat users dan server config kosong
echo '{}' > users.json
echo '[]' > server_config.json

# Buat folder QRIS
mkdir -p /var/www/html/qris
chmod -R 755 /var/www/html/qris

# Buat systemd service
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

# Enable & start
systemctl daemon-reexec
systemctl enable niku-bot
systemctl restart niku-bot

success "Bot Telegram berhasil dipasang!"
echo -e "${YELLOW}Edit config.json untuk memasukkan BOT_TOKEN dan ID admin Telegram${NC}"
