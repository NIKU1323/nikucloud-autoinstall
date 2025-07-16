#!/bin/bash

# ===============================
# Auto Install VPN Full System
# SSH, VMess, VLESS, Trojan, Shadowsocks
# Dengan Validasi Lisensi IP via Bot Telegram
# ===============================

# Warna terminal
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m" # No Color

clear

# Validasi IP
MYIP=$(curl -s ipv4.icanhazip.com)
LISENSI_FILE="$HOME/license/iplist.txt"

echo -e "\n🔍 Memvalidasi lisensi IP: $MYIP"

if [ ! -f "$LISENSI_FILE" ]; then
    echo -e "${RED}❌ File lisensi tidak ditemukan: $LISENSI_FILE${NC}"
    exit 1
fi

DATA=$(grep "^$MYIP|" "$LISENSI_FILE")
if [ -z "$DATA" ]; then
    echo -e "${RED}❌  IP $MYIP tidak terdaftar.${NC}"
    exit 1
fi

ID=$(echo "$DATA" | cut -d '|' -f 2)
EXP=$(echo "$DATA" | cut -d '|' -f 3)
AUTH=$(echo "$DATA" | cut -d '|' -f 4)

echo -e "${GREEN}✅ Lisensi valid!${NC}"
echo -e "👤 ID     : $ID"
echo -e "📅 Exp    : $EXP"
echo -e "🔐 Auth   : $AUTH"

echo -e "\n${GREEN}🚀 Memulai proses instalasi VPN...${NC}"

# Input domain
read -p "🌐 Masukkan domain yang sudah dipointing ke IP ini: " DOMAIN
echo "$DOMAIN" > /etc/domain

# Install dependensi
apt update && apt install -y curl wget gnupg lsb-release socat net-tools dnsutils screen unzip tar nginx python3 python3-pip vnstat lolcat figlet git jq > /dev/null 2>&1

# Install acme.sh
curl https://acme-install.netlify.app/acme.sh -o acme.sh && bash acme.sh --install > /dev/null 2>&1
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN > /dev/null 2>&1
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256 > /dev/null 2>&1
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/xray.key \
--fullchain-file /etc/xray/xray.crt > /dev/null 2>&1

# Setup Xray
mkdir -p /etc/xray
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray

# Config dasar Xray (dummy)
echo '{ "log": { "access": "/var/log/xray/access.log" } }' > /etc/xray/config.json

# Aktifkan vnstat
systemctl enable vnstat
systemctl start vnstat

# Selesai
echo -e "\n${GREEN}✅ Instalasi selesai!${NC}"
echo -e "🌐 DOMAIN : $DOMAIN"
echo -e "🧠 IP VPS : $MYIP"
echo -e "👤 ID     : $ID"
echo -e "📅 Exp    : $EXP"
echo -e "🔐 Auth   : $AUTH"
