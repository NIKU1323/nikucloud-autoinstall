#!/bin/bash

# Warna
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${GREEN}=============================="
echo "   AUTO INSTALL NIKU TUNNELING"
echo "  SSH | VMESS | VLESS | TROJAN"
echo "  + HAProxy + SSL (Let's Encrypt)"
echo -e "==============================${NC}"

# Validasi IP
MYIP=$(curl -s ipv4.icanhazip.com)
echo -e "\n📡 IP VPS: $MYIP"
LISENSI_FILE="$HOME/license/iplist.txt"

if [ ! -f "$LISENSI_FILE" ]; then
  echo -e "${RED}❌ File lisensi tidak ditemukan.${NC}"
  exit 1
fi

DATA=$(grep "^$MYIP|" "$LISENSI_FILE")
if [ -z "$DATA" ]; then
  echo -e "${RED}❌ IP $MYIP tidak terdaftar dalam lisensi.${NC}"
  exit 1
fi

ID=$(echo "$DATA" | cut -d '|' -f 2)
EXP=$(echo "$DATA" | cut -d '|' -f 3)
AUTH=$(echo "$DATA" | cut -d '|' -f 4)

echo -e "${GREEN}✅  Lisensi valid!${NC}"
echo -e "👤 ID     : $ID"
echo -e "📅 Exp    : $EXP"
echo -e "🔐 Auth   : $AUTH"

# Input domain dan validasi pointing
read -p $'\n🌐 Masukkan domain (sudah di-pointing ke VPS): ' DOMAIN
IP_DOMAIN=$(ping -c 1 $DOMAIN | grep -oP '\((.*?)\)' | tr -d '()')
if [[ "$IP_DOMAIN" != "$MYIP" ]]; then
  echo -e "${RED}❌ Domain belum dipointing ke IP VPS (${MYIP}). Saat ini mengarah ke $IP_DOMAIN${NC}"
  exit 1
fi
echo "$DOMAIN" > /etc/domain

# Install tools dan dependency dasar
apt update && apt install -y curl wget unzip tar socat cron bash-completion iptables dropbear openssh-server nginx gnupg lsb-release net-tools dnsutils screen python3-pip jq figlet lolcat haproxy vnstat certbot > /dev/null 2>&1

# Stop NGINX sementara agar certbot bisa listen port 80
systemctl stop nginx

# Buat folder untuk Xray
mkdir -p /etc/xray

# Pasang SSL dari Let's Encrypt
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN > /dev/null 2>&1

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  echo -e "${RED}❌ Gagal memasang SSL.${NC}"
  exit 1
fi
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/xray/xray.crt
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/xray/xray.key
chmod 600 /etc/xray/*

# Install Xray
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -q /tmp/xray.zip -d /tmp/xray
install -m 755 /tmp/xray/xray /usr/local/bin/xray
rm -rf /tmp/xray*

# Konfigurasi dasar Xray
UUID=$(uuidgen)
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$UUID"}]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/xray/xray.crt",
            "keyFile": "/etc/xray/xray.key"
          }]
        }
      }
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none"
      }
    },
    {
      "port": 444,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "trojanpass123"}]
      },
      "streamSettings": {
        "security": "tls",
        "network": "tcp",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/xray/xray.crt",
            "keyFile": "/etc/xray/xray.key"
          }]
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# Systemd untuk Xray
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# Start kembali NGINX
systemctl start nginx

# HAProxy config
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
cat > /etc/haproxy/haproxy.cfg <<EOF
# konfigurasi haproxy default
EOF
systemctl enable haproxy
systemctl restart haproxy

# Enable SSH & Dropbear
systemctl enable ssh
systemctl restart ssh
systemctl enable dropbear
systemctl restart dropbear

# Firewall (buka semua port umum)
ufw allow 22,80,443,444,109,143,110,445/tcp

# Download menu
mkdir -p /root/menu && cd /root/menu
BASE_URL="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"
for file in menu.sh menu-ssh.sh menu-vmess.sh menu-vless.sh menu-trojan.sh menu-shadow.sh menu-tools.sh menu-system.sh menu-bandwidth.sh menu-speedtest.sh menu-limit.sh menu-backup.sh; do
  wget -q "$BASE_URL/$file" -O "$file"
  chmod +x "$file"
done

# Buat subfolder dan isi
for type in ssh vmess vless trojan; do
  mkdir -p "/root/menu/$type"
  for script in create.sh autokill.sh cek.sh lock.sh list.sh delete-exp.sh delete.sh unlock.sh trial.sh multilogin.sh renew.sh; do
    wget -q -O "/root/menu/$type/$script" "$BASE_URL/$type/$script"
    chmod +x "/root/menu/$type/$script"
  done
done

# Shortcut menu
ln -sf /root/menu/menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu
if ! grep -q "menu.sh" ~/.bashrc; then
  echo "clear && bash /root/menu/menu.sh" >> ~/.bashrc
fi

# Status akhir
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "   SSH : ●   NGINX : ●   XRAY : $(systemctl is-active xray &>/dev/null && echo ● || echo ○)"
echo -e "   WS-ePRO : $(netstat -tunlp | grep -q 80 && echo ● || echo ○)   DROPBEAR : ●   HAPROXY : ●"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "🔄 Reboot VPS sekarang? (y/n): " jawab
if [[ "$jawab" == "y" || "$jawab" == "Y" ]]; then
  reboot
else
  echo -e "${YELLOW}⚠️  Jalankan dengan perintah: menu${NC}"
fi
