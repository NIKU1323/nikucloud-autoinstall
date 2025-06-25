#!/bin/bash
# AUTO INSTALL NIKU TUNNEL TELEGRAM BOT
# Brand: MERCURYVPN / NIKU TUNNEL

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

# Function to validate Telegram ID
validate_id() {
  [[ "$1" =~ ^[0-9]+$ ]] && return 0 || return 1
}

# Function to validate Bot Token
validate_token() {
  [[ "$1" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]] && return 0 || return 1
}

# Automated input
get_bot_config() {
  while true; do
    read -rp "Masukkan BOT TOKEN dari @BotFather: " bot_token
    if validate_token "$bot_token"; then
      break
    else
      error "Format token salah! Contoh: 1234567890:ABCdefGHIJKlmNoPQRStuVWXYz123456"
    fi
  done

  while true; do
    read -rp "Masukkan ID ADMIN TELEGRAM (dapatkan dari @userinfobot): " admin_id
    if validate_id "$admin_id"; then
      break
    else
      error "ID harus angka! Contoh: 123456789"
    fi
  done
}

# Install Python & dependensi bot
log "Menginstall Python & dependensi bot..."
apt update -y && apt install -y python3 python3-pip nginx jq curl unzip git
pip3 install --upgrade pip
pip3 install --no-cache-dir "python-telegram-bot>=20.3,<21.0" paramiko

# Buat folder bot
mkdir -p /etc/niku-bot
cd /etc/niku-bot || exit

# Download bot.py dari GitHub (pastikan link ini sesuai repositori kamu)
log "Mengunduh script bot..."
curl -s https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/bot/bot.py -o bot.py
chmod +x bot.py

# Dapatkan konfigurasi bot
get_bot_config

# Buat config.json dengan tiered pricing default
cat > config.json <<EOF
{
  "BOT_TOKEN": "$bot_token",
  "ADMIN_IDS": [$admin_id],
  "TARIF": {
    "ssh": {
      "7": 3000,
      "10": 5000,
      "15": 8000,
      "30": 15000
    },
    "vmess": {
      "7": 4000,
      "10": 6000,
      "15": 9000,
      "30": 18000
    },
    "vless": {
      "7": 5000,
      "10": 7000,
      "15": 10000,
      "30": 20000
    },
    "trojan": {
      "7": 6000,
      "10": 8000,
      "15": 12000,
      "30": 25000
    },
    "ipreg": 5000
  }
}
EOF

# Buat file database kosong jika belum ada
[ ! -f users.json ] && echo '{}' > users.json
[ ! -f server_config.json ] && echo '{"servers":[],"tarif":{}}' > server_config.json

# Set permission
chmod 600 config.json users.json server_config.json

# Buat folder QRIS (jika diperlukan)
mkdir -p /var/www/html/qris
chmod -R 755 /var/www/html/qris

# Buat systemd service untuk bot
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

# Enable & start service
systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

# Verifikasi instalasi
if systemctl is-active --quiet niku-bot; then
  success "Bot Telegram berhasil dipasang dan dijalankan!"
  echo -e "\n${GREEN}Konfigurasi:"
  echo -e "• Token Bot: $bot_token"
  echo -e "• Admin ID: $admin_id"
  echo -e "• Tarif default sudah diterapkan (bisa diubah via panel admin)"
  echo -e "• Direktori Config: /etc/niku-bot"
  echo -e "• Service: systemctl status niku-bot${NC}"
else
  error "Gagal menjalankan bot. Cek log dengan: journalctl -u niku-bot -f"
fi

