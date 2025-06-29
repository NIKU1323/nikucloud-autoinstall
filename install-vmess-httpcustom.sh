#!/bin/bash

# ============================================
# NIKU TUNNEL - Auto Install Xray VMESS WS TLS
# Compatible with HTTP Custom
# ============================================

# Warna
GREEN="\e[32m"
NC="\e[0m"

# Pastikan root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Harus dijalankan sebagai root!${NC}"
  exit 1
fi

# Input domain
read -p "Masukkan domain (sudah di-pointing ke VPS): " domain
echo "$domain" > /etc/xray/domain

# Update & install paket
apt update -y
apt install curl socat cron bash unzip -y

# Install ACME
curl https://acme-install.netlify.app/acme.sh -o /root/acme.sh
bash /root/acme.sh --install
~/.acme.sh/acme.sh --register-account -m admin@$domain
~/.acme.sh/acme.sh --issue --standalone -d $domain --force
~/.acme.sh/acme.sh --install-cert -d $domain \
  --key-file /etc/xray/xray.key \
  --fullchain-file /etc/xray/xray.crt

# Install Xray
mkdir -p /etc/xray
mkdir -p /var/log/xray/
cd /tmp
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip
install xray /usr/bin/xray
chmod +x /usr/bin/xray

# UUID random
uuid=$(cat /proc/sys/kernel/random/uuid)

# Buat config
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        },
        "wsSettings": {
          "path": "/vmess"
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

# Buat service systemd
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
ExecStart=/usr/bin/xray -config /etc/xray/config.json
Restart=on-failure
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Enable dan start
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl start xray

# Buat config link
vmess_base64=$(echo '{
  "v": "2",
  "ps": "NIKU-TUNNEL",
  "add": "'$domain'",
  "port": "443",
  "id": "'$uuid'",
  "aid": "0",
  "net": "ws",
  "path": "/vmess",
  "type": "none",
  "host": "'$domain'",
  "tls": "tls",
  "sni": "'$domain'"
}' | base64 -w0)

echo -e "${GREEN}Install sukses!${NC}"
echo "==============================="
echo "Format untuk HTTP Custom:"
echo "==============================="
echo -e "Domain      : $domain"
echo -e "Port        : 443"
echo -e "UUID        : $uuid"
echo -e "Path        : /vmess"
echo -e "Network     : ws"
echo -e "TLS         : on"
echo -e "SNI/Host    : $domain"
echo -e "vmess://$vmess_base64"
echo "==============================="
