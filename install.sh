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
apt update && apt install -y curl wget unzip tar socat cron bash-completion iptables dropbear openssh-server gnupg lsb-release net-tools dnsutils screen python3-pip jq figlet lolcat haproxy vnstat > /dev/null 2>&1

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
mkdir -p /var/log/xray
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
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": {
          "path": "/vmess",
          "headers": {
            "Host": "$domain"
          }
        },
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/xray/xray.crt",
            "keyFile": "/etc/xray/xray.key"
          }]
        }
      }
    },
    {
      "port": 444,
      "protocol": "trojan",
      "settings": {
        "clients": []
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
    },
    {
      "port": 445,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": {
          "path": "/vless",
          "headers": {
            "Host": "$domain"
          }
        },
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/xray/xray.crt",
            "keyFile": "/etc/xray/xray.key"
          }]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# Buat folder log Xray
mkdir -p /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

# === Install NGINX ===
apt install nginx -y

# Nonaktifkan default config
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# Buat config NGINX reverse proxy ke Xray (WS)
cat > /etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 80;
    server_name $(cat /etc/domain);

    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8881;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /trojan {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8882;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

# Restart NGINX
systemctl enable nginx
systemctl restart nginx

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

# Install nginx setelah SSL
apt install -y nginx > /dev/null 2>&1

# HAProxy config
touch /etc/haproxy/haproxy.cfg.bak
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
cat > /etc/haproxy/haproxy.cfg <<EOF
defaults
  mode tcp
  timeout connect 5000ms
  timeout client 50000ms
  timeout server 50000ms

frontend ssl_in
  bind *:443
  default_backend ssl_out

backend ssl_out
  server xray 127.0.0.1:443
EOF

systemctl enable haproxy
systemctl restart haproxy

# Enable SSH & Dropbear
systemctl enable ssh
systemctl restart ssh
systemctl enable dropbear
systemctl restart dropbear

# Firewall
ufw disable
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables -X

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
