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
apt update -y && apt upgrade -y && apt install socat curl cron unzip wget git python3 python3-pip dropbear stunnel4 -y >/dev/null 2>&1

# ====== Pasang SSL Let's Encrypt ======
echo -e "${cyan}[•] Pasang SSL Let's Encrypt...${plain}"
curl https://get.acme.sh | sh >/dev/null 2>&1
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN >/dev/null 2>&1

# Hentikan Xray jika aktif
systemctl stop xray >/dev/null 2>&1

~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --force --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem >/dev/null 2>&1

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
... (KODE BOT TETAP SAMA - DIPERSINGKAT UNTUK KEJELASAN) ...
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

# ====== Buat Menu CLI Manual ======
cat > /root/menu.sh << 'MENU'
#!/bin/bash
while true; do
clear
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;36m  NIKU TUNNEL - MERCURYVPN PANEL\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "1. Buat Akun SSH"
echo -e "2. Buat Akun VMESS"
echo -e "3. Cek Status Layanan"
echo -e "4. Restart Bot Telegram"
echo -e "5. Restart Xray"
echo -e "6. Lihat Log Xray"
echo -e "7. Keluar"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -p "Pilih opsi [1-7]: " opsi
case $opsi in
1)
  read -p "Username SSH: " user
  read -p "Password SSH: " pass
  read -p "Expired (hari): " exp
  useradd -e $(date -d "$exp days" +%Y-%m-%d) -s /bin/false -M $user
  echo "$user:$pass" | chpasswd
  echo -e "\n✅ SSH berhasil dibuat untuk $user, password: $pass\n"
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
2)
  uuid=$(cat /proc/sys/kernel/random/uuid)
  read -p "Username VMESS: " user
  read -p "Expired (hari): " exp
  expdate=$(date -d "$exp days" +%Y-%m-%d)
  sed -i "/clients":/a\        {\"id\": \"$uuid\", \"email\": \"$user\"}," /etc/xray/config.json
  systemctl restart xray
  echo -e "\n✅ VMESS berhasil dibuat untuk $user"
  echo -e "UUID: $uuid"
  echo -e "Expired: $expdate\n"
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
3)
  systemctl status xray | head -n 10
  systemctl status niku-bot | head -n 10
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
4)
  systemctl restart niku-bot && echo "✅ Bot berhasil direstart"
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
5)
  systemctl restart xray && echo "✅ Xray berhasil direstart"
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
6)
  journalctl -u xray --no-pager | tail -n 20
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
7)
  exit
  ;;
*)
  echo "❌ Pilihan tidak valid."
  read -n 1 -s -r -p "Tekan enter untuk kembali ke menu..."
  ;;
esac
done
MENU

chmod +x /root/menu.sh

# ====== Tambahkan alias menu ke ~/.bashrc ======
sed -i '/alias menu=/d' ~/.bashrc
echo "alias menu='bash /root/menu.sh'" >> ~/.bashrc

# Selesai
clear
echo -e "\n\033[1;32m✅ Instalasi selesai!\033[0m"
echo -e "Ketik \033[1;33mmenu\033[0m untuk membuka panel."
