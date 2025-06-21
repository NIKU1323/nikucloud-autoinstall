#!/bin/bash

# =====================================
#  NIKU TUNNEL – MERCURYVPN INSTALLER
#  ALL-IN-ONE: XRAY + SSH + SSL + BOT
# =====================================

# === Warna ===
blue="\033[1;34m"
green="\033[1;32m"
red="\033[1;31m"
yellow="\033[1;33m"
cyan="\033[1;36m"
plain="\033[0m"

clear
mkdir -p /etc/niku

# ===== Konfigurasi BOT =====
BOT_TOKEN="ISI_BOT_TOKEN_LO"
ADMIN_ID="ISI_ADMIN_ID_LO"

# ===== Input Domain =====
echo -e "${green}[•] Masukkan domain kamu yang sudah dipointing ke VPS:${plain}"
read -rp "Domain: " domain
mkdir -p /etc/niku
echo "$domain" > /etc/niku/domain

# ===== Install Paket =====
echo -e "${cyan}[•] Update & install dependensi...${plain}"
apt update -y && apt upgrade -y
apt install -y curl socat cron unzip wget git gnupg ca-certificates lsb-release python3 python3-pip netcat cron bash tar jq iptables iproute2 curl coreutils screen rsyslog gnupg2 lsof debconf-utils figlet dropbear stunnel4

# ===== Install SSL =====
echo -e "${cyan}[•] Pasang SSL Let's Encrypt...${plain}"
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m admin@$domain --server zerossl
~/.acme.sh/acme.sh --issue --standalone -d $domain --force --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d $domain --ecc \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem

# ===== Install Xray Core =====
echo -e "${cyan}[•] Install Xray Core...${plain}"
mkdir -p /etc/xray && cd /etc/xray
wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o Xray-linux-64.zip && chmod +x xray && mv xray /usr/local/bin/

# ===== Buat Konfigurasi Xray =====
cat > /etc/xray/config.json << EOF
{
  "log": { "loglevel": "none" },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]
        },
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "port": 444,
      "protocol": "trojan",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]
        }
      }
    },
    {
      "port": 443,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "grpcSettings": { "serviceName": "vless-grpc" },
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]
        }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# ===== Aktifkan Xray =====
cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ===== Bot Telegram + Reseller =====
mkdir -p /etc/niku-bot
pip3 install telebot

cat > /etc/niku-bot/bot.py << 'END'
# (ISI SCRIPT BOT TELEGRAM DI SINI - SUDAH DIISI DI SEBELUMNYA)
END

sed -i "s|BOT_TOKEN|$BOT_TOKEN|g" /etc/niku-bot/bot.py
sed -i "s|ADMIN_ID|$ADMIN_ID|g" /etc/niku-bot/bot.py

cat > /etc/systemd/system/niku-bot.service << SERVICE
[Unit]
Description=NIKU TUNNEL BOT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/niku-bot/bot.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

# ===== SSH Basic Setting =====
echo -e "${cyan}[•] Aktifkan SSH dan Dropbear...${plain}"
echo "Port 22" > /etc/ssh/sshd_config
systemctl restart ssh
systemctl enable dropbear

# ===== Alias Menu + Auto Jalankan Menu =====
cp "$0" /root/niku-tunnel.sh
chmod +x /root/niku-tunnel.sh
echo "alias menu='bash /root/niku-tunnel.sh'" >> ~/.bashrc
source ~/.bashrc

clear
echo -e "${green}✅ Instalasi selesai!${plain}"
echo -e "Ketik ${yellow}menu${plain} untuk membuka panel."
