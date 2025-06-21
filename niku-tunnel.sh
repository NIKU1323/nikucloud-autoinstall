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
systemctl stop xray >/dev/null 2>&1
~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --force --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem >/dev/null 2>&1

# ====== Install Xray Core ======
echo -e "${cyan}[•] Install Xray Core...${plain}"
cd /etc/xray
wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o Xray-linux-64.zip >/dev/null 2>&1
chmod +x xray && mv xray /usr/local/bin/

# ====== Buat Konfigurasi Xray ======
cat > /etc/xray/config.json << EOF
{ "log": { "loglevel": "none" },
  "inbounds": [
    {"port": 443, "protocol": "vmess", "settings": {"clients": []},
     "streamSettings": {"network": "ws", "security": "tls",
       "tlsSettings": {"certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]},
       "wsSettings": {"path": "/vmess"}}},
    {"port": 80, "protocol": "vmess", "settings": {"clients": []},
     "streamSettings": {"network": "ws", "security": "none", "wsSettings": {"path": "/vmess"}}},
    {"port": 444, "protocol": "trojan", "settings": {"clients": []},
     "streamSettings": {"network": "tcp", "security": "tls",
       "tlsSettings": {"certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]}}},
    {"port": 443, "protocol": "vless", "settings": {"clients": [], "decryption": "none"},
     "streamSettings": {"network": "grpc", "security": "tls",
       "grpcSettings": {"serviceName": "vless-grpc"},
       "tlsSettings": {"certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]}}}
  ],
  "outbounds": [{"protocol": "freedom"}]
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

# ====== Setup BOT TELEGRAM ======
mkdir -p /etc/niku-bot
pip3 install pyTelegramBotAPI >/dev/null 2>&1
cat > /etc/niku-bot/bot.py << 'EOF'
import telebot
import os
bot = telebot.TeleBot("BOT_TOKEN")

@bot.message_handler(commands=['start'])
def start(message):
  if str(message.from_user.id) != "ADMIN_ID": return
  bot.reply_to(message, "Selamat datang di NIKU TUNNEL BOT\nKetik /menu untuk mulai")

@bot.message_handler(commands=['menu'])
def menu(message):
  if str(message.from_user.id) != "ADMIN_ID": return
  menu = """
⚙️ MENU:
/menu - Tampilkan Menu
/addssh - Tambah Akun SSH
/addvmess - Tambah Akun VMESS
  """
  bot.reply_to(message, menu)

@bot.message_handler(commands=['addssh'])
def add_ssh(message):
  if str(message.from_user.id) != "ADMIN_ID": return
  os.system("bash /etc/niku-bot/addssh.sh")
  bot.reply_to(message, "✅ SSH berhasil dibuat.")

@bot.message_handler(commands=['addvmess'])
def add_vmess(message):
  if str(message.from_user.id) != "ADMIN_ID": return
  os.system("bash /etc/niku-bot/addvmess.sh")
  bot.reply_to(message, "✅ VMESS berhasil dibuat.")

bot.polling()
EOF

sed -i "s|BOT_TOKEN|$BOT_TOKEN|g" /etc/niku-bot/bot.py
sed -i "s|ADMIN_ID|$ADMIN_ID|g" /etc/niku-bot/bot.py

cat > /etc/systemd/system/niku-bot.service << EOF
[Unit]
Description=NIKU TUNNEL BOT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/niku-bot/bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

# ====== Menu CLI Manual ======
cat > /root/menu.sh << 'EOF'
#!/bin/bash
while true; do
clear
echo -e "\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[1;32m     NIKU TUNNEL - MERCURYVPN     \e[0m"
echo -e "\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "1. Buat Akun SSH"
echo -e "2. Buat Akun VMESS"
echo -e "3. Cek Status Layanan"
echo -e "4. Restart Layanan"
echo -e "5. Log Xray"
echo -e "6. Keluar"
echo -e "\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
read -p "Pilih opsi [1-6]: " pilih
case $pilih in
1) bash /etc/niku-bot/addssh.sh;;
2) bash /etc/niku-bot/addvmess.sh;;
3) systemctl status xray | head -n 10;;
4) systemctl restart xray && systemctl restart niku-bot;;
5) journalctl -u xray --no-pager | tail -n 20;;
6) exit;;
*) echo "❌ Pilihan tidak valid.";;
esac
done
EOF
chmod +x /root/menu.sh

# ====== Tambahkan alias ======
echo "alias menu='bash /root/menu.sh'" >> ~/.bashrc

# ====== Prompt reboot ======
echo -e "\n\e[1;32m✅ Instalasi selesai!\e[0m"
echo -e "Ingin reboot VPS sekarang? (y/n): "
read reboot_confirm
if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "Y" ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Ketik 'menu' untuk buka panel."
fi
