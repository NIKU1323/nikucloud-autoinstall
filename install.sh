#!/bin/bash

# === Warna Terminal ===
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

clear
echo -e "${GREEN}🚀 Memulai Validasi Lisensi IP...${NC}"

# Ambil IP VPS
MYIP=$(curl -s ipv4.icanhazip.com)
echo -e "📡 IP VPS: $MYIP"

# Path file lisensi
LISENSI_FILE="$HOME/license/iplist.txt"

# Cek file lisensi
if [ ! -f "$LISENSI_FILE" ]; then
    echo -e "${RED}❌ File lisensi tidak ditemukan: $LISENSI_FILE${NC}"
    exit 1
fi

# Validasi IP
DATA=$(grep "^$MYIP|" "$LISENSI_FILE")
if [ -z "$DATA" ]; then
    echo -e "${RED}❌ IP $MYIP tidak ditemukan di lisensi.${NC}"
    exit 1
fi

# Ambil data
ID=$(echo "$DATA" | cut -d '|' -f 2)
EXP=$(echo "$DATA" | cut -d '|' -f 3)
AUTH=$(echo "$DATA" | cut -d '|' -f 4)

# Tampilkan informasi lisensi
echo -e "${GREEN}✅ Lisensi valid!${NC}"
echo -e "👤 ID     : $ID"
echo -e "📅 Exp    : $EXP"
echo -e "🔐 Auth   : $AUTH"

# Input domain
echo ""
read -p "🌐 Masukkan domain yang sudah dipointing ke IP VPS ini: " DOMAIN
echo "$DOMAIN" > /etc/domain

# Install dependensi
echo -e "${GREEN}📦 Menginstal dependensi...${NC}"
apt update -y
apt install -y curl wget gnupg lsb-release socat net-tools dnsutils screen unzip tar nginx python3 python3-pip vnstat lolcat figlet git jq > /dev/null 2>&1

# Install acme.sh
echo -e "${GREEN}🔐 Mengatur SSL dengan acme.sh...${NC}"
mkdir -p /etc/xray
curl https://acme-install.netlify.app/acme.sh -o acme.sh && bash acme.sh --install > /dev/null 2>&1
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN > /dev/null 2>&1
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256 > /dev/null 2>&1
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/xray.key \
--fullchain-file /etc/xray/xray.crt > /dev/null 2>&1

# Download Xray Core
echo -e "${GREEN}⬇️ Mengunduh Xray Core...${NC}"
mkdir -p /usr/local/bin
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /usr/local/bin > /dev/null 2>&1
chmod +x /usr/local/bin/xray

# Config dasar dummy
echo -e "${GREEN}⚙️ Membuat config dummy Xray...${NC}"
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": []
}
EOF

# Enable dan jalankan vnstat
systemctl enable vnstat
systemctl start vnstat

# Output final
echo ""
echo -e "${GREEN}✅ Instalasi selesai!${NC}"
echo -e "🌐 DOMAIN : $DOMAIN"
echo -e "🧠 IP VPS : $MYIP"
echo -e "👤 ID     : $ID"
echo -e "📅 Exp    : $EXP"
echo -e "🔐 Auth   : $AUTH"
