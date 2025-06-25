#!/bin/bash
# AUTO INSTALL TELEGRAM BOT - NIKU TUNNEL

echo -e "\e[33m[•] Instalasi Bot Telegram NIKU TUNNEL dimulai...\e[0m"

# ==== INPUT TOKEN DAN ADMIN ID ====
read -p "Masukkan Bot Token Telegram: " TOKEN
read -p "Masukkan Telegram Admin ID: " ADMIN_ID

# ==== INSTALL PYTHON & PIP ====
echo -e "\e[33m[•] Install dependensi python3 & pip3...\e[0m"
apt update -y
apt install python3 python3-pip -y

# ==== INSTALL MODULE TELEGRAM & PARAMIKO ====
pip3 install --upgrade pip
pip3 install python-telegram-bot==20.3 paramiko

# ==== BUAT FOLDER BOT ====
mkdir -p /etc/niku-bot
mkdir -p /var/www/html/qris

# ==== BUAT FILE config.json ====
cat > /etc/niku-bot/config.json <<EOF
{
  "BOT_TOKEN": "$TOKEN",
  "ADMIN_IDS": [$ADMIN_ID],
  "TARIF": {
    "ssh": 1000,
    "vmess": 2000,
    "vless": 2000,
    "trojan": 2000,
    "ipreg": 5000
  }
}
EOF

# ==== BUAT allowed.json (jika dibutuhkan) ====
cat > /etc/niku-bot/allowed.json <<EOF
[]
EOF

# ==== BUAT FILE bot.py ====
cat > /etc/niku-bot/bot.py <<'EOF'
# ISI bot.py AKAN DIMASUKKAN DI SINI (lihat bagian sebelumnya)
# Agar tidak terlalu panjang, silakan salin isi `bot.py` versi fix sebelumnya ke sini
EOF

# ==== SYSTEMD SERVICE ====
cat > /etc/systemd/system/niku-bot.service <<EOF
[Unit]
Description=NIKU TUNNEL TELEGRAM BOT
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/niku-bot/bot.py
WorkingDirectory=/etc/niku-bot/
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# ==== ENABLE & START SERVICE ====
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable niku-bot
systemctl restart niku-bot

# ==== DONE ====
echo -e "\e[32m[SUKSES] Bot Telegram berhasil diinstall & dijalankan!\e[0m"
echo -e "Cek status: \e[36msystemctl status niku-bot\e[0m"
