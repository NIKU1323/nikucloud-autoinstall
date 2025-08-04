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
echo "  + Nginx + SSL (acme.sh)"
echo -e "==============================${NC}"

# Validasi IP
echo -e "\n🚀 Memulai Validasi Lisensi IP..."
MYIP=$(curl -s ipv4.icanhazip.com)
echo -e "📱 IP VPS: $MYIP"
LISENSI_FILE="$HOME/license/iplist.txt"

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

# Cek dan simpan domain hanya sekali
mkdir -p /etc/xray
if [[ -s /etc/xray/domain ]]; then
    DOMAIN=$(cat /etc/xray/domain)
    echo -e "✅ Domain terdeteksi: $DOMAIN"
else
    echo -e "\n🌐 Masukkan domain yang sudah di-pointing ke VPS ini:"
    read -p "→ Domain: " DOMAIN
    echo "$DOMAIN" > /etc/xray/domain
    echo "$DOMAIN" > /etc/domain.txt
    echo -e "✅ Domain tersimpan di /etc/xray/domain"
fi

# Cek pointing domain ke IP VPS
DOMAIN_IP=$(ping -c 1 $DOMAIN | grep -oP '(?<=\().*?(?=\))' | head -n1)
if [[ "$DOMAIN_IP" != "$MYIP" ]]; then
  echo -e "${YELLOW}⚠️  Domain tidak mengarah ke IP VPS. Lanjutkan tetap? (y/n): ${NC}"
  read Lanjut
  if [[ "$Lanjut" != "y" && "$Lanjut" != "Y" ]]; then
    echo -e "${RED}❌ Instalasi dibatalkan.${NC}"
    exit 1
  fi
fi

# Update & install tools
echo -e "\n${GREEN}📦 Mengupdate dan menginstall paket yang dibutuhkan...${NC}"
apt update
apt install -y curl wget unzip tar socat cron bash-completion iptables dropbear openssh-server gnupg lsb-release net-tools dnsutils screen python3-pip jq figlet lolcat nginx vnstat

# Install acme.sh + Let's Encrypt
echo -e "\n${GREEN}🔐 Mengatur SSL (Let's Encrypt)...${NC}"
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/xray.key \
--fullchain-file /etc/xray/xray.crt

# Konfirmasi SSL
if [ -f /etc/xray/xray.crt ]; then
  echo -e "${GREEN}✅ SSL sukses terpasang!${NC}"
  EXPIRE=$(openssl x509 -enddate -noout -in /etc/xray/xray.crt | cut -d= -f2)
  echo -e "📅 Expired SSL: $EXPIRE"
else
  echo -e "${RED}❌ Gagal pasang SSL.${NC}"
  exit 1
fi

# Install Xray
echo -e "\n${GREEN}🛠️  Menginstall Xray-core...${NC}"
mkdir -p /var/log/xray
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -q /tmp/xray.zip -d /tmp/xray
install -m 755 /tmp/xray/xray /usr/local/bin/xray
rm -rf /tmp/xray*

# Konfigurasi dasar Xray (Nginx sebagai frontend)
# Xray akan mendengarkan di alamat loopback (127.0.0.1) saja.
# Nginx akan bertindak sebagai reverse proxy yang menerima koneksi dari luar dan meneruskannya ke Xray.
# TLS (enkripsi) akan ditangani oleh Nginx, sehingga konfigurasi Xray tidak perlu menanganinya.
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vmess",
      "settings": {"clients": []},
      "streamSettings": {"network": "ws", "security": "none", "wsSettings": {"path": "/vmess"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vless",
      "settings": {"clients": [], "decryption": "none"},
      "streamSettings": {"network": "ws", "security": "none", "wsSettings": {"path": "/vless"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "settings": {"clients": []},
      "streamSettings": {"network": "ws", "security": "none", "wsSettings": {"path": "/trojan-ws"}}
    }
  ],
  "outbounds": [
    {"protocol": "freedom"}
  ]
}
EOF

# Buat folder log Xray
mkdir -p /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

# Konfigurasi Nginx sebagai Reverse Proxy
# Nginx akan mendengarkan di port 80 (HTTP) dan 443 (HTTPS).
# Port 80 akan secara otomatis mengalihkan semua permintaan ke HTTPS.
# Port 443 akan menangani terminasi SSL dan meneruskan lalu lintas ke layanan Xray yang sesuai berdasarkan path URL.
echo -e "\n${GREEN}🔌 Mengkonfigurasi Nginx sebagai Reverse Proxy...${NC}"
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default
cat > /etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384';

    location /vmess {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vless {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /trojan-ws {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
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

# Restart service
echo -e "\n${GREEN}🔄 Merestart layanan...${NC}"
systemctl daemon-reload
systemctl enable nginx
systemctl restart nginx
systemctl enable xray
systemctl restart xray

# Enable SSH & Dropbear
systemctl enable ssh
systemctl restart ssh
systemctl enable dropbear
systemctl restart dropbear

# Konfigurasi Firewall yang Aman
# Menggunakan UFW (Uncomplicated Firewall) untuk keamanan dasar.
# Aturan default: tolak semua koneksi masuk, izinkan semua koneksi keluar.
# Izinkan koneksi SSH (port 22), HTTP (port 80), dan HTTPS (port 443) secara eksplisit.
echo -e "\n${GREEN}🔒 Mengkonfigurasi firewall (UFW)...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable
echo -e "${GREEN}✅ Firewall diaktifkan dan dikonfigurasi.${NC}"

# Download dan pasang semua menu
mkdir -p /root/menu && cd /root/menu
BASE_URL="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"
for file in menu.sh menu-ssh.sh menu-vmess.sh menu-vless.sh menu-trojan.sh menu-shadow.sh menu-tools.sh menu-system.sh menu-bandwidth.sh menu-speedtest.sh menu-limit.sh menu-backup.sh; do
  wget -q "$BASE_URL/$file" -O "$file"
done
chmod +x *.sh

# Sub-folder menu detail
for type in ssh vmess vless trojan; do
  mkdir -p /root/menu/$type
  for script in create.sh autokill.sh cek.sh lock.sh list.sh delete-exp.sh delete.sh unlock.sh trial.sh multilogin.sh renew.sh; do
    wget -q -O "/root/menu/$type/$script" "$BASE_URL/$type/$script"
  done
  chmod +x /root/menu/$type/*.sh
  done

# Shortcut "menu"
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
