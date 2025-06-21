#!/bin/bash

# NIKU TUNNEL – MERCURYVPN ALL-IN-ONE INSTALLER
# SSH + VMESS + VLESS + TROJAN + SSL + BOT TELEGRAM + RESELLER

clear
blue="\033[1;34m"
red="\033[1;31m"
green="\033[1;32m"
yellow="\033[1;33m"
cyan="\033[1;36m"
plain="\033[0m"

# ====== KONFIG BOT (ISI MANUAL) ======
BOT_TOKEN="ISI_BOT_TOKEN_LO"
ADMIN_ID="ISI_ADMIN_ID_LO"

# ====== Cek dan pasang domain ======
echo -ne "\nMasukkan domain (sudah di-pointing ke VPS): "; read DOMAIN
mkdir -p /etc/niku
echo "$DOMAIN" > /etc/niku/domain

# ====== Install Dependensi Dasar ======
echo -e "${cyan}[•] Install package dasar...${plain}"
apt update -y && apt upgrade -y && apt install socat curl cron unzip wget git python3 python3-pip net-tools -y >/dev/null 2>&1

# ====== Pasang SSL Let's Encrypt ======
echo -e "${cyan}[•] Pasang SSL Let's Encrypt...${plain}"
curl https://get.acme.sh | sh >/dev/null 2>&1
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1
lsof -t -i :80 | xargs -r kill -9
sleep 2
~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --force --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem >/dev/null 2>&1

# ====== Install SSH ======
echo -e "${cyan}[•] Install SSH/Dropbear...${plain}"
apt install dropbear stunnel4 -y >/dev/null 2>&1

# ====== Install Xray Core ======
echo -e "${cyan}[•] Install Xray Core...${plain}"
mkdir -p /etc/xray && cd /etc/xray
wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o Xray-linux-64.zip >/dev/null 2>&1
chmod +x xray && mv xray /usr/local/bin/

# ====== Buat Konfigurasi Xray ======
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

# ====== Enable Service Xray ======
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

# ====== Setup BOT + RESELLER SYSTEM ======
mkdir -p /etc/niku-bot
pip3 install telebot >/dev/null 2>&1

cat > /etc/niku-bot/bot.py << 'END'
# (Isi skrip Python bot disisipkan terpisah dan aman tanpa perintah chpasswd root)
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

# ====== Buat File Menu Manual ======
cat > /root/menu.sh << 'MENU'
#!/bin/bash
clear
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;36m      NIKU TUNNEL - MERCURYVPN MENU\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "1. Cek status layanan"
echo -e "2. Restart layanan bot"
echo -e "3. Restart layanan Xray"
echo -e "4. Tampilkan log Xray"
echo -e "5. Buat akun SSH"
echo -e "6. Buat akun VMESS"
echo -e "7. Buat akun VLESS"
echo -e "8. Buat akun TROJAN"
echo -e "9. Keluar"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -rp "Pilih opsi [1-9]: " pilih
case "$pilih" in
  1) systemctl status xray | head -n 10 && systemctl status niku-bot | head -n 10 ;;
  2) systemctl restart niku-bot && echo "✅ Bot berhasil direstart" ;;
  3) systemctl restart xray && echo "✅ Xray berhasil direstart" ;;
  4) journalctl -u xray --no-pager | tail -n 20 ;;
  5)
    read -p "Username SSH: " user
    read -p "Durasi hari: " exp
    useradd -e $(date -d "+$exp days" +%Y-%m-%d) -s /bin/false -M $user
    echo -e "$user
123" | passwd $user >/dev/null 2>&1
    echo "✅ SSH berhasil dibuat untuk $user, password: 123"
    ;;
  6)
    read -p "Username: " user
    read -p "Durasi hari: " exp
    uuid=$(cat /proc/sys/kernel/random/uuid)
    exp_date=$(date -d "+$exp days" +%Y-%m-%d)
    domain=$(cat /etc/niku/domain)
    echo "{\"id\":\"$uuid\",\"alterId\":0,\"email\":\"$user\"}," >> /etc/xray/config.json
    systemctl restart xray
    echo "✅ VMESS dibuat untuk $user (expired: $exp hari)"
    ;;
  7)
    echo "(Coming soon: VLESS manual creation)" ;;
  8)
    echo "(Coming soon: TROJAN manual creation)" ;;
  9)
    exit ;;
  *)
    echo "❌ Pilihan tidak valid." ;;
esac
MENU

chmod +x /root/menu.sh
sed -i '/alias menu=/d' ~/.bashrc
echo "alias menu='bash /root/menu.sh'" >> ~/.bashrc
source ~/.bashrc

# Jalankan menu
bash /root/menu.sh
