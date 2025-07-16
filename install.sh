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
echo "  + HAProxy + SSL (acme.sh)"
echo -e "==============================${NC}"

# Validasi IP
echo -e "\n🚀 Memulai Validasi Lisensi IP..."
MYIP=$(curl -s ipv4.icanhazip.com)
echo -e "📡 IP VPS: $MYIP"
LISENSI_FILE="$HOME/license/iplist.txt"

DATA=$(grep "^$MYIP|" "$LISENSI_FILE")
if [ -z "$DATA" ]; then
  echo -e "${RED}❌ IP $MYIP tidak terdaftar dalam lisensi.${NC}"
  exit 1
fi

ID=$(echo "$DATA" | cut -d '|' -f 2)
EXP=$(echo "$DATA" | cut -d '|' -f 3)
AUTH=$(echo "$DATA" | cut -d '|' -f 4)

echo -e "${GREEN}✅ Lisensi valid!${NC}"
echo -e "👤 ID     : $ID"
echo -e "📅 Exp    : $EXP"
echo -e "🔐 Auth   : $AUTH"

# Input domain
read -p $'\n🌐 Masukkan domain (sudah di-pointing ke VPS): ' DOMAIN
echo "$DOMAIN" > /etc/domain

# Install dependensi
echo -e "\n${GREEN}📦 Menginstall dependensi...${NC}"
apt update && apt install -y curl wget unzip tar socat cron bash-completion iptables dropbear openssh-server nginx gnupg lsb-release net-tools dnsutils screen python3-pip jq figlet lolcat haproxy vnstat > /dev/null 2>&1

# Install acme.sh dan pasang SSL
echo -e "\n${GREEN}🔐 Mengatur SSL...${NC}"
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
  --key-file /etc/xray/xray.key \
  --fullchain-file /etc/xray/xray.crt

if [ -f /etc/xray/xray.crt ]; then
  echo -e "${GREEN}✅ SSL sukses terpasang!${NC}"
  EXPIRE=$(openssl x509 -enddate -noout -in /etc/xray/xray.crt | cut -d= -f2)
  echo -e "📅 Expired SSL: $EXPIRE"
else
  echo -e "${RED}❌ Gagal pasang SSL.${NC}"
  exit 1
fi

# Install Xray
echo -e "\n${GREEN}⬇️ Menginstall Xray Core...${NC}"
mkdir -p /etc/xray
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -q /tmp/xray.zip -d /tmp/xray
install -m 755 /tmp/xray/xray /usr/local/bin/xray
rm -rf /tmp/xray*

# Konfigurasi dasar Xray
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# Setup HAProxy
echo -e "\n${GREEN}🔀 Setting HAProxy...${NC}"
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
cat > /etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log local0
  log /dev/log local1 notice
  daemon
  maxconn 2048

defaults
  log global
  mode tcp
  timeout connect 10s
  timeout client  1m
  timeout server  1m

frontend https_in
  bind *:443
  mode tcp
  tcp-request inspect-delay 5s
  tcp-request content accept if { req_ssl_hello_type 1 }
  use_backend xray_tls

backend xray_tls
  mode tcp
  server xray 127.0.0.1:443
EOF

systemctl enable haproxy
systemctl restart haproxy

# Aktifkan Xray
echo -e "\n${GREEN}🚀 Menjalankan Xray...${NC}"
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

# Enable SSH & Dropbear
systemctl enable ssh
systemctl restart ssh
systemctl enable dropbear
systemctl restart dropbear

# Firewall
ufw allow 80
ufw allow 443
ufw allow 444
ufw allow 445
ufw allow 22
ufw allow 143
ufw allow 109
ufw allow 110

# Unduh semua menu
echo -e "\n${GREEN}⬇️ Mengunduh semua menu...${NC}"
mkdir -p /root/menu && cd /root/menu
BASE_URL="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"
for file in menu.sh menu-ssh.sh menu-vmess.sh menu-vless.sh menu-trojan.sh menu-shadow.sh menu-tools.sh menu-system.sh menu-bandwidth.sh menu-speedtest.sh menu-limit.sh menu-backup.sh; do
  wget -q "$BASE_URL/$file" -O "$file"
done
chmod +x *.sh

# Unduh submenu (per layanan)
for type in ssh vmess vless trojan; do
  mkdir -p /root/menu/$type
  for script in create.sh autokill.sh cek.sh lock.sh list.sh delete-exp.sh delete.sh unlock.sh trial.sh multilogin.sh renew.sh; do
    wget -q -O "/root/menu/$type/$script" "$BASE_URL/$type/$script"
  done
  chmod +x /root/menu/$type/*.sh
done

# Shortcut command
ln -sf /root/menu/menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu

# Jalankan menu saat login
if ! grep -q "menu.sh" ~/.bashrc; then
  echo "clear && bash /root/menu/menu.sh" >> ~/.bashrc
fi

# Prompt reboot
echo -e "\n${GREEN}✅ Instalasi selesai!${NC}"
read -p "🔄 Reboot VPS sekarang? (y/n): " jawab
if [[ "$jawab" == "y" || "$jawab" == "Y" ]]; then
  reboot
else
  echo -e "${YELLOW}⚠️  Jalankan dengan perintah: menu${NC}"
fi

